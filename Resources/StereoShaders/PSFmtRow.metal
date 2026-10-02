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
    char _m2_pad[28];
    float g_convergence;
    char _m3_pad[88];
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
    float2 _3630 = float2((_3558 ? ((in.i_uv.x - 0.5) * 2.0) : (in.i_uv.x * 2.0)) + (_13387 ? (-_395.g_convergence) : _395.g_convergence), (((floor(in.i_uv.y * (_395.g_srcH * 0.5)) * 2.0) + float(_13387)) + 0.5) / _395.g_srcH);
    float4 _13612;
    do
    {
        if (_395.g_srcDecode < 0.5)
        {
            _13612 = srcTex.sample(samp, _3630, level(0.0));
            break;
        }
        uint2 _5744 = uint2(srcTex.get_width(), srcTex.get_height());
        uint _5746 = _5744.x;
        uint _5748 = _5744.y;
        float2 _5757 = (_3630 * float2(float(_5746), float(_5748))) - float2(0.5);
        int2 _5764 = int2(int(_5746), int(_5748)) - int2(1);
        float2 _5766 = rint(_5757);
        if (all(abs(_5757 - _5766) < float2(0.001953125)))
        {
            float4 _5848 = srcTex.read(uint2(int3(clamp(int2(_5766), int2(0), _5764), 0).xy), 0);
            float4 _30510;
            if (_395.g_srcDecode > 0.5)
            {
                float3 _5857 = fast::clamp(_5848.xyz, float3(0.0), float3(1.0));
                float3 _5880 = select(powr((_5857 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5857 * float3(0.077399380505084991455078125), _5857 <= float3(0.040449999272823333740234375));
                float4 _30457 = _5848;
                _30457.x = _5880.x;
                _30457.y = _5880.y;
                _30457.z = _5880.z;
                _30510 = _30457;
            }
            else
            {
                _30510 = _5848;
            }
            _13612 = _30510;
            break;
        }
        float2 _5784 = fract(_5757);
        int2 _5787 = int2(floor(_5757));
        int2 _5789 = clamp(_5787, int2(0), _5764);
        int2 _5796 = clamp(_5787 + int2(1), int2(0), _5764);
        int _5798 = _5789.x;
        float4 _5890 = srcTex.read(uint2(int3(_5798, _5789.y, 0).xy), 0);
        bool _5893 = _395.g_srcDecode > 0.5;
        float4 _30506;
        if (_5893)
        {
            float3 _5899 = fast::clamp(_5890.xyz, float3(0.0), float3(1.0));
            float3 _5922 = select(powr((_5899 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5899 * float3(0.077399380505084991455078125), _5899 <= float3(0.040449999272823333740234375));
            float4 _30466 = _5890;
            _30466.x = _5922.x;
            _30466.y = _5922.y;
            _30466.z = _5922.z;
            _30506 = _30466;
        }
        else
        {
            _30506 = _5890;
        }
        int _5804 = _5796.x;
        float4 _5932 = srcTex.read(uint2(int3(_5804, _5789.y, 0).xy), 0);
        float4 _30507;
        if (_5893)
        {
            float3 _5941 = fast::clamp(_5932.xyz, float3(0.0), float3(1.0));
            float3 _5964 = select(powr((_5941 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5941 * float3(0.077399380505084991455078125), _5941 <= float3(0.040449999272823333740234375));
            float4 _30475 = _5932;
            _30475.x = _5964.x;
            _30475.y = _5964.y;
            _30475.z = _5964.z;
            _30507 = _30475;
        }
        else
        {
            _30507 = _5932;
        }
        float4 _5974 = srcTex.read(uint2(int3(_5798, _5796.y, 0).xy), 0);
        float4 _30508;
        if (_5893)
        {
            float3 _5983 = fast::clamp(_5974.xyz, float3(0.0), float3(1.0));
            float3 _6006 = select(powr((_5983 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5983 * float3(0.077399380505084991455078125), _5983 <= float3(0.040449999272823333740234375));
            float4 _30484 = _5974;
            _30484.x = _6006.x;
            _30484.y = _6006.y;
            _30484.z = _6006.z;
            _30508 = _30484;
        }
        else
        {
            _30508 = _5974;
        }
        float4 _6016 = srcTex.read(uint2(int3(_5804, _5796.y, 0).xy), 0);
        float4 _30509;
        if (_5893)
        {
            float3 _6025 = fast::clamp(_6016.xyz, float3(0.0), float3(1.0));
            float3 _6048 = select(powr((_6025 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6025 * float3(0.077399380505084991455078125), _6025 <= float3(0.040449999272823333740234375));
            float4 _30493 = _6016;
            _30493.x = _6048.x;
            _30493.y = _6048.y;
            _30493.z = _6048.z;
            _30509 = _30493;
        }
        else
        {
            _30509 = _6016;
        }
        float4 _5825 = float4(_5784.x);
        _13612 = mix(mix(_30506, _30507, _5825), mix(_30508, _30509, _5825), float4(_5784.y));
        break;
    } while(false);
    float4 _30502 = _13612;
    _30502.w = 1.0;
    out._entryPointOutput = _30502;
    return out;
}
