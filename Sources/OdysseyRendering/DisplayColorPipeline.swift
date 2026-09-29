import CoreImage
import CoreVideo
import Foundation

public enum DisplayColorError: Error {
  case invalidFrame
  case bufferAllocation(OSStatus)
}

/// Convert ordinary image colours before the weaver assigns physical display
/// subpixels to eyes. The woven window must use this same output colour space;
/// an sRGB-to-display transform afterward would mix the eye channels again.
/// Own and call this object from one capture queue.
public final class DisplayColorPipeline {
  public let outputColorSpace: CGColorSpace
  private lazy var context = CIContext(options: [
    .cacheIntermediates: false,
    .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    .outputColorSpace: outputColorSpace,
  ])
  private var pool: CVPixelBufferPool?
  private var width = 0, height = 0

  public init(outputColorSpace: CGColorSpace) {
    self.outputColorSpace = outputColorSpace
  }

  public func convert(_ source: CVPixelBuffer, from sourceColorSpace: CGColorSpace) throws
    -> CVPixelBuffer
  {
    let w = CVPixelBufferGetWidth(source)
    let h = CVPixelBufferGetHeight(source)
    guard CVPixelBufferGetPixelFormatType(source) == kCVPixelFormatType_32BGRA,
      w > 0, h > 0, w <= 8192, h <= 8192
    else { throw DisplayColorError.invalidFrame }
    if CFEqual(sourceColorSpace, outputColorSpace) { return source }
    if pool == nil || width != w || height != h {
      var newPool: CVPixelBufferPool?
      let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        kCVPixelBufferMetalCompatibilityKey as String: true,
      ]
      let result = CVPixelBufferPoolCreate(
        kCFAllocatorDefault, nil, attributes as CFDictionary, &newPool)
      guard result == kCVReturnSuccess, let newPool else {
        throw DisplayColorError.bufferAllocation(result)
      }
      pool = newPool
      width = w
      height = h
    }
    var converted: CVPixelBuffer?
    let result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool!, &converted)
    guard result == kCVReturnSuccess, let converted else {
      throw DisplayColorError.bufferAllocation(result)
    }
    let image = CIImage(cvPixelBuffer: source, options: [.colorSpace: sourceColorSpace])
    context.render(
      image, to: converted, bounds: CGRect(x: 0, y: 0, width: w, height: h),
      colorSpace: outputColorSpace)
    CVBufferSetAttachment(
      converted, kCVImageBufferCGColorSpaceKey, outputColorSpace, .shouldPropagate)
    return converted
  }
}
