import CoreGraphics
import Foundation
import IOSurface
import MacdisseyIPC
import Metal

public enum DirectStereoError: Error, LocalizedError {
  case unavailable(String)
  public var errorDescription: String? {
    switch self {
    case .unavailable(let message): return message
    }
  }
}

public struct DirectStereoTracking: Sendable {
  /// Measured display-space midpoint in centimetres, using the factory transform.
  /// Optical routing's separately predicted position is not a scene-camera pose.
  public let midpointCentimetres: SIMD3<Float>
  public let interpupillaryDistanceMillimetres: Float
  public let timestamp: Double
  private let tracked: Bool
  public var valid: Bool {
    let age = ProcessInfo.processInfo.systemUptime - timestamp
    return tracked && age >= 0 && age < 0.15
  }
  init(_ info: MDSInfo) {
    midpointCentimetres = SIMD3(info.viewer_x_cm, info.viewer_y_cm, info.viewer_z_cm)
    interpupillaryDistanceMillimetres = info.ipd_mm
    timestamp = info.timestamp
    tracked = info.tracked != 0
  }
}

/// An IOSurface-backed Metal render target. Allocate a small reusable pool,
/// render both eyes, finish GPU work, then await the session's present method.
public final class StereoEyeTexture: @unchecked Sendable {
  public let surface: IOSurfaceRef
  public let texture: MTLTexture
  public init(device: MTLDevice, width: Int, height: Int) throws {
    guard (2...3840).contains(width), (1...2160).contains(height),
      let surface = IOSurfaceCreate(
        [
          kIOSurfaceWidth: width, kIOSurfaceHeight: height,
          kIOSurfaceBytesPerElement: 4, kIOSurfacePixelFormat: 0x4247_5241,
        ] as CFDictionary)
    else { throw DirectStereoError.unavailable("Cannot allocate the stereo eye surface.") }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    descriptor.storageMode = .shared
    descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
    guard let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0)
    else {
      throw DirectStereoError.unavailable("Cannot make an IOSurface-backed Metal texture.")
    }
    self.surface = surface
    self.texture = texture
  }
}

/// One local, exclusive direct-rendering session. No screen capture, image
/// serialization, globally discoverable surface IDs, or external runtime.
public final class StereoSession: @unchecked Sendable {
  // Immutable references cross the transport queue. The presentation contract
  // grants the host exclusive reads until acknowledgement; callers finish GPU
  // writes first and do not mutate either surface during this interval.
  private final class EyePair: @unchecked Sendable {
    let left: IOSurfaceRef, right: IOSurfaceRef
    init(_ left: IOSurfaceRef, _ right: IOSurfaceRef) {
      self.left = left
      self.right = right
    }
  }
  public let eyeWidth: Int, eyeHeight: Int
  public let outputWidth: Int, outputHeight: Int
  public let refreshRate: Double
  public let displaySizeMillimetres: SIMD2<Float>
  /// Eye pixels must be encoded in this profile before presentation. Use a GPU
  /// colour transform when your renderer's working/output space is different.
  public let outputColorSpace: CGColorSpace
  private let queue = DispatchQueue(label: "macdissey.client", qos: .userInteractive)
  private let lock = NSLock()
  private var presenting = false, closed = false
  private var client: OpaquePointer?
  private var heartbeat: DispatchSourceTimer?
  private let session: UInt64
  private var sequence: UInt64 = 0
  private var tracking: DirectStereoTracking

