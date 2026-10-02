// Generated from SR-Loom Converter.hlsl (MIT). Copyright (c) 2026 SR Loom contributors.
// Upstream d0b93f308d5aaf7c57fd02f5a3bd61402fe31f8b. See Resources/Licenses/SR-Loom-LICENSE.txt.
// Regenerate with scripts/translate-stereo-shaders.py.
#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct Params
{
    char _m0_pad[4];
    int g_swap;
    float g_srcW;
    float g_srcH;
    char _m3_pad[28];
    float g_convergence;
    char _m4_pad[88];
    float g_srcDecode;
};

struct main0_out
{
    float4 _entryPointOutput [[color(0)]];
};

struct main0_in
{
    float2 i_uv [[user(locn0)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant Params& _395 [[buffer(0)]], texture2d<float> srcTex [[texture(0)]])
{
    main0_out out = {};
    bool _3558 = in.i_uv.x >= 0.5;
    bool _13387;
    if (_395.g_swap != int(0u))
    {
        _13387 = !_3558;
    }
    else
    {
        _13387 = _3558;
    }
    float4 _6058 = srcTex.read(uint2(int3(clamp((int(floor(((_3558 ? ((in.i_uv.x - 0.5) * 2.0) : (in.i_uv.x * 2.0)) + (_13387 ? (-_395.g_convergence) : _395.g_convergence)) * (_395.g_srcW * 0.5))) * 2) + int(_13387), 0, int(_395.g_srcW) - 1), clamp(int(floor(in.i_uv.y * _395.g_srcH)), 0, int(_395.g_srcH) - 1), 0).xy), 0);
    float4 _30468;
    if (_395.g_srcDecode > 0.5)
    {
        float3 _6067 = fast::clamp(_6058.xyz, float3(0.0), float3(1.0));
        float3 _6090 = select(powr((_6067 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6067 * float3(0.077399380505084991455078125), _6067 <= float3(0.040449999272823333740234375));
        float4 _30457 = _6058;
        _30457.x = _6090.x;
        _30457.y = _6090.y;
        _30457.z = _6090.z;
        _30468 = _30457;
    }
    else
    {
        _30468 = _6058;
    }
    float4 _30463 = _30468;
    _30463.w = 1.0;
    out._entryPointOutput = _30463;
    return out;
}
