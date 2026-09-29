import Foundation
import OdysseyVision

public struct PreparedEyeDepth {
  public let tensor: [Float]
  public let correctedRectangle: SIMD4<Int32>
  public let scaledSize: SIMD2<Int32>
  public let cropOrigin: SIMD2<Int32>
}

/// Blink's camera-specific undistortion, focal normalization, crop and tensor.
public final class DepthPreparation {
  private let handle: OpaquePointer
  private let lock = NSLock()
  private let width, height: Int
  public init(width: Int, height: Int, camera: [Double], distortion: [Double]) throws {
    guard width > 0, width <= 8192, height > 0, height <= 8192,
      camera.count == 9, distortion.count == 8
    else { throw TrackingMathError.invalidInput }
    var status: Int32 = 0
    guard
      let result = odyssey_depth_preparation_create(
        Int32(width), Int32(height), camera, distortion, &status)
    else {
      throw TrackingMathError.invalidInput
    }
    self.width = width
    self.height = height
    handle = result
  }
  deinit { odyssey_depth_preparation_destroy(handle) }
  public func prepare(pixels: [UInt8], channels: Int = 1, stride: Int, rectangle: SIMD4<Double>)
    throws -> PreparedEyeDepth
  {
    guard channels == 1 || channels == 3, stride >= width * channels else {
      throw TrackingMathError.invalidInput
    }
    lock.lock()
    defer { lock.unlock() }
    var tensor = [Float](repeating: 0, count: 3 * 224 * 224)
    var geometry = [Int32](repeating: 0, count: 8)
    let rect = [rectangle.x, rectangle.y, rectangle.z, rectangle.w]
    guard
      odyssey_depth_prepare(
        handle, pixels, pixels.count, Int32(channels), stride, rect, &tensor, tensor.count,
        &geometry) == 0
    else {
      throw TrackingMathError.invalidInput
    }
    return PreparedEyeDepth(
      tensor: tensor, correctedRectangle: SIMD4(geometry[0], geometry[1], geometry[2], geometry[3]),
      scaledSize: SIMD2(geometry[4], geometry[5]), cropOrigin: SIMD2(geometry[6], geometry[7]))
  }
  /// Most recent intermediate image, for reference validation.
  public func stage(_ stage: Int) throws -> [UInt8] {
    guard (0...2).contains(stage) else { throw TrackingMathError.invalidInput }
    lock.lock()
    defer { lock.unlock() }
    var count = 0
    guard odyssey_depth_preparation_stage(handle, Int32(stage), nil, 0, &count) == 0 else {
      throw TrackingMathError.invalidInput
    }
    var bytes = [UInt8](repeating: 0, count: count)
    guard odyssey_depth_preparation_stage(handle, Int32(stage), &bytes, bytes.count, &count) == 0
    else { throw TrackingMathError.invalidInput }
    return bytes
  }
}
