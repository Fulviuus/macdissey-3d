import AppKit
import OdysseyConversion

/// Layout options are applied between capture sessions, so temporal history and
/// Metal resources always belong to one immutable configuration.
@MainActor
final class StereoInputSettingsWindowController: NSWindowController {
  private let current: () -> StereoInputSettings
  private let apply: (StereoInputSettings) -> Void
  private var value = StereoInputSettings()
  private var stack = NSStackView()
  private var formatPicker = NSPopUpButton()
  private var swap = NSButton()
  private var readers: [() -> Void] = []

  init(current: @escaping () -> StereoInputSettings, apply: @escaping (StereoInputSettings) -> Void)
  {
    self.current = current
    self.apply = apply
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "Stereo Input"
    window.isReleasedWhenClosed = false
    super.init(window: window)
    window.center()
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func present() {
    value = current().validated
    rebuild()
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }

  private func row(_ title: String, _ control: NSView) {
    let label = NSTextField(labelWithString: title)
    let row = NSStackView(views: [label, NSView(), control])
    row.orientation = .horizontal
    row.spacing = 12
    stack.addArrangedSubview(row)
    row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    control.setAccessibilityLabel(title)
  }
  private func help(_ text: String) {
    let label = NSTextField(wrappingLabelWithString: text)
    label.font = .systemFont(ofSize: 12)
    label.textColor = .secondaryLabelColor
    stack.addArrangedSubview(label)
    label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
  }
  private func choice(
    _ title: String, _ options: [String], _ key: WritableKeyPath<StereoInputSettings, Int>
  ) {
    let popup = NSPopUpButton()
    popup.addItems(withTitles: options)
    popup.selectItem(at: value[keyPath: key])
    row(title, popup)
    readers.append { [weak self] in self?.value[keyPath: key] = popup.indexOfSelectedItem }
  }
  private func number(
    _ title: String, value initial: Double, range: ClosedRange<Double>, integer: Bool = false,
    update: @escaping (Double) -> Void
  ) {
    let field = NSTextField(string: integer ? String(Int(initial)) : String(initial))
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.allowsFloats = !integer
    formatter.maximumFractionDigits = integer ? 0 : 2
    formatter.minimum = NSNumber(value: range.lowerBound)
    formatter.maximum = NSNumber(value: range.upperBound)
    field.formatter = formatter
    field.objectValue = NSNumber(value: initial)
    field.widthAnchor.constraint(equalToConstant: 90).isActive = true
    row(title, field)
    readers.append {
      if let n = formatter.number(from: field.stringValue), range.contains(n.doubleValue) {
        update(n.doubleValue)
      }
    }
  }
  private func int(
    _ title: String, _ key: WritableKeyPath<StereoInputSettings, Int>, _ range: ClosedRange<Int>
  ) {
    number(
      title, value: Double(value[keyPath: key]),
      range: Double(range.lowerBound)...Double(range.upperBound), integer: true
    ) { [weak self] in self?.value[keyPath: key] = Int($0) }
  }
  private func decimal(
    _ title: String, _ key: WritableKeyPath<StereoInputSettings, Double>,
    _ range: ClosedRange<Double>
  ) {
    number(title, value: value[keyPath: key], range: range) { [weak self] in
      self?.value[keyPath: key] = $0
    }
  }

  private func rebuild() {
    guard let window else { return }
    readers = []
    let content = NSView()
    window.contentView = content
    stack = NSStackView()
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    content.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
      stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
    ])
    formatPicker = NSPopUpButton()
    formatPicker.addItems(withTitles: StereoInputFormat.allCases.map(\.title))
    formatPicker.selectItem(at: value.format.rawValue)
    formatPicker.target = self
    formatPicker.action = #selector(formatChanged)
    row("Video format", formatPicker)
    swap = NSButton(checkboxWithTitle: "Swap left and right eyes", target: nil, action: nil)
    swap.state = value.swapEyes ? .on : .off
    stack.addArrangedSubview(swap)
    switch value.format {
    case .fullSBS:
      help(
        "Full-width SBS shown with top and bottom bars. Removes the central image's bars before filling the monitor. Use Half for squeezed views or a picture that already fills the display."
      )
    case .halfSBS:
      help("Stretches each complete left/right half to fill the monitor. No bars are removed.")
    case .fullTAB, .halfTAB:
      help(
        "Left eye above, right eye below. Each complete half is stretched to fill the monitor. Both variants use the same split, as in SR-Loom."
      )
    case .rowInterleaved, .columnInterleaved, .checkerboard:
      help(
        "Requires exact captured pixel alignment: no resizing, interpolation, player borders or cropping. The first row/column, or top-left checker cell, belongs to the left eye. Use Swap if reversed."
      )
    case .anaglyph:
      choice("Colour pair", StereoInputSettings.anaglyphPairs, \.anaglyphPair)
      choice("Reconstruction", StereoInputSettings.anaglyphModes, \.anaglyphMode)
      help(
        "Recovered Colour uses SR-Loom's disparity and colour recovery. Missing colour cannot always be reconstructed; quality depends on the source. Monochrome keeps each eye's luminance."
      )
    case .frameSequential:
      help(
        "Experimental: alternating left/right source frames. The first captured frame is treated as left. Screen capture may drop or repeat source frames and cannot guarantee eye order. Swap eyes if depth is reversed; reactivate to reset history."
      )
    case .pulfrich:
      let mode = NSPopUpButton()
      mode.addItems(withTitles: ["Time Delay", "Neutral-Density Filter"])
      mode.selectItem(at: value.pulfrichND ? 1 : 0)
      row("Effect", mode)
      readers.append { [weak self] in self?.value.pulfrichND = mode.indexOfSelectedItem == 1 }
      choice("Affected eye", ["Left", "Right"], \.affectedEye)
      int("Delay (captured frames, 1–8)", \.delayFrames, 1...8)
      decimal("Filter transmission (0.05–1)", \.transmission, 0.05...1)
      help(
        "Time Delay uses the frame delay; Neutral-Density Filter uses transmission. A motion-dependent effect for ordinary video, not scene-depth reconstruction. Paused video may have no depth."
      )
    case .framePacking:
      decimal("Bottom-eye alignment (pixels)", \.framePackingAlignment, -10...10)
      help(
        "Decodes an image containing two 1080-line views separated by 45 blank lines (2205 total), scaled to the captured height. This is a captured layout, not an HDMI frame-packing signal from macOS."
      )
    case .quilt:
      int("Columns (1–16)", \.quiltColumns, 1...16)
      int("Rows (1–16)", \.quiltRows, 1...16)
      int("Left-eye view index", \.quiltLeft, 0...255)
      int("Right-eye view index", \.quiltRight, 0...255)
      help(
        "Views start at 0 in the bottom-left cell, run left to right, then upward. Indices are limited to the selected grid when applied. Each tile keeps its aspect ratio."
      )
    default:
      decimal("Look left/right (degrees)", \.yaw, -180...180)
      decimal("Look up/down (degrees)", \.pitch, -90...90)
      decimal("Zoom (0.2–3)", \.zoom, 0.2...3)
      help(
        "Projects stereo equirectangular VR video onto the monitor. Zoom 1 is approximately 90° horizontally. View direction is set here; eye tracking still aligns the monitor's lenses."
      )
    }
    let buttons = NSStackView()
    buttons.orientation = .horizontal
    buttons.addArrangedSubview(NSView())
    let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
    cancel.bezelStyle = .rounded
    cancel.keyEquivalent = "\u{1b}"
    let save = NSButton(title: "Apply", target: self, action: #selector(save))
    save.bezelStyle = .rounded
    save.keyEquivalent = "\r"
    buttons.addArrangedSubview(cancel)
    buttons.addArrangedSubview(save)
    stack.addArrangedSubview(buttons)
    buttons.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    content.layoutSubtreeIfNeeded()
    window.setContentSize(NSSize(width: 560, height: stack.fittingSize.height + 48))
  }
  private func read() {
    window?.makeFirstResponder(nil)
    for reader in readers { reader() }
    value.swapEyes = swap.state == .on
  }
  @objc private func formatChanged() {
    read()
    value.format = StereoInputFormat(rawValue: formatPicker.indexOfSelectedItem) ?? .fullSBS
    rebuild()
  }
  @objc private func cancel() { close() }
  @objc private func save() {
    read()
    apply(value.validated)
    close()
  }
}
