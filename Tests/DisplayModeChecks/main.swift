import AppKit

@main enum DisplayModeChecks {
  @MainActor static func main() async throws {
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--cold-display-lookup" {
      // Exercise the watchdog's fresh process, without initializing AppKit.
      let saved = try JSONDecoder().decode(
        SavedDisplayMode.self, from: Data(CommandLine.arguments[2].utf8))
      guard let id = saved.displayID else { preconditionFailure("Connected display not resolved") }
      print(id)
      return
    }
    _ = NSApplication.shared
    let id = CGMainDisplayID()
    let mode = CGDisplayCopyDisplayMode(id)!
    let expected = DisplayModeDescription(mode)
    let frame = CGRect(x: 0, y: 0, width: expected.width, height: expected.height)
    let scale = CGFloat(expected.pixelWidth) / CGFloat(expected.width)
    let ready = OutputDisplayState(
      modeID: expected.id, pixelWidth: expected.pixelWidth, pixelHeight: expected.pixelHeight,
      frame: frame, scale: scale)
    let staleBounds = OutputDisplayState(
      modeID: expected.id, pixelWidth: expected.pixelWidth, pixelHeight: expected.pixelHeight,
      frame: CGRect(x: 0, y: 0, width: frame.width + 100, height: frame.height), scale: scale)
    let stalePixels = OutputDisplayState(
      modeID: expected.id, pixelWidth: expected.pixelWidth * 2,
      pixelHeight: expected.pixelHeight * 2, frame: frame, scale: scale)
    var readiness = DisplayReadiness()
    for state in [nil, staleBounds, stalePixels, nil] {
      precondition(!readiness.observe(state, expected: expected))
    }
    precondition(!readiness.observe(ready, expected: expected))
    precondition(!readiness.observe(ready, expected: expected))
    // A disconnect during settling must restart the readiness period.
    precondition(!readiness.observe(nil, expected: expected))
    precondition(!readiness.observe(ready, expected: expected))
    precondition(!readiness.observe(ready, expected: expected))
    precondition(readiness.observe(ready, expected: expected))
    let moved = OutputDisplayState(
      modeID: expected.id, pixelWidth: expected.pixelWidth, pixelHeight: expected.pixelHeight,
      frame: frame.offsetBy(dx: 100, dy: 0), scale: scale)
    precondition(!readiness.observe(moved, expected: expected))
    precondition(!readiness.observe(moved, expected: expected))
    precondition(readiness.observe(moved, expected: expected))

    let saved = SavedDisplayMode(display: id, mode: mode)!
    let encoded = try JSONEncoder().encode(saved)
    let decoded = try JSONDecoder().decode(SavedDisplayMode.self, from: encoded)
    precondition(decoded.displayID == id && decoded.mode.matches(expected))
    let child = Process()
    let output = Pipe()
    child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    child.arguments = ["--cold-display-lookup", String(decoding: encoded, as: UTF8.self)]
    child.standardOutput = output
    try child.run()
    child.waitUntilExit()
    precondition(child.terminationReason == .exit && child.terminationStatus == 0)
    let childID = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    precondition(childID == String(id))
    // A missing monitor must never resolve as the main display (ID zero).
    var missingJSON = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
    missingJSON["displayUUID"] = UUID().uuidString
    let missing = try JSONDecoder().decode(
      SavedDisplayMode.self, from: JSONSerialization.data(withJSONObject: missingJSON))
    precondition(missing.displayID == nil)
    precondition(DisplayModeConfiguration.restore(missing) == .invalidConnection)
    do {
      _ = try await DisplayModeConfiguration.waitUntilReady(missing, mode: expected, timeout: 0.01)
      preconditionFailure("A missing monitor must time out")
    } catch DisplayModeError.notReady {}
    let task = Task { @MainActor in
      _ = try await DisplayModeConfiguration.waitUntilReady(missing, mode: expected)
    }
    task.cancel()
    do {
      try await task.value
      preconditionFailure("Cancelling startup must cancel the display wait")
    } catch is CancellationError {}
    print(
      "PASS: display reconnect settling, stale bounds, mode snapshot, missing display, timeout and cancellation"
    )
  }
}
