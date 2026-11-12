import AppKit
import QuartzCore

@MainActor enum DisplayFrameClock {
  static func start(for view: NSView, framesPerSecond: Double = 60, draw: @escaping () -> Void)
    -> CADisplayLink
  {
    let target = DisplayFrameTarget(draw: draw)
    // Follow this view's display, keeping the default 60 Hz capture budget.
    // The link retains its target; callers can capture their view weakly.
    let link = view.displayLink(
      target: target, selector: #selector(DisplayFrameTarget.displayFrame(_:)))
    let rate = Float(max(30, min(240, framesPerSecond.isFinite ? framesPerSecond : 60)))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
    link.add(to: .main, forMode: .common)
    return link
  }
}

@MainActor private final class DisplayFrameTarget: NSObject {
  private let draw: () -> Void
  init(draw: @escaping () -> Void) { self.draw = draw }
  @objc func displayFrame(_ link: CADisplayLink) { draw() }
}
