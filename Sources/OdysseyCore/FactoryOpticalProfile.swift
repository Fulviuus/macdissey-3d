import Foundation

public struct FactoryOpticalProfile: Codable {
  public let lensSerial: String
  public let pitch, slant, spacingCentimetres, refractiveIndex, pixelSizeCentimetres: Float
  public let phase: Float
  public let pixelLayout: String

  public static func decodeEINI(_ data: Data) throws -> Data {
    guard !data.isEmpty, data.count <= 65536 else { throw FactoryCalibrationError.invalidSize }
    var decoded = data
    decoded.append(contentsOf: repeatElement(UInt8(32), count: (4 - data.count % 4) % 4))
    var previous: UInt32 = 0x7263_7365
    for offset in stride(from: decoded.count - 4, through: 0, by: -4) {
      let original = decoded.withUnsafeBytes {
        UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
      }
      var value = (original ^ previous).littleEndian
      withUnsafeBytes(of: &value) { decoded.replaceSubrange(offset..<offset + 4, with: $0) }
      previous = original
    }
    return decoded
  }

  public init(eini: Data, identity: LensIdentity) throws {
    let decoded = try Self.decodeEINI(eini)
    guard let text = String(data: decoded, encoding: .ascii) else {
      throw LensProtocolError.malformed
    }
    var section = ""
    var values: [String: String] = [:]
    for raw in text.components(separatedBy: .newlines) {
      let line = String(
        raw.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)[0]
      ).trimmingCharacters(in: .whitespaces)
      if line.isEmpty { continue }
      if line.hasPrefix("["), line.hasSuffix("]") {
        section = String(line.dropFirst().dropLast())
        continue
      }
      guard let equals = line.firstIndex(of: "=") else { throw LensProtocolError.malformed }
      let name = section + "." + line[..<equals].trimmingCharacters(in: .whitespaces)
      guard values[name] == nil else { throw LensProtocolError.malformed }
      values[name] = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
    }
    func number(_ key: String) throws -> Float {
      guard let value = values[key].flatMap(Float.init), value.isFinite else {
        throw LensProtocolError.malformed
      }
      return value
    }
    guard values["Info.Serialnumber"] == identity.lensSerial, identity.productCode == "ET",
      values["Panel.pixel_layout"] == "LRGB"
    else { throw LensProtocolError.malformed }
    lensSerial = identity.lensSerial
    pixelLayout = "LRGB"
    pitch = try number("3DStack.pitch")
    slant = try number("3DStack.slant")
    spacingCentimetres = try number("3DStack.d_cm")
    refractiveIndex = try number("3DStack.n")
    pixelSizeCentimetres = try number("Panel.pixel_size_cm")
    // The original loader's phc default is zero; actual factory archive has
    // no phc entry. Correction map A supplies the spatial phase correction.
    phase = try values["3DStack.phc"] == nil ? 0 : number("3DStack.phc")
    guard pitch > 0, spacingCentimetres > 0, refractiveIndex > 1, pixelSizeCentimetres > 0 else {
      throw LensProtocolError.malformed
    }
  }
}
