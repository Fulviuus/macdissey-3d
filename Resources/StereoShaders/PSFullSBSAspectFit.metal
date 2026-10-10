// macdissey 3d — MIT License. Hand-written aspect-fit extension; not a generated SR-Loom port.
#include <metal_stdlib>
using namespace metal;

struct Params {
  int g_swap;
  float g_srcW, g_srcH, g_eyeAspect, g_displayAspect;
};
struct Input {
  float2 uv [[user(locn0)]];
};

fragment float4 main0(Input in [[stage_in]], constant Params& p [[buffer(0)]],
                     texture2d<float> srcTex [[texture(0)]], sampler samp [[sampler(0)]]) {
  bool right = in.uv.x >= 0.5f;
  float2 eyeUV = float2(in.uv.x * 2.0f - (right ? 1.0f : 0.0f), in.uv.y);

  // Fit one complete eye to the native 16:9 panel before the original weaver
  // expands its pane. Both eyes receive identical, centred bars and scale.
  float2 eyeSize = float2(min(1.0f, p.g_eyeAspect / p.g_displayAspect),
                         min(1.0f, p.g_displayAspect / p.g_eyeAspect));
  eyeUV = (eyeUV - 0.5f) / eyeSize + 0.5f;
  if (any(eyeUV < 0.0f) || any(eyeUV > 1.0f)) return float4(0, 0, 0, 1);

  // The source player fits the entire unsqueezed pair, not each eye, to its
  // fullscreen surface. At 4:3 per eye this occupies 2/3 of a 16:9 frame's height.
  float captureAspect = p.g_srcW / p.g_srcH;
  float pairAspect = 2.0f * p.g_eyeAspect;
  float2 pairSize = float2(min(1.0f, pairAspect / captureAspect),
                          min(1.0f, captureAspect / pairAspect));
  bool sourceRight = right != (p.g_swap != 0);
  float2 packedUV = float2((eyeUV.x + (sourceRight ? 1.0f : 0.0f)) * 0.5f, eyeUV.y);
  float2 uv = (packedUV - 0.5f) * pairSize + 0.5f;

  // Keep bilinear samples inside this eye, including the centre packing seam.
  float2 halfPixel = 0.5f / float2(p.g_srcW, p.g_srcH);
  float2 lower = (1.0f - pairSize) * 0.5f;
  float2 upper = 1.0f - lower;
  if (sourceRight) lower.x = 0.5f;
  else upper.x = 0.5f;
  uv = clamp(uv, lower + halfPixel, upper - halfPixel);
  return float4(srcTex.sample(samp, uv, level(0)).rgb, 1);
}
