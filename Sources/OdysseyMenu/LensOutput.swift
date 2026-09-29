import Foundation
import OdysseyMonitor

/// Serializes controller writes and coalesces frame callbacks. Only a newly
/// presented, tracked frame may request on. Shutdown cancels pending enables.
// Request state is protected by lock; controller state is confined to queue.
// The failure callback is immutable and safe to invoke from that queue.
final class LensOutput: @unchecked Sendable {
  private let queue = DispatchQueue(label: "Odyssey.lens-output")
  private let lock = NSLock()
  private var desired = false, scheduled = false, closed = false
  private var controller: LensController?
  private var monitor: MonitorModeClient?
  private var heartbeat: DispatchSourceTimer?
  private var lastPresentation: TimeInterval = 0
  private var enabled = false
  private let failure: @Sendable (Error) -> Void

  init(failure: @escaping @Sendable (Error) -> Void) {
    self.failure = failure
  }
  func start(port: String) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      queue.async {
        do {
          let controller = try LensController(port: port)
          try controller.authenticate()
          if try controller.isEnabled() { try controller.setEnabled(false) }
          self.controller = controller
          self.enabled = false
          self.monitor = try MonitorModeClient.connectIfPresent()
          if let monitor = self.monitor {
            try monitor.setEnabled(false)
            let state = try monitor.status()
            guard !state.notified3D, !state.firmwareUpdating else {
              throw MonitorModeError.unavailable("Monitor is not ready for playback.")
            }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
            timer.setEventHandler { [weak self] in self?.keepMonitorAlive() }
            self.heartbeat = timer
            timer.resume()
            print("Monitor 3D notification bridge connected")
            fflush(stdout)
          }
          continuation.resume()
        } catch {
          self.monitor?.disconnect()
          self.monitor = nil
          self.controller = nil
          continuation.resume(throwing: error)
        }
      }
    }
  }
  func request(_ on: Bool) {
    lock.lock()
    guard !closed else {
      lock.unlock()
      return
    }
    desired = on
    lastPresentation = ProcessInfo.processInfo.systemUptime
    guard !scheduled else {
      lock.unlock()
      return
    }
    scheduled = true
    lock.unlock()
    queue.async { self.drain() }
  }
  private func drain() {
    while true {
      lock.lock()
      let target = desired && !closed
      lock.unlock()
      if target != enabled {
        do {
          // Match the captured Windows order: lenses, then monitor notification.
          try controller?.setEnabled(target)
          try monitor?.setEnabled(target)
          enabled = target
        } catch {
          fail(error)
          return
        }
      }
      lock.lock()
      if target == (desired && !closed) {
        scheduled = false
        lock.unlock()
        return
      }
      lock.unlock()
    }
  }
  private func fail(_ error: Error) {
    lock.lock()
    closed = true
    desired = false
    scheduled = false
    lock.unlock()
    heartbeat?.cancel()
    heartbeat = nil
    try? controller?.setEnabled(false)
    monitor?.disconnect()
    monitor = nil
    enabled = false
    failure(error)
  }
  private func keepMonitorAlive() {
    guard enabled else { return }
    lock.lock()
    let fresh = !closed && desired && ProcessInfo.processInfo.systemUptime - lastPresentation < 0.75
    if !fresh { desired = false }
    lock.unlock()
    if !fresh {
      drain()
      return
    }
    do { try monitor?.heartbeat() } catch { fail(error) }
  }
  func stop() async {
    lock.withLock {
      closed = true
      desired = false
    }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      queue.async {
        self.heartbeat?.cancel()
        self.heartbeat = nil
        do { try self.controller?.setEnabled(false) } catch { self.failure(error) }
        do { try self.monitor?.setEnabled(false) } catch { self.failure(error) }
        self.monitor?.disconnect()
        self.monitor = nil
        self.enabled = false
        self.controller = nil
        continuation.resume()
      }
    }
  }
}
