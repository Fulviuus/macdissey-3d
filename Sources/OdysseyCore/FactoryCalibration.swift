import CryptoKit
import Foundation

// Recovered from the normally initialized LeiaSR 1.36.4 SRService.exe.
// These commands read the controller; they do not write calibration or firmware.
public enum FactoryCalibrationCommand: String, CaseIterable {
  case camera = "SR+CALCAM"
  case tracker = "SR+CALET"
  case optics = "SR+CAL3D"
  public var bytes: Data { Data((rawValue + "\r").utf8) }
  public var payloadSize: Int { self == .optics ? 0x20000 : 0x100 }
  public var timeout: TimeInterval { self == .optics ? 10 : 2 }
}

public struct FactoryCalibrationResponse {
  public let command: FactoryCalibrationCommand
  private var response: FixedLengthLensResponse
  public init(command: FactoryCalibrationCommand) {
    self.command = command
    response = FixedLengthLensResponse(payloadSize: command.payloadSize)
  }
  public var bytes: Data { response.bytes }
  public var complete: Bool { response.complete }
  public mutating func append(_ data: Data) throws { try response.append(data) }
  public func payload() throws -> Data { try response.payload() }
}

public struct FixedLengthLensResponse {
  public let payloadSize: Int
  private let prefix: Data
  public private(set) var bytes = Data()
  public init(payloadSize: Int, prefix: Data = Data([13, 10])) {
    precondition((0...131072).contains(payloadSize) && prefix.count <= 2)
    self.payloadSize = payloadSize
    self.prefix = prefix
  }
  public var expectedSize: Int { prefix.count + payloadSize + 6 }
  public var complete: Bool { bytes.count == expectedSize }
  public mutating func append(_ data: Data) throws {
    guard data.count <= expectedSize - bytes.count else {
      throw LensProtocolError.oversizedResponse
    }
    bytes.append(data)
    if bytes == Data("\r\nERROR NOT AUTHENTICATED\r\n".utf8) { throw LensProtocolError.rejected }
    // Binary payloads may contain CRLF OK CRLF internally. Only the fixed
    // boundary is a terminator; SRService reads exactly payloadSize+8 bytes.
    if complete { _ = try payload() }
  }
  public func payload() throws -> Data {
    guard complete, bytes.prefix(prefix.count) == prefix, bytes.suffix(6) == Data("\r\nOK\r\n".utf8)
    else { throw LensProtocolError.malformed }
    return Data(bytes.dropFirst(prefix.count).dropLast(6))
  }
}

public enum FactoryCalibrationError: Error {
  case truncated, unsupportedVersion, invalidSize, nonfinite, invalidChip, invalidArchive
}

private struct CalibrationBytes {
  let data: Data
  func word(_ offset: Int) throws -> UInt32 {
    guard offset >= 0, offset <= data.count - 4 else { throw FactoryCalibrationError.truncated }
    return data.withUnsafeBytes {
      UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }
  }
  func doubles(_ count: Int, at offset: Int) throws -> [Double] {
    guard offset >= 0, count >= 0, offset <= data.count, count <= (data.count - offset) / 8
    else { throw FactoryCalibrationError.truncated }
    return try (0..<count).map { index in
      let bits = data.withUnsafeBytes {
        UInt64(littleEndian: $0.loadUnaligned(fromByteOffset: offset + index * 8, as: UInt64.self))
      }
      let value = Double(bitPattern: bits)
      guard value.isFinite else { throw FactoryCalibrationError.nonfinite }
      return value
    }
  }
  func header(size: Int) throws {
    guard try word(0) == size else { throw FactoryCalibrationError.invalidSize }
    guard try word(4) == 1 else { throw FactoryCalibrationError.unsupportedVersion }
    guard data.count >= size else { throw FactoryCalibrationError.truncated }
  }
}

public struct FactoryCameraCalibration: Codable {
  // fx, fy, cx, cy per view; both distortion vectors retain all eight values.
  public let leftIntrinsics, rightIntrinsics, leftDistortion, rightDistortion: [Double]
  public let rotationVector, translation: [Double]
  public init(payload: Data) throws {
    let reader = CalibrationBytes(data: payload)
    try reader.header(size: 248)
    leftIntrinsics = try reader.doubles(4, at: 8)
    rightIntrinsics = try reader.doubles(4, at: 40)
    leftDistortion = try reader.doubles(8, at: 72)
    rightDistortion = try reader.doubles(8, at: 136)
    rotationVector = try reader.doubles(3, at: 200)
    translation = try reader.doubles(3, at: 224)
  }
}

public struct FactoryTrackerCalibration: Codable {
  public let translationCentimetres: [Double]
  public let rotationDegrees: [Double]
  public init(payload: Data) throws {
    let reader = CalibrationBytes(data: payload)
    try reader.header(size: 56)
    translationCentimetres = try reader.doubles(3, at: 8)
    rotationDegrees = try reader.doubles(3, at: 32)
  }
  public var ini: String {
    let values = translationCentimetres + rotationDegrees
    let names = ["Xoff_cm", "Yoff_cm", "Zoff_cm", "Xrot_deg", "Yrot_deg", "Zrot_deg"]
    return "[Transform]\r\n"
      + zip(names, values).map {
        $0 + "=" + String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), $1)
      }.joined(separator: "\r\n") + "\r\n"
  }
}

public enum FactoryOpticsCalibration {
  public static func archive(payload: Data) throws -> Data {
    let reader = CalibrationBytes(data: payload)
    let size = Int(try reader.word(0))
    guard size > 0, size <= payload.count - 4 else { throw FactoryCalibrationError.invalidSize }
    let archive = Data(payload.dropFirst(4).prefix(size))
    guard archive.prefix(6) == Data([0x37, 0x7a, 0xbc, 0xaf, 0x27, 0x1c]) else {
      throw FactoryCalibrationError.invalidArchive
    }
    return archive
  }
  public static func archivePassword(chipIdentity: Data) throws -> String {
    // SRService uses the exact 32 bytes returned by SR+CHIP, not the serial
    // or a user password. Preserve padding and case.
    guard chipIdentity.count == 32, chipIdentity.allSatisfy({ (32...126).contains($0) })
    else { throw FactoryCalibrationError.invalidChip }
    return SHA256.hash(data: chipIdentity + Data("FEwCid:-(Twb2Mw.".utf8))
      .map { String(format: "%02x", $0) }.joined()
  }
}
