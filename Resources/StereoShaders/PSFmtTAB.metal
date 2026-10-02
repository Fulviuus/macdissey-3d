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
    float _3598 = in.i_uv.y * 0.5;
    float2 _3604 = float2((_3558 ? ((in.i_uv.x - 0.5) * 2.0) : (in.i_uv.x * 2.0)) + (_13387 ? (-_395.g_convergence) : _395.g_convergence), _13387 ? (0.5 + _3598) : _3598);
    float4 _13613;
    do
    {
        if (_395.g_srcDecode < 0.5)
        {
            _13613 = srcTex.sample(samp, _3604, level(0.0));
            break;
        }
        uint2 _5396 = uint2(srcTex.get_width(), srcTex.get_height());
        uint _5398 = _5396.x;
        uint _5400 = _5396.y;
        float2 _5409 = (_3604 * float2(float(_5398), float(_5400))) - float2(0.5);
        int2 _5416 = int2(int(_5398), int(_5400)) - int2(1);
        float2 _5418 = rint(_5409);
        if (all(abs(_5409 - _5418) < float2(0.001953125)))
        {
            float4 _5500 = srcTex.read(uint2(int3(clamp(int2(_5418), int2(0), _5416), 0).xy), 0);
            float4 _30510;
            if (_395.g_srcDecode > 0.5)
            {
                float3 _5509 = fast::clamp(_5500.xyz, float3(0.0), float3(1.0));
                float3 _5532 = select(powr((_5509 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5509 * float3(0.077399380505084991455078125), _5509 <= float3(0.040449999272823333740234375));
                float4 _30458 = _5500;
                _30458.x = _5532.x;
                _30458.y = _5532.y;
                _30458.z = _5532.z;
                _30510 = _30458;
            }
            else
            {
                _30510 = _5500;
            }
            _13613 = _30510;
            break;
        }
        float2 _5436 = fract(_5409);
        int2 _5439 = int2(floor(_5409));
        int2 _5441 = clamp(_5439, int2(0), _5416);
        int2 _5448 = clamp(_5439 + int2(1), int2(0), _5416);
        int _5450 = _5441.x;
        float4 _5542 = srcTex.read(uint2(int3(_5450, _5441.y, 0).xy), 0);
        bool _5545 = _395.g_srcDecode > 0.5;
        float4 _30506;
        if (_5545)
        {
            float3 _5551 = fast::clamp(_5542.xyz, float3(0.0), float3(1.0));
            float3 _5574 = select(powr((_5551 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5551 * float3(0.077399380505084991455078125), _5551 <= float3(0.040449999272823333740234375));
            float4 _30467 = _5542;
            _30467.x = _5574.x;
            _30467.y = _5574.y;
            _30467.z = _5574.z;
            _30506 = _30467;
        }
        else
        {
            _30506 = _5542;
        }
        int _5456 = _5448.x;
        float4 _5584 = srcTex.read(uint2(int3(_5456, _5441.y, 0).xy), 0);
        float4 _30507;
        if (_5545)
        {
            float3 _5593 = fast::clamp(_5584.xyz, float3(0.0), float3(1.0));
            float3 _5616 = select(powr((_5593 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5593 * float3(0.077399380505084991455078125), _5593 <= float3(0.040449999272823333740234375));
            float4 _30476 = _5584;
            _30476.x = _5616.x;
            _30476.y = _5616.y;
            _30476.z = _5616.z;
            _30507 = _30476;
        }
        else
        {
            _30507 = _5584;
        }
        float4 _5626 = srcTex.read(uint2(int3(_5450, _5448.y, 0).xy), 0);
        float4 _30508;
        if (_5545)
        {
            float3 _5635 = fast::clamp(_5626.xyz, float3(0.0), float3(1.0));
            float3 _5658 = select(powr((_5635 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5635 * float3(0.077399380505084991455078125), _5635 <= float3(0.040449999272823333740234375));
            float4 _30485 = _5626;
            _30485.x = _5658.x;
            _30485.y = _5658.y;
            _30485.z = _5658.z;
            _30508 = _30485;
        }
        else
        {
            _30508 = _5626;
        }
        float4 _5668 = srcTex.read(uint2(int3(_5456, _5448.y, 0).xy), 0);
        float4 _30509;
        if (_5545)
        {
            float3 _5677 = fast::clamp(_5668.xyz, float3(0.0), float3(1.0));
            float3 _5700 = select(powr((_5677 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5677 * float3(0.077399380505084991455078125), _5677 <= float3(0.040449999272823333740234375));
            float4 _30494 = _5668;
            _30494.x = _5700.x;
            _30494.y = _5700.y;
            _30494.z = _5700.z;
            _30509 = _30494;
        }
        else
        {
            _30509 = _5668;
        }
        float4 _5477 = float4(_5436.x);
        _13613 = mix(mix(_30506, _30507, _5477), mix(_30508, _30509, _5477), float4(_5436.y));
        break;
    } while(false);
    float4 _30503 = _13613;
    _30503.w = 1.0;
    out._entryPointOutput = _30503;
    return out;
}
