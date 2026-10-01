import Foundation
import Metal

final class ConversionStereoGraph {
  let gpu: ConversionGPU, w: Int, h: Int, pot: Int
  let disparity: MTLTexture, rgbd: MTLTexture, grf: MTLTexture, view: MTLTexture, udp: MTLTexture,
    warped: MTLTexture
  let rawLeft: MTLTexture, rawRight: MTLTexture, pull: MTLTexture, push: MTLTexture,
    left: MTLTexture, right: MTLTexture, sharpLeft: MTLTexture, sharpRight: MTLTexture,
    detail: MTLTexture
  var textures: [String: MTLTexture] = [:], buffers: [String: MTLBuffer] = [:]
  var depthScale: Float = 1, popOut: Float = 0, previousPopOut: Float = -1, shift: Float = 0
  init(gpu: ConversionGPU, width: Int, height: Int, samples: MTLBuffer) throws {
    self.gpu = gpu
    w = width
    h = height
    var p = 1
    while p < max(w, h) { p *= 2 }
    pot = p
    disparity = try gpu.texture(w, h, format: .r16Float)
    rgbd = try gpu.texture(w, h, format: .rgba16Float)
    grf = try gpu.texture(w, h, format: .r16Float)
    gpu.upload(Data(count: w * h * 2), grf)
    view = try gpu.texture(1, 1, format: .r32Float)
    gpu.upload(Data(count: 4), view)
    let (ut, ub) = try gpu.atomicTexture(w * 2, h, format: .r32Uint)
    udp = ut
    buffers["UDP_atomic"] = ub
    warped = try gpu.texture(w * 2, h, format: .rgba8Unorm)
    rawLeft = try gpu.texture(w, h, format: .rgba16Float)
    rawRight = try gpu.texture(w, h, format: .rgba16Float)
    pull = try gpu.texture(pot, pot, format: .rgba16Float, mips: true)
    push = try gpu.texture(pot, pot, format: .rgba16Float, mips: true)
    left = try gpu.texture(w, h, format: .rgba16Float, mips: true)
    right = try gpu.texture(w, h, format: .rgba16Float, mips: true)
    sharpLeft = try gpu.texture(w, h, format: .rgba16Float)
    sharpRight = try gpu.texture(w, h, format: .rgba16Float)
    detail = try gpu.texture(w, h, format: .r16Float)
    textures = ["RGBZ": rgbd, "GRF": grf, "VIEW": view, "UDP": udp, "IRGB": warped]
    for channel in ["IR", "IG", "IB", "IA"] {
      let (t, b) = try gpu.atomicTexture(w * 2, h, format: .r32Float)
      textures[channel] = t
      buffers[channel + "_atomic"] = b
    }
    // Default virtual-camera setup, recovered from disparity initialize RVA18480.
    let minD: Float = -0.0026
    let maxD: Float = 0.0033
    let near: Float = 0.09090909361839294
    let denom: Float = -0.9090908765792847
    let focus: Float = 0.1
    let a = (minD - maxD) * near
    let vergence = a / (minD * near - maxD)
    let ipd = a / (focus * denom)
    let camera: [Float] = [focus, vergence, ipd]
    buffers["CAM"] = try gpu.buffer(camera.withUnsafeBytes { Data($0) })
    buffers["SAM"] = samples
  }
  func process(_ rgbz: MTLTexture, depth: MTLTexture) throws -> (MTLTexture, MTLTexture) {
    // The original only updates the convergence shift when Pop-Out changes.
    if popOut != previousPopOut {
      let minD: Float = -0.0026
      let maxD: Float = 0.0033
      let range = maxD - minD
      let negative = min(-range - minD, 0)
      let positive = max(range - maxD, 0)
      shift =
        popOut < 0
        ? Float(Double(depthScale) * -1 * Double(popOut) * Double(positive))
        : depthScale * popOut * negative
      previousPopOut = popOut
    }
    try gpu.run(
      "disparity/psDepth2Dspr", textures: ["RGBZ": rgbz], buffers: buffers,
      values: [
        "depth_scale": [Double(depthScale)], "depth_shift": [Double(shift)], "dspr_scale": [-1, 1],
      ], outputs: [disparity])
    try gpu.run(
      "disparity/psMergeRGBZ", textures: ["RGBZ": rgbz, "DSPR": disparity], outputs: [rgbd])
    let ub = buffers["UDP_atomic"]!
    try gpu.fillDepth(ub)
    for channel in ["IR", "IG", "IB", "IA"] {
      try gpu.clear(buffers[channel + "_atomic"]!)
    }
    try gpu.clear(warped)
    var values: [String: [Double]] = [
      "ts": [Double(w), Double(h)], "b_splat": [1], "view_pos": [0.5], "vo": [0],
      "b_write_color": [0],
    ]
    let grid = MTLSize(width: w, height: h, depth: 1)
    try gpu.run("warp/csWarpDspr", textures: textures, buffers: buffers, values: values, grid: grid)
    values["b_write_color"] = [1]
    try gpu.run("warp/csWarpDspr", textures: textures, buffers: buffers, values: values, grid: grid)
    try gpu.run(
      "warp/csAtomicWarpSplatOut", textures: textures, buffers: buffers, values: values,
      grid: MTLSize(width: w * 2, height: h, depth: 1))
    try gpu.run(
      "warp/psDsprLast2", textures: ["SRC": warped], values: values, outputs: [rawLeft, rawRight])
    let iv: [String: [Double]] = [
      "ts": [Double(pot), Double(pot)], "b_use_dspr": [1], "b_hole": [0],
    ]
    try gpu.run(
      "inpaint/psPadToPot2", textures: ["LSRC": rawLeft, "RSRC": rawRight], values: iv,
      outputs: [gpu.view(pull, 0)])
    for level in 1..<pull.mipmapLevelCount {
      try gpu.run(
        "inpaint/psPull", textures: ["PULL": gpu.view(pull, level - 1)],
        outputs: [gpu.view(pull, level)])
    }
    for level in stride(from: push.mipmapLevelCount - 2, through: 0, by: -1) {
      let parent = level == push.mipmapLevelCount - 2 ? pull : push
      try gpu.run(
        "inpaint/psPush",
        textures: ["PULL": gpu.view(pull, level), "PUSH": gpu.view(parent, level + 1)],
        outputs: [gpu.view(push, level)])
    }
    try gpu.run(
      "inpaint/psCropToNpot2",
      textures: ["LSRC": rawLeft, "RSRC": rawRight, "PUSH": gpu.view(push, 0)], values: iv,
      outputs: [left, right])
    try gpu.mipmaps(left)
    try gpu.mipmaps(right)
    try gpu.run(
      "inpaint/psDetailFocus", textures: ["RGBZ": rgbd, "SRC": depth], buffers: buffers,
      values: ["sample_count": [8]], outputs: [detail])
    let dv: [String: [Double]] = [
      "de_strength": [0.4], "de_miplevel": [2], "de_threshold": [0.05], "de_focus": [1],
      "fg_thresh": [0.2], "bg_thresh": [0.3],
    ]
    try gpu.run(
      "inpaint/psUnsharpMask", textures: ["SRC": left, "DFCS": detail], values: dv,
      outputs: [sharpLeft])
    try gpu.run(
      "inpaint/psUnsharpMask", textures: ["SRC": right, "DFCS": detail], values: dv,
      outputs: [sharpRight])
    return (sharpLeft, sharpRight)
  }
}
