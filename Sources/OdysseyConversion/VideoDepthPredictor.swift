// Streaming cache arithmetic adapted from Video-Depth-Anything, Copyright
// (2025) Bytedance Ltd. and/or its affiliates, Apache-2.0. See the bundled
// Video-Depth-Anything-LICENSE.txt and THIRD_PARTY_NOTICES.md.
import CoreML
import Foundation

/// One worker owns predictions and history; the preparation cache leases it exclusively.
public final class VideoDepthPredictor {
  public static let width = 518, height = 294
  private static let prepared = DepthRuntimeCache<VideoDepthPredictor>()
  private let first: MLModel, stream: MLModel
  private let image: MLMultiArray
  private var cached: [MLMultiArray] = []
  private final class Frame {
    let planes: [[UInt16]]
    init(_ planes: [[UInt16]]) { self.planes = planes }
  }
  private var history: [Frame] = []
  private var scene = VideoSceneDetector()
  public private(set) var changedScene = false
  private static let channels = [192, 192, 384, 384, 64, 64, 64, 64]
  private static let rows = [777, 777, 209, 209, 777, 777, 3108, 3108]

  private static func key(_ configuration: DepthModelConfiguration) -> String {
    configuration.directory.standardizedFileURL.path
  }
  static func prepare(
    _ configuration: DepthModelConfiguration, completion: ((Result<Void, Error>) -> Void)? = nil
  ) {
    prepared.prepare(key: key(configuration), completion: completion) { try warmed(configuration) }
  }
  static func acquire(_ configuration: DepthModelConfiguration) throws -> VideoDepthPredictor {
    let value = try prepared.acquire(key: key(configuration)) { try warmed(configuration) }
    value.reset()
    return value
  }
  func recycle() {
    reset()
    Self.prepared.release(self)
  }
  static func clearPrepared() { prepared.clear() }
  private static func warmed(_ configuration: DepthModelConfiguration) throws -> VideoDepthPredictor
  {
    let value = try VideoDepthPredictor(configuration)
    let input = [Float](repeating: 0, count: width * height * 3)
    var output = [Float](repeating: 0, count: width * height)
    try value.predict(input, output: &output)
    try value.predict(input, output: &output)
    value.reset()
    return value
  }

  public init(_ configuration: DepthModelConfiguration) throws {
    guard configuration.model == .videoSmall else {
      throw GPUFailure("Unsupported video depth model.")
    }
    let settings = MLModelConfiguration()
    settings.computeUnits =
      ProcessInfo.processInfo.environment["MACDISSEY_CONVERSION_CPU"] == "1" ? .cpuOnly : .cpuAndGPU
    settings.allowLowPrecisionAccumulationOnGPU = true
    first = try MLModel(
      contentsOf: configuration.directory.appendingPathComponent("first.mlmodelc"),
      configuration: settings)
    stream = try MLModel(
      contentsOf: configuration.directory.appendingPathComponent("stream.mlmodelc"),
      configuration: settings)
    image = try MLMultiArray(
      shape: [1, 1, 3, NSNumber(value: Self.height), NSNumber(value: Self.width)],
      dataType: .float32)
    // Read and validate the fixed graph contract instead of assuming feature order.
    for i in 0..<8 {
      let expected = [Self.rows[i], 31, Self.channels[i]]
      guard
        let constraint = stream.modelDescription.inputDescriptionsByName["history\(i)"]?
          .multiArrayConstraint,
        constraint.shape.map(\.intValue) == expected, constraint.dataType == .float16
      else {
        throw GPUFailure("The bundled video depth model has an incompatible history layout.")
      }
      cached.append(
        try MLMultiArray(shape: expected.map(NSNumber.init(value:)), dataType: .float16))
    }
  }
  public func reset() {
    history.removeAll(keepingCapacity: true)
    scene.reset()
    changedScene = false
  }

