import Foundation
import simd

@main enum DirectStereoViewpointChecks {
  static func main() throws {
    if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--replay" {
      try replay(CommandLine.arguments[2])
      return
    }
    let centre = SIMD3<Float>(0, 0, 0.6)
    for fps in [30, 60, 120, 240] {
      var filter = DemoViewpointFilter()
      var inputEnergy: Float = 0
      var outputEnergy: Float = 0
      var ipdInputEnergy: Float = 0
      var ipdOutputEnergy: Float = 0
      for i in 0..<(fps * 4) {
        let time = Double(i) / Double(fps)
        let noise = Float(sin(time * 2 * .pi * 9)) * 0.002
        let ipdNoise = Float(sin(time * 2 * .pi * 7)) * 0.004
        let result = filter.update(
          midpoint: centre + SIMD3(noise, 0, 0), ipd: 0.063 + ipdNoise,
          sampleTime: time, now: time)
        if i > fps {
          inputEnergy += noise * noise
          outputEnergy += result.midpoint.x * result.midpoint.x
          ipdInputEnergy += ipdNoise * ipdNoise
          ipdOutputEnergy += (result.ipd - 0.063) * (result.ipd - 0.063)
        }
      }
      precondition(outputEnergy < inputEnergy * 0.40, "Stationary camera jitter must be reduced")
      precondition(
        ipdOutputEnergy < ipdInputEnergy * 0.08, "Eye-separation noise must not pump depth")

      // Real movement remains responsive, monotonic and without overshoot. The
      // limit is scene-camera lag in this signal, not an end-to-end latency claim.
      filter = DemoViewpointFilter()
      var maximumLag: Float = 0
      for i in 0..<(fps * 2) {
        let time = Double(i) / Double(fps)
        let x = Float(min(time, 0.4)) * 0.25
        let result = filter.update(
          midpoint: centre + SIMD3(x, 0, 0), ipd: 0.063, sampleTime: time, now: time)
        maximumLag = max(maximumLag, x - result.midpoint.x)
        precondition(result.midpoint.x >= 0 && result.midpoint.x <= x + 0.000_001)
      }
      precondition(
        maximumLag < 0.01, "Ordinary head movement must not accumulate a large camera lag")
      precondition(abs(filter.value.midpoint.x - 0.1) < 0.000_01)
      print("PASS scene camera: \(fps) Hz jitter suppression, stable IPD and bounded movement lag")
    }

    // Synthetic stress shaped by the observed failure: roughly 12 mm depth
    // deviation and occasional 20 mm steps at ~50 observations/s, rendered at
    // 165 Hz. This is not a replay of the user's aggregate-only report.
    var stress = DemoViewpointFilter()
    var lastObservation = -1
    var observed = centre
    var rawProjection = DemoMoments()
    var stableProjection = DemoMoments()
    var depthVariation = DemoMoments()
    func project(_ point: SIMD3<Float>) -> Double {
      let object = SIMD3<Float>(0.15, 0.02, -0.06)
      let x = (object.x * point.z - point.x * object.z) / (point.z - object.z)
      return Double(x / 0.597 * 3840)
    }
    for frame in 0..<(165 * 8) {
      let now = Double(frame) / 165
      let observation = Int(now * 50)
      if observation != lastObservation {
        let t = Double(observation) / 50
        observed =
          centre
          + SIMD3(
            Float(sin(t * 2 * .pi * 11)) * 0.0008,
            Float(sin(t * 2 * .pi * 9)) * 0.0012,
            Float(sin(t * 2 * .pi * 7)) * 0.016)
        if observation % 127 == 0 { observed.z += 0.02 }
        lastObservation = observation
      }
      let result = stress.update(
        midpoint: observed, ipd: 0.063, sampleTime: Double(observation) / 50, now: now)
      if frame > 165 * 2 {
        rawProjection.add(project(observed))
        stableProjection.add(project(result.midpoint))
        depthVariation.add(Double(result.midpoint.z))
      }
    }
    precondition(
      stableProjection.standardDeviation < 0.5,
      "Stationary image must remain within half a physical pixel RMS")
    precondition(
      stableProjection.standardDeviation < rawProjection.standardDeviation * 0.25,
      "Large depth noise must not raise lateral smoothing gain")
    precondition(
      depthVariation.standardDeviation > 0, "The regression must not pass by freezing tracking")
    print(
      String(
        format:
          "PASS 50 Hz observations / 165 Hz rendering: projected jitter %.3f → %.3f physical pixels RMS",
        rawProjection.standardDeviation, stableProjection.standardDeviation))

