import Foundation
import OdysseyCore

func requireFailure(_ body: () throws -> Void) {
  do {
    try body()
    fatalError("Malformed calibration accepted")
  } catch {}
}
func word(_ n: UInt32) -> Data {
  var v = n.littleEndian
  return withUnsafeBytes(of: &v) { Data($0) }
}
func doubles(_ values: [Double]) -> Data {
  values.reduce(into: Data()) { result, value in
    var v = value.bitPattern.littleEndian
    result.append(withUnsafeBytes(of: &v) { Data($0) })
  }
}
// Synthetic structural fixtures, not unit calibration or original-writer outputs.
let values = (1...30).map { Double($0) / 8 }
let camera = word(248) + word(1) + doubles(values) + Data(repeating: 0xa5, count: 8)
let parsed = try FactoryCameraCalibration(payload: camera)
precondition(parsed.leftIntrinsics == [0.125, 0.25, 0.375, 0.5])
precondition(parsed.rightIntrinsics == [0.625, 0.75, 0.875, 1])
precondition(parsed.leftDistortion == (9...16).map { Double($0) / 8 })
precondition(parsed.rightDistortion == (17...24).map { Double($0) / 8 })
precondition(
  parsed.rotationVector == [3.125, 3.25, 3.375] && parsed.translation == [3.5, 3.625, 3.75])
let pose = word(56) + word(1) + doubles([-1.25, 2.5, -3.75, 4.125, -5.25, 6.5])
let tracker = try FactoryTrackerCalibration(payload: pose)
precondition(
  tracker.ini
    == "[Transform]\r\nXoff_cm=-1.250000\r\nYoff_cm=2.500000\r\nZoff_cm=-3.750000\r\nXrot_deg=4.125000\r\nYrot_deg=-5.250000\r\nZrot_deg=6.500000\r\n"
)
for size in 0..<248 {
  requireFailure { _ = try FactoryCameraCalibration(payload: Data(camera.prefix(size))) }
}
for size in 0..<56 {
  requireFailure { _ = try FactoryTrackerCalibration(payload: Data(pose.prefix(size))) }
}
for index in 0..<30 {
  var invalid = camera
  invalid.replaceSubrange((8 + index * 8)..<(16 + index * 8), with: doubles([.nan]))
  requireFailure { _ = try FactoryCameraCalibration(payload: invalid) }
}
var badVersion = camera
badVersion.replaceSubrange(4..<8, with: word(2))
requireFailure { _ = try FactoryCameraCalibration(payload: badVersion) }
var badSize = camera
badSize.replaceSubrange(0..<4, with: word(256))
requireFailure { _ = try FactoryCameraCalibration(payload: badSize) }
for command in FactoryCalibrationCommand.allCases {
  var payload = Data(repeating: 0x31, count: command.payloadSize)
  payload.replaceSubrange(12..<18, with: Data("\r\nOK\r\n".utf8))
  payload.replaceSubrange(30..<37, with: Data("\r\nERROR".utf8))
  let framed = Data([13, 10]) + payload + Data("\r\nOK\r\n".utf8)
  for chunkSize in [1, 7, 64, 4096, framed.count] {
    var response = FactoryCalibrationResponse(command: command)
    var at = 0
    while at < framed.count {
      let end = min(at + chunkSize, framed.count)
      try response.append(Data(framed[at..<end]))
      at = end
      precondition(response.complete == (at == framed.count))
    }
    let received = try response.payload()
    precondition(received == payload)
    requireFailure { try response.append(Data([0])) }
  }
  var malformed = FactoryCalibrationResponse(command: command)
  var frame = framed
  frame[frame.count - 1] = 0
  requireFailure { try malformed.append(frame) }
  var rejected = FactoryCalibrationResponse(command: command)
  requireFailure { try rejected.append(Data("\r\nERROR NOT AUTHENTICATED\r\n".utf8)) }
}
let archive = Data([0x37, 0x7a, 0xbc, 0xaf, 0x27, 0x1c, 0, 4])
let extracted = try FactoryOpticsCalibration.archive(
  payload: word(8) + archive + Data(repeating: 0, count: 32))
precondition(extracted == archive)
requireFailure { _ = try FactoryOpticsCalibration.archive(payload: word(40) + archive) }
requireFailure {
  _ = try FactoryOpticsCalibration.archive(payload: word(8) + Data(repeating: 0, count: 8))
}
requireFailure {
  _ = try FactoryOpticsCalibration.archivePassword(chipIdentity: Data("short".utf8))
}
print(
  "PASS: factory framing across 15 chunk patterns; embedded terminators; 304 truncations; nonfinite/version/size rejection; camera/pose field layout; archive bounds. Synthetic structure checks only."
)
