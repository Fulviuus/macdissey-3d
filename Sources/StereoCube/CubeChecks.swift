import AppKit

/// Independent packing checks against complete left/right renders of the same
/// scene. These do not prove the monitor's optical separation or capture parity.
enum CubeChecks {
  static func run() throws {
    let gpu = try CubeGPU()
    let w = 256
    let h = 144
    var p = CubeParameters()
    p.time = 1.2
    p.markers = 0
    p.format = 8
    let left = try gpu.image(width: w, height: h, parameters: p)
    p.phase = 1
    let right = try gpu.image(width: w, height: h, parameters: p)
    guard zip(left, right).filter({ $0 != $1 }).count > 100 else {
      throw CubeError("No stereo disparity in cube scene")
    }
    func require(_ yes: Bool, _ message: String) throws { if !yes { throw CubeError(message) } }
    func rgb(_ a: [UInt8], _ width: Int, _ x: Int, _ y: Int) -> [UInt8] {
      Array(a[(y * width + x) * 4..<(y * width + x) * 4 + 3])
    }
    var gridReference = p
    gridReference.screenGrid = 1
    gridReference.phase = 0
    let gridL = try gpu.image(width: w, height: h, parameters: gridReference)
    gridReference.phase = 1
    let gridR = try gpu.image(width: w, height: h, parameters: gridReference)
    for y in 0..<h {
      for x in 0..<w / 4 {
        try require(
          rgb(gridL, w, x, y) == rgb(gridR, w, x, y),
          "Screen-depth grid must be identical outside the cube")
      }
    }
    try require(
      zip(gridL, gridR).filter { $0 != $1 }.count > 100,
      "Grid reference must preserve cube stereo disparity")
    for mode: UInt32 in [0, 1, 2, 3, 4, 5] {
      p.format = mode
      let width = [0, 1, 5].contains(mode) ? 2 * w : w
      let height = mode == 1 || mode == 5 ? h : 2 * h
      let image = try gpu.image(width: width, height: height, parameters: p)
      for y in stride(from: 4, to: h - 4, by: 7) {
        for x in stride(from: 4, to: w - 4, by: 9) {
          let l: (Int, Int)
          let r: (Int, Int)
          switch mode {
          case 0:
            l = (x, y + h / 2)
            r = (x + w, y + h / 2)
          case 1:
            l = (x, y)
            r = (x + w, y)
          case 2, 3:
            l = (x, y)
            r = (x, y + h)
          case 4:
            l = (x, y * 2)
            r = (x, y * 2 + 1)
          default:
            l = (x * 2, y)
            r = (x * 2 + 1, y)
          }
          try require(
            rgb(image, width, l.0, l.1) == rgb(left, w, x, y), "Left packing mismatch mode \(mode)")
          try require(
            rgb(image, width, r.0, r.1) == rgb(right, w, x, y),
            "Right packing mismatch mode \(mode)")
        }
      }
    }
    p.format = 6
    let checker = try gpu.image(width: w, height: h, parameters: p)
    for y in 0..<h {
      for x in 0..<w {
        try require(
          rgb(checker, w, x, y) == rgb((x + y) % 2 == 0 ? left : right, w, x, y),
          "Checkerboard parity")
      }
    }
    p.format = 7
    p.pair = 0
    let ana = try gpu.image(width: w, height: h, parameters: p)
    // Separate shader branches can differ by one sRGB quantization step.
    for i in stride(from: 0, to: ana.count, by: 4) {
      try require(
        abs(Int(ana[i]) - Int(right[i])) <= 1 && abs(Int(ana[i + 1]) - Int(right[i + 1])) <= 1
          && abs(Int(ana[i + 2]) - Int(left[i + 2])) <= 1,
        "Red/cyan channel packing at \(i): \(Array(ana[i..<i+3])) vs L \(Array(left[i..<i+3])) R \(Array(right[i..<i+3]))"
      )
    }
    p.format = 8
    p.phase = 0
    p.isolation = 2
    let black = try gpu.image(width: w, height: h, parameters: p)
    try require(
      stride(from: 0, to: black.count, by: 4).allSatisfy {
        black[$0] == 0 && black[$0 + 1] == 0 && black[$0 + 2] == 0
      }, "Hidden eye is not black")
    p.isolation = 0
    p.separation = 0
    let sameL = try gpu.image(width: w, height: h, parameters: p)
    p.phase = 1
    try require(sameL == gpu.image(width: w, height: h, parameters: p), "Zero separation mismatch")
    p.separation = 0.07
    for mode in 0...16 {
      p.format = UInt32(mode)
      let image = try gpu.image(width: 384, height: 216, parameters: p)
      try require(
        image.enumerated().contains { $0.offset % 4 != 3 && $0.element > 100 },
        "Empty source mode \(mode)")
      try require(
        stride(from: 3, to: image.count, by: 4).allSatisfy { image[$0] == 255 },
        "Nonopaque mode \(mode)")
    }
    p.format = 10
    let fp = try gpu.image(width: 192, height: 2205, parameters: p)
    for y in 1080..<1125 {
      try require((0..<192).allSatisfy { rgb(fp, 192, $0, y) == [0, 0, 0] }, "Frame packing gap")
    }
    if let index = CommandLine.arguments.firstIndex(of: "--snapshot"),
      CommandLine.arguments.indices.contains(index + 1)
    {
      p.format = 1
      let bytes = try gpu.image(width: 1920, height: 1080, parameters: p)
      let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 1920, pixelsHigh: 1080, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 1920 * 4, bitsPerPixel: 32)!
      for i in stride(from: 0, to: bytes.count, by: 4) {
        rep.bitmapData![i] = bytes[i + 2]
        rep.bitmapData![i + 1] = bytes[i + 1]
        rep.bitmapData![i + 2] = bytes[i]
        rep.bitmapData![i + 3] = 255
      }
      try rep.representation(using: .png, properties: [:])!.write(
        to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
    }
    print(
      "PASS: all 16 formats + mono; independent stereo packing, disparity, checker parity, anaglyph channels, black-eye isolation, zero separation, screen-depth grid and frame-packing gap"
    )
  }
}
