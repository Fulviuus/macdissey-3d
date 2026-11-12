import Foundation
import simd

enum DemoViewpointMode: String {
  case smooth, raw, fixed
}

struct DemoViewpoint: Equatable {
  var midpoint = SIMD3<Float>(0, 0, 0.6)
  var ipd: Float = 0.063
}

/// Scene-camera smoothing only. Factory tracking and optical eye routing remain
/// live and unchanged in the host. Repeated render frames approach the last
/// accepted sample continuously, rather than stepping at the camera cadence.
struct DemoViewpointFilter {
  private(set) var value = DemoViewpoint()
  private var target = DemoViewpoint()
  private var lastFrameTime: Double?
  private var lastSampleTime: Double?
  private var samples: [SIMD3<Float>] = []
  private var velocity = SIMD3<Float>.zero

  mutating func update(
    midpoint: SIMD3<Float>?, ipd: Float, sampleTime: Double, now: Double,
    mode: DemoViewpointMode = .smooth
  ) -> DemoViewpoint {
    guard now.isFinite, lastFrameTime.map({ now > $0 }) ?? true else { return value }
    let elapsed = lastFrameTime.map { now - $0 } ?? 0
    lastFrameTime = now
    if mode == .fixed { return DemoViewpoint() }
    guard let midpoint, (0..<3).allSatisfy({ midpoint[$0].isFinite }),
      abs(midpoint.x) <= 2, abs(midpoint.y) <= 2,
      midpoint.z >= 0.2, midpoint.z <= 2, ipd.isFinite, ipd > 0,
      sampleTime.isFinite, sampleTime <= now, now - sampleTime < 0.15,
      lastSampleTime.map({ sampleTime >= $0 }) ?? true
    else {
      // A brief dropout must not jump the scene to the neutral camera. The
      // host still disables the lenses independently when tracking is invalid.
      return value
    }
    if lastSampleTime.map({ sampleTime > $0 }) ?? true {
      var observation = midpoint
      let sampleInterval = lastSampleTime.map { sampleTime - $0 }
      if sampleInterval.map({ $0 > 0.15 }) ?? false {
        samples.removeAll(keepingCapacity: true)
        velocity = .zero
      }
      samples.append(midpoint)
      if samples.count > 3 { samples.removeFirst() }
      if mode == .smooth && samples.count == 3 {
        // Reject isolated triangulation spikes without accumulating a frame queue.
        for axis in 0..<3 { observation[axis] = samples.map { $0[axis] }.sorted()[1] }
      }
      if let interval = sampleInterval, interval > 0, interval <= 0.15 {
        let dt = Float(interval)
        let measuredVelocity = (observation - target.midpoint) / dt
        for axis in 0..<3 {
          let derivativeCutoff: Float = axis == 2 ? 1 : 2
          let alpha = 1 - exp(-2 * Float.pi * derivativeCutoff * dt)
          velocity[axis] += (measuredVelocity[axis] - velocity[axis]) * alpha
        }
      }
      target = DemoViewpoint(midpoint: observation, ipd: min(0.08, max(0.04, ipd)))
      if lastSampleTime == nil && elapsed == 0 { value = target }
      lastSampleTime = sampleTime
    }
    if mode == .raw {
      value = target
      return value
    }
    // Speed-adaptive low-pass approach: Casiez, Roussel and Vogel, CHI 2012.
    // https://gery.casiez.net/1euro/ — independently implemented with a median
    // spike guard and render-rate updates. Derivatives use observation time,
    // not repeated acknowledgements of the same camera sample.
    // Noisy depth must not increase lateral gain or pull the scene sideways.
    let dt = Float(min(elapsed, 0.05))
    for axis in 0..<3 {
      let minimumCutoff: Float = axis == 2 ? 0.5 : 1
      let speedGain: Float = axis == 2 ? 10 : 90
      let cutoff = min(30, minimumCutoff + speedGain * abs(velocity[axis]))
      let alpha = 1 - exp(-2 * Float.pi * cutoff * dt)
      value.midpoint[axis] += (target.midpoint[axis] - value.midpoint[axis]) * alpha
    }
    let ipdAlpha = 1 - exp(-2 * Float.pi * dt)
    value.ipd += (target.ipd - value.ipd) * ipdAlpha
    return value
  }
}
