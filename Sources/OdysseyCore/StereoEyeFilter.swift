import OdysseyVision

/// Pixel observations for eye 0, then eye 1, in each stereo camera.
public struct StereoEyeObservation {
  public let first: SIMD4<Float>
  public let second: SIMD4<Float>
  public init(first: SIMD4<Float>, second: SIMD4<Float>) {
    self.first = first
    self.second = second
  }
  var packed: [Float] {
    [first.x, first.y, first.z, first.w, second.x, second.y, second.z, second.w]
  }
  var isFinite: Bool { packed.allSatisfy(\.isFinite) }
}

/// ET's original adaptive 2D filter: constant/linear fits with a ten-frame
/// maximum discrepancy weight. Keep one instance for the stereo tracker.
public final class StereoEyeFilter {
  private var times: [Double] = []
  private var camera0: [Float] = [], camera1: [Float] = []
  private var weights: [SIMD2<Float>] = []
  public init() {}
  public func resetTrackingHistory() {
    times.removeAll(keepingCapacity: true)
    camera0.removeAll(keepingCapacity: true)
    camera1.removeAll(keepingCapacity: true)
    // The original adaptive weights are process-static and outlive history.
  }
  private func fit(order: Int32) throws -> [Float] {
    var result = [Float](repeating: 0, count: 8)
    guard odyssey_stereo_fit(times, camera0, camera1, times.count, order, &result) == 0 else {
      throw TrackingMathError.invalidInput
    }
    return result
  }
  public func update(_ observation: StereoEyeObservation, frameNumber: UInt64) throws
    -> StereoEyeObservation
  {
    guard observation.isFinite else { throw TrackingMathError.invalidInput }
    let frame = Double(frameNumber)
    // The original regresses frame IDs, not capture timestamps, and ignores duplicates.
    if times.last == frame { return observation }
    times.append(frame)
    camera0 += [
      observation.first.x, observation.first.y, observation.second.x, observation.second.y,
    ]
    camera1 += [
      observation.first.z, observation.first.w, observation.second.z, observation.second.w,
    ]
    if times.count > 12 {
      times.removeFirst()
      camera0.removeFirst(4)
      camera1.removeFirst(4)
    }
    let constant = try fit(order: 0)
    let linear = try fit(order: 1)
    var weight = SIMD2<Float>.zero
    for axis in 0..<2 {
      let difference =
        ((abs(linear[axis + 2] - constant[axis + 2]) + abs(linear[axis] - constant[axis]))
          + abs(linear[axis + 4] - constant[axis + 4])) + abs(linear[axis + 6] - constant[axis + 6])
      weight[axis] = min(1, max(0, (Float(1) / 5) * (difference * 0.25)))
    }
    weights.append(weight)
    if weights.count > 10 { weights.removeFirst() }
    weight = weights.reduce(.zero) { SIMD2(max($0.x, $1.x), max($0.y, $1.y)) }
    var output = [Float](repeating: 0, count: 8)
    for index in 0..<8 {
      let w = weight[index % 2]
      let inverse = Float(1) - w
      // Original FMA operand ordering differs between the two eyes.
      output[index] =
        index < 4
        ? (constant[index] * inverse).addingProduct(w, linear[index])
        : (w * linear[index]).addingProduct(inverse, constant[index])
    }
    return StereoEyeObservation(
      first: SIMD4(output[0], output[1], output[2], output[3]),
      second: SIMD4(output[4], output[5], output[6], output[7]))
  }
}
