// Original macdissey test scene. MIT license; see the repository LICENSE.
#include <metal_stdlib>
using namespace metal;
struct Params {
  uint width, height, format, phase;
  float time, separation;
  uint pair, isolation;
  uint markers, monochrome, screenGrid, pad1;
};
struct Varying {
  float4 position [[position]];
};
vertex Varying vertexMain(uint i [[vertex_id]]) {
  float2 uv = float2((i << 1) & 2, i & 2);
  return {float4(uv.x * 2 - 1, 1 - uv.y * 2, 0, 1)};
}
float3 rotateY(float3 v, float a) {
  float c = cos(a), s = sin(a);
  return float3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}
float3 rotateX(float3 v, float a) {
  float c = cos(a), s = sin(a);
  return float3(v.x, c * v.y - s * v.z, s * v.y + c * v.z);
}
float3 maskFor(uint pair, bool right) {
  switch (pair) {
  case 0:
    return right ? float3(0, 1, 1) : float3(1, 0, 0);
  case 1:
    return right ? float3(0, 1, 0) : float3(1, 0, 0);
  case 2:
    return right ? float3(0, 0, 1) : float3(1, 0, 0);
  case 3:
    return right ? float3(1, 0, 1) : float3(0, 1, 0);
  case 4:
    return right ? float3(0, 0, 1) : float3(1, 1, 0);
  default:
    return right ? float3(1, 0, 1) : float3(0, 1, 1);
  }
}
float3 scene(float2 uv, float eye, constant Params &p, bool spherical = false) {
  if ((p.isolation == 1 && eye > 0.001) || (p.isolation == 2 && eye < -0.001))
    return 0;
  float eyeX = eye * p.separation;
  float3 origin = float3(eyeX, 0, 0);
  float3 dir;
  if (spherical) {
    float lon = (uv.x - 0.5) * (p.format >= 14 ? 2 * M_PI_F : M_PI_F);
    float lat = (0.5 - uv.y) * M_PI_F;
    dir = float3(sin(lon) * cos(lat), sin(lat), cos(lon) * cos(lat));
    // Converge on the same z=4 plane as the flat test view.
    dir = normalize(float3(dir.x - eyeX / 4 * dir.z, dir.y, dir.z));
  } else {
    dir = normalize(float3((uv.x * 2 - 1) - eyeX / 4, (1 - uv.y * 2) * 9.0 / 16.0, 1));
  }
  float3 color = float3(0.008, 0.012, 0.024);
  // A fixed grid at z=8 makes background disparity visible.
  if (dir.z > 0.001) {
    float3 q = origin + dir * (8 / dir.z);
    if (p.screenGrid) {
      // Zero-disparity grid reference. Keep angular spacing and brightness
      // unchanged; the cube still uses the original stereo camera rays.
      if (spherical) {
        float lon = (uv.x - 0.5) * (p.format >= 14 ? 2 * M_PI_F : M_PI_F);
        float lat = (0.5 - uv.y) * M_PI_F;
        float3 gridDir = float3(sin(lon) * cos(lat), sin(lat), cos(lon) * cos(lat));
        q = gridDir * (8 / gridDir.z);
      } else {
        q = float3((uv.x * 2 - 1) * 8, (1 - uv.y * 2) * 4.5, 8);
      }
    }
    float2 grid = abs(fract(q.xy) - 0.5);
    float line = 1 - smoothstep(0.012, 0.035, min(grid.x, grid.y));
    color += float3(0.045, 0.070, 0.105) * line;
    color += float3(0.009, 0.014, 0.023) * exp(-0.045 * dot(q.xy, q.xy));
  }
  float t = p.time;
  // Pulfrich needs lateral motion as well as rotation; its source stays mono.
  float3 center = float3(p.format == 9 ? 1.1 * sin(t * 0.9) : 0, 0, 3.65);
  float3 o = rotateX(rotateY(origin - center, -t * 0.55), -0.35 - t * 0.23);
  float3 d = rotateX(rotateY(dir, -t * 0.55), -0.35 - t * 0.23);
  float3 safeD = select(float3(-1e-6), float3(1e-6), d >= 0);
  safeD = select(safeD, d, abs(d) > 1e-6);
  float3 t0 = (-0.68 - o) / safeD, t1 = (0.68 - o) / safeD;
  float3 nearV = min(t0, t1), farV = max(t0, t1);
  float entry = max(max(nearV.x, nearV.y), nearV.z);
  float leave = min(min(farV.x, farV.y), farV.z);
  if (leave > max(entry, 0.0)) {
    float3 hit = o + d * max(entry, 0.0);
    float3 ah = abs(hit);
    float3 n = 0, base;
    float2 face;
    if (ah.x >= ah.y && ah.x >= ah.z) {
      n.x = sign(hit.x);
      base = float3(0.08, 0.65, 0.95);
      face = hit.yz;
    } else if (ah.y >= ah.z) {
      n.y = sign(hit.y);
      base = float3(0.96, 0.48, 0.07);
      face = hit.xz;
    } else {
      n.z = sign(hit.z);
      base = float3(0.45, 0.16, 0.88);
      face = hit.xy;
    }
    float3 worldN = rotateY(rotateX(n, 0.35 + t * 0.23), t * 0.55);
    float diffuse = 0.32 + 0.68 * max(0.0, dot(worldN, normalize(float3(-0.5, 0.8, -1))));
    float edge = smoothstep(0.625, 0.66, max(abs(face.x), abs(face.y)));
    float tile = fmod(floor((face.x + 0.68) * 6) + floor((face.y + 0.68) * 6), 2.0);
    color = mix(base * (0.74 + 0.26 * tile) * diffuse, float3(0.9), edge);
    float ring = 1 - smoothstep(0.016, 0.026, abs(length(face) - 0.24));
    color = mix(color, float3(0.88), ring * 0.85);
  }
  if (p.monochrome)
    color = dot(color, float3(0.2126, 0.7152, 0.0722));
  // Screen-plane registration cross, plus an L/R glyph per encoded eye.
  if (p.markers && !spherical) {
    float2 q = abs(uv - float2(0.5, 0.83));
    if ((q.x < 0.025 && q.y < 0.0018) || (q.x < 0.001 && q.y < 0.035))
      color = 0.7;
    float2 g = (uv - float2(0.055, 0.07)) / float2(0.012, 0.021);
    int x = int(floor(g.x)), y = int(floor(g.y));
    if (x >= 0 && x < 5 && y >= 0 && y < 7) {
      uint rowsL[7] = {16, 16, 16, 16, 16, 16, 31};
      uint rowsR[7] = {30, 17, 17, 30, 20, 18, 17};
      uint bits = eye > 0 ? rowsR[y] : rowsL[y];
      if (bits & (1u << (4 - x)))
        color = 0.7;
    }
  }
  return clamp(color, 0.0, 1.0);
}
fragment float4 fragmentMain(Varying in [[stage_in]], constant Params &p [[buffer(0)]]) {
  uint2 pixel = uint2(in.position.xy);
  float2 uv = in.position.xy / float2(p.width, p.height), e = uv;
  bool right = false, spherical = false;
  float eye;
  switch (p.format) {
  case 0: // Full SBS occupies the middle half of the 16:9 capture.
    if (uv.y < 0.25 || uv.y >= 0.75)
      return float4(0, 0, 0, 1);
    e.y = (uv.y - 0.25) * 2;
    right = uv.x >= 0.5;
    e.x = fract(uv.x * 2);
    break;
  case 1:
    right = uv.x >= 0.5;
    e.x = fract(uv.x * 2);
    break;
  case 2:
  case 3:
    right = uv.y >= 0.5;
    e.y = fract(uv.y * 2);
    break;
  case 4:
    right = (pixel.y & 1) != 0;
    e.y = (float(pixel.y / 2) + 0.5) / float(p.height / 2);
    break;
  case 5:
    right = (pixel.x & 1) != 0;
    e.x = (float(pixel.x / 2) + 0.5) / float(p.width / 2);
    break;
  case 6:
    right = ((pixel.x + pixel.y) & 1) != 0;
    break;
  case 7: {
    float3 l = scene(uv, -1, p), r = scene(uv, 1, p);
    float3 lm = maskFor(p.pair, false), rm = maskFor(p.pair, true);
    // Overlapping blue channel in cyan/magenta carries their average.
    float3 c = (l * lm + r * rm) / max(lm + rm, float3(1));
    return float4(c, 1);
  }
  case 8:
    right = p.phase != 0;
    break;
  case 9:
    return float4(scene(uv, 0, p), 1); // Pulfrich's source is ordinary mono.
  case 10: {
    uint top = uint(round(float(p.height) * 1080 / 2205));
    uint gap = uint(round(float(p.height) * 45 / 2205));
    uint bottom = p.height - top - gap, shared = min(top, bottom);
    if (pixel.y >= top && pixel.y < top + gap)
      return float4(0, 0, 0, 1);
    right = pixel.y >= top + gap;
    float row = float(pixel.y - (right ? top + gap : 0));
    e.y = row / max(1.0, float(shared - 1));
    break;
  }
  case 11: {
    uint col = min(4u, uint(uv.x * 5)), row = min(8u, uint(uv.y * 9));
    uint index = (8 - row) * 5 + col;
    e = fract(uv * float2(5, 9));
    // Tiles preserve their native aspect in the decoder: account for it
    // while drawing, so the eventual cube remains geometrically square.
    float aspect = (float(p.width) / 5) / (float(p.height) / 9);
    e.y = 0.5 + (e.y - 0.5) * (16.0 / 9.0) / aspect;
    eye = (float(index) - 22) / 2; // macdissey defaults: views 20 and 24.
    return float4(scene(e, eye, p), 1);
  }
  case 12:
  case 14:
    right = uv.y >= 0.5;
    e.y = fract(uv.y * 2);
    spherical = true;
    break;
  case 13:
  case 15:
    right = uv.x >= 0.5;
    e.x = fract(uv.x * 2);
    spherical = true;
    break;
  case 16:
    return float4(scene(uv, 0, p), 1); // Ordinary source for AI conversion.
  }
  eye = right ? 1 : -1;
  return float4(scene(e, eye, p, spherical), 1);
}
