import Foundation
import Metal

@main enum DirectStereoCoverageChecks {
  static func main() async throws {
    let device = MTLCreateSystemDefaultDevice()!
    let queue = device.makeCommandQueue()!
    let library = try await device.makeLibrary(
      source: """
        #include <metal_stdlib>
        using namespace metal;
        vertex float4 edge(uint id [[vertex_id]],constant float& x [[buffer(0)]]) {
          const float2 corners[]={{-1,-1},{1,-1},{1,1},{-1,1}};
          const uint indices[]={0,1,2,0,2,3};
          float2 p=corners[indices[id]];
          p.x=p.x>0 ? x : -1;
          return float4(p,0.5,1);
        }
        fragment float4 fill() { return float4(0.8,0.8,0.8,1); }
        """, options: nil)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm, width: 64, height: 32, mipmapped: false)
    descriptor.storageMode = .shared
    descriptor.usage = .renderTarget
    let output = device.makeTexture(descriptor: descriptor)!
    var errors: [Double] = []
    for requested in [1, 4] {
      let targets = try DemoRenderTargets(
        device: device, width: 64, height: 32, preferredSampleCount: requested)
      if requested == 4 && targets.sampleCount == 1 {
        print("SKIP raster coverage: multisampling unavailable")
        return
      }
      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.vertexFunction = library.makeFunction(name: "edge")
      pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fill")
      pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
      pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
      pipelineDescriptor.rasterSampleCount = targets.sampleCount
      let pipeline = try await device.makeRenderPipelineState(descriptor: pipelineDescriptor)
      var error = 0.0
      for step in 0..<16 {
        let boundary = 32 + Float(step) / 16
        var edge = boundary / 32 - 1
        let command = queue.makeCommandBuffer()!
        let encoder = command.makeRenderCommandEncoder(
          descriptor: targets.pass(resolvingTo: output))!
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBytes(&edge, length: MemoryLayout<Float>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
          command.addCompletedHandler { _ in continuation.resume() }
          command.commit()
        }
        precondition(command.status == .completed)
        var row = [UInt8](repeating: 0, count: 64 * 4)
        output.getBytes(
          &row, bytesPerRow: 64 * 4, from: MTLRegionMake2D(0, 16, 64, 1), mipmapLevel: 0)
        let covered = stride(from: 0, to: row.count, by: 4).reduce(0.0) {
          $0 + (Double(row[$1]) - 10) / 194
        }
        error += pow(covered - Double(boundary), 2)
      }
      errors.append(sqrt(error / 16))
      print(
        String(
          format: "Raster coverage: %d samples, %.3f source pixels RMS edge error",
          targets.sampleCount, errors.last!))
    }
    precondition(
      errors[1] < errors[0] * 0.65, "Subpixel camera motion must not toggle whole source pixels")
    print(
      "PASS fractional edge coverage, reused stereo targets and multisample resolve; no physical display activation"
    )
  }
}
