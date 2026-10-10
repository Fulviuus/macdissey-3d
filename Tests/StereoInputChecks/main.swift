import CoreVideo
import Foundation
import OdysseyConversion

func require(_ condition: @autoclosure () -> Bool, _ text: String) {
  if !condition() { fatalError(text) }
}
func makePixel(_ width: Int = 128, _ height: Int = 72, _ color: (Int, Int) -> (UInt8, UInt8, UInt8))
  -> CVPixelBuffer
{
  var pixel: CVPixelBuffer?
  precondition(
    CVPixelBufferCreate(
      nil, width, height, kCVPixelFormatType_32BGRA,
      [
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        kCVPixelBufferMetalCompatibilityKey as String: true,
      ] as CFDictionary, &pixel) == kCVReturnSuccess)
  let p = pixel!
  CVPixelBufferLockBaseAddress(p, [])
  defer { CVPixelBufferUnlockBaseAddress(p, []) }
  let bytes = CVPixelBufferGetBaseAddress(p)!.assumingMemoryBound(to: UInt8.self)
  let stride = CVPixelBufferGetBytesPerRow(p)
  for y in 0..<height {
    for x in 0..<width {
      let (r, g, b) = color(x, y)
      let i = y * stride + x * 4
      bytes[i] = b
      bytes[i + 1] = g
      bytes[i + 2] = r
      bytes[i + 3] = 255
    }
  }
  return p
}
func rgb(_ p: CVPixelBuffer, _ x: Int, _ y: Int) -> [Int] {
  CVPixelBufferLockBaseAddress(p, .readOnly)
  defer { CVPixelBufferUnlockBaseAddress(p, .readOnly) }
  let b =
    CVPixelBufferGetBaseAddress(p)!.assumingMemoryBound(to: UInt8.self) + y
    * CVPixelBufferGetBytesPerRow(p) + x * 4
  return [Int(b[2]), Int(b[1]), Int(b[0])]
}
func eyes(_ p: CVPixelBuffer, _ left: [Int], _ right: [Int], _ tolerance: Int = 1) {
  let w = CVPixelBufferGetWidth(p)
  let h = CVPixelBufferGetHeight(p)
  for (actual, expected) in [(rgb(p, w / 4, h / 2), left), (rgb(p, 3 * w / 4, h / 2), right)] {
    require(
      zip(actual, expected).allSatisfy { abs($0 - $1) <= tolerance },
      "Eye separation: \(actual) != \(expected)")
  }
}
@main enum StereoInputChecks {
  static func main() throws {
    let shaders = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("Resources/StereoShaders")
    let red: (UInt8, UInt8, UInt8) = (255, 0, 0)
    let blue: (UInt8, UInt8, UInt8) = (0, 0, 255)
    // Native-size isolation catches cross-eye sampling at the packing seam,
    // including pixels missed by the centre-colour checks below.
    for litEye in 0...1 {
      var settings = StereoInputSettings()
      settings.format = .fullTAB
      let input = makePixel(3840, 2160) { x, y in
        let lit = y / 1080 == litEye
        let white = x % 47 < 3 || y % 53 < 3
        return lit && white ? (255, 255, 255) : (0, 0, 0)
      }
      let decoder = try StereoInputConverter(settings: settings, shaders: shaders)
      let output = try decoder.process(input, timestamp: 1)!
      CVPixelBufferLockBaseAddress(output, .readOnly)
      let bytes = CVPixelBufferGetBaseAddress(output)!.assumingMemoryBound(to: UInt8.self)
      let stride = CVPixelBufferGetBytesPerRow(output)
      let pane = CVPixelBufferGetWidth(output) / 2
      let start = litEye == 0 ? pane : 0
      var maximum = UInt8(0)
      for y in 0..<CVPixelBufferGetHeight(output) {
        for x in start..<start + pane {
          let i = y * stride + x * 4
          maximum = max(maximum, bytes[i], bytes[i + 1], bytes[i + 2])
        }
      }
      CVPixelBufferUnlockBaseAddress(output, .readOnly)
      require(maximum == 0, "TAB leaked into black eye: maximum channel \(maximum)")
    }
    print("PASS native 4K TAB isolation: both black eye panes remain exactly zero")
    // ares Full SBS: a pair of 192x144 (4:3) eyes, letterboxed on a 384x216
    // display. Edge markers catch the old 50%-height crop; squares catch stretch.
    let classic = makePixel(384, 216) { x, y in
      guard (36..<180).contains(y) else { return (0, 0, 0) }
      if y < 48 { return (0, 255, 0) }
      if y >= 168 { return (255, 255, 0) }
      if (72..<120).contains(x % 192) && (84..<132).contains(y) { return (255, 255, 255) }
      return x < 192 ? red : blue
    }
    for swap in [false, true] {
      var s = StereoInputSettings()
      s.fullSBSAspect = .standard
      s.swapEyes = swap
      require(s.requiresDecoder, "4:3 SBS must bypass the legacy crop")
      let output = try StereoInputConverter(settings: s, shaders: shaders).process(
        classic, timestamp: 1)!
      require(
        CVPixelBufferGetWidth(output) == 384 && CVPixelBufferGetHeight(output) == 108,
        "4:3 normalization dimensions")
      for eye in 0...1 {
        let start = eye * 192
        let expected = (eye == 0) != swap ? [255, 0, 0] : [0, 0, 255]
        for x in [0, 23, 168, 191] {
          require(rgb(output, start + x, 54) == [0, 0, 0], "Asymmetric eye bars")
        }
        for x in [24, 48, 143, 167] {
          require(rgb(output, start + x, 54) == expected, "Eye mix or misplaced picture")
        }
        require(rgb(output, start + 96, 3) == [0, 255, 0], "Top of 4:3 picture cropped")
        require(rgb(output, start + 96, 104) == [255, 255, 0], "Bottom of 4:3 picture cropped")
        let white = [255, 255, 255]
        let horizontal = (0..<192).filter { rgb(output, start + $0, 54) == white }
        let vertical = (0..<108).filter { rgb(output, start + 96, $0) == white }
        require(horizontal == Array(78..<114), "4:3 square width or horizontal centre changed")
        require(vertical == Array(36..<72), "4:3 square stretched or vertically displaced")
      }
    }
    print("PASS 4:3 Full SBS: complete frame, square geometry, centred eyes and swap")
    for f in StereoInputFormat.allCases {
      var settings = StereoInputSettings()
      settings.format = f
      settings.quiltColumns = 2
      settings.quiltRows = 2
      settings.quiltLeft = 0
      settings.quiltRight = 1
      let input = makePixel { x, y in
        switch f {
        case .fullSBS, .halfSBS, .vr180SBS, .vr360SBS: return x < 64 ? red : blue
        case .fullTAB, .halfTAB, .vr180TAB, .vr360TAB, .framePacking: return y < 36 ? red : blue
        case .rowInterleaved: return y % 2 == 0 ? red : blue
        case .columnInterleaved: return x % 2 == 0 ? red : blue
        case .checkerboard: return (x + y) % 2 == 0 ? red : blue
        case .quilt: return y >= 36 ? (x < 64 ? red : blue) : (0, 255, 0)
        default: return (120, 120, 120)
        }
      }
      let decoder = try StereoInputConverter(settings: settings, shaders: shaders)
      let result = try decoder.process(input, timestamp: 1)!
      if f != .anaglyph && f != .pulfrich && f != .frameSequential {
        eyes(result, [255, 0, 0], [0, 0, 255])
      } else {
        eyes(result, [120, 120, 120], [120, 120, 120], 2)
      }
      let duplicate = try decoder.process(input, timestamp: 1)
      require(duplicate == nil, "Duplicate timestamps must not advance")
      print("PASS \(f.title)")
      fflush(stdout)
    }
    for pair in 0..<6 {
      for mode in 0..<5 {
        var s = StereoInputSettings()
        s.format = .anaglyph
        s.anaglyphPair = pair
        s.anaglyphMode = mode
        let d = try StereoInputConverter(settings: s, shaders: shaders)
        let p = try d.process(makePixel { _, _ in (128, 128, 128) }, timestamp: 1)!
        if mode != 1 && mode != 2 { eyes(p, [128, 128, 128], [128, 128, 128], 2) }
      }
    }
    var s = StereoInputSettings()
    s.format = .frameSequential
    let d = try StereoInputConverter(settings: s, shaders: shaders)
    _ = try d.process(makePixel { _, _ in red }, timestamp: 1)
    eyes(try d.process(makePixel { _, _ in blue }, timestamp: 1.016)!, [255, 0, 0], [0, 0, 255])
    eyes(try d.process(makePixel { _, _ in red }, timestamp: 1.032)!, [255, 0, 0], [0, 0, 255])
    eyes(try d.process(makePixel { _, _ in blue }, timestamp: 2)!, [0, 0, 255], [0, 0, 255])
    s.format = .pulfrich
    s.delayFrames = 2
    let delay = try StereoInputConverter(settings: s, shaders: shaders)
    _ = try delay.process(makePixel { _, _ in red }, timestamp: 1)
    eyes(
      try delay.process(makePixel { _, _ in blue }, timestamp: 1.016)!, [0, 0, 255], [255, 0, 0])
    s.format = .halfSBS
    s.swapEyes = true
    eyes(
      try StereoInputConverter(settings: s, shaders: shaders).process(
        makePixel { x, _ in x < 64 ? red : blue }, timestamp: 1)!, [0, 0, 255], [255, 0, 0])
    s.quiltColumns = Int.max
    s.quiltRows = -1
    s.zoom = .nan
    s.delayFrames = 500
    require(
      s.validated.quiltColumns == 16 && s.validated.quiltRows == 1 && s.validated.zoom == 1
        && s.validated.delayFrames == 8, "Validation")
    // The black HDMI blanking interval must never reach either eye.
    s = StereoInputSettings()
    s.format = .framePacking
    let packed = makePixel(192, 2205) { _, y in y < 1080 ? red : (y < 1125 ? (0, 255, 0) : blue) }
    let unpacked = try StereoInputConverter(settings: s, shaders: shaders).process(
      packed, timestamp: 1)!
    for y in [0, 539, 1079] {
      require(
        rgb(unpacked, 96, y) == [255, 0, 0] && rgb(unpacked, 288, y) == [0, 0, 255],
        "Frame-packing blanking leaked")
    }
    // Every interior checker sample, not just one convenient centre pixel.
    s.format = .checkerboard
    let checker = try StereoInputConverter(settings: s, shaders: shaders).process(
      makePixel { x, y in (x + y) % 2 == 0 ? red : blue }, timestamp: 1)!
    for y in stride(from: 2, to: 70, by: 7) {
      for x in stride(from: 2, to: 126, by: 9) {
        require(
          rgb(checker, x, y) == [255, 0, 0] && rgb(checker, x + 128, y) == [0, 0, 255],
          "Checkerboard parity")
      }
    }
    // Neutral-density attenuation happens in linear light, then re-encodes sRGB.
    s.format = .pulfrich
    s.pulfrichND = true
    s.transmission = 0.25
    let nd = try StereoInputConverter(settings: s, shaders: shaders).process(
      makePixel { _, _ in (255, 255, 255) }, timestamp: 1)!
    eyes(nd, [255, 255, 255], [137, 137, 137], 1)
    // Anaglyph luminance must separate channels, not return two identical eyes.
    s = StereoInputSettings()
    s.format = .anaglyph
    s.anaglyphMode = 3
    let mono = try StereoInputConverter(settings: s, shaders: shaders).process(
      makePixel { _, _ in (255, 0, 0) }, timestamp: 1)!
    eyes(mono, [255, 255, 255], [0, 0, 0])
    let suite = "StereoInputChecks-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(1, forKey: "videoLayout")
    require(StereoInputSettings.load(from: defaults).format == .halfSBS, "Legacy layout migration")
    s.swapEyes = true
    s.save(to: defaults)
    require(StereoInputSettings.load(from: defaults) == s, "Stereo settings persistence")
    // Older saved JSON has no aspect field: keep all previous options and the
    // original widescreen fast path. The new option survives a save/reload.
    var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as! [String: Any]
    legacy.removeValue(forKey: "fullSBSAspect")
    defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "stereoInput")
    require(StereoInputSettings.load(from: defaults) == s, "Existing stereo settings reset")
    require(
      StereoInputSettings.load(from: defaults).effectiveFullSBSAspect == .widescreen,
      "Existing Full SBS aspect changed")
    s = StereoInputSettings()
    require(!s.requiresDecoder, "Default SBS fast path changed")
    s.fullSBSAspect = .standard
    s.save(to: defaults)
    require(StereoInputSettings.load(from: defaults) == s, "4:3 aspect persistence")
    s.format = .halfSBS
    require(!s.requiresDecoder, "4:3 option must not affect Half SBS")
    if CommandLine.arguments.contains("--benchmark") {
      let source = makePixel(3840, 2160) { x, y in
        (UInt8((x / 8) % 256), UInt8((y / 8) % 256), UInt8(((x + y) / 16) % 256))
      }
      for format: StereoInputFormat in [.halfTAB, .checkerboard, .anaglyph, .quilt, .vr180SBS] {
        var settings = StereoInputSettings()
        settings.format = format
        let decoder = try StereoInputConverter(settings: settings, shaders: shaders)
        _ = try decoder.process(source, timestamp: 1)
        let start = Date()
        for i in 1...10 { _ = try decoder.process(source, timestamp: 1 + Double(i) / 60) }
        print(
          "4K \(format.title): \(String(format: "%.1f", Date().timeIntervalSince(start)*100)) ms/frame"
        )
        fflush(stdout)
      }
    }
    print("PASS anaglyph combinations, temporal phase/reset, delay, eye swap and bounds")
  }
}
