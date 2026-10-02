import Foundation
import Metal

// Executes Metal image programs for vendor conversion and open-source stereo decoding.
struct GPUFailure: LocalizedError, CustomStringConvertible {
  let description: String
  var errorDescription: String? { description }
  init(_ text: String) { description = text }
}
final class ConversionGPU {
  let device: MTLDevice
  let queue: MTLCommandQueue
  let sampler: MTLSamplerState
  let vertex: MTLFunction
  let root: URL
  let options: MTLCompileOptions
  struct Stage {
    var compute: MTLComputePipelineState?
    var render: MTLRenderPipelineState?
    var args: [MTLArgument]
    var types: [String: String] = [:]
  }
  var stages: [String: Stage] = [:]
  private var batch: MTLCommandBuffer?
  private var batching = false
  private let serial = ProcessInfo.processInfo.environment["MACDISSEY_CONVERSION_SERIAL_GPU"] == "1"
  private var fillPipeline: MTLComputePipelineState?

  // A conversion has only two CPU/GPU boundaries: model input readback and
  // finished stereo output. Tracked resources preserve dependencies between
  // encoders, including texture views and buffer-backed atomic textures.
  func beginBatch() { batching = !serial }
  func discardBatch() {
    batch = nil
    batching = false
  }
  func commandBuffer() throws -> MTLCommandBuffer {
    if let batch { return batch }
    guard let command = queue.makeCommandBuffer() else {
      throw GPUFailure("Cannot queue conversion work.")
    }
    if batching { batch = command }
    return command
  }
  func finish(_ command: MTLCommandBuffer) throws {
    guard batch !== command else { return }
    command.commit()
    command.waitUntilCompleted()
    if let error = command.error { throw error }
  }
  func flush() throws {
    guard let command = batch else { return }
    batch = nil
    try finish(command)
  }
  func clear(_ buffer: MTLBuffer) throws {
    let command = try commandBuffer()
    guard let encoder = command.makeBlitCommandEncoder() else {
      throw GPUFailure("Cannot clear conversion buffer.")
    }
    encoder.fill(buffer: buffer, range: 0..<buffer.length, value: 0)
    encoder.endEncoding()
    try finish(command)
  }
  func clear(_ texture: MTLTexture) throws {
    let command = try commandBuffer()
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
    pass.colorAttachments[0].storeAction = .store
    guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
      throw GPUFailure("Cannot clear conversion texture.")
    }
    encoder.endEncoding()
    try finish(command)
  }
  func fillDepth(_ buffer: MTLBuffer) throws {
    if fillPipeline == nil {
      let library = try device.makeLibrary(
        source: """
          #include <metal_stdlib>
          using namespace metal;
          kernel void fillDepth(device uint* values [[buffer(0)]], constant uint& count [[buffer(1)]], uint i [[thread_position_in_grid]]) {
            if (i < count) values[i] = 0x40000000u;
          }
          """, options: options)
      fillPipeline = try device.makeComputePipelineState(
        function: library.makeFunction(name: "fillDepth")!)
    }
    let command = try commandBuffer()
    guard let encoder = command.makeComputeCommandEncoder() else {
      throw GPUFailure("Cannot initialize warp depth.")
    }
    encoder.setComputePipelineState(fillPipeline!)
    encoder.setBuffer(buffer, offset: 0, index: 0)
    var count = UInt32(buffer.length / 4)
    encoder.setBytes(&count, length: 4, index: 1)
    encoder.dispatchThreads(
      MTLSize(width: Int(count), height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
    encoder.endEncoding()
    try finish(command)
  }

  init(root: URL) throws {
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
      throw GPUFailure("No Metal")
    }
    self.device = device
    self.queue = queue
    self.root = root
    options = MTLCompileOptions()
    options.fastMathEnabled = false
    options.languageVersion = .version3_0
    let sd = MTLSamplerDescriptor()
    sd.minFilter = .linear
    sd.magFilter = .linear
    sd.mipFilter = .linear
    sd.sAddressMode = .clampToEdge
    sd.tAddressMode = .clampToEdge
    sampler = device.makeSamplerState(descriptor: sd)!
    vertex = try device.makeLibrary(
      source: """
        #include <metal_stdlib>
        using namespace metal;
        struct Out { float4 position [[position]]; float2 uv [[user(locn0)]]; };
        vertex Out triangle(uint i [[vertex_id]]) {
          float2 uv = float2((i << 1) & 2, i & 2);
          return {float4(uv.x*2-1,1-uv.y*2,0,1),uv};
        }
        """, options: options
    ).makeFunction(name: "triangle")!
  }
  func stage(_ name: String, formats: [MTLPixelFormat] = []) throws -> Stage {
    let key = name + formats.map { "-\($0.rawValue)" }.joined()
    if let s = stages[key] { return s }
    let source = try String(
      contentsOf: root.appendingPathComponent(name + ".metal"), encoding: .utf8)
    let library = try device.makeLibrary(source: source, options: options)
    // SPIRV-Cross uses this alignment for atomics on buffer-backed textures.
    let constants = MTLFunctionConstantValues()
    var alignment = UInt32(device.minimumLinearTextureAlignment(for: .r32Uint))
    constants.setConstantValue(&alignment, type: .uint, index: 65535)
    let f = try library.makeFunction(name: "main0", constantValues: constants)
    var result: Stage
    if formats.isEmpty {
      var reflection: MTLComputePipelineReflection?
      let p = try device.makeComputePipelineState(
        function: f, options: [.argumentInfo, .bufferTypeInfo], reflection: &reflection)
      result = Stage(compute: p, args: reflection!.arguments)
    } else {
      let pd = MTLRenderPipelineDescriptor()
      pd.vertexFunction = vertex
      pd.fragmentFunction = f
      for (i, format) in formats.enumerated() { pd.colorAttachments[i].pixelFormat = format }
      var reflection: MTLRenderPipelineReflection?
      let p = try device.makeRenderPipelineState(
        descriptor: pd, options: [.argumentInfo, .bufferTypeInfo], reflection: &reflection)
      result = Stage(render: p, args: reflection!.fragmentArguments!)
    }
    let pattern = try NSRegularExpression(
      pattern: #"(?:device|constant)\s+(\w+)&\s+(\w+)\s+\[\[buffer"#)
    for match in pattern.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
      let type = String(source[Range(match.range(at: 1), in: source)!])
      let name = String(source[Range(match.range(at: 2), in: source)!])
      result.types[name] = type
    }
    stages[key] = result
    return result
  }
  func texture(_ w: Int, _ h: Int, format: MTLPixelFormat = .rgba32Float, mips: Bool = false)
    throws -> MTLTexture
  {
    let d = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: format, width: w, height: h, mipmapped: mips)
    d.storageMode = .shared
    d.usage = [.shaderRead, .shaderWrite, .renderTarget, .pixelFormatView]
    guard let texture = device.makeTexture(descriptor: d) else {
      throw GPUFailure("Cannot allocate conversion texture.")
    }
    return texture
  }
  func atomicTexture(_ w: Int, _ h: Int, format: MTLPixelFormat) throws -> (MTLTexture, MTLBuffer) {
    let align = device.minimumLinearTextureAlignment(for: format)
    let pitch = (w * 4 + align - 1) / align * align
    guard let buffer = device.makeBuffer(length: pitch * h, options: .storageModeShared) else {
      throw GPUFailure("Cannot allocate conversion buffer.")
    }
    memset(buffer.contents(), 0, buffer.length)
    let d = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: format, width: w, height: h, mipmapped: false)
    d.storageMode = .shared
    d.usage = [.shaderRead, .shaderWrite]
    guard let texture = buffer.makeTexture(descriptor: d, offset: 0, bytesPerRow: pitch) else {
      throw GPUFailure("Cannot map conversion buffer.")
    }
    return (texture, buffer)
  }
  func buffer(_ bytes: Data) throws -> MTLBuffer {
    try bytes.withUnsafeBytes {
      guard let address = $0.baseAddress,
        let buffer = device.makeBuffer(
          bytes: address, length: $0.count, options: .storageModeShared)
      else { throw GPUFailure("Cannot allocate conversion buffer.") }
      return buffer
    }
  }
  func data(_ texture: MTLTexture) -> Data {
    let size: Int
    switch texture.pixelFormat {
    case .r32Float, .r32Uint: size = 4
    case .r16Float: size = 2
    case .rg16Float: size = 4
    case .rg32Float: size = 8
    case .rgba16Float: size = 8
    case .rgba32Float: size = 16
    case .rgba8Unorm: size = 4
    default: fatalError("format")
    }
    var out = Data(count: texture.width * texture.height * size)
    out.withUnsafeMutableBytes {
      texture.getBytes(
        $0.baseAddress!, bytesPerRow: texture.width * size,
        from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
    }
    return out
  }
  func upload(_ bytes: Data, _ texture: MTLTexture) {
    let pitch = bytes.count / texture.height
    bytes.withUnsafeBytes {
      texture.replace(
        region: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0,
        withBytes: $0.baseAddress!, bytesPerRow: pitch)
    }
  }
  func uniform(_ arg: MTLArgument, _ values: [String: [Double]]) throws -> MTLBuffer {
    guard let type = arg.bufferStructType else { throw GPUFailure("No struct for \(arg.name)") }
    guard
      let bytes = device.makeBuffer(
        length: max(16, arg.bufferDataSize), options: .storageModeShared)
    else { throw GPUFailure("Cannot allocate conversion uniforms.") }
    memset(bytes.contents(), 0, bytes.length)
    for member in type.members {
      guard let list = values[member.name] else { continue }  // GLSL uniforms start at zero.
      var count: Int
      var integer = false
      switch member.dataType {
      case .float: count = 1
      case .float2: count = 2
      case .float3: count = 3
      case .float4: count = 4
      case .int, .uint, .bool:
        count = 1
        integer = true
      case .int2, .uint2:
        count = 2
        integer = true
      case .int3, .uint3:
        count = 3
        integer = true
      case .int4, .uint4:
        count = 4
        integer = true
      default: throw GPUFailure("Unhandled uniform type \(member.name) \(member.dataType)")
      }
      guard list.count == count, member.offset + count * 4 <= bytes.length else {
        throw GPUFailure("Uniform size \(member.name)")
      }
      for i in 0..<count {
        let bits: UInt32 = integer ? UInt32(bitPattern: Int32(list[i])) : Float(list[i]).bitPattern
        bytes.contents().storeBytes(of: bits, toByteOffset: member.offset + i * 4, as: UInt32.self)
      }
    }
    return bytes
  }
  func mipmaps(_ texture: MTLTexture) throws {
    let cb = try commandBuffer()
    guard let e = cb.makeBlitCommandEncoder() else {
      throw GPUFailure("Cannot encode conversion mipmaps.")
    }
    e.generateMipmaps(for: texture)
    e.endEncoding()
    try finish(cb)
  }
  func view(_ texture: MTLTexture, _ level: Int, _ count: Int = 1) -> MTLTexture {
    texture.makeTextureView(
      pixelFormat: texture.pixelFormat, textureType: .type2D, levels: level..<(level + count),
      slices: 0..<1)!
  }
  func run(
    _ name: String, textures: [String: MTLTexture], buffers: [String: MTLBuffer] = [:],
    values: [String: [Double]] = [:], outputs: [MTLTexture] = [],
    samplers: [String: MTLSamplerState] = [:], grid: MTLSize? = nil,
    group: MTLSize = MTLSize(width: 32, height: 32, depth: 1)
  ) throws {
    let s = try stage(name, formats: outputs.map(\.pixelFormat))
    let cb = try commandBuffer()
    let compute = s.compute != nil
    let ce: MTLComputeCommandEncoder?
    let re: MTLRenderCommandEncoder?
    if compute {
      ce = cb.makeComputeCommandEncoder()!
      re = nil
      ce!.setComputePipelineState(s.compute!)
    } else {
      ce = nil
      let pd = MTLRenderPassDescriptor()
      for (i, t) in outputs.enumerated() {
        pd.colorAttachments[i].texture = t
        pd.colorAttachments[i].loadAction = .clear
        pd.colorAttachments[i].storeAction = .store
      }
      re = cb.makeRenderCommandEncoder(descriptor: pd)!
      re!.setRenderPipelineState(s.render!)
    }
    var ended = false
    defer {
      if !ended {
        ce?.endEncoding()
        re?.endEncoding()
      }
    }
    var retained: [MTLBuffer] = []
    for arg in s.args where arg.isActive {
      switch arg.type {
      case .buffer:
        let b: MTLBuffer
        if let supplied = buffers[arg.name] ?? buffers[s.types[arg.name] ?? ""] {
          b = supplied
        } else if arg.access == .readOnly, let type = arg.bufferStructType,
          !type.members.contains(where: { $0.dataType == .array && !$0.name.contains("_pad") })
        {
          b = try uniform(arg, values)
        } else {
          throw GPUFailure("Missing buffer \(name):\(arg.name)")
        }
        retained.append(b)
        if compute {
          ce!.setBuffer(b, offset: 0, index: arg.index)
        } else {
          re!.setFragmentBuffer(b, offset: 0, index: arg.index)
        }
      case .texture:
        guard let t = textures[arg.name] else {
          throw GPUFailure("Missing texture \(name):\(arg.name)")
        }
        if compute {
          ce!.setTexture(t, index: arg.index)
        } else {
          re!.setFragmentTexture(t, index: arg.index)
        }
      case .sampler:
        let chosen = samplers[arg.name] ?? sampler
        if compute {
          ce!.setSamplerState(chosen, index: arg.index)
        } else {
          re!.setFragmentSamplerState(chosen, index: arg.index)
        }
      case .threadgroupMemory: throw GPUFailure("Unexpected threadgroup memory")
      default: break
      }
    }
    if compute {
      guard let grid else { throw GPUFailure("Missing grid") }
      ce!.dispatchThreadgroups(
        MTLSize(
          width: (grid.width + group.width - 1) / group.width,
          height: (grid.height + group.height - 1) / group.height,
          depth: (grid.depth + group.depth - 1) / group.depth), threadsPerThreadgroup: group)
      ce!.endEncoding()
    } else {
      re!.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
      re!.endEncoding()
    }
    ended = true
    try finish(cb)
    withExtendedLifetime(retained) {}
  }
}
