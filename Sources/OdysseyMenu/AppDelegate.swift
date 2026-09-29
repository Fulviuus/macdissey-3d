import AppKit
import Carbon
import OdysseyCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private var statusItem: NSStatusItem!
  private let threeD = ThreeDSession()
  private var threeDStatus = "3D is off"
  private var shortcut = KeyboardShortcut.load()
  private var hotKey: HotKey?
  private var nextHotKeyID: UInt32 = 10
  private var escapeKey: HotKey?
  private var running = false
  private var changing = false
  private var stopping = false
  private var startTask: Task<Void, Never>?
  private var terminationPending = false
  private var afterStop: (() -> Void)?
  private var factoryProfile: FactoryProfile?
  private var factoryLoading = false
  private var factoryStatus = "Connect the Odyssey video and USB cables."
  private lazy var settings = SettingsWindowController(
    currentShortcut: { [weak self] in self?.shortcut ?? .standard },
    applyShortcut: { [weak self] value in try self?.changeShortcut(to: value) })

  func applicationDidFinishLaunching(_ notification: Notification) {
    if let raw = UserDefaults.standard.object(forKey: "videoLayout") as? Int,
      let layout = SBSLayout(rawValue: raw)
    {
      threeD.layout = layout
    }
    if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
      let icon = NSImage(contentsOf: iconURL)
    {
      NSApp.applicationIconImage = icon
    }
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let menuIconURL = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
      let menuIcon = NSImage(contentsOf: menuIconURL)
    {
      menuIcon.size = NSSize(width: 20, height: 20)
      menuIcon.isTemplate = true
      statusItem.button?.image = menuIcon
      statusItem.button?.imageScaling = .scaleProportionallyDown
    }
    statusItem.button?.setAccessibilityLabel("macdissey 3d")
    let menu = NSMenu()
    menu.autoenablesItems = false
    menu.delegate = self
    statusItem.menu = menu
    rebuildMenu()
    loadFactoryProfile()
    do { try changeShortcut(to: shortcut) } catch { show(error.localizedDescription) }
    threeD.failure = { [weak self] error in self?.stop3D(message: error.localizedDescription) }
    threeD.status = { [weak self] status in
      self?.threeDStatus = status
      self?.refreshStatus()
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(displayChanged),
      name: NSApplication.didChangeScreenParametersNotification, object: nil)
    for name in [
      NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
      NSWorkspace.sessionDidResignActiveNotification,
    ] {
      NSWorkspace.shared.notificationCenter.addObserver(
        self, selector: #selector(displayChanged), name: name, object: nil)
    }
    if CommandLine.arguments.contains("--settings") { showSettings() }
    if CommandLine.arguments.contains("--about") { showAbout() }
  }

  func menuWillOpen(_ menu: NSMenu) {
    loadFactoryProfile()
    rebuildMenu()
  }

  private func loadFactoryProfile() {
    guard !factoryLoading, !running, !changing else { return }
    guard
      let port = Hardware.devices().first(where: { $0.vendorID == 0x354b && $0.productID == 0x0116 }
      )?.serialPort
    else {
      factoryProfile = nil
      factoryStatus = "Connect the Odyssey video and USB cables."
      refreshStatus()
      return
    }
    factoryLoading = true
    factoryStatus = "Loading the monitor's factory calibration…"
    Task {
      do {
        factoryProfile = try await Task.detached { try FactoryProfile.retrieve(port: port) }.value
        factoryStatus = "Ready for 3D"
      } catch {
        factoryProfile = nil
        factoryStatus = "Could not load factory calibration: " + error.localizedDescription
      }
      factoryLoading = false
      refreshStatus()
    }
  }

  private func item(_ title: String, _ action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }

  private func rebuildMenu() {
    guard let menu = statusItem.menu else { return }
    menu.removeAllItems()
    menu.addItem(item("About macdissey 3d…", #selector(showAbout)))
    menu.addItem(item("Settings…", #selector(showSettings)))
    menu.addItem(.separator())
    let toggle = item(
      changing
        ? (stopping ? "Deactivating 3D…" : "Activating 3D…")
        : (running ? "Deactivate 3D" : "Activate 3D"), #selector(toggle3D))
    toggle.isEnabled = !changing
    toggle.toolTip = running ? threeDStatus : factoryStatus
    menu.addItem(toggle)
    menu.addItem(.separator())
    for layout in [SBSLayout.halfWidth, .fullWidth] {
      let option = item(layout.title, #selector(selectLayout(_:)))
      option.tag = layout.rawValue
      option.state = threeD.layout == layout ? .on : .off
      option.toolTip =
        layout == .halfWidth
        ? "Stretch each complete eye view to fill the screen."
        : "Remove the top and bottom black bars before filling the screen."
      menu.addItem(option)
    }
    menu.addItem(.separator())
    menu.addItem(item("Quit macdissey 3d", #selector(quit)))
    refreshStatus()
  }

  private func refreshStatus() {
    statusItem.button?.toolTip =
      "macdissey 3d — " + (running || changing ? threeDStatus : factoryStatus)
  }

  @objc private func selectLayout(_ sender: NSMenuItem) {
    guard let layout = SBSLayout(rawValue: sender.tag) else { return }
    threeD.layout = layout
    UserDefaults.standard.set(layout.rawValue, forKey: "videoLayout")
    rebuildMenu()
  }

  private func changeShortcut(to value: KeyboardShortcut) throws {
    guard value.isValid else {
      throw AppError.unavailable("Include Command, Option or Control in your shortcut.")
    }
    if value == shortcut, hotKey != nil { return }
    // Register first so a conflicting shortcut cannot discard the working one.
    let replacement = try HotKey(
      keyCode: value.keyCode, modifiers: value.modifiers, id: nextHotKeyID
    ) { [weak self] in
      guard let self, !self.settings.isRecording else { return }
      self.toggle3D()
    }
    nextHotKeyID &+= 1
    hotKey = replacement
    shortcut = value
    shortcut.save()
  }

  @objc private func toggle3D() {
    guard !stopping, !settings.isRecording else { return }
    if running || changing {
      stop3D()
      return
    }
    let screens = NSScreen.screens.filter(Hardware.isOdyssey)
    guard screens.count == 1, let screen = screens.first, let profile = factoryProfile else {
      show(factoryStatus)
      return
    }
    do {
      escapeKey = try HotKey(keyCode: UInt32(kVK_Escape), modifiers: 0, id: 2) { [weak self] in
        self?.stop3D()
      }
    } catch {
      show(error.localizedDescription)
      return
    }
    settings.close()
    changing = true
    threeDStatus = "Starting 3D…"
    rebuildMenu()
    startTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await threeD.start(on: screen, profile: profile)
        running = true
      } catch {
        running = false
        escapeKey = nil
        threeDStatus = "3D is off"
        if !(error is CancellationError) { show(error.localizedDescription) }
      }
      if !stopping { changing = false }
      startTask = nil
      rebuildMenu()
    }
  }

  private func stop3D(message: String? = nil) {
    guard (running || changing) && !stopping else { return }
    stopping = true
    let pendingStart = startTask
    pendingStart?.cancel()
    changing = true
    rebuildMenu()
    Task {
      await pendingStart?.value
      await threeD.stop()
      running = false
      changing = false
      stopping = false
      threeDStatus = "3D is off"
      escapeKey = nil
      rebuildMenu()
      if terminationPending {
        NSApp.reply(toApplicationShouldTerminate: true)
        return
      }
      if let message { show(message) }
      let action = afterStop
      afterStop = nil
      action?()
    }
  }

  @objc private func displayChanged(_ notification: Notification) {
    // A native-mode switch during startup generates this notification.
    if changing && notification.name == NSApplication.didChangeScreenParametersNotification {
      return
    }
    stop3D()
  }

  private func presentAfterStopping(_ action: @escaping () -> Void) {
    if running || changing {
      afterStop = action
      stop3D()
    } else {
      action()
    }
  }

  @objc private func showSettings() {
    presentAfterStopping { [weak self] in self?.settings.present() }
  }

  @objc private func showAbout() {
    presentAfterStopping { [weak self] in
      guard let self else { return }
      let version =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
      let alert = NSAlert()
      alert.messageText = "macdissey 3d"
      alert.informativeText =
        "Watch fullscreen side-by-side videos in glasses-free 3D on your Samsung Odyssey 3D monitor. The app uses the monitor’s factory calibration and tracks your eyes to align the 3D image as you move.\n\nPlay an SBS video fullscreen, choose its picture layout, then select Activate 3D or press \(self.shortcut.displayName). Press Esc to stop.\n\nVersion \(version)"
      alert.icon = NSApp.applicationIconImage
      alert.addButton(withTitle: "OK")
      NSApp.activate(ignoringOtherApps: true)
      alert.runModal()
    }
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard running || changing else { return .terminateNow }
    terminationPending = true
    afterStop = nil
    stop3D()
    return .terminateLater
  }

  @objc private func quit() { NSApp.terminate(nil) }

  private func show(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "macdissey 3d"
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
  }
}
