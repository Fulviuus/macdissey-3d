import CoreVideo
import Foundation
import OdysseyRendering

func buffer(width: Int, height: Int, pixel: (Int, Int) -> [UInt8]) -> CVPixelBuffer {
  var value: CVPixelBuffer?
  precondition(
    CVPixelBufferCreate(
      nil, width, height, kCVPixelFormatType_32BGRA,
      [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &value)
      == kCVReturnSuccess)
  let result = value!
  CVPixelBufferLockBaseAddress(result, [])
  let pointer = CVPixelBufferGetBaseAddress(result)!.assumingMemoryBound(to: UInt8.self)
  let stride = CVPixelBufferGetBytesPerRow(result)
  for y in 0..<height {
    for x in 0..<width {
      for (channel, component) in pixel(x, y).enumerated() {
        pointer[y * stride + x * 4 + channel] = component
      }
    }
  }
  CVPixelBufferUnlockBaseAddress(result, [])
  return result
}

let width = 12
let height = 4
func backgroundPixel(_ x: Int, _ y: Int) -> [UInt8] {
  [UInt8(10 + x * 9), UInt8(30 + y * 20), UInt8(7 + x * 4), 255]
}
func foregroundPixel(_ x: Int, _ y: Int) -> [UInt8] {
  if (4...6).contains(x), y == 1 { return [25, 80, 210, 255] }
  if x == 8, y == 2 { return [40, 20, 60, 128] }  // Premultiplied translucent edge.
  return [0, 0, 0, 0]
}
let background = buffer(width: width, height: height, pixel: backgroundPixel)
let foreground = buffer(width: width, height: height, pixel: foregroundPixel)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
for offset in [0, 1, 3] {
  let compositor = DesktopCompositor(backgroundOffset: offset)
  for front in [nil, foreground] as [CVPixelBuffer?] {
    let output = try compositor.compose(
      background: background, foreground: front, colorSpace: space)
    precondition(
      CVPixelBufferGetWidth(output) == width * 2 && CVPixelBufferGetHeight(output) == height)
    CVPixelBufferLockBaseAddress(output, .readOnly)
    let pixels = CVPixelBufferGetBaseAddress(output)!.assumingMemoryBound(to: UInt8.self)
    let stride = CVPixelBufferGetBytesPerRow(output)
    for eye in 0..<2 {
      for y in 0..<height {
        for x in 0..<width {
          let sourceX = max(0, min(width - 1, x + (eye == 0 ? offset : -offset)))
          let back = backgroundPixel(sourceX, y)
          let frontPixel = front == nil ? [UInt8](repeating: 0, count: 4) : foregroundPixel(x, y)
          for channel in 0..<3 {
            let expected = Int(
              (Double(frontPixel[channel]) + Double(back[channel])
                * (1 - Double(frontPixel[3]) / 255)).rounded())
            let actual = Int(pixels[y * stride + (eye * width + x) * 4 + channel])
            precondition(
              abs(actual - expected) <= 1,
              "Eye \(eye), pixel \(x),\(y), channel \(channel): \(actual) != \(expected)")
          }
          precondition(pixels[y * stride + (eye * width + x) * 4 + 3] == 255)
        }
      }
    }
    CVPixelBufferUnlockBaseAddress(output, .readOnly)
  }
}
let invalid = buffer(width: 4, height: 2) { _, _ in [0, 0, 0, 255] }
let fullDisplay = buffer(width: width, height: height) { x, y in
  [UInt8(x * 15), UInt8(y * 50), 200, 255]
}
for regions: [CGRect] in [
  [], [CGRect(x: 2, y: 0, width: 5, height: 1)],
  [CGRect(x: -2, y: 2, width: 7, height: 4), CGRect(x: 3, y: 1, width: 4, height: 3)],
  [CGRect(x: 0, y: 0, width: width, height: height)],
] {
  let expectedFront = buffer(width: width, height: height) { x, y in
    if regions.contains(where: { $0.contains(CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)) }) {
      return [UInt8(x * 15), UInt8(y * 50), 200, 255]
    }
    return [0, 0, 0, 0]
  }
  let compositor = DesktopCompositor(backgroundOffset: 1)
  let actual = try compositor.compose(
    background: background, foreground: fullDisplay, colorSpace: space, foregroundRegions: regions)
  let expected = try compositor.compose(
    background: background, foreground: expectedFront, colorSpace: space)
  CVPixelBufferLockBaseAddress(actual, .readOnly)
  CVPixelBufferLockBaseAddress(expected, .readOnly)
  for row in 0..<height {
    precondition(
      memcmp(
        CVPixelBufferGetBaseAddress(actual)! + row * CVPixelBufferGetBytesPerRow(actual),
        CVPixelBufferGetBaseAddress(expected)! + row * CVPixelBufferGetBytesPerRow(expected),
        width * 2 * 4) == 0, "Display region mask differs at row \(row)")
  }
  CVPixelBufferUnlockBaseAddress(actual, .readOnly)
  CVPixelBufferUnlockBaseAddress(expected, .readOnly)
}
print("PASS: display region masks, top-left coordinates, clipping, overlap and empty selection")
do {
  _ = try DesktopCompositor(backgroundOffset: 1).compose(
    background: background,
    foreground: invalid, colorSpace: space)
  fatalError("Mismatched layer size accepted")
} catch DisplayColorError.invalidFrame {}
print(
  "PASS: desktop disparity direction, stationary foreground, alpha edges, row/eye order, clamped boundaries and size validation"
)
