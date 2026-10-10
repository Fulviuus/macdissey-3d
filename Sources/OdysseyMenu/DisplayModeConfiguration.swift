import AppKit

/// Copy values before reconfiguration: display IDs and mode lists can change
/// while macOS reconnects an output. Never resolve a missing display as ID zero.
struct SavedDisplayMode: Codable {
  let displayUUID: String
  let mode: DisplayModeDescription

  init?(display: CGDirectDisplayID, mode: CGDisplayMode) {
    guard let uuid = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue() else {
      return nil
    }
    displayUUID = CFUUIDCreateString(nil, uuid) as String
    self.mode = DisplayModeDescription(mode)
  }

  var displayID: CGDirectDisplayID? {
    // The watchdog starts without NSApplication. Enumerating displays first
    // opens its WindowServer connection; UUID lookup alone can assert on
    // macOS 27 before Core Graphics has initialized that connection.
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
    guard let uuid = CFUUIDCreateFromString(nil, displayUUID as CFString) else { return nil }
    let id = CGDisplayGetDisplayIDFromUUID(uuid)
    return id != 0 && CGDisplayIsOnline(id) != 0 ? id : nil
  }
}

struct DisplayModeDescription: Codable {
  let id: Int32
  let width: Int, height: Int, pixelWidth: Int, pixelHeight: Int
  let refreshRate: Double

  init(_ mode: CGDisplayMode) {
    id = mode.ioDisplayModeID
    width = mode.width
    height = mode.height
    pixelWidth = mode.pixelWidth
    pixelHeight = mode.pixelHeight
    refreshRate = mode.refreshRate
  }

  func matches(_ other: Self) -> Bool {
    width == other.width && height == other.height
      && pixelWidth == other.pixelWidth && pixelHeight == other.pixelHeight
      && abs(refreshRate - other.refreshRate) < 0.01
  }
}

/// Require consecutive matching observations so a transient reconnect state
/// cannot start a renderer with the old logical bounds or backing scale.
struct DisplayReadiness {
  private var previous: OutputDisplayState?
  private var matchingSamples = 0

  mutating func observe(_ state: OutputDisplayState?, expected: DisplayModeDescription) -> Bool {
    guard let state, state.pixelWidth == expected.pixelWidth,
      state.pixelHeight == expected.pixelHeight,
      Int((state.frame.width * state.scale).rounded()) == expected.pixelWidth,
      Int((state.frame.height * state.scale).rounded()) == expected.pixelHeight
    else {
      previous = nil
      matchingSamples = 0
      return false
    }
    matchingSamples = previous == state ? matchingSamples + 1 : 1
    previous = state
    return matchingSamples >= 3
  }
}

enum DisplayModeConfiguration {
  static func apply(_ mode: CGDisplayMode, to display: CGDirectDisplayID) -> CGError {
    guard display != 0, CGDisplayIsOnline(display) != 0 else { return .invalidConnection }
    var config: CGDisplayConfigRef?
    let begin = CGBeginDisplayConfiguration(&config)
    guard begin == .success, let config else { return begin == .success ? .failure : begin }
    let configure = CGConfigureDisplayWithDisplayMode(config, display, mode, nil)
    guard configure == .success else {
      CGCancelDisplayConfiguration(config)
      return configure
    }
    // App-only changes are discarded during the reconnect on macOS 27. A
    // session transaction survives it; normal stop and the watchdog restore
    // the saved mode. This does not modify permanent display preferences.
    return CGCompleteDisplayConfiguration(config, .forSession)
  }

  static func restore(_ saved: SavedDisplayMode) -> CGError {
    guard let id = saved.displayID,
      let modes = CGDisplayCopyAllDisplayModes(
        id, [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary) as? [CGDisplayMode]
    else { return .invalidConnection }
    let compatible = modes.filter { saved.mode.matches(DisplayModeDescription($0)) }
    guard
      let mode = compatible.first(where: { $0.ioDisplayModeID == saved.mode.id })
        ?? compatible.first
    else { return .illegalArgument }
    return apply(mode, to: id)
  }

  @MainActor static func waitUntilReady(
    _ saved: SavedDisplayMode, mode: DisplayModeDescription, timeout: TimeInterval = 8
  ) async throws -> NSScreen {
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    var readiness = DisplayReadiness()
    while ProcessInfo.processInfo.systemUptime < deadline {
      try Task.checkCancellation()
      var state: OutputDisplayState?
      var screen: NSScreen?
      if let id = saved.displayID, let active = CGDisplayCopyDisplayMode(id),
        mode.matches(DisplayModeDescription(active))
      {
        state = OutputDisplayState.current(id)
        screen = NSScreen.screens.first {
          ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
            .uint32Value == id
        }
      }
      if readiness.observe(state, expected: mode), let screen { return screen }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    throw DisplayModeError.notReady
  }

  /// Stop can run in an already-cancelled startup task. Perform restoration in
  /// an independent task so cancellation cannot skip the reconnect wait.
  @MainActor static func restoreWhenAvailable(_ saved: SavedDisplayMode) async -> Bool {
    await Task { @MainActor in
      let deadline = ProcessInfo.processInfo.systemUptime + 8
      while saved.displayID == nil && ProcessInfo.processInfo.systemUptime < deadline {
        try? await Task.sleep(nanoseconds: 100_000_000)
      }
      guard restore(saved) == .success else { return false }
      return (try? await waitUntilReady(saved, mode: saved.mode)) != nil
    }.value
  }
}

enum DisplayModeError: LocalizedError {
  case notReady
  var errorDescription: String? {
    "The Odyssey did not finish switching display modes. Check its video connection and try again."
  }
}
