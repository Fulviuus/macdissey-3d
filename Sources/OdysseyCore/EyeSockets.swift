import Foundation

public enum EyeSockets {
  /// Blink EyeLocationExtractor's default filter level is zero. Its two
  /// centers are double-precision corner midpoints of the mapped landmarks.
  public static func centers(landmarks68: [SIMD2<Double>]) throws -> [SIMD2<Double>] {
    guard landmarks68.count == 68, landmarks68.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
      throw TrackingMathError.invalidInput
    }
    return [(landmarks68[36] + landmarks68[39]) * 0.5, (landmarks68[42] + landmarks68[45]) * 0.5]
  }
  /// SREyeTracker 0x108910 replaces both eye contours with radius-three
  /// circles before its float six-point average. Preserve the original
  /// approximate angular increment and the second eye's one-step offset.
  public static func replaceContours(
    _ landmarks68: [SIMD2<Float>], centers: [SIMD2<Double>],
    offset: SIMD2<Double> = .zero
  ) throws -> [SIMD2<Float>] {
    guard landmarks68.count == 68, centers.count == 2,
      centers.allSatisfy({ $0.x.isFinite && $0.y.isFinite }), offset.x.isFinite, offset.y.isFinite
    else {
      throw TrackingMathError.invalidInput
    }
    var output = landmarks68
    for eye in 0..<2 {
      for point in 0..<6 {
        let angle = Double(point + eye) * 1.0471666666666666
        let center = centers[eye] + offset
        output[36 + eye * 6 + point] = SIMD2(
          Float(center.x.addingProduct(3, cos(angle))),
          Float(sin(angle) * 3 + center.y))
      }
    }
    return output
  }
}
