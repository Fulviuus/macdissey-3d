#ifndef ODYSSEY_GL_H
#define ODYSSEY_GL_H
#include <IOSurface/IOSurfaceRef.h>
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct OdysseyGL OdysseyGL;
// All calls require the same current OpenGL 4.1 context. Corrections have
// 480x270 bytes, bottom row first. Shader strings are the recovered originals.
OdysseyGL *odyssey_gl_create(const char *vertex, const char *fragment, const uint8_t *correction_a,
                             const uint8_t *correction_b, char *error, size_t error_size);
void odyssey_gl_destroy(OdysseyGL *renderer);
// Upload BGRA top-first capture bytes. crop_top/height select full-SBS content
// inside the fullscreen letterbox. No geometry or calibration is altered.
int odyssey_gl_source(OdysseyGL *renderer, const uint8_t *pixels, int width, int height,
                      size_t stride, int crop_top, int crop_height);
// Import IOSurface storage and flip/crop on the GPU. The caller must retain the
// pixel buffer until its GL work completes. Nonzero permits a CPU-path fallback.
int odyssey_gl_source_surface(OdysseyGL *renderer, IOSurfaceRef surface, int crop_top,
                              int crop_height);
// Vertices are original 3x16 floats: XYZW,phase4,ray4,screen2,weave2.
// Draw into the caller's framebuffer at exactly3840x2160. woven=false shows
// the original shader's left view; it does not invent a tracking position.
int odyssey_gl_draw(OdysseyGL *renderer, const float *vertices, int woven);
#ifdef __cplusplus
}
#endif
#endif
