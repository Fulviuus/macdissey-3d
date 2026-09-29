import Foundation

public struct StereoTrackingPose {
  public let firstCameraEyeMillimetres, secondCameraEyeMillimetres: SIMD3<Float>
  public let displayMidpointCentimetres: SIMD3<Float>
  public let timestamp: Double
  public let reprojectionError: Double
}

/// Composition of the recovered ET stereo math. Inputs are the original
/// 68-point camera landmarks, in unmirrored pixels. This class owns history
/// and must be used on one serial processing queue.
public final class StereoTrackingGeometry {
  private let camera: FactoryCameraCalibration
  private let transform: DisplayTransform
  private let rotation, leftK, rightK: [Double]
  private let filter = StereoEyeFilter()
  private var stabilization = EyeStabilization()
  private var history: PoseHistory
  private var output: PoseOutputFilter
  public init(camera: FactoryCameraCalibration, tracker: FactoryTrackerCalibration) throws {
    self.camera = camera
    transform = try DisplayTransform(factory: tracker)
    let r = camera.rotationVector
    rotation = EyeGeometry.rotation(SIMD3(r[0], r[1], r[2])).flatMap { $0 }
    func k(_ i: [Double]) -> [Double] { [i[0], 0, i[2], 0, i[1], i[3], 0, 0, 1] }
    leftK = k(camera.leftIntrinsics)
    rightK = k(camera.rightIntrinsics)
    history = try Self.makeHistory()
    output = try Self.makeOutput()
  }
  private static func makeHistory() throws -> PoseHistory {
    // 13a350 takes the maximum of weaving and lookaround axis counts.
    try PoseHistory(counts: SIMD3(4, 6, 12), ipdCounts: SIMD3(repeating: 12))
  }
  private static func makeOutput() throws -> PoseOutputFilter {
    let prediction = HistoryPredictionConfiguration(
      counts: SIMD3(4, 6, 12), velocityScales: .zero,
      outliers: .zero, projectToFixedDepth: true, fixedDepth: 60, horizon: 0.0156)
    let configuration = PoseOutputConfiguration(
      history: prediction, ipd: .zero,
      ipdThreshold: .greatestFiniteMagnitude, ipdTarget: 6.3, maxPredictionDistance: 15,
      prediction: true, depthPrediction: false, exponentialSmoothing: false, noiseRejection: true,
      rawMode: false)
    return try PoseOutputFilter(
      configuration: configuration, speed: [0, 0, 0, 0, 600, 600, 300],
      smoothing: [0, 0, 0, 1, 1, 1],
      noise: [0, 0, 0, 0, 0, 0, 0.1, 0.1, 0.1, 1, 1, 1, 5, 5, 5, 0.01, 0.01, 0.01])
  }
  public func reset() throws {
    filter.resetTrackingHistory()
    stabilization = EyeStabilization()
    history = try Self.makeHistory()
    output = try Self.makeOutput()
  }
  public func update(
    first: [SIMD2<Float>], second: [SIMD2<Float>], frameNumber: UInt64,
    captureTimestamp: Double, now: Double, newUser: Bool = false
  ) throws -> StereoTrackingPose? {
    guard captureTimestamp.isFinite, now.isFinite else { throw TrackingMathError.invalidInput }
    func sockets(_ points: [SIMD2<Float>]) throws -> [SIMD2<Float>] {
      let centers = try EyeSockets.centers(
        landmarks68: points.map { SIMD2(Double($0.x), Double($0.y)) })
      return try EyeSockets.replaceContours(points, centers: centers)
    }
    let a = try sockets(first)
    let b = try sockets(second)
    let centers0 = try StereoGeometry.eyeCenters(landmarks68: a)
    let centers1 = try StereoGeometry.eyeCenters(landmarks68: b)
    let pixels = try filter.update(
      StereoEyeObservation(
        first: SIMD4(centers0.x, centers0.y, centers1.x, centers1.y),
        second: SIMD4(centers0.z, centers0.w, centers1.z, centers1.w)), frameNumber: frameNumber)
    func triangulate(_ p: SIMD4<Float>) throws -> TriangulatedPoint {
      try StereoGeometry.triangulate(
        leftCamera: leftK, leftDistortion: camera.leftDistortion,
        rightCamera: rightK, rightDistortion: camera.rightDistortion, rotation: rotation,
        translation: camera.translation, pixels: p, minimumDepth: 200, maximumError: 40)
    }
    let eye0 = try triangulate(pixels.first)
    let eye1 = try triangulate(pixels.second)
    guard eye0.accepted, eye1.accepted else { return nil }
    let stabilized = try stabilization.apply(
      landmarks: a, left: eye0.position, right: eye1.position,
      intrinsics: camera.leftIntrinsics, newUser: newUser)
    // DisplayManager 132670 scales in float, then 138160 records doubles
    // in CAMERA coordinates. The display transform follows prediction.
    let c0 = stabilized.0 * Float(0.1)
    let c1 = stabilized.1 * Float(0.1)
    let timestamp = captureTimestamp - 0.0207
    guard history.samples.last.map({ $0.timestamp < timestamp }) ?? true else { return nil }
    try history.add(
      left: SIMD3(Double(c0.x), Double(c0.y), Double(c0.z)),
      right: SIMD3(Double(c1.x), Double(c1.y), Double(c1.z)), time: timestamp)
    guard history.samples.count >= 6 else { return nil }
    output.configuration.ipd = history.ipd
    let predicted = try output.apply(history.samples, now: now)
    let display0 = try transform.apply(
      centimetres: SIMD3(Float(predicted.left.x), Float(predicted.left.y), Float(predicted.left.z)))
    let display1 = try transform.apply(
      centimetres: SIMD3(
        Float(predicted.right.x), Float(predicted.right.y), Float(predicted.right.z)))
    return StereoTrackingPose(
      firstCameraEyeMillimetres: stabilized.0, secondCameraEyeMillimetres: stabilized.1,
      displayMidpointCentimetres: (display0 + display1) * Float(0.5), timestamp: captureTimestamp,
      reprojectionError: max(eye0.reprojectionError, eye1.reprojectionError))
  }
}

