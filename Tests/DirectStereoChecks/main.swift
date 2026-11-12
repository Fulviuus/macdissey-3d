import CoreGraphics
import Foundation
import IOSurface
import ImageIO
import MacdisseyClient
import MacdisseyIPC
import Metal

private final class TestState: @unchecked Sendable {
  let lock = NSLock()
  var input: DirectStereoInput?
  var ended = 0, consumed = 0
  var differentEyes = 0
  var litLeft = 0, litRight = 0
  var shadeCount = 0
  var captureNextFrame = false
  var jitterPose = false
  var previousSignature: UInt64?
  var changedFrames = 0
  var consume = true
}

private final class StartupState: @unchecked Sendable {
  let lock = NSLock()
  var input: DirectStereoInput?
  var callback: ((Result<DirectStereoOutput, Error>) -> Void)?
  var ready = false
}

@main enum DirectStereoChecks {
  static func main() async throws {
    if CommandLine.arguments.count >= 3,
      ["--client", "--crash", "--crash-frame"].contains(CommandLine.arguments[1])
    {
      try await client(
        service: CommandLine.arguments[2], crash: CommandLine.arguments[1] == "--crash",
        crashWithFrame: CommandLine.arguments[1] == "--crash-frame")
      return
    }
    let demo = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--demo"
    let name = "io.github.fulviuus.macdissey.checks.\(getpid()).\(UUID().uuidString)"
    let state = TestState()
    let previewPath = ProcessInfo.processInfo.environment["MACDISSEY_DEMO_PREVIEW"]
    let nativeDemo = ProcessInfo.processInfo.environment["MACDISSEY_DEMO_NATIVE"] == "1"
    let demoWidth = nativeDemo ? 1920 : 384
    let demoHeight = nativeDemo ? 2160 : 216
    let sampleStep = max(4, demoWidth / 96)
    let host = try DirectStereoHost(
      serviceName: name, lease: 0.8,
      begin: { configuration, input, reply in
        precondition(
          configuration.eyeWidth == (demo ? demoWidth : 16)
            && configuration.eyeHeight == (demo ? demoHeight : 8)
        )
        precondition(
          configuration.processID != getpid(),
          "Peer identity must come from the other process's audit trailer")
        state.lock.withLock { state.input = input }
        reply(
          .success(
            DirectStereoOutput(
              refreshRate: 120, displaySizeMillimetres: SIMD2(597, 336),
              colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)))
      },
      end: { _ in
        state.lock.withLock {
          state.ended += 1
          state.input = nil
        }
      })
    defer { host.stop() }
    let render = DispatchSource.makeTimerSource(
      queue: DispatchQueue(label: "DirectStereoChecks.consumer"))
    render.schedule(deadline: .now(), repeating: 0.002)
    render.setEventHandler {
      guard let input = state.lock.withLock({ state.consume ? state.input : nil }),
        let frame = input.takeLatest()
      else {
        return
      }
      if demo {
        IOSurfaceLock(frame.left, .readOnly, nil)
        IOSurfaceLock(frame.right, .readOnly, nil)
        let left = IOSurfaceGetBaseAddress(frame.left).assumingMemoryBound(to: UInt32.self)
        let right = IOSurfaceGetBaseAddress(frame.right).assumingMemoryBound(to: UInt32.self)
        let lp = IOSurfaceGetBytesPerRow(frame.left) / 4
        let rp = IOSurfaceGetBytesPerRow(frame.right) / 4
        var different = false
        var litLeft = false
        var litRight = false
        var shades = Set<UInt32>()
        var signature: UInt64 = 0xcbf2_9ce4_8422_2325
        for y in stride(from: 0, to: demoHeight, by: sampleStep) {
          for x in stride(from: 0, to: demoWidth, by: sampleStep) {
            precondition(left[y * lp + x] >> 24 == 255 && right[y * rp + x] >> 24 == 255)
            different = different || left[y * lp + x] != right[y * rp + x]
            litLeft = litLeft || left[y * lp + x] & 0x00ff_ffff != 0
            litRight = litRight || right[y * rp + x] & 0x00ff_ffff != 0
            shades.insert(left[y * lp + x] & 0x00ff_ffff)
            signature = (signature ^ UInt64(left[y * lp + x])) &* 0x100_0000_01b3
            signature = (signature ^ UInt64(right[y * rp + x])) &* 0x100_0000_01b3
          }
        }
        let capture = state.lock.withLock {
          if !state.captureNextFrame || state.consumed < 2 { return false }
          state.captureNextFrame = false
          return true
        }
        let snapshot = capture ? Data(bytes: left, count: lp * 4 * demoHeight) : nil
        IOSurfaceUnlock(frame.right, .readOnly, nil)
        IOSurfaceUnlock(frame.left, .readOnly, nil)
        if let snapshot, let previewPath {
          let provider = CGDataProvider(data: snapshot as CFData)!
          let image = CGImage(
            width: demoWidth, height: demoHeight, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: lp * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.union(
              CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
          let destination = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: previewPath) as CFURL, "public.png" as CFString, 1, nil)!
          CGImageDestinationAddImage(destination, image, nil)
          precondition(CGImageDestinationFinalize(destination))
        }
        state.lock.withLock {
          if different { state.differentEyes += 1 }
          if litLeft { state.litLeft += 1 }
          if litRight { state.litRight += 1 }
          state.shadeCount = max(state.shadeCount, shades.count)
          if let previous = state.previousSignature, previous != signature {
            state.changedFrames += 1
          }
          state.previousSignature = signature
        }
      } else {
        for (surface, red) in [(frame.left, true), (frame.right, false)] {
          IOSurfaceLock(surface, .readOnly, nil)
          let bytes = IOSurfaceGetBaseAddress(surface).assumingMemoryBound(to: UInt8.self)
          precondition(
            bytes[red ? 2 : 0] == 255 && bytes[red ? 0 : 2] == 0,
            "Cross-process GPU pixels must remain in their original eye")
          IOSurfaceUnlock(surface, .readOnly, nil)
        }
      }
      let jitter: Float = state.lock.withLock {
        state.jitterPose ? (state.consumed % 2 == 0 ? 1 : -1) : 0
      }
      input.track(
        midpoint: SIMD3(1 + jitter, 2 - jitter, 70 + jitter), ipdMillimetres: 63 + 5 * jitter,
        timestamp: ProcessInfo.processInfo.systemUptime, valid: true)
      state.lock.withLock { state.consumed += 1 }
      frame.complete(consumed: true)
      frame.complete(consumed: true)  // Completion must remain exactly once.
    }
    render.resume()
    defer { render.cancel() }
    if demo {
      for (pattern, scene, swapped, paused, viewpoint) in [
        ("stereo", "gallery", false, false, "smooth"),
        ("stereo", "gallery", false, true, "smooth"),
        ("stereo", "gallery", false, true, "fixed"),
        ("stereo", "gallery", false, true, "raw"),
        ("stereo", "cubes", false, false, "smooth"),
        ("stereo", "cubes", false, true, "smooth"),
        ("grid", "gallery", false, true, "smooth"),
        ("left", "gallery", false, true, "smooth"),
        ("right", "gallery", false, true, "smooth"),
        ("left", "gallery", true, true, "smooth"),
      ] {
        let before = state.lock.withLock {
          state.consumed = 0
          state.differentEyes = 0
          state.litLeft = 0
          state.litRight = 0
          state.shadeCount = 0
          state.jitterPose = viewpoint == "fixed" || viewpoint == "raw"
          state.previousSignature = nil
          state.changedFrames = 0
          state.captureNextFrame =
            previewPath != nil && pattern == "stereo" && scene == "gallery" && paused
          return state.ended
        }
        let process = Process()
        let reportURL = FileManager.default.temporaryDirectory.appendingPathComponent(
          "direct-stereo-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: reportURL) }
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[2])
        process.arguments =
          [
            "--seconds", "1", "--width", String(demoWidth), "--height", String(demoHeight),
            "--service", name, "--pattern", pattern, "--scene", scene,
            "--report", reportURL.path,
          ] + (viewpoint == "smooth" ? [] : ["--viewpoint", viewpoint])
          + (viewpoint == "raw" ? ["--samples", "1"] : [])
          + (paused ? ["--paused"] : []) + (swapped ? ["--swap-eyes"] : [])
        try process.run()
        process.waitUntilExit()
        precondition(process.terminationReason == .exit && process.terminationStatus == 0)
        let report =
          try JSONSerialization.jsonObject(with: Data(contentsOf: reportURL)) as! [String: Any]
        if let timing = report["producerGPUTimeMilliseconds"] as? [String: Any],
          let mean = timing["mean"] as? Double
        {
          print(
            String(
              format: "Demo GPU work: %.3f ms/frame (offscreen, excludes host and scan-out)", mean))
        }
        let deadline = Date().addingTimeInterval(1)
        while state.lock.withLock({ state.ended == before }) && Date() < deadline {
          try await Task.sleep(nanoseconds: 10_000_000)
        }
        state.lock.withLock {
          precondition(state.consumed > 20 && state.ended == before + 1)
          precondition(report["renderedFrames"] as? Int == state.consumed)
          precondition(report["displayRefreshRateHz"] as? Double == 120)
          if pattern == "grid" {
            precondition(state.differentEyes == 0 && state.litLeft == state.consumed)
          } else {
            precondition(state.differentEyes > 0)
          }
          if pattern == "stereo" && scene == "gallery" {
            precondition(
              state.shadeCount > 32, "Gallery lighting and materials must contain shaded geometry")
          }
          if viewpoint == "fixed" {
            precondition(
              state.changedFrames == 0, "Fixed scene cameras must ignore tracking jitter")
          } else if viewpoint == "raw" {
            precondition(
              state.changedFrames > 10, "Raw comparison must expose the injected tracking jitter")
          }
          if pattern == "left" || pattern == "right" {
            let leftIsLit = (pattern == "left") != swapped
            precondition(state.litLeft == (leftIsLit ? state.consumed : 0))
            precondition(state.litRight == (leftIsLit ? 0 : state.consumed))
          }
        }
        print(
          "PASS demo pattern: \(pattern) · \(scene) · \(viewpoint)\(paused ? " paused" : "")\(swapped ? " swapped" : "")"
        )
      }
      print(
        "PASS native stereo demo: runtime Metal shader, separate stereo views, tracking feedback and automatic stop; no physical display activation"
      )
      return
    }
    func child(_ crash: Bool, pending: Bool = false) throws {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
      process.arguments = [pending ? "--crash-frame" : (crash ? "--crash" : "--client"), name]
      try process.run()
      process.waitUntilExit()
      precondition(process.terminationReason == .exit && process.terminationStatus == 0)
    }
    try child(false)
    precondition(state.lock.withLock { state.ended >= 2 && state.consumed >= 26 })
    let before = state.lock.withLock { state.ended }
    try child(true)
    let deadline = Date().addingTimeInterval(3)
    while state.lock.withLock({ state.ended == before }) && Date() < deadline {
      try await Task.sleep(nanoseconds: 20_000_000)
    }
    precondition(
      state.lock.withLock { state.ended == before + 1 }, "Crashed clients must lose their lease")
    let beforePending = state.lock.withLock {
      state.consume = false
      return state.ended
    }
    try child(true, pending: true)
    let pendingDeadline = Date().addingTimeInterval(3)
    while state.lock.withLock({ state.ended == beforePending }) && Date() < pendingDeadline {
      try await Task.sleep(nanoseconds: 20_000_000)
    }
    precondition(
      state.lock.withLock { state.ended == beforePending + 1 && state.input == nil },
      "A crashed producer's pending surfaces must be released before another session")
    state.lock.withLock { state.consume = true }
    try child(false)
    host.stop()
    try await Task.sleep(nanoseconds: 200_000_000)
    // The app must be able to disable and later reopen the same endpoint.
    let startup = StartupState()
    func output() -> DirectStereoOutput {
      DirectStereoOutput(
        refreshRate: 120, displaySizeMillimetres: SIMD2(597, 336),
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    }
    let replacement = try DirectStereoHost(
      serviceName: name,
      begin: { _, input, reply in
        let ready = startup.lock.withLock {
          startup.input = input
          if !startup.ready { startup.callback = reply }
          return startup.ready
        }
        if ready { reply(.success(output())) }
      }, end: { _ in })
    let cancelled = Task {
      try await StereoSession.connect(eyeWidth: 16, eyeHeight: 8, serviceName: name)
    }
    let startupDeadline = Date().addingTimeInterval(3)
    while startup.lock.withLock({ startup.callback == nil }) && Date() < startupDeadline {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    precondition(startup.lock.withLock { startup.callback != nil })
    replacement.endSession()
    do {
      _ = try await cancelled.value
      preconditionFailure("Cancelled startup must not connect")
    } catch {}
    precondition(startup.lock.withLock { startup.input?.isOpen == false })
    let late = startup.lock.withLock {
      startup.ready = true
      let callback = startup.callback!
      startup.callback = nil
      return callback
    }
    let next = try await StereoSession.connect(eyeWidth: 16, eyeHeight: 8, serviceName: name)
    late(.success(output()))
    late(.failure(CancellationError()))
    try await Task.sleep(nanoseconds: 600_000_000)
    precondition(
      next.isConnected, "A late or duplicate startup callback must not affect a later session")
    await next.close()
    replacement.stop()
    print(
      "PASS direct stereo: cross-process Metal surfaces, colour profile, exclusive ownership, ordered frames, tracking, reuse, crash cleanup and service restart"
    )
  }

  static func client(service: String, crash: Bool, crashWithFrame: Bool) async throws {
    let session = try await StereoSession.connect(eyeWidth: 16, eyeHeight: 8, serviceName: service)
    precondition(session.refreshRate == 120 && session.outputWidth == 3840)
    precondition(CFEqual(session.outputColorSpace, CGColorSpace(name: CGColorSpace.sRGB)!))
    if crash { _exit(0) }
    do {
      _ = try await StereoSession.connect(eyeWidth: 16, eyeHeight: 8, serviceName: service)
      preconditionFailure("A second producer must not take over active 3D")
    } catch {}
    let device = MTLCreateSystemDefaultDevice()!
    let queue = device.makeCommandQueue()!
    let left = try StereoEyeTexture(device: device, width: 16, height: 8)
    let right = try StereoEyeTexture(device: device, width: 16, height: 8)
    let commands = queue.makeCommandBuffer()!
    for (eye, color) in [
      (left, MTLClearColorMake(1, 0, 0, 1)), (right, MTLClearColorMake(0, 0, 1, 1)),
    ] {
      let pass = MTLRenderPassDescriptor()
      pass.colorAttachments[0].texture = eye.texture
      pass.colorAttachments[0].loadAction = .clear
      pass.colorAttachments[0].storeAction = .store
      pass.colorAttachments[0].clearColor = color
      commands.makeRenderCommandEncoder(descriptor: pass)!.endEncoding()
    }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      commands.addCompletedHandler { _ in continuation.resume() }
      commands.commit()
    }
    precondition(commands.status == .completed)
    if crashWithFrame {
      DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { _exit(0) }
      _ = try await session.present(left: left.surface, right: right.surface)
      preconditionFailure("The fake GPU must not have acknowledged the abandoned frame")
    }
    var durations: [Double] = []
    for _ in 0..<25 {
      let start = ProcessInfo.processInfo.systemUptime
      let pose = try await session.present(left: left.surface, right: right.surface)
      precondition(pose.valid && pose.midpointCentimetres == SIMD3(1, 2, 70))
      durations.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
    }
    // Idle sessions remain live without resending or copying a static frame.
    try await Task.sleep(nanoseconds: 1_200_000_000)
    precondition(
      !session.latestTracking.valid, "Old tracking must expire while a static frame is idle")
    _ = try await session.present(left: left.surface, right: right.surface)
    await session.close()
    durations.sort()
    print("Direct IPC round trip (fake consumer): median \(durations[durations.count/2]) ms")
    let raw = mds_client_create(service)!
    defer { mds_client_destroy(raw) }
    var info = MDSInfo()
    precondition(
      mds_client_exchange(raw, UInt32(MDS_BEGIN), 0, 0, 16, 8, "Raw checks", nil, nil, 1000, &info)
        == MDS_OK)
    let token = info.session
    let wrongSize = try StereoEyeTexture(device: device, width: 8, height: 8)
    precondition(
      mds_client_exchange(
        raw, UInt32(MDS_FRAME), token, 1, 8, 8, nil,
        wrongSize.surface, wrongSize.surface, 1000, &info) == MDS_INVALID)
    precondition(
      mds_client_exchange(
        raw, UInt32(MDS_FRAME), token, 2, 16, 8, nil, left.surface, right.surface, 1000, &info)
        == MDS_OK)
    precondition(
      mds_client_exchange(
        raw, UInt32(MDS_FRAME), token, 1, 16, 8, nil, left.surface, right.surface, 1000, &info)
        == MDS_INVALID)
    precondition(
      mds_client_exchange(raw, UInt32(MDS_PING), token ^ 1, 0, 0, 0, nil, nil, nil, 1000, &info)
        == MDS_STOPPED)
    precondition(
      mds_client_exchange(raw, UInt32(MDS_END), token, 0, 0, 0, nil, nil, nil, 1000, &info)
        == MDS_OK)
  }
}
