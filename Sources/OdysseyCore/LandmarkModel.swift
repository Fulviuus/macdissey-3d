import CryptoKit
import Foundation
import OdysseyInference

public enum LandmarkInferenceError: Error {
  case unexpectedModel
  case invalidTensor
  case runtime(Int32)
}

public struct LandmarkModelOutput {
  public let coordinates: [SIMD2<Float>]
  public let logit: Float
  public let confidence: Float
}

// The recovered default Blink model, executed by pinned native LiteRT on CPU.
// Weights are recovered from the user's local vendor installation and copied
// into the private local build. Architecture-dependent inference
// differences are measured by InferenceReferenceChecks.
public final class LandmarkModel {
  public static let modelSHA256 = "f709156e5b17e07f07b93ae1c0d281d2f00e8b80029912a843184b2496e240cc"
  private let handle: OpaquePointer
  private let lock = NSLock()
  public init(modelURL: URL) throws {
    let data = try Data(contentsOf: modelURL)
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard digest == Self.modelSHA256 else { throw LandmarkInferenceError.unexpectedModel }
    var status: Int32 = 0
    guard let model = odyssey_landmark_create(modelURL.path, &status) else {
      throw LandmarkInferenceError.runtime(status)
    }
    handle = model
  }
  deinit { odyssey_landmark_destroy(handle) }
  public func predict(tensor: [Float]) throws -> LandmarkModelOutput {
    guard tensor.count == 192 * 192, tensor.allSatisfy(\.isFinite) else {
      throw LandmarkInferenceError.invalidTensor
    }
    lock.lock()
    defer { lock.unlock() }
    var coordinates = Array(repeating: Float(0), count: 396)
    var logit: Float = 0
    let status = odyssey_landmark_invoke(
      handle, tensor, tensor.count, &coordinates, coordinates.count, &logit)
    guard status == 0 else { throw LandmarkInferenceError.runtime(status) }
    return LandmarkModelOutput(
      coordinates: stride(from: 0, to: coordinates.count, by: 2).map {
        SIMD2(coordinates[$0], coordinates[$0 + 1])
      }, logit: logit, confidence: try LandmarkProcessing.confidence(logit: logit))
  }
}
