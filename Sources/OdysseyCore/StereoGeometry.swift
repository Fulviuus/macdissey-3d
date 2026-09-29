import OdysseyVision

public struct TriangulatedPoint {
  public let position: SIMD3<Float>
  public let reprojectionError: Double
  public let accepted: Bool
}
public enum StereoGeometry {
  /// SREyeTracker averages all six contour points per eye in float order.
  /// This differs from Blink's two-corner midpoint used in its mono path.
  public static func eyeCenters(landmarks68: [SIMD2<Float>]) throws -> SIMD4<Float> {
    guard landmarks68.count == 68, landmarks68.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
      throw TrackingMathError.invalidInput
    }
    var left = SIMD2<Float>.zero
    var right = SIMD2<Float>.zero
    for index in 36..<42 {
      left += landmarks68[index]
      right += landmarks68[index + 6]
    }
    left *= Float(1) / 6
    right *= Float(1) / 6
    return SIMD4(left.x, left.y, right.x, right.y)
  }
  /// Pixel coordinates and factory translation use the camera calibration's
  /// original orientation and millimetres. No display-space transform here.
  public static func triangulate(
    leftCamera: [Double], leftDistortion: [Double],
    rightCamera: [Double], rightDistortion: [Double], rotation: [Double], translation: [Double],
    pixels: SIMD4<Float>, minimumDepth: Double, maximumError: Double
  ) throws -> TriangulatedPoint {
    guard leftCamera.count == 9, rightCamera.count == 9, leftDistortion.count == 8,
      rightDistortion.count == 8, rotation.count == 9, translation.count == 3
    else {
      throw TrackingMathError.invalidInput
    }
    var point = [Float](repeating: 0, count: 3)
    var error = 0.0
    var accepted: Int32 = 0
    guard
      odyssey_stereo_triangulate(
        leftCamera, leftDistortion, rightCamera, rightDistortion,
        rotation, translation, [pixels.x, pixels.y, pixels.z, pixels.w], minimumDepth, maximumError,
        &point, &error, &accepted) == 0
    else { throw TrackingMathError.invalidInput }
    return TriangulatedPoint(
      position: SIMD3(point[0], point[1], point[2]), reprojectionError: error,
      accepted: accepted != 0)
  }
}
