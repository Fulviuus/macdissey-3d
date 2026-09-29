import Foundation
import OdysseyCore

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else { fatalError(message) }
}

for state in [false, true] {
  let bytes = Data("\r\n\(state ? 1 : 0)\r\nOK\r\n".utf8)
  for split in 0..<bytes.count {
    var response = LensResponse()
    try response.append(bytes.prefix(split))
    check(!response.complete, "Partial USB transfer treated as complete response")
    try response.append(bytes.dropFirst(split))
    let enabled = try response.enabled()
    check(enabled == state, "Wrong lens state")
  }
}
var invalid = LensResponse()
try invalid.append(Data("\r\n7\r\nOK\r\n".utf8))
do {
  _ = try invalid.enabled()
  fatalError("Invalid lens state accepted")
} catch LensProtocolError.malformed {}
var overflow = LensResponse()
do {
  try overflow.append(Data(repeating: 0, count: 4097))
  fatalError("Unbounded response accepted")
} catch LensProtocolError.oversizedResponse {}
check(
  LensCommand.status.bytes == Data([0x53, 0x52, 0x2b, 0x4c, 0x45, 0x4e, 0x53, 0x0d]),
  "Query differs from capture")
check(
  LensCommand.setEnabled(true).bytes == Data("SR+LENS=1\r".utf8),
  "Enable command differs from capture")
check(
  LensCommand.setEnabled(false).bytes == Data("SR+LENS=0\r".utf8),
  "Disable command differs from capture")
for serial in ["TEST0000HR0001", "TEST0000ET0001                  "] {
  let bytes = Data((serial + "\r\nOK\r\n").utf8)
  for split in 0..<bytes.count {
    var reply = LensResponse()
    try reply.append(bytes.prefix(split))
    check(!reply.complete, "Partial identity accepted")
    try reply.append(bytes.dropFirst(split))
    let parsed = try reply.serialNumber()
    check(
      parsed == serial.trimmingCharacters(in: .whitespaces),
      "Identity padding or fragmentation changed the serial")
  }
}
var wrongIdentity = LensResponse()
try wrongIdentity.append(Data("TEST0000ET0001\r\nEXTRA\r\nOK\r\n".utf8))
do {
  _ = try wrongIdentity.serialNumber()
  fatalError("Multiple identity lines accepted")
} catch LensProtocolError.malformed {}
check(
  LensCommand.lensSerial.bytes == Data("SR+SERIAL\r".utf8),
  "Lens identity command differs from capture")
check(
  LensCommand.calibrationSerial.bytes == Data("SR+SER4\r".utf8),
  "Calibration identity command differs from capture")
let identity = LensIdentity(lensSerial: "TEST0000HR0001", calibrationSerial: "TEST0000ET0001")
check(identity.productCode == "ET", "Product selection differs from native runtime")
print("PASS: fragmented lens replies, malformed replies, bounded responses, captured commands")