    // A 30 Hz observation stream drives smooth intermediate 120 Hz frames.
    var filter = DemoViewpointFilter()
    _ = filter.update(midpoint: centre, ipd: 0.063, sampleTime: 0, now: 0)
    let target = centre + SIMD3<Float>(0.03, 0, 0)
    let first = filter.update(midpoint: target, ipd: 0.063, sampleTime: 0.03, now: 0.03)
    let between = filter.update(midpoint: target, ipd: 0.063, sampleTime: 0.03, now: 0.038)
    precondition(between.midpoint.x > first.midpoint.x && between.midpoint.x < target.x)

    let held = filter.value
    for i in 1...30 {
      let result = filter.update(
        midpoint: nil, ipd: 0, sampleTime: 0, now: 0.038 + Double(i) / 120)
      precondition(result == held, "Tracking loss must hold the scene camera instead of recentring")
    }
    let reacquired = filter.update(
      midpoint: centre + SIMD3(0.08, 0, 0), ipd: 0.067, sampleTime: 0.30, now: 0.30)
    precondition(reacquired.midpoint.x > held.midpoint.x && reacquired.midpoint.x < 0.08)
    precondition(reacquired.ipd > held.ipd && reacquired.ipd < 0.067)

    // Invalid, stale and regressing observations never poison the projection.
    let before = filter.value
    for (point, ipd, sample, now) in [
      (SIMD3<Float>(.nan, 0, 0.6), Float(0.063), 0.31, 0.31),
      (centre, Float.nan, 0.32, 0.32),
      (centre, Float(0.063), 0.01, 0.33),
      (centre, Float(0.063), 0.5, 0.34),
      (centre, Float(0.063), 0.29, 0.35),
      (centre, Float(0.063), 0.36, Double.nan),
    ] {
      precondition(filter.update(midpoint: point, ipd: ipd, sampleTime: sample, now: now) == before)
    }

