import OdysseyVision

public struct FaceDetection {
  /// Normalized top-left XY and width/height; coordinates may extend outside the image.
  public let bounds: SIMD4<Float>
  public let keypoints: [SIMD3<Float>]
  public let confidence: Float
  public var landmarkRegion: NormalizedFaceRegion {
    NormalizedFaceRegion(
      center: SIMD2(
        Float(Double(bounds.z) * 0.5 + Double(bounds.x)),
        Float(Double(bounds.w) * 0.5 + Double(bounds.y))),
      size: SIMD2(bounds.z, bounds.w), rotation: 0)
  }
}

public struct FaceLetterbox {
  public let tensor: [Float]
  public let padding: [Int32]
  public static func prepare(pixels: [UInt8], width: Int, height: Int, stride: Int) throws
    -> FaceLetterbox
  {
    guard width > 0, width <= 8192, height > 0, height <= 8192, stride >= width else {
      throw TrackingMathError.invalidInput
    }
    var tensor = Array(repeating: Float(0), count: 448 * 320)
    var padding = Array(repeating: Int32(0), count: 4)
    guard
      odyssey_face_letterbox(
        pixels, pixels.count, Int32(width), Int32(height), stride,
        &tensor, tensor.count, &padding) == 0
    else { throw TrackingMathError.invalidInput }
    return FaceLetterbox(tensor: tensor, padding: padding)
  }
  public func decode(_ raw: [Float], confidenceThreshold: Float = 0.5) throws -> [FaceDetection] {
    var packed = Array(repeating: Float(0), count: 8820 * 20)
    var count = 0
    guard
      odyssey_face_decode(raw, raw.count, padding, confidenceThreshold, 0.5, &packed, 8820, &count)
        == 0
    else {
      throw TrackingMathError.invalidInput
    }
    return (0..<count).map { index in
      let base = index * 20
      return FaceDetection(
        bounds: SIMD4(packed[base], packed[base + 1], packed[base + 2], packed[base + 3]),
        keypoints: (0..<5).map {
          SIMD3(packed[base + 4 + $0 * 3], packed[base + 5 + $0 * 3], packed[base + 6 + $0 * 3])
        },
        confidence: packed[base + 19])
    }
  }
}

/// Original grayscale FaceDetectorRunner. Temporal face association and the
/// driver's CLAHE recovery pass belong to the enclosing tracking scheduler.
public final class FaceDetector {
  private let model: FaceModel
  public init(model: FaceModel) { self.model = model }
  public func execute(pixels: [UInt8], width: Int, height: Int, stride: Int) throws
    -> [FaceDetection]
  {
    let crop = try FaceLetterbox.prepare(
      pixels: pixels, width: width, height: height, stride: stride)
    return try crop.decode(model.predict(tensor: crop.tensor))
  }
}
