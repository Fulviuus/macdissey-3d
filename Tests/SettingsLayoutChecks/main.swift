import AppKit

@main
enum SettingsLayoutChecks {
  @MainActor static func main() throws {

    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    var selectedLayout: SBSLayout? = .fullWidth
    var appliedLayouts: [SBSLayout] = []
    var modifiers = ShortcutModifiers.standard
    var rejectModifiers = false
    let controller = SettingsWindowController(
      currentModifiers: { modifiers },
      applyModifiers: {
        if rejectModifiers { throw ShortcutModifiersError() }
        modifiers = $0
      },
      currentLayout: { selectedLayout },
      applyLayout: {
        selectedLayout = $0
        appliedLayouts.append($0)
      })
    let window = controller.window!
    defer { window.orderOut(nil) }
    let content = window.contentView!
    content.appearance = NSAppearance(named: .aqua)
    content.wantsLayer = true
    content.layoutSubtreeIfNeeded()
    func descendants(_ view: NSView) -> [NSView] {
      [view] + view.subviews.flatMap(descendants)
    }
    let all = descendants(content)
    let scroll = all.compactMap { $0 as? NSScrollView }.first!
    let document = scroll.documentView!
    let shift = all.compactMap { $0 as? NSButton }.first { $0.title == "Shift" }!
    let option = all.compactMap { $0 as? NSButton }.first { $0.title == "Option" }!
    shift.performClick(nil)
    precondition(modifiers.displayName(for: .exit) == "⌃⌥⇧⌘Esc")
    for action in ShortcutAction.allCases {
      let label = all.compactMap { $0 as? NSTextField }.first {
        $0.accessibilityLabel() == action.title + " shortcut"
      }!
      precondition(label.stringValue == modifiers.displayName(for: action))
    }
    let beforeRejectedChange = modifiers
    rejectModifiers = true
    option.performClick(nil)
    precondition(option.state == .on, "Failed changes restore all modifier controls")
    precondition(modifiers == beforeRejectedChange)
    rejectModifiers = false
    shift.performClick(nil)
    precondition(modifiers == .standard)
    let popup = all.compactMap { $0 as? NSPopUpButton }.first!
    precondition(popup.itemTitles == ["Stretch to fill", "Remove black bars"])
    precondition(popup.selectedTag() == SBSLayout.fullWidth.rawValue)
    for layout in [SBSLayout.halfWidth, .fullWidth] {
      popup.selectItem(withTag: layout.rawValue)
      NSApp.sendAction(popup.action!, to: popup.target, from: popup)
      precondition(selectedLayout == layout)
    }
    precondition(appliedLayouts == [.halfWidth, .fullWidth])
    selectedLayout = nil
    controller.present()
    precondition(!popup.isEnabled, "Other stereo formats must not be overwritten by picture sizing")
    selectedLayout = .halfWidth
    controller.present()
    precondition(popup.isEnabled && popup.selectedTag() == SBSLayout.halfWidth.rawValue)
    func inspect(_ view: NSView) -> [String] {
      guard !view.isHidden else { return [] }
      var labels: [String] = []
      if let label = view as? NSTextField {
        let bounds = label.convert(label.bounds, to: document)
        precondition(
          document.bounds.insetBy(dx: -1, dy: -1).contains(bounds),
          "Text outside settings document: \(label.stringValue) \(bounds)")
        precondition(label.frame.height >= 13, "Text collapsed: \(label.stringValue)")
        labels.append(label.stringValue)
      }
      for child in view.subviews { labels += inspect(child) }
      return labels
    }
    content.layoutSubtreeIfNeeded()
    let labels = inspect(document)
    for expected in [
      "Settings", "Launch at login", "App shortcuts", "⌃⌥⌘3",
      "2D video conversion (Experimental)", "⌃⌥⌘1", "⌃⌥⌘2", "⌃⌥⌘4", "⌃⌥⌘5", "⌃⌥⌘6", "⌃⌥⌘7",
      "Stop any 3D mode", "⌃⌥⌘Esc", "Side-by-side picture",
    ] {
      precondition(labels.contains(expected), "Missing setting: \(expected)")
    }
    for appearance in [NSAppearance.Name.aqua, .darkAqua] {
      content.appearance = NSAppearance(named: appearance)
      content.effectiveAppearance.performAsCurrentDrawingAppearance {
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
      }
      for height: CGFloat in [650, 450] {
        window.setContentSize(NSSize(width: 540, height: height))
        content.layoutSubtreeIfNeeded()
        precondition(scroll.scrollerStyle == .legacy)
        if document.bounds.height > scroll.contentView.bounds.height {
          precondition(scroll.verticalScroller?.isHidden == false)
          precondition(scroll.verticalScroller?.isEnabled == true)
          precondition((scroll.verticalScroller?.frame.width ?? 0) >= 12)
          precondition((scroll.verticalScroller?.knobProportion ?? 1) < 1)
        }
        scroll.contentView.scroll(
          to: NSPoint(x: 0, y: document.bounds.height - scroll.contentView.bounds.height))
        scroll.reflectScrolledClipView(scroll.contentView)
        let last = all.compactMap { $0 as? NSTextField }.first {
          $0.stringValue.hasPrefix("Use the menu for Desktop 3D")
        }!
        precondition(
          scroll.documentVisibleRect.contains(last.convert(last.bounds, to: document)),
          "Bottom settings must be reachable by scrolling")
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
        window.displayIfNeeded()
        scroll.verticalScroller?.display()
        CATransaction.flush()
        let image = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
        content.cacheDisplay(in: content.bounds, to: image)
        let path = CommandLine.arguments[1] + "-\(appearance.rawValue)-\(Int(height)).png"
        try image.representation(using: .png, properties: [:])!.write(
          to: URL(fileURLWithPath: path))
      }
    }
    print(
      "PASS: Settings picture sizing, external format changes, light/dark layouts and overflow scrolling"
    )
  }
}
