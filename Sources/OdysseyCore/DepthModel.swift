import CryptoKit
import Foundation
import OdysseyInference

public enum DepthInferenceError: Error {
  case unexpectedModel, invalidTensor
  case runtime(Int32)
}

/// Original Blink eye-depth network. Output values are camera distances in mm.
public final class DepthModel {
  public static let modelSHA256 = "be2985a295a417dcdaa9565d84aefd46d829f147cd6fbf655f9644a217471342"
  private let handle: OpaquePointer
  private let lock = NSLock()
  public init(modelURL: URL) throws {
    let data = try Data(contentsOf: modelURL)
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard digest == Self.modelSHA256 else { throw DepthInferenceError.unexpectedModel }
    var status: Int32 = 0
    guard let model = odyssey_depth_create(modelURL.path, &status) else {
      throw DepthInferenceError.runtime(status)
    }
    handle = model
  }
  deinit { odyssey_depth_destroy(handle) }
  public func predictRaw(tensor: [Float]) throws -> SIMD2<Float> {
    guard tensor.count == 3 * 224 * 224, tensor.allSatisfy(\.isFinite) else {
      throw DepthInferenceError.invalidTensor
    }
    lock.lock()
    defer { lock.unlock() }
    var output = [Float](repeating: 0, count: 2)
    let status = odyssey_depth_invoke(handle, tensor, tensor.count, &output, output.count)
    guard status == 0 else { throw DepthInferenceError.runtime(status) }
    return SIMD2(output[0], output[1])
  }
  public func predict(tensor: [Float]) throws -> SIMD2<Float> {
    let raw = try predictRaw(tensor: tensor)
    // Blink's original range conversion is not clamped.
    return raw * 800 + SIMD2(repeating: 200)
  }
}
