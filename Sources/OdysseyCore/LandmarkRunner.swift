import OdysseyVision

public struct LandmarkCrop {
  public let tensor: [Float]
  public let region: NormalizedFaceRegion

  public static func prepare(
    pixels: [UInt8], width: Int, height: Int, stride: Int,
    region: NormalizedFaceRegion
  ) throws -> LandmarkCrop {
    guard width > 0, width <= 8192, height > 0, height <= 8192, stride >= width else {
      throw TrackingMathError.invalidInput
    }
    let roi = [region.center.x, region.center.y, region.size.x, region.size.y, region.rotation]
    var tensor = Array(repeating: Float(0), count: 192 * 192)
    var adjusted = Array(repeating: Float(0), count: 5)
    guard
      odyssey_landmark_crop(
        pixels, pixels.count, Int32(width), Int32(height), stride,
        roi, &tensor, tensor.count, &adjusted) == 0
    else {
      throw TrackingMathError.invalidInput
    }
    return LandmarkCrop(
      tensor: tensor,
      region: NormalizedFaceRegion(
        center: SIMD2(adjusted[0], adjusted[1]), size: SIMD2(adjusted[2], adjusted[3]),
        rotation: adjusted[4]))
  }
}

public struct LandmarkRunnerOutput {
  public let confidence: Float
  public let landmarks: [SIMD3<Float>]
  public let nextRegion: NormalizedFaceRegion
}

// Reproduces Blink's default LandmarkDetectorRunner. The caller supplies a face
// region from the detector/scheduler and an already-prepared grayscale camera
// frame. This layer does not invent a face region or substitute calibration.
public final class LandmarkRunner {
  private let model: LandmarkModel
  public init(model: LandmarkModel) { self.model = model }

  public func execute(
    pixels: [UInt8], width: Int, height: Int, stride: Int,
    region: NormalizedFaceRegion
  ) throws -> LandmarkRunnerOutput {
    let crop = try LandmarkCrop.prepare(
      pixels: pixels, width: width, height: height,
      stride: stride, region: region)
    let prediction = try model.predict(tensor: crop.tensor)
    let landmarks = try LandmarkProcessing.project(
      prediction.coordinates,
      normalizer: SIMD2(repeating: 1), region: crop.region)
    let next = try LandmarkProcessing.nextRegion(
      landmarks,
      imageSize: SIMD2(Float(width), Float(height)))
    return LandmarkRunnerOutput(
      confidence: prediction.confidence,
      landmarks: landmarks, nextRegion: next)
  }
}
