import CoreVideo
import Foundation
import OdysseyConversion

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
  if !condition() {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
  }
}
private final class Results: @unchecked Sendable {
  let semaphore = DispatchSemaphore(value: 0)
  private let lock = NSLock()
  private var pixel: CVPixelBuffer?, error: Error?
  private var motionTimes: [Double] = []
  private var lastShade: UInt8?
  func receive(_ value: CVPixelBuffer) {
    CVPixelBufferLockBaseAddress(value, .readOnly)
    let bytes = CVPixelBufferGetBaseAddress(value)!.assumingMemoryBound(to: UInt8.self)
    let shade = bytes[540 * CVPixelBufferGetBytesPerRow(value) + 960 * 4]
    CVPixelBufferUnlockBaseAddress(value, .readOnly)
    lock.lock()
    pixel = value
    if lastShade != shade {
      motionTimes.append(ProcessInfo.processInfo.systemUptime)
      lastShade = shade
    }
    lock.unlock()
    semaphore.signal()
  }
  func fail(_ value: Error) {
    lock.lock()
    error = value
    lock.unlock()
    semaphore.signal()
  }
  func take() throws -> CVPixelBuffer {
    require(semaphore.wait(timeout: .now() + 30) == .success, "Conversion timed out")
    lock.lock()
    defer { lock.unlock() }
    if let error { throw error }
    guard let pixel else { throw NSError(domain: "ConversionChecks", code: 1) }
    return pixel
  }
  func motion(after start: Double) -> [Double] {
    lock.lock()
    defer { lock.unlock() }
    return motionTimes.filter { $0 >= start }
  }
  func clearNotifications() {
    while semaphore.wait(timeout: .now()) == .success {}
  }
}
@main enum ConversionChecks {
  static func main() async throws {
    var settings = ConversionAdjustment()
    require(settings.depthValue == 50 && settings.popOutValue == 0, "Original defaults")
    for _ in 0..<30 {
      settings.changeDepth(-1)
      settings.changePopOut(-1)
    }
    require(settings.depthValue == 0 && settings.popOutValue == -50, "Lower limits")
    for _ in 0..<50 {
      settings.changeDepth(1)
      settings.changePopOut(1)
    }
    require(settings.depthValue == 100 && settings.popOutValue == 50, "Upper limits")
    settings.changeDepth(-1)
    settings.changePopOut(-1)
    require(settings.depthValue == 95 && settings.popOutValue == 45, "Original display increments")
    print("PASS conversion adjustment defaults, increments and limits")
    guard let path = ProcessInfo.processInfo.environment["MACDISSEY_CONVERSION_ASSETS"] else {
      print("SKIP conversion GPU/inference check: private assets not supplied")
      return
    }
    let results = Results()
    let start = Date()
    let environment = ProcessInfo.processInfo.environment
    let depthModel: DepthModelConfiguration?
    if let name = environment["MACDISSEY_DEPTH_CHECK_MODEL"],
      let model = DepthModel(rawValue: name),
      let directory = environment["MACDISSEY_DEPTH_CHECK_DIRECTORY"]
    {
      depthModel = DepthModelConfiguration(model: model, directory: URL(fileURLWithPath: directory))
    } else {
      depthModel = nil
    }
    let converter = try VideoConverter(
      assets: URL(fileURLWithPath: path), depthModel: depthModel,
      deliver: results.receive, failure: results.fail)
    var source: CVPixelBuffer?
    let w = 640
    let h = 360
    let attrs =
      [
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        kCVPixelBufferMetalCompatibilityKey as String: true,
      ] as CFDictionary
    require(
      CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, attrs, &source) == kCVReturnSuccess,
      "Input allocation")
    let pixel = source!
    CVPixelBufferLockBaseAddress(pixel, [])
    let bytes = CVPixelBufferGetBaseAddress(pixel)!.assumingMemoryBound(to: UInt8.self)
    let pitch = CVPixelBufferGetBytesPerRow(pixel)
    for y in 0..<h {
      for x in 0..<w {
        let p = y * pitch + x * 4
        bytes[p] = UInt8((x * 17 + y * 31) % 256)
        bytes[p + 1] = UInt8(y * 255 / (h - 1))
        bytes[p + 2] = UInt8(x * 255 / (w - 1))
        bytes[p + 3] = 255
      }
    }
    CVPixelBufferUnlockBaseAddress(pixel, [])
    converter.submit(pixel)
    let output = try results.take()
    require(
      CVPixelBufferGetWidth(output) == 3840 && CVPixelBufferGetHeight(output) == 1080,
      "SBS output shape")
    CVPixelBufferLockBaseAddress(output, .readOnly)
    let data = CVPixelBufferGetBaseAddress(output)!.assumingMemoryBound(to: UInt8.self)
    let stride = CVPixelBufferGetBytesPerRow(output)
    var differences = 0
    var invalidAlpha = 0
    for y in 0..<1080 {
      for x in 0..<1920 {
        let l = y * stride + x * 4
        let r = l + 1920 * 4
        if data[l] != data[r] || data[l + 1] != data[r + 1] || data[l + 2] != data[r + 2] {
          differences += 1
        }
        if data[l + 3] != 255 || data[r + 3] != 255 { invalidAlpha += 1 }
      }
    }
    CVPixelBufferUnlockBaseAddress(output, .readOnly)
    require(differences > 100, "Distinct synthesized eye views")
    require(invalidAlpha == 0, "Fully initialized opaque output")
    print(
      "PASS full native conversion, \(differences) differing eye pixels; first frame \(Date().timeIntervalSince(start))s"
    )
    let update = Date()
    converter.adjust(depth: 1, popOut: 1)
    let hud = try results.take()
    require(CVPixelBufferGetWidth(hud) == 3840, "Paused-frame controls/HUD refresh")
    print("PASS controls update without another source frame; \(Date().timeIntervalSince(update))s")
    if let file = ProcessInfo.processInfo.environment["MACDISSEY_CONVERSION_CHECK_OUTPUT"] {
      CVPixelBufferLockBaseAddress(hud, .readOnly)
      let bytes = Data(
        bytes: CVPixelBufferGetBaseAddress(hud)!,
        count: CVPixelBufferGetBytesPerRow(hud) * CVPixelBufferGetHeight(hud))
      try bytes.write(to: URL(fileURLWithPath: file))
      CVPixelBufferUnlockBaseAddress(hud, .readOnly)
    }
    if depthModel != nil {
      // The asynchronous texture handoff must show the source of this map,
      // even while its next capture is already being prepared.
      for shade: UInt8 in [48, 190, 76, 225] {
        var source: CVPixelBuffer?
        require(
          CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, attrs, &source)
            == kCVReturnSuccess, "Paired fixture allocation")
        let sample = source!
        CVPixelBufferLockBaseAddress(sample, [])
        let base = CVPixelBufferGetBaseAddress(sample)!.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(sample)
        for y in 0..<h {
          for x in 0..<w {
            let offset = y * stride + x * 4
            for channel in 0..<3 { base[offset + channel] = shade }
            base[offset + 3] = 255
          }
        }
        CVPixelBufferUnlockBaseAddress(sample, [])
        results.clearNotifications()
        converter.submit(sample)
        let pair = try results.take()
        CVPixelBufferLockBaseAddress(pair, .readOnly)
        let image = CVPixelBufferGetBaseAddress(pair)!.assumingMemoryBound(to: UInt8.self)
        let actual = image[540 * CVPixelBufferGetBytesPerRow(pair) + 960 * 4]
        CVPixelBufferUnlockBaseAddress(pair, .readOnly)
        require(
          abs(Int(actual) - Int(shade)) <= 2,
          "Completed depth retains its own RGB texture across the handoff")
      }
      print("PASS paired RGB texture handoff across alternating shots")
    }
    let steady = Date()
    let iterations = depthModel == nil ? 30 : 3
    var timings: [Double] = []
    for _ in 0..<iterations {
      let frameStart = Date()
      converter.submit(pixel)
      _ = try results.take()
      timings.append(Date().timeIntervalSince(frameStart))
    }
    print(
      "PASS repeated frames; mean \(Date().timeIntervalSince(steady) / Double(iterations))s per conversion"
    )
    print(
      "Conversion p50=\(timings.sorted()[iterations / 2] * 1000)ms p95=\(timings.sorted()[iterations * 95 / 100] * 1000)ms"
    )
    // Scene cuts to a uniform black frame exercise empty/degenerate depth
    // histograms, which ordinary textured fixtures do not cover.
    CVPixelBufferLockBaseAddress(pixel, [])
    memset(CVPixelBufferGetBaseAddress(pixel)!, 0, pitch * h)
    CVPixelBufferUnlockBaseAddress(pixel, [])
    converter.submit(pixel)
    _ = try results.take()
    print("PASS black scene cut")
    if let raw = environment["MACDISSEY_CONVERSION_STREAM_SECONDS"], let seconds = Double(raw) {
      var frames: [CVPixelBuffer] = []
      for shade in 0..<15 {
        var allocated: CVPixelBuffer?
        require(
          CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, attrs, &allocated)
            == kCVReturnSuccess,
          "Streaming fixture allocation")
        let frame = allocated!
        CVPixelBufferLockBaseAddress(frame, [])
        let bytes = CVPixelBufferGetBaseAddress(frame)!.assumingMemoryBound(to: UInt8.self)
        let pitch = CVPixelBufferGetBytesPerRow(frame)
        for y in 0..<h {
          for x in 0..<w {
            let p = y * pitch + x * 4
            for channel in 0..<3 { bytes[p + channel] = UInt8(40 + shade * 10) }
            if environment["MACDISSEY_CONVERSION_TEXTURED_STREAM"] == "1" {
              // Moving patterned foreground over a textured background. Keep
              // the broad centre marker uniform to measure new source frames
              // independently of stereo displacement around object edges.
              let central = abs(x - w / 2) < 60 && abs(y - h / 2) < 60
              if !central {
                let moving = x > 40 + shade * 8 && x < 140 + shade * 8 && y > 30 && y < 110
                bytes[p] = UInt8((x * 3 + y * 7 + shade * 5) % 190 + 20)
                bytes[p + 1] = UInt8(moving ? 230 : 30 + y * 180 / h)
                bytes[p + 2] = UInt8(moving ? 30 : 30 + x * 180 / w)
              }
            }
            bytes[p + 3] = 255
          }
        }
        CVPixelBufferUnlockBaseAddress(frame, [])
        frames.append(frame)
      }
      let started = ProcessInfo.processInfo.systemUptime
      let capture = DispatchQueue(label: "ConversionChecks.capture", qos: .userInteractive)
      let timer = DispatchSource.makeTimerSource(queue: capture)
      var index = 0
      timer.setEventHandler {
        converter.submit(frames[index % frames.count])
        index += 1
      }
      timer.schedule(deadline: .now(), repeating: .nanoseconds(16_666_667), leeway: .nanoseconds(0))
      timer.resume()
      try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
      timer.cancel()
      capture.sync {}
      let elapsed = ProcessInfo.processInfo.systemUptime - started
      let motion = results.motion(after: started)
      let gaps = zip(motion.dropFirst(), motion).map { ($0 - $1) * 1000 }.sorted()
      require(motion.count > 2, "Streaming output contains new video frames")
      print(
        "STREAM input fps=\(Double(index) / elapsed) new video frames=\(motion.count) fps=\(Double(motion.count) / elapsed) p95 gap=\(gaps[gaps.count * 95 / 100])ms max gap=\(gaps.last!)ms"
      )
    }
    await converter.stop()
    results.clearNotifications()
    converter.submit(pixel)
    converter.adjust(depth: 1)
    require(
      results.semaphore.wait(timeout: .now() + 0.1) == .timedOut, "No callbacks after shutdown")
    print("PASS converter shutdown")
    if depthModel != nil {
      let restarted = Date()
      let next = try VideoConverter(
        assets: URL(fileURLWithPath: path), depthModel: depthModel,
        deliver: results.receive, failure: results.fail)
      let prepared = Date().timeIntervalSince(restarted)
      next.submit(pixel)
      _ = try results.take()
      print(
        "PASS reactivation: constructor \(prepared)s; first paired frame \(Date().timeIntervalSince(restarted))s"
      )
      await next.stop()
    }
  }
}