    var raw = DemoViewpointFilter()
    var fixed = DemoViewpointFilter()
    for i in 0..<10 {
      let time = Double(i) / 120
      let point = centre + SIMD3<Float>(Float(i) * 0.01, 0, 0)
      let rawResult = raw.update(
        midpoint: point, ipd: 0.064, sampleTime: time, now: time, mode: .raw)
      precondition(rawResult.midpoint == point && rawResult.ipd == 0.064)
      let fixedResult = fixed.update(
        midpoint: point, ipd: 0.064, sampleTime: time, now: time, mode: .fixed)
      precondition(fixedResult == DemoViewpoint())
    }
    print(
      "PASS scene camera: continuous frames, dropout hold, reacquisition, invalid inputs and raw/fixed comparisons"
    )
    var diagnostics = DemoDiagnostics()
    for (x, time, valid) in [
      (Float(-2), 0.0, true), (-1, 0.02, true), (-1, 0.03, false), (-1, 0.04, true),
    ] {
      diagnostics.record(
        midpointCentimetres: SIMD3(x, 0, 60), ipdMillimetres: 63, timestamp: time,
        valid: valid, now: time + 0.01)
    }
    let report = FileManager.default.temporaryDirectory.appendingPathComponent(
      "stereo-check-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: report) }
    try diagnostics.write(to: report.path, eyeWidth: 1920, eyeHeight: 2160, displayRefreshRate: 165)
    let values = try JSONSerialization.jsonObject(with: Data(contentsOf: report)) as! [String: Any]
    precondition(values["renderedFrames"] as? Int == 4)
    precondition(values["distinctTrackingSamples"] as? Int == 3)
    precondition(values["invalidFramesAfterTracking"] as? Int == 1)
    precondition(values["trackingValidityTransitions"] as? Int == 2)
    precondition(values["trackingRangeMillimetresXYZ"] as? [Double] == [10, 0, 0])
    precondition(values["largestTrackingStepMillimetres"] as? Double == 10)
    precondition(values["midpointCentimetres"] == nil)
    precondition(values["relativeTrackingTrace"] == nil)
    var traced = DemoDiagnostics(trace: true)
    for i in 0..<3000 {
      let time = Double(i) / 50
      traced.record(
        midpointCentimetres: SIMD3(12 + Float(i) * 0.001, -3, 80), ipdMillimetres: 64,
        timestamp: time, valid: true, now: time + 0.01)
    }
    try traced.write(to: report.path, eyeWidth: 1920, eyeHeight: 2160, displayRefreshRate: 165)
    let tracedValues =
      try JSONSerialization.jsonObject(with: Data(contentsOf: report)) as! [String: Any]
    let samples = tracedValues["relativeTrackingTrace"] as! [[Double]]
    precondition(samples.count == 2048 && samples[0] == [0, 0, 0, 0, 0])
    print(
      "PASS diagnostics: signed position variation, dropout transitions and bounded aggregate JSON")
  }

  static func replay(_ path: String) throws {
    let report =
      try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)))
      as! [String: Any]
    let trace = report["relativeTrackingTrace"] as! [[Double]]
    precondition(trace.count >= 20)
    var filter = DemoViewpointFilter()
    var raw = [DemoMoments](repeating: DemoMoments(), count: 6)
    var stable = raw
    var cameraAxes = [DemoMoments](repeating: DemoMoments(), count: 3)
    let points: [SIMD3<Float>] = [
      SIMD3(-0.22, 0.10, -0.078), SIMD3(0.22, 0.10, -0.078), SIMD3(0, -0.10, -0.05),
    ]
    var index = 0
    let fps = 165.0
    for frame in 0..<Int(trace.last![0] * fps) {
      let now = Double(frame) / fps
      while index + 1 < trace.count && trace[index + 1][0] <= now { index += 1 }
      let observation = trace[index]
      let midpoint = SIMD3<Float>(
        Float(observation[1] / 1000), Float(observation[2] / 1000),
        0.6 + Float(observation[3] / 1000))
      let value = filter.update(
        midpoint: midpoint, ipd: 0.063 + Float(observation[4] / 1000), sampleTime: observation[0],
        now: now)
      if now > 2 {
        for axis in 0..<3 { cameraAxes[axis].add(Double(value.midpoint[axis]) * 1000) }
        for (i, p) in points.enumerated() {
          func projection(_ eye: SIMD3<Float>, axis: Int) -> Double {
            let dimension: Float = axis == 0 ? 0.597 : 0.336
            let pixels: Float = axis == 0 ? 3840 : 2160
            return Double((p[axis] * eye.z - eye[axis] * p.z) / (eye.z - p.z) / dimension * pixels)
          }
          for axis in 0..<2 {
            raw[i * 2 + axis].add(projection(midpoint, axis: axis))
            stable[i * 2 + axis].add(projection(value.midpoint, axis: axis))
          }
        }
      }
    }
    print("REPLAY stationary relative trace: \(trace.count) samples, \(trace.last![0]) seconds")
    print("Scene camera deviation mm XYZ: \(cameraAxes.map { $0.standardDeviation })")
    for i in 0..<6 {
      print(
        String(
          format: "Projected jitter at reference %d: raw %.3f, filtered %.3f physical pixels RMS",
          i, raw[i].standardDeviation, stable[i].standardDeviation))
    }
  }
}
