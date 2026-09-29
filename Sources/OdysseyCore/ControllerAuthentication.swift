import Foundation

/// Protocol recovered from normally initialized SRService 1.36.4, RVAs
/// 48880/47f00/48e40. Only the observed hardware-16, chip-version-2 path is
/// supported. Both sides of the handshake must validate before factory reads.
public struct ControllerAuthentication {
  public let chip: [UInt8]
  public let secureChip: [UInt8]
  public init(information: String) throws {
    var fields: [String: String] = [:]
    for line in information.components(separatedBy: .newlines) {
      guard let range = line.range(of: ": ") else { continue }
      let name = String(line[..<range.lowerBound])
      guard fields[name] == nil else { throw LensProtocolError.malformed }
      fields[name] = String(line[range.upperBound...])
    }
    guard fields["Hardware"] == "16", fields["Chip version"] == "2",
      let chipText = fields["ChipID"], let secureText = fields["SEChipID"]
    else { throw LensProtocolError.malformed }
    chip = try Self.decodeHex(chipText, bytes: 16)
    secureChip = try Self.decodeHex(secureText, bytes: 16)
  }

  public static func decodeHex(_ value: String, bytes count: Int) throws -> [UInt8] {
    let text = Array(value.utf8)
    guard text.count == count * 2 else { throw LensProtocolError.malformed }
    func nibble(_ c: UInt8) throws -> UInt8 {
      switch c {
      case 48...57: return c - 48
      case 65...70: return c - 55
      case 97...102: return c - 87
      default: throw LensProtocolError.malformed
      }
    }
    return try stride(from: 0, to: text.count, by: 2).map {
      try nibble(text[$0]) << 4 | nibble(text[$0 + 1])
    }
  }
  public static func hex(_ bytes: [UInt8], uppercase: Bool = false) -> String {
    bytes.map { String(format: uppercase ? "%02X" : "%02x", $0) }.joined()
  }
  public func digest(nonce: [UInt8]) throws -> [UInt8] {
    guard nonce.count == 64 else { throw LensProtocolError.malformed }
    // Original protocol key, decoded by SRService RVA 47920. This is the
    // controller's common protocol constant, not a user's credential.
    let key: [UInt8] = [
      0xdb, 0xa4, 0x44, 0xfb, 0x61, 0xc9, 0x06, 0xf2, 0xe7, 0x4c, 0x45, 0xa0, 0xf9, 0xb3, 0x6d,
      0x8d,
    ]
    let prefix =
      Array(secureChip[6..<14]) + [UInt8](repeating: 255, count: 16)
      + [UInt8](repeating: 0, count: 16)
    let derived = SHA3_256.hmac(
      key: key, message: prefix + nonce.prefix(32) + [0x80, secureChip[14], 0])
    return SHA3_256.hmac(key: derived, message: prefix + nonce.suffix(32) + [0, secureChip[14], 0])
  }
  public func verifyDevice(nonce: [UInt8], response: Data) throws {
    guard response.count == 68 else { throw LensProtocolError.malformed }
    let expected = Array(Self.hex(try digest(nonce: nonce)).utf8)
    let received = Array(response.dropFirst(4))
    var difference: UInt8 = 0
    for i in expected.indices { difference |= expected[i] ^ received[i] }
    guard difference == 0 else { throw LensProtocolError.rejected }
  }
  public func hostResponse(deviceNonce: Data) throws -> String {
    guard deviceNonce.count == 132,
      let nonceText = String(data: deviceNonce.prefix(128), encoding: .ascii)
    else { throw LensProtocolError.malformed }
    let digest = try digest(nonce: Self.decodeHex(nonceText, bytes: 64))
    return Self.hex(digest.enumerated().map { $0.element ^ chip[$0.offset % 16] }, uppercase: true)
  }
}

/// SHA3-256's Keccak-f[1600], checked against the original service's
/// RVAs 87860/878e0/87ca0. SHA-3 uses suffix 0x06, not legacy Keccak's 0x01.
public enum SHA3_256 {
  private static let rounds: [UInt64] = [
    0x0000_0000_0000_0001, 0x0000_0000_0000_8082, 0x8000_0000_0000_808a, 0x8000_0000_8000_8000,
    0x0000_0000_0000_808b, 0x0000_0000_8000_0001, 0x8000_0000_8000_8081, 0x8000_0000_0000_8009,
    0x0000_0000_0000_008a, 0x0000_0000_0000_0088, 0x0000_0000_8000_8009, 0x0000_0000_8000_000a,
    0x0000_0000_8000_808b, 0x8000_0000_0000_008b, 0x8000_0000_0000_8089, 0x8000_0000_0000_8003,
    0x8000_0000_0000_8002, 0x8000_0000_0000_0080, 0x0000_0000_0000_800a, 0x8000_0000_8000_000a,
    0x8000_0000_8000_8081, 0x8000_0000_0000_8080, 0x0000_0000_8000_0001, 0x8000_0000_8000_8008,
  ]
  private static let rotations = [
    0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, 21, 8, 18, 2, 61, 56, 14,
  ]
  private static func rotate(_ value: UInt64, _ bits: Int) -> UInt64 {
    bits == 0 ? value : (value << bits) | (value >> (64 - bits))
  }
  public static func hash(_ message: [UInt8]) -> [UInt8] {
    let rate = 136
    var padded = message
    padded.append(6)
    padded.append(contentsOf: repeatElement(0, count: (rate - padded.count % rate) % rate))
    padded[padded.count - 1] |= 0x80
    var state = [UInt64](repeating: 0, count: 25)
    for offset in stride(from: 0, to: padded.count, by: rate) {
      for i in 0..<rate { state[i / 8] ^= UInt64(padded[offset + i]) << ((i % 8) * 8) }
      for constant in rounds {
        var c = [UInt64](repeating: 0, count: 5)
        for x in 0..<5 { for y in 0..<5 { c[x] ^= state[x + 5 * y] } }
        for x in 0..<5 {
          let d = c[(x + 4) % 5] ^ rotate(c[(x + 1) % 5], 1)
          for y in 0..<5 { state[x + 5 * y] ^= d }
        }
        var b = [UInt64](repeating: 0, count: 25)
        for x in 0..<5 {
          for y in 0..<5 {
            b[y + 5 * ((2 * x + 3 * y) % 5)] = rotate(state[x + 5 * y], rotations[x + 5 * y])
          }
        }
        for x in 0..<5 {
          for y in 0..<5 {
            state[x + 5 * y] = b[x + 5 * y] ^ ((~b[(x + 1) % 5 + 5 * y]) & b[(x + 2) % 5 + 5 * y])
          }
        }
        state[0] ^= constant
      }
    }
    return (0..<32).map { UInt8(truncatingIfNeeded: state[$0 / 8] >> (($0 % 8) * 8)) }
  }
  public static func hmac(key: [UInt8], message: [UInt8]) -> [UInt8] {
    var key = key.count > 136 ? hash(key) : key
    key.append(contentsOf: repeatElement(0, count: 136 - key.count))
    return hash(key.map { $0 ^ 0x5c } + hash(key.map { $0 ^ 0x36 } + message))
  }
}
