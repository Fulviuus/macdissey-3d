import CoreGraphics
import Foundation
import IOSurface
import MacdisseyIPC

public struct DirectStereoConfiguration: Sendable {
  public let name: String
  public let processID: pid_t
  public let eyeWidth: Int, eyeHeight: Int
}

public struct DirectStereoOutput: @unchecked Sendable {
  public var width: Int = 3840, height: Int = 2160
  public var refreshRate: Double
  public var displaySizeMillimetres: SIMD2<Float>
  public var colorSpace: CGColorSpace
  public init(refreshRate: Double, displaySizeMillimetres: SIMD2<Float>, colorSpace: CGColorSpace) {
    self.refreshRate = refreshRate
    self.displaySizeMillimetres = displaySizeMillimetres
    self.colorSpace = colorSpace
  }
}

/// A pair remains immutable until complete is called after GPU consumption.
public final class DirectStereoFrame: @unchecked Sendable {
  public let left: IOSurfaceRef, right: IOSurfaceRef
  private let lock = NSLock()
  private var completion: ((Bool) -> Void)?
  init(left: IOSurfaceRef, right: IOSurfaceRef, completion: @escaping (Bool) -> Void) {
    self.left = left
    self.right = right
    self.completion = completion
  }
  public func complete(consumed: Bool) {
    let callback = lock.withLock {
      let value = completion
      completion = nil
      return value
    }
    callback?(consumed)
  }
  deinit { complete(consumed: false) }
}

/// Bounded handoff between the IPC queue and the drawing thread. Replacing a
/// frame returns its buffers immediately, instead of queuing stale pictures.
public final class DirectStereoInput: @unchecked Sendable {
  private let lock = NSLock()
  private var pending: DirectStereoFrame?
  private var closed = false
  private var pose = MDSInfo()
  public var isOpen: Bool { lock.withLock { !closed } }
  public func takeLatest() -> DirectStereoFrame? {
    lock.withLock {
      let frame = pending
      pending = nil
      return frame
    }
  }
  fileprivate func submit(_ frame: DirectStereoFrame) {
    let discarded = lock.withLock { () -> DirectStereoFrame? in
      guard !closed else { return frame }
      let old = pending
      pending = frame
      return old
    }
    discarded?.complete(consumed: false)
  }
  public func close() {
    let discarded = lock.withLock { () -> DirectStereoFrame? in
      closed = true
      pose.tracked = 0
      let old = pending
      pending = nil
      return old
    }
    discarded?.complete(consumed: false)
  }
  public func track(midpoint: SIMD3<Float>, ipdMillimetres: Float, timestamp: Double, valid: Bool) {
    lock.withLock {
      pose.viewer_x_cm = midpoint.x
      pose.viewer_y_cm = midpoint.y
      pose.viewer_z_cm = midpoint.z
      pose.ipd_mm = ipdMillimetres
      pose.timestamp = timestamp
      pose.tracked = valid ? 1 : 0
    }
  }
  fileprivate func snapshot() -> MDSInfo { lock.withLock { pose } }
}

