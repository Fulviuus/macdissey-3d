import AppKit
import MetalKit

@MainActor final class CubeApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private var controls: NSWindow!, preview: NSWindow!, view: MTKView!, renderer: CubeRenderer!
  private let format = NSPopUpButton()
  private let pair = NSPopUpButton()
  private let isolation = NSPopUpButton()
  private let screen = NSPopUpButton()
  private let help = NSTextField(wrappingLabelWithString: "")
  private let pixels = NSTextField(wrappingLabelWithString: "")
  private let separation = NSSlider(
    value: 0.07, minValue: 0, maxValue: 0.18, target: nil, action: nil)
  private let pause = NSButton(
    checkboxWithTitle: "Pause rotation (Space)", target: nil, action: nil)
  private let markers = NSButton(
    checkboxWithTitle: "Show L/R labels and alignment cross", target: nil, action: nil)
  private let mono = NSButton(checkboxWithTitle: "Grayscale scene", target: nil, action: nil)
  private let screenGrid = NSButton(
    checkboxWithTitle: "Grid at screen depth — diagnostic (G)", target: nil, action: nil)
  private var screens: [NSScreen] = []
  private var keyMonitor: Any?

  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      let gpu = try CubeGPU()
      renderer = CubeRenderer(gpu: gpu)
      buildMenu()
      preview = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 960, height: 540),
        styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
        defer: false)
      preview.title = "Stereo Cube — Source Preview"
      preview.isReleasedWhenClosed = false
      preview.delegate = self
      preview.collectionBehavior = [.fullScreenPrimary]
      preview.colorSpace = .sRGB
      view = MTKView(frame: preview.contentView!.bounds, device: gpu.device)
      view.colorPixelFormat = .bgra8Unorm_srgb
      view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
      view.preferredFramesPerSecond = 60
      view.autoResizeDrawable = true
      view.delegate = renderer
      preview.contentView = view
      renderer.failure = { [weak self] error in self?.showError(error) }
      renderer.sizeChanged = { [weak self] size in self?.updatePixelLabel(size) }
      preview.center()
      buildControls()
      preview.makeKeyAndOrderFront(nil)
      controls.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self, event.window === self.preview else { return event }
        if event.keyCode == 5
          && event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        {
          self.screenGrid.state = self.screenGrid.state == .on ? .off : .on
          self.changed()
          return nil
        }
        if event.keyCode == 49 {
          self.pause.state = self.pause.state == .on ? .off : .on
          self.changed()
          return nil
        }
        if event.keyCode == 3
          && event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        {
          self.fullscreen()
          return nil
        }
        if event.keyCode == 53 && self.preview.styleMask.contains(.fullScreen) {
          self.preview.toggleFullScreen(nil)
          return nil
        }
        return event
      }
      NotificationCenter.default.addObserver(
        self, selector: #selector(refreshScreens),
        name: NSApplication.didChangeScreenParametersNotification, object: nil)
      changed()
    } catch { showError(error) }
  }
  private func buildMenu() {
    let menu = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Controls…", action: #selector(showControls), keyEquivalent: ",")
      .target = self
    appMenu.addItem(withTitle: "Fullscreen", action: #selector(fullscreen), keyEquivalent: "f")
      .target = self
    appMenu.addItem(.separator())
    appMenu.addItem(
      withTitle: "Quit Stereo Cube", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    appItem.submenu = appMenu
    menu.addItem(appItem)
    NSApp.mainMenu = menu
  }
  private func row(_ title: String, _ control: NSView) -> NSView {
    let label = NSTextField(labelWithString: title)
    let row = NSStackView(views: [label, NSView(), control])
    row.orientation = .horizontal
    control.setAccessibilityLabel(title)
    return row
  }
  private func buildControls() {
    controls = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 620, height: 690),
      styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    controls.title = "Stereo Cube — Controls"
    controls.isReleasedWhenClosed = false
    controls.center()
    let title = NSTextField(labelWithString: "Stereo Cube")
    title.font = .systemFont(ofSize: 24, weight: .bold)
    let intro = NSTextField(
      wrappingLabelWithString:
        "1. Choose the same Stereo Input in macdissey.\n2. Show this source fullscreen on the Odyssey.\n3. Activate macdissey with your usual 3D shortcut."
    )
    format.addItems(
      withTitles: StereoInputFormat.allCases.map(\.title) + ["Ordinary 2D (for AI Conversion)"])
    format.selectItem(at: 1)
    pair.addItems(withTitles: StereoInputSettings.anaglyphPairs)
    isolation.addItems(withTitles: [
      "Both eyes", "Left only (right black)", "Right only (left black)",
    ])
    markers.state = .on
    for control: NSControl in [
      format, pair, isolation, separation, pause, markers, mono, screenGrid,
    ] {
      control.target = self
      control.action = #selector(changed)
    }
    separation.widthAnchor.constraint(equalToConstant: 250).isActive = true
    let buttons = NSStackView()
    buttons.orientation = .horizontal
    for (name, action) in [
      ("Show Fullscreen (F)", #selector(fullscreen)), ("Reset Rotation", #selector(reset)),
    ] {
      let button = NSButton(title: name, target: self, action: action)
      button.bezelStyle = .rounded
      buttons.addArrangedSubview(button)
    }
    let tip = NSTextField(
      wrappingLabelWithString:
        "Esc stops macdissey first; press Esc again to leave fullscreen. Space pauses the cube while its source window is focused. Open Controls with ⌘,. The source is intentionally packed or distorted until macdissey decodes it."
    )
    for label in [help, pixels, tip] {
      label.font = .systemFont(ofSize: 12)
      label.textColor = .secondaryLabelColor
    }
    let stack = NSStackView(views: [
      title, intro, row("Source format", format), row("Anaglyph pair", pair),
      row("Eye isolation", isolation), row("Stereo separation", separation), pause, markers, mono,
      screenGrid,
      row("Display", screen), buttons, pixels, help, tip,
    ])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    controls.contentView!.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: controls.contentView!.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: controls.contentView!.trailingAnchor, constant: -24),
      stack.topAnchor.constraint(equalTo: controls.contentView!.topAnchor, constant: 24),
      stack.bottomAnchor.constraint(
        lessThanOrEqualTo: controls.contentView!.bottomAnchor, constant: -24),
    ])
    for child in stack.arrangedSubviews {
      child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    refreshScreens()
  }
  @objc private func refreshScreens() {
    let old = screen.indexOfSelectedItem
    screens = NSScreen.screens
    screen.removeAllItems()
    screen.addItems(withTitles: screens.map(\.localizedName))
    if let index = screens.firstIndex(where: {
      let id =
        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        ?? 0
      return CGDisplayVendorNumber(id) == 0x4c2d && CGDisplayModelNumber(id) == 0x7860
    }) {
      screen.selectItem(at: index)
    } else if screens.indices.contains(old) {
      screen.selectItem(at: old)
    }
    if view != nil { updatePixelLabel(view.drawableSize) }
  }
  @objc private func changed() {
    let index = format.indexOfSelectedItem
    renderer.parameters.format = UInt32(index)
    renderer.parameters.pair = UInt32(pair.indexOfSelectedItem)
    renderer.parameters.isolation = UInt32(isolation.indexOfSelectedItem)
    renderer.parameters.separation = Float(separation.doubleValue)
    renderer.parameters.markers = markers.state == .on ? 1 : 0
    renderer.parameters.monochrome = mono.state == .on ? 1 : 0
    renderer.parameters.screenGrid = screenGrid.state == .on ? 1 : 0
    renderer.paused = pause.state == .on
    pair.isEnabled = index == 7
    isolation.isEnabled = index != 9 && index != 16
    separation.isEnabled = index != 9 && index != 16
    if !isolation.isEnabled { renderer.parameters.isolation = 0 }
    switch index {
    case 0:
      help.stringValue =
        "Full SBS includes top/bottom bars for macdissey’s Remove black bars layout. Half SBS fills the source without bars."
    case 4...6:
      help.stringValue =
        "Use fullscreen at native 3840 × 2160 pixels. Window previews are not valid pixel-interleaving tests. Scaling or a one-pixel offset can mix/reverse eyes."
    case 7:
      help.stringValue =
        "Select the matching colour pair in macdissey Input Options. Try Monochrome or Recovered Colour. Anaglyph loses information, so recovery is approximate; cyan/magenta shares blue. Use SBS with eye isolation for optical leakage checks, since reconstruction can introduce its own signal."
    case 8:
      help.stringValue =
        "Experimental: presents alternating eyes at up to 60 frames/s. Screen capture can drop frames and lose parity. Eye isolation helps spot mixing. Pause freezes rotation but keeps alternating eyes."
    case 9:
      help.stringValue =
        "A mono cube moves sideways for Pulfrich tests. Choose Time Delay or Neutral-Density Filter in macdissey. Pausing may remove the effect; motion direction can reverse perceived depth."
    case 10:
      help.stringValue =
        "Frame packing: both eye images plus the proportional 45/2205 blanking gap. Start with bottom-eye alignment 0 in macdissey."
    case 11:
      help.stringValue =
        "Set macdissey Quilt to 5 columns × 9 rows, left view 20, right view 24. Other view pairs are available. The decoder preserves tile aspect, so letterboxing is expected."
    case 12...15:
      help.stringValue =
        "Choose the matching VR packing in macdissey. Start with yaw 0°, pitch 0°, zoom 1. The cube is in front; looking behind it in VR360 shows the surrounding background."
    case 16:
      help.stringValue =
        "Use macdissey’s Convert 2D Video to 3D (⌃⇧2). This is a mono source; depth is estimated by that feature. Desktop 3D can be tested with the preview window, but is a separate display effect."
    default:
      help.stringValue =
        "Match this format in macdissey. The cube rotates through different depths against a distant grid. Use zero stereo separation as a no-disparity reference. L/R labels identify each encoded eye."
    }
    preview.title = "Stereo Cube — " + (format.titleOfSelectedItem ?? "")
    updatePixelLabel(view.drawableSize)
  }
  private func updatePixelLabel(_ size: CGSize) {
    pixels.stringValue =
      "Source: \(Int(size.width)) × \(Int(size.height)) pixels · target 60 fps"
      + ((4...6).contains(format.indexOfSelectedItem) && size != CGSize(width: 3840, height: 2160)
        ? " · Use native 4K fullscreen for this format." : "")
  }
  @objc private func fullscreen() {
    if !preview.styleMask.contains(.fullScreen),
      screens.indices.contains(screen.indexOfSelectedItem)
    {
      let selected = screens[screen.indexOfSelectedItem]
      preview.setFrame(
        NSRect(
          x: selected.visibleFrame.midX - 480, y: selected.visibleFrame.midY - 270, width: 960,
          height: 540), display: true)
    }
    preview.makeKeyAndOrderFront(nil)
    preview.toggleFullScreen(nil)
  }
  @objc private func showControls() { controls.makeKeyAndOrderFront(nil) }
  @objc private func reset() { renderer.reset() }
  func windowWillClose(_ notification: Notification) {
    if notification.object as? NSWindow === preview { NSApp.terminate(nil) }
  }
  func applicationWillTerminate(_ notification: Notification) {
    if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
  }
  private func showError(_ error: Error) {
    let alert = NSAlert()
    alert.messageText = "Stereo Cube"
    alert.informativeText = error.localizedDescription
    alert.addButton(withTitle: "Quit")
    alert.runModal()
    NSApp.terminate(nil)
  }
}

@main enum StereoCubeMain {
  @MainActor static func main() {
    if CommandLine.arguments.contains("--self-test") {
      do {
        try CubeChecks.run()
        return
      } catch {
        fputs("Stereo Cube check failed: \(error)\n", stderr)
        exit(1)
      }
    }
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let delegate = CubeApp()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }
}