  public func predict(_ input: [Float], output: inout [Float]) throws {
    let pixels = Self.width * Self.height
    guard input.count == pixels * 3, output.count == pixels, input.allSatisfy(\.isFinite) else {
      throw GPUFailure("Invalid video depth input dimensions or values.")
    }
    changedScene = scene.changed(input, width: Self.width, height: Self.height)
    if changedScene { history.removeAll(keepingCapacity: true) }
    image.withUnsafeMutableBufferPointer(ofType: Float.self) { destination, strides in
      input.withUnsafeBufferPointer { source in
        // An allocated dense input is contiguous; no per-element NSNumber conversion.
        precondition(strides.last == 1 && destination.count >= input.count)
        destination.baseAddress!.update(from: source.baseAddress!, count: input.count)
      }
    }
    var features: [String: Any] = ["image": image]
    if !history.isEmpty {
      // Upstream selection: first two anchors followed by the most recent 29 frames.
      let selected = Array(history.prefix(2)) + Array(history.suffix(29))
      for i in 0..<8 {
        let channels = Self.channels[i]
        let rows = Self.rows[i]
        cached[i].withUnsafeMutableBytes { destination, strides in
          let target = destination.baseAddress!.assumingMemoryBound(to: UInt16.self)
          precondition(strides[2] == 1)
          for frame in 0..<31 {
            selected[frame].planes[i].withUnsafeBufferPointer { source in
              for row in 0..<rows {
                target.advanced(by: row * strides[0] + frame * strides[1])
                  .update(from: source.baseAddress!.advanced(by: row * channels), count: channels)
              }
            }
          }
        }
        features["history\(i)"] = cached[i]
      }
    }
    let prediction = try (history.isEmpty ? first : stream).prediction(
      from: MLDictionaryFeatureProvider(dictionary: features))
    guard let depth = prediction.featureValue(for: "depth")?.multiArrayValue,
      depth.dataType == .float32, depth.shape.map(\.intValue) == [1, 1, Self.height, Self.width]
    else {
      throw GPUFailure("The video depth model returned an unexpected depth map.")
    }
    depth.withUnsafeBufferPointer(ofType: Float.self) { values in
      let strides = depth.strides.map(\.intValue)
      for y in 0..<Self.height {
        for x in 0..<Self.width {
          output[y * Self.width + x] = values[y * strides[2] + x * strides[3]]
        }
      }
    }
    guard output.allSatisfy(\.isFinite) else {
      throw GPUFailure("The video depth model returned invalid values.")
    }
    var planes: [[UInt16]] = []
    for i in 0..<8 {
      guard let array = prediction.featureValue(for: "cache\(i)")?.multiArrayValue,
        array.dataType == .float16,
        array.shape.map(\.intValue) == [Self.rows[i], 1, Self.channels[i]]
      else {
        throw GPUFailure("The video depth model returned an unexpected history layout.")
      }
      var values = [UInt16](repeating: 0, count: Self.rows[i] * Self.channels[i])
      array.withUnsafeBytes { source in
        let strides = array.strides.map(\.intValue)
        let pointer = source.baseAddress!.assumingMemoryBound(to: UInt16.self)
        values.withUnsafeMutableBufferPointer { destination in
          for row in 0..<Self.rows[i] {
            if strides[2] == 1 {
              destination.baseAddress!.advanced(by: row * Self.channels[i]).update(
                from: pointer.advanced(by: row * strides[0]), count: Self.channels[i])
            } else {
              for channel in 0..<Self.channels[i] {
                destination[row * Self.channels[i] + channel] =
                  pointer[row * strides[0] + channel * strides[2]]
              }
            }
          }
        }
      }
      planes.append(values)
    }
    let frame = Frame(planes)
    if history.isEmpty {
      history = Array(repeating: frame, count: 32)
    } else {
      history.append(frame)
    }
    if history.count > 42 { history.remove(at: 1) }
  }
}
