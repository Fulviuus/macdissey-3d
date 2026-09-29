import AppKit
import CoreVideo
import OdysseyGL
import OpenGL.GL3

let format = NSOpenGLPixelFormat(attributes: [
  UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion4_1Core),
  UInt32(NSOpenGLPFAAccelerated), UInt32(NSOpenGLPFAColorSize), 24, 0,
])!
let context = NSOpenGLContext(format: format, share: nil)!
context.makeCurrentContext()
let vertex = """
  #version 330 core
  layout(location=0) in vec4 position;
  layout(location=1) in vec2 coordinate;
  out vec2 uv;
  void main() { gl_Position=position; uv=coordinate; }
  """
let fragment = """
  #version 330 core
  uniform sampler2D a;
  in vec2 uv;
  out vec4 color;
  void main() { color=texture(a,uv); }
  """
let correction = [UInt8](repeating: 0, count: 480 * 270)
var error = [CChar](repeating: 0, count: 4096)
guard
  let renderer = odyssey_gl_create(vertex, fragment, correction, correction, &error, error.count)
else { fatalError(String(cString: error)) }
defer { odyssey_gl_destroy(renderer) }
var target: GLuint = 0
var storage: GLuint = 0
glGenFramebuffers(1, &target)
glGenRenderbuffers(1, &storage)
glBindRenderbuffer(GLenum(GL_RENDERBUFFER), storage)
glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_RGBA8), 3840, 2160)
glBindFramebuffer(GLenum(GL_FRAMEBUFFER), target)
glFramebufferRenderbuffer(
  GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), storage)
precondition(glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) == GLenum(GL_FRAMEBUFFER_COMPLETE))
defer {
  glDeleteFramebuffers(1, &target)
  glDeleteRenderbuffers(1, &storage)
}
var vertices = [Float]()
for p in [(-1.0, 1.0), (-1.0, -3.0), (3.0, 1.0)] {
  vertices += [Float(p.0), Float(p.1), 0, 1] + [Float](repeating: 0, count: 12)
}
func read() -> [UInt8] {
  precondition(odyssey_gl_draw(renderer, vertices, 0) == 0)
  var pixels = [UInt8](repeating: 0, count: 3840 * 2160 * 4)
  glReadPixels(0, 0, 3840, 2160, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), &pixels)
  precondition(glGetError() == GLenum(GL_NO_ERROR))
  return pixels
}
for (width, height, top, crop) in [(16, 8, 0, 8), (16, 8, 2, 4), (7680, 2160, 0, 2160)] {
  var value: CVPixelBuffer?
  precondition(
    CVPixelBufferCreate(
      nil, width, height, kCVPixelFormatType_32BGRA,
      [
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        kCVPixelBufferOpenGLCompatibilityKey as String: true,
      ] as CFDictionary, &value) == kCVReturnSuccess)
  let buffer = value!
  CVPixelBufferLockBaseAddress(buffer, [])
  let pixels = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
  let stride = CVPixelBufferGetBytesPerRow(buffer)
  for y in 0..<height {
    for x in 0..<width {
      let index = y * stride + x * 4
      pixels[index] = UInt8(x % 251)
      pixels[index + 1] = UInt8(y % 251)
      pixels[index + 2] = UInt8((x ^ y) % 249)
      pixels[index + 3] = 255
    }
  }
  CVPixelBufferUnlockBaseAddress(buffer, [])
  let surface = CVPixelBufferGetIOSurface(buffer)!.takeUnretainedValue()
  func upload(_ gpu: Bool) {
    if gpu {
      precondition(odyssey_gl_source_surface(renderer, surface, Int32(top), Int32(crop)) == 0)
    } else {
      CVPixelBufferLockBaseAddress(buffer, .readOnly)
      precondition(
        odyssey_gl_source(
          renderer, pixels, Int32(width), Int32(height), stride,
          Int32(top), Int32(crop)) == 0)
      CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
    }
  }
  upload(false)
  let expected = read()
  upload(true)
  let actual = read()
  precondition(expected == actual, "IOSurface path changed pixel order, crop, channels or colours")
  print("PASS: CPU/GPU full framebuffer equality, source \(width)×\(height), crop \(top)/\(crop)")
  if width == 7680 {
    for gpu in [false, true] {
      let start = ProcessInfo.processInfo.systemUptime
      for _ in 0..<30 {
        upload(gpu)
        glFinish()
      }
      let ms = (ProcessInfo.processInfo.systemUptime - start) * 1000 / 30
      print(
        String(format: "8K upload+GPU completion: %@ %.2f ms/frame", gpu ? "IOSurface" : "CPU", ms))
    }
  }
}
