import Foundation

public struct NormalizedFaceRegion {
  public var center: SIMD2<Float>
  public var size: SIMD2<Float>
  public var rotation: Float
  public init(center: SIMD2<Float>, size: SIMD2<Float>, rotation: Float) {
    self.center = center
    self.size = size
    self.rotation = rotation
  }
  var isFinite: Bool {
    center.x.isFinite && center.y.isFinite && size.x.isFinite && size.y.isFinite
      && rotation.isFinite
  }
}

// Reconstructed from Blink's LandmarkPostprocessor, TensorToProjectedLandmarks,
// and RectFromLandmarks. These operations consume model outputs; they do not
// replace the inference model, face scheduler, or camera calibration.
public enum LandmarkProcessing {
  // Original ld_model_config for the default 198-point TFLite model.
  public static let defaultModelMapping68 = [
    197, 195, 193, 191, 189, 187, 185, 183, 181, 179, 177, 175, 173, 171, 169, 167, 165,
    58, 60, 62, 64, 66, 83, 81, 79, 77, 75, 139, 141, 143, 145, 157, 156, 155, 154, 153,
    0, 2, 4, 6, 8, 10, 35, 33, 31, 29, 39, 37, 104, 102, 100, 98, 97, 94, 92, 113, 111,
    110, 108, 106, 123, 121, 119, 117, 129, 127, 126, 125,
  ]
  public static func selectDefaultModelLandmarks68(_ landmarks: [SIMD3<Float>]) throws -> [SIMD3<
    Float
  >] {
    guard landmarks.count == 198, landmarks.allSatisfy({ $0.x.isFinite && $0.y.isFinite })
    else { throw TrackingMathError.invalidInput }
    return defaultModelMapping68.map { landmarks[$0] }
  }

  public static func confidence(logit: Float) throws -> Float {
    guard logit.isFinite else { throw TrackingMathError.invalidInput }
    return 1 / (exp(-logit) + 1)
  }

  public static func project(
    _ tensor: [SIMD2<Float>], normalizer: SIMD2<Float>,
    region: NormalizedFaceRegion, flipX: Bool = false
  ) throws -> [SIMD3<Float>] {
    guard !tensor.isEmpty, region.isFinite, region.size.x > 0, region.size.y > 0,
      normalizer.x.isFinite, normalizer.y.isFinite, normalizer.x > 0, normalizer.y > 0,
      tensor.allSatisfy({ $0.x.isFinite && $0.y.isFinite })
    else { throw TrackingMathError.invalidInput }
    let cosine = cos(region.rotation)
    let sine = sin(region.rotation)
    return try tensor.map { point in
      let x = (flipX ? normalizer.x - point.x : point.x) / normalizer.x - 0.5
      let y = point.y / normalizer.y - 0.5
      let px = (cosine * x - sine * y) * region.size.x + region.center.x
      let py = (sine * x + cosine * y) * region.size.y + region.center.y
      guard px.isFinite, py.isFinite else { throw TrackingMathError.invalidInput }
      return SIMD3(px, py, 0)
    }
  }

  public static func nextRegion(
    _ landmarks: [SIMD3<Float>], imageSize: SIMD2<Float>,
    eyeIndices: SIMD2<Int> = SIMD2(0, 29), expansion: Float = 1.5,
    targetRotation: Float = 0
  ) throws -> NormalizedFaceRegion {
    guard !landmarks.isEmpty, imageSize.x.isFinite, imageSize.y.isFinite,
      imageSize.x > 0, imageSize.y > 0, expansion.isFinite, expansion > 0,
      targetRotation.isFinite, eyeIndices.x >= 0, eyeIndices.y >= 0,
      eyeIndices.x < landmarks.count, eyeIndices.y < landmarks.count,
      landmarks.allSatisfy({ $0.x.isFinite && $0.y.isFinite })
    else { throw TrackingMathError.invalidInput }
    var lower = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
    // Original RectFromLandmarks initializes maxima to FLT_MIN (positive),
    // not -FLT_MAX. Preserve its out-of-frame behavior when all X/Y are negative.
    var upper = SIMD2<Float>(repeating: .leastNormalMagnitude)
    for point in landmarks {
      lower.x = min(lower.x, point.x)
      lower.y = min(lower.y, point.y)
      upper.x = max(upper.x, point.x)
      upper.y = max(upper.y, point.y)
    }
    let size = upper - lower
    let start = landmarks[eyeIndices.x]
    let end = landmarks[eyeIndices.y]
    let angle = atan2(
      -(imageSize.y * end.y - imageSize.y * start.y),
      imageSize.x * end.x - imageSize.x * start.x)
    let rawAngle = targetRotation - angle
    let turns = floor((Double(rawAngle) - (-Double.pi)) / (2 * Double.pi))
    let rotation = Float(Double(rawAngle) - turns * (2 * Double.pi))
    let side = max(imageSize.y * size.y, imageSize.x * size.x)
    let result = NormalizedFaceRegion(
      center: size * 0.5 + lower,
      size: SIMD2((side / imageSize.x) * expansion, (side / imageSize.y) * expansion),
      rotation: rotation)
    guard result.isFinite else { throw TrackingMathError.invalidInput }
    return result
  }
}
