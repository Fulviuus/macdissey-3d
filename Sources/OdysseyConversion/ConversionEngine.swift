import CoreGraphics
import CoreText
import CoreVideo
import CryptoKit
import Foundation
import Metal
import OdysseyInference

public struct ConversionAdjustment: Equatable, Sendable {
  public private(set) var depth = 10
  public private(set) var popOut = 0
  public init() {}
  public mutating func changeDepth(_ delta: Int) { depth = min(20, max(0, depth + delta)) }
  public mutating func changePopOut(_ delta: Int) { popOut = min(10, max(-10, popOut + delta)) }
  public var depthValue: Int { depth * 5 }
  public var popOutValue: Int { popOut * 5 }
  var scale: Float { depth <= 10 ? Float(depth) / 10 : Float(100 + (depth - 10) * 7) / 100 }
  var shift: Float { Float(popOut) / 10 }
}

// Owned by a single worker queue. The final SBS buffer is display-colored;
// weaving and eye tracking remain the responsibility of the existing renderer.
final class ConversionEngine {
  let gpu: ConversionGPU
  let model: OpaquePointer?
  let videoDepth: VideoDepthPredictor?
  let depthResampler: DepthMapResampler?
  let depthWorker: DepthInferenceWorker<CVPixelBuffer>?
  let modelWidth: Int, modelHeight: Int
  let side: Int
  let width = 1920, height = 1080
  let depthGraph: ConversionDepthGraph
  let stereo: ConversionStereoGraph
  var inferenceRGB: MTLTexture?
  var rgb: MTLTexture
  let normalized: MTLTexture, sliced: MTLTexture,
    modelDepth: MTLTexture,
    depth: MTLTexture
  let importPipeline: MTLRenderPipelineState, exportPipeline: MTLRenderPipelineState
  var textureCache: CVMetalTextureCache
  let outputPool: CVPixelBufferPool
  var input: [Float], output: [Float]
  var lastRGBZ: MTLTexture?
  var hudTexture: MTLTexture
  var hudAdjustment: ConversionAdjustment?
  private let profile = ProcessInfo.processInfo.environment["MACDISSEY_PROFILE_CONVERSION"] == "1"

