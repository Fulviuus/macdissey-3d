import CryptoKit
import Foundation
import ImageIO
import OdysseyCore

struct FactoryProfile {
  let identity: LensIdentity
  let camera: FactoryCameraCalibration
  let tracker: FactoryTrackerCalibration
  let optics: FactoryOpticalProfile
  let directory: URL

  static func decode(directory: URL, identity: LensIdentity) throws -> FactoryProfile {
    let camera = try FactoryCameraCalibration(
      payload: Data(contentsOf: directory.appendingPathComponent("SR+CALCAM.bin")))
    let tracker = try FactoryTrackerCalibration(
      payload: Data(contentsOf: directory.appendingPathComponent("SR+CALET.bin")))
    let optics = try FactoryOpticalProfile(
      eini: Data(contentsOf: directory.appendingPathComponent("3dstack.eini")), identity: identity)
    for name in ["3DStackCorrection_A.png", "3DStackCorrection_B.png"] {
      guard
        let source = CGImageSourceCreateWithURL(
          directory.appendingPathComponent(name) as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
        image.width == 480, image.height == 270, image.bitsPerComponent == 8,
        image.colorSpace?.model == .monochrome
      else {
        throw AppError.unavailable("Factory optical correction map is invalid.")
      }
    }
    return FactoryProfile(
      identity: identity, camera: camera, tracker: tracker, optics: optics, directory: directory)
  }

  static func unpack(directory: URL, identity: LensIdentity) throws -> FactoryProfile {
    let chip = try Data(contentsOf: directory.appendingPathComponent("chip.bin"))
    let payload = try Data(contentsOf: directory.appendingPathComponent("SR+CAL3D.bin"))
    let archive = try FactoryOpticsCalibration.archive(payload: payload)
    let archiveURL = directory.appendingPathComponent("factory.7z")
    if FileManager.default.fileExists(atPath: archiveURL.path) {
      guard try Data(contentsOf: archiveURL) == archive else { throw LensProtocolError.malformed }
    } else {
      try archive.write(to: archiveURL, options: .withoutOverwriting)
    }
    let password = try FactoryOpticsCalibration.archivePassword(chipIdentity: chip)
    let helper = Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent(
      "7zz")
    let executable =
      FileManager.default.isExecutableFile(atPath: helper.path)
      ? helper : URL(fileURLWithPath: "/opt/homebrew/bin/7zz")
    guard FileManager.default.isExecutableFile(atPath: executable.path) else {
      throw AppError.unavailable(
        "The factory archive helper is missing; rebuild the application bundle.")
    }
    // Read only three exact archive members into memory. Archive member
    // paths are never used as output destinations.
    for name in ["3dstack.eini", "3DStackCorrection_A.png", "3DStackCorrection_B.png"] {
      let process = Process()
      let output = Pipe()
      process.executableURL = executable
      process.arguments = ["e", "-so", "-bsp0", "-p" + password, archiveURL.path, "temp/" + name]
      process.standardOutput = output
      process.standardError = FileHandle.nullDevice
      process.standardInput = FileHandle.nullDevice
      try process.run()
      let data = output.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      guard process.terminationStatus == 0, !data.isEmpty, data.count <= 1024 * 1024 else {
        throw AppError.unavailable("Cannot decode the factory optical archive.")
      }
      try data.write(to: directory.appendingPathComponent(name), options: .withoutOverwriting)
    }
    let profile = try decode(directory: directory, identity: identity)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(profile.optics).write(
      to: directory.appendingPathComponent("optics.json"), options: .withoutOverwriting)
    return profile
  }

  static func retrieve(port: String) throws -> FactoryProfile {
    let controller = try LensController(port: port)
    let identity = try controller.identity()
    let root = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    )
    .appendingPathComponent("Odyssey3D/Calibration", isDirectory: true)
    try FileManager.default.createDirectory(
      at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let destination = root.appendingPathComponent(identity.calibrationSerial, isDirectory: true)
    if let cached = try? decode(directory: destination, identity: identity) { return cached }
    // Failed reads stay separate from a complete profile. Never replace a
    // user's existing profile until all payloads and optical maps validate.
    let temporary = root.appendingPathComponent(".fetch-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporary, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: temporary) }
    try controller.authenticate()
    try controller.chipIdentity().write(to: temporary.appendingPathComponent("chip.bin"))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(identity).write(to: temporary.appendingPathComponent("identity.json"))
    for command in FactoryCalibrationCommand.allCases {
      try controller.readFactoryCalibration(command).write(
        to: temporary.appendingPathComponent(command.rawValue + ".bin"))
    }
    _ = try unpack(directory: temporary, identity: identity)
    if FileManager.default.fileExists(atPath: destination.path) {
      let backup = root.appendingPathComponent(
        identity.calibrationSerial + ".previous-" + UUID().uuidString)
      try FileManager.default.moveItem(at: destination, to: backup)
    }
    try FileManager.default.moveItem(at: temporary, to: destination)
    return try decode(directory: destination, identity: identity)
  }
}
