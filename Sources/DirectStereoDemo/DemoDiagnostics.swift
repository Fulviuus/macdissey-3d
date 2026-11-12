import Foundation
import simd

/// Bounded aggregate measurements. Reports contain variation and timing, never
/// camera images, absolute eye positions, calibration or monitor identifiers.
struct DemoDiagnostics {
  private let traceEnabled: Bool
  private var traceOrigin: SIMD3<Float>?
  private var traceTimeOrigin: Double?
  private var traceIPDOrigin: Float = 0
  private var trace: [[Double]] = []
  var frames = 0
  var invalidFramesAfterTracking = 0
  var trackingTransitions = 0
  var distinctPoses = 0
  var largestPoseStepMillimetres: Float = 0
  private var previousValid: Bool?
  private var hasTracked = false
  private var lastTimestamp: Double?
  private var lastMidpoint: SIMD3<Float>?
  private var lastFrameTime: Double?
  private var axes = [DemoMoments(), DemoMoments(), DemoMoments()]
  private var ipd = DemoMoments(), age = DemoMoments()
  private var sceneAxes = [DemoMoments(), DemoMoments(), DemoMoments()]
  var intervals = DemoMoments(), presentationWait = DemoMoments(), gpu = DemoMoments()
  var rasterSamples = 1
  var viewpointMode = "unspecified"

  init(trace: Bool = false) { traceEnabled = trace }

  mutating func recordScene(midpointMetres: SIMD3<Float>) {
    for axis in 0..<3 { sceneAxes[axis].add(Double(midpointMetres[axis]) * 1000) }
  }

  mutating func record(
    midpointCentimetres: SIMD3<Float>, ipdMillimetres: Float, timestamp: Double,
    valid: Bool, now: Double
  ) {
    frames += 1
    if let previous = lastFrameTime { intervals.add((now - previous) * 1000) }
    lastFrameTime = now
    if let previous = previousValid, hasTracked && previous != valid { trackingTransitions += 1 }
    previousValid = valid
    if !valid {
      if hasTracked { invalidFramesAfterTracking += 1 }
      return
    }
    hasTracked = true
    age.add((now - timestamp) * 1000)
    guard timestamp.isFinite, lastTimestamp.map({ timestamp > $0 }) ?? true,
      (0..<3).allSatisfy({ midpointCentimetres[$0].isFinite }), ipdMillimetres.isFinite
    else { return }
    distinctPoses += 1
    if traceEnabled && trace.count < 2048 {
      if traceOrigin == nil {
        traceOrigin = midpointCentimetres
        traceTimeOrigin = timestamp
        traceIPDOrigin = ipdMillimetres
      }
      let delta = (midpointCentimetres - traceOrigin!) * 10
      trace.append([
        timestamp - traceTimeOrigin!, Double(delta.x), Double(delta.y), Double(delta.z),
        Double(ipdMillimetres - traceIPDOrigin),
      ])
    }
    if let previous = lastMidpoint {
      largestPoseStepMillimetres = max(
        largestPoseStepMillimetres, simd_distance(midpointCentimetres, previous) * 10)
    }
    for i in 0..<3 { axes[i].add(Double(midpointCentimetres[i]) * 10) }
    ipd.add(Double(ipdMillimetres))
    lastMidpoint = midpointCentimetres
    lastTimestamp = timestamp
  }

  func write(to path: String, eyeWidth: Int, eyeHeight: Int, displayRefreshRate: Double) throws {
    var report: [String: Any] = [
      "eyeWidth": eyeWidth, "eyeHeight": eyeHeight, "displayRefreshRateHz": displayRefreshRate,
      "rasterSamples": rasterSamples, "viewpointMode": viewpointMode,
      "renderedFrames": frames, "distinctTrackingSamples": distinctPoses,
      "invalidFramesAfterTracking": invalidFramesAfterTracking,
      "trackingValidityTransitions": trackingTransitions,
      "trackingRangeMillimetresXYZ": axes.map { $0.range },
      "trackingStandardDeviationMillimetresXYZ": axes.map { $0.standardDeviation },
      "sceneCameraStandardDeviationMillimetresXYZ": sceneAxes.map { $0.standardDeviation },
      "largestTrackingStepMillimetres": largestPoseStepMillimetres,
      "ipdRangeMillimetres": ipd.range, "ipdStandardDeviationMillimetres": ipd.standardDeviation,
      "trackingAgeMilliseconds": age.summary,
      "producerFrameIntervalMilliseconds": intervals.summary,
      "presentationWaitMilliseconds": presentationWait.summary,
      "producerGPUTimeMilliseconds": gpu.summary,
    ]
    if traceEnabled { report["relativeTrackingTrace"] = trace }
    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
      .write(to: URL(fileURLWithPath: path), options: .atomic)
  }
}

struct DemoMoments {
  private var count = 0
  private var mean = 0.0, squaredDeviation = 0.0
  private var minimum = Double.infinity, maximum = -Double.infinity
  mutating func add(_ value: Double) {
    guard value.isFinite else { return }
    count += 1
    let delta = value - mean
    mean += delta / Double(count)
    squaredDeviation += delta * (value - mean)
    minimum = min(minimum, value)
    maximum = max(maximum, value)
  }
  var range: Double { count > 0 ? maximum - minimum : 0 }
  var standardDeviation: Double { count > 0 ? sqrt(max(0, squaredDeviation / Double(count))) : 0 }
  var summary: [String: Any] {
    ["samples": count, "mean": mean, "maximum": count > 0 ? maximum : 0]
  }
}