  init(assets: URL, depthModel: DepthModelConfiguration? = nil) throws {
    var ready = false
    var ownedModel: OpaquePointer?
    var acquired: VideoDepthPredictor?
    defer {
      if !ready {
        if let ownedModel { odyssey_monocular_destroy(ownedModel) }
        acquired?.recycle()
      }
    }
    gpu = try ConversionGPU(root: assets.appendingPathComponent("Shaders"))
    if let depthModel, depthModel.model != .samsung {
      let loaded = try VideoDepthPredictor.acquire(depthModel)
      acquired = loaded
      videoDepth = loaded
      model = nil
      modelWidth = VideoDepthPredictor.width
      modelHeight = VideoDepthPredictor.height
      // The recovered reduction pyramids and histogram dispatches use a
      // power-of-two square. Resample the rectangular prediction into that
      // domain, keeping inference at the configured rectangular dimensions.
      side = 512
      print("2D conversion model: " + depthModel.model.title)
    } else {
      var dimension: Int32 = 0
      var status: Int32 = 0
      let modelURL = assets.appendingPathComponent("model.onnx")
      var accelerated: OpaquePointer?
      if ProcessInfo.processInfo.environment["MACDISSEY_CONVERSION_CPU"] != "1" {
        // Keep compiled models private and separate caches when weights or the
        // runtime change. A read-only/unavailable cache falls back to CPU.
        if let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
          .first,
          let data = try? Data(contentsOf: modelURL, options: .mappedIfSafe)
        {
          let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
          let cache = cacheRoot.appendingPathComponent("macdissey-3d/Conversion/ort-1.30.0/" + hash)
          do {
            try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
            accelerated = odyssey_monocular_create_accelerated(
              modelURL.path, cache.path, &dimension, &status)
          } catch {
            // CPU remains available when the cache cannot be created.
          }
        }
      }
      guard let loaded = accelerated ?? odyssey_monocular_create(modelURL.path, &dimension, &status)
      else {
        throw GPUFailure("Cannot load the 2D conversion model (\(status)).")
      }
      print("2D conversion inference: " + (accelerated == nil ? "CPU" : "Core ML GPU"))
      model = loaded
      ownedModel = loaded
      side = Int(dimension)
      modelWidth = side
      modelHeight = side
      videoDepth = nil
      // If later initialization fails, the partially initialized object does not
      // receive deinit. Release the native session in that case.
    }
    depthResampler = videoDepth == nil ? nil : try DepthMapResampler(gpu: gpu)
    if let videoDepth,
      ProcessInfo.processInfo.environment["MACDISSEY_DEPTH_SYNCHRONOUS"] != "1"
    {
      depthWorker = DepthInferenceWorker<CVPixelBuffer>(
        outputCount: modelWidth * modelHeight, changedScene: { videoDepth.changedScene },
        predict: { try videoDepth.predict($0, output: &$1) })
    } else {
      depthWorker = nil
    }
    depthGraph = try ConversionDepthGraph(
      gpu: gpu, side: side, width: width, height: height, root: assets)
    stereo = try ConversionStereoGraph(
      gpu: gpu, width: width, height: height, samples: depthGraph.buffers["SAM"]!)
    rgb = try gpu.texture(width, height, format: .rgba16Float, mips: true)
    inferenceRGB =
      depthWorker == nil ? nil : try gpu.texture(width, height, format: .rgba16Float, mips: true)
    normalized = try gpu.texture(modelWidth, modelHeight)
    sliced = try gpu.texture(modelWidth, modelHeight * 3, format: .r32Float)
    modelDepth = try gpu.texture(modelWidth, modelHeight, format: .r32Float)
    depth = try gpu.texture(side, side, format: .r32Float)
    input = [Float](repeating: 0, count: modelWidth * modelHeight * 3)
    output = [Float](repeating: 0, count: modelWidth * modelHeight)
    var cache: CVMetalTextureCache?
    guard CVMetalTextureCacheCreate(nil, nil, gpu.device, nil, &cache) == kCVReturnSuccess,
      let cache
    else {
      throw GPUFailure("Cannot create conversion texture cache.")
    }
    textureCache = cache
    var pool: CVPixelBufferPool?
    let attrs: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: width * 2, kCVPixelBufferHeightKey as String: height,
      kCVPixelBufferMetalCompatibilityKey as String: true,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:],
    ]
    guard CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pool) == kCVReturnSuccess,
      let pool
    else {
      throw GPUFailure("Cannot allocate conversion output buffers.")
    }
    outputPool = pool
    hudTexture = try gpu.texture(1, 1, format: .bgra8Unorm)
    gpu.upload(Data(count: 4), hudTexture)
    let library = try gpu.device.makeLibrary(source: Self.bridgeSource, options: gpu.options)
    let device = gpu.device
    let vertex = gpu.vertex
    func pipeline(_ name: String, _ format: MTLPixelFormat) throws -> MTLRenderPipelineState {
      let d = MTLRenderPipelineDescriptor()
      d.vertexFunction = vertex
      d.fragmentFunction = library.makeFunction(name: name)
      d.colorAttachments[0].pixelFormat = format
      return try device.makeRenderPipelineState(descriptor: d)
    }
    importPipeline = try pipeline("importFrame", .rgba16Float)
    exportPipeline = try pipeline("exportStereo", .bgra8Unorm)
    ready = true
  }
  deinit { if let model { odyssey_monocular_destroy(model) } }

  func cvTexture(_ pixel: CVPixelBuffer) throws -> (CVMetalTexture, MTLTexture) {
    guard CVPixelBufferGetPixelFormatType(pixel) == kCVPixelFormatType_32BGRA else {
      throw GPUFailure("Unsupported conversion input format.")
    }
    var cv: CVMetalTexture?
    let code = CVMetalTextureCacheCreateTextureFromImage(
      nil, textureCache, pixel, nil, .bgra8Unorm, CVPixelBufferGetWidth(pixel),
      CVPixelBufferGetHeight(pixel), 0, &cv)
    guard code == kCVReturnSuccess, let cv, let texture = CVMetalTextureGetTexture(cv) else {
      throw GPUFailure("Cannot map conversion frame (\(code)).")
    }
    return (cv, texture)
  }
  func bridge(
    _ pipeline: MTLRenderPipelineState, inputs: [MTLTexture], output: MTLTexture, hud: Bool = false
  ) throws {
    let pd = MTLRenderPassDescriptor()
    pd.colorAttachments[0].texture = output
    pd.colorAttachments[0].loadAction = .dontCare
    pd.colorAttachments[0].storeAction = .store
    let cb = try gpu.commandBuffer()
    guard let e = cb.makeRenderCommandEncoder(descriptor: pd)
    else { throw GPUFailure("Cannot encode conversion frame.") }
    e.setRenderPipelineState(pipeline)
    for (index, texture) in inputs.enumerated() { e.setFragmentTexture(texture, index: index) }
    e.setFragmentSamplerState(gpu.sampler, index: 0)
    var visible: UInt32 = hud ? 1 : 0
    e.setFragmentBytes(&visible, length: 4, index: 0)
    e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    e.endEncoding()
    try gpu.finish(cb)
  }
  func process(_ pixel: CVPixelBuffer?, adjustment: ConversionAdjustment, showHUD: Bool) throws
    -> CVPixelBuffer?
  {
    gpu.beginBatch()
    defer { gpu.discardBatch() }
    let started = Date()
    var checkpoints: [(String, Double)] = []
    func mark(_ name: String) {
      if profile { checkpoints.append((name, Date().timeIntervalSince(started) * 1000)) }
    }
    defer {
      if profile {
        print(
          "Conversion ms: "
            + checkpoints.map { "\($0.0)=\(String(format: "%.2f", $0.1))" }.joined(separator: " "))
      }
    }
    var importedFrame: CVMetalTexture?
    defer { withExtendedLifetime(importedFrame) {} }
    func importFrame(_ pixel: CVPixelBuffer, into target: MTLTexture) throws {
      let (cv, texture) = try cvTexture(pixel)
      importedFrame = cv
      try bridge(importPipeline, inputs: [texture], output: target)
      try gpu.mipmaps(target)
    }
    let completedDepth = try depthWorker?.takeLatest()
    var updatedDepth = false
    var changedScene = false
    if completedDepth != nil, let preparedRGB = inferenceRGB {
      // This texture contains the exact frame which produced the completed map.
      // Swap before preparing another capture, retaining its pixels and mipmaps
      // instead of importing the same full-HD frame twice.
      inferenceRGB = rgb
      rgb = preparedRGB
    }
    if let pixel, depthWorker?.canSubmit ?? true {
      let sourceRGB = inferenceRGB ?? rgb
      try importFrame(pixel, into: sourceRGB)
      try gpu.run(
        "mde/psNormalizeArea", textures: ["SRC": sourceRGB],
        values: [
          "mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225],
          "resolution": [Double(modelWidth), Double(modelHeight)],
        ], outputs: [normalized])
      try gpu.run("mde/psSlice", textures: ["SRC": normalized], outputs: [sliced])
      try gpu.flush()
      input.withUnsafeMutableBytes {
        sliced.getBytes(
          $0.baseAddress!, bytesPerRow: modelWidth * 4,
          from: MTLRegionMake2D(0, 0, modelWidth, modelHeight * 3),
          mipmapLevel: 0)
      }
      mark("preprocess")
      if let depthWorker {
        depthWorker.submit(input, frame: pixel)
      } else if let videoDepth {
        try videoDepth.predict(input, output: &output)
        changedScene = videoDepth.changedScene
        updatedDepth = true
      } else {
        let code = input.withUnsafeBufferPointer { src in
          output.withUnsafeMutableBufferPointer { dst in
            odyssey_monocular_invoke(model, src.baseAddress, src.count, dst.baseAddress, dst.count)
          }
        }
        guard code == 0 else { throw GPUFailure("2D depth inference failed (\(code)).") }
        updatedDepth = true
      }
      mark("inference")
    }
    if let result = completedDepth {
      // Postprocessing, focus and stereo synthesis all use the exact RGB frame
      // which produced this map, even if capture has moved ahead.
      output = result.depth
      changedScene = result.changedScene
      updatedDepth = true
    }
    if updatedDepth {
      output.withUnsafeBytes {
        modelDepth.replace(
          region: MTLRegionMake2D(0, 0, modelWidth, modelHeight), mipmapLevel: 0,
          withBytes: $0.baseAddress!,
          bytesPerRow: modelWidth * 4)
      }
      if let depthResampler {
        try depthResampler.run(gpu: gpu, source: modelDepth, output: depth)
      } else {
        try gpu.run("mde/psVflip", textures: ["SRC": modelDepth], outputs: [depth])
      }
      if changedScene { try depthGraph.resetVideoHistory() }
      lastRGBZ = try depthGraph.process(rgb: rgb, depth: depth)
      mark("depth")
    } else if pixel != nil {
      // A new capture without its own depth must never replace the paired RGB.
      // Controls can still redraw the last completed pair when pixel is nil.
      try gpu.flush()
      return nil
    }
    guard let lastRGBZ else {
      try gpu.flush()
      return nil
    }
    stereo.depthScale = adjustment.scale
    stereo.popOut = adjustment.shift
    let (left, right) = try stereo.process(lastRGBZ, depth: depthGraph.textures["DET"]!)
    mark("stereo")
    if showHUD && hudAdjustment != adjustment { try makeHUD(adjustment) }
    var outputPixel: CVPixelBuffer?
    let attrs = [kCVPixelBufferPoolAllocationThresholdKey as String: 4] as CFDictionary
    let code = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
      nil, outputPool, attrs, &outputPixel)
    if code == kCVReturnWouldExceedAllocationThreshold {
      try gpu.flush()
      return nil
    }
    guard code == kCVReturnSuccess, let outputPixel else {
      throw GPUFailure("Cannot allocate converted frame (\(code)).")
    }
    let (cv, texture) = try cvTexture(outputPixel)
    try bridge(exportPipeline, inputs: [left, right, hudTexture], output: texture, hud: showHUD)
    try gpu.flush()
    withExtendedLifetime(cv) {}
    mark("export")
    return outputPixel
  }
  func makeHUD(_ adjustment: ConversionAdjustment) throws {
    let w = 600
    let h = 104
    var data = Data(count: w * h * 4)
    try data.withUnsafeMutableBytes { bytes in
      guard
        let context = CGContext(
          data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
            | CGImageAlphaInfo.premultipliedFirst.rawValue)
      else { throw GPUFailure("Cannot draw conversion controls.") }
      context.setFillColor(CGColor(gray: 0.08, alpha: 0.92))
      context.addPath(
        CGPath(
          roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerWidth: 18, cornerHeight: 18,
          transform: nil))
      context.fillPath()
      let font = CTFontCreateUIFontForLanguage(.system, 27, nil)!
      let text = "3D Depth  \(adjustment.depthValue)     Pop-Out  \(adjustment.popOutValue)"
      let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
          gray: 1, alpha: 1),
      ]
      let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: attrs))
      context.textPosition = CGPoint(x: 30, y: 39)
      CTLineDraw(line, context)
    }
    hudTexture = try gpu.texture(w, h, format: .bgra8Unorm)
    gpu.upload(data, hudTexture)
    hudAdjustment = adjustment
  }
  private static let bridgeSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct In { float2 uv [[user(locn0)]]; };
    fragment float4 importFrame(In in [[stage_in]], texture2d<float> src [[texture(0)]], sampler s [[sampler(0)]]) {
      return float4(src.sample(s,float2(in.uv.x,1-in.uv.y)).rgb,1);
    }
    fragment float4 exportStereo(In in [[stage_in]], texture2d<float> left [[texture(0)]], texture2d<float> right [[texture(1)]], texture2d<float> hud [[texture(2)]], sampler s [[sampler(0)]], constant uint& visible [[buffer(0)]]) {
      float2 uv=float2(fract(in.uv.x*2),1-in.uv.y);
      float3 c=in.uv.x<0.5 ? left.sample(s,uv).rgb : right.sample(s,uv).rgb;
      float2 h=(float2(uv.x,in.uv.y)-float2(0.34375,0.07))/float2(0.3125,104.0/1080.0);
      if(visible && all(h>=0) && all(h<=1)) { float4 a=hud.sample(s,h); c=a.rgb+c*(1-a.a); }
      return float4(c,1);
    }
    """
}
