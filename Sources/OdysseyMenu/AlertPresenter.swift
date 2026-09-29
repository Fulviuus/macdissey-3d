import AppKit

/// Menu apps have no document window to host a sheet. Keep alerts modeless so
/// Quit and permission-driven relaunches never wait on a nested modal loop.
@MainActor final class AlertPresenter: NSObject {
  private var alert: NSAlert?

  func present(_ alert: NSAlert) {
    dismiss()
    self.alert = alert
    // runModal/beginSheet normally perform this; displaying window directly
    // otherwise exposes the alert's unconfigured placeholder controls.
    alert.layout()
    alert.window.isReleasedWhenClosed = false
    for button in alert.buttons {
      button.target = self
      button.action = #selector(dismiss)
    }
    alert.window.center()
    NSApp.activate(ignoringOtherApps: true)
    alert.window.makeKeyAndOrderFront(nil)
  }

  @objc func dismiss() {
    alert?.window.close()
    alert = nil
  }
}
