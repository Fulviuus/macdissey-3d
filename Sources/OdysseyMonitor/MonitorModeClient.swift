import Darwin
import Foundation

public enum MonitorModeError: Error, LocalizedError {
  case unavailable(String)
  public var errorDescription: String? {
    switch self {
    case .unavailable(let message): return "Monitor control: " + message
    }
  }
}

public struct MonitorModeStatus {
  public let pictureInPicture, portrait, sourceSupports3D, notified3D, firmwareUpdating: Bool
  public let notificationID: UInt32
}

/// Client for the temporary, narrowly scoped USB research bridge. The app stays
/// unprivileged. Use one serial queue; closing the socket releases any ON lease.
public final class MonitorModeClient {
  private var descriptor: Int32 = -1
  public static var defaultPath: String { "/var/run/odyssey3d-monitor-\(getuid()).sock" }

  public static func connectIfPresent() throws -> MonitorModeClient? {
    var info = stat()
    guard lstat(defaultPath, &info) == 0 else {
      if errno == ENOENT { return nil }
      throw MonitorModeError.unavailable("Cannot inspect the USB helper socket.")
    }
    guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFSOCK), info.st_uid == getuid() else {
      throw MonitorModeError.unavailable("Unexpected USB helper socket owner or type.")
    }
    return try MonitorModeClient(path: defaultPath, serverUID: 0)
  }

  // An explicit path/peer also allows isolated local protocol tests. Playback
  // always uses connectIfPresent's fixed path and requires a root server peer.
  public init(path: String, serverUID: uid_t) throws {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    let bytes = Array(path.utf8CString)
    guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
      throw MonitorModeError.unavailable("Socket path is too long.")
    }
    withUnsafeMutableBytes(of: &address.sun_path) { storage in
      for (index, value) in bytes.enumerated() { storage[index] = UInt8(bitPattern: value) }
    }
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw MonitorModeError.unavailable("Cannot create a socket.") }
    var connected = false
    defer { if !connected { Darwin.close(fd) } }
    var noSignal: Int32 = 1
    var timeout = timeval(tv_sec: 5, tv_usec: 0)
    guard
      setsockopt(
        fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))
        == 0,
      setsockopt(
        fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout))) == 0,
      setsockopt(
        fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout))) == 0
    else {
      throw MonitorModeError.unavailable("Cannot bound helper communication time.")
    }
    let result = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    guard result == 0 else {
      throw MonitorModeError.unavailable("Cannot connect to the USB helper.")
    }
    var peer = uid_t.max
    var group = gid_t.max
    guard getpeereid(fd, &peer, &group) == 0, peer == serverUID else {
      throw MonitorModeError.unavailable("Unexpected USB helper process identity.")
    }
    descriptor = fd
    connected = true
  }

  deinit { disconnect() }
  public func disconnect() {
    if descriptor >= 0 {
      Darwin.close(descriptor)
      descriptor = -1
    }
  }

  private func exchange(_ command: UInt8) throws -> String {
    guard descriptor >= 0 else { throw MonitorModeError.unavailable("USB helper disconnected.") }
    do {
      let deadline = ProcessInfo.processInfo.systemUptime + 5
      var byte = command
      var sent: Int
      repeat { sent = Darwin.send(descriptor, &byte, 1, 0) } while sent < 0 && errno == EINTR
      guard sent == 1 else {
        throw MonitorModeError.unavailable("Cannot send the monitor command.")
      }
      var reply = [UInt8]()
      while reply.count < 32 {
        let remaining = deadline - ProcessInfo.processInfo.systemUptime
        guard remaining > 0 else {
          throw MonitorModeError.unavailable("USB helper response timed out.")
        }
        var ready = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        let polled = poll(&ready, 1, Int32(max(1, remaining * 1000)))
        if polled < 0 && errno == EINTR { continue }
        guard polled > 0 else {
          throw MonitorModeError.unavailable("USB helper response timed out.")
        }
        var count: Int
        repeat { count = Darwin.recv(descriptor, &byte, 1, 0) } while count < 0 && errno == EINTR
        guard count == 1 else {
          throw MonitorModeError.unavailable("USB helper stopped responding.")
        }
        if byte == 10 {
          guard let value = String(bytes: reply, encoding: .ascii), value.hasPrefix("OK") else {
            throw MonitorModeError.unavailable("The monitor command was rejected.")
          }
          return value
        }
        reply.append(byte)
      }
      throw MonitorModeError.unavailable("Invalid USB helper response.")
    } catch {
      disconnect()
      throw error
    }
  }

  private func acknowledge(_ command: UInt8) throws {
    guard try exchange(command) == "OK" else {
      disconnect()
      throw MonitorModeError.unavailable("Invalid command acknowledgement.")
    }
  }
  public func setEnabled(_ enabled: Bool) throws { try acknowledge(enabled ? 49 : 48) }
  public func heartbeat() throws { try acknowledge(72) }
  public func status() throws -> MonitorModeStatus {
    let reply = try exchange(83)
    guard reply.hasPrefix("OK "), reply.utf8.count == 21 else {
      disconnect()
      throw MonitorModeError.unavailable("Invalid monitor status length.")
    }
    let hex = Array(reply.dropFirst(3))
    var bytes = [UInt8]()
    for index in stride(from: 0, to: 18, by: 2) {
      guard let byte = UInt8(String(hex[index...index + 1]), radix: 16) else {
        disconnect()
        throw MonitorModeError.unavailable("Invalid monitor status data.")
      }
      bytes.append(byte)
    }
    return MonitorModeStatus(
      pictureInPicture: bytes[0] != 0, portrait: bytes[1] != 0,
      sourceSupports3D: bytes[2] != 0, notified3D: bytes[3] != 0, firmwareUpdating: bytes[8] != 0,
      notificationID: UInt32(bytes[4]) << 24 | UInt32(bytes[5]) << 16 | UInt32(bytes[6]) << 8
        | UInt32(bytes[7]))
  }
}
