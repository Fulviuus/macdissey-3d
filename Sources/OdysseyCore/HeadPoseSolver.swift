import OdysseyVision

public enum HeadPoseSolver {
  // Model and calibrated pixels use the vendor camera coordinate system.
  // The caller supplies the verified subset and current depth-cache ratio.
  public static func solve(
    model: [SIMD3<Double>], pixels: [SIMD2<Double>],
    subset: [Int32], camera: CameraIntrinsics, ratio: Double
  ) throws -> HeadPose {
    guard model.count == 68, pixels.count == 68 else { throw TrackingMathError.invalidInput }
    let points = model.flatMap { [$0.x, $0.y, $0.z] }
    let image = pixels.flatMap { [$0.x, $0.y] }
    let matrix = [camera.fx, 0, camera.cx, 0, camera.fy, camera.cy, 0, 0, 1]
    var output = Array(repeating: 0.0, count: 6)
    let result = odyssey_solve_pose(
      points, image, subset, subset.count, matrix,
      camera.distortion, camera.width, ratio, 0, &output)
    guard result == 0 else { throw TrackingMathError.invalidInput }
    return HeadPose(
      position: SIMD3(output[0], output[1], output[2]),
      rotation: SIMD3(output[3], output[4], output[5]))
  }
}
