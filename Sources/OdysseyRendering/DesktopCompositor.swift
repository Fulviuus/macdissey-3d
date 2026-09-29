import CoreImage
import CoreVideo
import Foundation

/// Two flat desktop planes, packed as full-resolution left/right views.
/// Capture colours have already been converted to the display's colour space.
/// Confine this object to one rendering queue.
public final class DesktopCompositor {
  private let context = CIContext(options: [
    .cacheIntermediates: false, .workingColorSpace: NSNull(), .outputColorSpace: NSNull(),
  ])
  private var pool: CVPixelBufferPool?
  private var size = CGSize.zero
  public let backgroundOffset: Int

  public init(backgroundOffset: Int = 8) {
    self.backgroundOffset = max(0, min(backgroundOffset, 32))
  }

  public func compose(
    background: CVPixelBuffer, foreground: CVPixelBuffer?,
    colorSpace: CGColorSpace, foregroundRegions: [CGRect]? = nil
  ) throws -> CVPixelBuffer {
    let width = CVPixelBufferGetWidth(background)
    let height = CVPixelBufferGetHeight(background)
    guard width > backgroundOffset * 2, width <= 4096, height > 0, height <= 4096,
      CVPixelBufferGetPixelFormatType(background) == kCVPixelFormatType_32BGRA
    else {
      throw DisplayColorError.invalidFrame
    }
    if let foreground {
      guard CVPixelBufferGetWidth(foreground) == width,
        CVPixelBufferGetHeight(foreground) == height,
        CVPixelBufferGetPixelFormatType(foreground) == kCVPixelFormatType_32BGRA
      else {
        throw DisplayColorError.invalidFrame
      }
    }
    let outputSize = CGSize(width: width * 2, height: height)
    if pool == nil || size != outputSize {
      let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width * 2,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        kCVPixelBufferMetalCompatibilityKey as String: true,
      ]
      let result = CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
      guard result == kCVReturnSuccess else { throw DisplayColorError.bufferAllocation(result) }
      size = outputSize
    }
    var output: CVPixelBuffer?
    let result = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
      nil, pool!, [kCVPixelBufferPoolAllocationThresholdKey as String: 4] as CFDictionary, &output)
    guard result == kCVReturnSuccess, let output else {
      throw DisplayColorError.bufferAllocation(result)
    }
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    let back = CIImage(cvPixelBuffer: background, options: [.colorSpace: NSNull()])
      .clampedToExtent()
    let front = foreground.map { buffer -> CIImage in
      let image = CIImage(cvPixelBuffer: buffer, options: [.colorSpace: NSNull()])
      guard let foregroundRegions else { return image }
      // Regions are display pixels with a top-left origin, like window bounds.
      // Copy real display pixels so native window controls remain interactive.
      return foregroundRegions.reduce(CIImage.empty()) { result, region in
        let clipped = region.intersection(bounds)
        guard !clipped.isNull, !clipped.isEmpty else { return result }
        let rect = CGRect(
          x: clipped.minX, y: CGFloat(height) - clipped.maxY,
          width: clipped.width, height: clipped.height)
        return image.cropped(to: rect).composited(over: result)
      }
    }
    func eye(_ offset: Int) -> CIImage {
      let shifted = back.transformed(by: CGAffineTransform(translationX: CGFloat(offset), y: 0))
        .cropped(to: bounds)
      return (front?.composited(over: shifted) ?? shifted).cropped(to: bounds)
    }
    // Uncrossed disparity places the background behind the physical screen.
    let left = eye(-backgroundOffset)
    let right = eye(backgroundOffset)
      .transformed(by: CGAffineTransform(translationX: CGFloat(width), y: 0))
    context.render(
      left.composited(over: right), to: output,
      bounds: CGRect(origin: .zero, size: outputSize), colorSpace: nil)
    CVBufferSetAttachment(output, kCVImageBufferCGColorSpaceKey, colorSpace, .shouldPropagate)
    return output
  }
}
