import AppKit
import OdysseyConversion

@main enum DepthModelsLayoutChecks {
  @MainActor static func main() async throws {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let suite = "DepthModelsLayoutChecks-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let bundled = root.appendingPathComponent("bundle")
    for phase in ["first", "stream"] {
      let folder = bundled.appendingPathComponent(phase + ".mlmodelc")
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try Data([1]).write(to: folder.appendingPathComponent("coremldata.bin"))
    }
    let library = DepthModelLibrary(root: root, defaults: defaults, bundled: bundled)
    let controller = DepthModelsWindowController(library: library, performChange: { $0() })
    let window = controller.window!
    let content = window.contentView!
    window.orderFront(nil)
    defer { window.orderOut(nil) }
    func descendants(_ view: NSView) -> [NSView] {
      [view] + view.subviews.flatMap(descendants)
    }
    let all = descendants(content)
    let buttons = all.compactMap { $0 as? NSButton }
    precondition(buttons.count == 2, "Only two bundled model selection buttons")
    precondition(
      buttons.filter { $0.title == "Use Model" }.count == 1, "Small available without downloading")
    let use = buttons.first { $0.accessibilityLabel() == "Use Model · Video Depth Anything Small" }!
    use.performClick(nil)
    precondition(library.selected == .videoSmall, "Select bundled Small immediately")
    let samsung = buttons.first { $0.accessibilityLabel() == "Use Model · Samsung · Default" }!
    samsung.performClick(nil)
    precondition(library.selected == .samsung, "Return to default Samsung")
    for appearance in [NSAppearance.Name.aqua, .darkAqua] {
      content.appearance = NSAppearance(named: appearance)
      for size in [NSSize(width: 640, height: 240), NSSize(width: 640, height: 380)] {
        window.setContentSize(size)
        content.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        for view in all { view.displayIfNeeded() }
        CATransaction.flush()
        let scroll = all.compactMap { $0 as? NSScrollView }.first!
        precondition(scroll.scrollerStyle == .legacy, "Overflow scrollbar remains visible")
        let document = scroll.documentView!
        if document.bounds.height > scroll.contentView.bounds.height {
          precondition(scroll.verticalScroller?.isHidden == false, "Overflow has a scrollbar")
          precondition(scroll.verticalScroller?.isEnabled == true, "Overflow scrollbar is enabled")
          precondition(
            (scroll.verticalScroller?.frame.width ?? 0) >= 12, "Scrollbar has visible width")
          precondition(
            (scroll.verticalScroller?.knobProportion ?? 1) < 1, "Scrollbar represents overflow")
        }
        scroll.contentView.scroll(
          to: NSPoint(x: 0, y: document.bounds.height - scroll.contentView.bounds.height))
        scroll.reflectScrolledClipView(scroll.contentView)
        let last = all.compactMap { $0 as? NSTextField }.first {
          $0.stringValue == DepthModel.videoSmall.title
        }!
        precondition(
          scroll.documentVisibleRect.contains(last.convert(last.bounds, to: document)),
          "Last model is reachable by scrolling")
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
        window.displayIfNeeded()
        scroll.verticalScroller?.display()
        CATransaction.flush()
        for label in all.compactMap({ $0 as? NSTextField }) where !label.isHidden {
          precondition(label.frame.height >= 12, "Collapsed label: \(label.stringValue)")
          if let row = label.superview?.superview,
            String(describing: type(of: row)) == "DepthModelRow"
          {
            precondition(
              row.bounds.insetBy(dx: -1, dy: -1).contains(label.convert(label.bounds, to: row)),
              "Text outside card: \(label.stringValue)")
          } else {
            precondition(
              content.bounds.insetBy(dx: -1, dy: -1).contains(
                label.convert(label.bounds, to: content)),
              "Text outside window: \(label.stringValue)")
          }
        }
        let image = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
        content.cacheDisplay(in: content.bounds, to: image)
        let path = CommandLine.arguments[1] + "-\(appearance.rawValue)-\(Int(size.height)).png"
        try image.representation(using: .png, properties: [:])!.write(
          to: URL(fileURLWithPath: path))
      }
    }
    print(
      "PASS compact bundled model selector: immediate selection and light/dark layouts with overflow scrolling"
    )
  }
}
