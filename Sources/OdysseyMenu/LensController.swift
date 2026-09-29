import Darwin
import Foundation
import OdysseyCore
import Security

/// Uses the OS's existing CDC ACM driver. No arbitrary commands or firmware writes.
final class LensController {
  private let fd: Int32
  private var original = termios()

  init(port: String) throws {
    // Resolve the port from the matched USB device, never the first usbmodem.
    guard
      Hardware.devices().contains(where: {
        $0.vendorID == 0x354b && $0.productID == 0x0116 && $0.serialPort == port
      })
    else {
      throw AppError.unavailable("The serial port does not belong to the Odyssey lens board.")
    }
    fd = Darwin.open(port, O_RDWR | O_NOCTTY | O_NONBLOCK)
    guard fd >= 0 else {
      throw AppError.unavailable("Cannot open lens controller: \(String(cString: strerror(errno)))")
    }
    guard ioctl(fd, TIOCEXCL) == 0, tcgetattr(fd, &original) == 0 else {
      Darwin.close(fd)
      throw AppError.unavailable("Cannot acquire the lens controller exclusively.")
    }
    var settings = original
    cfmakeraw(&settings)
    settings.c_cflag |= tcflag_t(CLOCAL | CREAD)
    settings.c_cflag &= ~tcflag_t(CSTOPB | PARENB | CRTSCTS)
    cfsetispeed(&settings, speed_t(B115200))
    cfsetospeed(&settings, speed_t(B115200))
    guard tcsetattr(fd, TCSANOW, &settings) == 0 else {
      Darwin.close(fd)
      throw AppError.unavailable("Cannot configure the lens controller.")
    }
  }

  deinit {
    tcsetattr(fd, TCSANOW, &original)
    Darwin.close(fd)
  }

  private func exchange(_ command: LensCommand) throws -> LensResponse {
    tcflush(fd, TCIFLUSH)
    let data = command.bytes
    let deadline = ProcessInfo.processInfo.systemUptime + 2
    var sent = 0
    while sent < data.count {
      guard ProcessInfo.processInfo.systemUptime < deadline else {
        throw AppError.unavailable("Lens command timed out during write.")
      }
      var descriptor = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
      guard poll(&descriptor, 1, 50) >= 0 else {
        if errno == EINTR { continue }
        throw AppError.unavailable("Lens controller disconnected.")
      }
      let count = data.withUnsafeBytes {
        Darwin.write(fd, $0.baseAddress!.advanced(by: sent), data.count - sent)
      }
      if count > 0 {
        sent += count
      } else if count < 0 && errno != EAGAIN && errno != EINTR {
        throw AppError.unavailable("Lens command could not be sent.")
      }
    }
    var response = LensResponse()
    var bytes = [UInt8](repeating: 0, count: 256)
    while ProcessInfo.processInfo.systemUptime < deadline {
      var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
      let result = poll(&descriptor, 1, 50)
      if result < 0 && errno == EINTR { continue }
      guard result >= 0, descriptor.revents & Int16(POLLERR | POLLHUP | POLLNVAL) == 0 else {
        throw AppError.unavailable("Lens controller disconnected.")
      }
      if result == 0 { continue }
      let count = Darwin.read(fd, &bytes, bytes.count)
      if count > 0 {
        try response.append(Data(bytes.prefix(count)))
      } else if count < 0 && errno != EAGAIN && errno != EINTR {
        throw AppError.unavailable("Lens response could not be read.")
      }
      if response.complete { return response }
    }
    throw AppError.unavailable(
      "Lens controller did not acknowledge the command within two seconds.")
  }

  func isEnabled() throws -> Bool { try exchange(.status).enabled() }
  func information() throws -> String { try exchange(.information).textPayload() }

  func identity() throws -> LensIdentity {
    let calibration = try exchange(.calibrationSerial).serialNumber()
    let lens = try exchange(.lensSerial).serialNumber()
    return LensIdentity(lensSerial: lens, calibrationSerial: calibration)
  }

