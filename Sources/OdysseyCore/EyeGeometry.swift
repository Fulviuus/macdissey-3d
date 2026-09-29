import Foundation

// Blink 1.11.0 reconstruction.
// Rodrigues and inverse distortion preserve the OpenCV 4.3 arithmetic order.
// See THIRD_PARTY_NOTICES.md for the OpenCV license.
public struct HeadPose {
  public var position: SIMD3<Double>
  public var rotation: SIMD3<Double>
  public init(position: SIMD3<Double>, rotation: SIMD3<Double>) {
    self.position = position
    self.rotation = rotation
  }
  var isFinite: Bool { (0..<3).allSatisfy { position[$0].isFinite && rotation[$0].isFinite } }
}

public struct CameraIntrinsics {
  public let fx: Double, fy: Double, cx: Double, cy: Double, width: Double
  public let distortion: [Double]
  public init(
    fx: Double, fy: Double, cx: Double, cy: Double, width: Double,
    distortion: [Double]
  ) throws {
    guard [fx, fy, cx, cy, width].allSatisfy(\.isFinite), fx > 0, fy > 0, width > 0,
      distortion.count == 8, distortion.allSatisfy(\.isFinite)
    else { throw TrackingMathError.invalidInput }
    self.fx = fx
    self.fy = fy
    self.cx = cx
    self.cy = cy
    self.width = width
    self.distortion = distortion
  }
  func ray(_ pixel: SIMD2<Double>) -> SIMD2<Double> {
    let initialX = ((width - pixel.x) - (width - cx)) * (1.0 / fx)
    let initialY = (pixel.y - cy) * (1.0 / fy)
    var x = initialX
    var y = initialY
    let k = distortion
    for _ in 0..<5 {
      let radius = x * x + y * y
      let inverse =
        (1 + ((k[7] * radius + k[6]) * radius + k[5]) * radius)
        / (1 + ((k[4] * radius + k[1]) * radius + k[0]) * radius)
      if inverse < 0 { return SIMD2(initialX, initialY) }
      let dx = 2 * k[2] * x * y + k[3] * (radius + 2 * x * x)
      let dy = k[2] * (radius + 2 * y * y) + 2 * k[3] * x * y
      x = (initialX - dx) * inverse
      y = (initialY - dy) * inverse
    }
    return SIMD2(x, y)
  }
}

public enum EyeGeometry {
  static func rotation(_ vector: SIMD3<Double>) -> [[Double]] {
    let angle = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    if angle < Double.ulpOfOne { return [[1, 0, 0], [0, 1, 0], [0, 0, 1]] }
    let inverse = 1.0 / angle
    let cosine = cos(angle)
    let sine = sin(angle)
    let complement = 1 - cosine
    let x = vector.x * inverse
    let y = vector.y * inverse
    let z = vector.z * inverse
    let outer = [[x * x, x * y, x * z], [x * y, y * y, y * z], [x * z, y * z, z * z]]
    let cross = [[0.0, -z, y], [z, 0, -x], [-y, x, 0]]
    return (0..<3).map { i in
      (0..<3).map { j in
        (cosine * (i == j ? 1.0 : 0.0) + complement * outer[i][j]) + sine * cross[i][j]
      }
    }
  }

  public static func projectLandmarks(
    _ model: [SIMD3<Double>], pose: HeadPose,
    pixels: [SIMD2<Double>], camera: CameraIntrinsics, ratio: Double,
    depthMultiplier: Double, projectToPixels: Bool
  ) throws -> [SIMD3<Double>] {
    guard !model.isEmpty, pose.isFinite, ratio.isFinite, depthMultiplier.isFinite,
      model.allSatisfy({ p in (0..<3).allSatisfy { p[$0].isFinite } }),
      !projectToPixels
        || (pixels.count == model.count && pixels.allSatisfy({ $0.x.isFinite && $0.y.isFinite }))
    else { throw TrackingMathError.invalidInput }
    let matrix = rotation(pose.rotation)
    return try model.enumerated().map { index, input in
      let point = SIMD3(input.x * ratio, input.y, input.z)
      let values = matrix.map { point.x * $0[0] + point.y * $0[1] + point.z * $0[2] }
      var result = SIMD3(values[0], values[1], values[2] + pose.position.z * depthMultiplier)
      if projectToPixels {
        let ray = camera.ray(pixels[index])
        result.x = result.z * ray.x
        result.y = result.z * ray.y
      } else {
        result.x += pose.position.x
        result.y += pose.position.y
      }
      guard (0..<3).allSatisfy({ result[$0].isFinite }) else {
        throw TrackingMathError.invalidInput
      }
      return result
    }
  }

  public static func eyeCenters(_ landmarks: [SIMD3<Double>]) throws -> (
    left: SIMD3<Double>, right: SIMD3<Double>
  ) {
    guard landmarks.count >= 46 else { throw TrackingMathError.invalidInput }
    return ((landmarks[36] + landmarks[39]) * 0.5, (landmarks[42] + landmarks[45]) * 0.5)
  }

  public static func depthRatio(
    left: SIMD3<Double>, right: SIMD3<Double>,
    neuralDepth: SIMD2<Double>
  ) throws -> Double {
    let existing = (left.z + right.z) * 0.5
    guard existing.isFinite, existing != 0, neuralDepth.x.isFinite, neuralDepth.y.isFinite
    else { throw TrackingMathError.invalidInput }
    let result = ((neuralDepth.x + neuralDepth.y) * 0.5) / existing
    guard result.isFinite else { throw TrackingMathError.invalidInput }
    return result
  }
}

public struct DepthScaleCache {
  struct Key: Hashable { let stream: UInt32, camera: UInt32, face: UInt32 }
  private var values: [Key: Double] = [:]
  public let minimum: Double, maximum: Double
  public init(minimum: Double, maximum: Double) throws {
    guard minimum.isFinite, maximum.isFinite, minimum <= maximum else {
      throw TrackingMathError.invalidInput
    }
    self.minimum = minimum
    self.maximum = maximum
  }
  public mutating func reset() { values.removeAll(keepingCapacity: true) }
  public static func accepts(_ pose: HeadPose) -> Bool {
    abs(pose.position.x) < 100 && abs(pose.position.y) < 100
      && pose.position.z > 400 && pose.position.z < 700
      && abs(pose.rotation.y) < 0.436332 && abs(pose.rotation.z) < 0.436332
      && pose.rotation.x > -0.349066 && pose.rotation.x < 0.523599
  }
  // Status values are the recovered interface integers. Upstream scheduling
  // must establish them; this layer does not guess detection/tracking states.
  public mutating func update(
    stream: UInt32, camera: UInt32, face: UInt32, status: Int?,
    pose: HeadPose, left: SIMD3<Double>, right: SIMD3<Double>, neuralDepth: SIMD2<Double>
  )
    throws -> (missing: Bool, ratio: Double)
  {
    guard pose.isFinite else { throw TrackingMathError.invalidInput }
    let key = Key(stream: stream, camera: camera, face: face)
    var candidate: Double?
    if Self.accepts(pose) && values[key] == nil {
      let ratio = try EyeGeometry.depthRatio(left: left, right: right, neuralDepth: neuralDepth)
      if ratio >= minimum && ratio <= maximum { candidate = ratio }
    }
    if status == nil || status == 3 {
      values.removeValue(forKey: key)
    } else {
      if status == 0 { values.removeValue(forKey: key) }
      if let candidate { values[key] = candidate }
    }
    return (values[key] == nil, values[key] ?? 1.0)
  }
}
