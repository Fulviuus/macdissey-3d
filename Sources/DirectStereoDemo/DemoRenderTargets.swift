import Foundation
import Metal

/// Apple GPUs keep multisample storage on the tile; only the resolved image
/// needs to be stored in the producer's shared surface. Reuse between eyes.
struct DemoRenderTargets {
  let sampleCount: Int
  let depth: MTLTexture
  let multisampleColor: MTLTexture?

  init(device: MTLDevice, width: Int, height: Int, preferredSampleCount: Int = 4) throws {
    let count =
      [4, 2, 1].first {
        $0 <= preferredSampleCount && device.supportsTextureSampleCount($0)
      } ?? 1
    sampleCount = count
    func texture(_ format: MTLPixelFormat) -> MTLTexture? {
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: format, width: width, height: height, mipmapped: false)
      descriptor.textureType = count > 1 ? .type2DMultisample : .type2D
      descriptor.sampleCount = count
      descriptor.usage = .renderTarget
      if device.supportsFamily(.apple1) {
        descriptor.storageMode = .memoryless
        if let texture = device.makeTexture(descriptor: descriptor) { return texture }
      }
      descriptor.storageMode = .private
      return device.makeTexture(descriptor: descriptor)
    }
    guard let depth = texture(.depth32Float) else {
      throw NSError(
        domain: "DirectStereoDemo", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Cannot allocate the stereo depth target."])
    }
    self.depth = depth
    if count > 1 {
      guard let color = texture(.bgra8Unorm) else {
        throw NSError(
          domain: "DirectStereoDemo", code: 2,
          userInfo: [NSLocalizedDescriptionKey: "Cannot allocate the stereo antialiasing target."])
      }
      multisampleColor = color
    } else {
      multisampleColor = nil
    }
  }

  func pass(resolvingTo output: MTLTexture) -> MTLRenderPassDescriptor {
    let pass = MTLRenderPassDescriptor()
    let color = pass.colorAttachments[0]!
    color.texture = multisampleColor ?? output
    color.resolveTexture = multisampleColor == nil ? nil : output
    color.loadAction = .clear
    color.storeAction = multisampleColor == nil ? .store : .multisampleResolve
    color.clearColor = MTLClearColorMake(0.04, 0.04, 0.04, 1)
    pass.depthAttachment.texture = depth
    pass.depthAttachment.loadAction = .clear
    pass.depthAttachment.storeAction = .dontCare
    pass.depthAttachment.clearDepth = 1
    return pass
  }
}
