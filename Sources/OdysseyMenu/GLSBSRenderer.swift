import AppKit
import CoreVideo
import OdysseyCamera
import OdysseyCore
import OdysseyGL
import OpenGL.GL3

enum SBSLayout: Int, CaseIterable {
  case fullWidth, halfWidth
  var title: String {
    self == .fullWidth ? "Remove black bars" : "Stretch to fill"
  }
}

/// Original GLSL rendered at physical panel resolution. All GL work is on
/// the main thread; camera and screen callbacks only publish immutable data.
final class GLSBSRenderer: NSOpenGLView {
  private var renderer: OpaquePointer?
  private let profile: FactoryOpticalProfile
  private let lock = NSLock()
  private var source: CVPixelBuffer?
  private var sourceVersion: UInt64 = 0, uploadedVersion: UInt64 = 0
  private var pose: StereoTrackingPose?
  private var timer: Timer?
  private(set) var renderedFrames = 0
  private var gpuUploads = 0, cpuUploads = 0
  var layout: SBSLayout = .fullWidth { didSet { uploadedVersion = 0 } }
  var presented: ((Bool) -> Void)?
  var failure: ((Error) -> Void)?

  init?(size: CGSize, profile: FactoryProfile) throws {
    self.profile = profile.optics
    let attributes: [NSOpenGLPixelFormatAttribute] = [
      UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion4_1Core),
      UInt32(NSOpenGLPFAAccelerated), UInt32(NSOpenGLPFADoubleBuffer), UInt32(NSOpenGLPFAColorSize),
      24, UInt32(NSOpenGLPFAAlphaSize), 8, 0,
    ]
    guard let format = NSOpenGLPixelFormat(attributes: attributes) else {
      throw WeaverRenderFailure.unavailable
    }
    super.init(frame: CGRect(origin: .zero, size: size), pixelFormat: format)
    wantsBestResolutionOpenGLSurface = true
    guard let context = openGLContext else { throw WeaverRenderFailure.unavailable }
    context.makeCurrentContext()
    var interval: GLint = 1
    context.setValues(&interval, for: .swapInterval)
    guard let resources = Bundle.main.resourceURL else { throw WeaverRenderFailure.unavailable }
    let vertex = try String(contentsOf: resources.appendingPathComponent("Weaver/vertex.glsl"))
    let fragment = try String(contentsOf: resources.appendingPathComponent("Weaver/fragment.glsl"))
    let a = try FactoryCorrectionMap(
      png: Data(contentsOf: profile.directory.appendingPathComponent("3DStackCorrection_A.png")))
    let b = try FactoryCorrectionMap(
      png: Data(contentsOf: profile.directory.appendingPathComponent("3DStackCorrection_B.png")))
    var error = [CChar](repeating: 0, count: 4096)
    renderer = odyssey_gl_create(vertex, fragment, a.pixels, b.pixels, &error, error.count)
    guard renderer != nil else { throw AppError.unavailable(String(cString: error)) }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
  func begin() {
    let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.needsDisplay = true }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }
  func end() {
    timer?.invalidate()
    timer = nil
    print("Weaver uploads: \(gpuUploads) GPU surfaces, \(cpuUploads) CPU copies")
    openGLContext?.makeCurrentContext()
    if let renderer {
      odyssey_gl_destroy(renderer)
      self.renderer = nil
    }
    lock.lock()
    source = nil
    pose = nil
    lock.unlock()
  }
  func submit(_ buffer: CVPixelBuffer) {
    lock.lock()
    source = buffer
    sourceVersion &+= 1
    lock.unlock()
  }
  func track(_ value: StereoTrackingPose?) {
    lock.lock()
    pose = value
    lock.unlock()
  }
  override func reshape() {
    super.reshape()
    openGLContext?.update()
  }
  override func draw(_ dirtyRect: NSRect) {
    guard let renderer, let context = openGLContext else { return }
    lock.lock()
    let buffer = source
    let version = sourceVersion
    let position = pose
    lock.unlock()
    guard let buffer else { return }
    context.makeCurrentContext()
    let backing = convertToBacking(bounds)
    guard Int(backing.width) == 3840, Int(backing.height) == 2160 else {
      presented?(false)
      failure?(AppError.unavailable("3D output must use exactly 3840 × 2160 physical pixels."))
      return
    }
    if version != uploadedVersion {
      let width = CVPixelBufferGetWidth(buffer)
      let height = CVPixelBufferGetHeight(buffer)
      let top = layout == .fullWidth ? height / 4 : 0
      let crop = layout == .fullWidth ? height / 2 : height
      var status: Int32 = 1
      if let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue() {
        status = odyssey_gl_source_surface(renderer, surface, Int32(top), Int32(crop))
      }
      if status == 0 {
        gpuUploads += 1
      } else {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        status = odyssey_gl_source(
          renderer, CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self),
          Int32(width), Int32(height), CVPixelBufferGetBytesPerRow(buffer), Int32(top), Int32(crop))
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        cpuUploads += 1
      }
      guard status == 0 else {
        failure?(WeaverRenderFailure.unavailable)
        return
      }
      uploadedVersion = version
    }
    do {
      let fresh =
        position.map {
          StereoCamera.now() - $0.timestamp < 0.15
            && Self.insideViewingZone($0.displayMidpointCentimetres)
        } ?? false
      var vertices: [Float] = []
      for p in [SIMD2<Float>(-1, 1), SIMD2<Float>(-1, -3), SIMD2<Float>(3, 1)] {
        vertices += [p.x, p.y, 0, 1]
        if fresh, let position {
          vertices += try WeaverAttributes(
            profile: profile, eyeCentimetres: position.displayMidpointCentimetres, vertex: p
          ).values
        } else {
          // Finite unused attributes for the shader's explicit 2D
          // branch. These are not a synthetic tracking position.
          vertices += [Float](repeating: 0, count: 12)
        }
      }
      guard odyssey_gl_draw(renderer, vertices, fresh ? 1 : 0) == 0 else {
        throw WeaverRenderFailure.unavailable
      }
      context.flushBuffer()
      glFinish()
      renderedFrames += 1
      presented?(fresh)
    } catch {
      presented?(false)
      failure?(error)
    }
  }
  private static func insideViewingZone(_ p: SIMD3<Float>) -> Bool {
    guard p.x.isFinite, p.y.isFinite, p.z.isFinite, p.y >= -50, p.y <= 50, p.z >= 50, p.z <= 130
    else { return false }
    // ET ft_user.ini's symmetric factory viewing polygon, in centimetres.
    let halfWidth: Float = p.z <= 90 ? 20 + (p.z - 50) * (25 / 40) : 45 + (p.z - 90) * (3 / 40)
    return abs(p.x) <= halfWidth
  }
}
enum WeaverRenderFailure: Error { case unavailable }
