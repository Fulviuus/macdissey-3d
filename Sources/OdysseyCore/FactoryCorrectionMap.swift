import Foundation
import ImageIO

public struct FactoryCorrectionMap {
  public let width, height: Int
  /// Bottom row first, matching original LoadTexture(..., flip=true).
  public let pixels: [UInt8]
  public init(png: Data) throws {
    guard let source = CGImageSourceCreateWithData(png as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      image.width == 480, image.height == 270, image.bitsPerComponent == 8,
      image.bitsPerPixel == 8, image.colorSpace?.model == .monochrome,
      let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data),
      CFDataGetLength(data) >= image.bytesPerRow * image.height
    else {
      throw LensProtocolError.malformed
    }
    width = image.width
    height = image.height
    var flipped = [UInt8]()
    flipped.reserveCapacity(width * height)
    for row in (0..<height).reversed() {
      flipped.append(
        contentsOf: UnsafeBufferPointer(
          start: bytes.advanced(by: row * image.bytesPerRow), count: width))
    }
    pixels = flipped
  }
}
