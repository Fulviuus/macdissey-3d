import CryptoKit
import Foundation
import OdysseyCore
import simd

// Synthetic stereo cameras and projected landmarks, never unit calibration.
func payload(size: UInt32, values: [Double]) -> Data {
  var data = Data()
  for word in [size, UInt32(1)] {
    var value = word.littleEndian
    withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
  }
  for number in values {
    var value = number.bitPattern.littleEndian
    withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
  }
  return data
}
let camera = try FactoryCameraCalibration(
  payload: payload(
    size: 248,
    values: [600, 600, 320, 240, 600, 600, 320, 240]
      + [Double](repeating: 0, count: 19) + [-25, 0, 0]))
let tracker = try FactoryTrackerCalibration(
  payload: payload(size: 56, values: [Double](repeating: 0, count: 6)))
let geometry = try StereoTrackingGeometry(camera: camera, tracker: tracker)
var fingerprint = Data()
var poses: [StereoTrackingPose] = []
for i in 1...300 {
  let time = Double(i) / 50
  let headX = Float(sin(time * 2 * .pi * 0.7)) * 10
  let disparityNoise = Float(sin(time * 2 * .pi * 7) * 0.15 + sin(time * 2 * .pi * 13 + 0.4) * 0.06)
  let commonNoise = Float(sin(time * 2 * .pi * 5)) * 0.12
  var first: [SIMD2<Float>] = []
  for index in 0..<68 {
    let x = Float(272 + (index % 17) * 6)
    let y = Float(220 + (index / 17) * 12)
    first.append(SIMD2(x, y))
  }
  for (start, centre) in [(36, Float(-31.5)), (42, Float(31.5))] {
    for p in 0..<6 {
      let angle = Float(p) * 2 * .pi / 6
      first[start + p] = SIMD2(320 + centre * 600 / 700 + 5 * cos(angle), 230 + 2 * sin(angle))
    }
  }
  first = first.map { $0 + SIMD2(headX * 600 / 700 + commonNoise, 0) }
  let second = first.map { $0 + SIMD2(-25 * 600 / 700 + disparityNoise, 0) }
  if let pose = try geometry.update(
    first: first, second: second, frameNumber: UInt64(i), captureTimestamp: time,
    now: time + 0.045)
  {
    poses.append(pose)
    for vector in [
      pose.firstCameraEyeMillimetres, pose.secondCameraEyeMillimetres,
      pose.displayMidpointCentimetres,
    ] {
      for axis in 0..<3 {
        var bits = vector[axis].bitPattern.littleEndian
        withUnsafeBytes(of: &bits) { fingerprint.append(contentsOf: $0) }
      }
    }
  }
}
precondition(poses.count > 250)
let displayTransform = try DisplayTransform(factory: tracker)
var maximumPredictionDifference: Float = 0
for (index, pose) in poses.enumerated() {
  let first = pose.firstCameraEyeMillimetres * Float(0.1)
  let second = pose.secondCameraEyeMillimetres * Float(0.1)
  let observed = try displayTransform.apply(centimetres: (first + second) * Float(0.5))
  precondition(simd_distance(observed, pose.displayViewMidpointCentimetres) < 0.000_01)
  maximumPredictionDifference = max(
    maximumPredictionDifference, simd_distance(observed, pose.displayMidpointCentimetres))
  if index >= 11 {
    let pairs = poses[(index - 11)...index]
    var mean = SIMD3<Double>.zero
    for pair in pairs {
      let a = pair.firstCameraEyeMillimetres * Float(0.1)
      let b = pair.secondCameraEyeMillimetres * Float(0.1)
      mean +=
        SIMD3(Double(b.x) - Double(a.x), Double(b.y) - Double(a.y), Double(b.z) - Double(a.z)) / 12
    }
    let length = Float(simd_length(mean) * 10)
    precondition(abs(length - pose.viewInterpupillaryDistanceMillimetres) < 0.001)
  }
}
precondition(
  maximumPredictionDifference > 0.05, "Scene observations must not reuse optical prediction")
print("Synthetic optical trajectory: \(SHA256.hash(data: fingerprint))")
print("PASS synthetic camera landmarks: \(poses.count) tracked observations")
print(
  "PASS scene feedback: measured display transform, rolling IPD and separate optical prediction")
