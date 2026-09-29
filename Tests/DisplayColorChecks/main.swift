import AppKit
import CoreVideo
import OdysseyRendering

// Compare the actual capture-buffer conversion against CoreGraphics colour
// matching, and check channel/row order with asymmetric colours. No camera,
// screen capture, display-mode changes or lens commands are involved.
let samples: [[UInt8]] = [
  [0, 0, 255, 255], [0, 255, 0, 255], [255, 0, 0, 255], [128, 128, 128, 255],
  [19, 74, 193, 255], [225, 91, 38, 255], [0, 0, 0, 255], [255, 255, 255, 255],
]
var source: CVPixelBuffer?
precondition(
  CVPixelBufferCreate(
    kCFAllocatorDefault, 4, 2, kCVPixelFormatType_32BGRA,
    [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &source)
    == kCVReturnSuccess)
let input = source!
CVPixelBufferLockBaseAddress(input, [])
let base = CVPixelBufferGetBaseAddress(input)!.assumingMemoryBound(to: UInt8.self)
let stride = CVPixelBufferGetBytesPerRow(input)
for (i, pixel) in samples.enumerated() {
  for c in 0..<4 { base[(i / 4) * stride + (i % 4) * 4 + c] = pixel[c] }
}
CVPixelBufferUnlockBaseAddress(input, [])
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
var spaces = [CGColorSpace(name: CGColorSpace.displayP3)!]
for screen in NSScreen.screens where screen.localizedName.contains("Odyssey") {
  let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber)
    .uint32Value
  spaces.append(CGDisplayCopyColorSpace(id))
}
for space in spaces {
  let converter = DisplayColorPipeline(outputColorSpace: space)
  let output = try converter.convert(input, from: srgb)
  CVPixelBufferLockBaseAddress(output, .readOnly)
  let pixels = CVPixelBufferGetBaseAddress(output)!.assumingMemoryBound(to: UInt8.self)
  let rowBytes = CVPixelBufferGetBytesPerRow(output)
  var maximumError = 0
  for (i, pixel) in samples.enumerated() {
    let rgb = [CGFloat(pixel[2]) / 255, CGFloat(pixel[1]) / 255, CGFloat(pixel[0]) / 255, 1]
    let expected = CGColor(colorSpace: srgb, components: rgb)!.converted(
      to: space, intent: .relativeColorimetric, options: nil)!.components!
    for channel in 0..<3 {
      let target = Int((expected[2 - channel] * 255).rounded())
      let error = abs(Int(pixels[(i / 4) * rowBytes + (i % 4) * 4 + channel]) - target)
      maximumError = max(error, maximumError)
      precondition(error <= 3, "Colour conversion / row or channel order differs from CoreGraphics")
    }
    precondition(pixels[(i / 4) * rowBytes + (i % 4) * 4 + 3] == 255)
  }
  CVPixelBufferUnlockBaseAddress(output, .readOnly)
  let bypass = try converter.convert(output, from: space)
  precondition(bypass === output, "Display-native capture must bypass conversion")
  print("Display colour conversion: 8 pixels, maximum channel error \(maximumError)/255")
}
let identity = try DisplayColorPipeline(outputColorSpace: srgb).convert(input, from: srgb)
precondition(identity === input, "sRGB identity should preserve the original pixels")
print("PASS: pre-weave colour conversion, orientation, alpha and identity")
