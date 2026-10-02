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
    char _m1_pad[36];
    float g_convergence;
    char _m2_pad[88];
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

fragment main0_out main0(main0_in in [[stage_in]], constant Params& _395 [[buffer(0)]], texture2d<float> srcTex [[texture(0)]], sampler samp [[sampler(0)]])
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
    float _4991 = ((_3558 ? ((in.i_uv.x - 0.5) * 2.0) : (in.i_uv.x * 2.0)) + (_13387 ? (-_395.g_convergence) : _395.g_convergence)) * 0.5;
    float2 _4998 = float2(_13387 ? (0.5 + _4991) : _4991, in.i_uv.y);
    float4 _13390;
    do
    {
        if (_395.g_srcDecode < 0.5)
        {
            _13390 = srcTex.sample(samp, _4998, level(0.0));
            break;
        }
        uint2 _13066 = uint2(srcTex.get_width(), srcTex.get_height());
        uint _13068 = _13066.x;
        uint _13070 = _13066.y;
        float2 _13079 = (_4998 * float2(float(_13068), float(_13070))) - float2(0.5);
        int2 _13086 = int2(int(_13068), int(_13070)) - int2(1);
        float2 _13088 = rint(_13079);
        if (all(abs(_13079 - _13088) < float2(0.001953125)))
        {
            float4 _13170 = srcTex.read(uint2(int3(clamp(int2(_13088), int2(0), _13086), 0).xy), 0);
            float4 _30510;
            if (_395.g_srcDecode > 0.5)
            {
                float3 _13179 = fast::clamp(_13170.xyz, float3(0.0), float3(1.0));
                float3 _13202 = select(powr((_13179 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13179 * float3(0.077399380505084991455078125), _13179 <= float3(0.040449999272823333740234375));
                float4 _30458 = _13170;
                _30458.x = _13202.x;
                _30458.y = _13202.y;
                _30458.z = _13202.z;
                _30510 = _30458;
            }
            else
            {
                _30510 = _13170;
            }
            _13390 = _30510;
            break;
        }
        float2 _13106 = fract(_13079);
        int2 _13109 = int2(floor(_13079));
        int2 _13111 = clamp(_13109, int2(0), _13086);
        int2 _13118 = clamp(_13109 + int2(1), int2(0), _13086);
        int _13120 = _13111.x;
        float4 _13212 = srcTex.read(uint2(int3(_13120, _13111.y, 0).xy), 0);
        bool _13215 = _395.g_srcDecode > 0.5;
        float4 _30506;
        if (_13215)
        {
            float3 _13221 = fast::clamp(_13212.xyz, float3(0.0), float3(1.0));
            float3 _13244 = select(powr((_13221 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13221 * float3(0.077399380505084991455078125), _13221 <= float3(0.040449999272823333740234375));
            float4 _30467 = _13212;
            _30467.x = _13244.x;
            _30467.y = _13244.y;
            _30467.z = _13244.z;
            _30506 = _30467;
        }
        else
        {
            _30506 = _13212;
        }
        int _13126 = _13118.x;
        float4 _13254 = srcTex.read(uint2(int3(_13126, _13111.y, 0).xy), 0);
        float4 _30507;
        if (_13215)
        {
            float3 _13263 = fast::clamp(_13254.xyz, float3(0.0), float3(1.0));
            float3 _13286 = select(powr((_13263 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13263 * float3(0.077399380505084991455078125), _13263 <= float3(0.040449999272823333740234375));
            float4 _30476 = _13254;
            _30476.x = _13286.x;
            _30476.y = _13286.y;
            _30476.z = _13286.z;
            _30507 = _30476;
        }
        else
        {
            _30507 = _13254;
        }
        float4 _13296 = srcTex.read(uint2(int3(_13120, _13118.y, 0).xy), 0);
        float4 _30508;
        if (_13215)
        {
            float3 _13305 = fast::clamp(_13296.xyz, float3(0.0), float3(1.0));
            float3 _13328 = select(powr((_13305 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13305 * float3(0.077399380505084991455078125), _13305 <= float3(0.040449999272823333740234375));
            float4 _30485 = _13296;
            _30485.x = _13328.x;
            _30485.y = _13328.y;
            _30485.z = _13328.z;
            _30508 = _30485;
        }
        else
        {
            _30508 = _13296;
        }
        float4 _13338 = srcTex.read(uint2(int3(_13126, _13118.y, 0).xy), 0);
        float4 _30509;
        if (_13215)
        {
            float3 _13347 = fast::clamp(_13338.xyz, float3(0.0), float3(1.0));
            float3 _13370 = select(powr((_13347 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13347 * float3(0.077399380505084991455078125), _13347 <= float3(0.040449999272823333740234375));
            float4 _30494 = _13338;
            _30494.x = _13370.x;
            _30494.y = _13370.y;
            _30494.z = _13370.z;
            _30509 = _30494;
        }
        else
        {
            _30509 = _13338;
        }
        float4 _13147 = float4(_13106.x);
        _13390 = mix(mix(_30506, _30507, _13147), mix(_30508, _30509, _13147), float4(_13106.y));
        break;
    } while(false);
    float4 _30503 = _13390;
    _30503.w = 1.0;
    out._entryPointOutput = _30503;
    return out;
}
