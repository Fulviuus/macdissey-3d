import Foundation
import Metal

// Native host for the recovered default depth-processing path.
// Vendor shader text and model weights are supplied separately.
final class ConversionDepthGraph {
  let gpu: ConversionGPU
  let side: Int, w: Int, h: Int, pot: Int
  let nearest: MTLSamplerState
  var textures: [String: MTLTexture] = [:], buffers: [String: MTLBuffer] = [:]
  var frame = 0
  init(gpu: ConversionGPU, side: Int, width: Int, height: Int, root: URL) throws {
    self.gpu = gpu
    self.side = side
    w = width
    h = height
    var power = 1
    while power < side { power *= 2 }
    pot = power
    let sd = MTLSamplerDescriptor()
    sd.minFilter = .nearest
    sd.magFilter = .nearest
    sd.mipFilter = .nearest
    sd.sAddressMode = .clampToEdge
    sd.tAddressMode = .clampToEdge
    nearest = gpu.device.makeSamplerState(descriptor: sd)!
    func add(_ name: String, _ width: Int, _ height: Int, _ f: MTLPixelFormat, _ mips: Bool = false)
      throws
    { textures[name] = try gpu.texture(width, height, format: f, mips: mips) }
    try add("RGB0", w, h, .rgba16Float, true)
    try add("DHSV", w, h, .rgba32Float, true)
    try add("MMMX", pot, pot, .rgba32Float, true)
    try add("MMXS", pot, pot, .rg32Float, true)
    try add("MSLC", pot, pot, .r32Float)
    try add("MSLC_TMP", pot, pot, .r32Float)
    for name in ["DSPR", "DSPRS", "LABS", "EDGS", "DNORM", "IIR0", "IIR1"] {
      try add(name, side, side, .r16Float)
    }
    try add("DSPRS_TMP", side, side, .r16Float)
    try add("SALC", side, side, .rgba16Float)
    try add("REDEPTH", side, side, .rgba16Float)
    try add("DMIN", side, side, .r32Float)
    for name in ["BIC", "GUID", "GDIA", "DET"] { try add(name, w, h, .r16Float) }
    try add("GWGT", w, h, .rg16Float)
    try add("RGBZ", w, h, .rgba16Float)
    for (name, count) in [
      ("HIST4", 16384), ("CDFB", 4096), ("SCB", 32), ("MFCSB", 16), ("STAEND", 4096),
      ("REMAP", 4096), ("SMAP", 4096),
    ] { buffers[name] = try gpu.buffer(Data(count: count)) }
    var sampleData = Data(count: 1024)
    let recovered = try Data(contentsOf: root.appendingPathComponent("samples8.f32"))
    // Eight vec2 samples in the shader's 16-byte std140 array stride.
    guard recovered.count == 128 else { throw GPUFailure("Invalid conversion sample table.") }
    sampleData.replaceSubrange(0..<recovered.count, with: recovered)
    buffers["SAM"] = try gpu.buffer(sampleData)
  }
  func pass(
    _ shader: String, _ dest: String, _ inputs: [String: MTLTexture],
    _ values: [String: [Double]] = [:], nearest names: [String] = []
  ) throws {
    let samplers = Dictionary(uniqueKeysWithValues: names.map { ($0 + "Smplr", nearest) })
    try gpu.run(
      "depth/" + shader, textures: inputs, buffers: buffers, values: values,
      outputs: [textures[dest]!], samplers: samplers)
  }
  func pyramid(_ input: MTLTexture, _ name: String, _ saliency: Bool = false) throws -> MTLTexture {
    let t = textures[name]!
    try gpu.run("depth/psInitMinMax", textures: ["SRC": input], outputs: [gpu.view(t, 0)])
    let weights: [Double] = [2, 3, 3, 2]
    for level in 1..<t.mipmapLevelCount {
      try gpu.run(
        "depth/"
          + (saliency ? "psSalcMipmap" : name == "MMXS" ? "psBuildMinMax" : "psBuildMeanMinMax"),
        textures: ["MMX": gpu.view(t, level - 1)],
        values: ["mipw": [level <= 4 ? weights[level - 1] : 0]], outputs: [gpu.view(t, level)])
    }
    return gpu.view(t, t.mipmapLevelCount - 1)
  }
  func compute(
    _ shader: String, _ input: [String: MTLTexture], _ values: [String: [Double]], _ width: Int,
    _ height: Int, _ group: Int = 32
  ) throws {
    try gpu.run(
      "depth/" + shader, textures: input, buffers: buffers, values: values,
      grid: MTLSize(width: width, height: height, depth: 1),
      group: MTLSize(width: group, height: group == 32 ? 32 : 1, depth: 1))
  }
  func process(rgb: MTLTexture, depth: MTLTexture) throws -> MTLTexture {
    defer { frame += 1 }
    try pass(
      "psHSVDiff", "DHSV", ["RGB0": textures["RGB0"]!, "SRC": rgb], ["frame": [Double(frame)]])
    try gpu.mipmaps(textures["DHSV"]!)
    let dh = textures["DHSV"]!
    try compute(
      "csDetectSceneChange", ["DHSV": gpu.view(dh, dh.mipmapLevelCount - 1)],
      [
        "frame": [Double(frame)], "sc_hsv_weight": [1, 1, 1], "sc_thresh": [0.12],
        "sc_min_length": [15], "sc_prev_index": [Double((frame + 1) & 1)],
        "sc_curr_index": [Double(frame & 1)],
      ], 1, 1, 1)
    try pass("psCopy", "RGB0", ["SRC": rgb])
    let mm = try pyramid(depth, "MMMX")
    try pass("psNormalizeDspr", "DSPR", ["SRC": depth, "MMX": mm])
    try pass(
      "psSalcDspr", "DSPRS", ["DSPR": textures["MMMX"]!],
      ["salc_level_center": [0], "salc_level_surround": [0]], nearest: ["DSPR"])
    let sm = try pyramid(textures["DSPRS"]!, "MMXS")
    try pass("psSmoothstep", "DSPRS_TMP", ["SRC": textures["DSPRS"]!, "MMX": sm])
    try pass("psSalcEdge", "EDGS", ["RGB": rgb])
    try pass(
      "psSalcTexture", "LABS", ["RGB": rgb], ["salc_level_center": [3], "salc_level_surround": [6]])
    try pass(
      "psSalcMerge", "SALC",
      [
        "EDGS": textures["EDGS"]!, "DSPR": textures["DSPR"]!, "LABS": textures["LABS"]!,
        "DSPRS": textures["DSPRS_TMP"]!,
      ],
      [
        "salc_weight_edge": [0.1], "salc_weight_dspr": [0.2], "salc_weight_lab": [0.1],
        "salc_weight_dspr_salc": [0.6], "ts": [Double(pot), Double(pot)],
      ])
    let salcMM = try pyramid(textures["SALC"]!, "MMMX", true)
    try pass(
      "psMergeSalcMipmap", "MSLC_TMP", ["SLCM": gpu.view(textures["MMMX"]!, 1, 4)],
      ["levels": [4], "mip_w": [2, 3, 3, 2]], nearest: ["SLCM"])
    try pass("psSmoothstep", "MSLC", ["SRC": textures["MSLC_TMP"]!, "MMX": salcMM])
    try gpu.clear(buffers["HIST4"]!)
    try compute(
      "csSalcBuildHist", ["DSPR": textures["DSPR"]!, "SALC": textures["SALC"]!],
      ["b_store_pos": [0]], side, side)
    try compute("csSalcCDF", [:], [:], 1024, 1, 1024)
    try pass("psDisparityMap", "DNORM", ["DSPR": textures["DSPR"]!])
    try gpu.clear(buffers["HIST4"]!)
    try compute(
      "csSalcBuildHist", ["DSPR": textures["DNORM"]!, "SALC": textures["MSLC"]!],
      ["b_store_pos": [1]], side, side)
    try gpu.clear(buffers["STAEND"]!)
    try compute(
      "csFindMainFocus", [:],
      [
        "frame": [Double(frame)], "remove_rate": [0.003], "merge_threshold": [0.001],
        "b_reselect": [0], "focus_eps": [0.01], "iir_weight": [0.02], "iir_when_scene_change": [1],
        "ts": [Double(side), Double(side)],
      ], 1024, 1, 1024)
    try compute(
      "csBuildRemapFunc", [:],
      ["comp": [1], "expnd": [1], "comp0": [1], "expnd0": [1], "b_remap_subfocus": [1]], 1024, 1,
      1024)
    try pass(
      "psRemapDepth", "REDEPTH", ["SRC": textures["DNORM"]!],
      ["b_remap_depth": [1], "b_remap_curved": [0]])
    let previous = "IIR\(frame&1)"
    let current = "IIR\((frame+1)&1)"
    try pass(
      "psDepthFilterLocalIIR", current, ["SRC": textures["REDEPTH"]!, "IIR": textures[previous]!],
      ["frame": [Double(frame)], "slope": [2], "weight_min": [0.1], "weight_max": [1]])
    try pass(
      "psDilateDepth", "DMIN", ["SRC": textures[current]!],
      ["dil_rad": [0.006], "sample_count": [8]])
    try pass("psBicubic", "BIC", ["SRC": textures["DMIN"]!])
    let guided: [String: [Double]] = [
      "guided_radius": [8], "guided_epsilon": [0.04], "sample_count": [8],
    ]
    try pass("psDepthGuidedWeight", "GWGT", ["RGB": rgb, "SRC": textures["BIC"]!], guided)
    try pass(
      "psDepthGuidedFilter", "GUID",
      ["RGB": rgb, "SRC": textures["BIC"]!, "GWGT": textures["GWGT"]!], guided)
    try pass(
      "psDepthGuidedDilate", "GDIA", ["SRC": textures["GUID"]!],
      ["guided_dil_rad": [0.002], "sample_count": [8]])
    try pass(
      "psDepthDither", "DET", ["SRC": textures["GDIA"]!],
      [
        "contour_threshold": [0.05], "foreground_thresh": [0.2], "background_thresh": [0.3],
        "dither_strength": [0.01],
      ])
    try pass("psMergeRGBZ", "RGBZ", ["RGB": rgb, "SRC": textures["DET"]!])
    return textures["RGBZ"]!
  }
}
