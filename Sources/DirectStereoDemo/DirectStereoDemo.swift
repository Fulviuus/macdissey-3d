import Foundation
import MacdisseyClient
import Metal

private struct DemoUniforms {
  var eye: SIMD4<Float>
  var screenAndTime: SIMD4<Float>
}

private enum DemoPattern: String, CaseIterable {
  case stereo, grid, left, right
}

private enum DemoScene: String {
  case gallery, cubes
}

@main enum DirectStereoDemo {
  static func main() async {
    do { try await run() } catch {
      fputs("Direct stereo demo: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }
  static func run() async throws {
    let args = CommandLine.arguments
    func option(_ name: String) -> String? {
      guard let i = args.firstIndex(of: name), args.indices.contains(i + 1) else { return nil }
      return args[i + 1]
    }
    if args.contains("--help") {
      print("DirectStereoDemo [--seconds 10] [--width 1920] [--height 2160] [--service NAME]")
      print("  [--pattern stereo|grid|left|right] [--paused] [--swap-eyes]")
      print("  [--scene gallery|cubes] (default: gallery)")
      print("  [--viewpoint smooth|raw|fixed] (default: smooth)")
      print("  [--report PATH] (aggregate tracking/timing diagnostics as JSON)")
      print("  [--trace] (include a bounded relative-motion trace in --report)")
      print("  [--samples 1|2|4] (default: 4, device support permitting)")
      print("grid: identical screen-plane reference; left/right: isolate one eye, other eye black.")
      print(
        "Connects to macdissey and activates fullscreen 3D. Escape in macdissey stops playback.")
      return
    }
    guard let pattern = DemoPattern(rawValue: option("--pattern") ?? "stereo") else {
      throw DirectStereoError.unavailable("Unknown pattern. Use stereo, grid, left or right.")
    }
    guard let scene = DemoScene(rawValue: option("--scene") ?? "gallery") else {
      throw DirectStereoError.unavailable("Unknown scene. Use gallery or cubes.")
    }
    guard let viewpointMode = DemoViewpointMode(rawValue: option("--viewpoint") ?? "smooth") else {
      throw DirectStereoError.unavailable("Unknown viewpoint. Use smooth, raw or fixed.")
    }
    let reportPath = option("--report")
    if args.contains("--report") && reportPath == nil {
      throw DirectStereoError.unavailable("Provide a JSON output path after --report.")
    }
    if args.contains("--trace") && reportPath == nil {
      throw DirectStereoError.unavailable("--trace requires --report PATH.")
    }
    guard let samples = Int(option("--samples") ?? "4"), [1, 2, 4].contains(samples) else {
      throw DirectStereoError.unavailable("Choose 1, 2 or 4 raster samples.")
    }
    let seconds = Double(option("--seconds") ?? "10") ?? 10
    guard seconds.isFinite, seconds > 0, seconds <= 600,
      let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue()
    else { throw DirectStereoError.unavailable("Metal is unavailable or the duration is invalid.") }
    let session = try await StereoSession.connect(
      name: "Direct Stereo Demo", eyeWidth: Int(option("--width") ?? "1920") ?? 1920,
      eyeHeight: Int(option("--height") ?? "2160") ?? 2160, serviceName: option("--service"))
    do {
      let diagnostics = try await render(
        device: device, queue: queue, session: session, seconds: seconds, pattern: pattern,
        scene: scene, viewpointMode: viewpointMode, paused: args.contains("--paused"),
        swapEyes: args.contains("--swap-eyes"), collectDiagnostics: reportPath != nil,
        trace: args.contains("--trace"), samples: samples)
      await session.close()
      if let diagnostics, let reportPath {
        try diagnostics.write(
          to: reportPath, eyeWidth: session.eyeWidth, eyeHeight: session.eyeHeight,
          displayRefreshRate: session.refreshRate)
        print("Diagnostics saved: \(reportPath)")
      }
    } catch {
      await session.close()
      throw error
    }
  }

  private static func render(
    device: MTLDevice, queue: MTLCommandQueue, session: StereoSession, seconds: Double,
    pattern: DemoPattern, scene: DemoScene, viewpointMode: DemoViewpointMode, paused: Bool,
    swapEyes: Bool, collectDiagnostics: Bool, trace: Bool, samples: Int
  ) async throws -> DemoDiagnostics? {
    let library = try await device.makeLibrary(
      source: """
        #include <metal_stdlib>
        using namespace metal;
        struct U { float4 eye; float4 screenAndTime; };
        struct V { float4 position [[position]]; float shade; };
        vertex V scene(uint id [[vertex_id]], uint instance [[instance_id]], constant U& u [[buffer(0)]]) {
          const float3 corners[] = {
            {-1,-1,-1},{1,-1,-1},{1,1,-1},{-1,1,-1},
            {-1,-1,1},{1,-1,1},{1,1,1},{-1,1,1}
          };
          const uint indices[] = {0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,
                                  2,3,7,2,7,6,0,4,7,0,7,3,1,2,6,1,6,5};
          float t = u.screenAndTime.z + float(instance)*0.8;
          float c=cos(t), s=sin(t);
          float3 p=corners[indices[id]]*(0.020 + 0.004*float(instance));
          p=float3(c*p.x+s*p.z,p.y,-s*p.x+c*p.z);
          p.y+=0.025*sin(t*0.8);
          p.x+=(float(instance)-1.0)*0.16;
          // Keep the first optical test near the screen plane. The previous
          // scene put centres 10/23/36 cm behind it, producing large disparities.
          p.z+=(1.0-float(instance))*0.015;
          float w=u.eye.z-p.z;
          float2 projected=(p.xy*u.eye.z-u.eye.xy*p.z)*2.0/u.screenAndTime.xy;
          // Off-axis projection through the physical screen plane (world z=0).
          V v; v.position=float4(projected, w*10.0/9.99-0.1/9.99,w);
          // Device-encoded neutral greys keep this diagnostic independent of gamut.
          v.shade=0.22+0.13*float((id/6)%6);
          return v;
        }
        fragment float4 shade(V v [[stage_in]]) { return float4(float3(v.shade),1); }
        vertex float4 reference(uint id [[vertex_id]]) {
          float2 uv=float2((id<<1)&2,id&2);
          return float4(uv*2.0-1.0,0,1);
        }
        fragment float4 referenceShade(float4 p [[position]], constant U& u [[buffer(0)]]) {
          float2 uv=p.xy/u.screenAndTime.xy;
          uint mode=uint(u.eye.w);
          if (mode==1) {
            float2 edge=min(fract(uv*8.0),1.0-fract(uv*8.0));
            float line=float(min(edge.x,edge.y)<0.012);
            float cross=float(abs(uv.x-0.5)<0.002 || abs(uv.y-0.5)<0.002);
            return float4(float3(0.12+0.38*max(line,cross)),1);
          }
          // L/R glyphs at the same screen-plane location, with the other eye
          // completely black, isolate optical leakage from stereo disparity.
          bool vertical=uv.x>0.42 && uv.x<0.46 && uv.y>0.35 && uv.y<0.65;
          bool bottom=uv.x>0.42 && uv.x<0.58 && uv.y>0.61 && uv.y<0.65;
          bool top=uv.x>0.42 && uv.x<0.58 && uv.y>0.35 && uv.y<0.39;
          bool middle=uv.x>0.42 && uv.x<0.58 && uv.y>0.47 && uv.y<0.51;
          bool side=uv.x>0.54 && uv.x<0.58 && uv.y>0.35 && uv.y<0.51;
          bool leg=uv.y>0.49 && uv.y<0.65 && abs(uv.x-(0.46+(uv.y-0.49)*0.65))<0.02;
          bool lit=mode==2 ? (vertical||bottom) : mode==3 && (vertical||top||middle||side||leg);
          return float4(float3(lit ? 0.65 : 0.0),1);
        }
        """ + GalleryScene.shader, options: nil)
    let renderTargets = try DemoRenderTargets(
      device: device, width: session.eyeWidth, height: session.eyeHeight,
      preferredSampleCount: samples)
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.rasterSampleCount = renderTargets.sampleCount
    descriptor.vertexFunction = library.makeFunction(name: "scene")
    descriptor.fragmentFunction = library.makeFunction(name: "shade")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    descriptor.depthAttachmentPixelFormat = .depth32Float
    let pipeline = try await device.makeRenderPipelineState(descriptor: descriptor)
    descriptor.vertexFunction = library.makeFunction(name: "reference")
    descriptor.fragmentFunction = library.makeFunction(name: "referenceShade")
    let referencePipeline = try await device.makeRenderPipelineState(descriptor: descriptor)
    descriptor.vertexFunction = library.makeFunction(name: "gallery")
    descriptor.fragmentFunction = library.makeFunction(name: "galleryShade")
    let galleryPipeline = try await device.makeRenderPipelineState(descriptor: descriptor)
    let vertices = scene == .gallery && pattern == .stereo ? GalleryScene.vertices() : []
    let galleryBuffer = vertices.withUnsafeBytes { bytes -> MTLBuffer? in
      guard let base = bytes.baseAddress, !bytes.isEmpty else { return nil }
      return device.makeBuffer(bytes: base, length: bytes.count, options: .storageModeShared)
    }
    if !vertices.isEmpty && galleryBuffer == nil {
      throw DirectStereoError.unavailable("Cannot allocate the gallery geometry.")
    }
    let depthState = MTLDepthStencilDescriptor()
    depthState.depthCompareFunction = .less
    depthState.isDepthWriteEnabled = true
    let depth = device.makeDepthStencilState(descriptor: depthState)!
    let left = try StereoEyeTexture(
      device: device, width: session.eyeWidth, height: session.eyeHeight)
    let right = try StereoEyeTexture(
      device: device, width: session.eyeWidth, height: session.eyeHeight)
    let size = session.displaySizeMillimetres / 1000
    guard size.x > 0, size.y > 0 else {
      throw DirectStereoError.unavailable("Invalid physical display dimensions.")
    }
    let start = ProcessInfo.processInfo.systemUptime
    print(
      "Direct stereo test: \(pattern.rawValue)\(paused ? " · paused" : "")\(swapEyes ? " · eyes swapped" : "")"
    )
    if pattern == .stereo {
      print(
        "Scene: \(scene.rawValue) · \(viewpointMode.rawValue) viewpoint · \(renderTargets.sampleCount)× MSAA"
      )
    }
    var count = 0
    var viewpoint = DemoViewpointFilter()
    var diagnostics: DemoDiagnostics? = collectDiagnostics ? DemoDiagnostics(trace: trace) : nil
    diagnostics?.rasterSamples = renderTargets.sampleCount
    diagnostics?.viewpointMode = viewpointMode.rawValue
    while ProcessInfo.processInfo.systemUptime - start < seconds {
      try Task.checkCancellation()
      let pose = session.latestTracking
      let now = ProcessInfo.processInfo.systemUptime
      let trackingValid = pose.valid
      diagnostics?.record(
        midpointCentimetres: pose.midpointCentimetres,
        ipdMillimetres: pose.interpupillaryDistanceMillimetres, timestamp: pose.timestamp,
        valid: trackingValid, now: now)
      let camera = viewpoint.update(
        midpoint: trackingValid ? pose.midpointCentimetres / 100 : nil,
        ipd: pose.interpupillaryDistanceMillimetres / 1000, sampleTime: pose.timestamp,
        now: now, mode: viewpointMode)
      if trackingValid { diagnostics?.recordScene(midpointMetres: camera.midpoint) }
      // Both eyes must depict the exact same instant, including paused tests.
      let sceneTime = paused ? Float(0) : Float(now - start)
      guard let commands = queue.makeCommandBuffer() else {
        throw DirectStereoError.unavailable("Cannot encode the demo frame.")
      }
      for (eye, direction) in [(left, Float(-0.5)), (right, Float(0.5))] {
        var uniforms = DemoUniforms(
          eye: SIMD4(
            camera.midpoint.x + direction * camera.ipd, camera.midpoint.y, camera.midpoint.z, 1),
          screenAndTime: SIMD4(size.x, size.y, sceneTime, 0))
        if pattern != .stereo {
          let mode: Float
          switch pattern {
          case .grid: mode = 1
          case .left: mode = direction < 0 ? 2 : 0
          case .right: mode = direction > 0 ? 3 : 0
          case .stereo: mode = 0
          }
          uniforms.eye.w = mode
          uniforms.screenAndTime = SIMD4(Float(session.eyeWidth), Float(session.eyeHeight), 0, 0)
        }
        let pass = renderTargets.pass(resolvingTo: eye.texture)
        guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else {
          throw DirectStereoError.unavailable("Cannot render the stereo eye.")
        }
        let isGallery = pattern == .stereo && scene == .gallery
        encoder.setRenderPipelineState(
          pattern != .stereo ? referencePipeline : isGallery ? galleryPipeline : pipeline)
        encoder.setDepthStencilState(depth)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<DemoUniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<DemoUniforms>.stride, index: 0)
        if isGallery {
          encoder.setVertexBuffer(galleryBuffer, offset: 0, index: 1)
          encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        } else {
          encoder.drawPrimitives(
            type: .triangle, vertexStart: 0, vertexCount: pattern == .stereo ? 36 : 3,
            instanceCount: pattern == .stereo ? 3 : 1)
        }
        encoder.endEncoding()
      }
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        commands.addCompletedHandler { _ in continuation.resume() }
        commands.commit()
      }
      guard commands.status == .completed else {
        throw commands.error ?? DirectStereoError.unavailable("The demo GPU frame failed.")
      }
      if commands.gpuStartTime > 0 && commands.gpuEndTime > commands.gpuStartTime {
        diagnostics?.gpu.add((commands.gpuEndTime - commands.gpuStartTime) * 1000)
      }
      let presentationStart = ProcessInfo.processInfo.systemUptime
      _ = try await session.present(
        left: swapEyes ? right.surface : left.surface,
        right: swapEyes ? left.surface : right.surface)
      diagnostics?.presentationWait.add(
        (ProcessInfo.processInfo.systemUptime - presentationStart) * 1000)
      count += 1
    }
    let elapsed = ProcessInfo.processInfo.systemUptime - start
    print(
      String(
        format: "Direct stereo: %d paired frames in %.2fs (%.1f fps)", count, elapsed,
        Double(count) / elapsed))
    return diagnostics
  }
}
