import Foundation
import OdysseyVision

public enum TrackedFaceState: Int {
  case new = 0
  case tracked = 1
  case recovering = 2
}
public struct TrackedFace {
  public let id: Int
  public let state: TrackedFaceState
  public let region: NormalizedFaceRegion
  public let landmarks: [SIMD2<Float>]
  public let confidence: Float
  public let detectionConfidence: Float
}
public struct FaceTrackingFrame {
  public let detectionWasDue: Bool
  public let faces: [TrackedFace]
}

/// Default Blink video-mode face scheduling. One instance belongs to one camera
/// stream and must be called serially. Clock units match the vendor's 100 ns
/// ticks; injectable time permits comparison with its deterministic test clock.
public final class FaceTracker {
  private struct Face {
    var region: NormalizedFaceRegion
    var state: TrackedFaceState = .new
    var landmarks: [SIMD2<Float>] = []
    var confidence: Float = 0
    var detectionConfidence: Float
    var lastUpdate: Int64
    var frame: UInt64 = 0
  }
  private let detector: FaceDetector
  private let landmarkRunner: LandmarkRunner
  private let clock: () -> Int64
  private let maximumFaces: Int
  private var faces: [Int: Face] = [:]
  private var frameNumber: UInt64 = 0
  private var lastDetection: Int64 = 0
  private var width = 0, height = 0
  private var detectionDue = true
  private var selectedIDs: [Int] = []
  public init(
    detector: FaceDetector, landmarkRunner: LandmarkRunner, maximumFaces: Int = 4,
    clock: @escaping () -> Int64 = { Int64(DispatchTime.now().uptimeNanoseconds / 100) }
  ) throws {
    guard maximumFaces > 0, maximumFaces <= 16 else { throw TrackingMathError.invalidInput }
    self.detector = detector
    self.landmarkRunner = landmarkRunner
    self.maximumFaces = maximumFaces
    self.clock = clock
  }

  /// Blink's explicit face lock removes other faces and suppresses detection
  /// until stopTracking, including when the selected face subsequently expires.
  public func startTracking(ids: [Int]) throws {
    guard ids.allSatisfy({ faces[$0] != nil }) else { throw TrackingMathError.invalidInput }
    selectedIDs = ids
    faces = faces.filter { ids.contains($0.key) }
  }
  public func stopTracking() {
    selectedIDs.removeAll(keepingCapacity: true)
    faces.removeAll(keepingCapacity: true)
  }

