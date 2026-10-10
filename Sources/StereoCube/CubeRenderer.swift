import AppKit
import MetalKit

struct CubeParameters {
  var width: UInt32 = 0, height: UInt32 = 0, format: UInt32 = 1, phase: UInt32 = 0
  var time: Float = 0, separation: Float = 0.07
  var pair: UInt32 = 0, isolation: UInt32 = 0, markers: UInt32 = 1, monochrome: UInt32 = 0
  var screenGrid: UInt32 = 0, pad1: UInt32 = 0
}

struct CubeError: LocalizedError {
  let errorDescription: String?
  init(_ message: String) { errorDescription = message }
}

final class CubeGPU {
  let device: MTLDevice
  private let queue: MTLCommandQueue
  private let pipeline: MTLRenderPipelineState
  init() throws {
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
      throw CubeError("A Metal-capable Mac is required.")
    }
    self.device = device
    self.queue = queue
    guard let url = Bundle.main.url(forResource: "Cube", withExtension: "metal") else {
      throw CubeError("The cube shader is missing. Build the app with scripts/build-cube-app.sh.")
    }
    let library = try device.makeLibrary(source: String(contentsOf: url), options: nil)
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "vertexMain")
    descriptor.fragmentFunction = library.makeFunction(name: "fragmentMain")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
    pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
  }
  func render(_ texture: MTLTexture, parameters: CubeParameters, drawable: CAMetalDrawable? = nil)
    throws
  {
    guard let command = queue.makeCommandBuffer() else {
      throw CubeError("Metal command buffer unavailable.")
    }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
      throw CubeError("Metal encoder unavailable.")
    }
    var params = parameters
    params.width = UInt32(texture.width)
    params.height = UInt32(texture.height)
    encoder.setRenderPipelineState(pipeline)
    encoder.setFragmentBytes(&params, length: MemoryLayout<CubeParameters>.stride, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
    if let drawable { command.present(drawable) }
    command.commit()
    // Bound queued frames and surface lifetime; this small scene has no CPU ray tracing.
    command.waitUntilCompleted()
    if let error = command.error { throw error }
  }
  func image(width: Int, height: Int, parameters: CubeParameters) throws -> [UInt8] {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
    descriptor.storageMode = .shared
    descriptor.usage = [.renderTarget]
    guard let texture = device.makeTexture(descriptor: descriptor) else {
      throw CubeError("Test texture unavailable.")
    }
    try render(texture, parameters: parameters)
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    texture.getBytes(
      &bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
    return bytes
  }
}

@MainActor final class CubeRenderer: NSObject, MTKViewDelegate {
  let gpu: CubeGPU
  var parameters = CubeParameters()
  var paused = false
  var failure: ((Error) -> Void)?
  var sizeChanged: ((CGSize) -> Void)?
  private var lastTime = CACurrentMediaTime()
  private var sceneTime: Float = 0
  private var frame: UInt32 = 0
  init(gpu: CubeGPU) { self.gpu = gpu }
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { sizeChanged?(size) }
  func draw(in view: MTKView) {
    let now = CACurrentMediaTime()
    if !paused { sceneTime += Float(min(0.1, now - lastTime)) }
    lastTime = now
    guard let drawable = view.currentDrawable else { return }
    parameters.time = sceneTime
    parameters.phase = frame & 1
    do {
      try gpu.render(drawable.texture, parameters: parameters, drawable: drawable)
      frame &+= 1
    } catch {
      view.isPaused = true
      failure?(error)
    }
  }
  func reset() {
    sceneTime = 0
    frame = 0
  }
}
