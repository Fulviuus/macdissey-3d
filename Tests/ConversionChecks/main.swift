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
  func receive(_ value: CVPixelBuffer) {
    lock.lock()
    pixel = value
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
    let converter = try VideoConverter(
      assets: URL(fileURLWithPath: path), deliver: results.receive, failure: results.fail)
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
    let steady = Date()
    let iterations = 30
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
    await converter.stop()
    converter.submit(pixel)
    converter.adjust(depth: 1)
    require(
      results.semaphore.wait(timeout: .now() + 0.1) == .timedOut, "No callbacks after shutdown")
    print("PASS converter shutdown")
  }
}
