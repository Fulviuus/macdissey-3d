import AppKit
import CoreVideo
import OdysseyCamera
import OdysseyCore
import OdysseyGL
import OpenGL.GL3
import QuartzCore

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
  private var frameLink: CADisplayLink?
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
      throw WeaverRenderFailure.pixelFormat
    }
    super.init(frame: CGRect(origin: .zero, size: size), pixelFormat: format)
    wantsBestResolutionOpenGLSurface = true
    guard let context = openGLContext else { throw WeaverRenderFailure.context }
    context.makeCurrentContext()
    var interval: GLint = 1
    context.setValues(&interval, for: .swapInterval)
    guard let resources = Bundle.main.resourceURL else { throw WeaverRenderFailure.resources }
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
    frameLink?.invalidate()
    frameLink = DisplayFrameClock.start(for: self) { [weak self] in self?.needsDisplay = true }
  }
  func end() {
    frameLink?.invalidate()
    frameLink = nil
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
        failure?(WeaverRenderFailure.sourceUpload(status))
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
      let status = odyssey_gl_draw(renderer, vertices, fresh ? 1 : 0)
      guard status == 0 else {
        throw WeaverRenderFailure.draw(status)
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
enum WeaverRenderFailure: LocalizedError {
  case pixelFormat, context, resources, view
  case sourceUpload(Int32)
  case draw(Int32)

  var errorDescription: String? {
    switch self {
    case .pixelFormat:
      return "macOS could not create the OpenGL 4.1 pixel format required for 3D output."
    case .context:
      return "macOS could not create the OpenGL drawing context for 3D output."
    case .resources:
      return "The app's 3D renderer resources are unavailable. Reinstall macdissey 3d."
    case .view:
      return "macOS could not create the 3D output view."
    case .sourceUpload(let status):
      return "The 3D renderer could not upload the captured image (status \(status))."
    case .draw(let status):
      return "The 3D renderer could not draw the output image (status \(status))."
    }
  }
}
