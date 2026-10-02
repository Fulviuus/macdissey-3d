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
    char _m1_pad[4];
    float g_srcH;
    char _m2_pad[20];
    float g_fpEyeFrac;
    float g_fpGapFrac;
    float g_convergence;
    char _m5_pad[16];
    float g_fpEyeAlign;
    char _m6_pad[68];
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
    float _4533 = floor((_395.g_fpEyeFrac * _395.g_srcH) + 0.5);
    float _4545 = fast::max(1.0, (_395.g_srcH - _4533) - floor((_395.g_fpGapFrac * _395.g_srcH) + 0.5));
    float _4552 = _395.g_srcH - _4545;
    float _4557 = in.i_uv.y * (fast::max(1.0, fast::min(_4533, _4545)) - 1.0);
    float2 _4578 = float2((_3558 ? ((in.i_uv.x - 0.5) * 2.0) : (in.i_uv.x * 2.0)) + (_13387 ? (-_395.g_convergence) : _395.g_convergence), ((_13387 ? fast::clamp((_4552 + _395.g_fpEyeAlign) + _4557, _4552, _395.g_srcH - 1.0) : _4557) + 0.5) / _395.g_srcH);
    float4 _13433;
    do
    {
        if (_395.g_srcDecode < 0.5)
        {
            _13433 = srcTex.sample(samp, _4578, level(0.0));
            break;
        }
        uint2 _11634 = uint2(srcTex.get_width(), srcTex.get_height());
        uint _11636 = _11634.x;
        uint _11638 = _11634.y;
        float2 _11647 = (_4578 * float2(float(_11636), float(_11638))) - float2(0.5);
        int2 _11654 = int2(int(_11636), int(_11638)) - int2(1);
        float2 _11656 = rint(_11647);
        if (all(abs(_11647 - _11656) < float2(0.001953125)))
        {
            float4 _11738 = srcTex.read(uint2(int3(clamp(int2(_11656), int2(0), _11654), 0).xy), 0);
            float4 _30513;
            if (_395.g_srcDecode > 0.5)
            {
                float3 _11747 = fast::clamp(_11738.xyz, float3(0.0), float3(1.0));
                float3 _11770 = select(powr((_11747 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11747 * float3(0.077399380505084991455078125), _11747 <= float3(0.040449999272823333740234375));
                float4 _30457 = _11738;
                _30457.x = _11770.x;
                _30457.y = _11770.y;
                _30457.z = _11770.z;
                _30513 = _30457;
            }
            else
            {
                _30513 = _11738;
            }
            _13433 = _30513;
            break;
        }
        float2 _11674 = fract(_11647);
        int2 _11677 = int2(floor(_11647));
        int2 _11679 = clamp(_11677, int2(0), _11654);
        int2 _11686 = clamp(_11677 + int2(1), int2(0), _11654);
        int _11688 = _11679.x;
        float4 _11780 = srcTex.read(uint2(int3(_11688, _11679.y, 0).xy), 0);
        bool _11783 = _395.g_srcDecode > 0.5;
        float4 _30509;
        if (_11783)
        {
            float3 _11789 = fast::clamp(_11780.xyz, float3(0.0), float3(1.0));
            float3 _11812 = select(powr((_11789 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11789 * float3(0.077399380505084991455078125), _11789 <= float3(0.040449999272823333740234375));
            float4 _30466 = _11780;
            _30466.x = _11812.x;
            _30466.y = _11812.y;
            _30466.z = _11812.z;
            _30509 = _30466;
        }
        else
        {
            _30509 = _11780;
        }
        int _11694 = _11686.x;
        float4 _11822 = srcTex.read(uint2(int3(_11694, _11679.y, 0).xy), 0);
        float4 _30510;
        if (_11783)
        {
            float3 _11831 = fast::clamp(_11822.xyz, float3(0.0), float3(1.0));
            float3 _11854 = select(powr((_11831 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11831 * float3(0.077399380505084991455078125), _11831 <= float3(0.040449999272823333740234375));
            float4 _30475 = _11822;
            _30475.x = _11854.x;
            _30475.y = _11854.y;
            _30475.z = _11854.z;
            _30510 = _30475;
        }
        else
        {
            _30510 = _11822;
        }
        float4 _11864 = srcTex.read(uint2(int3(_11688, _11686.y, 0).xy), 0);
        float4 _30511;
        if (_11783)
        {
            float3 _11873 = fast::clamp(_11864.xyz, float3(0.0), float3(1.0));
            float3 _11896 = select(powr((_11873 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11873 * float3(0.077399380505084991455078125), _11873 <= float3(0.040449999272823333740234375));
            float4 _30484 = _11864;
            _30484.x = _11896.x;
            _30484.y = _11896.y;
            _30484.z = _11896.z;
            _30511 = _30484;
        }
        else
        {
            _30511 = _11864;
        }
        float4 _11906 = srcTex.read(uint2(int3(_11694, _11686.y, 0).xy), 0);
        float4 _30512;
        if (_11783)
        {
            float3 _11915 = fast::clamp(_11906.xyz, float3(0.0), float3(1.0));
            float3 _11938 = select(powr((_11915 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11915 * float3(0.077399380505084991455078125), _11915 <= float3(0.040449999272823333740234375));
            float4 _30493 = _11906;
            _30493.x = _11938.x;
            _30493.y = _11938.y;
            _30493.z = _11938.z;
            _30512 = _30493;
        }
        else
        {
            _30512 = _11906;
        }
        float4 _11715 = float4(_11674.x);
        _13433 = mix(mix(_30509, _30510, _11715), mix(_30511, _30512, _11715), float4(_11674.y));
        break;
    } while(false);
    float4 _30502 = _13433;
    _30502.w = 1.0;
    out._entryPointOutput = _30502;
    return out;
}
