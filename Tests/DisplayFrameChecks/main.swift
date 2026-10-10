import AppKit
import QuartzCore

@main enum DisplayFrameChecks {
  @MainActor static func main() {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    let window = NSWindow(
      contentRect: NSRect(x: 100, y: 100, width: 160, height: 80),
      styleMask: [.titled], backing: .buffered, defer: false)
    window.title = "Frame pacing check"
    let view = window.contentView!
    window.orderFront(nil)
    defer { window.orderOut(nil) }
    var ticks: [CFTimeInterval] = []
    let link = DisplayFrameClock.start(for: view) {
      precondition(Thread.isMainThread, "AppKit drawing stays on the main thread")
      ticks.append(CACurrentMediaTime())
    }
    RunLoop.main.run(until: Date().addingTimeInterval(0.8))
    precondition(ticks.count >= 10, "Visible view receives display callbacks")
    let gaps = zip(ticks.dropFirst(), ticks).map { $0 - $1 }.sorted()
    let median = gaps[gaps.count / 2] * 1000
    precondition(median >= 10, "120 Hz displays retain the 60 Hz rendering budget")
    link.invalidate()
    let stoppedCount = ticks.count
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    precondition(ticks.count == stoppedCount, "No display callbacks after stopping")
    window.orderOut(nil)
    var hiddenTicks = 0
    let hiddenLink = DisplayFrameClock.start(for: view) { hiddenTicks += 1 }
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    hiddenLink.invalidate()
    precondition(hiddenTicks == 0, "Hidden output does not keep scheduling draws")
    print(
      "PASS display-paced rendering: \(stoppedCount) callbacks, median gap \(median) ms; main-thread delivery, stop and hidden-view suspension"
    )
  }
}