public struct StereoCameraTrackingFrame {
  public let firstFaces, secondFaces: Int
  public let pose: StereoTrackingPose?
}

/// Single-viewer integration of the original per-camera Blink models and ET
/// stereo math. Multi-user ROI handover remains a separate controller stage.
public final class StereoCameraTracker {
  private let first, second: FaceTracker
  private let geometry: StereoTrackingGeometry
  private var frame: UInt64 = 0
  private var locked = false
  public init(
    camera: FactoryCameraCalibration, tracker: FactoryTrackerCalibration,
    faceModelURL: URL, landmarkModelURL: URL
  ) throws {
    let detector = FaceDetector(model: try FaceModel(modelURL: faceModelURL))
    let landmarks = LandmarkRunner(model: try LandmarkModel(modelURL: landmarkModelURL))
    first = try FaceTracker(detector: detector, landmarkRunner: landmarks)
    second = try FaceTracker(detector: detector, landmarkRunner: landmarks)
    geometry = try StereoTrackingGeometry(camera: camera, tracker: tracker)
  }
  public func update(
    pixels: [UInt8], width: Int, height: Int, stride: Int,
    captureTimestamp: Double, now: () -> Double
  ) throws -> StereoCameraTrackingFrame {
    guard width == 1280, height == 480, stride >= width, pixels.count >= stride * height else {
      throw TrackingMathError.invalidInput
    }
    frame += 1
    var left = [UInt8](repeating: 0, count: 640 * 480)
    var right = left
    for y in 0..<480 {
      left.replaceSubrange(y * 640..<(y + 1) * 640, with: pixels[y * stride..<y * stride + 640])
      right.replaceSubrange(
        y * 640..<(y + 1) * 640, with: pixels[y * stride + 640..<y * stride + 1280])
    }
    let a = try first.execute(pixels: left, width: 640, height: 480, stride: 640)
    let b = try second.execute(pixels: right, width: 640, height: 480, stride: 640)
    guard a.faces.count == 1, b.faces.count == 1,
      let face0 = a.faces.first, let face1 = b.faces.first,
      face0.landmarks.count == 198, face1.landmarks.count == 198
    else {
      if a.faces.isEmpty || b.faces.isEmpty {
        first.stopTracking()
        second.stopTracking()
        locked = false
        try geometry.reset()
      }
      return StereoCameraTrackingFrame(
        firstFaces: a.faces.count, secondFaces: b.faces.count, pose: nil)
    }
    let newUser = !locked
    if newUser {
      try first.startTracking(ids: [face0.id])
      try second.startTracking(ids: [face1.id])
      locked = true
    }
    let mapping = LandmarkProcessing.defaultModelMapping68
    let pose = try geometry.update(
      first: mapping.map { face0.landmarks[$0] }, second: mapping.map { face1.landmarks[$0] },
      frameNumber: frame, captureTimestamp: captureTimestamp, now: now(), newUser: newUser)
    return StereoCameraTrackingFrame(firstFaces: 1, secondFaces: 1, pose: pose)
  }
}
