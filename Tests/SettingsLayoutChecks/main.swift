import AppKit

@main
enum SettingsLayoutChecks {
  @MainActor static func main() throws {

    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    let controller = SettingsWindowController(
      currentShortcut: { .standard }, applyShortcut: { _ in })
    let window = controller.window!
    let content = window.contentView!
    content.appearance = NSAppearance(named: .aqua)
    content.wantsLayer = true
    content.layer?.backgroundColor = NSColor(calibratedWhite: 0.95, alpha: 1).cgColor
    content.layoutSubtreeIfNeeded()
    func inspect(_ view: NSView) -> [String] {
      guard !view.isHidden else { return [] }
      var labels: [String] = []
      if let label = view as? NSTextField {
        let bounds = label.convert(label.bounds, to: content)
        precondition(
          content.bounds.insetBy(dx: -1, dy: -1).contains(bounds),
          "Text outside window: \(label.stringValue) \(bounds)")
        precondition(label.frame.height >= 13, "Text collapsed: \(label.stringValue)")
        labels.append(label.stringValue)
      }
      for child in view.subviews { labels += inspect(child) }
      return labels
    }
    let labels = inspect(content)
    for expected in [
      "Settings", "Launch at login", "SBS video shortcut", "⌃⌥⌘3",
      "2D video conversion (Experimental)", "⌃⇧1", "⌃⇧2", "⌃⇧3", "⌃⇧4", "⌃⇧5", "⌃⇧6",
      "Stop any 3D mode", "Esc",
    ] {
      precondition(labels.contains(expected), "Missing setting: \(expected)")
    }
    let image = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
    content.cacheDisplay(in: content.bounds, to: image)
    try image.representation(using: .png, properties: [:])!.write(
      to: URL(fileURLWithPath: CommandLine.arguments[1]))
    print("PASS: native Settings window layout; visible labels stay within window bounds")
  }
}
