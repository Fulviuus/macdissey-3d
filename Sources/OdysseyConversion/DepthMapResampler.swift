import Metal

// Model output is top-down; the recovered stereo stages use bottom-up textures.
// Sample normalized coordinates so rectangular predictions cover the complete
// square processing texture, including when its height exceeds the source.
final class DepthMapResampler {
  private let pipeline: MTLRenderPipelineState

  init(gpu: ConversionGPU) throws {
    let library = try gpu.device.makeLibrary(
      source: """
        #include <metal_stdlib>
        using namespace metal;
        struct In { float2 uv [[user(locn0)]]; };
        fragment float resampleDepth(In in [[stage_in]], texture2d<float> src [[texture(0)]], sampler s [[sampler(0)]]) {
          return src.sample(s, float2(in.uv.x, 1.0-in.uv.y), level(0)).r;
        }
        """, options: gpu.options)
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = gpu.vertex
    descriptor.fragmentFunction = library.makeFunction(name: "resampleDepth")
    descriptor.colorAttachments[0].pixelFormat = .r32Float
    pipeline = try gpu.device.makeRenderPipelineState(descriptor: descriptor)
  }

  func run(gpu: ConversionGPU, source: MTLTexture, output: MTLTexture) throws {
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = output
    pass.colorAttachments[0].loadAction = .dontCare
    pass.colorAttachments[0].storeAction = .store
    let command = try gpu.commandBuffer()
    guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
      throw GPUFailure("Cannot resize the depth map.")
    }
    encoder.setRenderPipelineState(pipeline)
    encoder.setFragmentTexture(source, index: 0)
    encoder.setFragmentSamplerState(gpu.sampler, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
    try gpu.finish(command)
  }
}
