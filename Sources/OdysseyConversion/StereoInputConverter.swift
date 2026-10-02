import CoreVideo
import Foundation
import Metal

/// Normalizes a captured stereo layout to the two panes consumed by the original
/// weaver. Owned by the capture queue. No tracking/calibration math changes here.
public final class StereoInputConverter {
  public let settings: StereoInputSettings
  private let gpu: ConversionGPU
  private var cache: CVMetalTextureCache
  private var pool: CVPixelBufferPool?
  private var sourceWidth = 0, sourceHeight = 0, outputWidth = 0, outputHeight = 0
  private var history: [MTLTexture] = []
  private var historyIndex = 0, historyCount = 0
  private var lastTimestamp: Double?
  private var sequentialRight = false
  private var recovery: [String: MTLTexture] = [:]
  private var recoveryValid = false
  private let zero: MTLTexture

  public init(settings: StereoInputSettings, shaders: URL) throws {
    self.settings = settings.validated
    gpu = try ConversionGPU(root: shaders)
    var cache: CVMetalTextureCache?
    guard CVMetalTextureCacheCreate(nil, nil, gpu.device, nil, &cache) == kCVReturnSuccess,
      let cache
    else { throw GPUFailure("Cannot create stereo input texture cache.") }
    self.cache = cache
    zero = try gpu.texture(1, 1)
    gpu.upload(Data(count: 16), zero)
    // Compile before capture starts, on the session's startup worker.
    let recovery = self.settings.format == .anaglyph && self.settings.anaglyphMode == 4
    let linear =
      self.settings.format == .anaglyph
      || (self.settings.format == .pulfrich && self.settings.pulfrichND)
    _ = try gpu.stage(
      recovery ? "PSMain" : self.settings.format.shader,
      formats: [linear ? .bgra8Unorm_srgb : .bgra8Unorm])
    if recovery {
      for name in ["PSDown", "PSAnaDisp", "PSAnaRefine", "PSAnaFill", "PSAnaSmooth"] {
        _ = try gpu.stage(name, formats: [.rgba16Float])
      }
      _ = try gpu.stage("PSAnaDesc", formats: Array(repeating: .rgba32Uint, count: 4))
    }
  }

  private func mapped(_ pixel: CVPixelBuffer, linear: Bool) throws -> (CVMetalTexture, MTLTexture) {
    var cv: CVMetalTexture?
    let code = CVMetalTextureCacheCreateTextureFromImage(
      nil, cache, pixel, nil, linear ? .bgra8Unorm_srgb : .bgra8Unorm, CVPixelBufferGetWidth(pixel),
      CVPixelBufferGetHeight(pixel), 0, &cv)
    guard code == kCVReturnSuccess, let cv, let texture = CVMetalTextureGetTexture(cv) else {
      throw GPUFailure("Cannot map stereo input (\(code)).")
    }
    return (cv, texture)
  }