/// Host side of the SDK; no hardware operations are performed here. The app
/// supplies lifecycle callbacks, and only the renderer acknowledges GPU reads.
public final class DirectStereoHost: @unchecked Sendable {
  public typealias Begin = (
    DirectStereoConfiguration, DirectStereoInput,
    @escaping (Result<DirectStereoOutput, Error>) -> Void
  ) -> Void
  private final class Session {
    let id = UInt64.random(in: 1...UInt64.max)
    let configuration: DirectStereoConfiguration
    let input = DirectStereoInput()
    var ready = false, lastSequence: UInt64 = 0
    var lastContact = ProcessInfo.processInfo.systemUptime
    var info = MDSInfo()
    var handshake: OpaquePointer?
    init(_ configuration: DirectStereoConfiguration) { self.configuration = configuration }
  }
  private let queue = DispatchQueue(label: "macdissey.direct-host", qos: .userInteractive)
  private let lock = NSLock()
  private var stopped = false
  private var active: Session?
  private var receiver: DispatchSourceMachReceive?
  private var timer: DispatchSourceTimer?
  private let lease: Double
  private let begin: Begin
  private let end: (DirectStereoInput) -> Void
  public init(
    serviceName: String? = nil, lease: Double = 2, begin: @escaping Begin,
    end: @escaping (DirectStereoInput) -> Void
  ) throws {
    guard let host = mds_host_create(serviceName ?? String(cString: mds_service_name())) else {
      throw DirectStereoError.unavailable(
        "Cannot open app connections; another macdissey instance may be running.")
    }
    self.lease = lease
    self.begin = begin
    self.end = end
    let receiver = DispatchSource.makeMachReceiveSource(port: mds_host_port(host), queue: queue)
    receiver.setEventHandler { [self] in
      // A bounded batch lets completion replies and lease expiry run even when
      // another process floods the service with messages.
      for _ in 0..<8 {
        guard !lock.withLock({ stopped }), let request = mds_host_receive(host, 0) else { break }
        handle(request)
      }
    }
    receiver.setCancelHandler { mds_host_destroy(host) }
    self.receiver = receiver
    receiver.resume()
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + 0.2, repeating: 0.2)
    timer.setEventHandler { [self] in
      guard let session = active else { return }
      let limit = session.ready ? lease : 20
      if ProcessInfo.processInfo.systemUptime - session.lastContact > limit { finish() }
    }
    self.timer = timer
    timer.resume()
  }
  public func endSession() { queue.async { [self] in finish() } }
  public func stop() {
    lock.withLock { stopped = true }
    queue.async { [self] in
      finish()
      timer?.cancel()
      timer = nil
      receiver?.cancel()
      receiver = nil
    }
  }

  private func reply(
    _ request: OpaquePointer, _ status: Int, session: Session? = nil, message: String? = nil
  ) {
    var info = session.map { snapshot($0) } ?? MDSInfo()
    _ = mds_request_reply(request, Int32(status), &info, nil, message)
  }
  private func snapshot(_ session: Session) -> MDSInfo {
    var info = session.input.snapshot()
    info.session = session.id
    info.sequence = session.lastSequence
    info.output_width = session.info.output_width
    info.output_height = session.info.output_height
    info.refresh_rate = session.info.refresh_rate
    info.display_width_mm = session.info.display_width_mm
    info.display_height_mm = session.info.display_height_mm
    if ProcessInfo.processInfo.systemUptime - info.timestamp > 0.15 { info.tracked = 0 }
    return info
  }
  private func finish() {
    guard let session = active else { return }
    active = nil
    if let request = session.handshake {
      session.handshake = nil
      reply(request, MDS_STOPPED, message: "The direct stereo session was cancelled.")
    }
    session.input.close()
    end(session.input)
  }
  private func handle(_ request: OpaquePointer) {
    let command = mds_request_command(request)
    if command == MDS_BEGIN {
      guard active == nil else {
        reply(request, MDS_BUSY, message: "Another app already owns the direct stereo session.")
        return
      }
      let width = Int(mds_request_width(request))
      let height = Int(mds_request_height(request))
      guard (2...3840).contains(width), (1...2160).contains(height) else {
        reply(request, MDS_INVALID, message: "Unsupported eye dimensions.")
        return
      }
      let label = String(cString: mds_request_name(request)).unicodeScalars.filter {
        !CharacterSet.controlCharacters.contains($0)
      }
      let configuration = DirectStereoConfiguration(
        name: String(String.UnicodeScalarView(label)).prefix(80).description,
        processID: mds_request_pid(request), eyeWidth: width, eyeHeight: height)
      let session = Session(configuration)
      session.handshake = request
      active = session
      begin(configuration, session.input) { [self] result in
        queue.async { [self] in
          guard let request = session.handshake else { return }
          session.handshake = nil
          guard active === session, !lock.withLock({ stopped }) else {
            reply(request, MDS_STOPPED, message: "The stereo session was stopped during startup.")
            return
          }
          switch result {
          case .failure(let error):
            active = nil
            session.input.close()
            reply(request, MDS_UNAVAILABLE, message: error.localizedDescription)
          case .success(let output):
            guard let icc = output.colorSpace.copyICCData(), CFDataGetLength(icc) <= 65536 else {
              reply(
                request, MDS_UNAVAILABLE, message: "The display colour profile cannot be shared.")
              finish()
              return
            }
            session.ready = true
            session.lastContact = ProcessInfo.processInfo.systemUptime
            session.info.output_width = UInt32(output.width)
            session.info.output_height = UInt32(output.height)
            session.info.refresh_rate = output.refreshRate
            session.info.display_width_mm = output.displaySizeMillimetres.x
            session.info.display_height_mm = output.displaySizeMillimetres.y
            var info = snapshot(session)
            if mds_request_reply(request, Int32(MDS_OK), &info, icc, nil) == 0 { finish() }
          }
        }
      }
      return
    }
    guard let session = active, session.ready,
      mds_request_pid(request) == session.configuration.processID,
      mds_request_session(request) == session.id
    else {
      reply(request, MDS_STOPPED, message: "This app has no active stereo session.")
      return
    }
    switch Int(command) {
    case MDS_FRAME:
      let sequence = mds_request_sequence(request)
      guard sequence > session.lastSequence,
        let left = mds_request_left(request), let right = mds_request_right(request),
        mds_surface_valid(
          left, UInt32(session.configuration.eyeWidth), UInt32(session.configuration.eyeHeight))
          != 0,
        mds_surface_valid(
          right, UInt32(session.configuration.eyeWidth), UInt32(session.configuration.eyeHeight))
          != 0
      else {
        reply(
          request, MDS_INVALID, session: session, message: "Invalid or out-of-order stereo frame.")
        return
      }
      session.lastContact = ProcessInfo.processInfo.systemUptime
      session.lastSequence = sequence
      session.input.submit(
        DirectStereoFrame(left: left, right: right) { [self] consumed in
          queue.async { [self] in
            var info = snapshot(session)
            info.sequence = sequence
            if mds_request_reply(request, Int32(consumed ? MDS_OK : MDS_DROPPED), &info, nil, nil)
              == 0,
              active === session
            {
              finish()
            }
          }
        })
    case MDS_PING:
      session.lastContact = ProcessInfo.processInfo.systemUptime
      reply(request, MDS_OK, session: session)
    case MDS_END:
      reply(request, MDS_OK, session: session)
      finish()
    default:
      reply(request, MDS_INVALID, session: session, message: "Unsupported direct stereo command.")
    }
  }
}
