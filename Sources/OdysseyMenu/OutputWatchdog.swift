import AppKit
import Darwin
import Foundation

/// A separate process can release the lens state and display mode after a
/// crash. Its pipe is private to its parent; it never accepts enable commands.
enum OutputWatchdog {
  static func runIfRequested() -> Bool {
    let args = CommandLine.arguments
    guard args.count == 5, args[1] == "--output-watchdog",
      let parent = Int32(args[2]), parent == getppid(),
      let saved = try? JSONDecoder().decode(SavedDisplayMode.self, from: Data(args[4].utf8))
    else { return false }
    fputs(
      "Watchdog: armed for \(saved.mode.width)×\(saved.mode.height) logical, \(saved.mode.pixelWidth)×\(saved.mode.pixelHeight) pixels\n",
      stderr)
    var lastHeartbeat = ProcessInfo.processInfo.systemUptime
    while true {
      var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
      let status = poll(&descriptor, 1, 250)
      if status > 0 {
        var bytes = [UInt8](repeating: 0, count: 64)
        let count = Darwin.read(STDIN_FILENO, &bytes, bytes.count)
        if count <= 0 { break }
        if bytes.prefix(count).contains(88) { return true }
        if bytes.prefix(count).contains(72) { lastHeartbeat = ProcessInfo.processInfo.systemUptime }
      }
      if ProcessInfo.processInfo.systemUptime - lastHeartbeat > 3 { break }
    }
    fputs("Watchdog: recovering after heartbeat stopped\n", stderr)
    // A hung parent still owns the exclusive serial port. Terminate only
    // the process that spawned this helper, then regain that same device.
    if kill(parent, 0) == 0 {
      kill(parent, SIGTERM)
      Thread.sleep(forTimeInterval: 0.2)
      if kill(parent, 0) == 0 { kill(parent, SIGKILL) }
    }
    for _ in 0..<12 {
      do {
        let controller = try LensController(port: args[3])
        try controller.setEnabled(false)
        fputs("Watchdog: lenses confirmed off\n", stderr)
        break
      } catch { Thread.sleep(forTimeInterval: 0.25) }
    }
    // The display can temporarily vanish during a mode change. Re-resolve
    // only this physical display and restore the session configuration too.
    let deadline = ProcessInfo.processInfo.systemUptime + 8
    while saved.displayID == nil && ProcessInfo.processInfo.systemUptime < deadline {
      Thread.sleep(forTimeInterval: 0.1)
    }
    let result = DisplayModeConfiguration.restore(saved)
    fputs("Watchdog: display restore status \(result.rawValue)\n", stderr)
    return true
  }
}

@MainActor final class OutputWatchdogClient {
  private let process = Process(), pipe = Pipe()
  private var timer: Timer?
  func start(port: String, savedMode: SavedDisplayMode) throws {
    process.executableURL = Bundle.main.executableURL
    process.arguments = [
      "--output-watchdog", String(getpid()), port,
      String(decoding: try JSONEncoder().encode(savedMode), as: UTF8.self),
    ]
    process.standardInput = pipe
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.standardError
    try process.run()
    heartbeat()
    let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
      // This timer is installed only on the main run loop below.
      MainActor.assumeIsolated { self?.heartbeat() }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }
  private func heartbeat() { try? pipe.fileHandleForWriting.write(contentsOf: Data([72])) }
  func stop() {
    timer?.invalidate()
    timer = nil
    try? pipe.fileHandleForWriting.write(contentsOf: Data([88]))
    try? pipe.fileHandleForWriting.close()
  }
}
