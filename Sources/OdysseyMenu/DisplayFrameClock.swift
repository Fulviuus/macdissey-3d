import AppKit
import QuartzCore

@MainActor enum DisplayFrameClock {
  static func start(for view: NSView, draw: @escaping () -> Void) -> CADisplayLink {
    let target = DisplayFrameTarget(draw: draw)
    // Keep the 60 Hz rendering budget while following this view's display.
    // The link retains its target; callers can capture their view weakly.
    let link = view.displayLink(
      target: target, selector: #selector(DisplayFrameTarget.displayFrame(_:)))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
    link.add(to: .main, forMode: .common)
    return link
  }
}

@MainActor private final class DisplayFrameTarget: NSObject {
  private let draw: () -> Void
  init(draw: @escaping () -> Void) { self.draw = draw }
  @objc func displayFrame(_ link: CADisplayLink) { draw() }
}
