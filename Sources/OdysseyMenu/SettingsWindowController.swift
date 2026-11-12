import AppKit
import ServiceManagement

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  private let shortcutValue = NSTextField(labelWithString: "")
  private let shortcutHelp = NSTextField(
    wrappingLabelWithString: "Start stereo video from any app, or stop the active 3D mode.")
  private let editButton = NSButton(title: "Edit Shortcut…", target: nil, action: nil)
  private let loginSwitch = NSSwitch()
  private let layoutPopup = NSPopUpButton()
  private let layoutHelp = NSTextField(wrappingLabelWithString: "")
  private let loginHelp = NSTextField(
    wrappingLabelWithString: "Open macdissey 3d in the menu bar when you log in to your Mac.")
  private let approvalButton = NSButton(
    title: "Open Login Items Settings…", target: nil, action: nil)
  private var eventMonitor: Any?
  private(set) var isRecording = false
  private let currentShortcut: () -> KeyboardShortcut
  private let showStereoInput: () -> Void
  private let showDepthModels: () -> Void
  private let applyShortcut: (KeyboardShortcut) throws -> Void
  private let currentLayout: () -> SBSLayout?
  private let applyLayout: (SBSLayout) -> Void

  init(
    currentShortcut: @escaping () -> KeyboardShortcut,
    applyShortcut: @escaping (KeyboardShortcut) throws -> Void,
    currentLayout: @escaping () -> SBSLayout? = { .fullWidth },
    applyLayout: @escaping (SBSLayout) -> Void = { _ in },
    showStereoInput: @escaping () -> Void = {},
    showDepthModels: @escaping () -> Void = {}
  ) {
    self.currentShortcut = currentShortcut
    self.applyShortcut = applyShortcut
    self.currentLayout = currentLayout
    self.applyLayout = applyLayout
    self.showStereoInput = showStereoInput
    self.showDepthModels = showDepthModels
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 540, height: 650),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "macdissey 3d Settings"
    window.isReleasedWhenClosed = false
    super.init(window: window)
    window.delegate = self
    window.center()
    buildContent()
    refreshLogin()
    refreshShortcut()
    refreshLayout()
    NotificationCenter.default.addObserver(
      self, selector: #selector(refreshLogin),
      name: NSApplication.didBecomeActiveNotification, object: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func present() {
    refreshShortcut()
    refreshLogin()
    refreshLayout()
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }

  private func buildContent() {
    guard let content = window?.contentView else { return }
    let title = NSTextField(labelWithString: "Settings")
    title.font = .systemFont(ofSize: 22, weight: .bold)
    let loginLabel = NSTextField(labelWithString: "Launch at login")
    loginLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    loginSwitch.target = self
    loginSwitch.action = #selector(toggleLogin)
    loginSwitch.setAccessibilityLabel("Launch at login")
    let spacer = NSView()
    let loginRow = NSStackView(views: [loginLabel, spacer, loginSwitch])
    loginRow.orientation = .horizontal
    let shortcutLabel = NSTextField(labelWithString: "Stereo video shortcut")
    shortcutLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    shortcutValue.font = .systemFont(ofSize: 20, weight: .medium)
    shortcutValue.setAccessibilityLabel("Stereo video shortcut")
    editButton.target = self
    editButton.action = #selector(editShortcut)
    editButton.bezelStyle = .rounded
    let shortcutRow = NSStackView(views: [shortcutValue, NSView(), editButton])
    shortcutRow.orientation = .horizontal
    for label in [loginHelp, shortcutHelp] {
      label.font = .systemFont(ofSize: 12)
      label.textColor = .secondaryLabelColor
    }
    approvalButton.target = self
    approvalButton.action = #selector(openLoginSettings)
    approvalButton.bezelStyle = .rounded
    let stereoButton = NSButton(
      title: "Stereo Input…", target: self, action: #selector(openStereoInput))
    stereoButton.bezelStyle = .rounded
    let stereoHeading = NSStackView(views: [shortcutLabel, NSView(), stereoButton])
    stereoHeading.orientation = .horizontal
    stereoHeading.alignment = .centerY
    let layoutLabel = NSTextField(labelWithString: "Side-by-side picture")
    for layout in [SBSLayout.halfWidth, .fullWidth] {
      layoutPopup.addItem(withTitle: layout.title)
      layoutPopup.lastItem?.tag = layout.rawValue
    }
    layoutPopup.target = self
    layoutPopup.action = #selector(changeLayout)
    layoutPopup.setAccessibilityLabel("Side-by-side picture")
    let layoutRow = NSStackView(views: [layoutLabel, NSView(), layoutPopup])
    layoutRow.orientation = .horizontal
    layoutRow.alignment = .centerY
    layoutHelp.font = .systemFont(ofSize: 12)
    layoutHelp.textColor = .secondaryLabelColor
    let divider = NSBox()
    divider.boxType = .separator
    let conversionTitle = NSTextField(labelWithString: "2D video conversion (Experimental)")
    conversionTitle.font = .systemFont(ofSize: 13, weight: .semibold)
    func referenceRow(_ action: String, _ keys: String) -> NSStackView {
      let label = NSTextField(labelWithString: action)
      let value = NSTextField(labelWithString: keys)
      value.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
      value.setAccessibilityLabel(action + " shortcut")
      let row = NSStackView(views: [label, NSView(), value])
      row.orientation = .horizontal
      return row
    }
    let depthButton = NSButton(
      title: "Depth Models…", target: self, action: #selector(openDepthModels))
    depthButton.bezelStyle = .rounded
    let conversionHeading = NSStackView(views: [conversionTitle, NSView(), depthButton])
    conversionHeading.orientation = .horizontal
    conversionHeading.alignment = .centerY
    let references = [
      referenceRow("Start conversion / stop 3D", "⌃⇧2"),
      referenceRow("Show Depth and Pop-Out values", "⌃⇧1"),
      referenceRow("Decrease 3D Depth", "⌃⇧3"),
      referenceRow("Increase 3D Depth", "⌃⇧4"),
      referenceRow("Decrease Pop-Out", "⌃⇧5"),
      referenceRow("Increase Pop-Out", "⌃⇧6"),
    ]
    let conversionHelp = NSTextField(
      wrappingLabelWithString:
        "Depth, Pop-Out and the values overlay work only during 2D video conversion. These shortcuts are fixed."
    )
    let exitRow = referenceRow("Stop any 3D mode", "Esc")
    let keyLegend = NSTextField(labelWithString: "⌃ Control    ⇧ Shift    ⌥ Option    ⌘ Command")
    let menuHelp = NSTextField(
      wrappingLabelWithString:
        "Use the menu for Desktop 3D and Quit. Opening the menu also stops 3D.")
    for label in [conversionHelp, keyLegend, menuHelp] {
      label.font = .systemFont(ofSize: 12)
      label.textColor = .secondaryLabelColor
    }
    let conversionDivider = NSBox()
    conversionDivider.boxType = .separator
    let exitDivider = NSBox()
    exitDivider.boxType = .separator
    let stack = NSStackView(
      views: [
        title, loginRow, loginHelp, approvalButton,
        divider, stereoHeading, shortcutRow, shortcutHelp, layoutRow, layoutHelp,
        conversionDivider, conversionHeading,
      ] + references + [conversionHelp, exitDivider, exitRow, keyLegend, menuHelp])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 10
    stack.setCustomSpacing(20, after: title)
    stack.translatesAutoresizingMaskIntoConstraints = false
    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true
    scroll.scrollerStyle = .legacy
    scroll.autohidesScrollers = true
    scroll.drawsBackground = false
    scroll.translatesAutoresizingMaskIntoConstraints = false
    content.addSubview(scroll)
    let document = FlippedSettingsView()
    document.translatesAutoresizingMaskIntoConstraints = false
    scroll.documentView = document
    document.addSubview(stack)
    for view in references + [exitRow] {
      view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    for view in [conversionHelp, menuHelp, conversionDivider, exitDivider, conversionHeading] {
      view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    NSLayoutConstraint.activate([
      scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
      scroll.topAnchor.constraint(equalTo: content.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
      document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
      stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
      stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
      stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24),
      stereoHeading.widthAnchor.constraint(equalTo: stack.widthAnchor),
      layoutRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
      layoutHelp.widthAnchor.constraint(equalTo: stack.widthAnchor),
      loginRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
      shortcutRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
      loginHelp.widthAnchor.constraint(equalTo: stack.widthAnchor),
      shortcutHelp.widthAnchor.constraint(equalTo: stack.widthAnchor),
      divider.widthAnchor.constraint(equalTo: stack.widthAnchor),
    ])
  }

  @objc private func openDepthModels() { showDepthModels() }

  @objc private func openStereoInput() { showStereoInput() }

  private func refreshLayout() {
    let layout = currentLayout()
    layoutPopup.isEnabled = layout != nil
    if let layout {
      layoutPopup.selectItem(withTag: layout.rawValue)
    } else {
      layoutPopup.select(nil)
    }
    layoutHelp.stringValue =
      layout?.help ?? "Choose a side-by-side format in Stereo Input to change picture sizing."
  }

  @objc private func changeLayout() {
    guard currentLayout() != nil,
      let layout = SBSLayout(rawValue: layoutPopup.selectedTag())
    else { return }
    applyLayout(layout)
    refreshLayout()
  }

  @objc private func refreshLogin() {
    let status = SMAppService.mainApp.status
    loginSwitch.state = status == .enabled || status == .requiresApproval ? .on : .off
    approvalButton.isHidden = status != .requiresApproval
    loginHelp.stringValue =
      status == .requiresApproval
      ? "Allow macdissey 3d in Login Items to finish enabling launch at login."
      : "Open macdissey 3d in the menu bar when you log in to your Mac."
  }

  @objc private func toggleLogin() {
    let enable = loginSwitch.state == .on
    do {
      let service = SMAppService.mainApp
      if enable {
        if service.status == .requiresApproval {
          SMAppService.openSystemSettingsLoginItems()
        } else if service.status != .enabled {
          try service.register()
        }
      } else if service.status == .enabled || service.status == .requiresApproval {
        try service.unregister()
      }
      refreshLogin()
    } catch {
      refreshLogin()
      loginHelp.stringValue = "Could not change launch at login: \(error.localizedDescription)"
    }
  }

  @objc private func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

  private func refreshShortcut() { shortcutValue.stringValue = currentShortcut().displayName }

  @objc private func editShortcut() {
    if isRecording {
      cancelRecording()
      return
    }
    isRecording = true
    editButton.title = "Cancel"
    shortcutValue.stringValue = "Press shortcut…"
    shortcutHelp.stringValue = "Hold Command, Option or Control and press a key. Esc cancels."
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, self.isRecording, event.window === self.window else { return event }
      if event.keyCode == 53 {
        self.cancelRecording()
        return nil
      }
      guard !event.isARepeat else { return nil }
      guard let shortcut = KeyboardShortcut(event: event) else {
        self.shortcutHelp.stringValue = "Include Command, Option or Control in your shortcut."
        return nil
      }
      do {
        try self.applyShortcut(shortcut)
        self.cancelRecording()
      } catch {
        self.shortcutHelp.stringValue = error.localizedDescription
      }
      return nil
    }
  }

  private func cancelRecording() {
    isRecording = false
    if let eventMonitor {
      NSEvent.removeMonitor(eventMonitor)
      self.eventMonitor = nil
    }
    editButton.title = "Edit Shortcut…"
    refreshShortcut()
    shortcutHelp.stringValue = "Start stereo video from any app, or stop the active 3D mode."
  }
  func windowWillClose(_ notification: Notification) { cancelRecording() }
  func windowDidResignKey(_ notification: Notification) { cancelRecording() }
}

private final class FlippedSettingsView: NSView { override var isFlipped: Bool { true } }
