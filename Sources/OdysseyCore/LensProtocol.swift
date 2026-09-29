import Foundation

/// Recovered from the user's USBPcap recording. Commands end with CR;
/// responses arrive in multiple USB transfers and terminate with CRLF OK CRLF.
public enum LensCommand {
  case status
  case lensSerial
  case calibrationSerial
  case information
  case setEnabled(Bool)

  public var bytes: Data {
    switch self {
    case .status: return Data("SR+LENS\r".utf8)
    case .lensSerial: return Data("SR+SERIAL\r".utf8)
    case .calibrationSerial: return Data("SR+SER4\r".utf8)
    case .information: return Data("SR+INFO\r".utf8)
    case .setEnabled(let enabled): return Data("SR+LENS=\(enabled ? 1 : 0)\r".utf8)
    }
  }
}

public enum LensProtocolError: Error { case oversizedResponse, rejected, malformed }

public struct LensResponse {
  public private(set) var bytes = Data()
  public init() {}
  public mutating func append(_ data: Data) throws {
    guard bytes.count + data.count <= 4096 else { throw LensProtocolError.oversizedResponse }
    bytes.append(data)
    if lines.contains("ERROR") { throw LensProtocolError.rejected }
  }
  private var lines: [String] {
    String(decoding: bytes, as: UTF8.self).components(separatedBy: "\r\n").filter { !$0.isEmpty }
  }
  public var complete: Bool { bytes.suffix(6) == Data("\r\nOK\r\n".utf8) }
  public func textPayload() throws -> String {
    guard complete, bytes.prefix(2) == Data([13, 10]),
      let value = String(data: bytes.dropFirst(2).dropLast(6), encoding: .ascii)
    else { throw LensProtocolError.malformed }
    return value
  }
  public func enabled() throws -> Bool {
    guard complete else { throw LensProtocolError.malformed }
    let values = lines.filter { $0 != "OK" }
    guard values == ["0"] || values == ["1"] else { throw LensProtocolError.malformed }
    return values == ["1"]
  }

  public func serialNumber() throws -> String {
    guard complete else { throw LensProtocolError.malformed }
    let values = lines.filter { $0 != "OK" }
    guard values.count == 1 else { throw LensProtocolError.malformed }
    let value = values[0].trimmingCharacters(in: .whitespaces)
    // Both serial queries in the capture return a 14-character identity;
    // SER4 additionally pads the value with spaces to 32 bytes.
    guard value.utf8.count == 14,
      value.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) })
    else {
      throw LensProtocolError.malformed
    }
    return value
  }
}

public struct LensIdentity: Codable {
  public let lensSerial: String
  public let calibrationSerial: String

  public init(lensSerial: String, calibrationSerial: String) {
    self.lensSerial = lensSerial
    self.calibrationSerial = calibrationSerial
  }

  /// SREyeTracker 1.11.0, VA 0x1400ff270, reads characters 8 and 9.
  public var productCode: String { String(calibrationSerial.dropFirst(8).prefix(2)) }
}
