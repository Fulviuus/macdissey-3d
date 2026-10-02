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
    float4 _13615;
    do
    {
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
        int _3694 = int(_395.g_srcH) - 1;
        int _3695 = clamp(int(floor(in.i_uv.y * _395.g_srcH)), 0, _3694);
        int _3705 = int(_395.g_srcW) - 1;
        int _3706 = clamp(int(floor(((_3558 ? ((in.i_uv.x - 0.5) * 2.0) : (in.i_uv.x * 2.0)) + (_13387 ? (-_395.g_convergence) : _395.g_convergence)) * _395.g_srcW)), 0, _3705);
        if ((((_3706 + _3695) + int(_13387)) & 1) == 0)
        {
            float4 _6100 = srcTex.read(uint2(int3(_3706, _3695, 0).xy), 0);
            float4 _30502;
            if (_395.g_srcDecode > 0.5)
            {
                float3 _6109 = fast::clamp(_6100.xyz, float3(0.0), float3(1.0));
                float3 _6132 = select(powr((_6109 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6109 * float3(0.077399380505084991455078125), _6109 <= float3(0.040449999272823333740234375));
                float4 _30457 = _6100;
                _30457.x = _6132.x;
                _30457.y = _6132.y;
                _30457.z = _6132.z;
                _30502 = _30457;
            }
            else
            {
                _30502 = _6100;
            }
            _13615 = _30502;
            break;
        }
        int _3725 = _3706 - 1;
        int _3727 = _3706 + 1;
        float4 _6142 = srcTex.read(uint2(int3((_3706 > 0) ? _3725 : _3727, _3695, 0).xy), 0);
        bool _6145 = _395.g_srcDecode > 0.5;
        float4 _30498;
        if (_6145)
        {
            float3 _6151 = fast::clamp(_6142.xyz, float3(0.0), float3(1.0));
            float3 _6174 = select(powr((_6151 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6151 * float3(0.077399380505084991455078125), _6151 <= float3(0.040449999272823333740234375));
            float4 _30464 = _6142;
            _30464.x = _6174.x;
            _30464.y = _6174.y;
            _30464.z = _6174.z;
            _30498 = _30464;
        }
        else
        {
            _30498 = _6142;
        }
        float4 _6184 = srcTex.read(uint2(int3((_3706 < _3705) ? _3727 : _3725, _3695, 0).xy), 0);
        float4 _30499;
        if (_6145)
        {
            float3 _6193 = fast::clamp(_6184.xyz, float3(0.0), float3(1.0));
            float3 _6216 = select(powr((_6193 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6193 * float3(0.077399380505084991455078125), _6193 <= float3(0.040449999272823333740234375));
            float4 _30472 = _6184;
            _30472.x = _6216.x;
            _30472.y = _6216.y;
            _30472.z = _6216.z;
            _30499 = _30472;
        }
        else
        {
            _30499 = _6184;
        }
        int _3751 = _3695 - 1;
        int _3753 = _3695 + 1;
        float4 _6226 = srcTex.read(uint2(int3(_3706, (_3695 > 0) ? _3751 : _3753, 0).xy), 0);
        float4 _30500;
        if (_6145)
        {
            float3 _6235 = fast::clamp(_6226.xyz, float3(0.0), float3(1.0));
            float3 _6258 = select(powr((_6235 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6235 * float3(0.077399380505084991455078125), _6235 <= float3(0.040449999272823333740234375));
            float4 _30479 = _6226;
            _30479.x = _6258.x;
            _30479.y = _6258.y;
            _30479.z = _6258.z;
            _30500 = _30479;
        }
        else
        {
            _30500 = _6226;
        }
        float4 _6268 = srcTex.read(uint2(int3(_3706, (_3695 < _3694) ? _3753 : _3751, 0).xy), 0);
        float4 _30501;
        if (_6145)
        {
            float3 _6277 = fast::clamp(_6268.xyz, float3(0.0), float3(1.0));
            float3 _6300 = select(powr((_6277 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6277 * float3(0.077399380505084991455078125), _6277 <= float3(0.040449999272823333740234375));
            float4 _30487 = _6268;
            _30487.x = _6300.x;
            _30487.y = _6300.y;
            _30487.z = _6300.z;
            _30501 = _30487;
        }
        else
        {
            _30501 = _6268;
        }
        float _3776 = dot(abs(_30498.xyz - _30499.xyz), float3(1.0));
        float _3781 = dot(abs(_30500.xyz - _30501.xyz), float3(1.0));
        float3 _3788 = _30498.xyz + _30499.xyz;
        _13615 = float4(select(select(((_3788 + _30500.xyz) + _30501.xyz) * 0.25, (_30500.xyz + _30501.xyz) * 0.5, bool3(_3781 < (_3776 * 0.800000011920928955078125))), _3788 * 0.5, bool3(_3776 < (_3781 * 0.800000011920928955078125))), 1.0);
        break;
    } while(false);
    float4 _30493 = _13615;
    _30493.w = 1.0;
    out._entryPointOutput = _30493;
    return out;
}
