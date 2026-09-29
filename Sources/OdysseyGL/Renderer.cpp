#define GL_SILENCE_DEPRECATION
#include "OdysseyGL.h"
#include <OpenGL/CGLIOSurface.h>
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl3.h>
#include <cstdio>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <vector>
struct OdysseyGL {
  GLuint program = 0, vao = 0, buffers[2] = {0}, textures[4] = {0};
  int width = 0, height = 0;
  GLuint surfaceTexture = 0, copyFrames[2] = {0};
  std::vector<uint8_t> upload;
  ~OdysseyGL() {
    glDeleteFramebuffers(2, copyFrames);
    if (surfaceTexture)
      glDeleteTextures(1, &surfaceTexture);
    glDeleteTextures(4, textures);
    glDeleteBuffers(2, buffers);
    if (vao)
      glDeleteVertexArrays(1, &vao);
    if (program)
      glDeleteProgram(program);
  }
};
static GLuint compile(GLenum stage, const char *source) {
  GLuint shader = glCreateShader(stage);
  glShaderSource(shader, 1, &source, nullptr);
  glCompileShader(shader);
  GLint ok = 0;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
  if (!ok) {
    char log[4096];
    glGetShaderInfoLog(shader, sizeof(log), nullptr, log);
    glDeleteShader(shader);
    throw std::runtime_error(log);
  }
  return shader;
}
OdysseyGL *odyssey_gl_create(const char *vertex, const char *fragment, const uint8_t *a,
                             const uint8_t *b, char *error, size_t size) {
  if (!vertex || !fragment || !a || !b)
    return nullptr;
  try {
    std::unique_ptr<OdysseyGL> r(new OdysseyGL());
    r->program = glCreateProgram();
    GLuint vs = compile(GL_VERTEX_SHADER, vertex), fs = compile(GL_FRAGMENT_SHADER, fragment);
    glAttachShader(r->program, vs);
    glAttachShader(r->program, fs);
    glLinkProgram(r->program);
    glDeleteShader(vs);
    glDeleteShader(fs);
    GLint ok = 0;
    glGetProgramiv(r->program, GL_LINK_STATUS, &ok);
    if (!ok)
      throw std::runtime_error("Cannot link original weaving shader");
    glUseProgram(r->program);
    auto scalar = [&](const char *name, float v) {
      glUniform1f(glGetUniformLocation(r->program, name), v);
    };
    auto integer = [&](const char *name, int v) {
      glUniform1i(glGetUniformLocation(r->program, name), v);
    };
    scalar("r", .0128535f);
    scalar("m", .05f);
    scalar("s", 10);
    scalar("z", 1);
    scalar("d", 0);
    scalar("p", 0);
    integer("u", 1);
    integer("w", 0);
    integer("a", 0);
    integer("l", 1);
    integer("y", 2);
    integer("n", 3);
    glUniform2f(glGetUniformLocation(r->program, "O"), 1, 1);
    glUniform2f(glGetUniformLocation(r->program, "Q"), 0, 0);
    glUniform4f(glGetUniformLocation(r->program, "h"), 0, 1.f / 3.f, 2.f / 3.f, 1);
    glUniform4f(glGetUniformLocation(r->program, "F"), 0, 0, 0, 0);
    glUniform4f(glGetUniformLocation(r->program, "S"), 1, 1, 1, 0);
    glUniform4f(glGetUniformLocation(r->program, "D"), 1, 1, 1, 0);
    glGenTextures(4, r->textures);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    for (int i = 0; i < 4; i++) {
      glActiveTexture(GL_TEXTURE0 + i);
      glBindTexture(GL_TEXTURE_2D, r->textures[i]);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, i ? GL_NEAREST : GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, i ? GL_NEAREST : GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, i ? GL_REPEAT : GL_CLAMP_TO_EDGE);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, i ? GL_REPEAT : GL_CLAMP_TO_EDGE);
      if (i == 1 || i == 2)
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, 480, 270, 0, GL_RED, GL_UNSIGNED_BYTE,
                     i == 1 ? a : b);
      if (i == 3) {
        const float stamp[] = {0, 1.f / 3.f, 2.f / 3.f, 1, 0, 0, 0, 0};
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, 1, 2, 0, GL_RGBA, GL_FLOAT, stamp);
      }
    }
    glGenVertexArrays(1, &r->vao);
    glBindVertexArray(r->vao);
    glGenBuffers(2, r->buffers);
    const float uv[] = {0, 1, 0, -1, 2, 1};
    glBindBuffer(GL_ARRAY_BUFFER, r->buffers[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(uv), uv, GL_STATIC_DRAW);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 8, nullptr);
    glEnableVertexAttribArray(1);
    glBindBuffer(GL_ARRAY_BUFFER, r->buffers[0]);
    const int components[] = {4, 0, 4, 4, 2, 2}, offsets[] = {0, 0, 16, 32, 48, 56};
    for (int i = 0; i < 6; i++)
      if (i != 1) {
        glVertexAttribPointer(i, components[i], GL_FLOAT, GL_FALSE, 64, (void *)(size_t)offsets[i]);
        glEnableVertexAttribArray(i);
      }
    glVertexAttrib2f(6, 0, 0);
    if (glGetError() != GL_NO_ERROR)
      throw std::runtime_error("Cannot initialize OpenGL weaver");
    return r.release();
  } catch (const std::exception &e) {
    if (error && size)
      snprintf(error, size, "%s", e.what());
    return nullptr;
  }
}
void odyssey_gl_destroy(OdysseyGL *r) { delete r; }
int odyssey_gl_source(OdysseyGL *r, const uint8_t *pixels, int width, int height, size_t stride,
                      int top, int crop) {
  if (!r || !pixels || width < 2 || width > 8192 || width % 2 || height < 1 || height > 8192 ||
      stride < (size_t)width * 4 || top < 0 || crop < 1 || top > height - crop)
    return 1;
  try {
    r->upload.resize((size_t)width * crop * 4);
    for (int y = 0; y < crop; y++)
      memcpy(r->upload.data() + (size_t)y * width * 4,
             pixels + (size_t)(top + crop - 1 - y) * stride, (size_t)width * 4);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, r->textures[0]);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    if (width != r->width || crop != r->height) {
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, crop, 0, GL_BGRA, GL_UNSIGNED_BYTE,
                   r->upload.data());
      r->width = width;
      r->height = crop;
    } else
      glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, crop, GL_BGRA, GL_UNSIGNED_BYTE,
                      r->upload.data());
    return glGetError() == GL_NO_ERROR ? 0 : 2;
  } catch (...) {
    return 2;
  }
}
int odyssey_gl_source_surface(OdysseyGL *r, IOSurfaceRef surface, int top, int crop) {
  if (!r || !surface || IOSurfaceGetPlaneCount(surface) != 0 ||
      IOSurfaceGetPixelFormat(surface) != 0x42475241 || IOSurfaceGetBytesPerElement(surface) != 4)
    return 1;
  const int width = (int)IOSurfaceGetWidth(surface), height = (int)IOSurfaceGetHeight(surface);
  if (width < 2 || width > 8192 || width % 2 || height < 1 || height > 8192 || top < 0 ||
      crop < 1 || top > height - crop)
    return 1;
  if (!r->surfaceTexture) {
    glGenTextures(1, &r->surfaceTexture);
    glGenFramebuffers(2, r->copyFrames);
  }
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_RECTANGLE, r->surfaceTexture);
  glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  const auto result =
      CGLTexImageIOSurface2D(CGLGetCurrentContext(), GL_TEXTURE_RECTANGLE, GL_RGBA8, width, height,
                             GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, surface, 0);
  if (result != kCGLNoError) {
    while (glGetError() != GL_NO_ERROR) {
    }
    return 2;
  }
  glBindTexture(GL_TEXTURE_2D, r->textures[0]);
  if (width != r->width || crop != r->height) {
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, crop, 0, GL_BGRA, GL_UNSIGNED_BYTE, nullptr);
    r->width = width;
    r->height = crop;
  }
  GLint readFrame = 0, drawFrame = 0;
  glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &readFrame);
  glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &drawFrame);
  const auto scissor = glIsEnabled(GL_SCISSOR_TEST);
  const auto srgb = glIsEnabled(GL_FRAMEBUFFER_SRGB);
  glDisable(GL_SCISSOR_TEST);
  glDisable(GL_FRAMEBUFFER_SRGB);
  glBindFramebuffer(GL_READ_FRAMEBUFFER, r->copyFrames[0]);
  glFramebufferTexture2D(GL_READ_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_RECTANGLE,
                         r->surfaceTexture, 0);
  glReadBuffer(GL_COLOR_ATTACHMENT0);
  glBindFramebuffer(GL_DRAW_FRAMEBUFFER, r->copyFrames[1]);
  glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, r->textures[0],
                         0);
  glDrawBuffer(GL_COLOR_ATTACHMENT0);
  const bool complete = glCheckFramebufferStatus(GL_READ_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE &&
                        glCheckFramebufferStatus(GL_DRAW_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
  if (complete)
    glBlitFramebuffer(0, top + crop, width, top, 0, 0, width, crop, GL_COLOR_BUFFER_BIT,
                      GL_NEAREST);
  glBindFramebuffer(GL_READ_FRAMEBUFFER, readFrame);
  glBindFramebuffer(GL_DRAW_FRAMEBUFFER, drawFrame);
  if (scissor)
    glEnable(GL_SCISSOR_TEST);
  if (srgb)
    glEnable(GL_FRAMEBUFFER_SRGB);
  const auto error = glGetError();
  return complete && error == GL_NO_ERROR ? 0 : 2;
}

int odyssey_gl_draw(OdysseyGL *r, const float *vertices, int woven) {
  if (!r || !vertices || !r->width)
    return 1;
  glUseProgram(r->program);
  glBindVertexArray(r->vao);
  for (int i = 0; i < 4; i++) {
    glActiveTexture(GL_TEXTURE0 + i);
    glBindTexture(GL_TEXTURE_2D, r->textures[i]);
  }
  glViewport(0, 0, 3840, 2160);
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_BLEND);
  glDisable(GL_DITHER);
  glDisable(GL_FRAMEBUFFER_SRGB);
  glUniform1i(glGetUniformLocation(r->program, "u"), woven ? 1 : 0);
  glBindBuffer(GL_ARRAY_BUFFER, r->buffers[0]);
  glBufferData(GL_ARRAY_BUFFER, 3 * 64, vertices, GL_STREAM_DRAW);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  return glGetError() == GL_NO_ERROR ? 0 : 2;
}
