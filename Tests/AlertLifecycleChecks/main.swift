import AppKit

@MainActor final class QuitDelegate: NSObject, NSApplicationDelegate {
  let alerts = AlertPresenter()

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    alerts.dismiss()
    print("PASS: Quit reaches the app delegate while an alert is visible")
    fflush(stdout)
    return .terminateNow
  }
}

@main enum AlertLifecycleChecks {
  @MainActor static func main() {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    let delegate = QuitDelegate()
    NSApp.delegate = delegate
    let alert = NSAlert()
    alert.messageText = "macdissey 3d alert regression check"
    alert.informativeText =
      "Allow macdissey 3d in System Settings → Privacy & Security → Screen & System Audio Recording, then quit and reopen the app. If it is already enabled after an app update, remove its entry with the minus button and add this copy of the app again."
    alert.addButton(withTitle: "OK")
    delegate.alerts.present(alert)
    precondition(NSApp.modalWindow == nil && alert.window.isVisible)
    let content = alert.window.contentView!
    content.layoutSubtreeIfNeeded()
    var labels: [String] = []
    func inspect(_ view: NSView) {
      guard !view.isHidden else { return }
      if let button = view as? NSButton {
        precondition(button.title == "OK", "Unexpected placeholder control: \(button.title)")
      }
      if let label = view as? NSTextField { labels.append(label.stringValue) }
      for child in view.subviews { inspect(child) }
    }
    inspect(content)
    precondition(labels.contains(alert.informativeText), "Missing permission instructions")
    let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
    content.cacheDisplay(in: content.bounds, to: bitmap)
    try! bitmap.representation(using: .png, properties: [:])!.write(
      to: URL(fileURLWithPath: ".build/settings-checks/permission-alert.png"))
    alert.buttons[0].performClick(nil)
    precondition(!alert.window.isVisible, "OK must dismiss the alert")
    delegate.alerts.present(alert)
    DispatchQueue.main.async { NSApp.terminate(nil) }
    withExtendedLifetime(delegate) { NSApp.run() }
    fatalError("Quit should terminate the process")
  }
}