  private func configure(_ w: Int, _ h: Int) throws {
    guard w >= 2, h >= 2, w <= 4096, h <= 4096 else {
      throw GPUFailure("Stereo capture must be between 2 and 4096 pixels per dimension.")
    }
    guard sourceWidth != w || sourceHeight != h else { return }
    sourceWidth = w
    sourceHeight = h
    history = []
    historyCount = 0
    historyIndex = 0
    lastTimestamp = nil
    sequentialRight = false
    recovery = [:]
    recoveryValid = false
    var ew = w
    var eh = h
    switch settings.format {
    case .fullSBS:
      ew = w / 2
      eh = h / 2
    case .halfSBS, .columnInterleaved: ew = w / 2
    case .fullTAB, .halfTAB, .rowInterleaved: eh = h / 2
    case .framePacking: eh = max(1, Int((Double(h) * 1080 / 2205).rounded()))
    case .quilt, .vr180TAB, .vr180SBS, .vr360TAB, .vr360SBS:
      ew = min(1920, w)
      eh = max(1, ew * 9 / 16)
    case .anaglyph: if settings.anaglyphMode == 4 { ew = w / 2 }
    default: break
    }
    outputWidth = ew * 2
    outputHeight = eh
    let attrs: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: outputWidth,
      kCVPixelBufferHeightKey as String: outputHeight,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:],
      kCVPixelBufferMetalCompatibilityKey as String: true,
    ]
    guard CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pool) == kCVReturnSuccess else {
      throw GPUFailure("Cannot create stereo input output pool.")
    }
    if settings.format == .frameSequential || (settings.format == .pulfrich && !settings.pulfrichND)
    {
      let count = settings.format == .frameSequential ? 1 : settings.delayFrames
      for _ in 0..<count { history.append(try gpu.texture(w, h, format: .bgra8Unorm)) }
    }
    if settings.format == .anaglyph && settings.anaglyphMode == 4 {
      let w16 = (w + 15) / 16
      let h16 = (h + 15) / 16
      for name in ["src16", "disp0"] {
        recovery[name] = try gpu.texture(w16, h16, format: .rgba16Float)
      }
      for name in ["src4", "disp1", "disp2", "dispF", "dispPrev", "srcPrev"] {
        recovery[name] = try gpu.texture(w16 * 4, h16 * 4, format: .rgba16Float)
      }
      for name in ["descTexA", "descTexB", "descTexC", "descTexD"] {
        recovery[name] = try gpu.texture(w16 * 4, h16 * 4, format: .rgba32Uint)
      }
    }
  }

  private func copy(_ source: MTLTexture, to target: MTLTexture) throws {
    let cb = try gpu.commandBuffer()
    guard let e = cb.makeBlitCommandEncoder() else {
      throw GPUFailure("Cannot retain stereo frame.")
    }
    e.copy(from: source, to: target)
    e.endEncoding()
    try gpu.finish(cb)
  }

  public func process(_ pixel: CVPixelBuffer, timestamp: Double) throws -> CVPixelBuffer? {
    guard timestamp.isFinite else { throw GPUFailure("Invalid stereo capture timestamp.") }
    guard CVPixelBufferGetPixelFormatType(pixel) == kCVPixelFormatType_32BGRA else {
      throw GPUFailure("Unsupported stereo input pixel format.")
    }
    try configure(CVPixelBufferGetWidth(pixel), CVPixelBufferGetHeight(pixel))
    // Duplicate capture timestamps never advance a temporal eye pair. After a
    // discontinuity the first frame warms history; swapping eyes selects phase.
    if let lastTimestamp, timestamp <= lastTimestamp { return nil }
    if let lastTimestamp, timestamp - lastTimestamp > 0.25 {
      historyCount = 0
      historyIndex = 0
      sequentialRight = false
      recoveryValid = false
    }
    lastTimestamp = timestamp
    let linear =
      settings.format == .anaglyph || (settings.format == .pulfrich && settings.pulfrichND)
    let (cv, source) = try mapped(pixel, linear: linear)
    defer { withExtendedLifetime(cv) {} }
    var result: CVPixelBuffer?
    let code = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
      nil, pool!, [kCVPixelBufferPoolAllocationThresholdKey as String: 4] as CFDictionary, &result)
    guard code == kCVReturnSuccess, let result else {
      if code == kCVReturnWouldExceedAllocationThreshold {
        // The next accepted capture starts a fresh pair, not stale temporal state.
        historyCount = 0
        historyIndex = 0
        sequentialRight = false
        recoveryValid = false
        return nil
      }
      throw GPUFailure("Cannot allocate stereo output (\(code)).")
    }
    let (outCV, output) = try mapped(result, linear: linear)
    defer { withExtendedLifetime(outCV) {} }
    gpu.beginBatch()
    defer { gpu.discardBatch() }
    let w = Double(sourceWidth)
    let h = Double(sourceHeight)
    var values: [String: [Double]] = [
      "g_format": [Double(settings.format.code)], "g_swap": [settings.swapEyes ? 1 : 0],
      "g_srcW": [w], "g_srcH": [h],
      "g_anaCombo": [Double(settings.anaglyphPair)], "g_anaMode": [Double(settings.anaglyphMode)],
      "g_pulfMode": [settings.pulfrichND ? 1 : 0], "g_pulfEye": [Double(settings.affectedEye)],
      "g_ndTrans": [settings.transmission],
      "g_fpEyeFrac": [1080.0 / 2205], "g_fpGapFrac": [45.0 / 2205],
      "g_fpEyeAlign": [settings.framePackingAlignment],
      "g_dispMaxUV": [0.06], "g_quiltCols": [Double(settings.quiltColumns)],
      "g_quiltRows": [Double(settings.quiltRows)],
      "g_quiltLeftIdx": [Double(settings.quiltLeft)],
      "g_quiltRightIdx": [Double(settings.quiltRight)],
      "g_paneW": [Double(outputWidth / 2)], "g_paneH": [Double(outputHeight)],
      "g_vrYaw": [settings.yaw * .pi / 180], "g_vrPitch": [settings.pitch * .pi / 180],
      "g_vrZoom": [settings.zoom],
      "g_vrIs360": [settings.format == .vr360SBS || settings.format == .vr360TAB ? 1 : 0],
      "g_vrIsSBS": [settings.format == .vr180SBS || settings.format == .vr360SBS ? 1 : 0],
    ]
    var inputs = Dictionary(
      uniqueKeysWithValues: [
        "srcPrev", "dispTex", "anaTintTex", "anaBoxTex", "anaShiftTex", "srcQ", "changeTex",
        "anaBoxMapTex", "pairTex",
      ].map { ($0, zero) })
    inputs["srcTex"] = source
    if !history.isEmpty {
      if historyCount == 0 {
        for frame in history { try copy(source, to: frame) }
      }
      inputs["srcPrev"] = history[historyIndex]
      if settings.format == .frameSequential {
        // First capture is left, second right; alternate assignment rather than
        // reversing the views every frame. Screen capture cannot recover lost
        // source parity, so this mode remains explicitly experimental.
        values["g_swap"] = [(settings.swapEyes != !sequentialRight) ? 1 : 0]
      }
    }
    var shader = settings.format.shader
    if !recovery.isEmpty {
      values["g_temporal"] = [recoveryValid ? 1 : 0]
      values["g_lvlToSrcX"] = [Double(recovery["src16"]!.width * 16) / w]
      values["g_lvlToSrcY"] = [Double(recovery["src16"]!.height * 16) / h]
      func pass(_ name: String, _ dest: String, _ src: MTLTexture, _ prior: MTLTexture? = nil)
        throws
      {
        let t = recovery[dest]!
        values["g_coarseW"] = [Double(t.width)]
        values["g_coarseH"] = [Double(t.height)]
        var textures = [
          "srcTex": src, "dispTex": prior ?? zero, "dispPrevTex": recovery["dispPrev"]!,
          "srcPrevQ": recovery["srcPrev"]!,
        ]
        for name in ["descTexA", "descTexB", "descTexC", "descTexD"] {
          textures[name] = recovery[name]!
        }
        try gpu.run(name, textures: textures, values: values, outputs: [t])
      }
      try pass("PSDown", "src4", source)
      try pass("PSDown", "src16", recovery["src4"]!)
      try pass("PSAnaDisp", "disp0", recovery["src16"]!)
      values["g_coarseW"] = [Double(recovery["src4"]!.width)]
      values["g_coarseH"] = [Double(recovery["src4"]!.height)]
      try gpu.run(
        "PSAnaDesc", textures: ["srcTex": recovery["src4"]!], values: values,
        outputs: ["descTexA", "descTexB", "descTexC", "descTexD"].map { recovery[$0]! })
      try pass("PSAnaRefine", "disp1", recovery["src4"]!, recovery["disp0"]!)
      try pass("PSAnaFill", "disp2", recovery["src4"]!, recovery["disp1"]!)
      try pass("PSAnaSmooth", "dispF", recovery["src4"]!, recovery["disp2"]!)
      inputs["dispTex"] = recovery["dispF"]!
      inputs["srcQ"] = recovery["src4"]!
      try copy(recovery["dispF"]!, to: recovery["dispPrev"]!)
      try copy(recovery["src4"]!, to: recovery["srcPrev"]!)
      shader = "PSMain"
    }
    try gpu.run(shader, textures: inputs, values: values, outputs: [output])
    if !history.isEmpty {
      try copy(source, to: history[historyIndex])
      historyIndex = (historyIndex + 1) % history.count
      historyCount += 1
      sequentialRight.toggle()
    }
    try gpu.flush()
    recoveryValid = true
    return result
  }
}
