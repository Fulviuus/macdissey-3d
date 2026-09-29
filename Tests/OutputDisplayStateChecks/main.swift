import AppKit

@main enum OutputDisplayStateChecks {
  @MainActor static func main() {
    _ = NSApplication.shared
    let frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let expected = OutputDisplayState(
      modeID: 86, pixelWidth: 3840, pixelHeight: 2160, frame: frame, scale: 2)
    for candidate in [
      OutputDisplayState(modeID: 87, pixelWidth: 3840, pixelHeight: 2160, frame: frame, scale: 2),
      OutputDisplayState(modeID: 86, pixelWidth: 1920, pixelHeight: 1080, frame: frame, scale: 1),
      OutputDisplayState(
        modeID: 86, pixelWidth: 3840, pixelHeight: 2160,
        frame: frame.offsetBy(dx: 100, dy: 0), scale: 2),
      OutputDisplayState(modeID: 86, pixelWidth: 3840, pixelHeight: 2160, frame: frame, scale: 1),
    ] {
      precondition(expected != candidate, "A real output change must be detected")
    }
    precondition(OutputDisplayState.current(CGDirectDisplayID.max) == nil)
    let id = CGMainDisplayID()
    let before = OutputDisplayState.current(id)
    precondition(before != nil)
    for _ in 0..<20 {
      NotificationCenter.default.post(
        name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
      precondition(before == OutputDisplayState.current(id), "Layout notifications changed output")
    }
    print("PASS: unchanged display notifications, mode/scale/position changes and missing display")
  }
}