  private func beginFrame(width: Int, height: Int) {
    let now = clock()
    for id in faces.keys.sorted() {
      guard var face = faces[id] else { continue }
      if (now - face.lastUpdate) / 10_000 > 500 {
        faces[id] = nil
        continue
      }
      if face.frame < frameNumber { face.state = .tracked }
      face.landmarks = []
      face.frame = frameNumber
      faces[id] = face
    }
    let elapsed = (clock() - lastDetection) / 10_000
    detectionDue =
      selectedIDs.isEmpty && (faces.isEmpty || elapsed > 1000) && faces.count != maximumFaces
    self.width = width
    self.height = height
  }
  private static func intersection(_ a: NormalizedFaceRegion, _ b: NormalizedFaceRegion) -> (
    Double, Double, Double
  ) {
    let left = max(
      Double(a.center.x) - Double(a.size.x) * 0.5, Double(b.center.x) - Double(b.size.x) * 0.5)
    let right = min(
      Double(a.center.x) + Double(a.size.x) * 0.5, Double(b.center.x) + Double(b.size.x) * 0.5)
    let top = max(
      Double(a.center.y) - Double(a.size.y) * 0.5, Double(b.center.y) - Double(b.size.y) * 0.5)
    let bottom = min(
      Double(a.center.y) + Double(a.size.y) * 0.5, Double(b.center.y) + Double(b.size.y) * 0.5)
    let areaA = Double(a.size.x * a.size.y)
    let areaB = Double(b.size.x * b.size.y)
    return (right < left || bottom < top ? 0 : (bottom - top) * (right - left), areaA, areaB)
  }
  private func record(
    _ region: NormalizedFaceRegion, id explicitID: Int? = nil, detectionConfidence: Float? = nil
  ) -> Int {
    let now = clock()
    var id = explicitID
    if id == nil {
      id = faces.keys.sorted().first { key in
        let (intersection, areaA, areaB) = Self.intersection(faces[key]!.region, region)
        return intersection / ((areaB + areaA) - intersection) > 0.3
      }
      if id == nil {
        var available = 0
        while faces[available] != nil { available += 1 }
        id = available
      }
    }
    let key = id!
    if var face = faces[key] {
      if detectionConfidence == nil || (now - face.lastUpdate) / 10_000 > 500 {
        face.region = region
        if let confidence = detectionConfidence { face.detectionConfidence = confidence }
      }
      if detectionConfidence != nil { face.lastUpdate = now }
      faces[key] = face
    } else {
      faces[key] = Face(
        region: region, detectionConfidence: detectionConfidence ?? 0, lastUpdate: now)
    }
    return key
  }
  private func landmarks(id: Int, pixels: [UInt8], stride: Int, force: Bool) throws -> Bool {
    guard let old = faces[id] else { throw TrackingMathError.invalidInput }
    let result = try landmarkRunner.execute(
      pixels: pixels, width: width, height: height, stride: stride, region: old.region)
    guard result.confidence > 0.5 || force else { return false }
    _ = record(result.nextRegion, id: id)
    guard var face = faces[id] else { throw TrackingMathError.invalidInput }
    face.confidence = result.confidence
    face.landmarks = result.landmarks.map { SIMD2(Float(width) * $0.x, Float(height) * $0.y) }
    if face.frame < frameNumber { face.state = .tracked }
    face.frame = frameNumber
    face.lastUpdate = clock()
    faces[id] = face
    return true
  }
  private func pruneRegions() {
    var remove: Set<Int> = []
    let ids = faces.keys.sorted()
    for a in ids {
      let region = faces[a]!.region
      for b in ids where b != a {
        let (intersection, areaA, areaB) = Self.intersection(region, faces[b]!.region)
        if intersection > 0.000001
          && (abs(intersection - areaA) < 0.000001 || abs(intersection - areaB) < 0.000001)
        {
          let ratio = areaA <= areaB ? areaB / areaA : areaA / areaB
          if ratio <= 3 || ratio >= 5 {
            remove.insert(areaB <= areaA ? a : b)
          } else {
            remove.insert(areaB <= areaA ? b : a)
          }
        }
      }
      let left = max(0, Double(region.center.x) - Double(region.size.x) * 0.5)
      let right = min(1, Double(region.center.x) + Double(region.size.x) * 0.5)
      let top = max(0, Double(region.center.y) - Double(region.size.y) * 0.5)
      let bottom = min(1, Double(region.center.y) + Double(region.size.y) * 0.5)
      let ratio = ((Double(height) / Double(width)) * (bottom - top)) / (right - left)
      if ratio < 0.2 || ratio > 5 { remove.insert(a) }
    }
    for id in remove.sorted() {
      _ = clock()
      faces[id] = nil
    }
  }
  public func execute(pixels: [UInt8], width: Int, height: Int, stride: Int) throws
    -> FaceTrackingFrame
  {
    guard width > 0, width <= 8192, height > 0, height <= 8192, stride >= width,
      stride <= Int.max / height, pixels.count >= stride * (height - 1) + width
    else { throw TrackingMathError.invalidInput }
    beginFrame(width: width, height: height)
    let wasDue = detectionDue
    var detected: [FaceDetection] = []
    if wasDue {
      lastDetection = clock()
      detected = try detector.execute(pixels: pixels, width: width, height: height, stride: stride)
      if detected.isEmpty && !faces.values.contains(where: { $0.state.rawValue < 2 }) {
        var enhanced = Array(repeating: UInt8(0), count: width * height)
        guard
          odyssey_face_clahe(
            pixels, pixels.count, Int32(width), Int32(height), stride, &enhanced, enhanced.count)
            == 0
        else {
          throw TrackingMathError.invalidInput
        }
        beginFrame(width: width, height: height)
        lastDetection = clock()
        detected = try detector.execute(
          pixels: enhanced, width: width, height: height, stride: width)
        beginFrame(width: width, height: height)
      }
    }
    frameNumber += 1
    for face in detected { _ = record(face.landmarkRegion, detectionConfidence: face.confidence) }
    var tracked = 0
    for id in faces.keys.sorted() {
      guard let face = faces[id] else { continue }
      guard tracked < maximumFaces else {
        _ = clock()
        faces[id] = nil
        continue
      }
      if face.state == .new {
        _ = try landmarks(id: id, pixels: pixels, stride: stride, force: true)
      }
      if try landmarks(id: id, pixels: pixels, stride: stride, force: false) {
        tracked += 1
      } else if var current = faces[id] {
        let elapsed = (clock() - current.lastUpdate) / 10_000
        if elapsed > 500 || current.state == .new {
          faces[id] = nil
        } else {
          current.state = .recovering
          current.landmarks = []
          faces[id] = current
        }
      }
    }
    pruneRegions()
    let output = faces.keys.sorted().map { id -> TrackedFace in
      let face = faces[id]!
      return TrackedFace(
        id: id, state: face.state, region: face.region, landmarks: face.landmarks,
        confidence: face.state == .recovering ? 0 : face.confidence,
        detectionConfidence: face.state == .recovering ? 0 : face.detectionConfidence)
    }
    return FaceTrackingFrame(detectionWasDue: wasDue, faces: output)
  }
}
