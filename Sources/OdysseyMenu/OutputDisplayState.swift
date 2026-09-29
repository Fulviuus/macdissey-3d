import AppKit

/// Capture-relevant output state. visibleFrame deliberately isn't included:
/// Dock/menu layout updates post the same notification as mode changes.
struct OutputDisplayState: Equatable {
  let modeID: Int32
  let pixelWidth: Int
  let pixelHeight: Int
  let frame: CGRect
  let scale: CGFloat

  @MainActor static func current(_ displayID: CGDirectDisplayID) -> OutputDisplayState? {
    guard CGDisplayIsOnline(displayID) != 0,
      let mode = CGDisplayCopyDisplayMode(displayID),
      let screen = NSScreen.screens.first(where: {
        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
          == displayID
      })
    else { return nil }
    return OutputDisplayState(
      modeID: mode.ioDisplayModeID, pixelWidth: mode.pixelWidth, pixelHeight: mode.pixelHeight,
      frame: screen.frame, scale: screen.backingScaleFactor)
  }
}