  func readFactoryCalibration(_ command: FactoryCalibrationCommand) throws -> Data {
    try exchangeFixed(command.rawValue, payloadSize: command.payloadSize, timeout: command.timeout)
  }

  func chipIdentity() throws -> Data { try exchangeFixed("SR+CHIP", payloadSize: 32, timeout: 2) }

  func authenticate() throws {
    let authentication = try ControllerAuthentication(information: information())
    var nonce = [UInt8](repeating: 0, count: 64)
    guard SecRandomCopyBytes(kSecRandomDefault, nonce.count, &nonce) == errSecSuccess else {
      throw AppError.unavailable("Cannot generate the controller authentication challenge.")
    }
    _ = try exchangeFixed(
      "SR+NONCE=" + ControllerAuthentication.hex(nonce, uppercase: true), payloadSize: 4,
      timeout: 0.5)
    let deviceResponse = try exchangeFixed("SR+AUTH", payloadSize: 68, timeout: 3)
    try authentication.verifyDevice(nonce: nonce, response: deviceResponse)
    let deviceNonce = try exchangeFixed("SR+NONCE", payloadSize: 132, timeout: 0.5)
    let response = try authentication.hostResponse(deviceNonce: deviceNonce)
    _ = try exchangeFixed("SR+AUTH=" + response, payloadSize: 0, timeout: 3, prefix: Data())
    guard try information().components(separatedBy: .newlines).contains("Authenticated: 1") else {
      throw LensProtocolError.rejected
    }
  }

  private func exchangeFixed(
    _ command: String, payloadSize: Int, timeout: TimeInterval, prefix: Data = Data([13, 10])
  ) throws -> Data {
    tcflush(fd, TCIFLUSH)
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    var sent = 0
    let data = Data((command + "\r").utf8)
    while sent < data.count {
      guard ProcessInfo.processInfo.systemUptime < deadline else {
        throw AppError.unavailable("Calibration command write timed out.")
      }
      let count = data.withUnsafeBytes {
        Darwin.write(fd, $0.baseAddress!.advanced(by: sent), data.count - sent)
      }
      if count > 0 {
        sent += count
      } else if count < 0 && errno != EAGAIN && errno != EINTR {
        throw AppError.unavailable("Calibration command failed.")
      } else {
        var p = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        _ = poll(&p, 1, 20)
      }
    }
    var response = FixedLengthLensResponse(payloadSize: payloadSize, prefix: prefix)
    var bytes = [UInt8](repeating: 0, count: 4096)
    while ProcessInfo.processInfo.systemUptime < deadline {
      var p = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
      let result = poll(&p, 1, 50)
      if result < 0 && errno == EINTR { continue }
      guard result >= 0, p.revents & Int16(POLLERR | POLLHUP | POLLNVAL) == 0 else {
        throw AppError.unavailable("Controller disconnected during calibration read.")
      }
      if result == 0 { continue }
      let count = Darwin.read(fd, &bytes, bytes.count)
      if count > 0 {
        try response.append(Data(bytes.prefix(count)))
      } else if count < 0 && errno != EAGAIN && errno != EINTR {
        throw AppError.unavailable("Calibration read failed.")
      }
      if response.complete { return try response.payload() }
    }
    let detail =
      response.bytes.count <= 64
      ? " Reply bytes: " + response.bytes.map { String(format: "%02x", $0) }.joined() : ""
    throw AppError.unavailable(
      "\(command.split(separator: "=")[0]) timed out after \(response.bytes.count) of \(response.expectedSize) bytes."
        + detail)
  }

  /// Backend only, not exposed as a 3D action before calibrated rendering exists.
  func setEnabled(_ enabled: Bool) throws {
    _ = try exchange(.setEnabled(enabled))
    guard try isEnabled() == enabled else {
      throw AppError.unavailable("Lens state did not match the requested state.")
    }
  }
}
