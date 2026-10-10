import AppKit
import OdysseyConversion

@MainActor
final class DepthModelsWindowController: NSWindowController {
  private let library: DepthModelLibrary
  private let performChange: (@escaping () -> Void) -> Void
  private var rows: [DepthModel: DepthModelRow] = [:]
  private let selection = NSTextField(labelWithString: "")
  private let notice = NSTextField(wrappingLabelWithString: "")

  init(library: DepthModelLibrary, performChange: @escaping (@escaping () -> Void) -> Void) {
    self.library = library
    self.performChange = performChange
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 640, height: 380),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.title = "Depth Models"
    window.contentView = DepthModelsBackgroundView(frame: window.contentView!.bounds)
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 640, height: 280)
    super.init(window: window)
    window.center()
    buildContent()
    library.didChange = { [weak self] in self?.refresh() }
    refresh()
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func present() {
    refresh()
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }

  private func buildContent() {
    guard let content = window?.contentView else { return }
    let heading = NSTextField(labelWithString: "Choose your depth model")
    heading.font = .systemFont(ofSize: 20, weight: .bold)
    let description = NSTextField(
      wrappingLabelWithString:
        "Everything runs locally on your Mac."
    )
    description.textColor = .secondaryLabelColor
    selection.font = .systemFont(ofSize: 13, weight: .semibold)
    let header = NSStackView(views: [heading, description, selection])
    header.orientation = .vertical
    header.alignment = .leading
    header.spacing = 8
    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true
    scroll.scrollerStyle = .legacy
    scroll.autohidesScrollers = true
    scroll.drawsBackground = false
    let document = FlippedDepthView()
    document.translatesAutoresizingMaskIntoConstraints = false
    scroll.documentView = document
    let stack = NSStackView()
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false
    document.addSubview(stack)
    for model in DepthModel.allCases {
      let row = DepthModelRow(model: model)
      row.action = { [weak self] action in self?.handle(action, model: model) }
      rows[model] = row
      stack.addArrangedSubview(row)
      row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    notice.font = .systemFont(ofSize: 12)
    notice.textColor = .secondaryLabelColor
    notice.stringValue =
      "Changing models stops 3D. Restart conversion to use your selection. Small prepares in the background on first use."
    for view in [header, scroll, notice] {
      view.translatesAutoresizingMaskIntoConstraints = false
      content.addSubview(view)
    }
    NSLayoutConstraint.activate([
      header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
      header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
      header.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
      description.widthAnchor.constraint(equalTo: header.widthAnchor),
      scroll.leadingAnchor.constraint(equalTo: header.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: header.trailingAnchor),
      scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 14),
      scroll.bottomAnchor.constraint(equalTo: notice.topAnchor, constant: -16),
      notice.leadingAnchor.constraint(equalTo: header.leadingAnchor),
      notice.trailingAnchor.constraint(equalTo: header.trailingAnchor),
      notice.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
      document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
      stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -4),
      stack.topAnchor.constraint(equalTo: document.topAnchor),
      stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
    ])
  }
  private func refresh() {
    selection.stringValue = "Selected: " + library.selected.title
    for (model, row) in rows {
      row.refresh(
        installed: library.isInstalled(model), selected: library.selected == model,
        error: library.selected == model ? library.preparationError : nil,
        preparing: library.preparingSelection == model)
    }
  }
  private func handle(_ action: DepthModelRow.Action, model: DepthModel) {
    performChange { [weak self] in
      guard let self else { return }
      do {
        try self.library.select(model)
        self.notice.stringValue =
          "\(model.title) will be used the next time you start 2D video conversion."
      } catch { self.notice.stringValue = error.localizedDescription }
      self.refresh()
    }
  }
}

private final class FlippedDepthView: NSView { override var isFlipped: Bool { true } }

private final class DepthModelsBackgroundView: NSView {
  override func draw(_ dirtyRect: NSRect) {
    NSColor.windowBackgroundColor.setFill()
    dirtyRect.fill()
  }
}

@MainActor
private final class DepthModelRow: NSView {
  enum Action { case select }
  var action: ((Action) -> Void)?
  private let model: DepthModel
  private let title: NSTextField
  private let detail: NSTextField
  private let status = NSTextField(wrappingLabelWithString: "")
  private let progress = NSProgressIndicator()
  private let primary = NSButton()
  private var isSelected = false

  init(model: DepthModel) {
    self.model = model
    title = NSTextField(labelWithString: model.title)
    detail = NSTextField(wrappingLabelWithString: model.detail)
    super.init(frame: .zero)
    wantsLayer = true
    layer?.cornerRadius = 10
    title.font = .systemFont(ofSize: 13, weight: .semibold)
    detail.font = .systemFont(ofSize: 12)
    detail.textColor = .secondaryLabelColor
    status.font = .systemFont(ofSize: 11)
    status.textColor = .secondaryLabelColor
    status.maximumNumberOfLines = 2
    primary.bezelStyle = .rounded
    primary.target = self
    primary.action = #selector(primaryClicked)
    progress.style = .bar
    progress.minValue = 0
    progress.maxValue = 1
    progress.isIndeterminate = false
    let text = NSStackView(views: [title, detail, status, progress])
    text.orientation = .vertical
    text.alignment = .leading
    text.spacing = 4
    let buttons = NSStackView(views: [primary])
    buttons.orientation = .vertical
    buttons.spacing = 4
    for view in [text, buttons] {
      view.translatesAutoresizingMaskIntoConstraints = false
      addSubview(view)
    }
    NSLayoutConstraint.activate([
      heightAnchor.constraint(equalToConstant: 84),
      text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
      text.topAnchor.constraint(equalTo: topAnchor, constant: 9),
      text.trailingAnchor.constraint(equalTo: buttons.leadingAnchor, constant: -12),
      buttons.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
      buttons.centerYAnchor.constraint(equalTo: centerYAnchor),
      buttons.widthAnchor.constraint(equalToConstant: 124),
      primary.widthAnchor.constraint(equalTo: buttons.widthAnchor),
      detail.widthAnchor.constraint(equalTo: text.widthAnchor),
      status.widthAnchor.constraint(equalTo: text.widthAnchor),
      progress.widthAnchor.constraint(equalTo: text.widthAnchor),
    ])
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateColors()
  }
  private func updateColors() {
    effectiveAppearance.performAsCurrentDrawingAppearance {
      layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
      layer?.borderWidth = isSelected ? 1.5 : 1
      layer?.borderColor =
        (isSelected ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
    }
  }
  func refresh(installed: Bool, selected: Bool, error: String?, preparing: Bool) {
    isSelected = selected
    updateColors()
    progress.stopAnimation(nil)
    progress.isHidden = true
    primary.title = selected ? "✓ Selected" : "Use Model"
    primary.isEnabled = installed && !selected
    status.textColor = error == nil ? .secondaryLabelColor : .systemRed
    status.stringValue =
      error
      ?? (installed ? "" : "Bundled model missing · Reinstall the app")
    if preparing {
      status.stringValue = "Preparing in background…"
      progress.isHidden = false
      progress.isIndeterminate = true
      progress.startAnimation(nil)
    }
    status.isHidden = status.stringValue.isEmpty
    primary.setAccessibilityLabel(primary.title + " · " + model.title)
    status.toolTip = status.stringValue
  }
  @objc private func primaryClicked() { action?(.select) }
}
