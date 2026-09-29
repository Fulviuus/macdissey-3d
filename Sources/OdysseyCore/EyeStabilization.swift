import Foundation

/// Recovered vertical eye stabilization. The stereo loop and mono helper
/// differ in scalar operation order and history reset; preserve both paths.
public struct EyeStabilization {
  public enum Mode { case stereo, mono }
  public private(set) var history = SIMD2<Float>.zero
  public let mode: Mode
  public init(mode: Mode = .stereo) { self.mode = mode }

  public mutating func apply(
    landmarks: [SIMD2<Float>], left: SIMD3<Float>, right: SIMD3<Float>,
    intrinsics: [Double], newUser: Bool = false
  ) throws -> (SIMD3<Float>, SIMD3<Float>) {
    guard landmarks.count == 68, intrinsics.count == 4,
      landmarks.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
      intrinsics.allSatisfy(\.isFinite), intrinsics[0] > 0, intrinsics[1] > 0
    else { throw TrackingMathError.invalidInput }
    let pairs =
      mode == .stereo
      ? [(16, 0), (25, 18), (24, 19), (23, 20), (22, 21), (14, 2), (15, 1)]
      : [(15, 1), (14, 2), (16, 0), (25, 18), (24, 19), (23, 20), (22, 21)]
    var slope: Float = 0
    for (a, b) in pairs {
      let delta = landmarks[a] - landmarks[b]
      slope += delta.y / delta.x
    }
    let angle = -atan(slope * Float(1.0 / 7.0))
    let s = sin(angle)
    let c = cos(angle)
    guard angle.isFinite else { throw TrackingMathError.invalidInput }
    let rotated = landmarks.map { p -> SIMD2<Float> in
      let x = (-s * p.y).addingProduct(p.x, c)
      let y = mode == .stereo ? (c * p.y).addingProduct(p.x, s) : (s * p.x).addingProduct(p.y, c)
      return SIMD2(x, y)
    }
    var low: Float = 1e9
    var high: Float = 0
    for p in rotated {
      low = min(low, p.y)
      high = max(high, p.y)
    }
    let means = [36, 42].map { start -> SIMD2<Float> in
      var sum = SIMD2<Double>.zero
      for i in start..<start + 6 { sum += SIMD2(Double(rotated[i].x), Double(rotated[i].y)) }
      return SIMD2(Float(sum.x / 6), Float(sum.y / 6))
    }
    var anchor: Float = 0
    for i in [1, 2, 3, 15, 16, 17, 19, 20, 21, 22, 23, 24, 25, 26, 27, 29, 30, 31, 32, 33, 34, 35] {
      anchor = anchor.addingProduct(Float(1.0 / 22.0), rotated[i].y)
    }
    let distance = SIMD2(means[0].y - anchor, means[1].y - anchor)
    let threshold = abs(high - low) * 5 * Float(0.01)
    let factor = Double(Float(0.95))
    for eye in 0..<2 {
      if threshold < abs(history[eye] - distance[eye]) || (mode == .stereo && newUser) {
        history[eye] = distance[eye]
      }
      history[eye] =
        Float(Double(history[eye]) * factor) + Float(Double(distance[eye]) * (1 - factor))
    }
    let fx = Float(intrinsics[0])
    let fy = Float(intrinsics[1])
    let cx = Float(intrinsics[2])
    let cy = Float(intrinsics[3])
    let z = left.z
    var output = [left, right]
    for eye in 0..<2 {
      let mean = means[eye]
      let y = history[eye] + anchor
      // Deliberately separate products: the original stereo pair helpers
      // round each multiplication before adding/subtracting.
      let oldX = s * mean.y + c * mean.x
      let newX = s * y + c * mean.x
      let oldY = c * mean.y - s * mean.x
      let newY = c * y - s * mean.x
      output[eye].x += ((newX - cx) / fx) * z - ((oldX - cx) / fx) * z
      output[eye].y += ((newY - cy) / fy) * z - ((oldY - cy) / fy) * z
    }
    guard output.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else {
      throw TrackingMathError.invalidInput
    }
    return (output[0], output[1])
  }
}
