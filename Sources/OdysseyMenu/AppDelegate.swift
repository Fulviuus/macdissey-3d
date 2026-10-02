import AppKit
import Carbon
import OSLog
import OdysseyConversion
import OdysseyCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private let logger = Logger(subsystem: "local.odyssey3d.research", category: "session")
  private var statusItem: NSStatusItem!
  private let threeD = ThreeDSession()
  private var threeDStatus = "3D is off"
  private var shortcut = KeyboardShortcut.load()
  private var stereoInput = StereoInputSettings.load()
  private lazy var stereoOptions = StereoInputSettingsWindowController(
    current: { [weak self] in self?.stereoInput ?? StereoInputSettings() },
    apply: { [weak self] value in self?.applyStereoInput(value) })
  private var hotKey: HotKey?
  private var nextHotKeyID: UInt32 = 10
  private var escapeKey: HotKey?
  private var conversionKey: HotKey?
  private var conversionControls: [HotKey] = []
  private var running = false
  private var changing = false
  private var stopping = false
  private var startTask: Task<Void, Never>?
  private var terminationPending = false
  private var afterStop: (() -> Void)?
  private let alerts = AlertPresenter()
  private var factoryProfile: FactoryProfile?
  private var factoryLoading = false
  private var factoryStatus = "Connect the Odyssey video and USB cables."
  private lazy var settings = SettingsWindowController(
    currentShortcut: { [weak self] in self?.shortcut ?? .standard },
    applyShortcut: { [weak self] value in try self?.changeShortcut(to: value) },
    showStereoInput: { [weak self] in self?.showStereoOptions() })

  func applicationDidFinishLaunching(_ notification: Notification) {
    threeD.stereoSettings = stereoInput
    threeD.layout = stereoInput.format == .fullSBS ? .fullWidth : .halfWidth
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
    do {
      conversionKey = try HotKey(
        keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(controlKey | shiftKey), id: 400
      ) { [weak self] in
        self?.toggleConversion()
      }
    } catch {
      logger.error(
        "2D conversion shortcut unavailable: \(error.localizedDescription, privacy: .public)")
    }
    threeD.failure = { [weak self] error in
      self?.stop3D(message: error.localizedDescription, reason: "pipeline error")
    }
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
    if CommandLine.arguments.contains("--stereo-options") { showStereoOptions() }
    if CommandLine.arguments.contains("--settings") { showSettings() }
    if CommandLine.arguments.contains("--about") { showAbout() }
  }

  func menuWillOpen(_ menu: NSMenu) {
    if running || changing {
      // Our own windows are excluded from capture, so this menu would be
      // invisible underneath the 3D overlay. Exit tracking before awaiting
      // shutdown, then reopen it after the real desktop is visible.
      afterStop = { [weak self] in self?.statusItem.button?.performClick(nil) }
      DispatchQueue.main.async { [weak self, weak menu] in
        menu?.cancelTracking()
        self?.stop3D()
      }
      return
    }
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
    let conversion = item("Convert 2D Video to 3D (Experimental)", #selector(toggleConversion))
    conversion.isEnabled = !running && !changing
    conversion.toolTip = "Control–Shift–2. Converts a fullscreen ordinary video; Escape exits."
    menu.addItem(conversion)
    let desktop = item("Try Desktop 3D (Experimental)", #selector(toggleDesktop))
    desktop.isEnabled = !running && !changing
    desktop.toolTip =
      "An experimental depth effect that puts the background behind the front window. Escape exits."
    menu.addItem(desktop)
    menu.addItem(.separator())
    let inputMenu = NSMenu()
    inputMenu.autoenablesItems = false
    for format in StereoInputFormat.allCases {
      let option = item(format.title, #selector(selectStereoInput(_:)))
      option.tag = format.rawValue
      option.state = stereoInput.format == format ? .on : .off
      inputMenu.addItem(option)
    }
    inputMenu.addItem(.separator())
    let swap = item("Swap Left and Right Eyes", #selector(swapStereoEyes))
    swap.state = stereoInput.swapEyes ? .on : .off
    inputMenu.addItem(swap)
    inputMenu.addItem(item("Input Options…", #selector(showStereoOptions)))
    let input = NSMenuItem(
      title: "Stereo Input: " + stereoInput.format.title, action: nil, keyEquivalent: "")
    input.submenu = inputMenu
    menu.addItem(input)
    for layout in [SBSLayout.halfWidth, .fullWidth] {
      let option = item(layout.title, #selector(selectLayout(_:)))
      option.tag = layout.rawValue
      option.state = stereoInput.format.isSBS && threeD.layout == layout ? .on : .off
      option.isEnabled = stereoInput.format.isSBS && !running && !changing
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
    var value = stereoInput
    value.format = layout == .fullWidth ? .fullSBS : .halfSBS
    applyStereoInput(value)
  }

  private func applyStereoInput(_ value: StereoInputSettings) {
    if running || changing {
      presentAfterStopping { [weak self] in self?.applyStereoInput(value) }
      return
    }
    stereoInput = value.validated
    stereoInput.save()
    threeD.stereoSettings = stereoInput
    threeD.layout = stereoInput.format == .fullSBS ? .fullWidth : .halfWidth
    if stereoInput.format.isSBS {
      UserDefaults.standard.set(threeD.layout.rawValue, forKey: "videoLayout")
    }
    rebuildMenu()
  }

  @objc private func selectStereoInput(_ sender: NSMenuItem) {
    guard let format = StereoInputFormat(rawValue: sender.tag) else { return }
    var value = stereoInput
    value.format = format
    applyStereoInput(value)
  }

  @objc private func swapStereoEyes() {
    var value = stereoInput
    value.swapEyes.toggle()
    applyStereoInput(value)
  }

  @objc private func showStereoOptions() {
    presentAfterStopping { [weak self] in self?.stereoOptions.present() }
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
    activate3D(mode: .video)
  }

  @objc private func toggleDesktop() {
    activate3D(mode: .desktop)
  }

  @objc private func toggleConversion() {
    guard !settings.isRecording else { return }
    if !running && !changing
      && Bundle.main.url(forResource: "model", withExtension: "onnx", subdirectory: "Conversion")
        == nil
    {
      show("This build does not include the private 2D conversion assets.")
      return
    }
    activate3D(mode: .conversion)
  }

  private func registerConversionControls() throws {
    let bindings: [(Int, Int, Int)] = [
      (kVK_ANSI_1, 0, 0), (kVK_ANSI_3, -1, 0), (kVK_ANSI_4, 1, 0), (kVK_ANSI_5, 0, -1),
      (kVK_ANSI_6, 0, 1),
    ]
    conversionControls = try bindings.enumerated().map { index, binding in
      try HotKey(
        keyCode: UInt32(binding.0), modifiers: UInt32(controlKey | shiftKey),
        id: UInt32(410 + index)
      ) { [weak self] in
        guard let self, self.running, self.threeD.mode == .conversion else { return }
        self.threeD.adjustConversion(depth: binding.1, popOut: binding.2)
      }
    }
  }

  private func activate3D(mode: PresentationMode) {
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
      if mode == .conversion { try registerConversionControls() }
    } catch {
      escapeKey = nil
      conversionControls = []
      show(error.localizedDescription)
      return
    }
    settings.close()
    threeD.mode = mode
    changing = true
    threeDStatus = "Starting 3D…"
    rebuildMenu()
    startTask = Task { [weak self] in
      guard let self else { return }
      var failureMessage: String?
      do {
        try await threeD.start(on: screen, profile: profile)
        running = true
      } catch {
        running = false
        escapeKey = nil
        conversionControls = []
        threeDStatus = "3D is off"
        if !(error is CancellationError) { failureMessage = error.localizedDescription }
      }
      if !stopping { changing = false }
      startTask = nil
      rebuildMenu()
      if let failureMessage, !stopping, !terminationPending { show(failureMessage) }
    }
  }

  private func stop3D(message: String? = nil, reason: String = "user request") {
    guard (running || changing) && !stopping else { return }
    logger.notice("Stopping 3D: \(reason, privacy: .public)")
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
      conversionControls = []
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
    if notification.name == NSApplication.didChangeScreenParametersNotification {
      if changing || threeD.outputDisplayIsUnchanged { return }
    }
    stop3D(reason: notification.name.rawValue)
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
        "Watch fullscreen stereo videos in glasses-free 3D on your Samsung Odyssey 3D monitor. The app uses the monitor’s factory calibration and tracks your eyes to align the 3D image as you move.\n\nPlay a stereo video fullscreen, choose its Stereo Input format, then select Activate 3D or press \(self.shortcut.displayName). Press Esc to stop.\n\nConvert ordinary fullscreen 2D video with Control–Shift–2 (Experimental). During conversion, Control–Shift–3/4 adjusts Depth and Control–Shift–5/6 adjusts Pop-Out.\n\nDesktop 3D adds an experimental depth effect to your windows.\n\nVersion \(version)\nLicense: MIT (app source; third-party components retain their own licenses)."
      alert.icon = NSApp.applicationIconImage
      alert.addButton(withTitle: "OK")
      alerts.present(alert)
    }
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    alerts.dismiss()
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
    alerts.present(alert)
  }
}
