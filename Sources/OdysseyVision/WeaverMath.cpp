// Recovered DimencoWeaving 1.36.4 RVAs bf20/a370, ordinary ET/LRGB path.
// The operation order is intentionally the same as the original float code.
#include "OdysseyVision.h"
#include <cmath>
void odyssey_weave_attributes(const float *p, const float *eye, const float *resolution,
                              const float *offset, const float *vertex, float *out) {
  const float ex = eye[0] / p[7], ey = -eye[1] / p[7], ez = eye[2] / p[7];
  const float q = 1.0f - p[3] / (ez * p[4]);
  const float sx = ((vertex[0] + 1.0f) * resolution[0] * 0.5f + offset[0]) - 0.5f;
  const float sy =
      (resolution[1] - 1.0f) - (((vertex[1] + 1.0f) * resolution[1] * 0.5f + offset[1]) - 0.5f);
  const float cx = sx - 3840.0f * 0.5f, cy = sy - 2160.0f * 0.5f;
  const float dx = ex - cx, dy = ey - cy;
  const float base = ((cy * p[0] + cx) * 3.0f) / p[1] + (p[5] / 28.0f + 10000.0f);
  // LRGB's first stamp offset is zero. RGB offsets are applied in the
  // fragment shader using phase derivatives and the full subpixel stamp.
  out[0] = base;
  out[1] = base;
  out[2] = base;
  out[3] = 0;
  const float u = dy * p[0] + dx;
  const float a = (p[4] * p[4] - 1.0f) * q * q;
  const float norm = sqrtf((ez * ez * p[4] * p[4]) / a);
  out[4] = dx;
  out[5] = dy;
  out[6] = dx / norm;
  out[7] = dy / norm;
  out[8] = sx;
  out[9] = sy;
  out[10] = (((p[3] * 3.0f * q * u) / p[1]) / sqrtf(a)) / norm;
  out[11] = u / ez;
}
