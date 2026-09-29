import AppKit
import ServiceManagement

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  private let shortcutValue = NSTextField(labelWithString: "")
  private let shortcutHelp = NSTextField(
    wrappingLabelWithString: "Toggle 3D from any app. Press Esc to stop 3D.")
  private let editButton = NSButton(title: "Edit Shortcut…", target: nil, action: nil)
  private let loginSwitch = NSSwitch()
  private let loginHelp = NSTextField(
    wrappingLabelWithString: "Open macdissey 3d in the menu bar when you log in to your Mac.")
  private let approvalButton = NSButton(
    title: "Open Login Items Settings…", target: nil, action: nil)
  private var eventMonitor: Any?
  private(set) var isRecording = false
  private let currentShortcut: () -> KeyboardShortcut
  private let applyShortcut: (KeyboardShortcut) throws -> Void

  init(
    currentShortcut: @escaping () -> KeyboardShortcut,
    applyShortcut: @escaping (KeyboardShortcut) throws -> Void
  ) {
    self.currentShortcut = currentShortcut
    self.applyShortcut = applyShortcut
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "macdissey 3d Settings"
    window.isReleasedWhenClosed = false
    super.init(window: window)
    window.delegate = self
    window.center()
    buildContent()
    refreshLogin()
    refreshShortcut()
    NotificationCenter.default.addObserver(
      self, selector: #selector(refreshLogin),
      name: NSApplication.didBecomeActiveNotification, object: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func present() {
    refreshShortcut()
    refreshLogin()
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
    let shortcutLabel = NSTextField(labelWithString: "Current shortcut")
    shortcutLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    shortcutValue.font = .systemFont(ofSize: 20, weight: .medium)
    shortcutValue.setAccessibilityLabel("Current shortcut")
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
    let divider = NSBox()
    divider.boxType = .separator
    let stack = NSStackView(views: [
      title, loginRow, loginHelp, approvalButton,
      divider, shortcutLabel, shortcutRow, shortcutHelp,
    ])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    stack.setCustomSpacing(20, after: title)
    stack.translatesAutoresizingMaskIntoConstraints = false
    content.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
      stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24),
      loginRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
      shortcutRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
      loginHelp.widthAnchor.constraint(equalTo: stack.widthAnchor),
      shortcutHelp.widthAnchor.constraint(equalTo: stack.widthAnchor),
      divider.widthAnchor.constraint(equalTo: stack.widthAnchor),
    ])
  }

  @objc private func refreshLogin() {
    let status = SMAppService.mainApp.status
    loginSwitch.state = status == .enabled || status == .requiresApproval ? .on : .off
    approvalButton.isHidden = status != .requiresApproval
    window?.setContentSize(NSSize(width: 460, height: status == .requiresApproval ? 400 : 360))
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
    shortcutHelp.stringValue = "Toggle 3D from any app. Press Esc to stop 3D."
  }
  func windowWillClose(_ notification: Notification) { cancelRecording() }
  func windowDidResignKey(_ notification: Notification) { cancelRecording() }
}
