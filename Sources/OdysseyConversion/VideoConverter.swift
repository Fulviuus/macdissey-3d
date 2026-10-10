import CoreVideo
import Foundation

/// Keeps at most one waiting input, so inference cannot build a queue of stale
/// video frames. All model and GPU work runs off the application/capture queues.
public final class VideoConverter: @unchecked Sendable {
  private let queue = DispatchQueue(label: "macdissey.conversion", qos: .userInitiated)
  private let lock = NSLock()
  private let engine: ConversionEngine
  private var pending: CVPixelBuffer?
  private var adjustment = ConversionAdjustment()
  private var hudUntil = Date.distantPast
  private var refresh = false, working = false, stopped = false
  private var completed = 0
  private var recycled = false
  private let deliver: (CVPixelBuffer) -> Void
  private let failure: (Error) -> Void

  public var convertedFrames: Int {
    lock.lock()
    defer { lock.unlock() }
    return completed
  }

  public init(
    assets: URL, depthModel: DepthModelConfiguration? = nil,
    deliver: @escaping (CVPixelBuffer) -> Void, failure: @escaping (Error) -> Void
  ) throws {
    engine = try ConversionEngine(assets: assets, depthModel: depthModel)
    self.deliver = deliver
    self.failure = failure
    engine.depthWorker?.didComplete = { [weak self] in self?.refreshDepth() }
  }
  public func submit(_ pixel: CVPixelBuffer) {
    lock.lock()
    guard !stopped else {
      lock.unlock()
      return
    }
    pending = pixel
    scheduleLocked()
    lock.unlock()
  }
  public func adjust(depth: Int = 0, popOut: Int = 0) {
    lock.lock()
    guard !stopped else {
      lock.unlock()
      return
    }
    adjustment.changeDepth(depth)
    adjustment.changePopOut(popOut)
    hudUntil = Date().addingTimeInterval(1.4)
    refresh = true
    scheduleLocked()
    lock.unlock()
    queue.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      guard let self else { return }
      self.lock.lock()
      if !self.stopped && Date() >= self.hudUntil {
        self.refresh = true
        self.scheduleLocked()
      }
      self.lock.unlock()
    }
  }
  public func stop() async {
    cancelPending()
    await engine.depthWorker?.stop()
    await withCheckedContinuation { continuation in
      queue.async { [self] in
        if !recycled {
          engine.videoDepth?.recycle()
          recycled = true
        }
        continuation.resume()
      }
    }
  }
  private func refreshDepth() {
    lock.lock()
    if !stopped {
      refresh = true
      scheduleLocked()
    }
    lock.unlock()
  }
  private func cancelPending() {
    lock.lock()
    stopped = true
    pending = nil
    refresh = false
    lock.unlock()
  }
  private func scheduleLocked() {
    guard !working else { return }
    working = true
    queue.async { [weak self] in self?.drain() }
  }
  private func drain() {
    while true {
      lock.lock()
      let consumeInput = engine.depthWorker?.canAdvance ?? true
      guard !stopped && ((consumeInput && pending != nil) || refresh) else {
        working = false
        lock.unlock()
        return
      }
      let pixel = consumeInput ? pending : nil
      let value = adjustment
      let hud = Date() < hudUntil
      if consumeInput { pending = nil }
      refresh = false
      lock.unlock()
      do {
        let result = try autoreleasepool {
          try engine.process(pixel, adjustment: value, showHUD: hud)
        }
        lock.lock()
        let cancelled = stopped
        if !cancelled && result != nil { completed += 1 }
        lock.unlock()
        if !cancelled, let result { deliver(result) }
      } catch {
        lock.lock()
        let notify = !stopped
        stopped = true
        pending = nil
        working = false
        lock.unlock()
        if notify { failure(error) }
        return
      }
    }
  }
}
