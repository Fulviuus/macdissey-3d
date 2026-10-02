import AppKit
import OdysseyConversion

@main enum StereoSettingsLayoutChecks {
  @MainActor static func main() throws {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    var settings = StereoInputSettings()
    var applied: StereoInputSettings?
    let controller = StereoInputSettingsWindowController(
      current: { settings }, apply: { applied = $0 })
    for format in StereoInputFormat.allCases {
      settings.format = format
      controller.present()
      let content = controller.window!.contentView!
      content.layoutSubtreeIfNeeded()
      var apply: NSButton?
      var picker: NSPopUpButton?
      func inspect(_ view: NSView) {
        if let field = view as? NSTextField {
          let bounds = field.convert(field.bounds, to: content)
          precondition(
            content.bounds.insetBy(dx: -1, dy: -1).contains(bounds),
            "Outside window: \(field.stringValue) \(bounds)")
          precondition(field.frame.height >= 13, "Collapsed text: \(field.stringValue)")
        }
        if let button = view as? NSButton, button.title == "Apply" { apply = button }
        if let popup = view as? NSPopUpButton,
          popup.numberOfItems == StereoInputFormat.allCases.count
        {
          picker = popup
        }
        for child in view.subviews { inspect(child) }
      }
      inspect(content)
      precondition(picker?.indexOfSelectedItem == format.rawValue)
      apply!.performClick(nil)
      precondition(applied?.format == format, "Settings apply lost selected format")
    }
    settings.format = .quilt
    controller.present()
    let content = controller.window!.contentView!
    content.appearance = NSAppearance(named: .aqua)
    content.wantsLayer = true
    content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    content.layoutSubtreeIfNeeded()
    let image = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
    content.cacheDisplay(in: content.bounds, to: image)
    try image.representation(using: .png, properties: [:])!.write(
      to: URL(fileURLWithPath: CommandLine.arguments[1]))
    controller.close()
    print("PASS: all stereo options layouts, format selection and Apply")
  }
}
