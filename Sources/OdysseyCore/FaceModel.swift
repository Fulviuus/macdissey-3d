import CryptoKit
import Foundation
import OdysseyInference

public enum FaceInferenceError: Error {
  case unexpectedModel, invalidTensor
  case runtime(Int32)
}

/// The original Blink grayscale face model, run by native ONNX Runtime on CPU.
public final class FaceModel {
  public static let modelSHA256 = "71df6bb5243e20463af494e4626c58629c736bd94a7452cb811d63aa5e95dbb3"
  private let handle: OpaquePointer
  private let lock = NSLock()
  public init(modelURL: URL) throws {
    let data = try Data(contentsOf: modelURL)
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard digest == Self.modelSHA256 else { throw FaceInferenceError.unexpectedModel }
    var status: Int32 = 0
    guard let model = odyssey_face_create(modelURL.path, &status) else {
      throw FaceInferenceError.runtime(status)
    }
    handle = model
  }
  deinit { odyssey_face_destroy(handle) }
  public func predict(tensor: [Float]) throws -> [Float] {
    guard tensor.count == 320 * 448, tensor.allSatisfy(\.isFinite) else {
      throw FaceInferenceError.invalidTensor
    }
    lock.lock()
    defer { lock.unlock() }
    var output = Array(repeating: Float(0), count: 107520 + 26880 + 6720)
    let status = odyssey_face_invoke(handle, tensor, tensor.count, &output, output.count)
    guard status == 0 else { throw FaceInferenceError.runtime(status) }
    return output
  }
}