  private init(client: OpaquePointer, info: MDSInfo, width: Int, height: Int) throws {
    guard let icc = mds_client_copy_icc(client), let space = CGColorSpace(iccData: icc) else {
      throw DirectStereoError.unavailable(
        "The host did not provide a usable display colour profile.")
    }
    self.client = client
    session = info.session
    eyeWidth = width
    eyeHeight = height
    outputWidth = Int(info.output_width)
    outputHeight = Int(info.output_height)
    refreshRate = info.refresh_rate
    displaySizeMillimetres = SIMD2(info.display_width_mm, info.display_height_mm)
    outputColorSpace = space
    tracking = DirectStereoTracking(info)
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + 0.4, repeating: 0.4)
    timer.setEventHandler { [weak self] in self?.ping() }
    heartbeat = timer
    timer.resume()
  }

  public static func connect(
    name: String = ProcessInfo.processInfo.processName, eyeWidth: Int = 1920,
    eyeHeight: Int = 2160, serviceName: String? = nil
  ) async throws -> StereoSession {
    guard (2...3840).contains(eyeWidth), (1...2160).contains(eyeHeight) else {
      throw DirectStereoError.unavailable("Unsupported stereo eye dimensions.")
    }
    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let service = serviceName ?? String(cString: mds_service_name())
        guard let client = mds_client_create(service) else {
          continuation.resume(
            throwing: DirectStereoError.unavailable(
              "Open macdissey 3d and enable Allow App Connections in its menu."))
          return
        }
        do {
          var info = MDSInfo()
          let status = mds_client_exchange(
            client, UInt32(MDS_BEGIN), 0, 0, UInt32(eyeWidth), UInt32(eyeHeight), name,
            nil, nil, 20_000, &info)
          guard status == MDS_OK, info.session != 0 else {
            throw failure(status, client: client)
          }
          let value = try StereoSession(
            client: client, info: info, width: eyeWidth, height: eyeHeight)
          continuation.resume(returning: value)
        } catch {
          mds_client_destroy(client)
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// Only one outstanding presentation is permitted, preventing a hidden queue
  /// of stale frames. Keep both eyes immutable until this method returns.
  /// Returns the latest measured scene viewing position. Optical prediction
  /// and lens gating remain private to the host.
  public func present(left: IOSurfaceRef, right: IOSurfaceRef) async throws -> DirectStereoTracking
  {
    let allowed = lock.withLock {
      guard !closed, !presenting else { return false }
      presenting = true
      return true
    }
    guard allowed else {
      throw DirectStereoError.unavailable("Session closed or a frame is already in flight.")
    }
    let pair = EyePair(left, right)
    return try await withCheckedThrowingContinuation { continuation in
      queue.async { [self] in
        let complete: (Result<DirectStereoTracking, Error>) -> Void = { [self] result in
          // Clear back-pressure before waking the producer. A resumed task may
          // immediately call present again from a different executor.
          lock.withLock { presenting = false }
          continuation.resume(with: result)
        }
        guard let client else {
          complete(.failure(DirectStereoError.unavailable("The stereo session has ended.")))
          return
        }
        sequence &+= 1
        var info = MDSInfo()
        let status = mds_client_exchange(
          client, UInt32(MDS_FRAME), session, sequence, UInt32(eyeWidth), UInt32(eyeHeight),
          nil, pair.left, pair.right, 1500, &info)
        if status == MDS_OK || status == MDS_DROPPED {
          let value = DirectStereoTracking(info)
          lock.withLock { tracking = value }
          complete(.success(value))
        } else {
          let error = Self.failure(status, client: client)
          // A timed-out frame may still be on the GPU. End the session and do
          // not imply that these surfaces may be overwritten for another frame.
          closeOnQueue()
          complete(.failure(error))
        }
      }
    }
  }

  public var latestTracking: DirectStereoTracking { lock.withLock { tracking } }
  public var isConnected: Bool { lock.withLock { !closed } }

  public func close() async {
    await withCheckedContinuation { continuation in
      queue.async { [self] in
        closeOnQueue()
        continuation.resume()
      }
    }
  }
  private func ping() {
    guard let client else { return }
    var info = MDSInfo()
    let status = mds_client_exchange(
      client, UInt32(MDS_PING), session, sequence, 0, 0, nil, nil, nil, 1000, &info)
    if status == MDS_OK {
      lock.withLock { tracking = DirectStereoTracking(info) }
    } else {
      closeOnQueue()
    }
  }
  private func closeOnQueue() {
    heartbeat?.cancel()
    heartbeat = nil
    guard let client else { return }
    lock.withLock { closed = true }
    var info = MDSInfo()
    _ = mds_client_exchange(
      client, UInt32(MDS_END), session, sequence, 0, 0, nil, nil, nil, 500, &info)
    mds_client_destroy(client)
    self.client = nil
  }
  deinit {
    heartbeat?.cancel()
    // Dropping a session closes its port; the host's bounded heartbeat lease
    // handles process crashes and callers which omit an explicit close.
    if let client { mds_client_destroy(client) }
  }
  private static func failure(_ status: Int32, client: OpaquePointer) -> DirectStereoError {
    let detail = String(cString: mds_client_error(client))
    return .unavailable(detail.isEmpty ? "Direct stereo connection failed (\(status))." : detail)
  }
}
