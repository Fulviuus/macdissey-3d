// Generated from SR-Loom Converter.hlsl (MIT). Copyright (c) 2026 SR Loom contributors.
// Upstream d0b93f308d5aaf7c57fd02f5a3bd61402fe31f8b. See Resources/Licenses/SR-Loom-LICENSE.txt.
// Regenerate with scripts/translate-stereo-shaders.py.
#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wmissing-braces"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

template<typename T, size_t Num>
struct spvUnsafeArray
{
    T elements[Num ? Num : 1];

    thread T& operator [] (size_t pos) thread
    {
        return elements[pos];
    }
    constexpr const thread T& operator [] (size_t pos) const thread
    {
        return elements[pos];
    }

    device T& operator [] (size_t pos) device
    {
        return elements[pos];
    }
    constexpr const device T& operator [] (size_t pos) const device
    {
        return elements[pos];
    }

    constexpr const constant T& operator [] (size_t pos) const constant
    {
        return elements[pos];
    }

    threadgroup T& operator [] (size_t pos) threadgroup
    {
        return elements[pos];
    }
    constexpr const threadgroup T& operator [] (size_t pos) const threadgroup
    {
        return elements[pos];
    }
};

// Implementation of signed integer mod accurate to SPIR-V specification
template<typename Tx, typename Ty>
inline Tx spvSMod(Tx x, Ty y)
{
    Tx remainder = x - y * (x / y);
    return select(Tx(remainder + y), remainder, remainder == 0 || (x >= 0) == (y >= 0));
}

struct Params
{
    int g_format;
    int g_swap;
    float g_srcW;
    float g_srcH;
    int g_anaCombo;
    int g_anaMode;
    int g_pulfMode;
    int g_pulfEye;
    float g_ndTrans;
    float g_fpEyeFrac;
    float g_fpGapFrac;
    float g_convergence;
    char _m12_pad[16];
    float g_fpEyeAlign;
    int g_quiltCols;
    int g_quiltRows;
    int g_quiltLeftIdx;
    int g_quiltRightIdx;
    float g_paneW;
    float g_paneH;
    float g_quiltLBlend;
    float g_quiltRBlend;
    float g_vrYaw;
    float g_vrPitch;
    float g_vrZoom;
    int g_vrIs360;
    int g_vrIsSBS;
    char _m26_pad[4];
    float g_lvlToSrcX;
    float g_lvlToSrcY;
    float g_changeSkip;
    float g_srcDecode;
    float g_pairRefine;
};

constant float4 _13625 = {};
constant float _35925 = {};

struct main0_out
{
    float4 _entryPointOutput [[color(0)]];
};

struct main0_in
{
    float2 i_uv [[user(locn0)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant Params& _395 [[buffer(0)]], texture2d<float> srcTex [[texture(0)]], texture2d<float> anaTintTex [[texture(1)]], texture2d<float> anaBoxTex [[texture(2)]], texture2d<float> anaShiftTex [[texture(3)]], texture2d<float> dispTex [[texture(4)]], texture2d<float> srcQ [[texture(5)]], texture2d<float> changeTex [[texture(6)]], texture2d<float> anaBoxMapTex [[texture(7)]], texture2d<float> pairTex [[texture(8)]], texture2d<float> srcPrev [[texture(9)]], sampler samp [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 _13619;
    do
    {
        if (_395.g_format == 99)
        {
            float4 _13618;
            do
            {
                if (_395.g_srcDecode < 0.5)
                {
                    _13618 = srcTex.sample(samp, in.i_uv, level(0.0));
                    break;
                }
                uint2 _5052 = uint2(srcTex.get_width(), srcTex.get_height());
                uint _5054 = _5052.x;
                uint _5056 = _5052.y;
                float2 _5065 = (in.i_uv * float2(float(_5054), float(_5056))) - float2(0.5);
                int2 _5072 = int2(int(_5054), int(_5056)) - int2(1);
                float2 _5074 = rint(_5065);
                if (all(abs(_5065 - _5074) < float2(0.001953125)))
                {
                    float4 _5156 = srcTex.read(uint2(int3(clamp(int2(_5074), int2(0), _5072), 0).xy), 0);
                    float4 _36981;
                    if (_395.g_srcDecode > 0.5)
                    {
                        float3 _5165 = fast::clamp(_5156.xyz, float3(0.0), float3(1.0));
                        float3 _5188 = select(powr((_5165 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5165 * float3(0.077399380505084991455078125), _5165 <= float3(0.040449999272823333740234375));
                        float4 _32352 = _5156;
                        _32352.x = _5188.x;
                        _32352.y = _5188.y;
                        _32352.z = _5188.z;
                        _36981 = _32352;
                    }
                    else
                    {
                        _36981 = _5156;
                    }
                    _13618 = _36981;
                    break;
                }
                float2 _5092 = fract(_5065);
                int2 _5095 = int2(floor(_5065));
                int2 _5097 = clamp(_5095, int2(0), _5072);
                int2 _5104 = clamp(_5095 + int2(1), int2(0), _5072);
                int _5106 = _5097.x;
                float4 _5198 = srcTex.read(uint2(int3(_5106, _5097.y, 0).xy), 0);
                bool _5201 = _395.g_srcDecode > 0.5;
                float4 _36977;
                if (_5201)
                {
                    float3 _5207 = fast::clamp(_5198.xyz, float3(0.0), float3(1.0));
                    float3 _5230 = select(powr((_5207 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5207 * float3(0.077399380505084991455078125), _5207 <= float3(0.040449999272823333740234375));
                    float4 _32361 = _5198;
                    _32361.x = _5230.x;
                    _32361.y = _5230.y;
                    _32361.z = _5230.z;
                    _36977 = _32361;
                }
                else
                {
                    _36977 = _5198;
                }
                int _5112 = _5104.x;
                float4 _5240 = srcTex.read(uint2(int3(_5112, _5097.y, 0).xy), 0);
                float4 _36978;
                if (_5201)
                {
                    float3 _5249 = fast::clamp(_5240.xyz, float3(0.0), float3(1.0));
                    float3 _5272 = select(powr((_5249 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5249 * float3(0.077399380505084991455078125), _5249 <= float3(0.040449999272823333740234375));
                    float4 _32370 = _5240;
                    _32370.x = _5272.x;
                    _32370.y = _5272.y;
                    _32370.z = _5272.z;
                    _36978 = _32370;
                }
                else
                {
                    _36978 = _5240;
                }
                float4 _5282 = srcTex.read(uint2(int3(_5106, _5104.y, 0).xy), 0);
                float4 _36979;
                if (_5201)
                {
                    float3 _5291 = fast::clamp(_5282.xyz, float3(0.0), float3(1.0));
                    float3 _5314 = select(powr((_5291 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5291 * float3(0.077399380505084991455078125), _5291 <= float3(0.040449999272823333740234375));
                    float4 _32379 = _5282;
                    _32379.x = _5314.x;
                    _32379.y = _5314.y;
                    _32379.z = _5314.z;
                    _36979 = _32379;
                }
                else
                {
                    _36979 = _5282;
                }
                float4 _5324 = srcTex.read(uint2(int3(_5112, _5104.y, 0).xy), 0);
                float4 _36980;
                if (_5201)
                {
                    float3 _5333 = fast::clamp(_5324.xyz, float3(0.0), float3(1.0));
                    float3 _5356 = select(powr((_5333 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5333 * float3(0.077399380505084991455078125), _5333 <= float3(0.040449999272823333740234375));
                    float4 _32388 = _5324;
                    _32388.x = _5356.x;
                    _32388.y = _5356.y;
                    _32388.z = _5356.z;
                    _36980 = _32388;
                }
                else
                {
                    _36980 = _5324;
                }
                float4 _5133 = float4(_5092.x);
                _13618 = mix(mix(_36977, _36978, _5133), mix(_36979, _36980, _5133), float4(_5092.y));
                break;
            } while(false);
            _13619 = _13618;
            break;
        }
        bool _3562 = in.i_uv.x >= 0.5;
        float _3571 = _3562 ? ((in.i_uv.x - 0.5) * 2.0) : (in.i_uv.x * 2.0);
        float2 _3574 = float2(_3571, in.i_uv.y);
        bool _13391;
        if (_395.g_swap != int(0u))
        {
            _13391 = !_3562;
        }
        else
        {
            _13391 = _3562;
        }
        float _3592 = _3571 + (_13391 ? (-_395.g_convergence) : _395.g_convergence);
        _3574.x = _3592;
        if (_395.g_format == 1)
        {
            float _3602 = in.i_uv.y * 0.5;
            float2 _3608 = float2(_3592, _13391 ? (0.5 + _3602) : _3602);
            float4 _13617;
            do
            {
                if (_395.g_srcDecode < 0.5)
                {
                    _13617 = srcTex.sample(samp, _3608, level(0.0));
                    break;
                }
                uint2 _5400 = uint2(srcTex.get_width(), srcTex.get_height());
                uint _5402 = _5400.x;
                uint _5404 = _5400.y;
                float2 _5413 = (_3608 * float2(float(_5402), float(_5404))) - float2(0.5);
                int2 _5420 = int2(int(_5402), int(_5404)) - int2(1);
                float2 _5422 = rint(_5413);
                if (all(abs(_5413 - _5422) < float2(0.001953125)))
                {
                    float4 _5504 = srcTex.read(uint2(int3(clamp(int2(_5422), int2(0), _5420), 0).xy), 0);
                    float4 _36976;
                    if (_395.g_srcDecode > 0.5)
                    {
                        float3 _5513 = fast::clamp(_5504.xyz, float3(0.0), float3(1.0));
                        float3 _5536 = select(powr((_5513 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5513 * float3(0.077399380505084991455078125), _5513 <= float3(0.040449999272823333740234375));
                        float4 _35827 = _5504;
                        _35827.x = _5536.x;
                        _35827.y = _5536.y;
                        _35827.z = _5536.z;
                        _36976 = _35827;
                    }
                    else
                    {
                        _36976 = _5504;
                    }
                    _13617 = _36976;
                    break;
                }
                float2 _5440 = fract(_5413);
                int2 _5443 = int2(floor(_5413));
                int2 _5445 = clamp(_5443, int2(0), _5420);
                int2 _5452 = clamp(_5443 + int2(1), int2(0), _5420);
                int _5454 = _5445.x;
                float4 _5546 = srcTex.read(uint2(int3(_5454, _5445.y, 0).xy), 0);
                bool _5549 = _395.g_srcDecode > 0.5;
                float4 _36972;
                if (_5549)
                {
                    float3 _5555 = fast::clamp(_5546.xyz, float3(0.0), float3(1.0));
                    float3 _5578 = select(powr((_5555 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5555 * float3(0.077399380505084991455078125), _5555 <= float3(0.040449999272823333740234375));
                    float4 _35836 = _5546;
                    _35836.x = _5578.x;
                    _35836.y = _5578.y;
                    _35836.z = _5578.z;
                    _36972 = _35836;
                }
                else
                {
                    _36972 = _5546;
                }
                int _5460 = _5452.x;
                float4 _5588 = srcTex.read(uint2(int3(_5460, _5445.y, 0).xy), 0);
                float4 _36973;
                if (_5549)
                {
                    float3 _5597 = fast::clamp(_5588.xyz, float3(0.0), float3(1.0));
                    float3 _5620 = select(powr((_5597 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5597 * float3(0.077399380505084991455078125), _5597 <= float3(0.040449999272823333740234375));
                    float4 _35845 = _5588;
                    _35845.x = _5620.x;
                    _35845.y = _5620.y;
                    _35845.z = _5620.z;
                    _36973 = _35845;
                }
                else
                {
                    _36973 = _5588;
                }
                float4 _5630 = srcTex.read(uint2(int3(_5454, _5452.y, 0).xy), 0);
                float4 _36974;
                if (_5549)
                {
                    float3 _5639 = fast::clamp(_5630.xyz, float3(0.0), float3(1.0));
                    float3 _5662 = select(powr((_5639 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5639 * float3(0.077399380505084991455078125), _5639 <= float3(0.040449999272823333740234375));
                    float4 _35854 = _5630;
                    _35854.x = _5662.x;
                    _35854.y = _5662.y;
                    _35854.z = _5662.z;
                    _36974 = _35854;
                }
                else
                {
                    _36974 = _5630;
                }
                float4 _5672 = srcTex.read(uint2(int3(_5460, _5452.y, 0).xy), 0);
                float4 _36975;
                if (_5549)
                {
                    float3 _5681 = fast::clamp(_5672.xyz, float3(0.0), float3(1.0));
                    float3 _5704 = select(powr((_5681 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5681 * float3(0.077399380505084991455078125), _5681 <= float3(0.040449999272823333740234375));
                    float4 _35863 = _5672;
                    _35863.x = _5704.x;
                    _35863.y = _5704.y;
                    _35863.z = _5704.z;
                    _36975 = _35863;
                }
                else
                {
                    _36975 = _5672;
                }
                float4 _5481 = float4(_5440.x);
                _13617 = mix(mix(_36972, _36973, _5481), mix(_36974, _36975, _5481), float4(_5440.y));
                break;
            } while(false);
            _13619 = _13617;
            break;
        }
        else
        {
            if (_395.g_format == 3)
            {
                float2 _3634 = float2(_3592, (((floor(in.i_uv.y * (_395.g_srcH * 0.5)) * 2.0) + float(_13391)) + 0.5) / _395.g_srcH);
                float4 _13616;
                do
                {
                    if (_395.g_srcDecode < 0.5)
                    {
                        _13616 = srcTex.sample(samp, _3634, level(0.0));
                        break;
                    }
                    uint2 _5748 = uint2(srcTex.get_width(), srcTex.get_height());
                    uint _5750 = _5748.x;
                    uint _5752 = _5748.y;
                    float2 _5761 = (_3634 * float2(float(_5750), float(_5752))) - float2(0.5);
                    int2 _5768 = int2(int(_5750), int(_5752)) - int2(1);
                    float2 _5770 = rint(_5761);
                    if (all(abs(_5761 - _5770) < float2(0.001953125)))
                    {
                        float4 _5852 = srcTex.read(uint2(int3(clamp(int2(_5770), int2(0), _5768), 0).xy), 0);
                        float4 _36971;
                        if (_395.g_srcDecode > 0.5)
                        {
                            float3 _5861 = fast::clamp(_5852.xyz, float3(0.0), float3(1.0));
                            float3 _5884 = select(powr((_5861 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5861 * float3(0.077399380505084991455078125), _5861 <= float3(0.040449999272823333740234375));
                            float4 _35776 = _5852;
                            _35776.x = _5884.x;
                            _35776.y = _5884.y;
                            _35776.z = _5884.z;
                            _36971 = _35776;
                        }
                        else
                        {
                            _36971 = _5852;
                        }
                        _13616 = _36971;
                        break;
                    }
                    float2 _5788 = fract(_5761);
                    int2 _5791 = int2(floor(_5761));
                    int2 _5793 = clamp(_5791, int2(0), _5768);
                    int2 _5800 = clamp(_5791 + int2(1), int2(0), _5768);
                    int _5802 = _5793.x;
                    float4 _5894 = srcTex.read(uint2(int3(_5802, _5793.y, 0).xy), 0);
                    bool _5897 = _395.g_srcDecode > 0.5;
                    float4 _36967;
                    if (_5897)
                    {
                        float3 _5903 = fast::clamp(_5894.xyz, float3(0.0), float3(1.0));
                        float3 _5926 = select(powr((_5903 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5903 * float3(0.077399380505084991455078125), _5903 <= float3(0.040449999272823333740234375));
                        float4 _35785 = _5894;
                        _35785.x = _5926.x;
                        _35785.y = _5926.y;
                        _35785.z = _5926.z;
                        _36967 = _35785;
                    }
                    else
                    {
                        _36967 = _5894;
                    }
                    int _5808 = _5800.x;
                    float4 _5936 = srcTex.read(uint2(int3(_5808, _5793.y, 0).xy), 0);
                    float4 _36968;
                    if (_5897)
                    {
                        float3 _5945 = fast::clamp(_5936.xyz, float3(0.0), float3(1.0));
                        float3 _5968 = select(powr((_5945 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5945 * float3(0.077399380505084991455078125), _5945 <= float3(0.040449999272823333740234375));
                        float4 _35794 = _5936;
                        _35794.x = _5968.x;
                        _35794.y = _5968.y;
                        _35794.z = _5968.z;
                        _36968 = _35794;
                    }
                    else
                    {
                        _36968 = _5936;
                    }
                    float4 _5978 = srcTex.read(uint2(int3(_5802, _5800.y, 0).xy), 0);
                    float4 _36969;
                    if (_5897)
                    {
                        float3 _5987 = fast::clamp(_5978.xyz, float3(0.0), float3(1.0));
                        float3 _6010 = select(powr((_5987 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _5987 * float3(0.077399380505084991455078125), _5987 <= float3(0.040449999272823333740234375));
                        float4 _35803 = _5978;
                        _35803.x = _6010.x;
                        _35803.y = _6010.y;
                        _35803.z = _6010.z;
                        _36969 = _35803;
                    }
                    else
                    {
                        _36969 = _5978;
                    }
                    float4 _6020 = srcTex.read(uint2(int3(_5808, _5800.y, 0).xy), 0);
                    float4 _36970;
                    if (_5897)
                    {
                        float3 _6029 = fast::clamp(_6020.xyz, float3(0.0), float3(1.0));
                        float3 _6052 = select(powr((_6029 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6029 * float3(0.077399380505084991455078125), _6029 <= float3(0.040449999272823333740234375));
                        float4 _35812 = _6020;
                        _35812.x = _6052.x;
                        _35812.y = _6052.y;
                        _35812.z = _6052.z;
                        _36970 = _35812;
                    }
                    else
                    {
                        _36970 = _6020;
                    }
                    float4 _5829 = float4(_5788.x);
                    _13616 = mix(mix(_36967, _36968, _5829), mix(_36969, _36970, _5829), float4(_5788.y));
                    break;
                } while(false);
                _13619 = _13616;
                break;
            }
            else
            {
                if (_395.g_format == 4)
                {
                    float4 _6062 = srcTex.read(uint2(int3(clamp((int(floor(_3592 * (_395.g_srcW * 0.5))) * 2) + int(_13391), 0, int(_395.g_srcW) - 1), clamp(int(floor(in.i_uv.y * _395.g_srcH)), 0, int(_395.g_srcH) - 1), 0).xy), 0);
                    float4 _36966;
                    if (_395.g_srcDecode > 0.5)
                    {
                        float3 _6071 = fast::clamp(_6062.xyz, float3(0.0), float3(1.0));
                        float3 _6094 = select(powr((_6071 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6071 * float3(0.077399380505084991455078125), _6071 <= float3(0.040449999272823333740234375));
                        float4 _35765 = _6062;
                        _35765.x = _6094.x;
                        _35765.y = _6094.y;
                        _35765.z = _6094.z;
                        _36966 = _35765;
                    }
                    else
                    {
                        _36966 = _6062;
                    }
                    _13619 = _36966;
                    break;
                }
                else
                {
                    if (_395.g_format == 5)
                    {
                        int _3698 = int(_395.g_srcH) - 1;
                        int _3699 = clamp(int(floor(in.i_uv.y * _395.g_srcH)), 0, _3698);
                        int _3709 = int(_395.g_srcW) - 1;
                        int _3710 = clamp(int(floor(_3592 * _395.g_srcW)), 0, _3709);
                        if ((((_3710 + _3699) + int(_13391)) & 1) == 0)
                        {
                            float4 _6104 = srcTex.read(uint2(int3(_3710, _3699, 0).xy), 0);
                            float4 _36965;
                            if (_395.g_srcDecode > 0.5)
                            {
                                float3 _6113 = fast::clamp(_6104.xyz, float3(0.0), float3(1.0));
                                float3 _6136 = select(powr((_6113 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6113 * float3(0.077399380505084991455078125), _6113 <= float3(0.040449999272823333740234375));
                                float4 _35724 = _6104;
                                _35724.x = _6136.x;
                                _35724.y = _6136.y;
                                _35724.z = _6136.z;
                                _36965 = _35724;
                            }
                            else
                            {
                                _36965 = _6104;
                            }
                            _13619 = _36965;
                            break;
                        }
                        int _3729 = _3710 - 1;
                        int _3731 = _3710 + 1;
                        float4 _6146 = srcTex.read(uint2(int3((_3710 > 0) ? _3729 : _3731, _3699, 0).xy), 0);
                        bool _6149 = _395.g_srcDecode > 0.5;
                        float4 _36961;
                        if (_6149)
                        {
                            float3 _6155 = fast::clamp(_6146.xyz, float3(0.0), float3(1.0));
                            float3 _6178 = select(powr((_6155 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6155 * float3(0.077399380505084991455078125), _6155 <= float3(0.040449999272823333740234375));
                            float4 _35731 = _6146;
                            _35731.x = _6178.x;
                            _35731.y = _6178.y;
                            _35731.z = _6178.z;
                            _36961 = _35731;
                        }
                        else
                        {
                            _36961 = _6146;
                        }
                        float4 _6188 = srcTex.read(uint2(int3((_3710 < _3709) ? _3731 : _3729, _3699, 0).xy), 0);
                        float4 _36962;
                        if (_6149)
                        {
                            float3 _6197 = fast::clamp(_6188.xyz, float3(0.0), float3(1.0));
                            float3 _6220 = select(powr((_6197 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6197 * float3(0.077399380505084991455078125), _6197 <= float3(0.040449999272823333740234375));
                            float4 _35739 = _6188;
                            _35739.x = _6220.x;
                            _35739.y = _6220.y;
                            _35739.z = _6220.z;
                            _36962 = _35739;
                        }
                        else
                        {
                            _36962 = _6188;
                        }
                        int _3755 = _3699 - 1;
                        int _3757 = _3699 + 1;
                        float4 _6230 = srcTex.read(uint2(int3(_3710, (_3699 > 0) ? _3755 : _3757, 0).xy), 0);
                        float4 _36963;
                        if (_6149)
                        {
                            float3 _6239 = fast::clamp(_6230.xyz, float3(0.0), float3(1.0));
                            float3 _6262 = select(powr((_6239 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6239 * float3(0.077399380505084991455078125), _6239 <= float3(0.040449999272823333740234375));
                            float4 _35746 = _6230;
                            _35746.x = _6262.x;
                            _35746.y = _6262.y;
                            _35746.z = _6262.z;
                            _36963 = _35746;
                        }
                        else
                        {
                            _36963 = _6230;
                        }
                        float4 _6272 = srcTex.read(uint2(int3(_3710, (_3699 < _3698) ? _3757 : _3755, 0).xy), 0);
                        float4 _36964;
                        if (_6149)
                        {
                            float3 _6281 = fast::clamp(_6272.xyz, float3(0.0), float3(1.0));
                            float3 _6304 = select(powr((_6281 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6281 * float3(0.077399380505084991455078125), _6281 <= float3(0.040449999272823333740234375));
                            float4 _35754 = _6272;
                            _35754.x = _6304.x;
                            _35754.y = _6304.y;
                            _35754.z = _6304.z;
                            _36964 = _35754;
                        }
                        else
                        {
                            _36964 = _6272;
                        }
                        float _3780 = dot(abs(_36961.xyz - _36962.xyz), float3(1.0));
                        float _3785 = dot(abs(_36963.xyz - _36964.xyz), float3(1.0));
                        float3 _3792 = _36961.xyz + _36962.xyz;
                        _13619 = float4(select(select(((_3792 + _36963.xyz) + _36964.xyz) * 0.25, (_36963.xyz + _36964.xyz) * 0.5, bool3(_3785 < (_3780 * 0.800000011920928955078125))), _3792 * 0.5, bool3(_3780 < (_3785 * 0.800000011920928955078125))), 1.0);
                        break;
                    }
                    else
                    {
                        if (_395.g_format == 2)
                        {
                            if (_395.g_changeSkip > 0.5)
                            {
                                uint2 _3828 = uint2(changeTex.get_width(), changeTex.get_height());
                                uint _3830 = _3828.x;
                                if ((_3830 > 0u) && (changeTex.read(uint2(int3(clamp(int2((_3574 * float2(_395.g_srcW, _395.g_srcH)) * float2(0.0625)), int2(0), int2(int(_3830), int(_3828.y)) - int2(1)), 0).xy), 0).x < 0.5))
                                {
                                    discard_fragment();
                                }
                            }
                            float _6337;
                            bool _6338;
                            int _3888 = int(_13391);
                            float4 _13446;
                            do
                            {
                                _6337 = _395.g_srcDecode;
                                _6338 = _6337 < 0.5;
                                if (_6338)
                                {
                                    _13446 = srcTex.sample(samp, _3574, level(0.0));
                                    break;
                                }
                                uint2 _6348 = uint2(srcTex.get_width(), srcTex.get_height());
                                uint _6350 = _6348.x;
                                uint _6352 = _6348.y;
                                float2 _6361 = (_3574 * float2(float(_6350), float(_6352))) - float2(0.5);
                                int2 _6368 = int2(int(_6350), int(_6352)) - int2(1);
                                float2 _6370 = rint(_6361);
                                if (all(abs(_6361 - _6370) < float2(0.001953125)))
                                {
                                    float4 _6452 = srcTex.read(uint2(int3(clamp(int2(_6370), int2(0), _6368), 0).xy), 0);
                                    float4 _36135;
                                    if (_6337 > 0.5)
                                    {
                                        float3 _6461 = fast::clamp(_6452.xyz, float3(0.0), float3(1.0));
                                        float3 _6484 = select(powr((_6461 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6461 * float3(0.077399380505084991455078125), _6461 <= float3(0.040449999272823333740234375));
                                        float4 _33358 = _6452;
                                        _33358.x = _6484.x;
                                        _33358.y = _6484.y;
                                        _33358.z = _6484.z;
                                        _36135 = _33358;
                                    }
                                    else
                                    {
                                        _36135 = _6452;
                                    }
                                    _13446 = _36135;
                                    break;
                                }
                                float2 _6388 = fract(_6361);
                                int2 _6391 = int2(floor(_6361));
                                int2 _6393 = clamp(_6391, int2(0), _6368);
                                int2 _6400 = clamp(_6391 + int2(1), int2(0), _6368);
                                int _6402 = _6393.x;
                                float4 _6494 = srcTex.read(uint2(int3(_6402, _6393.y, 0).xy), 0);
                                bool _6497 = _6337 > 0.5;
                                float4 _36131;
                                if (_6497)
                                {
                                    float3 _6503 = fast::clamp(_6494.xyz, float3(0.0), float3(1.0));
                                    float3 _6526 = select(powr((_6503 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6503 * float3(0.077399380505084991455078125), _6503 <= float3(0.040449999272823333740234375));
                                    float4 _33367 = _6494;
                                    _33367.x = _6526.x;
                                    _33367.y = _6526.y;
                                    _33367.z = _6526.z;
                                    _36131 = _33367;
                                }
                                else
                                {
                                    _36131 = _6494;
                                }
                                int _6408 = _6400.x;
                                float4 _6536 = srcTex.read(uint2(int3(_6408, _6393.y, 0).xy), 0);
                                float4 _36132;
                                if (_6497)
                                {
                                    float3 _6545 = fast::clamp(_6536.xyz, float3(0.0), float3(1.0));
                                    float3 _6568 = select(powr((_6545 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6545 * float3(0.077399380505084991455078125), _6545 <= float3(0.040449999272823333740234375));
                                    float4 _33376 = _6536;
                                    _33376.x = _6568.x;
                                    _33376.y = _6568.y;
                                    _33376.z = _6568.z;
                                    _36132 = _33376;
                                }
                                else
                                {
                                    _36132 = _6536;
                                }
                                float4 _6578 = srcTex.read(uint2(int3(_6402, _6400.y, 0).xy), 0);
                                float4 _36133;
                                if (_6497)
                                {
                                    float3 _6587 = fast::clamp(_6578.xyz, float3(0.0), float3(1.0));
                                    float3 _6610 = select(powr((_6587 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6587 * float3(0.077399380505084991455078125), _6587 <= float3(0.040449999272823333740234375));
                                    float4 _33385 = _6578;
                                    _33385.x = _6610.x;
                                    _33385.y = _6610.y;
                                    _33385.z = _6610.z;
                                    _36133 = _33385;
                                }
                                else
                                {
                                    _36133 = _6578;
                                }
                                float4 _6620 = srcTex.read(uint2(int3(_6408, _6400.y, 0).xy), 0);
                                float4 _36134;
                                if (_6497)
                                {
                                    float3 _6629 = fast::clamp(_6620.xyz, float3(0.0), float3(1.0));
                                    float3 _6652 = select(powr((_6629 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6629 * float3(0.077399380505084991455078125), _6629 <= float3(0.040449999272823333740234375));
                                    float4 _33394 = _6620;
                                    _33394.x = _6652.x;
                                    _33394.y = _6652.y;
                                    _33394.z = _6652.z;
                                    _36134 = _33394;
                                }
                                else
                                {
                                    _36134 = _6620;
                                }
                                float4 _6429 = float4(_6388.x);
                                _13446 = mix(mix(_36131, _36132, _6429), mix(_36133, _36134, _6429), float4(_6388.y));
                                break;
                            } while(false);
                            bool _3894 = _395.g_anaMode == 5;
                            if (_3894 && (anaTintTex.read(uint2(int2(0)), 0).w > 0.5))
                            {
                                float3 _13615;
                                do
                                {
                                    float3 _6673 = fast::clamp(_13446.xyz, float3(0.0), float3(1.0));
                                    float3 _6744 = select((powr(_6673, float3(0.4166666567325592041015625)) * 1.05499994754791259765625) - float3(0.054999999701976776123046875), _6673 * 12.9200000762939453125, _6673 <= float3(0.003130800090730190277099609375));
                                    float3 _6655 = _6744;
                                    bool _6680 = _395.g_anaCombo == 4;
                                    int _6682 = (_395.g_anaCombo == 3) ? 1 : (_6680 ? 2 : 0);
                                    if (_3888 == int(_6680))
                                    {
                                        float _6751 = fast::clamp(_6655[_6682], 0.0, 1.0) * 255.0;
                                        int _6754 = min(int(_6751), 254);
                                        float3 _6696 = mix(anaTintTex.read(uint2(int3(_6754, 0, 0).xy), 0), anaTintTex.read(uint2(int3(_6754 + 1, 0, 0).xy), 0), float4(_6751 - float(_6754))).xyz;
                                        _13615 = select(powr((_6696 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6696 * float3(0.077399380505084991455078125), _6696 <= float3(0.040449999272823333740234375));
                                        break;
                                    }
                                    float _6803 = fast::clamp((dot(_6744, float3(1.0)) - _6655[_6682]) * 0.5, 0.0, 1.0) * 255.0;
                                    int _6806 = min(int(_6803), 254);
                                    float4 _6834 = mix(anaTintTex.read(uint2(int3(_6806, 1, 0).xy), 0), anaTintTex.read(uint2(int3(_6806 + 1, 1, 0).xy), 0), float4(_6803 - float(_6806)));
                                    float _6710 = _6834.x;
                                    float3 _6729 = float3((_6682 == 0) ? _6710 : _6655.x, (_6682 == 1) ? _6710 : _6655.y, (_6682 == 2) ? _6710 : _6655.z);
                                    _13615 = select(powr((_6729 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6729 * float3(0.077399380505084991455078125), _6729 <= float3(0.040449999272823333740234375));
                                    break;
                                } while(false);
                                _13619 = float4(_13615, 1.0);
                                break;
                            }
                            bool _3914 = _395.g_anaMode == 4;
                            if (_3914)
                            {
                                uint2 _3918 = uint2(anaBoxMapTex.get_width(), anaBoxMapTex.get_height());
                                uint _3920 = _3918.x;
                                float2 _3384 = select(float2(0.0), anaBoxMapTex.read(uint2(int3(min(int2((_3574 * float2(_395.g_srcW, _395.g_srcH)) * float2(0.0625)), (int2(int(_3920), int(_3918.y)) - int2(1))), 0).xy), 0).xy, bool2(_3920 > 0u));
                                bool _13453;
                                float4 _13620;
                                int _13447 = 0;
                                for (;;)
                                {
                                    if (_13447 < 2)
                                    {
                                        int _3983 = int(_3384[_13447]) - 1;
                                        if (_3983 < 0)
                                        {
                                            _13620 = _13625;
                                            _13453 = false;
                                            break;
                                        }
                                        int _6855 = 2 * _3983;
                                        float _6877 = (anaShiftTex.read(uint2(int3(_3983, 0, 0).xy), 0).x * 16.0) / _395.g_srcH;
                                        float4 _6882 = anaBoxTex.read(uint2(int3(1 + _6855, 0, 0).xy), 0) + float4(0.0, _6877, 0.0, _6877);
                                        if ((((_3592 < _6882.x) || (_3592 > _6882.z)) || (in.i_uv.y < _6882.y)) || (in.i_uv.y > _6882.w))
                                        {
                                            int _4088 = _13447 + 1;
                                            _13447 = _4088;
                                            continue;
                                        }
                                        float4 _4026 = anaBoxTex.read(uint2(int3(2 + _6855, 0, 0).xy), 0);
                                        float _4028 = _4026.x;
                                        if (_4028 > 1.5)
                                        {
                                            float3 _4034 = fast::clamp(_13446.xyz, float3(0.0), float3(1.0));
                                            float3 _6894 = select((powr(_4034, float3(0.4166666567325592041015625)) * 1.05499994754791259765625) - float3(0.054999999701976776123046875), _4034 * 12.9200000762939453125, _4034 <= float3(0.003130800090730190277099609375));
                                            float _4037 = _6894.x;
                                            float _4039 = _6894.y;
                                            float _4042 = _6894.z;
                                            if ((fast::max(fast::max(_4037, _4039), _4042) - fast::min(fast::min(_4037, _4039), _4042)) < 0.011764706112444400787353515625)
                                            {
                                                _13620 = float4(_13446.xyz, 1.0);
                                                _13453 = true;
                                                break;
                                            }
                                            int _4063 = int(_4026.y);
                                            float3 _13451;
                                            do
                                            {
                                                float3 _6897 = _6894;
                                                bool _6922 = _395.g_anaCombo == 4;
                                                int _6924 = (_395.g_anaCombo == 3) ? 1 : (_6922 ? 2 : 0);
                                                if (_3888 == int(_6922))
                                                {
                                                    float _6993 = fast::clamp(_6897[_6924], 0.0, 1.0) * 255.0;
                                                    int _6996 = min(int(_6993), 254);
                                                    float3 _6938 = mix(anaTintTex.read(uint2(int3(_6996, _4063, 0).xy), 0), anaTintTex.read(uint2(int3(_6996 + 1, _4063, 0).xy), 0), float4(_6993 - float(_6996))).xyz;
                                                    _13451 = select(powr((_6938 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6938 * float3(0.077399380505084991455078125), _6938 <= float3(0.040449999272823333740234375));
                                                    break;
                                                }
                                                int _6949 = _4063 + 1;
                                                float _7045 = fast::clamp((dot(_6894, float3(1.0)) - _6897[_6924]) * 0.5, 0.0, 1.0) * 255.0;
                                                int _7048 = min(int(_7045), 254);
                                                float4 _7076 = mix(anaTintTex.read(uint2(int3(_7048, _6949, 0).xy), 0), anaTintTex.read(uint2(int3(_7048 + 1, _6949, 0).xy), 0), float4(_7045 - float(_7048)));
                                                float _6952 = _7076.x;
                                                float3 _6971 = float3((_6924 == 0) ? _6952 : _6897.x, (_6924 == 1) ? _6952 : _6897.y, (_6924 == 2) ? _6952 : _6897.z);
                                                _13451 = select(powr((_6971 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _6971 * float3(0.077399380505084991455078125), _6971 <= float3(0.040449999272823333740234375));
                                                break;
                                            } while(false);
                                            _13620 = float4(_13451, 1.0);
                                            _13453 = true;
                                            break;
                                        }
                                        if (_4028 > 0.5)
                                        {
                                            float _13448;
                                            do
                                            {
                                                if (_395.g_anaCombo == 0)
                                                {
                                                    _13448 = (!_13391) ? _13446.x : ((_13446.y + _13446.z) * 0.5);
                                                    break;
                                                }
                                                if (_395.g_anaCombo == 1)
                                                {
                                                    _13448 = (!_13391) ? _13446.x : _13446.y;
                                                    break;
                                                }
                                                if (_395.g_anaCombo == 2)
                                                {
                                                    _13448 = (!_13391) ? _13446.x : _13446.z;
                                                    break;
                                                }
                                                if (_395.g_anaCombo == 3)
                                                {
                                                    _13448 = (!_13391) ? _13446.y : ((_13446.x + _13446.z) * 0.5);
                                                    break;
                                                }
                                                if (_395.g_anaCombo == 4)
                                                {
                                                    _13448 = (!_13391) ? ((_13446.x + _13446.y) * 0.5) : _13446.z;
                                                    break;
                                                }
                                                _13448 = (!_13391) ? ((_13446.y + _13446.z) * 0.5) : ((_13446.x + _13446.z) * 0.5);
                                                break;
                                            } while(false);
                                            _13620 = float4(_13448, _13448, _13448, 1.0);
                                            _13453 = true;
                                            break;
                                        }
                                        int _4088 = _13447 + 1;
                                        _13447 = _4088;
                                        continue;
                                    }
                                    else
                                    {
                                        _13620 = _13625;
                                        _13453 = false;
                                        break;
                                    }
                                }
                                if (_13453)
                                {
                                    _13619 = _13620;
                                    break;
                                }
                            }
                            if (_3914)
                            {
                                float _4101 = 1.0 / _395.g_srcW;
                                float _4104 = 1.0 / _395.g_srcH;
                                float2 _4138 = float2(_4101, _4104);
                                float2 _4140 = _3574 + (float2(-3.0) * _4138);
                                float4 _13601;
                                do
                                {
                                    if (_6338)
                                    {
                                        _13601 = srcTex.sample(samp, _4140, level(0.0));
                                        break;
                                    }
                                    uint2 _7383 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _7385 = _7383.x;
                                    uint _7387 = _7383.y;
                                    float2 _7396 = (_4140 * float2(float(_7385), float(_7387))) - float2(0.5);
                                    int2 _7403 = int2(int(_7385), int(_7387)) - int2(1);
                                    float2 _7405 = rint(_7396);
                                    if (all(abs(_7396 - _7405) < float2(0.001953125)))
                                    {
                                        float4 _7487 = srcTex.read(uint2(int3(clamp(int2(_7405), int2(0), _7403), 0).xy), 0);
                                        float4 _36246;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _7496 = fast::clamp(_7487.xyz, float3(0.0), float3(1.0));
                                            float3 _7519 = select(powr((_7496 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _7496 * float3(0.077399380505084991455078125), _7496 <= float3(0.040449999272823333740234375));
                                            float4 _33446 = _7487;
                                            _33446.x = _7519.x;
                                            _33446.y = _7519.y;
                                            _33446.z = _7519.z;
                                            _36246 = _33446;
                                        }
                                        else
                                        {
                                            _36246 = _7487;
                                        }
                                        _13601 = _36246;
                                        break;
                                    }
                                    float2 _7423 = fract(_7396);
                                    int2 _7426 = int2(floor(_7396));
                                    int2 _7428 = clamp(_7426, int2(0), _7403);
                                    int2 _7435 = clamp(_7426 + int2(1), int2(0), _7403);
                                    int _7437 = _7428.x;
                                    float4 _7529 = srcTex.read(uint2(int3(_7437, _7428.y, 0).xy), 0);
                                    bool _7532 = _6337 > 0.5;
                                    float4 _36233;
                                    if (_7532)
                                    {
                                        float3 _7538 = fast::clamp(_7529.xyz, float3(0.0), float3(1.0));
                                        float3 _7561 = select(powr((_7538 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _7538 * float3(0.077399380505084991455078125), _7538 <= float3(0.040449999272823333740234375));
                                        float4 _33455 = _7529;
                                        _33455.x = _7561.x;
                                        _33455.y = _7561.y;
                                        _33455.z = _7561.z;
                                        _36233 = _33455;
                                    }
                                    else
                                    {
                                        _36233 = _7529;
                                    }
                                    int _7443 = _7435.x;
                                    float4 _7571 = srcTex.read(uint2(int3(_7443, _7428.y, 0).xy), 0);
                                    float4 _36236;
                                    if (_7532)
                                    {
                                        float3 _7580 = fast::clamp(_7571.xyz, float3(0.0), float3(1.0));
                                        float3 _7603 = select(powr((_7580 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _7580 * float3(0.077399380505084991455078125), _7580 <= float3(0.040449999272823333740234375));
                                        float4 _33464 = _7571;
                                        _33464.x = _7603.x;
                                        _33464.y = _7603.y;
                                        _33464.z = _7603.z;
                                        _36236 = _33464;
                                    }
                                    else
                                    {
                                        _36236 = _7571;
                                    }
                                    float4 _7613 = srcTex.read(uint2(int3(_7437, _7435.y, 0).xy), 0);
                                    float4 _36239;
                                    if (_7532)
                                    {
                                        float3 _7622 = fast::clamp(_7613.xyz, float3(0.0), float3(1.0));
                                        float3 _7645 = select(powr((_7622 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _7622 * float3(0.077399380505084991455078125), _7622 <= float3(0.040449999272823333740234375));
                                        float4 _33473 = _7613;
                                        _33473.x = _7645.x;
                                        _33473.y = _7645.y;
                                        _33473.z = _7645.z;
                                        _36239 = _33473;
                                    }
                                    else
                                    {
                                        _36239 = _7613;
                                    }
                                    float4 _7655 = srcTex.read(uint2(int3(_7443, _7435.y, 0).xy), 0);
                                    float4 _36241;
                                    if (_7532)
                                    {
                                        float3 _7664 = fast::clamp(_7655.xyz, float3(0.0), float3(1.0));
                                        float3 _7687 = select(powr((_7664 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _7664 * float3(0.077399380505084991455078125), _7664 <= float3(0.040449999272823333740234375));
                                        float4 _33482 = _7655;
                                        _33482.x = _7687.x;
                                        _33482.y = _7687.y;
                                        _33482.z = _7687.z;
                                        _36241 = _33482;
                                    }
                                    else
                                    {
                                        _36241 = _7655;
                                    }
                                    float4 _7464 = float4(_7423.x);
                                    _13601 = mix(mix(_36233, _36236, _7464), mix(_36239, _36241, _7464), float4(_7423.y));
                                    break;
                                } while(false);
                                float2 _21626 = _3574 + (float2(0.0, -3.0) * _4138);
                                float4 _21863;
                                do
                                {
                                    if (_6338)
                                    {
                                        _21863 = srcTex.sample(samp, _21626, level(0.0));
                                        break;
                                    }
                                    uint2 _21638 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _21640 = _21638.x;
                                    uint _21642 = _21638.y;
                                    float2 _21648 = (_21626 * float2(float(_21640), float(_21642))) - float2(0.5);
                                    int2 _21653 = int2(int(_21640), int(_21642)) - int2(1);
                                    float2 _21654 = rint(_21648);
                                    if (all(abs(_21648 - _21654) < float2(0.001953125)))
                                    {
                                        float4 _21669 = srcTex.read(uint2(int3(clamp(int2(_21654), int2(0), _21653), 0).xy), 0);
                                        float4 _36266;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _21678 = fast::clamp(_21669.xyz, float3(0.0), float3(1.0));
                                            float3 _21687 = select(powr((_21678 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _21678 * float3(0.077399380505084991455078125), _21678 <= float3(0.040449999272823333740234375));
                                            float4 _33504 = _21669;
                                            _33504.x = _21687.x;
                                            _33504.y = _21687.y;
                                            _33504.z = _21687.z;
                                            _36266 = _33504;
                                        }
                                        else
                                        {
                                            _36266 = _21669;
                                        }
                                        _21863 = _36266;
                                        break;
                                    }
                                    float2 _21697 = fract(_21648);
                                    int2 _21699 = int2(floor(_21648));
                                    int2 _21700 = clamp(_21699, int2(0), _21653);
                                    int2 _21705 = clamp(_21699 + int2(1), int2(0), _21653);
                                    int _21707 = _21700.x;
                                    float4 _21715 = srcTex.read(uint2(int3(_21707, _21700.y, 0).xy), 0);
                                    bool _21718 = _6337 > 0.5;
                                    float4 _36253;
                                    if (_21718)
                                    {
                                        float3 _21724 = fast::clamp(_21715.xyz, float3(0.0), float3(1.0));
                                        float3 _21733 = select(powr((_21724 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _21724 * float3(0.077399380505084991455078125), _21724 <= float3(0.040449999272823333740234375));
                                        float4 _33513 = _21715;
                                        _33513.x = _21733.x;
                                        _33513.y = _21733.y;
                                        _33513.z = _21733.z;
                                        _36253 = _33513;
                                    }
                                    else
                                    {
                                        _36253 = _21715;
                                    }
                                    int _21743 = _21705.x;
                                    float4 _21751 = srcTex.read(uint2(int3(_21743, _21700.y, 0).xy), 0);
                                    float4 _36256;
                                    if (_21718)
                                    {
                                        float3 _21760 = fast::clamp(_21751.xyz, float3(0.0), float3(1.0));
                                        float3 _21769 = select(powr((_21760 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _21760 * float3(0.077399380505084991455078125), _21760 <= float3(0.040449999272823333740234375));
                                        float4 _33522 = _21751;
                                        _33522.x = _21769.x;
                                        _33522.y = _21769.y;
                                        _33522.z = _21769.z;
                                        _36256 = _33522;
                                    }
                                    else
                                    {
                                        _36256 = _21751;
                                    }
                                    float4 _21787 = srcTex.read(uint2(int3(_21707, _21705.y, 0).xy), 0);
                                    float4 _36259;
                                    if (_21718)
                                    {
                                        float3 _21796 = fast::clamp(_21787.xyz, float3(0.0), float3(1.0));
                                        float3 _21805 = select(powr((_21796 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _21796 * float3(0.077399380505084991455078125), _21796 <= float3(0.040449999272823333740234375));
                                        float4 _33531 = _21787;
                                        _33531.x = _21805.x;
                                        _33531.y = _21805.y;
                                        _33531.z = _21805.z;
                                        _36259 = _33531;
                                    }
                                    else
                                    {
                                        _36259 = _21787;
                                    }
                                    float4 _21823 = srcTex.read(uint2(int3(_21743, _21705.y, 0).xy), 0);
                                    float4 _36261;
                                    if (_21718)
                                    {
                                        float3 _21832 = fast::clamp(_21823.xyz, float3(0.0), float3(1.0));
                                        float3 _21841 = select(powr((_21832 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _21832 * float3(0.077399380505084991455078125), _21832 <= float3(0.040449999272823333740234375));
                                        float4 _33540 = _21823;
                                        _33540.x = _21841.x;
                                        _33540.y = _21841.y;
                                        _33540.z = _21841.z;
                                        _36261 = _33540;
                                    }
                                    else
                                    {
                                        _36261 = _21823;
                                    }
                                    float4 _21852 = float4(_21697.x);
                                    _21863 = mix(mix(_36253, _36256, _21852), mix(_36259, _36261, _21852), float4(_21697.y));
                                    break;
                                } while(false);
                                float2 _21916 = _3574 + (float2(3.0, -3.0) * _4138);
                                float4 _22153;
                                do
                                {
                                    if (_6338)
                                    {
                                        _22153 = srcTex.sample(samp, _21916, level(0.0));
                                        break;
                                    }
                                    uint2 _21928 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _21930 = _21928.x;
                                    uint _21932 = _21928.y;
                                    float2 _21938 = (_21916 * float2(float(_21930), float(_21932))) - float2(0.5);
                                    int2 _21943 = int2(int(_21930), int(_21932)) - int2(1);
                                    float2 _21944 = rint(_21938);
                                    if (all(abs(_21938 - _21944) < float2(0.001953125)))
                                    {
                                        float4 _21959 = srcTex.read(uint2(int3(clamp(int2(_21944), int2(0), _21943), 0).xy), 0);
                                        float4 _36286;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _21968 = fast::clamp(_21959.xyz, float3(0.0), float3(1.0));
                                            float3 _21977 = select(powr((_21968 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _21968 * float3(0.077399380505084991455078125), _21968 <= float3(0.040449999272823333740234375));
                                            float4 _33562 = _21959;
                                            _33562.x = _21977.x;
                                            _33562.y = _21977.y;
                                            _33562.z = _21977.z;
                                            _36286 = _33562;
                                        }
                                        else
                                        {
                                            _36286 = _21959;
                                        }
                                        _22153 = _36286;
                                        break;
                                    }
                                    float2 _21987 = fract(_21938);
                                    int2 _21989 = int2(floor(_21938));
                                    int2 _21990 = clamp(_21989, int2(0), _21943);
                                    int2 _21995 = clamp(_21989 + int2(1), int2(0), _21943);
                                    int _21997 = _21990.x;
                                    float4 _22005 = srcTex.read(uint2(int3(_21997, _21990.y, 0).xy), 0);
                                    bool _22008 = _6337 > 0.5;
                                    float4 _36273;
                                    if (_22008)
                                    {
                                        float3 _22014 = fast::clamp(_22005.xyz, float3(0.0), float3(1.0));
                                        float3 _22023 = select(powr((_22014 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22014 * float3(0.077399380505084991455078125), _22014 <= float3(0.040449999272823333740234375));
                                        float4 _33571 = _22005;
                                        _33571.x = _22023.x;
                                        _33571.y = _22023.y;
                                        _33571.z = _22023.z;
                                        _36273 = _33571;
                                    }
                                    else
                                    {
                                        _36273 = _22005;
                                    }
                                    int _22033 = _21995.x;
                                    float4 _22041 = srcTex.read(uint2(int3(_22033, _21990.y, 0).xy), 0);
                                    float4 _36276;
                                    if (_22008)
                                    {
                                        float3 _22050 = fast::clamp(_22041.xyz, float3(0.0), float3(1.0));
                                        float3 _22059 = select(powr((_22050 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22050 * float3(0.077399380505084991455078125), _22050 <= float3(0.040449999272823333740234375));
                                        float4 _33580 = _22041;
                                        _33580.x = _22059.x;
                                        _33580.y = _22059.y;
                                        _33580.z = _22059.z;
                                        _36276 = _33580;
                                    }
                                    else
                                    {
                                        _36276 = _22041;
                                    }
                                    float4 _22077 = srcTex.read(uint2(int3(_21997, _21995.y, 0).xy), 0);
                                    float4 _36279;
                                    if (_22008)
                                    {
                                        float3 _22086 = fast::clamp(_22077.xyz, float3(0.0), float3(1.0));
                                        float3 _22095 = select(powr((_22086 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22086 * float3(0.077399380505084991455078125), _22086 <= float3(0.040449999272823333740234375));
                                        float4 _33589 = _22077;
                                        _33589.x = _22095.x;
                                        _33589.y = _22095.y;
                                        _33589.z = _22095.z;
                                        _36279 = _33589;
                                    }
                                    else
                                    {
                                        _36279 = _22077;
                                    }
                                    float4 _22113 = srcTex.read(uint2(int3(_22033, _21995.y, 0).xy), 0);
                                    float4 _36281;
                                    if (_22008)
                                    {
                                        float3 _22122 = fast::clamp(_22113.xyz, float3(0.0), float3(1.0));
                                        float3 _22131 = select(powr((_22122 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22122 * float3(0.077399380505084991455078125), _22122 <= float3(0.040449999272823333740234375));
                                        float4 _33598 = _22113;
                                        _33598.x = _22131.x;
                                        _33598.y = _22131.y;
                                        _33598.z = _22131.z;
                                        _36281 = _33598;
                                    }
                                    else
                                    {
                                        _36281 = _22113;
                                    }
                                    float4 _22142 = float4(_21987.x);
                                    _22153 = mix(mix(_36273, _36276, _22142), mix(_36279, _36281, _22142), float4(_21987.y));
                                    break;
                                } while(false);
                                float2 _22210 = _3574 + (float2(-3.0, 0.0) * _4138);
                                float4 _22447;
                                do
                                {
                                    if (_6338)
                                    {
                                        _22447 = srcTex.sample(samp, _22210, level(0.0));
                                        break;
                                    }
                                    uint2 _22222 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _22224 = _22222.x;
                                    uint _22226 = _22222.y;
                                    float2 _22232 = (_22210 * float2(float(_22224), float(_22226))) - float2(0.5);
                                    int2 _22237 = int2(int(_22224), int(_22226)) - int2(1);
                                    float2 _22238 = rint(_22232);
                                    if (all(abs(_22232 - _22238) < float2(0.001953125)))
                                    {
                                        float4 _22253 = srcTex.read(uint2(int3(clamp(int2(_22238), int2(0), _22237), 0).xy), 0);
                                        float4 _36306;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _22262 = fast::clamp(_22253.xyz, float3(0.0), float3(1.0));
                                            float3 _22271 = select(powr((_22262 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22262 * float3(0.077399380505084991455078125), _22262 <= float3(0.040449999272823333740234375));
                                            float4 _33620 = _22253;
                                            _33620.x = _22271.x;
                                            _33620.y = _22271.y;
                                            _33620.z = _22271.z;
                                            _36306 = _33620;
                                        }
                                        else
                                        {
                                            _36306 = _22253;
                                        }
                                        _22447 = _36306;
                                        break;
                                    }
                                    float2 _22281 = fract(_22232);
                                    int2 _22283 = int2(floor(_22232));
                                    int2 _22284 = clamp(_22283, int2(0), _22237);
                                    int2 _22289 = clamp(_22283 + int2(1), int2(0), _22237);
                                    int _22291 = _22284.x;
                                    float4 _22299 = srcTex.read(uint2(int3(_22291, _22284.y, 0).xy), 0);
                                    bool _22302 = _6337 > 0.5;
                                    float4 _36293;
                                    if (_22302)
                                    {
                                        float3 _22308 = fast::clamp(_22299.xyz, float3(0.0), float3(1.0));
                                        float3 _22317 = select(powr((_22308 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22308 * float3(0.077399380505084991455078125), _22308 <= float3(0.040449999272823333740234375));
                                        float4 _33629 = _22299;
                                        _33629.x = _22317.x;
                                        _33629.y = _22317.y;
                                        _33629.z = _22317.z;
                                        _36293 = _33629;
                                    }
                                    else
                                    {
                                        _36293 = _22299;
                                    }
                                    int _22327 = _22289.x;
                                    float4 _22335 = srcTex.read(uint2(int3(_22327, _22284.y, 0).xy), 0);
                                    float4 _36296;
                                    if (_22302)
                                    {
                                        float3 _22344 = fast::clamp(_22335.xyz, float3(0.0), float3(1.0));
                                        float3 _22353 = select(powr((_22344 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22344 * float3(0.077399380505084991455078125), _22344 <= float3(0.040449999272823333740234375));
                                        float4 _33638 = _22335;
                                        _33638.x = _22353.x;
                                        _33638.y = _22353.y;
                                        _33638.z = _22353.z;
                                        _36296 = _33638;
                                    }
                                    else
                                    {
                                        _36296 = _22335;
                                    }
                                    float4 _22371 = srcTex.read(uint2(int3(_22291, _22289.y, 0).xy), 0);
                                    float4 _36299;
                                    if (_22302)
                                    {
                                        float3 _22380 = fast::clamp(_22371.xyz, float3(0.0), float3(1.0));
                                        float3 _22389 = select(powr((_22380 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22380 * float3(0.077399380505084991455078125), _22380 <= float3(0.040449999272823333740234375));
                                        float4 _33647 = _22371;
                                        _33647.x = _22389.x;
                                        _33647.y = _22389.y;
                                        _33647.z = _22389.z;
                                        _36299 = _33647;
                                    }
                                    else
                                    {
                                        _36299 = _22371;
                                    }
                                    float4 _22407 = srcTex.read(uint2(int3(_22327, _22289.y, 0).xy), 0);
                                    float4 _36301;
                                    if (_22302)
                                    {
                                        float3 _22416 = fast::clamp(_22407.xyz, float3(0.0), float3(1.0));
                                        float3 _22425 = select(powr((_22416 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22416 * float3(0.077399380505084991455078125), _22416 <= float3(0.040449999272823333740234375));
                                        float4 _33656 = _22407;
                                        _33656.x = _22425.x;
                                        _33656.y = _22425.y;
                                        _33656.z = _22425.z;
                                        _36301 = _33656;
                                    }
                                    else
                                    {
                                        _36301 = _22407;
                                    }
                                    float4 _22436 = float4(_22281.x);
                                    _22447 = mix(mix(_36293, _36296, _22436), mix(_36299, _36301, _22436), float4(_22281.y));
                                    break;
                                } while(false);
                                float _22483 = fast::max(fast::max(fast::max(fast::max(fast::max(fast::max(fast::max(fast::max(fast::max(abs(_13446.x - _13446.y), abs(_13446.x - _13446.z)), fast::max(fast::max(abs(_13601.x - _13446.x), abs(_13601.y - _13446.y)), abs(_13601.z - _13446.z))), fast::max(abs(_13601.x - _13601.y), abs(_13601.x - _13601.z))), fast::max(fast::max(abs(_21863.x - _13446.x), abs(_21863.y - _13446.y)), abs(_21863.z - _13446.z))), fast::max(abs(_21863.x - _21863.y), abs(_21863.x - _21863.z))), fast::max(fast::max(abs(_22153.x - _13446.x), abs(_22153.y - _13446.y)), abs(_22153.z - _13446.z))), fast::max(abs(_22153.x - _22153.y), abs(_22153.x - _22153.z))), fast::max(fast::max(abs(_22447.x - _13446.x), abs(_22447.y - _13446.y)), abs(_22447.z - _13446.z))), fast::max(abs(_22447.x - _22447.y), abs(_22447.x - _22447.z)));
                                float4 _22735;
                                do
                                {
                                    if (_6338)
                                    {
                                        _22735 = srcTex.sample(samp, _3574, level(0.0));
                                        break;
                                    }
                                    uint2 _22510 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _22512 = _22510.x;
                                    uint _22514 = _22510.y;
                                    float2 _22520 = (_3574 * float2(float(_22512), float(_22514))) - float2(0.5);
                                    int2 _22525 = int2(int(_22512), int(_22514)) - int2(1);
                                    float2 _22526 = rint(_22520);
                                    if (all(abs(_22520 - _22526) < float2(0.001953125)))
                                    {
                                        float4 _22541 = srcTex.read(uint2(int3(clamp(int2(_22526), int2(0), _22525), 0).xy), 0);
                                        float4 _36326;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _22550 = fast::clamp(_22541.xyz, float3(0.0), float3(1.0));
                                            float3 _22559 = select(powr((_22550 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22550 * float3(0.077399380505084991455078125), _22550 <= float3(0.040449999272823333740234375));
                                            float4 _33678 = _22541;
                                            _33678.x = _22559.x;
                                            _33678.y = _22559.y;
                                            _33678.z = _22559.z;
                                            _36326 = _33678;
                                        }
                                        else
                                        {
                                            _36326 = _22541;
                                        }
                                        _22735 = _36326;
                                        break;
                                    }
                                    float2 _22569 = fract(_22520);
                                    int2 _22571 = int2(floor(_22520));
                                    int2 _22572 = clamp(_22571, int2(0), _22525);
                                    int2 _22577 = clamp(_22571 + int2(1), int2(0), _22525);
                                    int _22579 = _22572.x;
                                    float4 _22587 = srcTex.read(uint2(int3(_22579, _22572.y, 0).xy), 0);
                                    bool _22590 = _6337 > 0.5;
                                    float4 _36313;
                                    if (_22590)
                                    {
                                        float3 _22596 = fast::clamp(_22587.xyz, float3(0.0), float3(1.0));
                                        float3 _22605 = select(powr((_22596 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22596 * float3(0.077399380505084991455078125), _22596 <= float3(0.040449999272823333740234375));
                                        float4 _33687 = _22587;
                                        _33687.x = _22605.x;
                                        _33687.y = _22605.y;
                                        _33687.z = _22605.z;
                                        _36313 = _33687;
                                    }
                                    else
                                    {
                                        _36313 = _22587;
                                    }
                                    int _22615 = _22577.x;
                                    float4 _22623 = srcTex.read(uint2(int3(_22615, _22572.y, 0).xy), 0);
                                    float4 _36316;
                                    if (_22590)
                                    {
                                        float3 _22632 = fast::clamp(_22623.xyz, float3(0.0), float3(1.0));
                                        float3 _22641 = select(powr((_22632 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22632 * float3(0.077399380505084991455078125), _22632 <= float3(0.040449999272823333740234375));
                                        float4 _33696 = _22623;
                                        _33696.x = _22641.x;
                                        _33696.y = _22641.y;
                                        _33696.z = _22641.z;
                                        _36316 = _33696;
                                    }
                                    else
                                    {
                                        _36316 = _22623;
                                    }
                                    float4 _22659 = srcTex.read(uint2(int3(_22579, _22577.y, 0).xy), 0);
                                    float4 _36319;
                                    if (_22590)
                                    {
                                        float3 _22668 = fast::clamp(_22659.xyz, float3(0.0), float3(1.0));
                                        float3 _22677 = select(powr((_22668 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22668 * float3(0.077399380505084991455078125), _22668 <= float3(0.040449999272823333740234375));
                                        float4 _33705 = _22659;
                                        _33705.x = _22677.x;
                                        _33705.y = _22677.y;
                                        _33705.z = _22677.z;
                                        _36319 = _33705;
                                    }
                                    else
                                    {
                                        _36319 = _22659;
                                    }
                                    float4 _22695 = srcTex.read(uint2(int3(_22615, _22577.y, 0).xy), 0);
                                    float4 _36321;
                                    if (_22590)
                                    {
                                        float3 _22704 = fast::clamp(_22695.xyz, float3(0.0), float3(1.0));
                                        float3 _22713 = select(powr((_22704 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22704 * float3(0.077399380505084991455078125), _22704 <= float3(0.040449999272823333740234375));
                                        float4 _33714 = _22695;
                                        _33714.x = _22713.x;
                                        _33714.y = _22713.y;
                                        _33714.z = _22713.z;
                                        _36321 = _33714;
                                    }
                                    else
                                    {
                                        _36321 = _22695;
                                    }
                                    float4 _22724 = float4(_22569.x);
                                    _22735 = mix(mix(_36313, _36316, _22724), mix(_36319, _36321, _22724), float4(_22569.y));
                                    break;
                                } while(false);
                                float2 _22786 = _3574 + (float2(3.0, 0.0) * _4138);
                                float4 _23023;
                                do
                                {
                                    if (_6338)
                                    {
                                        _23023 = srcTex.sample(samp, _22786, level(0.0));
                                        break;
                                    }
                                    uint2 _22798 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _22800 = _22798.x;
                                    uint _22802 = _22798.y;
                                    float2 _22808 = (_22786 * float2(float(_22800), float(_22802))) - float2(0.5);
                                    int2 _22813 = int2(int(_22800), int(_22802)) - int2(1);
                                    float2 _22814 = rint(_22808);
                                    if (all(abs(_22808 - _22814) < float2(0.001953125)))
                                    {
                                        float4 _22829 = srcTex.read(uint2(int3(clamp(int2(_22814), int2(0), _22813), 0).xy), 0);
                                        float4 _36346;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _22838 = fast::clamp(_22829.xyz, float3(0.0), float3(1.0));
                                            float3 _22847 = select(powr((_22838 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22838 * float3(0.077399380505084991455078125), _22838 <= float3(0.040449999272823333740234375));
                                            float4 _33736 = _22829;
                                            _33736.x = _22847.x;
                                            _33736.y = _22847.y;
                                            _33736.z = _22847.z;
                                            _36346 = _33736;
                                        }
                                        else
                                        {
                                            _36346 = _22829;
                                        }
                                        _23023 = _36346;
                                        break;
                                    }
                                    float2 _22857 = fract(_22808);
                                    int2 _22859 = int2(floor(_22808));
                                    int2 _22860 = clamp(_22859, int2(0), _22813);
                                    int2 _22865 = clamp(_22859 + int2(1), int2(0), _22813);
                                    int _22867 = _22860.x;
                                    float4 _22875 = srcTex.read(uint2(int3(_22867, _22860.y, 0).xy), 0);
                                    bool _22878 = _6337 > 0.5;
                                    float4 _36333;
                                    if (_22878)
                                    {
                                        float3 _22884 = fast::clamp(_22875.xyz, float3(0.0), float3(1.0));
                                        float3 _22893 = select(powr((_22884 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22884 * float3(0.077399380505084991455078125), _22884 <= float3(0.040449999272823333740234375));
                                        float4 _33745 = _22875;
                                        _33745.x = _22893.x;
                                        _33745.y = _22893.y;
                                        _33745.z = _22893.z;
                                        _36333 = _33745;
                                    }
                                    else
                                    {
                                        _36333 = _22875;
                                    }
                                    int _22903 = _22865.x;
                                    float4 _22911 = srcTex.read(uint2(int3(_22903, _22860.y, 0).xy), 0);
                                    float4 _36336;
                                    if (_22878)
                                    {
                                        float3 _22920 = fast::clamp(_22911.xyz, float3(0.0), float3(1.0));
                                        float3 _22929 = select(powr((_22920 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22920 * float3(0.077399380505084991455078125), _22920 <= float3(0.040449999272823333740234375));
                                        float4 _33754 = _22911;
                                        _33754.x = _22929.x;
                                        _33754.y = _22929.y;
                                        _33754.z = _22929.z;
                                        _36336 = _33754;
                                    }
                                    else
                                    {
                                        _36336 = _22911;
                                    }
                                    float4 _22947 = srcTex.read(uint2(int3(_22867, _22865.y, 0).xy), 0);
                                    float4 _36339;
                                    if (_22878)
                                    {
                                        float3 _22956 = fast::clamp(_22947.xyz, float3(0.0), float3(1.0));
                                        float3 _22965 = select(powr((_22956 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22956 * float3(0.077399380505084991455078125), _22956 <= float3(0.040449999272823333740234375));
                                        float4 _33763 = _22947;
                                        _33763.x = _22965.x;
                                        _33763.y = _22965.y;
                                        _33763.z = _22965.z;
                                        _36339 = _33763;
                                    }
                                    else
                                    {
                                        _36339 = _22947;
                                    }
                                    float4 _22983 = srcTex.read(uint2(int3(_22903, _22865.y, 0).xy), 0);
                                    float4 _36341;
                                    if (_22878)
                                    {
                                        float3 _22992 = fast::clamp(_22983.xyz, float3(0.0), float3(1.0));
                                        float3 _23001 = select(powr((_22992 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _22992 * float3(0.077399380505084991455078125), _22992 <= float3(0.040449999272823333740234375));
                                        float4 _33772 = _22983;
                                        _33772.x = _23001.x;
                                        _33772.y = _23001.y;
                                        _33772.z = _23001.z;
                                        _36341 = _33772;
                                    }
                                    else
                                    {
                                        _36341 = _22983;
                                    }
                                    float4 _23012 = float4(_22857.x);
                                    _23023 = mix(mix(_36333, _36336, _23012), mix(_36339, _36341, _23012), float4(_22857.y));
                                    break;
                                } while(false);
                                float2 _23083 = _3574 + (float2(-3.0, 3.0) * _4138);
                                float4 _23320;
                                do
                                {
                                    if (_6338)
                                    {
                                        _23320 = srcTex.sample(samp, _23083, level(0.0));
                                        break;
                                    }
                                    uint2 _23095 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _23097 = _23095.x;
                                    uint _23099 = _23095.y;
                                    float2 _23105 = (_23083 * float2(float(_23097), float(_23099))) - float2(0.5);
                                    int2 _23110 = int2(int(_23097), int(_23099)) - int2(1);
                                    float2 _23111 = rint(_23105);
                                    if (all(abs(_23105 - _23111) < float2(0.001953125)))
                                    {
                                        float4 _23126 = srcTex.read(uint2(int3(clamp(int2(_23111), int2(0), _23110), 0).xy), 0);
                                        float4 _36366;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _23135 = fast::clamp(_23126.xyz, float3(0.0), float3(1.0));
                                            float3 _23144 = select(powr((_23135 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23135 * float3(0.077399380505084991455078125), _23135 <= float3(0.040449999272823333740234375));
                                            float4 _33794 = _23126;
                                            _33794.x = _23144.x;
                                            _33794.y = _23144.y;
                                            _33794.z = _23144.z;
                                            _36366 = _33794;
                                        }
                                        else
                                        {
                                            _36366 = _23126;
                                        }
                                        _23320 = _36366;
                                        break;
                                    }
                                    float2 _23154 = fract(_23105);
                                    int2 _23156 = int2(floor(_23105));
                                    int2 _23157 = clamp(_23156, int2(0), _23110);
                                    int2 _23162 = clamp(_23156 + int2(1), int2(0), _23110);
                                    int _23164 = _23157.x;
                                    float4 _23172 = srcTex.read(uint2(int3(_23164, _23157.y, 0).xy), 0);
                                    bool _23175 = _6337 > 0.5;
                                    float4 _36353;
                                    if (_23175)
                                    {
                                        float3 _23181 = fast::clamp(_23172.xyz, float3(0.0), float3(1.0));
                                        float3 _23190 = select(powr((_23181 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23181 * float3(0.077399380505084991455078125), _23181 <= float3(0.040449999272823333740234375));
                                        float4 _33803 = _23172;
                                        _33803.x = _23190.x;
                                        _33803.y = _23190.y;
                                        _33803.z = _23190.z;
                                        _36353 = _33803;
                                    }
                                    else
                                    {
                                        _36353 = _23172;
                                    }
                                    int _23200 = _23162.x;
                                    float4 _23208 = srcTex.read(uint2(int3(_23200, _23157.y, 0).xy), 0);
                                    float4 _36356;
                                    if (_23175)
                                    {
                                        float3 _23217 = fast::clamp(_23208.xyz, float3(0.0), float3(1.0));
                                        float3 _23226 = select(powr((_23217 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23217 * float3(0.077399380505084991455078125), _23217 <= float3(0.040449999272823333740234375));
                                        float4 _33812 = _23208;
                                        _33812.x = _23226.x;
                                        _33812.y = _23226.y;
                                        _33812.z = _23226.z;
                                        _36356 = _33812;
                                    }
                                    else
                                    {
                                        _36356 = _23208;
                                    }
                                    float4 _23244 = srcTex.read(uint2(int3(_23164, _23162.y, 0).xy), 0);
                                    float4 _36359;
                                    if (_23175)
                                    {
                                        float3 _23253 = fast::clamp(_23244.xyz, float3(0.0), float3(1.0));
                                        float3 _23262 = select(powr((_23253 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23253 * float3(0.077399380505084991455078125), _23253 <= float3(0.040449999272823333740234375));
                                        float4 _33821 = _23244;
                                        _33821.x = _23262.x;
                                        _33821.y = _23262.y;
                                        _33821.z = _23262.z;
                                        _36359 = _33821;
                                    }
                                    else
                                    {
                                        _36359 = _23244;
                                    }
                                    float4 _23280 = srcTex.read(uint2(int3(_23200, _23162.y, 0).xy), 0);
                                    float4 _36361;
                                    if (_23175)
                                    {
                                        float3 _23289 = fast::clamp(_23280.xyz, float3(0.0), float3(1.0));
                                        float3 _23298 = select(powr((_23289 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23289 * float3(0.077399380505084991455078125), _23289 <= float3(0.040449999272823333740234375));
                                        float4 _33830 = _23280;
                                        _33830.x = _23298.x;
                                        _33830.y = _23298.y;
                                        _33830.z = _23298.z;
                                        _36361 = _33830;
                                    }
                                    else
                                    {
                                        _36361 = _23280;
                                    }
                                    float4 _23309 = float4(_23154.x);
                                    _23320 = mix(mix(_36353, _36356, _23309), mix(_36359, _36361, _23309), float4(_23154.y));
                                    break;
                                } while(false);
                                float2 _23371 = _3574 + (float2(0.0, 3.0) * _4138);
                                float4 _23608;
                                do
                                {
                                    if (_6338)
                                    {
                                        _23608 = srcTex.sample(samp, _23371, level(0.0));
                                        break;
                                    }
                                    uint2 _23383 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _23385 = _23383.x;
                                    uint _23387 = _23383.y;
                                    float2 _23393 = (_23371 * float2(float(_23385), float(_23387))) - float2(0.5);
                                    int2 _23398 = int2(int(_23385), int(_23387)) - int2(1);
                                    float2 _23399 = rint(_23393);
                                    if (all(abs(_23393 - _23399) < float2(0.001953125)))
                                    {
                                        float4 _23414 = srcTex.read(uint2(int3(clamp(int2(_23399), int2(0), _23398), 0).xy), 0);
                                        float4 _36386;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _23423 = fast::clamp(_23414.xyz, float3(0.0), float3(1.0));
                                            float3 _23432 = select(powr((_23423 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23423 * float3(0.077399380505084991455078125), _23423 <= float3(0.040449999272823333740234375));
                                            float4 _33852 = _23414;
                                            _33852.x = _23432.x;
                                            _33852.y = _23432.y;
                                            _33852.z = _23432.z;
                                            _36386 = _33852;
                                        }
                                        else
                                        {
                                            _36386 = _23414;
                                        }
                                        _23608 = _36386;
                                        break;
                                    }
                                    float2 _23442 = fract(_23393);
                                    int2 _23444 = int2(floor(_23393));
                                    int2 _23445 = clamp(_23444, int2(0), _23398);
                                    int2 _23450 = clamp(_23444 + int2(1), int2(0), _23398);
                                    int _23452 = _23445.x;
                                    float4 _23460 = srcTex.read(uint2(int3(_23452, _23445.y, 0).xy), 0);
                                    bool _23463 = _6337 > 0.5;
                                    float4 _36373;
                                    if (_23463)
                                    {
                                        float3 _23469 = fast::clamp(_23460.xyz, float3(0.0), float3(1.0));
                                        float3 _23478 = select(powr((_23469 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23469 * float3(0.077399380505084991455078125), _23469 <= float3(0.040449999272823333740234375));
                                        float4 _33861 = _23460;
                                        _33861.x = _23478.x;
                                        _33861.y = _23478.y;
                                        _33861.z = _23478.z;
                                        _36373 = _33861;
                                    }
                                    else
                                    {
                                        _36373 = _23460;
                                    }
                                    int _23488 = _23450.x;
                                    float4 _23496 = srcTex.read(uint2(int3(_23488, _23445.y, 0).xy), 0);
                                    float4 _36376;
                                    if (_23463)
                                    {
                                        float3 _23505 = fast::clamp(_23496.xyz, float3(0.0), float3(1.0));
                                        float3 _23514 = select(powr((_23505 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23505 * float3(0.077399380505084991455078125), _23505 <= float3(0.040449999272823333740234375));
                                        float4 _33870 = _23496;
                                        _33870.x = _23514.x;
                                        _33870.y = _23514.y;
                                        _33870.z = _23514.z;
                                        _36376 = _33870;
                                    }
                                    else
                                    {
                                        _36376 = _23496;
                                    }
                                    float4 _23532 = srcTex.read(uint2(int3(_23452, _23450.y, 0).xy), 0);
                                    float4 _36379;
                                    if (_23463)
                                    {
                                        float3 _23541 = fast::clamp(_23532.xyz, float3(0.0), float3(1.0));
                                        float3 _23550 = select(powr((_23541 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23541 * float3(0.077399380505084991455078125), _23541 <= float3(0.040449999272823333740234375));
                                        float4 _33879 = _23532;
                                        _33879.x = _23550.x;
                                        _33879.y = _23550.y;
                                        _33879.z = _23550.z;
                                        _36379 = _33879;
                                    }
                                    else
                                    {
                                        _36379 = _23532;
                                    }
                                    float4 _23568 = srcTex.read(uint2(int3(_23488, _23450.y, 0).xy), 0);
                                    float4 _36381;
                                    if (_23463)
                                    {
                                        float3 _23577 = fast::clamp(_23568.xyz, float3(0.0), float3(1.0));
                                        float3 _23586 = select(powr((_23577 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23577 * float3(0.077399380505084991455078125), _23577 <= float3(0.040449999272823333740234375));
                                        float4 _33888 = _23568;
                                        _33888.x = _23586.x;
                                        _33888.y = _23586.y;
                                        _33888.z = _23586.z;
                                        _36381 = _33888;
                                    }
                                    else
                                    {
                                        _36381 = _23568;
                                    }
                                    float4 _23597 = float4(_23442.x);
                                    _23608 = mix(mix(_36373, _36376, _23597), mix(_36379, _36381, _23597), float4(_23442.y));
                                    break;
                                } while(false);
                                float _23644 = fast::max(fast::max(fast::max(fast::max(fast::max(fast::max(fast::max(fast::max(_22483, fast::max(fast::max(abs(_22735.x - _13446.x), abs(_22735.y - _13446.y)), abs(_22735.z - _13446.z))), fast::max(abs(_22735.x - _22735.y), abs(_22735.x - _22735.z))), fast::max(fast::max(abs(_23023.x - _13446.x), abs(_23023.y - _13446.y)), abs(_23023.z - _13446.z))), fast::max(abs(_23023.x - _23023.y), abs(_23023.x - _23023.z))), fast::max(fast::max(abs(_23320.x - _13446.x), abs(_23320.y - _13446.y)), abs(_23320.z - _13446.z))), fast::max(abs(_23320.x - _23320.y), abs(_23320.x - _23320.z))), fast::max(fast::max(abs(_23608.x - _13446.x), abs(_23608.y - _13446.y)), abs(_23608.z - _13446.z))), fast::max(abs(_23608.x - _23608.y), abs(_23608.x - _23608.z)));
                                float2 _23659 = _3574 + (float2(3.0) * _4138);
                                float4 _23896;
                                do
                                {
                                    if (_6338)
                                    {
                                        _23896 = srcTex.sample(samp, _23659, level(0.0));
                                        break;
                                    }
                                    uint2 _23671 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _23673 = _23671.x;
                                    uint _23675 = _23671.y;
                                    float2 _23681 = (_23659 * float2(float(_23673), float(_23675))) - float2(0.5);
                                    int2 _23686 = int2(int(_23673), int(_23675)) - int2(1);
                                    float2 _23687 = rint(_23681);
                                    if (all(abs(_23681 - _23687) < float2(0.001953125)))
                                    {
                                        float4 _23702 = srcTex.read(uint2(int3(clamp(int2(_23687), int2(0), _23686), 0).xy), 0);
                                        float4 _36406;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _23711 = fast::clamp(_23702.xyz, float3(0.0), float3(1.0));
                                            float3 _23720 = select(powr((_23711 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23711 * float3(0.077399380505084991455078125), _23711 <= float3(0.040449999272823333740234375));
                                            float4 _33910 = _23702;
                                            _33910.x = _23720.x;
                                            _33910.y = _23720.y;
                                            _33910.z = _23720.z;
                                            _36406 = _33910;
                                        }
                                        else
                                        {
                                            _36406 = _23702;
                                        }
                                        _23896 = _36406;
                                        break;
                                    }
                                    float2 _23730 = fract(_23681);
                                    int2 _23732 = int2(floor(_23681));
                                    int2 _23733 = clamp(_23732, int2(0), _23686);
                                    int2 _23738 = clamp(_23732 + int2(1), int2(0), _23686);
                                    int _23740 = _23733.x;
                                    float4 _23748 = srcTex.read(uint2(int3(_23740, _23733.y, 0).xy), 0);
                                    bool _23751 = _6337 > 0.5;
                                    float4 _36393;
                                    if (_23751)
                                    {
                                        float3 _23757 = fast::clamp(_23748.xyz, float3(0.0), float3(1.0));
                                        float3 _23766 = select(powr((_23757 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23757 * float3(0.077399380505084991455078125), _23757 <= float3(0.040449999272823333740234375));
                                        float4 _33919 = _23748;
                                        _33919.x = _23766.x;
                                        _33919.y = _23766.y;
                                        _33919.z = _23766.z;
                                        _36393 = _33919;
                                    }
                                    else
                                    {
                                        _36393 = _23748;
                                    }
                                    int _23776 = _23738.x;
                                    float4 _23784 = srcTex.read(uint2(int3(_23776, _23733.y, 0).xy), 0);
                                    float4 _36396;
                                    if (_23751)
                                    {
                                        float3 _23793 = fast::clamp(_23784.xyz, float3(0.0), float3(1.0));
                                        float3 _23802 = select(powr((_23793 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23793 * float3(0.077399380505084991455078125), _23793 <= float3(0.040449999272823333740234375));
                                        float4 _33928 = _23784;
                                        _33928.x = _23802.x;
                                        _33928.y = _23802.y;
                                        _33928.z = _23802.z;
                                        _36396 = _33928;
                                    }
                                    else
                                    {
                                        _36396 = _23784;
                                    }
                                    float4 _23820 = srcTex.read(uint2(int3(_23740, _23738.y, 0).xy), 0);
                                    float4 _36399;
                                    if (_23751)
                                    {
                                        float3 _23829 = fast::clamp(_23820.xyz, float3(0.0), float3(1.0));
                                        float3 _23838 = select(powr((_23829 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23829 * float3(0.077399380505084991455078125), _23829 <= float3(0.040449999272823333740234375));
                                        float4 _33937 = _23820;
                                        _33937.x = _23838.x;
                                        _33937.y = _23838.y;
                                        _33937.z = _23838.z;
                                        _36399 = _33937;
                                    }
                                    else
                                    {
                                        _36399 = _23820;
                                    }
                                    float4 _23856 = srcTex.read(uint2(int3(_23776, _23738.y, 0).xy), 0);
                                    float4 _36401;
                                    if (_23751)
                                    {
                                        float3 _23865 = fast::clamp(_23856.xyz, float3(0.0), float3(1.0));
                                        float3 _23874 = select(powr((_23865 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _23865 * float3(0.077399380505084991455078125), _23865 <= float3(0.040449999272823333740234375));
                                        float4 _33946 = _23856;
                                        _33946.x = _23874.x;
                                        _33946.y = _23874.y;
                                        _33946.z = _23874.z;
                                        _36401 = _33946;
                                    }
                                    else
                                    {
                                        _36401 = _23856;
                                    }
                                    float4 _23885 = float4(_23730.x);
                                    _23896 = mix(mix(_36393, _36396, _23885), mix(_36399, _36401, _23885), float4(_23730.y));
                                    break;
                                } while(false);
                                if (fast::max(fast::max(_23644, fast::max(fast::max(abs(_23896.x - _13446.x), abs(_23896.y - _13446.y)), abs(_23896.z - _13446.z))), fast::max(abs(_23896.x - _23896.y), abs(_23896.x - _23896.z))) < 0.00999999977648258209228515625)
                                {
                                    _13619 = float4(_13446.xyz, 1.0);
                                    break;
                                }
                                float _13548;
                                if (_395.g_pairRefine > 0.5)
                                {
                                    int _4206 = int(_395.g_paneW);
                                    int _4209 = int(gl_FragCoord.x);
                                    float4 _4243 = pairTex.read(uint2(int3(clamp(_4209 - (int(_4209 >= _4206) * _4206), 0, _4206 - 1) / 2, int(gl_FragCoord.y), 0).xy), 0);
                                    _13548 = select(_4243.zw, _4243.xy, bool2(!_13391)).x;
                                }
                                else
                                {
                                    uint2 _7741 = uint2(dispTex.get_width(), dispTex.get_height());
                                    uint _7743 = _7741.x;
                                    uint _7745 = _7741.y;
                                    float2 _7760 = ((_3574 / float2(_395.g_lvlToSrcX, _395.g_lvlToSrcY)) * float2(float(_7743), float(_7745))) - float2(0.5);
                                    int2 _7763 = int2(floor(_7760));
                                    int2 _7785 = int2(int(_7743 - 1u), int(_7745 - 1u));
                                    float2 _7795 = abs(_7760 - float2(_7763));
                                    int2 _7810 = int3(clamp(_7763, int2(0), _7785), 0).xy;
                                    float _7831 = (fast::max(0.0, 1.0 - _7795.x) * fast::max(0.0, 1.0 - _7795.y)) * (exp(dot(abs(srcQ.read(uint2(_7810), 0).xyz - _13446.xyz), float3(1.0)) * (-8.0)) + 9.9999999747524270787835121154785e-07);
                                    int2 _21424 = _7763 + int2(1, 0);
                                    float2 _21435 = abs(_7760 - float2(_21424));
                                    int2 _21449 = int3(clamp(_21424, int2(0), _7785), 0).xy;
                                    float _21464 = (fast::max(0.0, 1.0 - _21435.x) * fast::max(0.0, 1.0 - _21435.y)) * (exp(dot(abs(srcQ.read(uint2(_21449), 0).xyz - _13446.xyz), float3(1.0)) * (-8.0)) + 9.9999999747524270787835121154785e-07);
                                    int2 _21492 = _7763 + int2(0, 1);
                                    float2 _21503 = abs(_7760 - float2(_21492));
                                    int2 _21517 = int3(clamp(_21492, int2(0), _7785), 0).xy;
                                    float _21532 = (fast::max(0.0, 1.0 - _21503.x) * fast::max(0.0, 1.0 - _21503.y)) * (exp(dot(abs(srcQ.read(uint2(_21517), 0).xyz - _13446.xyz), float3(1.0)) * (-8.0)) + 9.9999999747524270787835121154785e-07);
                                    int2 _21553 = _7763 + int2(1);
                                    float2 _21564 = abs(_7760 - float2(_21553));
                                    int2 _21578 = int3(clamp(_21553, int2(0), _7785), 0).xy;
                                    float _21593 = (fast::max(0.0, 1.0 - _21564.x) * fast::max(0.0, 1.0 - _21564.y)) * (exp(dot(abs(srcQ.read(uint2(_21578), 0).xyz - _13446.xyz), float3(1.0)) * (-8.0)) + 9.9999999747524270787835121154785e-07);
                                    float4 _7863 = ((((dispTex.read(uint2(_7810), 0) * _7831) + (dispTex.read(uint2(_21449), 0) * _21464)) + (dispTex.read(uint2(_21517), 0) * _21532)) + (dispTex.read(uint2(_21578), 0) * _21593)) / float4(fast::max(((_7831 + _21464) + _21532) + _21593, 9.9999999392252902907785028219223e-09));
                                    float _7886 = (-2.0) / _395.g_srcW;
                                    float2 _7888 = _3574 + float2(_7886, 0.0);
                                    float4 _13531;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _13531 = srcTex.sample(samp, _7888, level(0.0));
                                            break;
                                        }
                                        uint2 _7968 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _7970 = _7968.x;
                                        uint _7972 = _7968.y;
                                        float2 _7981 = (_7888 * float2(float(_7970), float(_7972))) - float2(0.5);
                                        int2 _7988 = int2(int(_7970), int(_7972)) - int2(1);
                                        float2 _7990 = rint(_7981);
                                        if (all(abs(_7981 - _7990) < float2(0.001953125)))
                                        {
                                            float4 _8072 = srcTex.read(uint2(int3(clamp(int2(_7990), int2(0), _7988), 0).xy), 0);
                                            float4 _36426;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _8081 = fast::clamp(_8072.xyz, float3(0.0), float3(1.0));
                                                float3 _8104 = select(powr((_8081 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _8081 * float3(0.077399380505084991455078125), _8081 <= float3(0.040449999272823333740234375));
                                                float4 _33978 = _8072;
                                                _33978.x = _8104.x;
                                                _33978.y = _8104.y;
                                                _33978.z = _8104.z;
                                                _36426 = _33978;
                                            }
                                            else
                                            {
                                                _36426 = _8072;
                                            }
                                            _13531 = _36426;
                                            break;
                                        }
                                        float2 _8008 = fract(_7981);
                                        int2 _8011 = int2(floor(_7981));
                                        int2 _8013 = clamp(_8011, int2(0), _7988);
                                        int2 _8020 = clamp(_8011 + int2(1), int2(0), _7988);
                                        int _8022 = _8013.x;
                                        float4 _8114 = srcTex.read(uint2(int3(_8022, _8013.y, 0).xy), 0);
                                        bool _8117 = _6337 > 0.5;
                                        float4 _36413;
                                        if (_8117)
                                        {
                                            float3 _8123 = fast::clamp(_8114.xyz, float3(0.0), float3(1.0));
                                            float3 _8146 = select(powr((_8123 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _8123 * float3(0.077399380505084991455078125), _8123 <= float3(0.040449999272823333740234375));
                                            float4 _33987 = _8114;
                                            _33987.x = _8146.x;
                                            _33987.y = _8146.y;
                                            _33987.z = _8146.z;
                                            _36413 = _33987;
                                        }
                                        else
                                        {
                                            _36413 = _8114;
                                        }
                                        int _8028 = _8020.x;
                                        float4 _8156 = srcTex.read(uint2(int3(_8028, _8013.y, 0).xy), 0);
                                        float4 _36416;
                                        if (_8117)
                                        {
                                            float3 _8165 = fast::clamp(_8156.xyz, float3(0.0), float3(1.0));
                                            float3 _8188 = select(powr((_8165 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _8165 * float3(0.077399380505084991455078125), _8165 <= float3(0.040449999272823333740234375));
                                            float4 _33996 = _8156;
                                            _33996.x = _8188.x;
                                            _33996.y = _8188.y;
                                            _33996.z = _8188.z;
                                            _36416 = _33996;
                                        }
                                        else
                                        {
                                            _36416 = _8156;
                                        }
                                        float4 _8198 = srcTex.read(uint2(int3(_8022, _8020.y, 0).xy), 0);
                                        float4 _36419;
                                        if (_8117)
                                        {
                                            float3 _8207 = fast::clamp(_8198.xyz, float3(0.0), float3(1.0));
                                            float3 _8230 = select(powr((_8207 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _8207 * float3(0.077399380505084991455078125), _8207 <= float3(0.040449999272823333740234375));
                                            float4 _34005 = _8198;
                                            _34005.x = _8230.x;
                                            _34005.y = _8230.y;
                                            _34005.z = _8230.z;
                                            _36419 = _34005;
                                        }
                                        else
                                        {
                                            _36419 = _8198;
                                        }
                                        float4 _8240 = srcTex.read(uint2(int3(_8028, _8020.y, 0).xy), 0);
                                        float4 _36421;
                                        if (_8117)
                                        {
                                            float3 _8249 = fast::clamp(_8240.xyz, float3(0.0), float3(1.0));
                                            float3 _8272 = select(powr((_8249 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _8249 * float3(0.077399380505084991455078125), _8249 <= float3(0.040449999272823333740234375));
                                            float4 _34014 = _8240;
                                            _34014.x = _8272.x;
                                            _34014.y = _8272.y;
                                            _34014.z = _8272.z;
                                            _36421 = _34014;
                                        }
                                        else
                                        {
                                            _36421 = _8240;
                                        }
                                        float4 _8049 = float4(_8008.x);
                                        _13531 = mix(mix(_36413, _36416, _8049), mix(_36419, _36421, _8049), float4(_8008.y));
                                        break;
                                    } while(false);
                                    int _8279;
                                    bool _8284;
                                    float _13538;
                                    do
                                    {
                                        _8279 = _395.g_anaCombo;
                                        _8284 = (_8279 == 3) || (_8279 == 5);
                                        if (_8284)
                                        {
                                            _13538 = _13531.y;
                                            break;
                                        }
                                        if (_8279 == 4)
                                        {
                                            _13538 = (_13531.x + _13531.y) * 0.5;
                                            break;
                                        }
                                        _13538 = _13531.x;
                                        break;
                                    } while(false);
                                    bool _8314;
                                    bool _8315;
                                    float _13540;
                                    do
                                    {
                                        _8314 = _8279 == 4;
                                        _8315 = (_8279 == 2) || _8314;
                                        if (_8315)
                                        {
                                            _13540 = _13531.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _13540 = _13531.x;
                                            break;
                                        }
                                        _13540 = _13531.y;
                                        break;
                                    } while(false);
                                    float _20199 = (-1.0) / _395.g_srcW;
                                    float2 _20201 = _3574 + float2(_20199, 0.0);
                                    float4 _20438;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _20438 = srcTex.sample(samp, _20201, level(0.0));
                                            break;
                                        }
                                        uint2 _20213 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _20215 = _20213.x;
                                        uint _20217 = _20213.y;
                                        float2 _20223 = (_20201 * float2(float(_20215), float(_20217))) - float2(0.5);
                                        int2 _20228 = int2(int(_20215), int(_20217)) - int2(1);
                                        float2 _20229 = rint(_20223);
                                        if (all(abs(_20223 - _20229) < float2(0.001953125)))
                                        {
                                            float4 _20244 = srcTex.read(uint2(int3(clamp(int2(_20229), int2(0), _20228), 0).xy), 0);
                                            float4 _36440;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _20253 = fast::clamp(_20244.xyz, float3(0.0), float3(1.0));
                                                float3 _20262 = select(powr((_20253 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20253 * float3(0.077399380505084991455078125), _20253 <= float3(0.040449999272823333740234375));
                                                float4 _34033 = _20244;
                                                _34033.x = _20262.x;
                                                _34033.y = _20262.y;
                                                _34033.z = _20262.z;
                                                _36440 = _34033;
                                            }
                                            else
                                            {
                                                _36440 = _20244;
                                            }
                                            _20438 = _36440;
                                            break;
                                        }
                                        float2 _20272 = fract(_20223);
                                        int2 _20274 = int2(floor(_20223));
                                        int2 _20275 = clamp(_20274, int2(0), _20228);
                                        int2 _20280 = clamp(_20274 + int2(1), int2(0), _20228);
                                        int _20282 = _20275.x;
                                        float4 _20290 = srcTex.read(uint2(int3(_20282, _20275.y, 0).xy), 0);
                                        bool _20293 = _6337 > 0.5;
                                        float4 _36427;
                                        if (_20293)
                                        {
                                            float3 _20299 = fast::clamp(_20290.xyz, float3(0.0), float3(1.0));
                                            float3 _20308 = select(powr((_20299 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20299 * float3(0.077399380505084991455078125), _20299 <= float3(0.040449999272823333740234375));
                                            float4 _34042 = _20290;
                                            _34042.x = _20308.x;
                                            _34042.y = _20308.y;
                                            _34042.z = _20308.z;
                                            _36427 = _34042;
                                        }
                                        else
                                        {
                                            _36427 = _20290;
                                        }
                                        int _20318 = _20280.x;
                                        float4 _20326 = srcTex.read(uint2(int3(_20318, _20275.y, 0).xy), 0);
                                        float4 _36430;
                                        if (_20293)
                                        {
                                            float3 _20335 = fast::clamp(_20326.xyz, float3(0.0), float3(1.0));
                                            float3 _20344 = select(powr((_20335 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20335 * float3(0.077399380505084991455078125), _20335 <= float3(0.040449999272823333740234375));
                                            float4 _34051 = _20326;
                                            _34051.x = _20344.x;
                                            _34051.y = _20344.y;
                                            _34051.z = _20344.z;
                                            _36430 = _34051;
                                        }
                                        else
                                        {
                                            _36430 = _20326;
                                        }
                                        float4 _20362 = srcTex.read(uint2(int3(_20282, _20280.y, 0).xy), 0);
                                        float4 _36433;
                                        if (_20293)
                                        {
                                            float3 _20371 = fast::clamp(_20362.xyz, float3(0.0), float3(1.0));
                                            float3 _20380 = select(powr((_20371 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20371 * float3(0.077399380505084991455078125), _20371 <= float3(0.040449999272823333740234375));
                                            float4 _34060 = _20362;
                                            _34060.x = _20380.x;
                                            _34060.y = _20380.y;
                                            _34060.z = _20380.z;
                                            _36433 = _34060;
                                        }
                                        else
                                        {
                                            _36433 = _20362;
                                        }
                                        float4 _20398 = srcTex.read(uint2(int3(_20318, _20280.y, 0).xy), 0);
                                        float4 _36435;
                                        if (_20293)
                                        {
                                            float3 _20407 = fast::clamp(_20398.xyz, float3(0.0), float3(1.0));
                                            float3 _20416 = select(powr((_20407 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20407 * float3(0.077399380505084991455078125), _20407 <= float3(0.040449999272823333740234375));
                                            float4 _34069 = _20398;
                                            _34069.x = _20416.x;
                                            _34069.y = _20416.y;
                                            _34069.z = _20416.z;
                                            _36435 = _34069;
                                        }
                                        else
                                        {
                                            _36435 = _20398;
                                        }
                                        float4 _20427 = float4(_20272.x);
                                        _20438 = mix(mix(_36427, _36430, _20427), mix(_36433, _36435, _20427), float4(_20272.y));
                                        break;
                                    } while(false);
                                    float _20466;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _20466 = _20438.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _20466 = (_20438.x + _20438.y) * 0.5;
                                            break;
                                        }
                                        _20466 = _20438.x;
                                        break;
                                    } while(false);
                                    float _20494;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _20494 = _20438.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _20494 = _20438.x;
                                            break;
                                        }
                                        _20494 = _20438.y;
                                        break;
                                    } while(false);
                                    float4 _20744;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _20744 = srcTex.sample(samp, _3574, level(0.0));
                                            break;
                                        }
                                        uint2 _20519 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _20521 = _20519.x;
                                        uint _20523 = _20519.y;
                                        float2 _20529 = (_3574 * float2(float(_20521), float(_20523))) - float2(0.5);
                                        int2 _20534 = int2(int(_20521), int(_20523)) - int2(1);
                                        float2 _20535 = rint(_20529);
                                        if (all(abs(_20529 - _20535) < float2(0.001953125)))
                                        {
                                            float4 _20550 = srcTex.read(uint2(int3(clamp(int2(_20535), int2(0), _20534), 0).xy), 0);
                                            float4 _36454;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _20559 = fast::clamp(_20550.xyz, float3(0.0), float3(1.0));
                                                float3 _20568 = select(powr((_20559 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20559 * float3(0.077399380505084991455078125), _20559 <= float3(0.040449999272823333740234375));
                                                float4 _34088 = _20550;
                                                _34088.x = _20568.x;
                                                _34088.y = _20568.y;
                                                _34088.z = _20568.z;
                                                _36454 = _34088;
                                            }
                                            else
                                            {
                                                _36454 = _20550;
                                            }
                                            _20744 = _36454;
                                            break;
                                        }
                                        float2 _20578 = fract(_20529);
                                        int2 _20580 = int2(floor(_20529));
                                        int2 _20581 = clamp(_20580, int2(0), _20534);
                                        int2 _20586 = clamp(_20580 + int2(1), int2(0), _20534);
                                        int _20588 = _20581.x;
                                        float4 _20596 = srcTex.read(uint2(int3(_20588, _20581.y, 0).xy), 0);
                                        bool _20599 = _6337 > 0.5;
                                        float4 _36441;
                                        if (_20599)
                                        {
                                            float3 _20605 = fast::clamp(_20596.xyz, float3(0.0), float3(1.0));
                                            float3 _20614 = select(powr((_20605 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20605 * float3(0.077399380505084991455078125), _20605 <= float3(0.040449999272823333740234375));
                                            float4 _34097 = _20596;
                                            _34097.x = _20614.x;
                                            _34097.y = _20614.y;
                                            _34097.z = _20614.z;
                                            _36441 = _34097;
                                        }
                                        else
                                        {
                                            _36441 = _20596;
                                        }
                                        int _20624 = _20586.x;
                                        float4 _20632 = srcTex.read(uint2(int3(_20624, _20581.y, 0).xy), 0);
                                        float4 _36444;
                                        if (_20599)
                                        {
                                            float3 _20641 = fast::clamp(_20632.xyz, float3(0.0), float3(1.0));
                                            float3 _20650 = select(powr((_20641 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20641 * float3(0.077399380505084991455078125), _20641 <= float3(0.040449999272823333740234375));
                                            float4 _34106 = _20632;
                                            _34106.x = _20650.x;
                                            _34106.y = _20650.y;
                                            _34106.z = _20650.z;
                                            _36444 = _34106;
                                        }
                                        else
                                        {
                                            _36444 = _20632;
                                        }
                                        float4 _20668 = srcTex.read(uint2(int3(_20588, _20586.y, 0).xy), 0);
                                        float4 _36447;
                                        if (_20599)
                                        {
                                            float3 _20677 = fast::clamp(_20668.xyz, float3(0.0), float3(1.0));
                                            float3 _20686 = select(powr((_20677 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20677 * float3(0.077399380505084991455078125), _20677 <= float3(0.040449999272823333740234375));
                                            float4 _34115 = _20668;
                                            _34115.x = _20686.x;
                                            _34115.y = _20686.y;
                                            _34115.z = _20686.z;
                                            _36447 = _34115;
                                        }
                                        else
                                        {
                                            _36447 = _20668;
                                        }
                                        float4 _20704 = srcTex.read(uint2(int3(_20624, _20586.y, 0).xy), 0);
                                        float4 _36449;
                                        if (_20599)
                                        {
                                            float3 _20713 = fast::clamp(_20704.xyz, float3(0.0), float3(1.0));
                                            float3 _20722 = select(powr((_20713 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20713 * float3(0.077399380505084991455078125), _20713 <= float3(0.040449999272823333740234375));
                                            float4 _34124 = _20704;
                                            _34124.x = _20722.x;
                                            _34124.y = _20722.y;
                                            _34124.z = _20722.z;
                                            _36449 = _34124;
                                        }
                                        else
                                        {
                                            _36449 = _20704;
                                        }
                                        float4 _20733 = float4(_20578.x);
                                        _20744 = mix(mix(_36441, _36444, _20733), mix(_36447, _36449, _20733), float4(_20578.y));
                                        break;
                                    } while(false);
                                    float _20772;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _20772 = _20744.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _20772 = (_20744.x + _20744.y) * 0.5;
                                            break;
                                        }
                                        _20772 = _20744.x;
                                        break;
                                    } while(false);
                                    float _20800;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _20800 = _20744.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _20800 = _20744.x;
                                            break;
                                        }
                                        _20800 = _20744.y;
                                        break;
                                    } while(false);
                                    float2 _20813 = _3574 + float2(_4101, 0.0);
                                    float4 _21050;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _21050 = srcTex.sample(samp, _20813, level(0.0));
                                            break;
                                        }
                                        uint2 _20825 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _20827 = _20825.x;
                                        uint _20829 = _20825.y;
                                        float2 _20835 = (_20813 * float2(float(_20827), float(_20829))) - float2(0.5);
                                        int2 _20840 = int2(int(_20827), int(_20829)) - int2(1);
                                        float2 _20841 = rint(_20835);
                                        if (all(abs(_20835 - _20841) < float2(0.001953125)))
                                        {
                                            float4 _20856 = srcTex.read(uint2(int3(clamp(int2(_20841), int2(0), _20840), 0).xy), 0);
                                            float4 _36468;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _20865 = fast::clamp(_20856.xyz, float3(0.0), float3(1.0));
                                                float3 _20874 = select(powr((_20865 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20865 * float3(0.077399380505084991455078125), _20865 <= float3(0.040449999272823333740234375));
                                                float4 _34143 = _20856;
                                                _34143.x = _20874.x;
                                                _34143.y = _20874.y;
                                                _34143.z = _20874.z;
                                                _36468 = _34143;
                                            }
                                            else
                                            {
                                                _36468 = _20856;
                                            }
                                            _21050 = _36468;
                                            break;
                                        }
                                        float2 _20884 = fract(_20835);
                                        int2 _20886 = int2(floor(_20835));
                                        int2 _20887 = clamp(_20886, int2(0), _20840);
                                        int2 _20892 = clamp(_20886 + int2(1), int2(0), _20840);
                                        int _20894 = _20887.x;
                                        float4 _20902 = srcTex.read(uint2(int3(_20894, _20887.y, 0).xy), 0);
                                        bool _20905 = _6337 > 0.5;
                                        float4 _36455;
                                        if (_20905)
                                        {
                                            float3 _20911 = fast::clamp(_20902.xyz, float3(0.0), float3(1.0));
                                            float3 _20920 = select(powr((_20911 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20911 * float3(0.077399380505084991455078125), _20911 <= float3(0.040449999272823333740234375));
                                            float4 _34152 = _20902;
                                            _34152.x = _20920.x;
                                            _34152.y = _20920.y;
                                            _34152.z = _20920.z;
                                            _36455 = _34152;
                                        }
                                        else
                                        {
                                            _36455 = _20902;
                                        }
                                        int _20930 = _20892.x;
                                        float4 _20938 = srcTex.read(uint2(int3(_20930, _20887.y, 0).xy), 0);
                                        float4 _36458;
                                        if (_20905)
                                        {
                                            float3 _20947 = fast::clamp(_20938.xyz, float3(0.0), float3(1.0));
                                            float3 _20956 = select(powr((_20947 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20947 * float3(0.077399380505084991455078125), _20947 <= float3(0.040449999272823333740234375));
                                            float4 _34161 = _20938;
                                            _34161.x = _20956.x;
                                            _34161.y = _20956.y;
                                            _34161.z = _20956.z;
                                            _36458 = _34161;
                                        }
                                        else
                                        {
                                            _36458 = _20938;
                                        }
                                        float4 _20974 = srcTex.read(uint2(int3(_20894, _20892.y, 0).xy), 0);
                                        float4 _36461;
                                        if (_20905)
                                        {
                                            float3 _20983 = fast::clamp(_20974.xyz, float3(0.0), float3(1.0));
                                            float3 _20992 = select(powr((_20983 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20983 * float3(0.077399380505084991455078125), _20983 <= float3(0.040449999272823333740234375));
                                            float4 _34170 = _20974;
                                            _34170.x = _20992.x;
                                            _34170.y = _20992.y;
                                            _34170.z = _20992.z;
                                            _36461 = _34170;
                                        }
                                        else
                                        {
                                            _36461 = _20974;
                                        }
                                        float4 _21010 = srcTex.read(uint2(int3(_20930, _20892.y, 0).xy), 0);
                                        float4 _36463;
                                        if (_20905)
                                        {
                                            float3 _21019 = fast::clamp(_21010.xyz, float3(0.0), float3(1.0));
                                            float3 _21028 = select(powr((_21019 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _21019 * float3(0.077399380505084991455078125), _21019 <= float3(0.040449999272823333740234375));
                                            float4 _34179 = _21010;
                                            _34179.x = _21028.x;
                                            _34179.y = _21028.y;
                                            _34179.z = _21028.z;
                                            _36463 = _34179;
                                        }
                                        else
                                        {
                                            _36463 = _21010;
                                        }
                                        float4 _21039 = float4(_20884.x);
                                        _21050 = mix(mix(_36455, _36458, _21039), mix(_36461, _36463, _21039), float4(_20884.y));
                                        break;
                                    } while(false);
                                    float _21078;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _21078 = _21050.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _21078 = (_21050.x + _21050.y) * 0.5;
                                            break;
                                        }
                                        _21078 = _21050.x;
                                        break;
                                    } while(false);
                                    float _21106;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _21106 = _21050.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _21106 = _21050.x;
                                            break;
                                        }
                                        _21106 = _21050.y;
                                        break;
                                    } while(false);
                                    float _21117 = 2.0 / _395.g_srcW;
                                    float2 _21119 = _3574 + float2(_21117, 0.0);
                                    float4 _21356;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _21356 = srcTex.sample(samp, _21119, level(0.0));
                                            break;
                                        }
                                        uint2 _21131 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _21133 = _21131.x;
                                        uint _21135 = _21131.y;
                                        float2 _21141 = (_21119 * float2(float(_21133), float(_21135))) - float2(0.5);
                                        int2 _21146 = int2(int(_21133), int(_21135)) - int2(1);
                                        float2 _21147 = rint(_21141);
                                        if (all(abs(_21141 - _21147) < float2(0.001953125)))
                                        {
                                            float4 _21162 = srcTex.read(uint2(int3(clamp(int2(_21147), int2(0), _21146), 0).xy), 0);
                                            float4 _36482;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _21171 = fast::clamp(_21162.xyz, float3(0.0), float3(1.0));
                                                float3 _21180 = select(powr((_21171 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _21171 * float3(0.077399380505084991455078125), _21171 <= float3(0.040449999272823333740234375));
                                                float4 _34198 = _21162;
                                                _34198.x = _21180.x;
                                                _34198.y = _21180.y;
                                                _34198.z = _21180.z;
                                                _36482 = _34198;
                                            }
                                            else
                                            {
                                                _36482 = _21162;
                                            }
                                            _21356 = _36482;
                                            break;
                                        }
                                        float2 _21190 = fract(_21141);
                                        int2 _21192 = int2(floor(_21141));
                                        int2 _21193 = clamp(_21192, int2(0), _21146);
                                        int2 _21198 = clamp(_21192 + int2(1), int2(0), _21146);
                                        int _21200 = _21193.x;
                                        float4 _21208 = srcTex.read(uint2(int3(_21200, _21193.y, 0).xy), 0);
                                        bool _21211 = _6337 > 0.5;
                                        float4 _36469;
                                        if (_21211)
                                        {
                                            float3 _21217 = fast::clamp(_21208.xyz, float3(0.0), float3(1.0));
                                            float3 _21226 = select(powr((_21217 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _21217 * float3(0.077399380505084991455078125), _21217 <= float3(0.040449999272823333740234375));
                                            float4 _34207 = _21208;
                                            _34207.x = _21226.x;
                                            _34207.y = _21226.y;
                                            _34207.z = _21226.z;
                                            _36469 = _34207;
                                        }
                                        else
                                        {
                                            _36469 = _21208;
                                        }
                                        int _21236 = _21198.x;
                                        float4 _21244 = srcTex.read(uint2(int3(_21236, _21193.y, 0).xy), 0);
                                        float4 _36472;
                                        if (_21211)
                                        {
                                            float3 _21253 = fast::clamp(_21244.xyz, float3(0.0), float3(1.0));
                                            float3 _21262 = select(powr((_21253 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _21253 * float3(0.077399380505084991455078125), _21253 <= float3(0.040449999272823333740234375));
                                            float4 _34216 = _21244;
                                            _34216.x = _21262.x;
                                            _34216.y = _21262.y;
                                            _34216.z = _21262.z;
                                            _36472 = _34216;
                                        }
                                        else
                                        {
                                            _36472 = _21244;
                                        }
                                        float4 _21280 = srcTex.read(uint2(int3(_21200, _21198.y, 0).xy), 0);
                                        float4 _36475;
                                        if (_21211)
                                        {
                                            float3 _21289 = fast::clamp(_21280.xyz, float3(0.0), float3(1.0));
                                            float3 _21298 = select(powr((_21289 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _21289 * float3(0.077399380505084991455078125), _21289 <= float3(0.040449999272823333740234375));
                                            float4 _34225 = _21280;
                                            _34225.x = _21298.x;
                                            _34225.y = _21298.y;
                                            _34225.z = _21298.z;
                                            _36475 = _34225;
                                        }
                                        else
                                        {
                                            _36475 = _21280;
                                        }
                                        float4 _21316 = srcTex.read(uint2(int3(_21236, _21198.y, 0).xy), 0);
                                        float4 _36477;
                                        if (_21211)
                                        {
                                            float3 _21325 = fast::clamp(_21316.xyz, float3(0.0), float3(1.0));
                                            float3 _21334 = select(powr((_21325 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _21325 * float3(0.077399380505084991455078125), _21325 <= float3(0.040449999272823333740234375));
                                            float4 _34234 = _21316;
                                            _34234.x = _21334.x;
                                            _34234.y = _21334.y;
                                            _34234.z = _21334.z;
                                            _36477 = _34234;
                                        }
                                        else
                                        {
                                            _36477 = _21316;
                                        }
                                        float4 _21345 = float4(_21190.x);
                                        _21356 = mix(mix(_36469, _36472, _21345), mix(_36475, _36477, _21345), float4(_21190.y));
                                        break;
                                    } while(false);
                                    float _21384;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _21384 = _21356.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _21384 = (_21356.x + _21356.y) * 0.5;
                                            break;
                                        }
                                        _21384 = _21356.x;
                                        break;
                                    } while(false);
                                    float _21412;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _21412 = _21356.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _21412 = _21356.x;
                                            break;
                                        }
                                        _21412 = _21356.y;
                                        break;
                                    } while(false);
                                    float _7917 = _20466 - _13538;
                                    float _7927 = _20494 - _13540;
                                    float _20139 = _20772 - _20466;
                                    float _20146 = _20800 - _20494;
                                    float _20160 = _21078 - _20772;
                                    float _20167 = _21106 - _20800;
                                    float _20181 = _21384 - _21078;
                                    float _20188 = _21412 - _21106;
                                    bool _8363 = !_13391;
                                    float _8371 = (_8363 ? _7863.x : _7863.y) * _395.g_lvlToSrcX;
                                    float _8385 = _3592 + _8371;
                                    float2 _8394 = float2(_8385 + ((-5.0) / _395.g_srcW), in.i_uv.y);
                                    float4 _13520;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _13520 = srcTex.sample(samp, _8394, level(0.0));
                                            break;
                                        }
                                        uint2 _8624 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _8626 = _8624.x;
                                        uint _8628 = _8624.y;
                                        float2 _8637 = (_8394 * float2(float(_8626), float(_8628))) - float2(0.5);
                                        int2 _8644 = int2(int(_8626), int(_8628)) - int2(1);
                                        float2 _8646 = rint(_8637);
                                        if (all(abs(_8637 - _8646) < float2(0.001953125)))
                                        {
                                            float4 _8728 = srcTex.read(uint2(int3(clamp(int2(_8646), int2(0), _8644), 0).xy), 0);
                                            float4 _36496;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _8737 = fast::clamp(_8728.xyz, float3(0.0), float3(1.0));
                                                float3 _8760 = select(powr((_8737 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _8737 * float3(0.077399380505084991455078125), _8737 <= float3(0.040449999272823333740234375));
                                                float4 _34259 = _8728;
                                                _34259.x = _8760.x;
                                                _34259.y = _8760.y;
                                                _34259.z = _8760.z;
                                                _36496 = _34259;
                                            }
                                            else
                                            {
                                                _36496 = _8728;
                                            }
                                            _13520 = _36496;
                                            break;
                                        }
                                        float2 _8664 = fract(_8637);
                                        int2 _8667 = int2(floor(_8637));
                                        int2 _8669 = clamp(_8667, int2(0), _8644);
                                        int2 _8676 = clamp(_8667 + int2(1), int2(0), _8644);
                                        int _8678 = _8669.x;
                                        float4 _8770 = srcTex.read(uint2(int3(_8678, _8669.y, 0).xy), 0);
                                        bool _8773 = _6337 > 0.5;
                                        float4 _36483;
                                        if (_8773)
                                        {
                                            float3 _8779 = fast::clamp(_8770.xyz, float3(0.0), float3(1.0));
                                            float3 _8802 = select(powr((_8779 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _8779 * float3(0.077399380505084991455078125), _8779 <= float3(0.040449999272823333740234375));
                                            float4 _34268 = _8770;
                                            _34268.x = _8802.x;
                                            _34268.y = _8802.y;
                                            _34268.z = _8802.z;
                                            _36483 = _34268;
                                        }
                                        else
                                        {
                                            _36483 = _8770;
                                        }
                                        int _8684 = _8676.x;
                                        float4 _8812 = srcTex.read(uint2(int3(_8684, _8669.y, 0).xy), 0);
                                        float4 _36486;
                                        if (_8773)
                                        {
                                            float3 _8821 = fast::clamp(_8812.xyz, float3(0.0), float3(1.0));
                                            float3 _8844 = select(powr((_8821 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _8821 * float3(0.077399380505084991455078125), _8821 <= float3(0.040449999272823333740234375));
                                            float4 _34277 = _8812;
                                            _34277.x = _8844.x;
                                            _34277.y = _8844.y;
                                            _34277.z = _8844.z;
                                            _36486 = _34277;
                                        }
                                        else
                                        {
                                            _36486 = _8812;
                                        }
                                        float4 _8854 = srcTex.read(uint2(int3(_8678, _8676.y, 0).xy), 0);
                                        float4 _36489;
                                        if (_8773)
                                        {
                                            float3 _8863 = fast::clamp(_8854.xyz, float3(0.0), float3(1.0));
                                            float3 _8886 = select(powr((_8863 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _8863 * float3(0.077399380505084991455078125), _8863 <= float3(0.040449999272823333740234375));
                                            float4 _34286 = _8854;
                                            _34286.x = _8886.x;
                                            _34286.y = _8886.y;
                                            _34286.z = _8886.z;
                                            _36489 = _34286;
                                        }
                                        else
                                        {
                                            _36489 = _8854;
                                        }
                                        float4 _8896 = srcTex.read(uint2(int3(_8684, _8676.y, 0).xy), 0);
                                        float4 _36491;
                                        if (_8773)
                                        {
                                            float3 _8905 = fast::clamp(_8896.xyz, float3(0.0), float3(1.0));
                                            float3 _8928 = select(powr((_8905 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _8905 * float3(0.077399380505084991455078125), _8905 <= float3(0.040449999272823333740234375));
                                            float4 _34295 = _8896;
                                            _34295.x = _8928.x;
                                            _34295.y = _8928.y;
                                            _34295.z = _8928.z;
                                            _36491 = _34295;
                                        }
                                        else
                                        {
                                            _36491 = _8896;
                                        }
                                        float4 _8705 = float4(_8664.x);
                                        _13520 = mix(mix(_36483, _36486, _8705), mix(_36489, _36491, _8705), float4(_8664.y));
                                        break;
                                    } while(false);
                                    float _13527;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _13527 = _13520.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _13527 = (_13520.x + _13520.y) * 0.5;
                                            break;
                                        }
                                        _13527 = _13520.x;
                                        break;
                                    } while(false);
                                    float _13529;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _13529 = _13520.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _13529 = _13520.x;
                                            break;
                                        }
                                        _13529 = _13520.y;
                                        break;
                                    } while(false);
                                    float2 _17033 = float2(_8385 + ((-4.0) / _395.g_srcW), in.i_uv.y);
                                    float4 _17270;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _17270 = srcTex.sample(samp, _17033, level(0.0));
                                            break;
                                        }
                                        uint2 _17045 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _17047 = _17045.x;
                                        uint _17049 = _17045.y;
                                        float2 _17055 = (_17033 * float2(float(_17047), float(_17049))) - float2(0.5);
                                        int2 _17060 = int2(int(_17047), int(_17049)) - int2(1);
                                        float2 _17061 = rint(_17055);
                                        if (all(abs(_17055 - _17061) < float2(0.001953125)))
                                        {
                                            float4 _17076 = srcTex.read(uint2(int3(clamp(int2(_17061), int2(0), _17060), 0).xy), 0);
                                            float4 _36510;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _17085 = fast::clamp(_17076.xyz, float3(0.0), float3(1.0));
                                                float3 _17094 = select(powr((_17085 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17085 * float3(0.077399380505084991455078125), _17085 <= float3(0.040449999272823333740234375));
                                                float4 _34316 = _17076;
                                                _34316.x = _17094.x;
                                                _34316.y = _17094.y;
                                                _34316.z = _17094.z;
                                                _36510 = _34316;
                                            }
                                            else
                                            {
                                                _36510 = _17076;
                                            }
                                            _17270 = _36510;
                                            break;
                                        }
                                        float2 _17104 = fract(_17055);
                                        int2 _17106 = int2(floor(_17055));
                                        int2 _17107 = clamp(_17106, int2(0), _17060);
                                        int2 _17112 = clamp(_17106 + int2(1), int2(0), _17060);
                                        int _17114 = _17107.x;
                                        float4 _17122 = srcTex.read(uint2(int3(_17114, _17107.y, 0).xy), 0);
                                        bool _17125 = _6337 > 0.5;
                                        float4 _36497;
                                        if (_17125)
                                        {
                                            float3 _17131 = fast::clamp(_17122.xyz, float3(0.0), float3(1.0));
                                            float3 _17140 = select(powr((_17131 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17131 * float3(0.077399380505084991455078125), _17131 <= float3(0.040449999272823333740234375));
                                            float4 _34325 = _17122;
                                            _34325.x = _17140.x;
                                            _34325.y = _17140.y;
                                            _34325.z = _17140.z;
                                            _36497 = _34325;
                                        }
                                        else
                                        {
                                            _36497 = _17122;
                                        }
                                        int _17150 = _17112.x;
                                        float4 _17158 = srcTex.read(uint2(int3(_17150, _17107.y, 0).xy), 0);
                                        float4 _36500;
                                        if (_17125)
                                        {
                                            float3 _17167 = fast::clamp(_17158.xyz, float3(0.0), float3(1.0));
                                            float3 _17176 = select(powr((_17167 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17167 * float3(0.077399380505084991455078125), _17167 <= float3(0.040449999272823333740234375));
                                            float4 _34334 = _17158;
                                            _34334.x = _17176.x;
                                            _34334.y = _17176.y;
                                            _34334.z = _17176.z;
                                            _36500 = _34334;
                                        }
                                        else
                                        {
                                            _36500 = _17158;
                                        }
                                        float4 _17194 = srcTex.read(uint2(int3(_17114, _17112.y, 0).xy), 0);
                                        float4 _36503;
                                        if (_17125)
                                        {
                                            float3 _17203 = fast::clamp(_17194.xyz, float3(0.0), float3(1.0));
                                            float3 _17212 = select(powr((_17203 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17203 * float3(0.077399380505084991455078125), _17203 <= float3(0.040449999272823333740234375));
                                            float4 _34343 = _17194;
                                            _34343.x = _17212.x;
                                            _34343.y = _17212.y;
                                            _34343.z = _17212.z;
                                            _36503 = _34343;
                                        }
                                        else
                                        {
                                            _36503 = _17194;
                                        }
                                        float4 _17230 = srcTex.read(uint2(int3(_17150, _17112.y, 0).xy), 0);
                                        float4 _36505;
                                        if (_17125)
                                        {
                                            float3 _17239 = fast::clamp(_17230.xyz, float3(0.0), float3(1.0));
                                            float3 _17248 = select(powr((_17239 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17239 * float3(0.077399380505084991455078125), _17239 <= float3(0.040449999272823333740234375));
                                            float4 _34352 = _17230;
                                            _34352.x = _17248.x;
                                            _34352.y = _17248.y;
                                            _34352.z = _17248.z;
                                            _36505 = _34352;
                                        }
                                        else
                                        {
                                            _36505 = _17230;
                                        }
                                        float4 _17259 = float4(_17104.x);
                                        _17270 = mix(mix(_36497, _36500, _17259), mix(_36503, _36505, _17259), float4(_17104.y));
                                        break;
                                    } while(false);
                                    float _17298;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _17298 = _17270.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _17298 = (_17270.x + _17270.y) * 0.5;
                                            break;
                                        }
                                        _17298 = _17270.x;
                                        break;
                                    } while(false);
                                    float _17326;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _17326 = _17270.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _17326 = _17270.x;
                                            break;
                                        }
                                        _17326 = _17270.y;
                                        break;
                                    } while(false);
                                    float2 _17344 = float2(_8385 + ((-3.0) / _395.g_srcW), in.i_uv.y);
                                    float4 _17581;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _17581 = srcTex.sample(samp, _17344, level(0.0));
                                            break;
                                        }
                                        uint2 _17356 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _17358 = _17356.x;
                                        uint _17360 = _17356.y;
                                        float2 _17366 = (_17344 * float2(float(_17358), float(_17360))) - float2(0.5);
                                        int2 _17371 = int2(int(_17358), int(_17360)) - int2(1);
                                        float2 _17372 = rint(_17366);
                                        if (all(abs(_17366 - _17372) < float2(0.001953125)))
                                        {
                                            float4 _17387 = srcTex.read(uint2(int3(clamp(int2(_17372), int2(0), _17371), 0).xy), 0);
                                            float4 _36524;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _17396 = fast::clamp(_17387.xyz, float3(0.0), float3(1.0));
                                                float3 _17405 = select(powr((_17396 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17396 * float3(0.077399380505084991455078125), _17396 <= float3(0.040449999272823333740234375));
                                                float4 _34373 = _17387;
                                                _34373.x = _17405.x;
                                                _34373.y = _17405.y;
                                                _34373.z = _17405.z;
                                                _36524 = _34373;
                                            }
                                            else
                                            {
                                                _36524 = _17387;
                                            }
                                            _17581 = _36524;
                                            break;
                                        }
                                        float2 _17415 = fract(_17366);
                                        int2 _17417 = int2(floor(_17366));
                                        int2 _17418 = clamp(_17417, int2(0), _17371);
                                        int2 _17423 = clamp(_17417 + int2(1), int2(0), _17371);
                                        int _17425 = _17418.x;
                                        float4 _17433 = srcTex.read(uint2(int3(_17425, _17418.y, 0).xy), 0);
                                        bool _17436 = _6337 > 0.5;
                                        float4 _36511;
                                        if (_17436)
                                        {
                                            float3 _17442 = fast::clamp(_17433.xyz, float3(0.0), float3(1.0));
                                            float3 _17451 = select(powr((_17442 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17442 * float3(0.077399380505084991455078125), _17442 <= float3(0.040449999272823333740234375));
                                            float4 _34382 = _17433;
                                            _34382.x = _17451.x;
                                            _34382.y = _17451.y;
                                            _34382.z = _17451.z;
                                            _36511 = _34382;
                                        }
                                        else
                                        {
                                            _36511 = _17433;
                                        }
                                        int _17461 = _17423.x;
                                        float4 _17469 = srcTex.read(uint2(int3(_17461, _17418.y, 0).xy), 0);
                                        float4 _36514;
                                        if (_17436)
                                        {
                                            float3 _17478 = fast::clamp(_17469.xyz, float3(0.0), float3(1.0));
                                            float3 _17487 = select(powr((_17478 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17478 * float3(0.077399380505084991455078125), _17478 <= float3(0.040449999272823333740234375));
                                            float4 _34391 = _17469;
                                            _34391.x = _17487.x;
                                            _34391.y = _17487.y;
                                            _34391.z = _17487.z;
                                            _36514 = _34391;
                                        }
                                        else
                                        {
                                            _36514 = _17469;
                                        }
                                        float4 _17505 = srcTex.read(uint2(int3(_17425, _17423.y, 0).xy), 0);
                                        float4 _36517;
                                        if (_17436)
                                        {
                                            float3 _17514 = fast::clamp(_17505.xyz, float3(0.0), float3(1.0));
                                            float3 _17523 = select(powr((_17514 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17514 * float3(0.077399380505084991455078125), _17514 <= float3(0.040449999272823333740234375));
                                            float4 _34400 = _17505;
                                            _34400.x = _17523.x;
                                            _34400.y = _17523.y;
                                            _34400.z = _17523.z;
                                            _36517 = _34400;
                                        }
                                        else
                                        {
                                            _36517 = _17505;
                                        }
                                        float4 _17541 = srcTex.read(uint2(int3(_17461, _17423.y, 0).xy), 0);
                                        float4 _36519;
                                        if (_17436)
                                        {
                                            float3 _17550 = fast::clamp(_17541.xyz, float3(0.0), float3(1.0));
                                            float3 _17559 = select(powr((_17550 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17550 * float3(0.077399380505084991455078125), _17550 <= float3(0.040449999272823333740234375));
                                            float4 _34409 = _17541;
                                            _34409.x = _17559.x;
                                            _34409.y = _17559.y;
                                            _34409.z = _17559.z;
                                            _36519 = _34409;
                                        }
                                        else
                                        {
                                            _36519 = _17541;
                                        }
                                        float4 _17570 = float4(_17415.x);
                                        _17581 = mix(mix(_36511, _36514, _17570), mix(_36517, _36519, _17570), float4(_17415.y));
                                        break;
                                    } while(false);
                                    float _17609;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _17609 = _17581.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _17609 = (_17581.x + _17581.y) * 0.5;
                                            break;
                                        }
                                        _17609 = _17581.x;
                                        break;
                                    } while(false);
                                    float _17637;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _17637 = _17581.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _17637 = _17581.x;
                                            break;
                                        }
                                        _17637 = _17581.y;
                                        break;
                                    } while(false);
                                    float2 _17655 = float2(_8385 + _7886, in.i_uv.y);
                                    float4 _17892;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _17892 = srcTex.sample(samp, _17655, level(0.0));
                                            break;
                                        }
                                        uint2 _17667 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _17669 = _17667.x;
                                        uint _17671 = _17667.y;
                                        float2 _17677 = (_17655 * float2(float(_17669), float(_17671))) - float2(0.5);
                                        int2 _17682 = int2(int(_17669), int(_17671)) - int2(1);
                                        float2 _17683 = rint(_17677);
                                        if (all(abs(_17677 - _17683) < float2(0.001953125)))
                                        {
                                            float4 _17698 = srcTex.read(uint2(int3(clamp(int2(_17683), int2(0), _17682), 0).xy), 0);
                                            float4 _36538;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _17707 = fast::clamp(_17698.xyz, float3(0.0), float3(1.0));
                                                float3 _17716 = select(powr((_17707 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17707 * float3(0.077399380505084991455078125), _17707 <= float3(0.040449999272823333740234375));
                                                float4 _34430 = _17698;
                                                _34430.x = _17716.x;
                                                _34430.y = _17716.y;
                                                _34430.z = _17716.z;
                                                _36538 = _34430;
                                            }
                                            else
                                            {
                                                _36538 = _17698;
                                            }
                                            _17892 = _36538;
                                            break;
                                        }
                                        float2 _17726 = fract(_17677);
                                        int2 _17728 = int2(floor(_17677));
                                        int2 _17729 = clamp(_17728, int2(0), _17682);
                                        int2 _17734 = clamp(_17728 + int2(1), int2(0), _17682);
                                        int _17736 = _17729.x;
                                        float4 _17744 = srcTex.read(uint2(int3(_17736, _17729.y, 0).xy), 0);
                                        bool _17747 = _6337 > 0.5;
                                        float4 _36525;
                                        if (_17747)
                                        {
                                            float3 _17753 = fast::clamp(_17744.xyz, float3(0.0), float3(1.0));
                                            float3 _17762 = select(powr((_17753 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17753 * float3(0.077399380505084991455078125), _17753 <= float3(0.040449999272823333740234375));
                                            float4 _34439 = _17744;
                                            _34439.x = _17762.x;
                                            _34439.y = _17762.y;
                                            _34439.z = _17762.z;
                                            _36525 = _34439;
                                        }
                                        else
                                        {
                                            _36525 = _17744;
                                        }
                                        int _17772 = _17734.x;
                                        float4 _17780 = srcTex.read(uint2(int3(_17772, _17729.y, 0).xy), 0);
                                        float4 _36528;
                                        if (_17747)
                                        {
                                            float3 _17789 = fast::clamp(_17780.xyz, float3(0.0), float3(1.0));
                                            float3 _17798 = select(powr((_17789 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17789 * float3(0.077399380505084991455078125), _17789 <= float3(0.040449999272823333740234375));
                                            float4 _34448 = _17780;
                                            _34448.x = _17798.x;
                                            _34448.y = _17798.y;
                                            _34448.z = _17798.z;
                                            _36528 = _34448;
                                        }
                                        else
                                        {
                                            _36528 = _17780;
                                        }
                                        float4 _17816 = srcTex.read(uint2(int3(_17736, _17734.y, 0).xy), 0);
                                        float4 _36531;
                                        if (_17747)
                                        {
                                            float3 _17825 = fast::clamp(_17816.xyz, float3(0.0), float3(1.0));
                                            float3 _17834 = select(powr((_17825 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17825 * float3(0.077399380505084991455078125), _17825 <= float3(0.040449999272823333740234375));
                                            float4 _34457 = _17816;
                                            _34457.x = _17834.x;
                                            _34457.y = _17834.y;
                                            _34457.z = _17834.z;
                                            _36531 = _34457;
                                        }
                                        else
                                        {
                                            _36531 = _17816;
                                        }
                                        float4 _17852 = srcTex.read(uint2(int3(_17772, _17734.y, 0).xy), 0);
                                        float4 _36533;
                                        if (_17747)
                                        {
                                            float3 _17861 = fast::clamp(_17852.xyz, float3(0.0), float3(1.0));
                                            float3 _17870 = select(powr((_17861 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _17861 * float3(0.077399380505084991455078125), _17861 <= float3(0.040449999272823333740234375));
                                            float4 _34466 = _17852;
                                            _34466.x = _17870.x;
                                            _34466.y = _17870.y;
                                            _34466.z = _17870.z;
                                            _36533 = _34466;
                                        }
                                        else
                                        {
                                            _36533 = _17852;
                                        }
                                        float4 _17881 = float4(_17726.x);
                                        _17892 = mix(mix(_36525, _36528, _17881), mix(_36531, _36533, _17881), float4(_17726.y));
                                        break;
                                    } while(false);
                                    float _17920;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _17920 = _17892.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _17920 = (_17892.x + _17892.y) * 0.5;
                                            break;
                                        }
                                        _17920 = _17892.x;
                                        break;
                                    } while(false);
                                    float _17948;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _17948 = _17892.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _17948 = _17892.x;
                                            break;
                                        }
                                        _17948 = _17892.y;
                                        break;
                                    } while(false);
                                    float2 _17966 = float2(_8385 + _20199, in.i_uv.y);
                                    float4 _18203;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _18203 = srcTex.sample(samp, _17966, level(0.0));
                                            break;
                                        }
                                        uint2 _17978 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _17980 = _17978.x;
                                        uint _17982 = _17978.y;
                                        float2 _17988 = (_17966 * float2(float(_17980), float(_17982))) - float2(0.5);
                                        int2 _17993 = int2(int(_17980), int(_17982)) - int2(1);
                                        float2 _17994 = rint(_17988);
                                        if (all(abs(_17988 - _17994) < float2(0.001953125)))
                                        {
                                            float4 _18009 = srcTex.read(uint2(int3(clamp(int2(_17994), int2(0), _17993), 0).xy), 0);
                                            float4 _36552;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _18018 = fast::clamp(_18009.xyz, float3(0.0), float3(1.0));
                                                float3 _18027 = select(powr((_18018 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18018 * float3(0.077399380505084991455078125), _18018 <= float3(0.040449999272823333740234375));
                                                float4 _34487 = _18009;
                                                _34487.x = _18027.x;
                                                _34487.y = _18027.y;
                                                _34487.z = _18027.z;
                                                _36552 = _34487;
                                            }
                                            else
                                            {
                                                _36552 = _18009;
                                            }
                                            _18203 = _36552;
                                            break;
                                        }
                                        float2 _18037 = fract(_17988);
                                        int2 _18039 = int2(floor(_17988));
                                        int2 _18040 = clamp(_18039, int2(0), _17993);
                                        int2 _18045 = clamp(_18039 + int2(1), int2(0), _17993);
                                        int _18047 = _18040.x;
                                        float4 _18055 = srcTex.read(uint2(int3(_18047, _18040.y, 0).xy), 0);
                                        bool _18058 = _6337 > 0.5;
                                        float4 _36539;
                                        if (_18058)
                                        {
                                            float3 _18064 = fast::clamp(_18055.xyz, float3(0.0), float3(1.0));
                                            float3 _18073 = select(powr((_18064 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18064 * float3(0.077399380505084991455078125), _18064 <= float3(0.040449999272823333740234375));
                                            float4 _34496 = _18055;
                                            _34496.x = _18073.x;
                                            _34496.y = _18073.y;
                                            _34496.z = _18073.z;
                                            _36539 = _34496;
                                        }
                                        else
                                        {
                                            _36539 = _18055;
                                        }
                                        int _18083 = _18045.x;
                                        float4 _18091 = srcTex.read(uint2(int3(_18083, _18040.y, 0).xy), 0);
                                        float4 _36542;
                                        if (_18058)
                                        {
                                            float3 _18100 = fast::clamp(_18091.xyz, float3(0.0), float3(1.0));
                                            float3 _18109 = select(powr((_18100 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18100 * float3(0.077399380505084991455078125), _18100 <= float3(0.040449999272823333740234375));
                                            float4 _34505 = _18091;
                                            _34505.x = _18109.x;
                                            _34505.y = _18109.y;
                                            _34505.z = _18109.z;
                                            _36542 = _34505;
                                        }
                                        else
                                        {
                                            _36542 = _18091;
                                        }
                                        float4 _18127 = srcTex.read(uint2(int3(_18047, _18045.y, 0).xy), 0);
                                        float4 _36545;
                                        if (_18058)
                                        {
                                            float3 _18136 = fast::clamp(_18127.xyz, float3(0.0), float3(1.0));
                                            float3 _18145 = select(powr((_18136 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18136 * float3(0.077399380505084991455078125), _18136 <= float3(0.040449999272823333740234375));
                                            float4 _34514 = _18127;
                                            _34514.x = _18145.x;
                                            _34514.y = _18145.y;
                                            _34514.z = _18145.z;
                                            _36545 = _34514;
                                        }
                                        else
                                        {
                                            _36545 = _18127;
                                        }
                                        float4 _18163 = srcTex.read(uint2(int3(_18083, _18045.y, 0).xy), 0);
                                        float4 _36547;
                                        if (_18058)
                                        {
                                            float3 _18172 = fast::clamp(_18163.xyz, float3(0.0), float3(1.0));
                                            float3 _18181 = select(powr((_18172 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18172 * float3(0.077399380505084991455078125), _18172 <= float3(0.040449999272823333740234375));
                                            float4 _34523 = _18163;
                                            _34523.x = _18181.x;
                                            _34523.y = _18181.y;
                                            _34523.z = _18181.z;
                                            _36547 = _34523;
                                        }
                                        else
                                        {
                                            _36547 = _18163;
                                        }
                                        float4 _18192 = float4(_18037.x);
                                        _18203 = mix(mix(_36539, _36542, _18192), mix(_36545, _36547, _18192), float4(_18037.y));
                                        break;
                                    } while(false);
                                    float _18231;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _18231 = _18203.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _18231 = (_18203.x + _18203.y) * 0.5;
                                            break;
                                        }
                                        _18231 = _18203.x;
                                        break;
                                    } while(false);
                                    float _18259;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _18259 = _18203.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _18259 = _18203.x;
                                            break;
                                        }
                                        _18259 = _18203.y;
                                        break;
                                    } while(false);
                                    float2 _18277 = float2(_8385, in.i_uv.y);
                                    float4 _18514;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _18514 = srcTex.sample(samp, _18277, level(0.0));
                                            break;
                                        }
                                        uint2 _18289 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _18291 = _18289.x;
                                        uint _18293 = _18289.y;
                                        float2 _18299 = (_18277 * float2(float(_18291), float(_18293))) - float2(0.5);
                                        int2 _18304 = int2(int(_18291), int(_18293)) - int2(1);
                                        float2 _18305 = rint(_18299);
                                        if (all(abs(_18299 - _18305) < float2(0.001953125)))
                                        {
                                            float4 _18320 = srcTex.read(uint2(int3(clamp(int2(_18305), int2(0), _18304), 0).xy), 0);
                                            float4 _36566;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _18329 = fast::clamp(_18320.xyz, float3(0.0), float3(1.0));
                                                float3 _18338 = select(powr((_18329 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18329 * float3(0.077399380505084991455078125), _18329 <= float3(0.040449999272823333740234375));
                                                float4 _34544 = _18320;
                                                _34544.x = _18338.x;
                                                _34544.y = _18338.y;
                                                _34544.z = _18338.z;
                                                _36566 = _34544;
                                            }
                                            else
                                            {
                                                _36566 = _18320;
                                            }
                                            _18514 = _36566;
                                            break;
                                        }
                                        float2 _18348 = fract(_18299);
                                        int2 _18350 = int2(floor(_18299));
                                        int2 _18351 = clamp(_18350, int2(0), _18304);
                                        int2 _18356 = clamp(_18350 + int2(1), int2(0), _18304);
                                        int _18358 = _18351.x;
                                        float4 _18366 = srcTex.read(uint2(int3(_18358, _18351.y, 0).xy), 0);
                                        bool _18369 = _6337 > 0.5;
                                        float4 _36553;
                                        if (_18369)
                                        {
                                            float3 _18375 = fast::clamp(_18366.xyz, float3(0.0), float3(1.0));
                                            float3 _18384 = select(powr((_18375 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18375 * float3(0.077399380505084991455078125), _18375 <= float3(0.040449999272823333740234375));
                                            float4 _34553 = _18366;
                                            _34553.x = _18384.x;
                                            _34553.y = _18384.y;
                                            _34553.z = _18384.z;
                                            _36553 = _34553;
                                        }
                                        else
                                        {
                                            _36553 = _18366;
                                        }
                                        int _18394 = _18356.x;
                                        float4 _18402 = srcTex.read(uint2(int3(_18394, _18351.y, 0).xy), 0);
                                        float4 _36556;
                                        if (_18369)
                                        {
                                            float3 _18411 = fast::clamp(_18402.xyz, float3(0.0), float3(1.0));
                                            float3 _18420 = select(powr((_18411 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18411 * float3(0.077399380505084991455078125), _18411 <= float3(0.040449999272823333740234375));
                                            float4 _34562 = _18402;
                                            _34562.x = _18420.x;
                                            _34562.y = _18420.y;
                                            _34562.z = _18420.z;
                                            _36556 = _34562;
                                        }
                                        else
                                        {
                                            _36556 = _18402;
                                        }
                                        float4 _18438 = srcTex.read(uint2(int3(_18358, _18356.y, 0).xy), 0);
                                        float4 _36559;
                                        if (_18369)
                                        {
                                            float3 _18447 = fast::clamp(_18438.xyz, float3(0.0), float3(1.0));
                                            float3 _18456 = select(powr((_18447 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18447 * float3(0.077399380505084991455078125), _18447 <= float3(0.040449999272823333740234375));
                                            float4 _34571 = _18438;
                                            _34571.x = _18456.x;
                                            _34571.y = _18456.y;
                                            _34571.z = _18456.z;
                                            _36559 = _34571;
                                        }
                                        else
                                        {
                                            _36559 = _18438;
                                        }
                                        float4 _18474 = srcTex.read(uint2(int3(_18394, _18356.y, 0).xy), 0);
                                        float4 _36561;
                                        if (_18369)
                                        {
                                            float3 _18483 = fast::clamp(_18474.xyz, float3(0.0), float3(1.0));
                                            float3 _18492 = select(powr((_18483 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18483 * float3(0.077399380505084991455078125), _18483 <= float3(0.040449999272823333740234375));
                                            float4 _34580 = _18474;
                                            _34580.x = _18492.x;
                                            _34580.y = _18492.y;
                                            _34580.z = _18492.z;
                                            _36561 = _34580;
                                        }
                                        else
                                        {
                                            _36561 = _18474;
                                        }
                                        float4 _18503 = float4(_18348.x);
                                        _18514 = mix(mix(_36553, _36556, _18503), mix(_36559, _36561, _18503), float4(_18348.y));
                                        break;
                                    } while(false);
                                    float _18542;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _18542 = _18514.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _18542 = (_18514.x + _18514.y) * 0.5;
                                            break;
                                        }
                                        _18542 = _18514.x;
                                        break;
                                    } while(false);
                                    float _18570;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _18570 = _18514.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _18570 = _18514.x;
                                            break;
                                        }
                                        _18570 = _18514.y;
                                        break;
                                    } while(false);
                                    float2 _18588 = float2(_8385 + _4101, in.i_uv.y);
                                    float4 _18825;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _18825 = srcTex.sample(samp, _18588, level(0.0));
                                            break;
                                        }
                                        uint2 _18600 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _18602 = _18600.x;
                                        uint _18604 = _18600.y;
                                        float2 _18610 = (_18588 * float2(float(_18602), float(_18604))) - float2(0.5);
                                        int2 _18615 = int2(int(_18602), int(_18604)) - int2(1);
                                        float2 _18616 = rint(_18610);
                                        if (all(abs(_18610 - _18616) < float2(0.001953125)))
                                        {
                                            float4 _18631 = srcTex.read(uint2(int3(clamp(int2(_18616), int2(0), _18615), 0).xy), 0);
                                            float4 _36580;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _18640 = fast::clamp(_18631.xyz, float3(0.0), float3(1.0));
                                                float3 _18649 = select(powr((_18640 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18640 * float3(0.077399380505084991455078125), _18640 <= float3(0.040449999272823333740234375));
                                                float4 _34601 = _18631;
                                                _34601.x = _18649.x;
                                                _34601.y = _18649.y;
                                                _34601.z = _18649.z;
                                                _36580 = _34601;
                                            }
                                            else
                                            {
                                                _36580 = _18631;
                                            }
                                            _18825 = _36580;
                                            break;
                                        }
                                        float2 _18659 = fract(_18610);
                                        int2 _18661 = int2(floor(_18610));
                                        int2 _18662 = clamp(_18661, int2(0), _18615);
                                        int2 _18667 = clamp(_18661 + int2(1), int2(0), _18615);
                                        int _18669 = _18662.x;
                                        float4 _18677 = srcTex.read(uint2(int3(_18669, _18662.y, 0).xy), 0);
                                        bool _18680 = _6337 > 0.5;
                                        float4 _36567;
                                        if (_18680)
                                        {
                                            float3 _18686 = fast::clamp(_18677.xyz, float3(0.0), float3(1.0));
                                            float3 _18695 = select(powr((_18686 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18686 * float3(0.077399380505084991455078125), _18686 <= float3(0.040449999272823333740234375));
                                            float4 _34610 = _18677;
                                            _34610.x = _18695.x;
                                            _34610.y = _18695.y;
                                            _34610.z = _18695.z;
                                            _36567 = _34610;
                                        }
                                        else
                                        {
                                            _36567 = _18677;
                                        }
                                        int _18705 = _18667.x;
                                        float4 _18713 = srcTex.read(uint2(int3(_18705, _18662.y, 0).xy), 0);
                                        float4 _36570;
                                        if (_18680)
                                        {
                                            float3 _18722 = fast::clamp(_18713.xyz, float3(0.0), float3(1.0));
                                            float3 _18731 = select(powr((_18722 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18722 * float3(0.077399380505084991455078125), _18722 <= float3(0.040449999272823333740234375));
                                            float4 _34619 = _18713;
                                            _34619.x = _18731.x;
                                            _34619.y = _18731.y;
                                            _34619.z = _18731.z;
                                            _36570 = _34619;
                                        }
                                        else
                                        {
                                            _36570 = _18713;
                                        }
                                        float4 _18749 = srcTex.read(uint2(int3(_18669, _18667.y, 0).xy), 0);
                                        float4 _36573;
                                        if (_18680)
                                        {
                                            float3 _18758 = fast::clamp(_18749.xyz, float3(0.0), float3(1.0));
                                            float3 _18767 = select(powr((_18758 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18758 * float3(0.077399380505084991455078125), _18758 <= float3(0.040449999272823333740234375));
                                            float4 _34628 = _18749;
                                            _34628.x = _18767.x;
                                            _34628.y = _18767.y;
                                            _34628.z = _18767.z;
                                            _36573 = _34628;
                                        }
                                        else
                                        {
                                            _36573 = _18749;
                                        }
                                        float4 _18785 = srcTex.read(uint2(int3(_18705, _18667.y, 0).xy), 0);
                                        float4 _36575;
                                        if (_18680)
                                        {
                                            float3 _18794 = fast::clamp(_18785.xyz, float3(0.0), float3(1.0));
                                            float3 _18803 = select(powr((_18794 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18794 * float3(0.077399380505084991455078125), _18794 <= float3(0.040449999272823333740234375));
                                            float4 _34637 = _18785;
                                            _34637.x = _18803.x;
                                            _34637.y = _18803.y;
                                            _34637.z = _18803.z;
                                            _36575 = _34637;
                                        }
                                        else
                                        {
                                            _36575 = _18785;
                                        }
                                        float4 _18814 = float4(_18659.x);
                                        _18825 = mix(mix(_36567, _36570, _18814), mix(_36573, _36575, _18814), float4(_18659.y));
                                        break;
                                    } while(false);
                                    float _18853;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _18853 = _18825.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _18853 = (_18825.x + _18825.y) * 0.5;
                                            break;
                                        }
                                        _18853 = _18825.x;
                                        break;
                                    } while(false);
                                    float _18881;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _18881 = _18825.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _18881 = _18825.x;
                                            break;
                                        }
                                        _18881 = _18825.y;
                                        break;
                                    } while(false);
                                    float2 _18899 = float2(_8385 + _21117, in.i_uv.y);
                                    float4 _19136;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _19136 = srcTex.sample(samp, _18899, level(0.0));
                                            break;
                                        }
                                        uint2 _18911 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _18913 = _18911.x;
                                        uint _18915 = _18911.y;
                                        float2 _18921 = (_18899 * float2(float(_18913), float(_18915))) - float2(0.5);
                                        int2 _18926 = int2(int(_18913), int(_18915)) - int2(1);
                                        float2 _18927 = rint(_18921);
                                        if (all(abs(_18921 - _18927) < float2(0.001953125)))
                                        {
                                            float4 _18942 = srcTex.read(uint2(int3(clamp(int2(_18927), int2(0), _18926), 0).xy), 0);
                                            float4 _36594;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _18951 = fast::clamp(_18942.xyz, float3(0.0), float3(1.0));
                                                float3 _18960 = select(powr((_18951 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18951 * float3(0.077399380505084991455078125), _18951 <= float3(0.040449999272823333740234375));
                                                float4 _34658 = _18942;
                                                _34658.x = _18960.x;
                                                _34658.y = _18960.y;
                                                _34658.z = _18960.z;
                                                _36594 = _34658;
                                            }
                                            else
                                            {
                                                _36594 = _18942;
                                            }
                                            _19136 = _36594;
                                            break;
                                        }
                                        float2 _18970 = fract(_18921);
                                        int2 _18972 = int2(floor(_18921));
                                        int2 _18973 = clamp(_18972, int2(0), _18926);
                                        int2 _18978 = clamp(_18972 + int2(1), int2(0), _18926);
                                        int _18980 = _18973.x;
                                        float4 _18988 = srcTex.read(uint2(int3(_18980, _18973.y, 0).xy), 0);
                                        bool _18991 = _6337 > 0.5;
                                        float4 _36581;
                                        if (_18991)
                                        {
                                            float3 _18997 = fast::clamp(_18988.xyz, float3(0.0), float3(1.0));
                                            float3 _19006 = select(powr((_18997 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _18997 * float3(0.077399380505084991455078125), _18997 <= float3(0.040449999272823333740234375));
                                            float4 _34667 = _18988;
                                            _34667.x = _19006.x;
                                            _34667.y = _19006.y;
                                            _34667.z = _19006.z;
                                            _36581 = _34667;
                                        }
                                        else
                                        {
                                            _36581 = _18988;
                                        }
                                        int _19016 = _18978.x;
                                        float4 _19024 = srcTex.read(uint2(int3(_19016, _18973.y, 0).xy), 0);
                                        float4 _36584;
                                        if (_18991)
                                        {
                                            float3 _19033 = fast::clamp(_19024.xyz, float3(0.0), float3(1.0));
                                            float3 _19042 = select(powr((_19033 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19033 * float3(0.077399380505084991455078125), _19033 <= float3(0.040449999272823333740234375));
                                            float4 _34676 = _19024;
                                            _34676.x = _19042.x;
                                            _34676.y = _19042.y;
                                            _34676.z = _19042.z;
                                            _36584 = _34676;
                                        }
                                        else
                                        {
                                            _36584 = _19024;
                                        }
                                        float4 _19060 = srcTex.read(uint2(int3(_18980, _18978.y, 0).xy), 0);
                                        float4 _36587;
                                        if (_18991)
                                        {
                                            float3 _19069 = fast::clamp(_19060.xyz, float3(0.0), float3(1.0));
                                            float3 _19078 = select(powr((_19069 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19069 * float3(0.077399380505084991455078125), _19069 <= float3(0.040449999272823333740234375));
                                            float4 _34685 = _19060;
                                            _34685.x = _19078.x;
                                            _34685.y = _19078.y;
                                            _34685.z = _19078.z;
                                            _36587 = _34685;
                                        }
                                        else
                                        {
                                            _36587 = _19060;
                                        }
                                        float4 _19096 = srcTex.read(uint2(int3(_19016, _18978.y, 0).xy), 0);
                                        float4 _36589;
                                        if (_18991)
                                        {
                                            float3 _19105 = fast::clamp(_19096.xyz, float3(0.0), float3(1.0));
                                            float3 _19114 = select(powr((_19105 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19105 * float3(0.077399380505084991455078125), _19105 <= float3(0.040449999272823333740234375));
                                            float4 _34694 = _19096;
                                            _34694.x = _19114.x;
                                            _34694.y = _19114.y;
                                            _34694.z = _19114.z;
                                            _36589 = _34694;
                                        }
                                        else
                                        {
                                            _36589 = _19096;
                                        }
                                        float4 _19125 = float4(_18970.x);
                                        _19136 = mix(mix(_36581, _36584, _19125), mix(_36587, _36589, _19125), float4(_18970.y));
                                        break;
                                    } while(false);
                                    float _19164;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _19164 = _19136.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _19164 = (_19136.x + _19136.y) * 0.5;
                                            break;
                                        }
                                        _19164 = _19136.x;
                                        break;
                                    } while(false);
                                    float _19192;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _19192 = _19136.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _19192 = _19136.x;
                                            break;
                                        }
                                        _19192 = _19136.y;
                                        break;
                                    } while(false);
                                    float2 _19210 = float2(_8385 + (3.0 / _395.g_srcW), in.i_uv.y);
                                    float4 _19447;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _19447 = srcTex.sample(samp, _19210, level(0.0));
                                            break;
                                        }
                                        uint2 _19222 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _19224 = _19222.x;
                                        uint _19226 = _19222.y;
                                        float2 _19232 = (_19210 * float2(float(_19224), float(_19226))) - float2(0.5);
                                        int2 _19237 = int2(int(_19224), int(_19226)) - int2(1);
                                        float2 _19238 = rint(_19232);
                                        if (all(abs(_19232 - _19238) < float2(0.001953125)))
                                        {
                                            float4 _19253 = srcTex.read(uint2(int3(clamp(int2(_19238), int2(0), _19237), 0).xy), 0);
                                            float4 _36608;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _19262 = fast::clamp(_19253.xyz, float3(0.0), float3(1.0));
                                                float3 _19271 = select(powr((_19262 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19262 * float3(0.077399380505084991455078125), _19262 <= float3(0.040449999272823333740234375));
                                                float4 _34715 = _19253;
                                                _34715.x = _19271.x;
                                                _34715.y = _19271.y;
                                                _34715.z = _19271.z;
                                                _36608 = _34715;
                                            }
                                            else
                                            {
                                                _36608 = _19253;
                                            }
                                            _19447 = _36608;
                                            break;
                                        }
                                        float2 _19281 = fract(_19232);
                                        int2 _19283 = int2(floor(_19232));
                                        int2 _19284 = clamp(_19283, int2(0), _19237);
                                        int2 _19289 = clamp(_19283 + int2(1), int2(0), _19237);
                                        int _19291 = _19284.x;
                                        float4 _19299 = srcTex.read(uint2(int3(_19291, _19284.y, 0).xy), 0);
                                        bool _19302 = _6337 > 0.5;
                                        float4 _36595;
                                        if (_19302)
                                        {
                                            float3 _19308 = fast::clamp(_19299.xyz, float3(0.0), float3(1.0));
                                            float3 _19317 = select(powr((_19308 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19308 * float3(0.077399380505084991455078125), _19308 <= float3(0.040449999272823333740234375));
                                            float4 _34724 = _19299;
                                            _34724.x = _19317.x;
                                            _34724.y = _19317.y;
                                            _34724.z = _19317.z;
                                            _36595 = _34724;
                                        }
                                        else
                                        {
                                            _36595 = _19299;
                                        }
                                        int _19327 = _19289.x;
                                        float4 _19335 = srcTex.read(uint2(int3(_19327, _19284.y, 0).xy), 0);
                                        float4 _36598;
                                        if (_19302)
                                        {
                                            float3 _19344 = fast::clamp(_19335.xyz, float3(0.0), float3(1.0));
                                            float3 _19353 = select(powr((_19344 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19344 * float3(0.077399380505084991455078125), _19344 <= float3(0.040449999272823333740234375));
                                            float4 _34733 = _19335;
                                            _34733.x = _19353.x;
                                            _34733.y = _19353.y;
                                            _34733.z = _19353.z;
                                            _36598 = _34733;
                                        }
                                        else
                                        {
                                            _36598 = _19335;
                                        }
                                        float4 _19371 = srcTex.read(uint2(int3(_19291, _19289.y, 0).xy), 0);
                                        float4 _36601;
                                        if (_19302)
                                        {
                                            float3 _19380 = fast::clamp(_19371.xyz, float3(0.0), float3(1.0));
                                            float3 _19389 = select(powr((_19380 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19380 * float3(0.077399380505084991455078125), _19380 <= float3(0.040449999272823333740234375));
                                            float4 _34742 = _19371;
                                            _34742.x = _19389.x;
                                            _34742.y = _19389.y;
                                            _34742.z = _19389.z;
                                            _36601 = _34742;
                                        }
                                        else
                                        {
                                            _36601 = _19371;
                                        }
                                        float4 _19407 = srcTex.read(uint2(int3(_19327, _19289.y, 0).xy), 0);
                                        float4 _36603;
                                        if (_19302)
                                        {
                                            float3 _19416 = fast::clamp(_19407.xyz, float3(0.0), float3(1.0));
                                            float3 _19425 = select(powr((_19416 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19416 * float3(0.077399380505084991455078125), _19416 <= float3(0.040449999272823333740234375));
                                            float4 _34751 = _19407;
                                            _34751.x = _19425.x;
                                            _34751.y = _19425.y;
                                            _34751.z = _19425.z;
                                            _36603 = _34751;
                                        }
                                        else
                                        {
                                            _36603 = _19407;
                                        }
                                        float4 _19436 = float4(_19281.x);
                                        _19447 = mix(mix(_36595, _36598, _19436), mix(_36601, _36603, _19436), float4(_19281.y));
                                        break;
                                    } while(false);
                                    float _19475;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _19475 = _19447.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _19475 = (_19447.x + _19447.y) * 0.5;
                                            break;
                                        }
                                        _19475 = _19447.x;
                                        break;
                                    } while(false);
                                    float _19503;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _19503 = _19447.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _19503 = _19447.x;
                                            break;
                                        }
                                        _19503 = _19447.y;
                                        break;
                                    } while(false);
                                    float2 _19521 = float2(_8385 + (4.0 / _395.g_srcW), in.i_uv.y);
                                    float4 _19758;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _19758 = srcTex.sample(samp, _19521, level(0.0));
                                            break;
                                        }
                                        uint2 _19533 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _19535 = _19533.x;
                                        uint _19537 = _19533.y;
                                        float2 _19543 = (_19521 * float2(float(_19535), float(_19537))) - float2(0.5);
                                        int2 _19548 = int2(int(_19535), int(_19537)) - int2(1);
                                        float2 _19549 = rint(_19543);
                                        if (all(abs(_19543 - _19549) < float2(0.001953125)))
                                        {
                                            float4 _19564 = srcTex.read(uint2(int3(clamp(int2(_19549), int2(0), _19548), 0).xy), 0);
                                            float4 _36622;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _19573 = fast::clamp(_19564.xyz, float3(0.0), float3(1.0));
                                                float3 _19582 = select(powr((_19573 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19573 * float3(0.077399380505084991455078125), _19573 <= float3(0.040449999272823333740234375));
                                                float4 _34772 = _19564;
                                                _34772.x = _19582.x;
                                                _34772.y = _19582.y;
                                                _34772.z = _19582.z;
                                                _36622 = _34772;
                                            }
                                            else
                                            {
                                                _36622 = _19564;
                                            }
                                            _19758 = _36622;
                                            break;
                                        }
                                        float2 _19592 = fract(_19543);
                                        int2 _19594 = int2(floor(_19543));
                                        int2 _19595 = clamp(_19594, int2(0), _19548);
                                        int2 _19600 = clamp(_19594 + int2(1), int2(0), _19548);
                                        int _19602 = _19595.x;
                                        float4 _19610 = srcTex.read(uint2(int3(_19602, _19595.y, 0).xy), 0);
                                        bool _19613 = _6337 > 0.5;
                                        float4 _36609;
                                        if (_19613)
                                        {
                                            float3 _19619 = fast::clamp(_19610.xyz, float3(0.0), float3(1.0));
                                            float3 _19628 = select(powr((_19619 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19619 * float3(0.077399380505084991455078125), _19619 <= float3(0.040449999272823333740234375));
                                            float4 _34781 = _19610;
                                            _34781.x = _19628.x;
                                            _34781.y = _19628.y;
                                            _34781.z = _19628.z;
                                            _36609 = _34781;
                                        }
                                        else
                                        {
                                            _36609 = _19610;
                                        }
                                        int _19638 = _19600.x;
                                        float4 _19646 = srcTex.read(uint2(int3(_19638, _19595.y, 0).xy), 0);
                                        float4 _36612;
                                        if (_19613)
                                        {
                                            float3 _19655 = fast::clamp(_19646.xyz, float3(0.0), float3(1.0));
                                            float3 _19664 = select(powr((_19655 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19655 * float3(0.077399380505084991455078125), _19655 <= float3(0.040449999272823333740234375));
                                            float4 _34790 = _19646;
                                            _34790.x = _19664.x;
                                            _34790.y = _19664.y;
                                            _34790.z = _19664.z;
                                            _36612 = _34790;
                                        }
                                        else
                                        {
                                            _36612 = _19646;
                                        }
                                        float4 _19682 = srcTex.read(uint2(int3(_19602, _19600.y, 0).xy), 0);
                                        float4 _36615;
                                        if (_19613)
                                        {
                                            float3 _19691 = fast::clamp(_19682.xyz, float3(0.0), float3(1.0));
                                            float3 _19700 = select(powr((_19691 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19691 * float3(0.077399380505084991455078125), _19691 <= float3(0.040449999272823333740234375));
                                            float4 _34799 = _19682;
                                            _34799.x = _19700.x;
                                            _34799.y = _19700.y;
                                            _34799.z = _19700.z;
                                            _36615 = _34799;
                                        }
                                        else
                                        {
                                            _36615 = _19682;
                                        }
                                        float4 _19718 = srcTex.read(uint2(int3(_19638, _19600.y, 0).xy), 0);
                                        float4 _36617;
                                        if (_19613)
                                        {
                                            float3 _19727 = fast::clamp(_19718.xyz, float3(0.0), float3(1.0));
                                            float3 _19736 = select(powr((_19727 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19727 * float3(0.077399380505084991455078125), _19727 <= float3(0.040449999272823333740234375));
                                            float4 _34808 = _19718;
                                            _34808.x = _19736.x;
                                            _34808.y = _19736.y;
                                            _34808.z = _19736.z;
                                            _36617 = _34808;
                                        }
                                        else
                                        {
                                            _36617 = _19718;
                                        }
                                        float4 _19747 = float4(_19592.x);
                                        _19758 = mix(mix(_36609, _36612, _19747), mix(_36615, _36617, _19747), float4(_19592.y));
                                        break;
                                    } while(false);
                                    float _19786;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _19786 = _19758.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _19786 = (_19758.x + _19758.y) * 0.5;
                                            break;
                                        }
                                        _19786 = _19758.x;
                                        break;
                                    } while(false);
                                    float _19814;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _19814 = _19758.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _19814 = _19758.x;
                                            break;
                                        }
                                        _19814 = _19758.y;
                                        break;
                                    } while(false);
                                    float2 _19832 = float2(_8385 + (5.0 / _395.g_srcW), in.i_uv.y);
                                    float4 _20069;
                                    do
                                    {
                                        if (_6338)
                                        {
                                            _20069 = srcTex.sample(samp, _19832, level(0.0));
                                            break;
                                        }
                                        uint2 _19844 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _19846 = _19844.x;
                                        uint _19848 = _19844.y;
                                        float2 _19854 = (_19832 * float2(float(_19846), float(_19848))) - float2(0.5);
                                        int2 _19859 = int2(int(_19846), int(_19848)) - int2(1);
                                        float2 _19860 = rint(_19854);
                                        if (all(abs(_19854 - _19860) < float2(0.001953125)))
                                        {
                                            float4 _19875 = srcTex.read(uint2(int3(clamp(int2(_19860), int2(0), _19859), 0).xy), 0);
                                            float4 _36636;
                                            if (_6337 > 0.5)
                                            {
                                                float3 _19884 = fast::clamp(_19875.xyz, float3(0.0), float3(1.0));
                                                float3 _19893 = select(powr((_19884 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19884 * float3(0.077399380505084991455078125), _19884 <= float3(0.040449999272823333740234375));
                                                float4 _34829 = _19875;
                                                _34829.x = _19893.x;
                                                _34829.y = _19893.y;
                                                _34829.z = _19893.z;
                                                _36636 = _34829;
                                            }
                                            else
                                            {
                                                _36636 = _19875;
                                            }
                                            _20069 = _36636;
                                            break;
                                        }
                                        float2 _19903 = fract(_19854);
                                        int2 _19905 = int2(floor(_19854));
                                        int2 _19906 = clamp(_19905, int2(0), _19859);
                                        int2 _19911 = clamp(_19905 + int2(1), int2(0), _19859);
                                        int _19913 = _19906.x;
                                        float4 _19921 = srcTex.read(uint2(int3(_19913, _19906.y, 0).xy), 0);
                                        bool _19924 = _6337 > 0.5;
                                        float4 _36623;
                                        if (_19924)
                                        {
                                            float3 _19930 = fast::clamp(_19921.xyz, float3(0.0), float3(1.0));
                                            float3 _19939 = select(powr((_19930 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19930 * float3(0.077399380505084991455078125), _19930 <= float3(0.040449999272823333740234375));
                                            float4 _34838 = _19921;
                                            _34838.x = _19939.x;
                                            _34838.y = _19939.y;
                                            _34838.z = _19939.z;
                                            _36623 = _34838;
                                        }
                                        else
                                        {
                                            _36623 = _19921;
                                        }
                                        int _19949 = _19911.x;
                                        float4 _19957 = srcTex.read(uint2(int3(_19949, _19906.y, 0).xy), 0);
                                        float4 _36626;
                                        if (_19924)
                                        {
                                            float3 _19966 = fast::clamp(_19957.xyz, float3(0.0), float3(1.0));
                                            float3 _19975 = select(powr((_19966 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _19966 * float3(0.077399380505084991455078125), _19966 <= float3(0.040449999272823333740234375));
                                            float4 _34847 = _19957;
                                            _34847.x = _19975.x;
                                            _34847.y = _19975.y;
                                            _34847.z = _19975.z;
                                            _36626 = _34847;
                                        }
                                        else
                                        {
                                            _36626 = _19957;
                                        }
                                        float4 _19993 = srcTex.read(uint2(int3(_19913, _19911.y, 0).xy), 0);
                                        float4 _36629;
                                        if (_19924)
                                        {
                                            float3 _20002 = fast::clamp(_19993.xyz, float3(0.0), float3(1.0));
                                            float3 _20011 = select(powr((_20002 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20002 * float3(0.077399380505084991455078125), _20002 <= float3(0.040449999272823333740234375));
                                            float4 _34856 = _19993;
                                            _34856.x = _20011.x;
                                            _34856.y = _20011.y;
                                            _34856.z = _20011.z;
                                            _36629 = _34856;
                                        }
                                        else
                                        {
                                            _36629 = _19993;
                                        }
                                        float4 _20029 = srcTex.read(uint2(int3(_19949, _19911.y, 0).xy), 0);
                                        float4 _36631;
                                        if (_19924)
                                        {
                                            float3 _20038 = fast::clamp(_20029.xyz, float3(0.0), float3(1.0));
                                            float3 _20047 = select(powr((_20038 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _20038 * float3(0.077399380505084991455078125), _20038 <= float3(0.040449999272823333740234375));
                                            float4 _34865 = _20029;
                                            _34865.x = _20047.x;
                                            _34865.y = _20047.y;
                                            _34865.z = _20047.z;
                                            _36631 = _34865;
                                        }
                                        else
                                        {
                                            _36631 = _20029;
                                        }
                                        float4 _20058 = float4(_19903.x);
                                        _20069 = mix(mix(_36623, _36626, _20058), mix(_36629, _36631, _20058), float4(_19903.y));
                                        break;
                                    } while(false);
                                    float _20097;
                                    do
                                    {
                                        if (_8284)
                                        {
                                            _20097 = _20069.y;
                                            break;
                                        }
                                        if (_8314)
                                        {
                                            _20097 = (_20069.x + _20069.y) * 0.5;
                                            break;
                                        }
                                        _20097 = _20069.x;
                                        break;
                                    } while(false);
                                    float _20125;
                                    do
                                    {
                                        if (_8315)
                                        {
                                            _20125 = _20069.z;
                                            break;
                                        }
                                        if (_8284)
                                        {
                                            _20125 = _20069.x;
                                            break;
                                        }
                                        _20125 = _20069.y;
                                        break;
                                    } while(false);
                                    float _16084 = _17637 - _17326;
                                    float _16096 = _17609 - _17298;
                                    float _16119 = _17948 - _17637;
                                    float _16131 = _17920 - _17609;
                                    float _16154 = _18259 - _17948;
                                    float _16166 = _18231 - _17920;
                                    spvUnsafeArray<float, 7> _8349;
                                    _8349[0] = (((_8363 ? abs(_7917 - (_17326 - _13529)) : abs(_7927 - (_17298 - _13527))) + (_8363 ? abs(_20139 - _16084) : abs(_20146 - _16096))) + (_8363 ? abs(_20160 - _16119) : abs(_20167 - _16131))) + (_8363 ? abs(_20181 - _16154) : abs(_20188 - _16166));
                                    float _16291 = _18570 - _18259;
                                    float _16303 = _18542 - _18231;
                                    _8349[1] = (((_8363 ? abs(_7917 - _16084) : abs(_7927 - _16096)) + (_8363 ? abs(_20139 - _16119) : abs(_20146 - _16131))) + (_8363 ? abs(_20160 - _16154) : abs(_20167 - _16166))) + (_8363 ? abs(_20181 - _16291) : abs(_20188 - _16303));
                                    float _16432 = _18881 - _18570;
                                    float _16444 = _18853 - _18542;
                                    _8349[2] = (((_8363 ? abs(_7917 - _16119) : abs(_7927 - _16131)) + (_8363 ? abs(_20139 - _16154) : abs(_20146 - _16166))) + (_8363 ? abs(_20160 - _16291) : abs(_20167 - _16303))) + (_8363 ? abs(_20181 - _16432) : abs(_20188 - _16444));
                                    float _16573 = _19192 - _18881;
                                    float _16585 = _19164 - _18853;
                                    _8349[3] = (((_8363 ? abs(_7917 - _16154) : abs(_7927 - _16166)) + (_8363 ? abs(_20139 - _16291) : abs(_20146 - _16303))) + (_8363 ? abs(_20160 - _16432) : abs(_20167 - _16444))) + (_8363 ? abs(_20181 - _16573) : abs(_20188 - _16585));
                                    float _16714 = _19503 - _19192;
                                    float _16726 = _19475 - _19164;
                                    _8349[4] = (((_8363 ? abs(_7917 - _16291) : abs(_7927 - _16303)) + (_8363 ? abs(_20139 - _16432) : abs(_20146 - _16444))) + (_8363 ? abs(_20160 - _16573) : abs(_20167 - _16585))) + (_8363 ? abs(_20181 - _16714) : abs(_20188 - _16726));
                                    float _16855 = _19814 - _19503;
                                    float _16867 = _19786 - _19475;
                                    _8349[5] = (((_8363 ? abs(_7917 - _16432) : abs(_7927 - _16444)) + (_8363 ? abs(_20139 - _16573) : abs(_20146 - _16585))) + (_8363 ? abs(_20160 - _16714) : abs(_20167 - _16726))) + (_8363 ? abs(_20181 - _16855) : abs(_20188 - _16867));
                                    _8349[6] = (((_8363 ? abs(_7917 - _16573) : abs(_7927 - _16585)) + (_8363 ? abs(_20139 - _16714) : abs(_20146 - _16726))) + (_8363 ? abs(_20160 - _16855) : abs(_20167 - _16867))) + (_8363 ? abs(_20181 - (_20125 - _19814)) : abs(_20188 - (_20097 - _19786)));
                                    _8349[0] += (abs(-3.0) * 0.00200000009499490261077880859375);
                                    _8349[1] += (abs(-2.0) * 0.00200000009499490261077880859375);
                                    _8349[2] += (abs(-1.0) * 0.00200000009499490261077880859375);
                                    _8349[3] += (abs(0.0) * 0.00200000009499490261077880859375);
                                    _8349[4] += (abs(1.0) * 0.00200000009499490261077880859375);
                                    _8349[5] += (abs(2.0) * 0.00200000009499490261077880859375);
                                    _8349[6] += (abs(3.0) * 0.00200000009499490261077880859375);
                                    bool _8500 = _8349[0] < _8349[3];
                                    float _13635;
                                    if (_8500)
                                    {
                                        _13635 = _8349[0];
                                    }
                                    else
                                    {
                                        _13635 = _8349[3];
                                    }
                                    bool _15879 = _8349[1] < _13635;
                                    float _15884;
                                    if (_15879)
                                    {
                                        _15884 = _8349[1];
                                    }
                                    else
                                    {
                                        _15884 = _13635;
                                    }
                                    bool _15897 = _8349[2] < _15884;
                                    float _15902;
                                    if (_15897)
                                    {
                                        _15902 = _8349[2];
                                    }
                                    else
                                    {
                                        _15902 = _15884;
                                    }
                                    bool _15915 = _8349[3] < _15902;
                                    float _15920;
                                    if (_15915)
                                    {
                                        _15920 = _8349[3];
                                    }
                                    else
                                    {
                                        _15920 = _15902;
                                    }
                                    bool _15933 = _8349[4] < _15920;
                                    float _15938;
                                    if (_15933)
                                    {
                                        _15938 = _8349[4];
                                    }
                                    else
                                    {
                                        _15938 = _15920;
                                    }
                                    bool _15951 = _8349[5] < _15938;
                                    float _15956;
                                    if (_15951)
                                    {
                                        _15956 = _8349[5];
                                    }
                                    else
                                    {
                                        _15956 = _15938;
                                    }
                                    int _32347 = (_8349[6] < _15956) ? 6 : (_15951 ? 5 : (_15933 ? 4 : (_15915 ? 3 : (_15897 ? 2 : (_15879 ? 1 : (_8500 ? 0 : 3))))));
                                    float _8517 = _8371 + (float(_32347 - 3) * _4101);
                                    float _13515;
                                    if ((_32347 > 0) && (_32347 < 6))
                                    {
                                        int _8525 = _32347 - 1;
                                        int _8532 = _32347 + 1;
                                        float _8540 = (_8349[_8525] - (2.0 * _8349[_32347])) + _8349[_8532];
                                        _13515 = _8517 + (fast::clamp((abs(_8540) > 9.9999997473787516355514526367188e-06) ? ((0.5 * (_8349[_8525] - _8349[_8532])) / _8540) : 0.0, -1.0, 1.0) * _4101);
                                    }
                                    else
                                    {
                                        _13515 = _8517;
                                    }
                                    _13548 = _13515;
                                }
                                bool _8997;
                                float _13546;
                                do
                                {
                                    _8997 = _395.g_anaCombo == 0;
                                    if (_8997)
                                    {
                                        _13546 = (!_13391) ? _13446.x : ((_13446.y + _13446.z) * 0.5);
                                        break;
                                    }
                                    if (_395.g_anaCombo == 1)
                                    {
                                        _13546 = (!_13391) ? _13446.x : _13446.y;
                                        break;
                                    }
                                    if (_395.g_anaCombo == 2)
                                    {
                                        _13546 = (!_13391) ? _13446.x : _13446.z;
                                        break;
                                    }
                                    if (_395.g_anaCombo == 3)
                                    {
                                        _13546 = (!_13391) ? _13446.y : ((_13446.x + _13446.z) * 0.5);
                                        break;
                                    }
                                    if (_395.g_anaCombo == 4)
                                    {
                                        _13546 = (!_13391) ? ((_13446.x + _13446.y) * 0.5) : _13446.z;
                                        break;
                                    }
                                    _13546 = (!_13391) ? ((_13446.y + _13446.z) * 0.5) : ((_13446.x + _13446.z) * 0.5);
                                    break;
                                } while(false);
                                float _4278 = _3592 + _13548;
                                float2 _4281 = float2(_4278, in.i_uv.y);
                                float4 _13550;
                                do
                                {
                                    if (_6338)
                                    {
                                        _13550 = srcTex.sample(samp, _4281, level(0.0));
                                        break;
                                    }
                                    uint2 _9115 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _9117 = _9115.x;
                                    uint _9119 = _9115.y;
                                    float2 _9128 = (_4281 * float2(float(_9117), float(_9119))) - float2(0.5);
                                    int2 _9135 = int2(int(_9117), int(_9119)) - int2(1);
                                    float2 _9137 = rint(_9128);
                                    if (all(abs(_9128 - _9137) < float2(0.001953125)))
                                    {
                                        float4 _9219 = srcTex.read(uint2(int3(clamp(int2(_9137), int2(0), _9135), 0).xy), 0);
                                        float4 _36779;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _9228 = fast::clamp(_9219.xyz, float3(0.0), float3(1.0));
                                            float3 _9251 = select(powr((_9228 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _9228 * float3(0.077399380505084991455078125), _9228 <= float3(0.040449999272823333740234375));
                                            float4 _34905 = _9219;
                                            _34905.x = _9251.x;
                                            _34905.y = _9251.y;
                                            _34905.z = _9251.z;
                                            _36779 = _34905;
                                        }
                                        else
                                        {
                                            _36779 = _9219;
                                        }
                                        _13550 = _36779;
                                        break;
                                    }
                                    float2 _9155 = fract(_9128);
                                    int2 _9158 = int2(floor(_9128));
                                    int2 _9160 = clamp(_9158, int2(0), _9135);
                                    int2 _9167 = clamp(_9158 + int2(1), int2(0), _9135);
                                    int _9169 = _9160.x;
                                    float4 _9261 = srcTex.read(uint2(int3(_9169, _9160.y, 0).xy), 0);
                                    bool _9264 = _6337 > 0.5;
                                    float4 _36775;
                                    if (_9264)
                                    {
                                        float3 _9270 = fast::clamp(_9261.xyz, float3(0.0), float3(1.0));
                                        float3 _9293 = select(powr((_9270 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _9270 * float3(0.077399380505084991455078125), _9270 <= float3(0.040449999272823333740234375));
                                        float4 _34914 = _9261;
                                        _34914.x = _9293.x;
                                        _34914.y = _9293.y;
                                        _34914.z = _9293.z;
                                        _36775 = _34914;
                                    }
                                    else
                                    {
                                        _36775 = _9261;
                                    }
                                    int _9175 = _9167.x;
                                    float4 _9303 = srcTex.read(uint2(int3(_9175, _9160.y, 0).xy), 0);
                                    float4 _36776;
                                    if (_9264)
                                    {
                                        float3 _9312 = fast::clamp(_9303.xyz, float3(0.0), float3(1.0));
                                        float3 _9335 = select(powr((_9312 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _9312 * float3(0.077399380505084991455078125), _9312 <= float3(0.040449999272823333740234375));
                                        float4 _34923 = _9303;
                                        _34923.x = _9335.x;
                                        _34923.y = _9335.y;
                                        _34923.z = _9335.z;
                                        _36776 = _34923;
                                    }
                                    else
                                    {
                                        _36776 = _9303;
                                    }
                                    float4 _9345 = srcTex.read(uint2(int3(_9169, _9167.y, 0).xy), 0);
                                    float4 _36777;
                                    if (_9264)
                                    {
                                        float3 _9354 = fast::clamp(_9345.xyz, float3(0.0), float3(1.0));
                                        float3 _9377 = select(powr((_9354 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _9354 * float3(0.077399380505084991455078125), _9354 <= float3(0.040449999272823333740234375));
                                        float4 _34932 = _9345;
                                        _34932.x = _9377.x;
                                        _34932.y = _9377.y;
                                        _34932.z = _9377.z;
                                        _36777 = _34932;
                                    }
                                    else
                                    {
                                        _36777 = _9345;
                                    }
                                    float4 _9387 = srcTex.read(uint2(int3(_9175, _9167.y, 0).xy), 0);
                                    float4 _36778;
                                    if (_9264)
                                    {
                                        float3 _9396 = fast::clamp(_9387.xyz, float3(0.0), float3(1.0));
                                        float3 _9419 = select(powr((_9396 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _9396 * float3(0.077399380505084991455078125), _9396 <= float3(0.040449999272823333740234375));
                                        float4 _34941 = _9387;
                                        _34941.x = _9419.x;
                                        _34941.y = _9419.y;
                                        _34941.z = _9419.z;
                                        _36778 = _34941;
                                    }
                                    else
                                    {
                                        _36778 = _9387;
                                    }
                                    float4 _9196 = float4(_9155.x);
                                    _13550 = mix(mix(_36775, _36776, _9196), mix(_36777, _36778, _9196), float4(_9155.y));
                                    break;
                                } while(false);
                                float _4286 = dot(_13550.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
                                float _4305 = _4278 + ((-1.0) / _395.g_srcW);
                                float _4312 = in.i_uv.y + ((-1.0) / _395.g_srcH);
                                float2 _4313 = float2(_4305, _4312);
                                float4 _13578;
                                do
                                {
                                    if (_6338)
                                    {
                                        _13578 = srcTex.sample(samp, _4313, level(0.0));
                                        break;
                                    }
                                    uint2 _9455 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _9457 = _9455.x;
                                    uint _9459 = _9455.y;
                                    float2 _9468 = (_4313 * float2(float(_9457), float(_9459))) - float2(0.5);
                                    int2 _9475 = int2(int(_9457), int(_9459)) - int2(1);
                                    float2 _9477 = rint(_9468);
                                    if (all(abs(_9468 - _9477) < float2(0.001953125)))
                                    {
                                        float4 _9559 = srcTex.read(uint2(int3(clamp(int2(_9477), int2(0), _9475), 0).xy), 0);
                                        float4 _36799;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _9568 = fast::clamp(_9559.xyz, float3(0.0), float3(1.0));
                                            float3 _9591 = select(powr((_9568 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _9568 * float3(0.077399380505084991455078125), _9568 <= float3(0.040449999272823333740234375));
                                            float4 _34955 = _9559;
                                            _34955.x = _9591.x;
                                            _34955.y = _9591.y;
                                            _34955.z = _9591.z;
                                            _36799 = _34955;
                                        }
                                        else
                                        {
                                            _36799 = _9559;
                                        }
                                        _13578 = _36799;
                                        break;
                                    }
                                    float2 _9495 = fract(_9468);
                                    int2 _9498 = int2(floor(_9468));
                                    int2 _9500 = clamp(_9498, int2(0), _9475);
                                    int2 _9507 = clamp(_9498 + int2(1), int2(0), _9475);
                                    int _9509 = _9500.x;
                                    float4 _9601 = srcTex.read(uint2(int3(_9509, _9500.y, 0).xy), 0);
                                    bool _9604 = _6337 > 0.5;
                                    float4 _36786;
                                    if (_9604)
                                    {
                                        float3 _9610 = fast::clamp(_9601.xyz, float3(0.0), float3(1.0));
                                        float3 _9633 = select(powr((_9610 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _9610 * float3(0.077399380505084991455078125), _9610 <= float3(0.040449999272823333740234375));
                                        float4 _34964 = _9601;
                                        _34964.x = _9633.x;
                                        _34964.y = _9633.y;
                                        _34964.z = _9633.z;
                                        _36786 = _34964;
                                    }
                                    else
                                    {
                                        _36786 = _9601;
                                    }
                                    int _9515 = _9507.x;
                                    float4 _9643 = srcTex.read(uint2(int3(_9515, _9500.y, 0).xy), 0);
                                    float4 _36789;
                                    if (_9604)
                                    {
                                        float3 _9652 = fast::clamp(_9643.xyz, float3(0.0), float3(1.0));
                                        float3 _9675 = select(powr((_9652 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _9652 * float3(0.077399380505084991455078125), _9652 <= float3(0.040449999272823333740234375));
                                        float4 _34973 = _9643;
                                        _34973.x = _9675.x;
                                        _34973.y = _9675.y;
                                        _34973.z = _9675.z;
                                        _36789 = _34973;
                                    }
                                    else
                                    {
                                        _36789 = _9643;
                                    }
                                    float4 _9685 = srcTex.read(uint2(int3(_9509, _9507.y, 0).xy), 0);
                                    float4 _36792;
                                    if (_9604)
                                    {
                                        float3 _9694 = fast::clamp(_9685.xyz, float3(0.0), float3(1.0));
                                        float3 _9717 = select(powr((_9694 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _9694 * float3(0.077399380505084991455078125), _9694 <= float3(0.040449999272823333740234375));
                                        float4 _34982 = _9685;
                                        _34982.x = _9717.x;
                                        _34982.y = _9717.y;
                                        _34982.z = _9717.z;
                                        _36792 = _34982;
                                    }
                                    else
                                    {
                                        _36792 = _9685;
                                    }
                                    float4 _9727 = srcTex.read(uint2(int3(_9515, _9507.y, 0).xy), 0);
                                    float4 _36794;
                                    if (_9604)
                                    {
                                        float3 _9736 = fast::clamp(_9727.xyz, float3(0.0), float3(1.0));
                                        float3 _9759 = select(powr((_9736 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _9736 * float3(0.077399380505084991455078125), _9736 <= float3(0.040449999272823333740234375));
                                        float4 _34991 = _9727;
                                        _34991.x = _9759.x;
                                        _34991.y = _9759.y;
                                        _34991.z = _9759.z;
                                        _36794 = _34991;
                                    }
                                    else
                                    {
                                        _36794 = _9727;
                                    }
                                    float4 _9536 = float4(_9495.x);
                                    _13578 = mix(mix(_36786, _36789, _9536), mix(_36792, _36794, _9536), float4(_9495.y));
                                    break;
                                } while(false);
                                float _4325 = exp(abs(dot(_13578.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)) - _4286) * (-8.0));
                                float2 _13692 = float2(_4278, _4312);
                                float4 _13929;
                                do
                                {
                                    if (_6338)
                                    {
                                        _13929 = srcTex.sample(samp, _13692, level(0.0));
                                        break;
                                    }
                                    uint2 _13704 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _13706 = _13704.x;
                                    uint _13708 = _13704.y;
                                    float2 _13714 = (_13692 * float2(float(_13706), float(_13708))) - float2(0.5);
                                    int2 _13719 = int2(int(_13706), int(_13708)) - int2(1);
                                    float2 _13720 = rint(_13714);
                                    if (all(abs(_13714 - _13720) < float2(0.001953125)))
                                    {
                                        float4 _13735 = srcTex.read(uint2(int3(clamp(int2(_13720), int2(0), _13719), 0).xy), 0);
                                        float4 _36819;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _13744 = fast::clamp(_13735.xyz, float3(0.0), float3(1.0));
                                            float3 _13753 = select(powr((_13744 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13744 * float3(0.077399380505084991455078125), _13744 <= float3(0.040449999272823333740234375));
                                            float4 _35005 = _13735;
                                            _35005.x = _13753.x;
                                            _35005.y = _13753.y;
                                            _35005.z = _13753.z;
                                            _36819 = _35005;
                                        }
                                        else
                                        {
                                            _36819 = _13735;
                                        }
                                        _13929 = _36819;
                                        break;
                                    }
                                    float2 _13763 = fract(_13714);
                                    int2 _13765 = int2(floor(_13714));
                                    int2 _13766 = clamp(_13765, int2(0), _13719);
                                    int2 _13771 = clamp(_13765 + int2(1), int2(0), _13719);
                                    int _13773 = _13766.x;
                                    float4 _13781 = srcTex.read(uint2(int3(_13773, _13766.y, 0).xy), 0);
                                    bool _13784 = _6337 > 0.5;
                                    float4 _36806;
                                    if (_13784)
                                    {
                                        float3 _13790 = fast::clamp(_13781.xyz, float3(0.0), float3(1.0));
                                        float3 _13799 = select(powr((_13790 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13790 * float3(0.077399380505084991455078125), _13790 <= float3(0.040449999272823333740234375));
                                        float4 _35014 = _13781;
                                        _35014.x = _13799.x;
                                        _35014.y = _13799.y;
                                        _35014.z = _13799.z;
                                        _36806 = _35014;
                                    }
                                    else
                                    {
                                        _36806 = _13781;
                                    }
                                    int _13809 = _13771.x;
                                    float4 _13817 = srcTex.read(uint2(int3(_13809, _13766.y, 0).xy), 0);
                                    float4 _36809;
                                    if (_13784)
                                    {
                                        float3 _13826 = fast::clamp(_13817.xyz, float3(0.0), float3(1.0));
                                        float3 _13835 = select(powr((_13826 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13826 * float3(0.077399380505084991455078125), _13826 <= float3(0.040449999272823333740234375));
                                        float4 _35023 = _13817;
                                        _35023.x = _13835.x;
                                        _35023.y = _13835.y;
                                        _35023.z = _13835.z;
                                        _36809 = _35023;
                                    }
                                    else
                                    {
                                        _36809 = _13817;
                                    }
                                    float4 _13853 = srcTex.read(uint2(int3(_13773, _13771.y, 0).xy), 0);
                                    float4 _36812;
                                    if (_13784)
                                    {
                                        float3 _13862 = fast::clamp(_13853.xyz, float3(0.0), float3(1.0));
                                        float3 _13871 = select(powr((_13862 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13862 * float3(0.077399380505084991455078125), _13862 <= float3(0.040449999272823333740234375));
                                        float4 _35032 = _13853;
                                        _35032.x = _13871.x;
                                        _35032.y = _13871.y;
                                        _35032.z = _13871.z;
                                        _36812 = _35032;
                                    }
                                    else
                                    {
                                        _36812 = _13853;
                                    }
                                    float4 _13889 = srcTex.read(uint2(int3(_13809, _13771.y, 0).xy), 0);
                                    float4 _36814;
                                    if (_13784)
                                    {
                                        float3 _13898 = fast::clamp(_13889.xyz, float3(0.0), float3(1.0));
                                        float3 _13907 = select(powr((_13898 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13898 * float3(0.077399380505084991455078125), _13898 <= float3(0.040449999272823333740234375));
                                        float4 _35041 = _13889;
                                        _35041.x = _13907.x;
                                        _35041.y = _13907.y;
                                        _35041.z = _13907.z;
                                        _36814 = _35041;
                                    }
                                    else
                                    {
                                        _36814 = _13889;
                                    }
                                    float4 _13918 = float4(_13763.x);
                                    _13929 = mix(mix(_36806, _36809, _13918), mix(_36812, _36814, _13918), float4(_13763.y));
                                    break;
                                } while(false);
                                float _13936 = exp(abs(dot(_13929.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)) - _4286) * (-8.0));
                                float _13954 = _4278 + _4101;
                                float2 _13960 = float2(_13954, _4312);
                                float4 _14197;
                                do
                                {
                                    if (_6338)
                                    {
                                        _14197 = srcTex.sample(samp, _13960, level(0.0));
                                        break;
                                    }
                                    uint2 _13972 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _13974 = _13972.x;
                                    uint _13976 = _13972.y;
                                    float2 _13982 = (_13960 * float2(float(_13974), float(_13976))) - float2(0.5);
                                    int2 _13987 = int2(int(_13974), int(_13976)) - int2(1);
                                    float2 _13988 = rint(_13982);
                                    if (all(abs(_13982 - _13988) < float2(0.001953125)))
                                    {
                                        float4 _14003 = srcTex.read(uint2(int3(clamp(int2(_13988), int2(0), _13987), 0).xy), 0);
                                        float4 _36839;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _14012 = fast::clamp(_14003.xyz, float3(0.0), float3(1.0));
                                            float3 _14021 = select(powr((_14012 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14012 * float3(0.077399380505084991455078125), _14012 <= float3(0.040449999272823333740234375));
                                            float4 _35055 = _14003;
                                            _35055.x = _14021.x;
                                            _35055.y = _14021.y;
                                            _35055.z = _14021.z;
                                            _36839 = _35055;
                                        }
                                        else
                                        {
                                            _36839 = _14003;
                                        }
                                        _14197 = _36839;
                                        break;
                                    }
                                    float2 _14031 = fract(_13982);
                                    int2 _14033 = int2(floor(_13982));
                                    int2 _14034 = clamp(_14033, int2(0), _13987);
                                    int2 _14039 = clamp(_14033 + int2(1), int2(0), _13987);
                                    int _14041 = _14034.x;
                                    float4 _14049 = srcTex.read(uint2(int3(_14041, _14034.y, 0).xy), 0);
                                    bool _14052 = _6337 > 0.5;
                                    float4 _36826;
                                    if (_14052)
                                    {
                                        float3 _14058 = fast::clamp(_14049.xyz, float3(0.0), float3(1.0));
                                        float3 _14067 = select(powr((_14058 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14058 * float3(0.077399380505084991455078125), _14058 <= float3(0.040449999272823333740234375));
                                        float4 _35064 = _14049;
                                        _35064.x = _14067.x;
                                        _35064.y = _14067.y;
                                        _35064.z = _14067.z;
                                        _36826 = _35064;
                                    }
                                    else
                                    {
                                        _36826 = _14049;
                                    }
                                    int _14077 = _14039.x;
                                    float4 _14085 = srcTex.read(uint2(int3(_14077, _14034.y, 0).xy), 0);
                                    float4 _36829;
                                    if (_14052)
                                    {
                                        float3 _14094 = fast::clamp(_14085.xyz, float3(0.0), float3(1.0));
                                        float3 _14103 = select(powr((_14094 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14094 * float3(0.077399380505084991455078125), _14094 <= float3(0.040449999272823333740234375));
                                        float4 _35073 = _14085;
                                        _35073.x = _14103.x;
                                        _35073.y = _14103.y;
                                        _35073.z = _14103.z;
                                        _36829 = _35073;
                                    }
                                    else
                                    {
                                        _36829 = _14085;
                                    }
                                    float4 _14121 = srcTex.read(uint2(int3(_14041, _14039.y, 0).xy), 0);
                                    float4 _36832;
                                    if (_14052)
                                    {
                                        float3 _14130 = fast::clamp(_14121.xyz, float3(0.0), float3(1.0));
                                        float3 _14139 = select(powr((_14130 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14130 * float3(0.077399380505084991455078125), _14130 <= float3(0.040449999272823333740234375));
                                        float4 _35082 = _14121;
                                        _35082.x = _14139.x;
                                        _35082.y = _14139.y;
                                        _35082.z = _14139.z;
                                        _36832 = _35082;
                                    }
                                    else
                                    {
                                        _36832 = _14121;
                                    }
                                    float4 _14157 = srcTex.read(uint2(int3(_14077, _14039.y, 0).xy), 0);
                                    float4 _36834;
                                    if (_14052)
                                    {
                                        float3 _14166 = fast::clamp(_14157.xyz, float3(0.0), float3(1.0));
                                        float3 _14175 = select(powr((_14166 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14166 * float3(0.077399380505084991455078125), _14166 <= float3(0.040449999272823333740234375));
                                        float4 _35091 = _14157;
                                        _35091.x = _14175.x;
                                        _35091.y = _14175.y;
                                        _35091.z = _14175.z;
                                        _36834 = _35091;
                                    }
                                    else
                                    {
                                        _36834 = _14157;
                                    }
                                    float4 _14186 = float4(_14031.x);
                                    _14197 = mix(mix(_36826, _36829, _14186), mix(_36832, _36834, _14186), float4(_14031.y));
                                    break;
                                } while(false);
                                float _14204 = exp(abs(dot(_14197.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)) - _4286) * (-8.0));
                                float2 _14233 = float2(_4305, in.i_uv.y);
                                float4 _14470;
                                do
                                {
                                    if (_6338)
                                    {
                                        _14470 = srcTex.sample(samp, _14233, level(0.0));
                                        break;
                                    }
                                    uint2 _14245 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _14247 = _14245.x;
                                    uint _14249 = _14245.y;
                                    float2 _14255 = (_14233 * float2(float(_14247), float(_14249))) - float2(0.5);
                                    int2 _14260 = int2(int(_14247), int(_14249)) - int2(1);
                                    float2 _14261 = rint(_14255);
                                    if (all(abs(_14255 - _14261) < float2(0.001953125)))
                                    {
                                        float4 _14276 = srcTex.read(uint2(int3(clamp(int2(_14261), int2(0), _14260), 0).xy), 0);
                                        float4 _36859;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _14285 = fast::clamp(_14276.xyz, float3(0.0), float3(1.0));
                                            float3 _14294 = select(powr((_14285 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14285 * float3(0.077399380505084991455078125), _14285 <= float3(0.040449999272823333740234375));
                                            float4 _35105 = _14276;
                                            _35105.x = _14294.x;
                                            _35105.y = _14294.y;
                                            _35105.z = _14294.z;
                                            _36859 = _35105;
                                        }
                                        else
                                        {
                                            _36859 = _14276;
                                        }
                                        _14470 = _36859;
                                        break;
                                    }
                                    float2 _14304 = fract(_14255);
                                    int2 _14306 = int2(floor(_14255));
                                    int2 _14307 = clamp(_14306, int2(0), _14260);
                                    int2 _14312 = clamp(_14306 + int2(1), int2(0), _14260);
                                    int _14314 = _14307.x;
                                    float4 _14322 = srcTex.read(uint2(int3(_14314, _14307.y, 0).xy), 0);
                                    bool _14325 = _6337 > 0.5;
                                    float4 _36846;
                                    if (_14325)
                                    {
                                        float3 _14331 = fast::clamp(_14322.xyz, float3(0.0), float3(1.0));
                                        float3 _14340 = select(powr((_14331 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14331 * float3(0.077399380505084991455078125), _14331 <= float3(0.040449999272823333740234375));
                                        float4 _35114 = _14322;
                                        _35114.x = _14340.x;
                                        _35114.y = _14340.y;
                                        _35114.z = _14340.z;
                                        _36846 = _35114;
                                    }
                                    else
                                    {
                                        _36846 = _14322;
                                    }
                                    int _14350 = _14312.x;
                                    float4 _14358 = srcTex.read(uint2(int3(_14350, _14307.y, 0).xy), 0);
                                    float4 _36849;
                                    if (_14325)
                                    {
                                        float3 _14367 = fast::clamp(_14358.xyz, float3(0.0), float3(1.0));
                                        float3 _14376 = select(powr((_14367 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14367 * float3(0.077399380505084991455078125), _14367 <= float3(0.040449999272823333740234375));
                                        float4 _35123 = _14358;
                                        _35123.x = _14376.x;
                                        _35123.y = _14376.y;
                                        _35123.z = _14376.z;
                                        _36849 = _35123;
                                    }
                                    else
                                    {
                                        _36849 = _14358;
                                    }
                                    float4 _14394 = srcTex.read(uint2(int3(_14314, _14312.y, 0).xy), 0);
                                    float4 _36852;
                                    if (_14325)
                                    {
                                        float3 _14403 = fast::clamp(_14394.xyz, float3(0.0), float3(1.0));
                                        float3 _14412 = select(powr((_14403 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14403 * float3(0.077399380505084991455078125), _14403 <= float3(0.040449999272823333740234375));
                                        float4 _35132 = _14394;
                                        _35132.x = _14412.x;
                                        _35132.y = _14412.y;
                                        _35132.z = _14412.z;
                                        _36852 = _35132;
                                    }
                                    else
                                    {
                                        _36852 = _14394;
                                    }
                                    float4 _14430 = srcTex.read(uint2(int3(_14350, _14312.y, 0).xy), 0);
                                    float4 _36854;
                                    if (_14325)
                                    {
                                        float3 _14439 = fast::clamp(_14430.xyz, float3(0.0), float3(1.0));
                                        float3 _14448 = select(powr((_14439 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14439 * float3(0.077399380505084991455078125), _14439 <= float3(0.040449999272823333740234375));
                                        float4 _35141 = _14430;
                                        _35141.x = _14448.x;
                                        _35141.y = _14448.y;
                                        _35141.z = _14448.z;
                                        _36854 = _35141;
                                    }
                                    else
                                    {
                                        _36854 = _14430;
                                    }
                                    float4 _14459 = float4(_14304.x);
                                    _14470 = mix(mix(_36846, _36849, _14459), mix(_36852, _36854, _14459), float4(_14304.y));
                                    break;
                                } while(false);
                                float _14477 = exp(abs(dot(_14470.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)) - _4286) * (-8.0));
                                float4 _14735;
                                do
                                {
                                    if (_6338)
                                    {
                                        _14735 = srcTex.sample(samp, _4281, level(0.0));
                                        break;
                                    }
                                    uint2 _14510 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _14512 = _14510.x;
                                    uint _14514 = _14510.y;
                                    float2 _14520 = (_4281 * float2(float(_14512), float(_14514))) - float2(0.5);
                                    int2 _14525 = int2(int(_14512), int(_14514)) - int2(1);
                                    float2 _14526 = rint(_14520);
                                    if (all(abs(_14520 - _14526) < float2(0.001953125)))
                                    {
                                        float4 _14541 = srcTex.read(uint2(int3(clamp(int2(_14526), int2(0), _14525), 0).xy), 0);
                                        float4 _36879;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _14550 = fast::clamp(_14541.xyz, float3(0.0), float3(1.0));
                                            float3 _14559 = select(powr((_14550 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14550 * float3(0.077399380505084991455078125), _14550 <= float3(0.040449999272823333740234375));
                                            float4 _35155 = _14541;
                                            _35155.x = _14559.x;
                                            _35155.y = _14559.y;
                                            _35155.z = _14559.z;
                                            _36879 = _35155;
                                        }
                                        else
                                        {
                                            _36879 = _14541;
                                        }
                                        _14735 = _36879;
                                        break;
                                    }
                                    float2 _14569 = fract(_14520);
                                    int2 _14571 = int2(floor(_14520));
                                    int2 _14572 = clamp(_14571, int2(0), _14525);
                                    int2 _14577 = clamp(_14571 + int2(1), int2(0), _14525);
                                    int _14579 = _14572.x;
                                    float4 _14587 = srcTex.read(uint2(int3(_14579, _14572.y, 0).xy), 0);
                                    bool _14590 = _6337 > 0.5;
                                    float4 _36866;
                                    if (_14590)
                                    {
                                        float3 _14596 = fast::clamp(_14587.xyz, float3(0.0), float3(1.0));
                                        float3 _14605 = select(powr((_14596 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14596 * float3(0.077399380505084991455078125), _14596 <= float3(0.040449999272823333740234375));
                                        float4 _35164 = _14587;
                                        _35164.x = _14605.x;
                                        _35164.y = _14605.y;
                                        _35164.z = _14605.z;
                                        _36866 = _35164;
                                    }
                                    else
                                    {
                                        _36866 = _14587;
                                    }
                                    int _14615 = _14577.x;
                                    float4 _14623 = srcTex.read(uint2(int3(_14615, _14572.y, 0).xy), 0);
                                    float4 _36869;
                                    if (_14590)
                                    {
                                        float3 _14632 = fast::clamp(_14623.xyz, float3(0.0), float3(1.0));
                                        float3 _14641 = select(powr((_14632 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14632 * float3(0.077399380505084991455078125), _14632 <= float3(0.040449999272823333740234375));
                                        float4 _35173 = _14623;
                                        _35173.x = _14641.x;
                                        _35173.y = _14641.y;
                                        _35173.z = _14641.z;
                                        _36869 = _35173;
                                    }
                                    else
                                    {
                                        _36869 = _14623;
                                    }
                                    float4 _14659 = srcTex.read(uint2(int3(_14579, _14577.y, 0).xy), 0);
                                    float4 _36872;
                                    if (_14590)
                                    {
                                        float3 _14668 = fast::clamp(_14659.xyz, float3(0.0), float3(1.0));
                                        float3 _14677 = select(powr((_14668 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14668 * float3(0.077399380505084991455078125), _14668 <= float3(0.040449999272823333740234375));
                                        float4 _35182 = _14659;
                                        _35182.x = _14677.x;
                                        _35182.y = _14677.y;
                                        _35182.z = _14677.z;
                                        _36872 = _35182;
                                    }
                                    else
                                    {
                                        _36872 = _14659;
                                    }
                                    float4 _14695 = srcTex.read(uint2(int3(_14615, _14577.y, 0).xy), 0);
                                    float4 _36874;
                                    if (_14590)
                                    {
                                        float3 _14704 = fast::clamp(_14695.xyz, float3(0.0), float3(1.0));
                                        float3 _14713 = select(powr((_14704 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14704 * float3(0.077399380505084991455078125), _14704 <= float3(0.040449999272823333740234375));
                                        float4 _35191 = _14695;
                                        _35191.x = _14713.x;
                                        _35191.y = _14713.y;
                                        _35191.z = _14713.z;
                                        _36874 = _35191;
                                    }
                                    else
                                    {
                                        _36874 = _14695;
                                    }
                                    float4 _14724 = float4(_14569.x);
                                    _14735 = mix(mix(_36866, _36869, _14724), mix(_36872, _36874, _14724), float4(_14569.y));
                                    break;
                                } while(false);
                                float _14742 = exp(abs(dot(_14735.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)) - _4286) * (-8.0));
                                float2 _14763 = float2(_13954, in.i_uv.y);
                                float4 _15000;
                                do
                                {
                                    if (_6338)
                                    {
                                        _15000 = srcTex.sample(samp, _14763, level(0.0));
                                        break;
                                    }
                                    uint2 _14775 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _14777 = _14775.x;
                                    uint _14779 = _14775.y;
                                    float2 _14785 = (_14763 * float2(float(_14777), float(_14779))) - float2(0.5);
                                    int2 _14790 = int2(int(_14777), int(_14779)) - int2(1);
                                    float2 _14791 = rint(_14785);
                                    if (all(abs(_14785 - _14791) < float2(0.001953125)))
                                    {
                                        float4 _14806 = srcTex.read(uint2(int3(clamp(int2(_14791), int2(0), _14790), 0).xy), 0);
                                        float4 _36899;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _14815 = fast::clamp(_14806.xyz, float3(0.0), float3(1.0));
                                            float3 _14824 = select(powr((_14815 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14815 * float3(0.077399380505084991455078125), _14815 <= float3(0.040449999272823333740234375));
                                            float4 _35205 = _14806;
                                            _35205.x = _14824.x;
                                            _35205.y = _14824.y;
                                            _35205.z = _14824.z;
                                            _36899 = _35205;
                                        }
                                        else
                                        {
                                            _36899 = _14806;
                                        }
                                        _15000 = _36899;
                                        break;
                                    }
                                    float2 _14834 = fract(_14785);
                                    int2 _14836 = int2(floor(_14785));
                                    int2 _14837 = clamp(_14836, int2(0), _14790);
                                    int2 _14842 = clamp(_14836 + int2(1), int2(0), _14790);
                                    int _14844 = _14837.x;
                                    float4 _14852 = srcTex.read(uint2(int3(_14844, _14837.y, 0).xy), 0);
                                    bool _14855 = _6337 > 0.5;
                                    float4 _36886;
                                    if (_14855)
                                    {
                                        float3 _14861 = fast::clamp(_14852.xyz, float3(0.0), float3(1.0));
                                        float3 _14870 = select(powr((_14861 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14861 * float3(0.077399380505084991455078125), _14861 <= float3(0.040449999272823333740234375));
                                        float4 _35214 = _14852;
                                        _35214.x = _14870.x;
                                        _35214.y = _14870.y;
                                        _35214.z = _14870.z;
                                        _36886 = _35214;
                                    }
                                    else
                                    {
                                        _36886 = _14852;
                                    }
                                    int _14880 = _14842.x;
                                    float4 _14888 = srcTex.read(uint2(int3(_14880, _14837.y, 0).xy), 0);
                                    float4 _36889;
                                    if (_14855)
                                    {
                                        float3 _14897 = fast::clamp(_14888.xyz, float3(0.0), float3(1.0));
                                        float3 _14906 = select(powr((_14897 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14897 * float3(0.077399380505084991455078125), _14897 <= float3(0.040449999272823333740234375));
                                        float4 _35223 = _14888;
                                        _35223.x = _14906.x;
                                        _35223.y = _14906.y;
                                        _35223.z = _14906.z;
                                        _36889 = _35223;
                                    }
                                    else
                                    {
                                        _36889 = _14888;
                                    }
                                    float4 _14924 = srcTex.read(uint2(int3(_14844, _14842.y, 0).xy), 0);
                                    float4 _36892;
                                    if (_14855)
                                    {
                                        float3 _14933 = fast::clamp(_14924.xyz, float3(0.0), float3(1.0));
                                        float3 _14942 = select(powr((_14933 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14933 * float3(0.077399380505084991455078125), _14933 <= float3(0.040449999272823333740234375));
                                        float4 _35232 = _14924;
                                        _35232.x = _14942.x;
                                        _35232.y = _14942.y;
                                        _35232.z = _14942.z;
                                        _36892 = _35232;
                                    }
                                    else
                                    {
                                        _36892 = _14924;
                                    }
                                    float4 _14960 = srcTex.read(uint2(int3(_14880, _14842.y, 0).xy), 0);
                                    float4 _36894;
                                    if (_14855)
                                    {
                                        float3 _14969 = fast::clamp(_14960.xyz, float3(0.0), float3(1.0));
                                        float3 _14978 = select(powr((_14969 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _14969 * float3(0.077399380505084991455078125), _14969 <= float3(0.040449999272823333740234375));
                                        float4 _35241 = _14960;
                                        _35241.x = _14978.x;
                                        _35241.y = _14978.y;
                                        _35241.z = _14978.z;
                                        _36894 = _35241;
                                    }
                                    else
                                    {
                                        _36894 = _14960;
                                    }
                                    float4 _14989 = float4(_14834.x);
                                    _15000 = mix(mix(_36886, _36889, _14989), mix(_36892, _36894, _14989), float4(_14834.y));
                                    break;
                                } while(false);
                                float _15007 = exp(abs(dot(_15000.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)) - _4286) * (-8.0));
                                float _15038 = in.i_uv.y + _4104;
                                float2 _15039 = float2(_4305, _15038);
                                float4 _15276;
                                do
                                {
                                    if (_6338)
                                    {
                                        _15276 = srcTex.sample(samp, _15039, level(0.0));
                                        break;
                                    }
                                    uint2 _15051 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _15053 = _15051.x;
                                    uint _15055 = _15051.y;
                                    float2 _15061 = (_15039 * float2(float(_15053), float(_15055))) - float2(0.5);
                                    int2 _15066 = int2(int(_15053), int(_15055)) - int2(1);
                                    float2 _15067 = rint(_15061);
                                    if (all(abs(_15061 - _15067) < float2(0.001953125)))
                                    {
                                        float4 _15082 = srcTex.read(uint2(int3(clamp(int2(_15067), int2(0), _15066), 0).xy), 0);
                                        float4 _36919;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _15091 = fast::clamp(_15082.xyz, float3(0.0), float3(1.0));
                                            float3 _15100 = select(powr((_15091 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15091 * float3(0.077399380505084991455078125), _15091 <= float3(0.040449999272823333740234375));
                                            float4 _35255 = _15082;
                                            _35255.x = _15100.x;
                                            _35255.y = _15100.y;
                                            _35255.z = _15100.z;
                                            _36919 = _35255;
                                        }
                                        else
                                        {
                                            _36919 = _15082;
                                        }
                                        _15276 = _36919;
                                        break;
                                    }
                                    float2 _15110 = fract(_15061);
                                    int2 _15112 = int2(floor(_15061));
                                    int2 _15113 = clamp(_15112, int2(0), _15066);
                                    int2 _15118 = clamp(_15112 + int2(1), int2(0), _15066);
                                    int _15120 = _15113.x;
                                    float4 _15128 = srcTex.read(uint2(int3(_15120, _15113.y, 0).xy), 0);
                                    bool _15131 = _6337 > 0.5;
                                    float4 _36906;
                                    if (_15131)
                                    {
                                        float3 _15137 = fast::clamp(_15128.xyz, float3(0.0), float3(1.0));
                                        float3 _15146 = select(powr((_15137 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15137 * float3(0.077399380505084991455078125), _15137 <= float3(0.040449999272823333740234375));
                                        float4 _35264 = _15128;
                                        _35264.x = _15146.x;
                                        _35264.y = _15146.y;
                                        _35264.z = _15146.z;
                                        _36906 = _35264;
                                    }
                                    else
                                    {
                                        _36906 = _15128;
                                    }
                                    int _15156 = _15118.x;
                                    float4 _15164 = srcTex.read(uint2(int3(_15156, _15113.y, 0).xy), 0);
                                    float4 _36909;
                                    if (_15131)
                                    {
                                        float3 _15173 = fast::clamp(_15164.xyz, float3(0.0), float3(1.0));
                                        float3 _15182 = select(powr((_15173 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15173 * float3(0.077399380505084991455078125), _15173 <= float3(0.040449999272823333740234375));
                                        float4 _35273 = _15164;
                                        _35273.x = _15182.x;
                                        _35273.y = _15182.y;
                                        _35273.z = _15182.z;
                                        _36909 = _35273;
                                    }
                                    else
                                    {
                                        _36909 = _15164;
                                    }
                                    float4 _15200 = srcTex.read(uint2(int3(_15120, _15118.y, 0).xy), 0);
                                    float4 _36912;
                                    if (_15131)
                                    {
                                        float3 _15209 = fast::clamp(_15200.xyz, float3(0.0), float3(1.0));
                                        float3 _15218 = select(powr((_15209 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15209 * float3(0.077399380505084991455078125), _15209 <= float3(0.040449999272823333740234375));
                                        float4 _35282 = _15200;
                                        _35282.x = _15218.x;
                                        _35282.y = _15218.y;
                                        _35282.z = _15218.z;
                                        _36912 = _35282;
                                    }
                                    else
                                    {
                                        _36912 = _15200;
                                    }
                                    float4 _15236 = srcTex.read(uint2(int3(_15156, _15118.y, 0).xy), 0);
                                    float4 _36914;
                                    if (_15131)
                                    {
                                        float3 _15245 = fast::clamp(_15236.xyz, float3(0.0), float3(1.0));
                                        float3 _15254 = select(powr((_15245 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15245 * float3(0.077399380505084991455078125), _15245 <= float3(0.040449999272823333740234375));
                                        float4 _35291 = _15236;
                                        _35291.x = _15254.x;
                                        _35291.y = _15254.y;
                                        _35291.z = _15254.z;
                                        _36914 = _35291;
                                    }
                                    else
                                    {
                                        _36914 = _15236;
                                    }
                                    float4 _15265 = float4(_15110.x);
                                    _15276 = mix(mix(_36906, _36909, _15265), mix(_36912, _36914, _15265), float4(_15110.y));
                                    break;
                                } while(false);
                                float _15283 = exp(abs(dot(_15276.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)) - _4286) * (-8.0));
                                float2 _15304 = float2(_4278, _15038);
                                float4 _15541;
                                do
                                {
                                    if (_6338)
                                    {
                                        _15541 = srcTex.sample(samp, _15304, level(0.0));
                                        break;
                                    }
                                    uint2 _15316 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _15318 = _15316.x;
                                    uint _15320 = _15316.y;
                                    float2 _15326 = (_15304 * float2(float(_15318), float(_15320))) - float2(0.5);
                                    int2 _15331 = int2(int(_15318), int(_15320)) - int2(1);
                                    float2 _15332 = rint(_15326);
                                    if (all(abs(_15326 - _15332) < float2(0.001953125)))
                                    {
                                        float4 _15347 = srcTex.read(uint2(int3(clamp(int2(_15332), int2(0), _15331), 0).xy), 0);
                                        float4 _36939;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _15356 = fast::clamp(_15347.xyz, float3(0.0), float3(1.0));
                                            float3 _15365 = select(powr((_15356 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15356 * float3(0.077399380505084991455078125), _15356 <= float3(0.040449999272823333740234375));
                                            float4 _35305 = _15347;
                                            _35305.x = _15365.x;
                                            _35305.y = _15365.y;
                                            _35305.z = _15365.z;
                                            _36939 = _35305;
                                        }
                                        else
                                        {
                                            _36939 = _15347;
                                        }
                                        _15541 = _36939;
                                        break;
                                    }
                                    float2 _15375 = fract(_15326);
                                    int2 _15377 = int2(floor(_15326));
                                    int2 _15378 = clamp(_15377, int2(0), _15331);
                                    int2 _15383 = clamp(_15377 + int2(1), int2(0), _15331);
                                    int _15385 = _15378.x;
                                    float4 _15393 = srcTex.read(uint2(int3(_15385, _15378.y, 0).xy), 0);
                                    bool _15396 = _6337 > 0.5;
                                    float4 _36926;
                                    if (_15396)
                                    {
                                        float3 _15402 = fast::clamp(_15393.xyz, float3(0.0), float3(1.0));
                                        float3 _15411 = select(powr((_15402 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15402 * float3(0.077399380505084991455078125), _15402 <= float3(0.040449999272823333740234375));
                                        float4 _35314 = _15393;
                                        _35314.x = _15411.x;
                                        _35314.y = _15411.y;
                                        _35314.z = _15411.z;
                                        _36926 = _35314;
                                    }
                                    else
                                    {
                                        _36926 = _15393;
                                    }
                                    int _15421 = _15383.x;
                                    float4 _15429 = srcTex.read(uint2(int3(_15421, _15378.y, 0).xy), 0);
                                    float4 _36929;
                                    if (_15396)
                                    {
                                        float3 _15438 = fast::clamp(_15429.xyz, float3(0.0), float3(1.0));
                                        float3 _15447 = select(powr((_15438 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15438 * float3(0.077399380505084991455078125), _15438 <= float3(0.040449999272823333740234375));
                                        float4 _35323 = _15429;
                                        _35323.x = _15447.x;
                                        _35323.y = _15447.y;
                                        _35323.z = _15447.z;
                                        _36929 = _35323;
                                    }
                                    else
                                    {
                                        _36929 = _15429;
                                    }
                                    float4 _15465 = srcTex.read(uint2(int3(_15385, _15383.y, 0).xy), 0);
                                    float4 _36932;
                                    if (_15396)
                                    {
                                        float3 _15474 = fast::clamp(_15465.xyz, float3(0.0), float3(1.0));
                                        float3 _15483 = select(powr((_15474 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15474 * float3(0.077399380505084991455078125), _15474 <= float3(0.040449999272823333740234375));
                                        float4 _35332 = _15465;
                                        _35332.x = _15483.x;
                                        _35332.y = _15483.y;
                                        _35332.z = _15483.z;
                                        _36932 = _35332;
                                    }
                                    else
                                    {
                                        _36932 = _15465;
                                    }
                                    float4 _15501 = srcTex.read(uint2(int3(_15421, _15383.y, 0).xy), 0);
                                    float4 _36934;
                                    if (_15396)
                                    {
                                        float3 _15510 = fast::clamp(_15501.xyz, float3(0.0), float3(1.0));
                                        float3 _15519 = select(powr((_15510 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15510 * float3(0.077399380505084991455078125), _15510 <= float3(0.040449999272823333740234375));
                                        float4 _35341 = _15501;
                                        _35341.x = _15519.x;
                                        _35341.y = _15519.y;
                                        _35341.z = _15519.z;
                                        _36934 = _35341;
                                    }
                                    else
                                    {
                                        _36934 = _15501;
                                    }
                                    float4 _15530 = float4(_15375.x);
                                    _15541 = mix(mix(_36926, _36929, _15530), mix(_36932, _36934, _15530), float4(_15375.y));
                                    break;
                                } while(false);
                                float _15548 = exp(abs(dot(_15541.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)) - _4286) * (-8.0));
                                float2 _15569 = float2(_13954, _15038);
                                float4 _15806;
                                do
                                {
                                    if (_6338)
                                    {
                                        _15806 = srcTex.sample(samp, _15569, level(0.0));
                                        break;
                                    }
                                    uint2 _15581 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _15583 = _15581.x;
                                    uint _15585 = _15581.y;
                                    float2 _15591 = (_15569 * float2(float(_15583), float(_15585))) - float2(0.5);
                                    int2 _15596 = int2(int(_15583), int(_15585)) - int2(1);
                                    float2 _15597 = rint(_15591);
                                    if (all(abs(_15591 - _15597) < float2(0.001953125)))
                                    {
                                        float4 _15612 = srcTex.read(uint2(int3(clamp(int2(_15597), int2(0), _15596), 0).xy), 0);
                                        float4 _36959;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _15621 = fast::clamp(_15612.xyz, float3(0.0), float3(1.0));
                                            float3 _15630 = select(powr((_15621 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15621 * float3(0.077399380505084991455078125), _15621 <= float3(0.040449999272823333740234375));
                                            float4 _35355 = _15612;
                                            _35355.x = _15630.x;
                                            _35355.y = _15630.y;
                                            _35355.z = _15630.z;
                                            _36959 = _35355;
                                        }
                                        else
                                        {
                                            _36959 = _15612;
                                        }
                                        _15806 = _36959;
                                        break;
                                    }
                                    float2 _15640 = fract(_15591);
                                    int2 _15642 = int2(floor(_15591));
                                    int2 _15643 = clamp(_15642, int2(0), _15596);
                                    int2 _15648 = clamp(_15642 + int2(1), int2(0), _15596);
                                    int _15650 = _15643.x;
                                    float4 _15658 = srcTex.read(uint2(int3(_15650, _15643.y, 0).xy), 0);
                                    bool _15661 = _6337 > 0.5;
                                    float4 _36946;
                                    if (_15661)
                                    {
                                        float3 _15667 = fast::clamp(_15658.xyz, float3(0.0), float3(1.0));
                                        float3 _15676 = select(powr((_15667 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15667 * float3(0.077399380505084991455078125), _15667 <= float3(0.040449999272823333740234375));
                                        float4 _35364 = _15658;
                                        _35364.x = _15676.x;
                                        _35364.y = _15676.y;
                                        _35364.z = _15676.z;
                                        _36946 = _35364;
                                    }
                                    else
                                    {
                                        _36946 = _15658;
                                    }
                                    int _15686 = _15648.x;
                                    float4 _15694 = srcTex.read(uint2(int3(_15686, _15643.y, 0).xy), 0);
                                    float4 _36949;
                                    if (_15661)
                                    {
                                        float3 _15703 = fast::clamp(_15694.xyz, float3(0.0), float3(1.0));
                                        float3 _15712 = select(powr((_15703 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15703 * float3(0.077399380505084991455078125), _15703 <= float3(0.040449999272823333740234375));
                                        float4 _35373 = _15694;
                                        _35373.x = _15712.x;
                                        _35373.y = _15712.y;
                                        _35373.z = _15712.z;
                                        _36949 = _35373;
                                    }
                                    else
                                    {
                                        _36949 = _15694;
                                    }
                                    float4 _15730 = srcTex.read(uint2(int3(_15650, _15648.y, 0).xy), 0);
                                    float4 _36952;
                                    if (_15661)
                                    {
                                        float3 _15739 = fast::clamp(_15730.xyz, float3(0.0), float3(1.0));
                                        float3 _15748 = select(powr((_15739 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15739 * float3(0.077399380505084991455078125), _15739 <= float3(0.040449999272823333740234375));
                                        float4 _35382 = _15730;
                                        _35382.x = _15748.x;
                                        _35382.y = _15748.y;
                                        _35382.z = _15748.z;
                                        _36952 = _35382;
                                    }
                                    else
                                    {
                                        _36952 = _15730;
                                    }
                                    float4 _15766 = srcTex.read(uint2(int3(_15686, _15648.y, 0).xy), 0);
                                    float4 _36954;
                                    if (_15661)
                                    {
                                        float3 _15775 = fast::clamp(_15766.xyz, float3(0.0), float3(1.0));
                                        float3 _15784 = select(powr((_15775 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _15775 * float3(0.077399380505084991455078125), _15775 <= float3(0.040449999272823333740234375));
                                        float4 _35391 = _15766;
                                        _35391.x = _15784.x;
                                        _35391.y = _15784.y;
                                        _35391.z = _15784.z;
                                        _36954 = _35391;
                                    }
                                    else
                                    {
                                        _36954 = _15766;
                                    }
                                    float4 _15795 = float4(_15640.x);
                                    _15806 = mix(mix(_36946, _36949, _15795), mix(_36952, _36954, _15795), float4(_15640.y));
                                    break;
                                } while(false);
                                float _15813 = exp(abs(dot(_15806.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)) - _4286) * (-8.0));
                                float3 _13554;
                                do
                                {
                                    if (_8997)
                                    {
                                        _13554 = select(float3(0.0, 1.0, 1.0), float3(1.0, 0.0, 0.0), bool3(!_13391));
                                        break;
                                    }
                                    if (_395.g_anaCombo == 1)
                                    {
                                        _13554 = select(float3(0.0, 1.0, 0.0), float3(1.0, 0.0, 0.0), bool3(!_13391));
                                        break;
                                    }
                                    if (_395.g_anaCombo == 2)
                                    {
                                        _13554 = select(float3(0.0, 0.0, 1.0), float3(1.0, 0.0, 0.0), bool3(!_13391));
                                        break;
                                    }
                                    if (_395.g_anaCombo == 3)
                                    {
                                        _13554 = select(float3(1.0, 0.0, 1.0), float3(0.0, 1.0, 0.0), bool3(!_13391));
                                        break;
                                    }
                                    if (_395.g_anaCombo == 4)
                                    {
                                        _13554 = select(float3(0.0, 0.0, 1.0), float3(1.0, 1.0, 0.0), bool3(!_13391));
                                        break;
                                    }
                                    _13554 = select(float3(1.0, 0.0, 1.0), float3(0.0, 1.0, 1.0), bool3(!_13391));
                                    break;
                                } while(false);
                                float3 _4358 = (_13446.xyz * _13554) + (((((((((((_13578.xyz * _4325) + (_13929.xyz * _13936)) + (_14197.xyz * _14204)) + (_14470.xyz * _14477)) + (_14735.xyz * _14742)) + (_15000.xyz * _15007)) + (_15276.xyz * _15283)) + (_15541.xyz * _15548)) + (_15806.xyz * _15813)) / float3(((((((((9.9999997473787516355514526367188e-05 + _4325) + _13936) + _14204) + _14477) + _14742) + _15007) + _15283) + _15548) + _15813)) * (float3(1.0) - _13554));
                                float3 _4366 = _4358 * (_13546 / fast::max(dot(_4358, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)), 0.001000000047497451305389404296875));
                                float _4374 = fast::max(fast::max(_4366.x, _4366.y), _4366.z);
                                float3 _36960;
                                if (_4374 > 1.0)
                                {
                                    _36960 = _4366 / float3(_4374);
                                }
                                else
                                {
                                    _36960 = _4366;
                                }
                                _13619 = float4(fast::clamp(_36960, float3(0.0), float3(1.0)), _35925);
                                break;
                            }
                            bool _4394 = _395.g_anaMode == 0;
                            if (_4394 || _3914)
                            {
                                float _13467;
                                do
                                {
                                    if (_395.g_anaCombo == 0)
                                    {
                                        _13467 = (!_13391) ? _13446.x : ((_13446.y + _13446.z) * 0.5);
                                        break;
                                    }
                                    if (_395.g_anaCombo == 1)
                                    {
                                        _13467 = (!_13391) ? _13446.x : _13446.y;
                                        break;
                                    }
                                    if (_395.g_anaCombo == 2)
                                    {
                                        _13467 = (!_13391) ? _13446.x : _13446.z;
                                        break;
                                    }
                                    if (_395.g_anaCombo == 3)
                                    {
                                        _13467 = (!_13391) ? _13446.y : ((_13446.x + _13446.z) * 0.5);
                                        break;
                                    }
                                    if (_395.g_anaCombo == 4)
                                    {
                                        _13467 = (!_13391) ? ((_13446.x + _13446.y) * 0.5) : _13446.z;
                                        break;
                                    }
                                    _13467 = (!_13391) ? ((_13446.y + _13446.z) * 0.5) : ((_13446.x + _13446.z) * 0.5);
                                    break;
                                } while(false);
                                float4 _13468;
                                do
                                {
                                    if (_6338)
                                    {
                                        _13468 = srcTex.sample(samp, _3574, level(0.0));
                                        break;
                                    }
                                    uint2 _9989 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _9991 = _9989.x;
                                    uint _9993 = _9989.y;
                                    float2 _10002 = (_3574 * float2(float(_9991), float(_9993))) - float2(0.5);
                                    int2 _10009 = int2(int(_9991), int(_9993)) - int2(1);
                                    float2 _10011 = rint(_10002);
                                    if (all(abs(_10002 - _10011) < float2(0.001953125)))
                                    {
                                        float4 _10093 = srcTex.read(uint2(int3(clamp(int2(_10011), int2(0), _10009), 0).xy), 0);
                                        float4 _36152;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _10102 = fast::clamp(_10093.xyz, float3(0.0), float3(1.0));
                                            float3 _10125 = select(powr((_10102 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10102 * float3(0.077399380505084991455078125), _10102 <= float3(0.040449999272823333740234375));
                                            float4 _35440 = _10093;
                                            _35440.x = _10125.x;
                                            _35440.y = _10125.y;
                                            _35440.z = _10125.z;
                                            _36152 = _35440;
                                        }
                                        else
                                        {
                                            _36152 = _10093;
                                        }
                                        _13468 = _36152;
                                        break;
                                    }
                                    float2 _10029 = fract(_10002);
                                    int2 _10032 = int2(floor(_10002));
                                    int2 _10034 = clamp(_10032, int2(0), _10009);
                                    int2 _10041 = clamp(_10032 + int2(1), int2(0), _10009);
                                    int _10043 = _10034.x;
                                    float4 _10135 = srcTex.read(uint2(int3(_10043, _10034.y, 0).xy), 0);
                                    bool _10138 = _6337 > 0.5;
                                    float4 _36148;
                                    if (_10138)
                                    {
                                        float3 _10144 = fast::clamp(_10135.xyz, float3(0.0), float3(1.0));
                                        float3 _10167 = select(powr((_10144 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10144 * float3(0.077399380505084991455078125), _10144 <= float3(0.040449999272823333740234375));
                                        float4 _35449 = _10135;
                                        _35449.x = _10167.x;
                                        _35449.y = _10167.y;
                                        _35449.z = _10167.z;
                                        _36148 = _35449;
                                    }
                                    else
                                    {
                                        _36148 = _10135;
                                    }
                                    int _10049 = _10041.x;
                                    float4 _10177 = srcTex.read(uint2(int3(_10049, _10034.y, 0).xy), 0);
                                    float4 _36149;
                                    if (_10138)
                                    {
                                        float3 _10186 = fast::clamp(_10177.xyz, float3(0.0), float3(1.0));
                                        float3 _10209 = select(powr((_10186 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10186 * float3(0.077399380505084991455078125), _10186 <= float3(0.040449999272823333740234375));
                                        float4 _35458 = _10177;
                                        _35458.x = _10209.x;
                                        _35458.y = _10209.y;
                                        _35458.z = _10209.z;
                                        _36149 = _35458;
                                    }
                                    else
                                    {
                                        _36149 = _10177;
                                    }
                                    float4 _10219 = srcTex.read(uint2(int3(_10043, _10041.y, 0).xy), 0);
                                    float4 _36150;
                                    if (_10138)
                                    {
                                        float3 _10228 = fast::clamp(_10219.xyz, float3(0.0), float3(1.0));
                                        float3 _10251 = select(powr((_10228 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10228 * float3(0.077399380505084991455078125), _10228 <= float3(0.040449999272823333740234375));
                                        float4 _35467 = _10219;
                                        _35467.x = _10251.x;
                                        _35467.y = _10251.y;
                                        _35467.z = _10251.z;
                                        _36150 = _35467;
                                    }
                                    else
                                    {
                                        _36150 = _10219;
                                    }
                                    float4 _10261 = srcTex.read(uint2(int3(_10049, _10041.y, 0).xy), 0);
                                    float4 _36151;
                                    if (_10138)
                                    {
                                        float3 _10270 = fast::clamp(_10261.xyz, float3(0.0), float3(1.0));
                                        float3 _10293 = select(powr((_10270 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10270 * float3(0.077399380505084991455078125), _10270 <= float3(0.040449999272823333740234375));
                                        float4 _35476 = _10261;
                                        _35476.x = _10293.x;
                                        _35476.y = _10293.y;
                                        _35476.z = _10293.z;
                                        _36151 = _35476;
                                    }
                                    else
                                    {
                                        _36151 = _10261;
                                    }
                                    float4 _10070 = float4(_10029.x);
                                    _13468 = mix(mix(_36148, _36149, _10070), mix(_36150, _36151, _10070), float4(_10029.y));
                                    break;
                                } while(false);
                                float _4424 = 1.5 / _395.g_srcW;
                                float2 _4431 = float2(_3592 - _4424, in.i_uv.y);
                                float4 _13471;
                                do
                                {
                                    if (_6338)
                                    {
                                        _13471 = srcTex.sample(samp, _4431, level(0.0));
                                        break;
                                    }
                                    uint2 _10337 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _10339 = _10337.x;
                                    uint _10341 = _10337.y;
                                    float2 _10350 = (_4431 * float2(float(_10339), float(_10341))) - float2(0.5);
                                    int2 _10357 = int2(int(_10339), int(_10341)) - int2(1);
                                    float2 _10359 = rint(_10350);
                                    if (all(abs(_10350 - _10359) < float2(0.001953125)))
                                    {
                                        float4 _10441 = srcTex.read(uint2(int3(clamp(int2(_10359), int2(0), _10357), 0).xy), 0);
                                        float4 _36172;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _10450 = fast::clamp(_10441.xyz, float3(0.0), float3(1.0));
                                            float3 _10473 = select(powr((_10450 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10450 * float3(0.077399380505084991455078125), _10450 <= float3(0.040449999272823333740234375));
                                            float4 _35490 = _10441;
                                            _35490.x = _10473.x;
                                            _35490.y = _10473.y;
                                            _35490.z = _10473.z;
                                            _36172 = _35490;
                                        }
                                        else
                                        {
                                            _36172 = _10441;
                                        }
                                        _13471 = _36172;
                                        break;
                                    }
                                    float2 _10377 = fract(_10350);
                                    int2 _10380 = int2(floor(_10350));
                                    int2 _10382 = clamp(_10380, int2(0), _10357);
                                    int2 _10389 = clamp(_10380 + int2(1), int2(0), _10357);
                                    int _10391 = _10382.x;
                                    float4 _10483 = srcTex.read(uint2(int3(_10391, _10382.y, 0).xy), 0);
                                    bool _10486 = _6337 > 0.5;
                                    float4 _36159;
                                    if (_10486)
                                    {
                                        float3 _10492 = fast::clamp(_10483.xyz, float3(0.0), float3(1.0));
                                        float3 _10515 = select(powr((_10492 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10492 * float3(0.077399380505084991455078125), _10492 <= float3(0.040449999272823333740234375));
                                        float4 _35499 = _10483;
                                        _35499.x = _10515.x;
                                        _35499.y = _10515.y;
                                        _35499.z = _10515.z;
                                        _36159 = _35499;
                                    }
                                    else
                                    {
                                        _36159 = _10483;
                                    }
                                    int _10397 = _10389.x;
                                    float4 _10525 = srcTex.read(uint2(int3(_10397, _10382.y, 0).xy), 0);
                                    float4 _36162;
                                    if (_10486)
                                    {
                                        float3 _10534 = fast::clamp(_10525.xyz, float3(0.0), float3(1.0));
                                        float3 _10557 = select(powr((_10534 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10534 * float3(0.077399380505084991455078125), _10534 <= float3(0.040449999272823333740234375));
                                        float4 _35508 = _10525;
                                        _35508.x = _10557.x;
                                        _35508.y = _10557.y;
                                        _35508.z = _10557.z;
                                        _36162 = _35508;
                                    }
                                    else
                                    {
                                        _36162 = _10525;
                                    }
                                    float4 _10567 = srcTex.read(uint2(int3(_10391, _10389.y, 0).xy), 0);
                                    float4 _36165;
                                    if (_10486)
                                    {
                                        float3 _10576 = fast::clamp(_10567.xyz, float3(0.0), float3(1.0));
                                        float3 _10599 = select(powr((_10576 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10576 * float3(0.077399380505084991455078125), _10576 <= float3(0.040449999272823333740234375));
                                        float4 _35517 = _10567;
                                        _35517.x = _10599.x;
                                        _35517.y = _10599.y;
                                        _35517.z = _10599.z;
                                        _36165 = _35517;
                                    }
                                    else
                                    {
                                        _36165 = _10567;
                                    }
                                    float4 _10609 = srcTex.read(uint2(int3(_10397, _10389.y, 0).xy), 0);
                                    float4 _36167;
                                    if (_10486)
                                    {
                                        float3 _10618 = fast::clamp(_10609.xyz, float3(0.0), float3(1.0));
                                        float3 _10641 = select(powr((_10618 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10618 * float3(0.077399380505084991455078125), _10618 <= float3(0.040449999272823333740234375));
                                        float4 _35526 = _10609;
                                        _35526.x = _10641.x;
                                        _35526.y = _10641.y;
                                        _35526.z = _10641.z;
                                        _36167 = _35526;
                                    }
                                    else
                                    {
                                        _36167 = _10609;
                                    }
                                    float4 _10418 = float4(_10377.x);
                                    _13471 = mix(mix(_36159, _36162, _10418), mix(_36165, _36167, _10418), float4(_10377.y));
                                    break;
                                } while(false);
                                float2 _4441 = float2(_3592 + _4424, in.i_uv.y);
                                float4 _13472;
                                do
                                {
                                    if (_6338)
                                    {
                                        _13472 = srcTex.sample(samp, _4441, level(0.0));
                                        break;
                                    }
                                    uint2 _10685 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _10687 = _10685.x;
                                    uint _10689 = _10685.y;
                                    float2 _10698 = (_4441 * float2(float(_10687), float(_10689))) - float2(0.5);
                                    int2 _10705 = int2(int(_10687), int(_10689)) - int2(1);
                                    float2 _10707 = rint(_10698);
                                    if (all(abs(_10698 - _10707) < float2(0.001953125)))
                                    {
                                        float4 _10789 = srcTex.read(uint2(int3(clamp(int2(_10707), int2(0), _10705), 0).xy), 0);
                                        float4 _36192;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _10798 = fast::clamp(_10789.xyz, float3(0.0), float3(1.0));
                                            float3 _10821 = select(powr((_10798 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10798 * float3(0.077399380505084991455078125), _10798 <= float3(0.040449999272823333740234375));
                                            float4 _35540 = _10789;
                                            _35540.x = _10821.x;
                                            _35540.y = _10821.y;
                                            _35540.z = _10821.z;
                                            _36192 = _35540;
                                        }
                                        else
                                        {
                                            _36192 = _10789;
                                        }
                                        _13472 = _36192;
                                        break;
                                    }
                                    float2 _10725 = fract(_10698);
                                    int2 _10728 = int2(floor(_10698));
                                    int2 _10730 = clamp(_10728, int2(0), _10705);
                                    int2 _10737 = clamp(_10728 + int2(1), int2(0), _10705);
                                    int _10739 = _10730.x;
                                    float4 _10831 = srcTex.read(uint2(int3(_10739, _10730.y, 0).xy), 0);
                                    bool _10834 = _6337 > 0.5;
                                    float4 _36179;
                                    if (_10834)
                                    {
                                        float3 _10840 = fast::clamp(_10831.xyz, float3(0.0), float3(1.0));
                                        float3 _10863 = select(powr((_10840 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10840 * float3(0.077399380505084991455078125), _10840 <= float3(0.040449999272823333740234375));
                                        float4 _35549 = _10831;
                                        _35549.x = _10863.x;
                                        _35549.y = _10863.y;
                                        _35549.z = _10863.z;
                                        _36179 = _35549;
                                    }
                                    else
                                    {
                                        _36179 = _10831;
                                    }
                                    int _10745 = _10737.x;
                                    float4 _10873 = srcTex.read(uint2(int3(_10745, _10730.y, 0).xy), 0);
                                    float4 _36182;
                                    if (_10834)
                                    {
                                        float3 _10882 = fast::clamp(_10873.xyz, float3(0.0), float3(1.0));
                                        float3 _10905 = select(powr((_10882 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10882 * float3(0.077399380505084991455078125), _10882 <= float3(0.040449999272823333740234375));
                                        float4 _35558 = _10873;
                                        _35558.x = _10905.x;
                                        _35558.y = _10905.y;
                                        _35558.z = _10905.z;
                                        _36182 = _35558;
                                    }
                                    else
                                    {
                                        _36182 = _10873;
                                    }
                                    float4 _10915 = srcTex.read(uint2(int3(_10739, _10737.y, 0).xy), 0);
                                    float4 _36185;
                                    if (_10834)
                                    {
                                        float3 _10924 = fast::clamp(_10915.xyz, float3(0.0), float3(1.0));
                                        float3 _10947 = select(powr((_10924 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10924 * float3(0.077399380505084991455078125), _10924 <= float3(0.040449999272823333740234375));
                                        float4 _35567 = _10915;
                                        _35567.x = _10947.x;
                                        _35567.y = _10947.y;
                                        _35567.z = _10947.z;
                                        _36185 = _35567;
                                    }
                                    else
                                    {
                                        _36185 = _10915;
                                    }
                                    float4 _10957 = srcTex.read(uint2(int3(_10745, _10737.y, 0).xy), 0);
                                    float4 _36187;
                                    if (_10834)
                                    {
                                        float3 _10966 = fast::clamp(_10957.xyz, float3(0.0), float3(1.0));
                                        float3 _10989 = select(powr((_10966 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _10966 * float3(0.077399380505084991455078125), _10966 <= float3(0.040449999272823333740234375));
                                        float4 _35576 = _10957;
                                        _35576.x = _10989.x;
                                        _35576.y = _10989.y;
                                        _35576.z = _10989.z;
                                        _36187 = _35576;
                                    }
                                    else
                                    {
                                        _36187 = _10957;
                                    }
                                    float4 _10766 = float4(_10725.x);
                                    _13472 = mix(mix(_36179, _36182, _10766), mix(_36185, _36187, _10766), float4(_10725.y));
                                    break;
                                } while(false);
                                float _23947 = 3.5 / _395.g_srcW;
                                float2 _23953 = float2(_3592 - _23947, in.i_uv.y);
                                float4 _24190;
                                do
                                {
                                    if (_6338)
                                    {
                                        _24190 = srcTex.sample(samp, _23953, level(0.0));
                                        break;
                                    }
                                    uint2 _23965 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _23967 = _23965.x;
                                    uint _23969 = _23965.y;
                                    float2 _23975 = (_23953 * float2(float(_23967), float(_23969))) - float2(0.5);
                                    int2 _23980 = int2(int(_23967), int(_23969)) - int2(1);
                                    float2 _23981 = rint(_23975);
                                    if (all(abs(_23975 - _23981) < float2(0.001953125)))
                                    {
                                        float4 _23996 = srcTex.read(uint2(int3(clamp(int2(_23981), int2(0), _23980), 0).xy), 0);
                                        float4 _36212;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _24005 = fast::clamp(_23996.xyz, float3(0.0), float3(1.0));
                                            float3 _24014 = select(powr((_24005 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24005 * float3(0.077399380505084991455078125), _24005 <= float3(0.040449999272823333740234375));
                                            float4 _35590 = _23996;
                                            _35590.x = _24014.x;
                                            _35590.y = _24014.y;
                                            _35590.z = _24014.z;
                                            _36212 = _35590;
                                        }
                                        else
                                        {
                                            _36212 = _23996;
                                        }
                                        _24190 = _36212;
                                        break;
                                    }
                                    float2 _24024 = fract(_23975);
                                    int2 _24026 = int2(floor(_23975));
                                    int2 _24027 = clamp(_24026, int2(0), _23980);
                                    int2 _24032 = clamp(_24026 + int2(1), int2(0), _23980);
                                    int _24034 = _24027.x;
                                    float4 _24042 = srcTex.read(uint2(int3(_24034, _24027.y, 0).xy), 0);
                                    bool _24045 = _6337 > 0.5;
                                    float4 _36199;
                                    if (_24045)
                                    {
                                        float3 _24051 = fast::clamp(_24042.xyz, float3(0.0), float3(1.0));
                                        float3 _24060 = select(powr((_24051 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24051 * float3(0.077399380505084991455078125), _24051 <= float3(0.040449999272823333740234375));
                                        float4 _35599 = _24042;
                                        _35599.x = _24060.x;
                                        _35599.y = _24060.y;
                                        _35599.z = _24060.z;
                                        _36199 = _35599;
                                    }
                                    else
                                    {
                                        _36199 = _24042;
                                    }
                                    int _24070 = _24032.x;
                                    float4 _24078 = srcTex.read(uint2(int3(_24070, _24027.y, 0).xy), 0);
                                    float4 _36202;
                                    if (_24045)
                                    {
                                        float3 _24087 = fast::clamp(_24078.xyz, float3(0.0), float3(1.0));
                                        float3 _24096 = select(powr((_24087 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24087 * float3(0.077399380505084991455078125), _24087 <= float3(0.040449999272823333740234375));
                                        float4 _35608 = _24078;
                                        _35608.x = _24096.x;
                                        _35608.y = _24096.y;
                                        _35608.z = _24096.z;
                                        _36202 = _35608;
                                    }
                                    else
                                    {
                                        _36202 = _24078;
                                    }
                                    float4 _24114 = srcTex.read(uint2(int3(_24034, _24032.y, 0).xy), 0);
                                    float4 _36205;
                                    if (_24045)
                                    {
                                        float3 _24123 = fast::clamp(_24114.xyz, float3(0.0), float3(1.0));
                                        float3 _24132 = select(powr((_24123 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24123 * float3(0.077399380505084991455078125), _24123 <= float3(0.040449999272823333740234375));
                                        float4 _35617 = _24114;
                                        _35617.x = _24132.x;
                                        _35617.y = _24132.y;
                                        _35617.z = _24132.z;
                                        _36205 = _35617;
                                    }
                                    else
                                    {
                                        _36205 = _24114;
                                    }
                                    float4 _24150 = srcTex.read(uint2(int3(_24070, _24032.y, 0).xy), 0);
                                    float4 _36207;
                                    if (_24045)
                                    {
                                        float3 _24159 = fast::clamp(_24150.xyz, float3(0.0), float3(1.0));
                                        float3 _24168 = select(powr((_24159 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24159 * float3(0.077399380505084991455078125), _24159 <= float3(0.040449999272823333740234375));
                                        float4 _35626 = _24150;
                                        _35626.x = _24168.x;
                                        _35626.y = _24168.y;
                                        _35626.z = _24168.z;
                                        _36207 = _35626;
                                    }
                                    else
                                    {
                                        _36207 = _24150;
                                    }
                                    float4 _24179 = float4(_24024.x);
                                    _24190 = mix(mix(_36199, _36202, _24179), mix(_36205, _36207, _24179), float4(_24024.y));
                                    break;
                                } while(false);
                                float2 _24197 = float2(_3592 + _23947, in.i_uv.y);
                                float4 _24434;
                                do
                                {
                                    if (_6338)
                                    {
                                        _24434 = srcTex.sample(samp, _24197, level(0.0));
                                        break;
                                    }
                                    uint2 _24209 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _24211 = _24209.x;
                                    uint _24213 = _24209.y;
                                    float2 _24219 = (_24197 * float2(float(_24211), float(_24213))) - float2(0.5);
                                    int2 _24224 = int2(int(_24211), int(_24213)) - int2(1);
                                    float2 _24225 = rint(_24219);
                                    if (all(abs(_24219 - _24225) < float2(0.001953125)))
                                    {
                                        float4 _24240 = srcTex.read(uint2(int3(clamp(int2(_24225), int2(0), _24224), 0).xy), 0);
                                        float4 _36232;
                                        if (_6337 > 0.5)
                                        {
                                            float3 _24249 = fast::clamp(_24240.xyz, float3(0.0), float3(1.0));
                                            float3 _24258 = select(powr((_24249 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24249 * float3(0.077399380505084991455078125), _24249 <= float3(0.040449999272823333740234375));
                                            float4 _35640 = _24240;
                                            _35640.x = _24258.x;
                                            _35640.y = _24258.y;
                                            _35640.z = _24258.z;
                                            _36232 = _35640;
                                        }
                                        else
                                        {
                                            _36232 = _24240;
                                        }
                                        _24434 = _36232;
                                        break;
                                    }
                                    float2 _24268 = fract(_24219);
                                    int2 _24270 = int2(floor(_24219));
                                    int2 _24271 = clamp(_24270, int2(0), _24224);
                                    int2 _24276 = clamp(_24270 + int2(1), int2(0), _24224);
                                    int _24278 = _24271.x;
                                    float4 _24286 = srcTex.read(uint2(int3(_24278, _24271.y, 0).xy), 0);
                                    bool _24289 = _6337 > 0.5;
                                    float4 _36219;
                                    if (_24289)
                                    {
                                        float3 _24295 = fast::clamp(_24286.xyz, float3(0.0), float3(1.0));
                                        float3 _24304 = select(powr((_24295 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24295 * float3(0.077399380505084991455078125), _24295 <= float3(0.040449999272823333740234375));
                                        float4 _35649 = _24286;
                                        _35649.x = _24304.x;
                                        _35649.y = _24304.y;
                                        _35649.z = _24304.z;
                                        _36219 = _35649;
                                    }
                                    else
                                    {
                                        _36219 = _24286;
                                    }
                                    int _24314 = _24276.x;
                                    float4 _24322 = srcTex.read(uint2(int3(_24314, _24271.y, 0).xy), 0);
                                    float4 _36222;
                                    if (_24289)
                                    {
                                        float3 _24331 = fast::clamp(_24322.xyz, float3(0.0), float3(1.0));
                                        float3 _24340 = select(powr((_24331 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24331 * float3(0.077399380505084991455078125), _24331 <= float3(0.040449999272823333740234375));
                                        float4 _35658 = _24322;
                                        _35658.x = _24340.x;
                                        _35658.y = _24340.y;
                                        _35658.z = _24340.z;
                                        _36222 = _35658;
                                    }
                                    else
                                    {
                                        _36222 = _24322;
                                    }
                                    float4 _24358 = srcTex.read(uint2(int3(_24278, _24276.y, 0).xy), 0);
                                    float4 _36225;
                                    if (_24289)
                                    {
                                        float3 _24367 = fast::clamp(_24358.xyz, float3(0.0), float3(1.0));
                                        float3 _24376 = select(powr((_24367 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24367 * float3(0.077399380505084991455078125), _24367 <= float3(0.040449999272823333740234375));
                                        float4 _35667 = _24358;
                                        _35667.x = _24376.x;
                                        _35667.y = _24376.y;
                                        _35667.z = _24376.z;
                                        _36225 = _35667;
                                    }
                                    else
                                    {
                                        _36225 = _24358;
                                    }
                                    float4 _24394 = srcTex.read(uint2(int3(_24314, _24276.y, 0).xy), 0);
                                    float4 _36227;
                                    if (_24289)
                                    {
                                        float3 _24403 = fast::clamp(_24394.xyz, float3(0.0), float3(1.0));
                                        float3 _24412 = select(powr((_24403 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24403 * float3(0.077399380505084991455078125), _24403 <= float3(0.040449999272823333740234375));
                                        float4 _35676 = _24394;
                                        _35676.x = _24412.x;
                                        _35676.y = _24412.y;
                                        _35676.z = _24412.z;
                                        _36227 = _35676;
                                    }
                                    else
                                    {
                                        _36227 = _24394;
                                    }
                                    float4 _24423 = float4(_24268.x);
                                    _24434 = mix(mix(_36219, _36222, _24423), mix(_36225, _36227, _24423), float4(_24268.y));
                                    break;
                                } while(false);
                                float3 _4455 = ((_13468.xyz + ((_13471.xyz + _13472.xyz) * 2.0)) + ((_24190.xyz + _24434.xyz) * 2.0)) * float3(0.111111111938953399658203125);
                                _13619 = float4(fast::clamp(_4455 * (_13467 / fast::max(dot(_4455, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)), 0.001000000047497451305389404296875)), float3(0.0), float3(1.0)), 1.0);
                                break;
                            }
                            float3 _13466;
                            do
                            {
                                bool _11067;
                                float _13464;
                                do
                                {
                                    _11067 = _395.g_anaCombo == 0;
                                    if (_11067)
                                    {
                                        _13464 = (!_13391) ? _13446.x : ((_13446.y + _13446.z) * 0.5);
                                        break;
                                    }
                                    if (_395.g_anaCombo == 1)
                                    {
                                        _13464 = (!_13391) ? _13446.x : _13446.y;
                                        break;
                                    }
                                    if (_395.g_anaCombo == 2)
                                    {
                                        _13464 = (!_13391) ? _13446.x : _13446.z;
                                        break;
                                    }
                                    if (_395.g_anaCombo == 3)
                                    {
                                        _13464 = (!_13391) ? _13446.y : ((_13446.x + _13446.z) * 0.5);
                                        break;
                                    }
                                    if (_395.g_anaCombo == 4)
                                    {
                                        _13464 = (!_13391) ? ((_13446.x + _13446.y) * 0.5) : _13446.z;
                                        break;
                                    }
                                    _13464 = (!_13391) ? ((_13446.y + _13446.z) * 0.5) : ((_13446.x + _13446.z) * 0.5);
                                    break;
                                } while(false);
                                if (_4394)
                                {
                                    _13466 = fast::clamp(_13446.xyz * (_13464 / fast::max(dot(_13446.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)), 0.001000000047497451305389404296875)), float3(0.0), float3(1.0));
                                    break;
                                }
                                float3 _13465;
                                do
                                {
                                    if (_11067)
                                    {
                                        _13465 = select(float3(0.0, _13446.yz), float3(_13446.x, 0.0, 0.0), bool3(!_13391));
                                        break;
                                    }
                                    if (_395.g_anaCombo == 1)
                                    {
                                        _13465 = select(float3(0.0, _13446.y, 0.0), float3(_13446.x, 0.0, 0.0), bool3(!_13391));
                                        break;
                                    }
                                    if (_395.g_anaCombo == 2)
                                    {
                                        _13465 = select(float3(0.0, 0.0, _13446.z), float3(_13446.x, 0.0, 0.0), bool3(!_13391));
                                        break;
                                    }
                                    if (_395.g_anaCombo == 3)
                                    {
                                        _13465 = select(float3(_13446.x, 0.0, _13446.z), float3(0.0, _13446.y, 0.0), bool3(!_13391));
                                        break;
                                    }
                                    if (_395.g_anaCombo == 4)
                                    {
                                        _13465 = select(float3(0.0, 0.0, _13446.z), float3(_13446.xy, 0.0), bool3(!_13391));
                                        break;
                                    }
                                    _13465 = select(float3(_13446.x, 0.0, _13446.z), float3(0.0, _13446.yz), bool3(!_13391));
                                    break;
                                } while(false);
                                if (_395.g_anaMode == 2)
                                {
                                    float3 _11036 = mix(_13465, float3(_13464), float3(0.5));
                                    _13466 = fast::clamp(_11036 * (_13464 / fast::max(dot(_11036, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)), 0.001000000047497451305389404296875)), float3(0.0), float3(1.0));
                                    break;
                                }
                                if ((_395.g_anaMode == 3) || _3894)
                                {
                                    _13466 = float3(_13464);
                                    break;
                                }
                                _13466 = _13465;
                                break;
                            } while(false);
                            _13619 = float4(_13466, 1.0);
                            break;
                        }
                        else
                        {
                            if (_395.g_format == 6)
                            {
                                float4 _13438;
                                do
                                {
                                    if (_395.g_srcDecode < 0.5)
                                    {
                                        _13438 = srcTex.sample(samp, _3574, level(0.0));
                                        break;
                                    }
                                    uint2 _11290 = uint2(srcTex.get_width(), srcTex.get_height());
                                    uint _11292 = _11290.x;
                                    uint _11294 = _11290.y;
                                    float2 _11303 = (_3574 * float2(float(_11292), float(_11294))) - float2(0.5);
                                    int2 _11310 = int2(int(_11292), int(_11294)) - int2(1);
                                    float2 _11312 = rint(_11303);
                                    if (all(abs(_11303 - _11312) < float2(0.001953125)))
                                    {
                                        float4 _11394 = srcTex.read(uint2(int3(clamp(int2(_11312), int2(0), _11310), 0).xy), 0);
                                        float4 _36123;
                                        if (_395.g_srcDecode > 0.5)
                                        {
                                            float3 _11403 = fast::clamp(_11394.xyz, float3(0.0), float3(1.0));
                                            float3 _11426 = select(powr((_11403 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11403 * float3(0.077399380505084991455078125), _11403 <= float3(0.040449999272823333740234375));
                                            float4 _33308 = _11394;
                                            _33308.x = _11426.x;
                                            _33308.y = _11426.y;
                                            _33308.z = _11426.z;
                                            _36123 = _33308;
                                        }
                                        else
                                        {
                                            _36123 = _11394;
                                        }
                                        _13438 = _36123;
                                        break;
                                    }
                                    float2 _11330 = fract(_11303);
                                    int2 _11333 = int2(floor(_11303));
                                    int2 _11335 = clamp(_11333, int2(0), _11310);
                                    int2 _11342 = clamp(_11333 + int2(1), int2(0), _11310);
                                    int _11344 = _11335.x;
                                    float4 _11436 = srcTex.read(uint2(int3(_11344, _11335.y, 0).xy), 0);
                                    bool _11439 = _395.g_srcDecode > 0.5;
                                    float4 _36119;
                                    if (_11439)
                                    {
                                        float3 _11445 = fast::clamp(_11436.xyz, float3(0.0), float3(1.0));
                                        float3 _11468 = select(powr((_11445 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11445 * float3(0.077399380505084991455078125), _11445 <= float3(0.040449999272823333740234375));
                                        float4 _33317 = _11436;
                                        _33317.x = _11468.x;
                                        _33317.y = _11468.y;
                                        _33317.z = _11468.z;
                                        _36119 = _33317;
                                    }
                                    else
                                    {
                                        _36119 = _11436;
                                    }
                                    int _11350 = _11342.x;
                                    float4 _11478 = srcTex.read(uint2(int3(_11350, _11335.y, 0).xy), 0);
                                    float4 _36120;
                                    if (_11439)
                                    {
                                        float3 _11487 = fast::clamp(_11478.xyz, float3(0.0), float3(1.0));
                                        float3 _11510 = select(powr((_11487 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11487 * float3(0.077399380505084991455078125), _11487 <= float3(0.040449999272823333740234375));
                                        float4 _33326 = _11478;
                                        _33326.x = _11510.x;
                                        _33326.y = _11510.y;
                                        _33326.z = _11510.z;
                                        _36120 = _33326;
                                    }
                                    else
                                    {
                                        _36120 = _11478;
                                    }
                                    float4 _11520 = srcTex.read(uint2(int3(_11344, _11342.y, 0).xy), 0);
                                    float4 _36121;
                                    if (_11439)
                                    {
                                        float3 _11529 = fast::clamp(_11520.xyz, float3(0.0), float3(1.0));
                                        float3 _11552 = select(powr((_11529 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11529 * float3(0.077399380505084991455078125), _11529 <= float3(0.040449999272823333740234375));
                                        float4 _33335 = _11520;
                                        _33335.x = _11552.x;
                                        _33335.y = _11552.y;
                                        _33335.z = _11552.z;
                                        _36121 = _33335;
                                    }
                                    else
                                    {
                                        _36121 = _11520;
                                    }
                                    float4 _11562 = srcTex.read(uint2(int3(_11350, _11342.y, 0).xy), 0);
                                    float4 _36122;
                                    if (_11439)
                                    {
                                        float3 _11571 = fast::clamp(_11562.xyz, float3(0.0), float3(1.0));
                                        float3 _11594 = select(powr((_11571 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11571 * float3(0.077399380505084991455078125), _11571 <= float3(0.040449999272823333740234375));
                                        float4 _33344 = _11562;
                                        _33344.x = _11594.x;
                                        _33344.y = _11594.y;
                                        _33344.z = _11594.z;
                                        _36122 = _33344;
                                    }
                                    else
                                    {
                                        _36122 = _11562;
                                    }
                                    float4 _11371 = float4(_11330.x);
                                    _13438 = mix(mix(_36119, _36120, _11371), mix(_36121, _36122, _11371), float4(_11330.y));
                                    break;
                                } while(false);
                                if (int(_13391) != _395.g_pulfEye)
                                {
                                    _13619 = float4(_13438.xyz, 1.0);
                                    break;
                                }
                                if (_395.g_pulfMode == 1)
                                {
                                    _13619 = float4(_13438.xyz * _395.g_ndTrans, 1.0);
                                    break;
                                }
                                _13619 = float4(srcPrev.sample(samp, _3574).xyz, 1.0);
                                break;
                            }
                            else
                            {
                                if (_395.g_format == 7)
                                {
                                    float _4537 = floor((_395.g_fpEyeFrac * _395.g_srcH) + 0.5);
                                    float _4549 = fast::max(1.0, (_395.g_srcH - _4537) - floor((_395.g_fpGapFrac * _395.g_srcH) + 0.5));
                                    float _4556 = _395.g_srcH - _4549;
                                    float _4561 = in.i_uv.y * (fast::max(1.0, fast::min(_4537, _4549)) - 1.0);
                                    float2 _4582 = float2(_3592, ((_13391 ? fast::clamp((_4556 + _395.g_fpEyeAlign) + _4561, _4556, _395.g_srcH - 1.0) : _4561) + 0.5) / _395.g_srcH);
                                    float4 _13437;
                                    do
                                    {
                                        if (_395.g_srcDecode < 0.5)
                                        {
                                            _13437 = srcTex.sample(samp, _4582, level(0.0));
                                            break;
                                        }
                                        uint2 _11638 = uint2(srcTex.get_width(), srcTex.get_height());
                                        uint _11640 = _11638.x;
                                        uint _11642 = _11638.y;
                                        float2 _11651 = (_4582 * float2(float(_11640), float(_11642))) - float2(0.5);
                                        int2 _11658 = int2(int(_11640), int(_11642)) - int2(1);
                                        float2 _11660 = rint(_11651);
                                        if (all(abs(_11651 - _11660) < float2(0.001953125)))
                                        {
                                            float4 _11742 = srcTex.read(uint2(int3(clamp(int2(_11660), int2(0), _11658), 0).xy), 0);
                                            float4 _36118;
                                            if (_395.g_srcDecode > 0.5)
                                            {
                                                float3 _11751 = fast::clamp(_11742.xyz, float3(0.0), float3(1.0));
                                                float3 _11774 = select(powr((_11751 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11751 * float3(0.077399380505084991455078125), _11751 <= float3(0.040449999272823333740234375));
                                                float4 _33260 = _11742;
                                                _33260.x = _11774.x;
                                                _33260.y = _11774.y;
                                                _33260.z = _11774.z;
                                                _36118 = _33260;
                                            }
                                            else
                                            {
                                                _36118 = _11742;
                                            }
                                            _13437 = _36118;
                                            break;
                                        }
                                        float2 _11678 = fract(_11651);
                                        int2 _11681 = int2(floor(_11651));
                                        int2 _11683 = clamp(_11681, int2(0), _11658);
                                        int2 _11690 = clamp(_11681 + int2(1), int2(0), _11658);
                                        int _11692 = _11683.x;
                                        float4 _11784 = srcTex.read(uint2(int3(_11692, _11683.y, 0).xy), 0);
                                        bool _11787 = _395.g_srcDecode > 0.5;
                                        float4 _36114;
                                        if (_11787)
                                        {
                                            float3 _11793 = fast::clamp(_11784.xyz, float3(0.0), float3(1.0));
                                            float3 _11816 = select(powr((_11793 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11793 * float3(0.077399380505084991455078125), _11793 <= float3(0.040449999272823333740234375));
                                            float4 _33269 = _11784;
                                            _33269.x = _11816.x;
                                            _33269.y = _11816.y;
                                            _33269.z = _11816.z;
                                            _36114 = _33269;
                                        }
                                        else
                                        {
                                            _36114 = _11784;
                                        }
                                        int _11698 = _11690.x;
                                        float4 _11826 = srcTex.read(uint2(int3(_11698, _11683.y, 0).xy), 0);
                                        float4 _36115;
                                        if (_11787)
                                        {
                                            float3 _11835 = fast::clamp(_11826.xyz, float3(0.0), float3(1.0));
                                            float3 _11858 = select(powr((_11835 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11835 * float3(0.077399380505084991455078125), _11835 <= float3(0.040449999272823333740234375));
                                            float4 _33278 = _11826;
                                            _33278.x = _11858.x;
                                            _33278.y = _11858.y;
                                            _33278.z = _11858.z;
                                            _36115 = _33278;
                                        }
                                        else
                                        {
                                            _36115 = _11826;
                                        }
                                        float4 _11868 = srcTex.read(uint2(int3(_11692, _11690.y, 0).xy), 0);
                                        float4 _36116;
                                        if (_11787)
                                        {
                                            float3 _11877 = fast::clamp(_11868.xyz, float3(0.0), float3(1.0));
                                            float3 _11900 = select(powr((_11877 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11877 * float3(0.077399380505084991455078125), _11877 <= float3(0.040449999272823333740234375));
                                            float4 _33287 = _11868;
                                            _33287.x = _11900.x;
                                            _33287.y = _11900.y;
                                            _33287.z = _11900.z;
                                            _36116 = _33287;
                                        }
                                        else
                                        {
                                            _36116 = _11868;
                                        }
                                        float4 _11910 = srcTex.read(uint2(int3(_11698, _11690.y, 0).xy), 0);
                                        float4 _36117;
                                        if (_11787)
                                        {
                                            float3 _11919 = fast::clamp(_11910.xyz, float3(0.0), float3(1.0));
                                            float3 _11942 = select(powr((_11919 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _11919 * float3(0.077399380505084991455078125), _11919 <= float3(0.040449999272823333740234375));
                                            float4 _33296 = _11910;
                                            _33296.x = _11942.x;
                                            _33296.y = _11942.y;
                                            _33296.z = _11942.z;
                                            _36117 = _33296;
                                        }
                                        else
                                        {
                                            _36117 = _11910;
                                        }
                                        float4 _11719 = float4(_11678.x);
                                        _13437 = mix(mix(_36114, _36115, _11719), mix(_36116, _36117, _11719), float4(_11678.y));
                                        break;
                                    } while(false);
                                    _13619 = _13437;
                                    break;
                                }
                                else
                                {
                                    if (_395.g_format == 8)
                                    {
                                        if (_13391)
                                        {
                                            float4 _13436;
                                            do
                                            {
                                                if (_395.g_srcDecode < 0.5)
                                                {
                                                    _13436 = srcTex.sample(samp, _3574, level(0.0));
                                                    break;
                                                }
                                                uint2 _11986 = uint2(srcTex.get_width(), srcTex.get_height());
                                                uint _11988 = _11986.x;
                                                uint _11990 = _11986.y;
                                                float2 _11999 = (_3574 * float2(float(_11988), float(_11990))) - float2(0.5);
                                                int2 _12006 = int2(int(_11988), int(_11990)) - int2(1);
                                                float2 _12008 = rint(_11999);
                                                if (all(abs(_11999 - _12008) < float2(0.001953125)))
                                                {
                                                    float4 _12090 = srcTex.read(uint2(int3(clamp(int2(_12008), int2(0), _12006), 0).xy), 0);
                                                    float4 _36113;
                                                    if (_395.g_srcDecode > 0.5)
                                                    {
                                                        float3 _12099 = fast::clamp(_12090.xyz, float3(0.0), float3(1.0));
                                                        float3 _12122 = select(powr((_12099 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _12099 * float3(0.077399380505084991455078125), _12099 <= float3(0.040449999272823333740234375));
                                                        float4 _33210 = _12090;
                                                        _33210.x = _12122.x;
                                                        _33210.y = _12122.y;
                                                        _33210.z = _12122.z;
                                                        _36113 = _33210;
                                                    }
                                                    else
                                                    {
                                                        _36113 = _12090;
                                                    }
                                                    _13436 = _36113;
                                                    break;
                                                }
                                                float2 _12026 = fract(_11999);
                                                int2 _12029 = int2(floor(_11999));
                                                int2 _12031 = clamp(_12029, int2(0), _12006);
                                                int2 _12038 = clamp(_12029 + int2(1), int2(0), _12006);
                                                int _12040 = _12031.x;
                                                float4 _12132 = srcTex.read(uint2(int3(_12040, _12031.y, 0).xy), 0);
                                                bool _12135 = _395.g_srcDecode > 0.5;
                                                float4 _36109;
                                                if (_12135)
                                                {
                                                    float3 _12141 = fast::clamp(_12132.xyz, float3(0.0), float3(1.0));
                                                    float3 _12164 = select(powr((_12141 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _12141 * float3(0.077399380505084991455078125), _12141 <= float3(0.040449999272823333740234375));
                                                    float4 _33219 = _12132;
                                                    _33219.x = _12164.x;
                                                    _33219.y = _12164.y;
                                                    _33219.z = _12164.z;
                                                    _36109 = _33219;
                                                }
                                                else
                                                {
                                                    _36109 = _12132;
                                                }
                                                int _12046 = _12038.x;
                                                float4 _12174 = srcTex.read(uint2(int3(_12046, _12031.y, 0).xy), 0);
                                                float4 _36110;
                                                if (_12135)
                                                {
                                                    float3 _12183 = fast::clamp(_12174.xyz, float3(0.0), float3(1.0));
                                                    float3 _12206 = select(powr((_12183 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _12183 * float3(0.077399380505084991455078125), _12183 <= float3(0.040449999272823333740234375));
                                                    float4 _33228 = _12174;
                                                    _33228.x = _12206.x;
                                                    _33228.y = _12206.y;
                                                    _33228.z = _12206.z;
                                                    _36110 = _33228;
                                                }
                                                else
                                                {
                                                    _36110 = _12174;
                                                }
                                                float4 _12216 = srcTex.read(uint2(int3(_12040, _12038.y, 0).xy), 0);
                                                float4 _36111;
                                                if (_12135)
                                                {
                                                    float3 _12225 = fast::clamp(_12216.xyz, float3(0.0), float3(1.0));
                                                    float3 _12248 = select(powr((_12225 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _12225 * float3(0.077399380505084991455078125), _12225 <= float3(0.040449999272823333740234375));
                                                    float4 _33237 = _12216;
                                                    _33237.x = _12248.x;
                                                    _33237.y = _12248.y;
                                                    _33237.z = _12248.z;
                                                    _36111 = _33237;
                                                }
                                                else
                                                {
                                                    _36111 = _12216;
                                                }
                                                float4 _12258 = srcTex.read(uint2(int3(_12046, _12038.y, 0).xy), 0);
                                                float4 _36112;
                                                if (_12135)
                                                {
                                                    float3 _12267 = fast::clamp(_12258.xyz, float3(0.0), float3(1.0));
                                                    float3 _12290 = select(powr((_12267 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _12267 * float3(0.077399380505084991455078125), _12267 <= float3(0.040449999272823333740234375));
                                                    float4 _33246 = _12258;
                                                    _33246.x = _12290.x;
                                                    _33246.y = _12290.y;
                                                    _33246.z = _12290.z;
                                                    _36112 = _33246;
                                                }
                                                else
                                                {
                                                    _36112 = _12258;
                                                }
                                                float4 _12067 = float4(_12026.x);
                                                _13436 = mix(mix(_36109, _36110, _12067), mix(_36111, _36112, _12067), float4(_12026.y));
                                                break;
                                            } while(false);
                                            _13619 = float4(_13436.xyz, 1.0);
                                            break;
                                        }
                                        _13619 = float4(srcPrev.sample(samp, _3574).xyz, 1.0);
                                        break;
                                    }
                                    else
                                    {
                                        if (_395.g_format == 9)
                                        {
                                            int _4627 = max(1, (_395.g_quiltCols * _395.g_quiltRows)) - 1;
                                            int _4628 = clamp(_13391 ? _395.g_quiltRightIdx : _395.g_quiltLeftIdx, 0, _4627);
                                            int _4633 = min((_4628 + 1), _4627);
                                            float _4640 = fast::clamp(_13391 ? _395.g_quiltRBlend : _395.g_quiltLBlend, 0.0, 1.0);
                                            float _4662 = _395.g_srcW / float(_395.g_quiltCols);
                                            float _4668 = _395.g_srcH / float(_395.g_quiltRows);
                                            float _4670 = _4662 / fast::max(1.0, _4668);
                                            float _4680 = (_395.g_paneH > 0.0) ? (_395.g_paneW / _395.g_paneH) : _4670;
                                            float2 _35957;
                                            if (_4670 < _4680)
                                            {
                                                float _4688 = _4670 / _4680;
                                                float _4691 = (1.0 - _4688) * 0.5;
                                                if ((_3592 < _4691) || (_3592 > (1.0 - _4691)))
                                                {
                                                    _13619 = float4(0.0, 0.0, 0.0, 1.0);
                                                    break;
                                                }
                                                float2 _32473 = _3574;
                                                _32473.x = (_3592 - _4691) / _4688;
                                                _35957 = _32473;
                                            }
                                            else
                                            {
                                                float2 _35958;
                                                if (_4670 > _4680)
                                                {
                                                    float _4718 = _4680 / _4670;
                                                    float _4721 = (1.0 - _4718) * 0.5;
                                                    if ((in.i_uv.y < _4721) || (in.i_uv.y > (1.0 - _4721)))
                                                    {
                                                        _13619 = float4(0.0, 0.0, 0.0, 1.0);
                                                        break;
                                                    }
                                                    _35958 = float2(_3592, (in.i_uv.y - _4721) / _4718);
                                                }
                                                else
                                                {
                                                    _35958 = _3574;
                                                }
                                                _35957 = _35958;
                                            }
                                            float _12392;
                                            bool _12394;
                                            int _4750 = max(1, int(_4662));
                                            int _4758 = max(1, int(_4668));
                                            int _4764 = _395.g_quiltRows - 1;
                                            int2 _4769 = int2(spvSMod(_4628, _395.g_quiltCols) * _4750, (_4764 - (_4628 / _395.g_quiltCols)) * _4758);
                                            int2 _4772 = int2(_4750, _4758);
                                            float2 _12312 = (_35957 * float2(_4772)) - float2(0.5);
                                            int2 _12315 = int2(floor(_12312));
                                            float2 _12319 = _12312 - float2(_12315);
                                            float _12328 = _12319.y;
                                            float _13420;
                                            do
                                            {
                                                _12392 = abs((-2.0) - _12328);
                                                _12394 = _12392 < 9.9999997473787516355514526367188e-06;
                                                if (_12394)
                                                {
                                                    _13420 = 1.0;
                                                    break;
                                                }
                                                if (_12392 >= 3.0)
                                                {
                                                    _13420 = 0.0;
                                                    break;
                                                }
                                                _13420 = (sin(3.1415927410125732421875 * _12392) * sin(_12392 * 1.0471975803375244140625)) / ((_12392 * _12392) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _12423;
                                            bool _12425;
                                            float _12339 = _12319.x;
                                            float _13424;
                                            do
                                            {
                                                _12423 = abs((-2.0) - _12339);
                                                _12425 = _12423 < 9.9999997473787516355514526367188e-06;
                                                if (_12425)
                                                {
                                                    _13424 = 1.0;
                                                    break;
                                                }
                                                if (_12423 >= 3.0)
                                                {
                                                    _13424 = 0.0;
                                                    break;
                                                }
                                                _13424 = (sin(3.1415927410125732421875 * _12423) * sin(_12423 * 1.0471975803375244140625)) / ((_12423 * _12423) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _12344 = _13424 * _13420;
                                            int _12346 = _12315.x;
                                            int _12348 = _12346 + (-2);
                                            int _12350 = _12315.y;
                                            int _12352 = _12350 + (-2);
                                            int2 _12355 = _4772 - int2(1);
                                            int2 _12356 = clamp(int2(_12348, _12352), int2(0), _12355);
                                            float4 _12456 = srcTex.read(uint2(int3(_4769 + _12356, 0).xy), 0);
                                            bool _12459 = _395.g_srcDecode > 0.5;
                                            float4 _35959;
                                            if (_12459)
                                            {
                                                float3 _12465 = fast::clamp(_12456.xyz, float3(0.0), float3(1.0));
                                                float3 _12488 = select(powr((_12465 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _12465 * float3(0.077399380505084991455078125), _12465 <= float3(0.040449999272823333740234375));
                                                float4 _32480 = _12456;
                                                _32480.x = _12488.x;
                                                _32480.y = _12488.y;
                                                _32480.z = _12488.z;
                                                _35959 = _32480;
                                            }
                                            else
                                            {
                                                _35959 = _12456;
                                            }
                                            float _27323;
                                            bool _27324;
                                            float _27339;
                                            do
                                            {
                                                _27323 = abs((-1.0) - _12339);
                                                _27324 = _27323 < 9.9999997473787516355514526367188e-06;
                                                if (_27324)
                                                {
                                                    _27339 = 1.0;
                                                    break;
                                                }
                                                if (_27323 >= 3.0)
                                                {
                                                    _27339 = 0.0;
                                                    break;
                                                }
                                                _27339 = (sin(3.1415927410125732421875 * _27323) * sin(_27323 * 1.0471975803375244140625)) / ((_27323 * _27323) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _27340 = _27339 * _13420;
                                            int _27343 = _12346 + (-1);
                                            int2 _27349 = clamp(int2(_27343, _12352), int2(0), _12355);
                                            float4 _27358 = srcTex.read(uint2(int3(_4769 + _27349, 0).xy), 0);
                                            float4 _35960;
                                            if (_12459)
                                            {
                                                float3 _27367 = fast::clamp(_27358.xyz, float3(0.0), float3(1.0));
                                                float3 _27376 = select(powr((_27367 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _27367 * float3(0.077399380505084991455078125), _27367 <= float3(0.040449999272823333740234375));
                                                float4 _32490 = _27358;
                                                _32490.x = _27376.x;
                                                _32490.y = _27376.y;
                                                _32490.z = _27376.z;
                                                _35960 = _32490;
                                            }
                                            else
                                            {
                                                _35960 = _27358;
                                            }
                                            float _27403;
                                            bool _27404;
                                            float _27419;
                                            do
                                            {
                                                _27403 = abs(-_12339);
                                                _27404 = _27403 < 9.9999997473787516355514526367188e-06;
                                                if (_27404)
                                                {
                                                    _27419 = 1.0;
                                                    break;
                                                }
                                                if (_27403 >= 3.0)
                                                {
                                                    _27419 = 0.0;
                                                    break;
                                                }
                                                _27419 = (sin(3.1415927410125732421875 * _27403) * sin(_27403 * 1.0471975803375244140625)) / ((_27403 * _27403) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _27420 = _27419 * _13420;
                                            int2 _27429 = clamp(int2(_12346, _12352), int2(0), _12355);
                                            float4 _27438 = srcTex.read(uint2(int3(_4769 + _27429, 0).xy), 0);
                                            float4 _35961;
                                            if (_12459)
                                            {
                                                float3 _27447 = fast::clamp(_27438.xyz, float3(0.0), float3(1.0));
                                                float3 _27456 = select(powr((_27447 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _27447 * float3(0.077399380505084991455078125), _27447 <= float3(0.040449999272823333740234375));
                                                float4 _32500 = _27438;
                                                _32500.x = _27456.x;
                                                _32500.y = _27456.y;
                                                _32500.z = _27456.z;
                                                _35961 = _32500;
                                            }
                                            else
                                            {
                                                _35961 = _27438;
                                            }
                                            float _27483;
                                            bool _27484;
                                            float _27499;
                                            do
                                            {
                                                _27483 = abs(1.0 - _12339);
                                                _27484 = _27483 < 9.9999997473787516355514526367188e-06;
                                                if (_27484)
                                                {
                                                    _27499 = 1.0;
                                                    break;
                                                }
                                                if (_27483 >= 3.0)
                                                {
                                                    _27499 = 0.0;
                                                    break;
                                                }
                                                _27499 = (sin(3.1415927410125732421875 * _27483) * sin(_27483 * 1.0471975803375244140625)) / ((_27483 * _27483) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _27500 = _27499 * _13420;
                                            int _27503 = _12346 + 1;
                                            int2 _27509 = clamp(int2(_27503, _12352), int2(0), _12355);
                                            float4 _27518 = srcTex.read(uint2(int3(_4769 + _27509, 0).xy), 0);
                                            float4 _35962;
                                            if (_12459)
                                            {
                                                float3 _27527 = fast::clamp(_27518.xyz, float3(0.0), float3(1.0));
                                                float3 _27536 = select(powr((_27527 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _27527 * float3(0.077399380505084991455078125), _27527 <= float3(0.040449999272823333740234375));
                                                float4 _32510 = _27518;
                                                _32510.x = _27536.x;
                                                _32510.y = _27536.y;
                                                _32510.z = _27536.z;
                                                _35962 = _32510;
                                            }
                                            else
                                            {
                                                _35962 = _27518;
                                            }
                                            float _27563;
                                            bool _27564;
                                            float _27579;
                                            do
                                            {
                                                _27563 = abs(2.0 - _12339);
                                                _27564 = _27563 < 9.9999997473787516355514526367188e-06;
                                                if (_27564)
                                                {
                                                    _27579 = 1.0;
                                                    break;
                                                }
                                                if (_27563 >= 3.0)
                                                {
                                                    _27579 = 0.0;
                                                    break;
                                                }
                                                _27579 = (sin(3.1415927410125732421875 * _27563) * sin(_27563 * 1.0471975803375244140625)) / ((_27563 * _27563) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _27580 = _27579 * _13420;
                                            int _27583 = _12346 + 2;
                                            int2 _27589 = clamp(int2(_27583, _12352), int2(0), _12355);
                                            float4 _27598 = srcTex.read(uint2(int3(_4769 + _27589, 0).xy), 0);
                                            float4 _35963;
                                            if (_12459)
                                            {
                                                float3 _27607 = fast::clamp(_27598.xyz, float3(0.0), float3(1.0));
                                                float3 _27616 = select(powr((_27607 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _27607 * float3(0.077399380505084991455078125), _27607 <= float3(0.040449999272823333740234375));
                                                float4 _32520 = _27598;
                                                _32520.x = _27616.x;
                                                _32520.y = _27616.y;
                                                _32520.z = _27616.z;
                                                _35963 = _32520;
                                            }
                                            else
                                            {
                                                _35963 = _27598;
                                            }
                                            float _27643;
                                            bool _27644;
                                            float _27659;
                                            do
                                            {
                                                _27643 = abs(3.0 - _12339);
                                                _27644 = _27643 < 9.9999997473787516355514526367188e-06;
                                                if (_27644)
                                                {
                                                    _27659 = 1.0;
                                                    break;
                                                }
                                                if (_27643 >= 3.0)
                                                {
                                                    _27659 = 0.0;
                                                    break;
                                                }
                                                _27659 = (sin(3.1415927410125732421875 * _27643) * sin(_27643 * 1.0471975803375244140625)) / ((_27643 * _27643) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _27660 = _27659 * _13420;
                                            int _27663 = _12346 + 3;
                                            int2 _27669 = clamp(int2(_27663, _12352), int2(0), _12355);
                                            float4 _27678 = srcTex.read(uint2(int3(_4769 + _27669, 0).xy), 0);
                                            float4 _35964;
                                            if (_12459)
                                            {
                                                float3 _27687 = fast::clamp(_27678.xyz, float3(0.0), float3(1.0));
                                                float3 _27696 = select(powr((_27687 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _27687 * float3(0.077399380505084991455078125), _27687 <= float3(0.040449999272823333740234375));
                                                float4 _32530 = _27678;
                                                _32530.x = _27696.x;
                                                _32530.y = _27696.y;
                                                _32530.z = _27696.z;
                                                _35964 = _32530;
                                            }
                                            else
                                            {
                                                _35964 = _27678;
                                            }
                                            float _27723;
                                            bool _27724;
                                            float _27739;
                                            do
                                            {
                                                _27723 = abs((-1.0) - _12328);
                                                _27724 = _27723 < 9.9999997473787516355514526367188e-06;
                                                if (_27724)
                                                {
                                                    _27739 = 1.0;
                                                    break;
                                                }
                                                if (_27723 >= 3.0)
                                                {
                                                    _27739 = 0.0;
                                                    break;
                                                }
                                                _27739 = (sin(3.1415927410125732421875 * _27723) * sin(_27723 * 1.0471975803375244140625)) / ((_27723 * _27723) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _27765;
                                            do
                                            {
                                                if (_12425)
                                                {
                                                    _27765 = 1.0;
                                                    break;
                                                }
                                                if (_12423 >= 3.0)
                                                {
                                                    _27765 = 0.0;
                                                    break;
                                                }
                                                _27765 = (sin(3.1415927410125732421875 * _12423) * sin(_12423 * 1.0471975803375244140625)) / ((_12423 * _12423) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _27766 = _27765 * _27739;
                                            int _27772 = _12350 + (-1);
                                            int2 _27775 = clamp(int2(_12348, _27772), int2(0), _12355);
                                            float4 _27784 = srcTex.read(uint2(int3(_4769 + _27775, 0).xy), 0);
                                            float4 _35965;
                                            if (_12459)
                                            {
                                                float3 _27793 = fast::clamp(_27784.xyz, float3(0.0), float3(1.0));
                                                float3 _27802 = select(powr((_27793 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _27793 * float3(0.077399380505084991455078125), _27793 <= float3(0.040449999272823333740234375));
                                                float4 _32541 = _27784;
                                                _32541.x = _27802.x;
                                                _32541.y = _27802.y;
                                                _32541.z = _27802.z;
                                                _35965 = _32541;
                                            }
                                            else
                                            {
                                                _35965 = _27784;
                                            }
                                            float _27842;
                                            do
                                            {
                                                if (_27324)
                                                {
                                                    _27842 = 1.0;
                                                    break;
                                                }
                                                if (_27323 >= 3.0)
                                                {
                                                    _27842 = 0.0;
                                                    break;
                                                }
                                                _27842 = (sin(3.1415927410125732421875 * _27323) * sin(_27323 * 1.0471975803375244140625)) / ((_27323 * _27323) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _27843 = _27842 * _27739;
                                            int2 _27852 = clamp(int2(_27343, _27772), int2(0), _12355);
                                            float4 _27861 = srcTex.read(uint2(int3(_4769 + _27852, 0).xy), 0);
                                            float4 _35966;
                                            if (_12459)
                                            {
                                                float3 _27870 = fast::clamp(_27861.xyz, float3(0.0), float3(1.0));
                                                float3 _27879 = select(powr((_27870 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _27870 * float3(0.077399380505084991455078125), _27870 <= float3(0.040449999272823333740234375));
                                                float4 _32551 = _27861;
                                                _32551.x = _27879.x;
                                                _32551.y = _27879.y;
                                                _32551.z = _27879.z;
                                                _35966 = _32551;
                                            }
                                            else
                                            {
                                                _35966 = _27861;
                                            }
                                            float _27919;
                                            do
                                            {
                                                if (_27404)
                                                {
                                                    _27919 = 1.0;
                                                    break;
                                                }
                                                if (_27403 >= 3.0)
                                                {
                                                    _27919 = 0.0;
                                                    break;
                                                }
                                                _27919 = (sin(3.1415927410125732421875 * _27403) * sin(_27403 * 1.0471975803375244140625)) / ((_27403 * _27403) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _27920 = _27919 * _27739;
                                            int2 _27929 = clamp(int2(_12346, _27772), int2(0), _12355);
                                            float4 _27938 = srcTex.read(uint2(int3(_4769 + _27929, 0).xy), 0);
                                            float4 _35967;
                                            if (_12459)
                                            {
                                                float3 _27947 = fast::clamp(_27938.xyz, float3(0.0), float3(1.0));
                                                float3 _27956 = select(powr((_27947 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _27947 * float3(0.077399380505084991455078125), _27947 <= float3(0.040449999272823333740234375));
                                                float4 _32561 = _27938;
                                                _32561.x = _27956.x;
                                                _32561.y = _27956.y;
                                                _32561.z = _27956.z;
                                                _35967 = _32561;
                                            }
                                            else
                                            {
                                                _35967 = _27938;
                                            }
                                            float _27996;
                                            do
                                            {
                                                if (_27484)
                                                {
                                                    _27996 = 1.0;
                                                    break;
                                                }
                                                if (_27483 >= 3.0)
                                                {
                                                    _27996 = 0.0;
                                                    break;
                                                }
                                                _27996 = (sin(3.1415927410125732421875 * _27483) * sin(_27483 * 1.0471975803375244140625)) / ((_27483 * _27483) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _27997 = _27996 * _27739;
                                            int2 _28006 = clamp(int2(_27503, _27772), int2(0), _12355);
                                            float4 _28015 = srcTex.read(uint2(int3(_4769 + _28006, 0).xy), 0);
                                            float4 _35968;
                                            if (_12459)
                                            {
                                                float3 _28024 = fast::clamp(_28015.xyz, float3(0.0), float3(1.0));
                                                float3 _28033 = select(powr((_28024 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _28024 * float3(0.077399380505084991455078125), _28024 <= float3(0.040449999272823333740234375));
                                                float4 _32571 = _28015;
                                                _32571.x = _28033.x;
                                                _32571.y = _28033.y;
                                                _32571.z = _28033.z;
                                                _35968 = _32571;
                                            }
                                            else
                                            {
                                                _35968 = _28015;
                                            }
                                            float _28073;
                                            do
                                            {
                                                if (_27564)
                                                {
                                                    _28073 = 1.0;
                                                    break;
                                                }
                                                if (_27563 >= 3.0)
                                                {
                                                    _28073 = 0.0;
                                                    break;
                                                }
                                                _28073 = (sin(3.1415927410125732421875 * _27563) * sin(_27563 * 1.0471975803375244140625)) / ((_27563 * _27563) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28074 = _28073 * _27739;
                                            int2 _28083 = clamp(int2(_27583, _27772), int2(0), _12355);
                                            float4 _28092 = srcTex.read(uint2(int3(_4769 + _28083, 0).xy), 0);
                                            float4 _35969;
                                            if (_12459)
                                            {
                                                float3 _28101 = fast::clamp(_28092.xyz, float3(0.0), float3(1.0));
                                                float3 _28110 = select(powr((_28101 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _28101 * float3(0.077399380505084991455078125), _28101 <= float3(0.040449999272823333740234375));
                                                float4 _32581 = _28092;
                                                _32581.x = _28110.x;
                                                _32581.y = _28110.y;
                                                _32581.z = _28110.z;
                                                _35969 = _32581;
                                            }
                                            else
                                            {
                                                _35969 = _28092;
                                            }
                                            float _28150;
                                            do
                                            {
                                                if (_27644)
                                                {
                                                    _28150 = 1.0;
                                                    break;
                                                }
                                                if (_27643 >= 3.0)
                                                {
                                                    _28150 = 0.0;
                                                    break;
                                                }
                                                _28150 = (sin(3.1415927410125732421875 * _27643) * sin(_27643 * 1.0471975803375244140625)) / ((_27643 * _27643) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28151 = _28150 * _27739;
                                            int2 _28160 = clamp(int2(_27663, _27772), int2(0), _12355);
                                            float4 _28169 = srcTex.read(uint2(int3(_4769 + _28160, 0).xy), 0);
                                            float4 _35970;
                                            if (_12459)
                                            {
                                                float3 _28178 = fast::clamp(_28169.xyz, float3(0.0), float3(1.0));
                                                float3 _28187 = select(powr((_28178 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _28178 * float3(0.077399380505084991455078125), _28178 <= float3(0.040449999272823333740234375));
                                                float4 _32591 = _28169;
                                                _32591.x = _28187.x;
                                                _32591.y = _28187.y;
                                                _32591.z = _28187.z;
                                                _35970 = _32591;
                                            }
                                            else
                                            {
                                                _35970 = _28169;
                                            }
                                            float _28217;
                                            bool _28218;
                                            float _28233;
                                            do
                                            {
                                                _28217 = abs(-_12328);
                                                _28218 = _28217 < 9.9999997473787516355514526367188e-06;
                                                if (_28218)
                                                {
                                                    _28233 = 1.0;
                                                    break;
                                                }
                                                if (_28217 >= 3.0)
                                                {
                                                    _28233 = 0.0;
                                                    break;
                                                }
                                                _28233 = (sin(3.1415927410125732421875 * _28217) * sin(_28217 * 1.0471975803375244140625)) / ((_28217 * _28217) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28259;
                                            do
                                            {
                                                if (_12425)
                                                {
                                                    _28259 = 1.0;
                                                    break;
                                                }
                                                if (_12423 >= 3.0)
                                                {
                                                    _28259 = 0.0;
                                                    break;
                                                }
                                                _28259 = (sin(3.1415927410125732421875 * _12423) * sin(_12423 * 1.0471975803375244140625)) / ((_12423 * _12423) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28260 = _28259 * _28233;
                                            int2 _28269 = clamp(int2(_12348, _12350), int2(0), _12355);
                                            float4 _28278 = srcTex.read(uint2(int3(_4769 + _28269, 0).xy), 0);
                                            float4 _35971;
                                            if (_12459)
                                            {
                                                float3 _28287 = fast::clamp(_28278.xyz, float3(0.0), float3(1.0));
                                                float3 _28296 = select(powr((_28287 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _28287 * float3(0.077399380505084991455078125), _28287 <= float3(0.040449999272823333740234375));
                                                float4 _32602 = _28278;
                                                _32602.x = _28296.x;
                                                _32602.y = _28296.y;
                                                _32602.z = _28296.z;
                                                _35971 = _32602;
                                            }
                                            else
                                            {
                                                _35971 = _28278;
                                            }
                                            float _28336;
                                            do
                                            {
                                                if (_27324)
                                                {
                                                    _28336 = 1.0;
                                                    break;
                                                }
                                                if (_27323 >= 3.0)
                                                {
                                                    _28336 = 0.0;
                                                    break;
                                                }
                                                _28336 = (sin(3.1415927410125732421875 * _27323) * sin(_27323 * 1.0471975803375244140625)) / ((_27323 * _27323) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28337 = _28336 * _28233;
                                            int2 _28346 = clamp(int2(_27343, _12350), int2(0), _12355);
                                            float4 _28355 = srcTex.read(uint2(int3(_4769 + _28346, 0).xy), 0);
                                            float4 _35972;
                                            if (_12459)
                                            {
                                                float3 _28364 = fast::clamp(_28355.xyz, float3(0.0), float3(1.0));
                                                float3 _28373 = select(powr((_28364 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _28364 * float3(0.077399380505084991455078125), _28364 <= float3(0.040449999272823333740234375));
                                                float4 _32612 = _28355;
                                                _32612.x = _28373.x;
                                                _32612.y = _28373.y;
                                                _32612.z = _28373.z;
                                                _35972 = _32612;
                                            }
                                            else
                                            {
                                                _35972 = _28355;
                                            }
                                            float _28413;
                                            do
                                            {
                                                if (_27404)
                                                {
                                                    _28413 = 1.0;
                                                    break;
                                                }
                                                if (_27403 >= 3.0)
                                                {
                                                    _28413 = 0.0;
                                                    break;
                                                }
                                                _28413 = (sin(3.1415927410125732421875 * _27403) * sin(_27403 * 1.0471975803375244140625)) / ((_27403 * _27403) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28414 = _28413 * _28233;
                                            int2 _28423 = clamp(_12315, int2(0), _12355);
                                            float4 _28432 = srcTex.read(uint2(int3(_4769 + _28423, 0).xy), 0);
                                            float4 _35973;
                                            if (_12459)
                                            {
                                                float3 _28441 = fast::clamp(_28432.xyz, float3(0.0), float3(1.0));
                                                float3 _28450 = select(powr((_28441 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _28441 * float3(0.077399380505084991455078125), _28441 <= float3(0.040449999272823333740234375));
                                                float4 _32622 = _28432;
                                                _32622.x = _28450.x;
                                                _32622.y = _28450.y;
                                                _32622.z = _28450.z;
                                                _35973 = _32622;
                                            }
                                            else
                                            {
                                                _35973 = _28432;
                                            }
                                            float _28490;
                                            do
                                            {
                                                if (_27484)
                                                {
                                                    _28490 = 1.0;
                                                    break;
                                                }
                                                if (_27483 >= 3.0)
                                                {
                                                    _28490 = 0.0;
                                                    break;
                                                }
                                                _28490 = (sin(3.1415927410125732421875 * _27483) * sin(_27483 * 1.0471975803375244140625)) / ((_27483 * _27483) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28491 = _28490 * _28233;
                                            int2 _28500 = clamp(int2(_27503, _12350), int2(0), _12355);
                                            float4 _28509 = srcTex.read(uint2(int3(_4769 + _28500, 0).xy), 0);
                                            float4 _35974;
                                            if (_12459)
                                            {
                                                float3 _28518 = fast::clamp(_28509.xyz, float3(0.0), float3(1.0));
                                                float3 _28527 = select(powr((_28518 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _28518 * float3(0.077399380505084991455078125), _28518 <= float3(0.040449999272823333740234375));
                                                float4 _32632 = _28509;
                                                _32632.x = _28527.x;
                                                _32632.y = _28527.y;
                                                _32632.z = _28527.z;
                                                _35974 = _32632;
                                            }
                                            else
                                            {
                                                _35974 = _28509;
                                            }
                                            float _28567;
                                            do
                                            {
                                                if (_27564)
                                                {
                                                    _28567 = 1.0;
                                                    break;
                                                }
                                                if (_27563 >= 3.0)
                                                {
                                                    _28567 = 0.0;
                                                    break;
                                                }
                                                _28567 = (sin(3.1415927410125732421875 * _27563) * sin(_27563 * 1.0471975803375244140625)) / ((_27563 * _27563) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28568 = _28567 * _28233;
                                            int2 _28577 = clamp(int2(_27583, _12350), int2(0), _12355);
                                            float4 _28586 = srcTex.read(uint2(int3(_4769 + _28577, 0).xy), 0);
                                            float4 _35975;
                                            if (_12459)
                                            {
                                                float3 _28595 = fast::clamp(_28586.xyz, float3(0.0), float3(1.0));
                                                float3 _28604 = select(powr((_28595 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _28595 * float3(0.077399380505084991455078125), _28595 <= float3(0.040449999272823333740234375));
                                                float4 _32642 = _28586;
                                                _32642.x = _28604.x;
                                                _32642.y = _28604.y;
                                                _32642.z = _28604.z;
                                                _35975 = _32642;
                                            }
                                            else
                                            {
                                                _35975 = _28586;
                                            }
                                            float _28644;
                                            do
                                            {
                                                if (_27644)
                                                {
                                                    _28644 = 1.0;
                                                    break;
                                                }
                                                if (_27643 >= 3.0)
                                                {
                                                    _28644 = 0.0;
                                                    break;
                                                }
                                                _28644 = (sin(3.1415927410125732421875 * _27643) * sin(_27643 * 1.0471975803375244140625)) / ((_27643 * _27643) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28645 = _28644 * _28233;
                                            int2 _28654 = clamp(int2(_27663, _12350), int2(0), _12355);
                                            float4 _28663 = srcTex.read(uint2(int3(_4769 + _28654, 0).xy), 0);
                                            float4 _35976;
                                            if (_12459)
                                            {
                                                float3 _28672 = fast::clamp(_28663.xyz, float3(0.0), float3(1.0));
                                                float3 _28681 = select(powr((_28672 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _28672 * float3(0.077399380505084991455078125), _28672 <= float3(0.040449999272823333740234375));
                                                float4 _32652 = _28663;
                                                _32652.x = _28681.x;
                                                _32652.y = _28681.y;
                                                _32652.z = _28681.z;
                                                _35976 = _32652;
                                            }
                                            else
                                            {
                                                _35976 = _28663;
                                            }
                                            float _28711;
                                            bool _28712;
                                            float3 _28692 = (((((((((((((((((_35959.xyz * _12344) + (_35960.xyz * _27340)) + (_35961.xyz * _27420)) + (_35962.xyz * _27500)) + (_35963.xyz * _27580)) + (_35964.xyz * _27660)) + (_35965.xyz * _27766)) + (_35966.xyz * _27843)) + (_35967.xyz * _27920)) + (_35968.xyz * _27997)) + (_35969.xyz * _28074)) + (_35970.xyz * _28151)) + (_35971.xyz * _28260)) + (_35972.xyz * _28337)) + (_35973.xyz * _28414)) + (_35974.xyz * _28491)) + (_35975.xyz * _28568)) + (_35976.xyz * _28645);
                                            float _28727;
                                            do
                                            {
                                                _28711 = abs(1.0 - _12328);
                                                _28712 = _28711 < 9.9999997473787516355514526367188e-06;
                                                if (_28712)
                                                {
                                                    _28727 = 1.0;
                                                    break;
                                                }
                                                if (_28711 >= 3.0)
                                                {
                                                    _28727 = 0.0;
                                                    break;
                                                }
                                                _28727 = (sin(3.1415927410125732421875 * _28711) * sin(_28711 * 1.0471975803375244140625)) / ((_28711 * _28711) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28753;
                                            do
                                            {
                                                if (_12425)
                                                {
                                                    _28753 = 1.0;
                                                    break;
                                                }
                                                if (_12423 >= 3.0)
                                                {
                                                    _28753 = 0.0;
                                                    break;
                                                }
                                                _28753 = (sin(3.1415927410125732421875 * _12423) * sin(_12423 * 1.0471975803375244140625)) / ((_12423 * _12423) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28754 = _28753 * _28727;
                                            int _28760 = _12350 + 1;
                                            int2 _28763 = clamp(int2(_12348, _28760), int2(0), _12355);
                                            float4 _28772 = srcTex.read(uint2(int3(_4769 + _28763, 0).xy), 0);
                                            float4 _35977;
                                            if (_12459)
                                            {
                                                float3 _28781 = fast::clamp(_28772.xyz, float3(0.0), float3(1.0));
                                                float3 _28790 = select(powr((_28781 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _28781 * float3(0.077399380505084991455078125), _28781 <= float3(0.040449999272823333740234375));
                                                float4 _32663 = _28772;
                                                _32663.x = _28790.x;
                                                _32663.y = _28790.y;
                                                _32663.z = _28790.z;
                                                _35977 = _32663;
                                            }
                                            else
                                            {
                                                _35977 = _28772;
                                            }
                                            float _28830;
                                            do
                                            {
                                                if (_27324)
                                                {
                                                    _28830 = 1.0;
                                                    break;
                                                }
                                                if (_27323 >= 3.0)
                                                {
                                                    _28830 = 0.0;
                                                    break;
                                                }
                                                _28830 = (sin(3.1415927410125732421875 * _27323) * sin(_27323 * 1.0471975803375244140625)) / ((_27323 * _27323) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28831 = _28830 * _28727;
                                            int2 _28840 = clamp(int2(_27343, _28760), int2(0), _12355);
                                            float4 _28849 = srcTex.read(uint2(int3(_4769 + _28840, 0).xy), 0);
                                            float4 _35978;
                                            if (_12459)
                                            {
                                                float3 _28858 = fast::clamp(_28849.xyz, float3(0.0), float3(1.0));
                                                float3 _28867 = select(powr((_28858 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _28858 * float3(0.077399380505084991455078125), _28858 <= float3(0.040449999272823333740234375));
                                                float4 _32673 = _28849;
                                                _32673.x = _28867.x;
                                                _32673.y = _28867.y;
                                                _32673.z = _28867.z;
                                                _35978 = _32673;
                                            }
                                            else
                                            {
                                                _35978 = _28849;
                                            }
                                            float _28907;
                                            do
                                            {
                                                if (_27404)
                                                {
                                                    _28907 = 1.0;
                                                    break;
                                                }
                                                if (_27403 >= 3.0)
                                                {
                                                    _28907 = 0.0;
                                                    break;
                                                }
                                                _28907 = (sin(3.1415927410125732421875 * _27403) * sin(_27403 * 1.0471975803375244140625)) / ((_27403 * _27403) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28908 = _28907 * _28727;
                                            int2 _28917 = clamp(int2(_12346, _28760), int2(0), _12355);
                                            float4 _28926 = srcTex.read(uint2(int3(_4769 + _28917, 0).xy), 0);
                                            float4 _35979;
                                            if (_12459)
                                            {
                                                float3 _28935 = fast::clamp(_28926.xyz, float3(0.0), float3(1.0));
                                                float3 _28944 = select(powr((_28935 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _28935 * float3(0.077399380505084991455078125), _28935 <= float3(0.040449999272823333740234375));
                                                float4 _32683 = _28926;
                                                _32683.x = _28944.x;
                                                _32683.y = _28944.y;
                                                _32683.z = _28944.z;
                                                _35979 = _32683;
                                            }
                                            else
                                            {
                                                _35979 = _28926;
                                            }
                                            float _28984;
                                            do
                                            {
                                                if (_27484)
                                                {
                                                    _28984 = 1.0;
                                                    break;
                                                }
                                                if (_27483 >= 3.0)
                                                {
                                                    _28984 = 0.0;
                                                    break;
                                                }
                                                _28984 = (sin(3.1415927410125732421875 * _27483) * sin(_27483 * 1.0471975803375244140625)) / ((_27483 * _27483) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _28985 = _28984 * _28727;
                                            int2 _28994 = clamp(int2(_27503, _28760), int2(0), _12355);
                                            float4 _29003 = srcTex.read(uint2(int3(_4769 + _28994, 0).xy), 0);
                                            float4 _35980;
                                            if (_12459)
                                            {
                                                float3 _29012 = fast::clamp(_29003.xyz, float3(0.0), float3(1.0));
                                                float3 _29021 = select(powr((_29012 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _29012 * float3(0.077399380505084991455078125), _29012 <= float3(0.040449999272823333740234375));
                                                float4 _32693 = _29003;
                                                _32693.x = _29021.x;
                                                _32693.y = _29021.y;
                                                _32693.z = _29021.z;
                                                _35980 = _32693;
                                            }
                                            else
                                            {
                                                _35980 = _29003;
                                            }
                                            float _29061;
                                            do
                                            {
                                                if (_27564)
                                                {
                                                    _29061 = 1.0;
                                                    break;
                                                }
                                                if (_27563 >= 3.0)
                                                {
                                                    _29061 = 0.0;
                                                    break;
                                                }
                                                _29061 = (sin(3.1415927410125732421875 * _27563) * sin(_27563 * 1.0471975803375244140625)) / ((_27563 * _27563) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29062 = _29061 * _28727;
                                            int2 _29071 = clamp(int2(_27583, _28760), int2(0), _12355);
                                            float4 _29080 = srcTex.read(uint2(int3(_4769 + _29071, 0).xy), 0);
                                            float4 _35981;
                                            if (_12459)
                                            {
                                                float3 _29089 = fast::clamp(_29080.xyz, float3(0.0), float3(1.0));
                                                float3 _29098 = select(powr((_29089 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _29089 * float3(0.077399380505084991455078125), _29089 <= float3(0.040449999272823333740234375));
                                                float4 _32703 = _29080;
                                                _32703.x = _29098.x;
                                                _32703.y = _29098.y;
                                                _32703.z = _29098.z;
                                                _35981 = _32703;
                                            }
                                            else
                                            {
                                                _35981 = _29080;
                                            }
                                            float _29138;
                                            do
                                            {
                                                if (_27644)
                                                {
                                                    _29138 = 1.0;
                                                    break;
                                                }
                                                if (_27643 >= 3.0)
                                                {
                                                    _29138 = 0.0;
                                                    break;
                                                }
                                                _29138 = (sin(3.1415927410125732421875 * _27643) * sin(_27643 * 1.0471975803375244140625)) / ((_27643 * _27643) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29139 = _29138 * _28727;
                                            int2 _29148 = clamp(int2(_27663, _28760), int2(0), _12355);
                                            float4 _29157 = srcTex.read(uint2(int3(_4769 + _29148, 0).xy), 0);
                                            float4 _35982;
                                            if (_12459)
                                            {
                                                float3 _29166 = fast::clamp(_29157.xyz, float3(0.0), float3(1.0));
                                                float3 _29175 = select(powr((_29166 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _29166 * float3(0.077399380505084991455078125), _29166 <= float3(0.040449999272823333740234375));
                                                float4 _32713 = _29157;
                                                _32713.x = _29175.x;
                                                _32713.y = _29175.y;
                                                _32713.z = _29175.z;
                                                _35982 = _32713;
                                            }
                                            else
                                            {
                                                _35982 = _29157;
                                            }
                                            float _29205;
                                            bool _29206;
                                            float _29221;
                                            do
                                            {
                                                _29205 = abs(2.0 - _12328);
                                                _29206 = _29205 < 9.9999997473787516355514526367188e-06;
                                                if (_29206)
                                                {
                                                    _29221 = 1.0;
                                                    break;
                                                }
                                                if (_29205 >= 3.0)
                                                {
                                                    _29221 = 0.0;
                                                    break;
                                                }
                                                _29221 = (sin(3.1415927410125732421875 * _29205) * sin(_29205 * 1.0471975803375244140625)) / ((_29205 * _29205) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29247;
                                            do
                                            {
                                                if (_12425)
                                                {
                                                    _29247 = 1.0;
                                                    break;
                                                }
                                                if (_12423 >= 3.0)
                                                {
                                                    _29247 = 0.0;
                                                    break;
                                                }
                                                _29247 = (sin(3.1415927410125732421875 * _12423) * sin(_12423 * 1.0471975803375244140625)) / ((_12423 * _12423) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29248 = _29247 * _29221;
                                            int _29254 = _12350 + 2;
                                            int2 _29257 = clamp(int2(_12348, _29254), int2(0), _12355);
                                            float4 _29266 = srcTex.read(uint2(int3(_4769 + _29257, 0).xy), 0);
                                            float4 _35983;
                                            if (_12459)
                                            {
                                                float3 _29275 = fast::clamp(_29266.xyz, float3(0.0), float3(1.0));
                                                float3 _29284 = select(powr((_29275 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _29275 * float3(0.077399380505084991455078125), _29275 <= float3(0.040449999272823333740234375));
                                                float4 _32724 = _29266;
                                                _32724.x = _29284.x;
                                                _32724.y = _29284.y;
                                                _32724.z = _29284.z;
                                                _35983 = _32724;
                                            }
                                            else
                                            {
                                                _35983 = _29266;
                                            }
                                            float _29324;
                                            do
                                            {
                                                if (_27324)
                                                {
                                                    _29324 = 1.0;
                                                    break;
                                                }
                                                if (_27323 >= 3.0)
                                                {
                                                    _29324 = 0.0;
                                                    break;
                                                }
                                                _29324 = (sin(3.1415927410125732421875 * _27323) * sin(_27323 * 1.0471975803375244140625)) / ((_27323 * _27323) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29325 = _29324 * _29221;
                                            int2 _29334 = clamp(int2(_27343, _29254), int2(0), _12355);
                                            float4 _29343 = srcTex.read(uint2(int3(_4769 + _29334, 0).xy), 0);
                                            float4 _35984;
                                            if (_12459)
                                            {
                                                float3 _29352 = fast::clamp(_29343.xyz, float3(0.0), float3(1.0));
                                                float3 _29361 = select(powr((_29352 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _29352 * float3(0.077399380505084991455078125), _29352 <= float3(0.040449999272823333740234375));
                                                float4 _32734 = _29343;
                                                _32734.x = _29361.x;
                                                _32734.y = _29361.y;
                                                _32734.z = _29361.z;
                                                _35984 = _32734;
                                            }
                                            else
                                            {
                                                _35984 = _29343;
                                            }
                                            float _29401;
                                            do
                                            {
                                                if (_27404)
                                                {
                                                    _29401 = 1.0;
                                                    break;
                                                }
                                                if (_27403 >= 3.0)
                                                {
                                                    _29401 = 0.0;
                                                    break;
                                                }
                                                _29401 = (sin(3.1415927410125732421875 * _27403) * sin(_27403 * 1.0471975803375244140625)) / ((_27403 * _27403) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29402 = _29401 * _29221;
                                            int2 _29411 = clamp(int2(_12346, _29254), int2(0), _12355);
                                            float4 _29420 = srcTex.read(uint2(int3(_4769 + _29411, 0).xy), 0);
                                            float4 _35985;
                                            if (_12459)
                                            {
                                                float3 _29429 = fast::clamp(_29420.xyz, float3(0.0), float3(1.0));
                                                float3 _29438 = select(powr((_29429 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _29429 * float3(0.077399380505084991455078125), _29429 <= float3(0.040449999272823333740234375));
                                                float4 _32744 = _29420;
                                                _32744.x = _29438.x;
                                                _32744.y = _29438.y;
                                                _32744.z = _29438.z;
                                                _35985 = _32744;
                                            }
                                            else
                                            {
                                                _35985 = _29420;
                                            }
                                            float _29478;
                                            do
                                            {
                                                if (_27484)
                                                {
                                                    _29478 = 1.0;
                                                    break;
                                                }
                                                if (_27483 >= 3.0)
                                                {
                                                    _29478 = 0.0;
                                                    break;
                                                }
                                                _29478 = (sin(3.1415927410125732421875 * _27483) * sin(_27483 * 1.0471975803375244140625)) / ((_27483 * _27483) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29479 = _29478 * _29221;
                                            int2 _29488 = clamp(int2(_27503, _29254), int2(0), _12355);
                                            float4 _29497 = srcTex.read(uint2(int3(_4769 + _29488, 0).xy), 0);
                                            float4 _35986;
                                            if (_12459)
                                            {
                                                float3 _29506 = fast::clamp(_29497.xyz, float3(0.0), float3(1.0));
                                                float3 _29515 = select(powr((_29506 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _29506 * float3(0.077399380505084991455078125), _29506 <= float3(0.040449999272823333740234375));
                                                float4 _32754 = _29497;
                                                _32754.x = _29515.x;
                                                _32754.y = _29515.y;
                                                _32754.z = _29515.z;
                                                _35986 = _32754;
                                            }
                                            else
                                            {
                                                _35986 = _29497;
                                            }
                                            float _29555;
                                            do
                                            {
                                                if (_27564)
                                                {
                                                    _29555 = 1.0;
                                                    break;
                                                }
                                                if (_27563 >= 3.0)
                                                {
                                                    _29555 = 0.0;
                                                    break;
                                                }
                                                _29555 = (sin(3.1415927410125732421875 * _27563) * sin(_27563 * 1.0471975803375244140625)) / ((_27563 * _27563) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29556 = _29555 * _29221;
                                            int2 _29565 = clamp(int2(_27583, _29254), int2(0), _12355);
                                            float4 _29574 = srcTex.read(uint2(int3(_4769 + _29565, 0).xy), 0);
                                            float4 _35987;
                                            if (_12459)
                                            {
                                                float3 _29583 = fast::clamp(_29574.xyz, float3(0.0), float3(1.0));
                                                float3 _29592 = select(powr((_29583 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _29583 * float3(0.077399380505084991455078125), _29583 <= float3(0.040449999272823333740234375));
                                                float4 _32764 = _29574;
                                                _32764.x = _29592.x;
                                                _32764.y = _29592.y;
                                                _32764.z = _29592.z;
                                                _35987 = _32764;
                                            }
                                            else
                                            {
                                                _35987 = _29574;
                                            }
                                            float _29632;
                                            do
                                            {
                                                if (_27644)
                                                {
                                                    _29632 = 1.0;
                                                    break;
                                                }
                                                if (_27643 >= 3.0)
                                                {
                                                    _29632 = 0.0;
                                                    break;
                                                }
                                                _29632 = (sin(3.1415927410125732421875 * _27643) * sin(_27643 * 1.0471975803375244140625)) / ((_27643 * _27643) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29633 = _29632 * _29221;
                                            int2 _29642 = clamp(int2(_27663, _29254), int2(0), _12355);
                                            float4 _29651 = srcTex.read(uint2(int3(_4769 + _29642, 0).xy), 0);
                                            float4 _35988;
                                            if (_12459)
                                            {
                                                float3 _29660 = fast::clamp(_29651.xyz, float3(0.0), float3(1.0));
                                                float3 _29669 = select(powr((_29660 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _29660 * float3(0.077399380505084991455078125), _29660 <= float3(0.040449999272823333740234375));
                                                float4 _32774 = _29651;
                                                _32774.x = _29669.x;
                                                _32774.y = _29669.y;
                                                _32774.z = _29669.z;
                                                _35988 = _32774;
                                            }
                                            else
                                            {
                                                _35988 = _29651;
                                            }
                                            float _29699;
                                            bool _29700;
                                            float _29715;
                                            do
                                            {
                                                _29699 = abs(3.0 - _12328);
                                                _29700 = _29699 < 9.9999997473787516355514526367188e-06;
                                                if (_29700)
                                                {
                                                    _29715 = 1.0;
                                                    break;
                                                }
                                                if (_29699 >= 3.0)
                                                {
                                                    _29715 = 0.0;
                                                    break;
                                                }
                                                _29715 = (sin(3.1415927410125732421875 * _29699) * sin(_29699 * 1.0471975803375244140625)) / ((_29699 * _29699) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29741;
                                            do
                                            {
                                                if (_12425)
                                                {
                                                    _29741 = 1.0;
                                                    break;
                                                }
                                                if (_12423 >= 3.0)
                                                {
                                                    _29741 = 0.0;
                                                    break;
                                                }
                                                _29741 = (sin(3.1415927410125732421875 * _12423) * sin(_12423 * 1.0471975803375244140625)) / ((_12423 * _12423) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29742 = _29741 * _29715;
                                            int _29748 = _12350 + 3;
                                            int2 _29751 = clamp(int2(_12348, _29748), int2(0), _12355);
                                            float4 _29760 = srcTex.read(uint2(int3(_4769 + _29751, 0).xy), 0);
                                            float4 _35989;
                                            if (_12459)
                                            {
                                                float3 _29769 = fast::clamp(_29760.xyz, float3(0.0), float3(1.0));
                                                float3 _29778 = select(powr((_29769 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _29769 * float3(0.077399380505084991455078125), _29769 <= float3(0.040449999272823333740234375));
                                                float4 _32785 = _29760;
                                                _32785.x = _29778.x;
                                                _32785.y = _29778.y;
                                                _32785.z = _29778.z;
                                                _35989 = _32785;
                                            }
                                            else
                                            {
                                                _35989 = _29760;
                                            }
                                            float _29818;
                                            do
                                            {
                                                if (_27324)
                                                {
                                                    _29818 = 1.0;
                                                    break;
                                                }
                                                if (_27323 >= 3.0)
                                                {
                                                    _29818 = 0.0;
                                                    break;
                                                }
                                                _29818 = (sin(3.1415927410125732421875 * _27323) * sin(_27323 * 1.0471975803375244140625)) / ((_27323 * _27323) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29819 = _29818 * _29715;
                                            int2 _29828 = clamp(int2(_27343, _29748), int2(0), _12355);
                                            float4 _29837 = srcTex.read(uint2(int3(_4769 + _29828, 0).xy), 0);
                                            float4 _35990;
                                            if (_12459)
                                            {
                                                float3 _29846 = fast::clamp(_29837.xyz, float3(0.0), float3(1.0));
                                                float3 _29855 = select(powr((_29846 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _29846 * float3(0.077399380505084991455078125), _29846 <= float3(0.040449999272823333740234375));
                                                float4 _32795 = _29837;
                                                _32795.x = _29855.x;
                                                _32795.y = _29855.y;
                                                _32795.z = _29855.z;
                                                _35990 = _32795;
                                            }
                                            else
                                            {
                                                _35990 = _29837;
                                            }
                                            float _29895;
                                            do
                                            {
                                                if (_27404)
                                                {
                                                    _29895 = 1.0;
                                                    break;
                                                }
                                                if (_27403 >= 3.0)
                                                {
                                                    _29895 = 0.0;
                                                    break;
                                                }
                                                _29895 = (sin(3.1415927410125732421875 * _27403) * sin(_27403 * 1.0471975803375244140625)) / ((_27403 * _27403) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29896 = _29895 * _29715;
                                            int2 _29905 = clamp(int2(_12346, _29748), int2(0), _12355);
                                            float4 _29914 = srcTex.read(uint2(int3(_4769 + _29905, 0).xy), 0);
                                            float4 _35991;
                                            if (_12459)
                                            {
                                                float3 _29923 = fast::clamp(_29914.xyz, float3(0.0), float3(1.0));
                                                float3 _29932 = select(powr((_29923 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _29923 * float3(0.077399380505084991455078125), _29923 <= float3(0.040449999272823333740234375));
                                                float4 _32805 = _29914;
                                                _32805.x = _29932.x;
                                                _32805.y = _29932.y;
                                                _32805.z = _29932.z;
                                                _35991 = _32805;
                                            }
                                            else
                                            {
                                                _35991 = _29914;
                                            }
                                            float _29972;
                                            do
                                            {
                                                if (_27484)
                                                {
                                                    _29972 = 1.0;
                                                    break;
                                                }
                                                if (_27483 >= 3.0)
                                                {
                                                    _29972 = 0.0;
                                                    break;
                                                }
                                                _29972 = (sin(3.1415927410125732421875 * _27483) * sin(_27483 * 1.0471975803375244140625)) / ((_27483 * _27483) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _29973 = _29972 * _29715;
                                            int2 _29982 = clamp(int2(_27503, _29748), int2(0), _12355);
                                            float4 _29991 = srcTex.read(uint2(int3(_4769 + _29982, 0).xy), 0);
                                            float4 _35992;
                                            if (_12459)
                                            {
                                                float3 _30000 = fast::clamp(_29991.xyz, float3(0.0), float3(1.0));
                                                float3 _30009 = select(powr((_30000 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _30000 * float3(0.077399380505084991455078125), _30000 <= float3(0.040449999272823333740234375));
                                                float4 _32815 = _29991;
                                                _32815.x = _30009.x;
                                                _32815.y = _30009.y;
                                                _32815.z = _30009.z;
                                                _35992 = _32815;
                                            }
                                            else
                                            {
                                                _35992 = _29991;
                                            }
                                            float _30021 = ((((((((((((((((((((((((((((((((_12344 + _27340) + _27420) + _27500) + _27580) + _27660) + _27766) + _27843) + _27920) + _27997) + _28074) + _28151) + _28260) + _28337) + _28414) + _28491) + _28568) + _28645) + _28754) + _28831) + _28908) + _28985) + _29062) + _29139) + _29248) + _29325) + _29402) + _29479) + _29556) + _29633) + _29742) + _29819) + _29896) + _29973;
                                            float _30049;
                                            do
                                            {
                                                if (_27564)
                                                {
                                                    _30049 = 1.0;
                                                    break;
                                                }
                                                if (_27563 >= 3.0)
                                                {
                                                    _30049 = 0.0;
                                                    break;
                                                }
                                                _30049 = (sin(3.1415927410125732421875 * _27563) * sin(_27563 * 1.0471975803375244140625)) / ((_27563 * _27563) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _30050 = _30049 * _29715;
                                            int2 _30059 = clamp(int2(_27583, _29748), int2(0), _12355);
                                            float4 _30068 = srcTex.read(uint2(int3(_4769 + _30059, 0).xy), 0);
                                            float4 _35993;
                                            if (_12459)
                                            {
                                                float3 _30077 = fast::clamp(_30068.xyz, float3(0.0), float3(1.0));
                                                float3 _30086 = select(powr((_30077 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _30077 * float3(0.077399380505084991455078125), _30077 <= float3(0.040449999272823333740234375));
                                                float4 _32825 = _30068;
                                                _32825.x = _30086.x;
                                                _32825.y = _30086.y;
                                                _32825.z = _30086.z;
                                                _35993 = _32825;
                                            }
                                            else
                                            {
                                                _35993 = _30068;
                                            }
                                            float3 _30097 = ((((((((((((((((_28692 + (_35977.xyz * _28754)) + (_35978.xyz * _28831)) + (_35979.xyz * _28908)) + (_35980.xyz * _28985)) + (_35981.xyz * _29062)) + (_35982.xyz * _29139)) + (_35983.xyz * _29248)) + (_35984.xyz * _29325)) + (_35985.xyz * _29402)) + (_35986.xyz * _29479)) + (_35987.xyz * _29556)) + (_35988.xyz * _29633)) + (_35989.xyz * _29742)) + (_35990.xyz * _29819)) + (_35991.xyz * _29896)) + (_35992.xyz * _29973)) + (_35993.xyz * _30050);
                                            float _30126;
                                            do
                                            {
                                                if (_27644)
                                                {
                                                    _30126 = 1.0;
                                                    break;
                                                }
                                                if (_27643 >= 3.0)
                                                {
                                                    _30126 = 0.0;
                                                    break;
                                                }
                                                _30126 = (sin(3.1415927410125732421875 * _27643) * sin(_27643 * 1.0471975803375244140625)) / ((_27643 * _27643) * 3.28986835479736328125);
                                                break;
                                            } while(false);
                                            float _30127 = _30126 * _29715;
                                            int2 _30136 = clamp(int2(_27663, _29748), int2(0), _12355);
                                            float4 _30145 = srcTex.read(uint2(int3(_4769 + _30136, 0).xy), 0);
                                            float4 _35994;
                                            if (_12459)
                                            {
                                                float3 _30154 = fast::clamp(_30145.xyz, float3(0.0), float3(1.0));
                                                float3 _30163 = select(powr((_30154 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _30154 * float3(0.077399380505084991455078125), _30154 <= float3(0.040449999272823333740234375));
                                                float4 _32835 = _30145;
                                                _32835.x = _30163.x;
                                                _32835.y = _30163.y;
                                                _32835.z = _30163.z;
                                                _35994 = _32835;
                                            }
                                            else
                                            {
                                                _35994 = _30145;
                                            }
                                            float3 _12384 = (_30097 + (_35994.xyz * _30127)) / float3(fast::max((_30021 + _30050) + _30127, 9.9999997473787516355514526367188e-06));
                                            float3 _13403;
                                            if ((_4640 > 0.00200000009499490261077880859375) && (_4633 != _4628))
                                            {
                                                int2 _4794 = int2(spvSMod(_4633, _395.g_quiltCols) * _4750, (_4764 - (_4633 / _395.g_quiltCols)) * _4758);
                                                float _13404;
                                                do
                                                {
                                                    if (_12394)
                                                    {
                                                        _13404 = 1.0;
                                                        break;
                                                    }
                                                    if (_12392 >= 3.0)
                                                    {
                                                        _13404 = 0.0;
                                                        break;
                                                    }
                                                    _13404 = (sin(3.1415927410125732421875 * _12392) * sin(_12392 * 1.0471975803375244140625)) / ((_12392 * _12392) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _13408;
                                                do
                                                {
                                                    if (_12425)
                                                    {
                                                        _13408 = 1.0;
                                                        break;
                                                    }
                                                    if (_12423 >= 3.0)
                                                    {
                                                        _13408 = 0.0;
                                                        break;
                                                    }
                                                    _13408 = (sin(3.1415927410125732421875 * _12423) * sin(_12423 * 1.0471975803375244140625)) / ((_12423 * _12423) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _12542 = _13408 * _13404;
                                                float4 _12654 = srcTex.read(uint2(int3(_4794 + _12356, 0).xy), 0);
                                                float4 _36073;
                                                if (_12459)
                                                {
                                                    float3 _12663 = fast::clamp(_12654.xyz, float3(0.0), float3(1.0));
                                                    float3 _12686 = select(powr((_12663 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _12663 * float3(0.077399380505084991455078125), _12663 <= float3(0.040449999272823333740234375));
                                                    float4 _32846 = _12654;
                                                    _32846.x = _12686.x;
                                                    _32846.y = _12686.y;
                                                    _32846.z = _12686.z;
                                                    _36073 = _32846;
                                                }
                                                else
                                                {
                                                    _36073 = _12654;
                                                }
                                                float _24469;
                                                do
                                                {
                                                    if (_27324)
                                                    {
                                                        _24469 = 1.0;
                                                        break;
                                                    }
                                                    if (_27323 >= 3.0)
                                                    {
                                                        _24469 = 0.0;
                                                        break;
                                                    }
                                                    _24469 = (sin(3.1415927410125732421875 * _27323) * sin(_27323 * 1.0471975803375244140625)) / ((_27323 * _27323) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _24470 = _24469 * _13404;
                                                float4 _24488 = srcTex.read(uint2(int3(_4794 + _27349, 0).xy), 0);
                                                float4 _36074;
                                                if (_12459)
                                                {
                                                    float3 _24497 = fast::clamp(_24488.xyz, float3(0.0), float3(1.0));
                                                    float3 _24506 = select(powr((_24497 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24497 * float3(0.077399380505084991455078125), _24497 <= float3(0.040449999272823333740234375));
                                                    float4 _32856 = _24488;
                                                    _32856.x = _24506.x;
                                                    _32856.y = _24506.y;
                                                    _32856.z = _24506.z;
                                                    _36074 = _32856;
                                                }
                                                else
                                                {
                                                    _36074 = _24488;
                                                }
                                                float _24549;
                                                do
                                                {
                                                    if (_27404)
                                                    {
                                                        _24549 = 1.0;
                                                        break;
                                                    }
                                                    if (_27403 >= 3.0)
                                                    {
                                                        _24549 = 0.0;
                                                        break;
                                                    }
                                                    _24549 = (sin(3.1415927410125732421875 * _27403) * sin(_27403 * 1.0471975803375244140625)) / ((_27403 * _27403) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _24550 = _24549 * _13404;
                                                float4 _24568 = srcTex.read(uint2(int3(_4794 + _27429, 0).xy), 0);
                                                float4 _36075;
                                                if (_12459)
                                                {
                                                    float3 _24577 = fast::clamp(_24568.xyz, float3(0.0), float3(1.0));
                                                    float3 _24586 = select(powr((_24577 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24577 * float3(0.077399380505084991455078125), _24577 <= float3(0.040449999272823333740234375));
                                                    float4 _32866 = _24568;
                                                    _32866.x = _24586.x;
                                                    _32866.y = _24586.y;
                                                    _32866.z = _24586.z;
                                                    _36075 = _32866;
                                                }
                                                else
                                                {
                                                    _36075 = _24568;
                                                }
                                                float _24629;
                                                do
                                                {
                                                    if (_27484)
                                                    {
                                                        _24629 = 1.0;
                                                        break;
                                                    }
                                                    if (_27483 >= 3.0)
                                                    {
                                                        _24629 = 0.0;
                                                        break;
                                                    }
                                                    _24629 = (sin(3.1415927410125732421875 * _27483) * sin(_27483 * 1.0471975803375244140625)) / ((_27483 * _27483) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _24630 = _24629 * _13404;
                                                float4 _24648 = srcTex.read(uint2(int3(_4794 + _27509, 0).xy), 0);
                                                float4 _36076;
                                                if (_12459)
                                                {
                                                    float3 _24657 = fast::clamp(_24648.xyz, float3(0.0), float3(1.0));
                                                    float3 _24666 = select(powr((_24657 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24657 * float3(0.077399380505084991455078125), _24657 <= float3(0.040449999272823333740234375));
                                                    float4 _32876 = _24648;
                                                    _32876.x = _24666.x;
                                                    _32876.y = _24666.y;
                                                    _32876.z = _24666.z;
                                                    _36076 = _32876;
                                                }
                                                else
                                                {
                                                    _36076 = _24648;
                                                }
                                                float _24709;
                                                do
                                                {
                                                    if (_27564)
                                                    {
                                                        _24709 = 1.0;
                                                        break;
                                                    }
                                                    if (_27563 >= 3.0)
                                                    {
                                                        _24709 = 0.0;
                                                        break;
                                                    }
                                                    _24709 = (sin(3.1415927410125732421875 * _27563) * sin(_27563 * 1.0471975803375244140625)) / ((_27563 * _27563) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _24710 = _24709 * _13404;
                                                float4 _24728 = srcTex.read(uint2(int3(_4794 + _27589, 0).xy), 0);
                                                float4 _36077;
                                                if (_12459)
                                                {
                                                    float3 _24737 = fast::clamp(_24728.xyz, float3(0.0), float3(1.0));
                                                    float3 _24746 = select(powr((_24737 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24737 * float3(0.077399380505084991455078125), _24737 <= float3(0.040449999272823333740234375));
                                                    float4 _32886 = _24728;
                                                    _32886.x = _24746.x;
                                                    _32886.y = _24746.y;
                                                    _32886.z = _24746.z;
                                                    _36077 = _32886;
                                                }
                                                else
                                                {
                                                    _36077 = _24728;
                                                }
                                                float _24789;
                                                do
                                                {
                                                    if (_27644)
                                                    {
                                                        _24789 = 1.0;
                                                        break;
                                                    }
                                                    if (_27643 >= 3.0)
                                                    {
                                                        _24789 = 0.0;
                                                        break;
                                                    }
                                                    _24789 = (sin(3.1415927410125732421875 * _27643) * sin(_27643 * 1.0471975803375244140625)) / ((_27643 * _27643) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _24790 = _24789 * _13404;
                                                float4 _24808 = srcTex.read(uint2(int3(_4794 + _27669, 0).xy), 0);
                                                float4 _36078;
                                                if (_12459)
                                                {
                                                    float3 _24817 = fast::clamp(_24808.xyz, float3(0.0), float3(1.0));
                                                    float3 _24826 = select(powr((_24817 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24817 * float3(0.077399380505084991455078125), _24817 <= float3(0.040449999272823333740234375));
                                                    float4 _32896 = _24808;
                                                    _32896.x = _24826.x;
                                                    _32896.y = _24826.y;
                                                    _32896.z = _24826.z;
                                                    _36078 = _32896;
                                                }
                                                else
                                                {
                                                    _36078 = _24808;
                                                }
                                                float _24869;
                                                do
                                                {
                                                    if (_27724)
                                                    {
                                                        _24869 = 1.0;
                                                        break;
                                                    }
                                                    if (_27723 >= 3.0)
                                                    {
                                                        _24869 = 0.0;
                                                        break;
                                                    }
                                                    _24869 = (sin(3.1415927410125732421875 * _27723) * sin(_27723 * 1.0471975803375244140625)) / ((_27723 * _27723) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _24895;
                                                do
                                                {
                                                    if (_12425)
                                                    {
                                                        _24895 = 1.0;
                                                        break;
                                                    }
                                                    if (_12423 >= 3.0)
                                                    {
                                                        _24895 = 0.0;
                                                        break;
                                                    }
                                                    _24895 = (sin(3.1415927410125732421875 * _12423) * sin(_12423 * 1.0471975803375244140625)) / ((_12423 * _12423) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _24896 = _24895 * _24869;
                                                float4 _24914 = srcTex.read(uint2(int3(_4794 + _27775, 0).xy), 0);
                                                float4 _36079;
                                                if (_12459)
                                                {
                                                    float3 _24923 = fast::clamp(_24914.xyz, float3(0.0), float3(1.0));
                                                    float3 _24932 = select(powr((_24923 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _24923 * float3(0.077399380505084991455078125), _24923 <= float3(0.040449999272823333740234375));
                                                    float4 _32907 = _24914;
                                                    _32907.x = _24932.x;
                                                    _32907.y = _24932.y;
                                                    _32907.z = _24932.z;
                                                    _36079 = _32907;
                                                }
                                                else
                                                {
                                                    _36079 = _24914;
                                                }
                                                float _24972;
                                                do
                                                {
                                                    if (_27324)
                                                    {
                                                        _24972 = 1.0;
                                                        break;
                                                    }
                                                    if (_27323 >= 3.0)
                                                    {
                                                        _24972 = 0.0;
                                                        break;
                                                    }
                                                    _24972 = (sin(3.1415927410125732421875 * _27323) * sin(_27323 * 1.0471975803375244140625)) / ((_27323 * _27323) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _24973 = _24972 * _24869;
                                                float4 _24991 = srcTex.read(uint2(int3(_4794 + _27852, 0).xy), 0);
                                                float4 _36080;
                                                if (_12459)
                                                {
                                                    float3 _25000 = fast::clamp(_24991.xyz, float3(0.0), float3(1.0));
                                                    float3 _25009 = select(powr((_25000 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25000 * float3(0.077399380505084991455078125), _25000 <= float3(0.040449999272823333740234375));
                                                    float4 _32917 = _24991;
                                                    _32917.x = _25009.x;
                                                    _32917.y = _25009.y;
                                                    _32917.z = _25009.z;
                                                    _36080 = _32917;
                                                }
                                                else
                                                {
                                                    _36080 = _24991;
                                                }
                                                float _25049;
                                                do
                                                {
                                                    if (_27404)
                                                    {
                                                        _25049 = 1.0;
                                                        break;
                                                    }
                                                    if (_27403 >= 3.0)
                                                    {
                                                        _25049 = 0.0;
                                                        break;
                                                    }
                                                    _25049 = (sin(3.1415927410125732421875 * _27403) * sin(_27403 * 1.0471975803375244140625)) / ((_27403 * _27403) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25050 = _25049 * _24869;
                                                float4 _25068 = srcTex.read(uint2(int3(_4794 + _27929, 0).xy), 0);
                                                float4 _36081;
                                                if (_12459)
                                                {
                                                    float3 _25077 = fast::clamp(_25068.xyz, float3(0.0), float3(1.0));
                                                    float3 _25086 = select(powr((_25077 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25077 * float3(0.077399380505084991455078125), _25077 <= float3(0.040449999272823333740234375));
                                                    float4 _32927 = _25068;
                                                    _32927.x = _25086.x;
                                                    _32927.y = _25086.y;
                                                    _32927.z = _25086.z;
                                                    _36081 = _32927;
                                                }
                                                else
                                                {
                                                    _36081 = _25068;
                                                }
                                                float _25126;
                                                do
                                                {
                                                    if (_27484)
                                                    {
                                                        _25126 = 1.0;
                                                        break;
                                                    }
                                                    if (_27483 >= 3.0)
                                                    {
                                                        _25126 = 0.0;
                                                        break;
                                                    }
                                                    _25126 = (sin(3.1415927410125732421875 * _27483) * sin(_27483 * 1.0471975803375244140625)) / ((_27483 * _27483) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25127 = _25126 * _24869;
                                                float4 _25145 = srcTex.read(uint2(int3(_4794 + _28006, 0).xy), 0);
                                                float4 _36082;
                                                if (_12459)
                                                {
                                                    float3 _25154 = fast::clamp(_25145.xyz, float3(0.0), float3(1.0));
                                                    float3 _25163 = select(powr((_25154 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25154 * float3(0.077399380505084991455078125), _25154 <= float3(0.040449999272823333740234375));
                                                    float4 _32937 = _25145;
                                                    _32937.x = _25163.x;
                                                    _32937.y = _25163.y;
                                                    _32937.z = _25163.z;
                                                    _36082 = _32937;
                                                }
                                                else
                                                {
                                                    _36082 = _25145;
                                                }
                                                float _25203;
                                                do
                                                {
                                                    if (_27564)
                                                    {
                                                        _25203 = 1.0;
                                                        break;
                                                    }
                                                    if (_27563 >= 3.0)
                                                    {
                                                        _25203 = 0.0;
                                                        break;
                                                    }
                                                    _25203 = (sin(3.1415927410125732421875 * _27563) * sin(_27563 * 1.0471975803375244140625)) / ((_27563 * _27563) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25204 = _25203 * _24869;
                                                float4 _25222 = srcTex.read(uint2(int3(_4794 + _28083, 0).xy), 0);
                                                float4 _36083;
                                                if (_12459)
                                                {
                                                    float3 _25231 = fast::clamp(_25222.xyz, float3(0.0), float3(1.0));
                                                    float3 _25240 = select(powr((_25231 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25231 * float3(0.077399380505084991455078125), _25231 <= float3(0.040449999272823333740234375));
                                                    float4 _32947 = _25222;
                                                    _32947.x = _25240.x;
                                                    _32947.y = _25240.y;
                                                    _32947.z = _25240.z;
                                                    _36083 = _32947;
                                                }
                                                else
                                                {
                                                    _36083 = _25222;
                                                }
                                                float _25280;
                                                do
                                                {
                                                    if (_27644)
                                                    {
                                                        _25280 = 1.0;
                                                        break;
                                                    }
                                                    if (_27643 >= 3.0)
                                                    {
                                                        _25280 = 0.0;
                                                        break;
                                                    }
                                                    _25280 = (sin(3.1415927410125732421875 * _27643) * sin(_27643 * 1.0471975803375244140625)) / ((_27643 * _27643) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25281 = _25280 * _24869;
                                                float4 _25299 = srcTex.read(uint2(int3(_4794 + _28160, 0).xy), 0);
                                                float4 _36084;
                                                if (_12459)
                                                {
                                                    float3 _25308 = fast::clamp(_25299.xyz, float3(0.0), float3(1.0));
                                                    float3 _25317 = select(powr((_25308 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25308 * float3(0.077399380505084991455078125), _25308 <= float3(0.040449999272823333740234375));
                                                    float4 _32957 = _25299;
                                                    _32957.x = _25317.x;
                                                    _32957.y = _25317.y;
                                                    _32957.z = _25317.z;
                                                    _36084 = _32957;
                                                }
                                                else
                                                {
                                                    _36084 = _25299;
                                                }
                                                float _25363;
                                                do
                                                {
                                                    if (_28218)
                                                    {
                                                        _25363 = 1.0;
                                                        break;
                                                    }
                                                    if (_28217 >= 3.0)
                                                    {
                                                        _25363 = 0.0;
                                                        break;
                                                    }
                                                    _25363 = (sin(3.1415927410125732421875 * _28217) * sin(_28217 * 1.0471975803375244140625)) / ((_28217 * _28217) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25389;
                                                do
                                                {
                                                    if (_12425)
                                                    {
                                                        _25389 = 1.0;
                                                        break;
                                                    }
                                                    if (_12423 >= 3.0)
                                                    {
                                                        _25389 = 0.0;
                                                        break;
                                                    }
                                                    _25389 = (sin(3.1415927410125732421875 * _12423) * sin(_12423 * 1.0471975803375244140625)) / ((_12423 * _12423) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25390 = _25389 * _25363;
                                                float4 _25408 = srcTex.read(uint2(int3(_4794 + _28269, 0).xy), 0);
                                                float4 _36085;
                                                if (_12459)
                                                {
                                                    float3 _25417 = fast::clamp(_25408.xyz, float3(0.0), float3(1.0));
                                                    float3 _25426 = select(powr((_25417 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25417 * float3(0.077399380505084991455078125), _25417 <= float3(0.040449999272823333740234375));
                                                    float4 _32968 = _25408;
                                                    _32968.x = _25426.x;
                                                    _32968.y = _25426.y;
                                                    _32968.z = _25426.z;
                                                    _36085 = _32968;
                                                }
                                                else
                                                {
                                                    _36085 = _25408;
                                                }
                                                float _25466;
                                                do
                                                {
                                                    if (_27324)
                                                    {
                                                        _25466 = 1.0;
                                                        break;
                                                    }
                                                    if (_27323 >= 3.0)
                                                    {
                                                        _25466 = 0.0;
                                                        break;
                                                    }
                                                    _25466 = (sin(3.1415927410125732421875 * _27323) * sin(_27323 * 1.0471975803375244140625)) / ((_27323 * _27323) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25467 = _25466 * _25363;
                                                float4 _25485 = srcTex.read(uint2(int3(_4794 + _28346, 0).xy), 0);
                                                float4 _36086;
                                                if (_12459)
                                                {
                                                    float3 _25494 = fast::clamp(_25485.xyz, float3(0.0), float3(1.0));
                                                    float3 _25503 = select(powr((_25494 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25494 * float3(0.077399380505084991455078125), _25494 <= float3(0.040449999272823333740234375));
                                                    float4 _32978 = _25485;
                                                    _32978.x = _25503.x;
                                                    _32978.y = _25503.y;
                                                    _32978.z = _25503.z;
                                                    _36086 = _32978;
                                                }
                                                else
                                                {
                                                    _36086 = _25485;
                                                }
                                                float _25543;
                                                do
                                                {
                                                    if (_27404)
                                                    {
                                                        _25543 = 1.0;
                                                        break;
                                                    }
                                                    if (_27403 >= 3.0)
                                                    {
                                                        _25543 = 0.0;
                                                        break;
                                                    }
                                                    _25543 = (sin(3.1415927410125732421875 * _27403) * sin(_27403 * 1.0471975803375244140625)) / ((_27403 * _27403) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25544 = _25543 * _25363;
                                                float4 _25562 = srcTex.read(uint2(int3(_4794 + _28423, 0).xy), 0);
                                                float4 _36087;
                                                if (_12459)
                                                {
                                                    float3 _25571 = fast::clamp(_25562.xyz, float3(0.0), float3(1.0));
                                                    float3 _25580 = select(powr((_25571 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25571 * float3(0.077399380505084991455078125), _25571 <= float3(0.040449999272823333740234375));
                                                    float4 _32988 = _25562;
                                                    _32988.x = _25580.x;
                                                    _32988.y = _25580.y;
                                                    _32988.z = _25580.z;
                                                    _36087 = _32988;
                                                }
                                                else
                                                {
                                                    _36087 = _25562;
                                                }
                                                float _25620;
                                                do
                                                {
                                                    if (_27484)
                                                    {
                                                        _25620 = 1.0;
                                                        break;
                                                    }
                                                    if (_27483 >= 3.0)
                                                    {
                                                        _25620 = 0.0;
                                                        break;
                                                    }
                                                    _25620 = (sin(3.1415927410125732421875 * _27483) * sin(_27483 * 1.0471975803375244140625)) / ((_27483 * _27483) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25621 = _25620 * _25363;
                                                float4 _25639 = srcTex.read(uint2(int3(_4794 + _28500, 0).xy), 0);
                                                float4 _36088;
                                                if (_12459)
                                                {
                                                    float3 _25648 = fast::clamp(_25639.xyz, float3(0.0), float3(1.0));
                                                    float3 _25657 = select(powr((_25648 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25648 * float3(0.077399380505084991455078125), _25648 <= float3(0.040449999272823333740234375));
                                                    float4 _32998 = _25639;
                                                    _32998.x = _25657.x;
                                                    _32998.y = _25657.y;
                                                    _32998.z = _25657.z;
                                                    _36088 = _32998;
                                                }
                                                else
                                                {
                                                    _36088 = _25639;
                                                }
                                                float _25697;
                                                do
                                                {
                                                    if (_27564)
                                                    {
                                                        _25697 = 1.0;
                                                        break;
                                                    }
                                                    if (_27563 >= 3.0)
                                                    {
                                                        _25697 = 0.0;
                                                        break;
                                                    }
                                                    _25697 = (sin(3.1415927410125732421875 * _27563) * sin(_27563 * 1.0471975803375244140625)) / ((_27563 * _27563) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25698 = _25697 * _25363;
                                                float4 _25716 = srcTex.read(uint2(int3(_4794 + _28577, 0).xy), 0);
                                                float4 _36089;
                                                if (_12459)
                                                {
                                                    float3 _25725 = fast::clamp(_25716.xyz, float3(0.0), float3(1.0));
                                                    float3 _25734 = select(powr((_25725 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25725 * float3(0.077399380505084991455078125), _25725 <= float3(0.040449999272823333740234375));
                                                    float4 _33008 = _25716;
                                                    _33008.x = _25734.x;
                                                    _33008.y = _25734.y;
                                                    _33008.z = _25734.z;
                                                    _36089 = _33008;
                                                }
                                                else
                                                {
                                                    _36089 = _25716;
                                                }
                                                float _25774;
                                                do
                                                {
                                                    if (_27644)
                                                    {
                                                        _25774 = 1.0;
                                                        break;
                                                    }
                                                    if (_27643 >= 3.0)
                                                    {
                                                        _25774 = 0.0;
                                                        break;
                                                    }
                                                    _25774 = (sin(3.1415927410125732421875 * _27643) * sin(_27643 * 1.0471975803375244140625)) / ((_27643 * _27643) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25775 = _25774 * _25363;
                                                float4 _25793 = srcTex.read(uint2(int3(_4794 + _28654, 0).xy), 0);
                                                float4 _36090;
                                                if (_12459)
                                                {
                                                    float3 _25802 = fast::clamp(_25793.xyz, float3(0.0), float3(1.0));
                                                    float3 _25811 = select(powr((_25802 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25802 * float3(0.077399380505084991455078125), _25802 <= float3(0.040449999272823333740234375));
                                                    float4 _33018 = _25793;
                                                    _33018.x = _25811.x;
                                                    _33018.y = _25811.y;
                                                    _33018.z = _25811.z;
                                                    _36090 = _33018;
                                                }
                                                else
                                                {
                                                    _36090 = _25793;
                                                }
                                                float3 _25822 = (((((((((((((((((_36073.xyz * _12542) + (_36074.xyz * _24470)) + (_36075.xyz * _24550)) + (_36076.xyz * _24630)) + (_36077.xyz * _24710)) + (_36078.xyz * _24790)) + (_36079.xyz * _24896)) + (_36080.xyz * _24973)) + (_36081.xyz * _25050)) + (_36082.xyz * _25127)) + (_36083.xyz * _25204)) + (_36084.xyz * _25281)) + (_36085.xyz * _25390)) + (_36086.xyz * _25467)) + (_36087.xyz * _25544)) + (_36088.xyz * _25621)) + (_36089.xyz * _25698)) + (_36090.xyz * _25775);
                                                float _25857;
                                                do
                                                {
                                                    if (_28712)
                                                    {
                                                        _25857 = 1.0;
                                                        break;
                                                    }
                                                    if (_28711 >= 3.0)
                                                    {
                                                        _25857 = 0.0;
                                                        break;
                                                    }
                                                    _25857 = (sin(3.1415927410125732421875 * _28711) * sin(_28711 * 1.0471975803375244140625)) / ((_28711 * _28711) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25883;
                                                do
                                                {
                                                    if (_12425)
                                                    {
                                                        _25883 = 1.0;
                                                        break;
                                                    }
                                                    if (_12423 >= 3.0)
                                                    {
                                                        _25883 = 0.0;
                                                        break;
                                                    }
                                                    _25883 = (sin(3.1415927410125732421875 * _12423) * sin(_12423 * 1.0471975803375244140625)) / ((_12423 * _12423) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25884 = _25883 * _25857;
                                                float4 _25902 = srcTex.read(uint2(int3(_4794 + _28763, 0).xy), 0);
                                                float4 _36091;
                                                if (_12459)
                                                {
                                                    float3 _25911 = fast::clamp(_25902.xyz, float3(0.0), float3(1.0));
                                                    float3 _25920 = select(powr((_25911 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25911 * float3(0.077399380505084991455078125), _25911 <= float3(0.040449999272823333740234375));
                                                    float4 _33029 = _25902;
                                                    _33029.x = _25920.x;
                                                    _33029.y = _25920.y;
                                                    _33029.z = _25920.z;
                                                    _36091 = _33029;
                                                }
                                                else
                                                {
                                                    _36091 = _25902;
                                                }
                                                float _25960;
                                                do
                                                {
                                                    if (_27324)
                                                    {
                                                        _25960 = 1.0;
                                                        break;
                                                    }
                                                    if (_27323 >= 3.0)
                                                    {
                                                        _25960 = 0.0;
                                                        break;
                                                    }
                                                    _25960 = (sin(3.1415927410125732421875 * _27323) * sin(_27323 * 1.0471975803375244140625)) / ((_27323 * _27323) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _25961 = _25960 * _25857;
                                                float4 _25979 = srcTex.read(uint2(int3(_4794 + _28840, 0).xy), 0);
                                                float4 _36092;
                                                if (_12459)
                                                {
                                                    float3 _25988 = fast::clamp(_25979.xyz, float3(0.0), float3(1.0));
                                                    float3 _25997 = select(powr((_25988 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _25988 * float3(0.077399380505084991455078125), _25988 <= float3(0.040449999272823333740234375));
                                                    float4 _33039 = _25979;
                                                    _33039.x = _25997.x;
                                                    _33039.y = _25997.y;
                                                    _33039.z = _25997.z;
                                                    _36092 = _33039;
                                                }
                                                else
                                                {
                                                    _36092 = _25979;
                                                }
                                                float _26037;
                                                do
                                                {
                                                    if (_27404)
                                                    {
                                                        _26037 = 1.0;
                                                        break;
                                                    }
                                                    if (_27403 >= 3.0)
                                                    {
                                                        _26037 = 0.0;
                                                        break;
                                                    }
                                                    _26037 = (sin(3.1415927410125732421875 * _27403) * sin(_27403 * 1.0471975803375244140625)) / ((_27403 * _27403) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26038 = _26037 * _25857;
                                                float4 _26056 = srcTex.read(uint2(int3(_4794 + _28917, 0).xy), 0);
                                                float4 _36093;
                                                if (_12459)
                                                {
                                                    float3 _26065 = fast::clamp(_26056.xyz, float3(0.0), float3(1.0));
                                                    float3 _26074 = select(powr((_26065 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _26065 * float3(0.077399380505084991455078125), _26065 <= float3(0.040449999272823333740234375));
                                                    float4 _33049 = _26056;
                                                    _33049.x = _26074.x;
                                                    _33049.y = _26074.y;
                                                    _33049.z = _26074.z;
                                                    _36093 = _33049;
                                                }
                                                else
                                                {
                                                    _36093 = _26056;
                                                }
                                                float _26114;
                                                do
                                                {
                                                    if (_27484)
                                                    {
                                                        _26114 = 1.0;
                                                        break;
                                                    }
                                                    if (_27483 >= 3.0)
                                                    {
                                                        _26114 = 0.0;
                                                        break;
                                                    }
                                                    _26114 = (sin(3.1415927410125732421875 * _27483) * sin(_27483 * 1.0471975803375244140625)) / ((_27483 * _27483) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26115 = _26114 * _25857;
                                                float4 _26133 = srcTex.read(uint2(int3(_4794 + _28994, 0).xy), 0);
                                                float4 _36094;
                                                if (_12459)
                                                {
                                                    float3 _26142 = fast::clamp(_26133.xyz, float3(0.0), float3(1.0));
                                                    float3 _26151 = select(powr((_26142 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _26142 * float3(0.077399380505084991455078125), _26142 <= float3(0.040449999272823333740234375));
                                                    float4 _33059 = _26133;
                                                    _33059.x = _26151.x;
                                                    _33059.y = _26151.y;
                                                    _33059.z = _26151.z;
                                                    _36094 = _33059;
                                                }
                                                else
                                                {
                                                    _36094 = _26133;
                                                }
                                                float _26191;
                                                do
                                                {
                                                    if (_27564)
                                                    {
                                                        _26191 = 1.0;
                                                        break;
                                                    }
                                                    if (_27563 >= 3.0)
                                                    {
                                                        _26191 = 0.0;
                                                        break;
                                                    }
                                                    _26191 = (sin(3.1415927410125732421875 * _27563) * sin(_27563 * 1.0471975803375244140625)) / ((_27563 * _27563) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26192 = _26191 * _25857;
                                                float4 _26210 = srcTex.read(uint2(int3(_4794 + _29071, 0).xy), 0);
                                                float4 _36095;
                                                if (_12459)
                                                {
                                                    float3 _26219 = fast::clamp(_26210.xyz, float3(0.0), float3(1.0));
                                                    float3 _26228 = select(powr((_26219 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _26219 * float3(0.077399380505084991455078125), _26219 <= float3(0.040449999272823333740234375));
                                                    float4 _33069 = _26210;
                                                    _33069.x = _26228.x;
                                                    _33069.y = _26228.y;
                                                    _33069.z = _26228.z;
                                                    _36095 = _33069;
                                                }
                                                else
                                                {
                                                    _36095 = _26210;
                                                }
                                                float _26268;
                                                do
                                                {
                                                    if (_27644)
                                                    {
                                                        _26268 = 1.0;
                                                        break;
                                                    }
                                                    if (_27643 >= 3.0)
                                                    {
                                                        _26268 = 0.0;
                                                        break;
                                                    }
                                                    _26268 = (sin(3.1415927410125732421875 * _27643) * sin(_27643 * 1.0471975803375244140625)) / ((_27643 * _27643) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26269 = _26268 * _25857;
                                                float4 _26287 = srcTex.read(uint2(int3(_4794 + _29148, 0).xy), 0);
                                                float4 _36096;
                                                if (_12459)
                                                {
                                                    float3 _26296 = fast::clamp(_26287.xyz, float3(0.0), float3(1.0));
                                                    float3 _26305 = select(powr((_26296 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _26296 * float3(0.077399380505084991455078125), _26296 <= float3(0.040449999272823333740234375));
                                                    float4 _33079 = _26287;
                                                    _33079.x = _26305.x;
                                                    _33079.y = _26305.y;
                                                    _33079.z = _26305.z;
                                                    _36096 = _33079;
                                                }
                                                else
                                                {
                                                    _36096 = _26287;
                                                }
                                                float _26351;
                                                do
                                                {
                                                    if (_29206)
                                                    {
                                                        _26351 = 1.0;
                                                        break;
                                                    }
                                                    if (_29205 >= 3.0)
                                                    {
                                                        _26351 = 0.0;
                                                        break;
                                                    }
                                                    _26351 = (sin(3.1415927410125732421875 * _29205) * sin(_29205 * 1.0471975803375244140625)) / ((_29205 * _29205) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26377;
                                                do
                                                {
                                                    if (_12425)
                                                    {
                                                        _26377 = 1.0;
                                                        break;
                                                    }
                                                    if (_12423 >= 3.0)
                                                    {
                                                        _26377 = 0.0;
                                                        break;
                                                    }
                                                    _26377 = (sin(3.1415927410125732421875 * _12423) * sin(_12423 * 1.0471975803375244140625)) / ((_12423 * _12423) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26378 = _26377 * _26351;
                                                float4 _26396 = srcTex.read(uint2(int3(_4794 + _29257, 0).xy), 0);
                                                float4 _36097;
                                                if (_12459)
                                                {
                                                    float3 _26405 = fast::clamp(_26396.xyz, float3(0.0), float3(1.0));
                                                    float3 _26414 = select(powr((_26405 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _26405 * float3(0.077399380505084991455078125), _26405 <= float3(0.040449999272823333740234375));
                                                    float4 _33090 = _26396;
                                                    _33090.x = _26414.x;
                                                    _33090.y = _26414.y;
                                                    _33090.z = _26414.z;
                                                    _36097 = _33090;
                                                }
                                                else
                                                {
                                                    _36097 = _26396;
                                                }
                                                float _26454;
                                                do
                                                {
                                                    if (_27324)
                                                    {
                                                        _26454 = 1.0;
                                                        break;
                                                    }
                                                    if (_27323 >= 3.0)
                                                    {
                                                        _26454 = 0.0;
                                                        break;
                                                    }
                                                    _26454 = (sin(3.1415927410125732421875 * _27323) * sin(_27323 * 1.0471975803375244140625)) / ((_27323 * _27323) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26455 = _26454 * _26351;
                                                float4 _26473 = srcTex.read(uint2(int3(_4794 + _29334, 0).xy), 0);
                                                float4 _36098;
                                                if (_12459)
                                                {
                                                    float3 _26482 = fast::clamp(_26473.xyz, float3(0.0), float3(1.0));
                                                    float3 _26491 = select(powr((_26482 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _26482 * float3(0.077399380505084991455078125), _26482 <= float3(0.040449999272823333740234375));
                                                    float4 _33100 = _26473;
                                                    _33100.x = _26491.x;
                                                    _33100.y = _26491.y;
                                                    _33100.z = _26491.z;
                                                    _36098 = _33100;
                                                }
                                                else
                                                {
                                                    _36098 = _26473;
                                                }
                                                float _26531;
                                                do
                                                {
                                                    if (_27404)
                                                    {
                                                        _26531 = 1.0;
                                                        break;
                                                    }
                                                    if (_27403 >= 3.0)
                                                    {
                                                        _26531 = 0.0;
                                                        break;
                                                    }
                                                    _26531 = (sin(3.1415927410125732421875 * _27403) * sin(_27403 * 1.0471975803375244140625)) / ((_27403 * _27403) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26532 = _26531 * _26351;
                                                float4 _26550 = srcTex.read(uint2(int3(_4794 + _29411, 0).xy), 0);
                                                float4 _36099;
                                                if (_12459)
                                                {
                                                    float3 _26559 = fast::clamp(_26550.xyz, float3(0.0), float3(1.0));
                                                    float3 _26568 = select(powr((_26559 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _26559 * float3(0.077399380505084991455078125), _26559 <= float3(0.040449999272823333740234375));
                                                    float4 _33110 = _26550;
                                                    _33110.x = _26568.x;
                                                    _33110.y = _26568.y;
                                                    _33110.z = _26568.z;
                                                    _36099 = _33110;
                                                }
                                                else
                                                {
                                                    _36099 = _26550;
                                                }
                                                float _26608;
                                                do
                                                {
                                                    if (_27484)
                                                    {
                                                        _26608 = 1.0;
                                                        break;
                                                    }
                                                    if (_27483 >= 3.0)
                                                    {
                                                        _26608 = 0.0;
                                                        break;
                                                    }
                                                    _26608 = (sin(3.1415927410125732421875 * _27483) * sin(_27483 * 1.0471975803375244140625)) / ((_27483 * _27483) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26609 = _26608 * _26351;
                                                float4 _26627 = srcTex.read(uint2(int3(_4794 + _29488, 0).xy), 0);
                                                float4 _36100;
                                                if (_12459)
                                                {
                                                    float3 _26636 = fast::clamp(_26627.xyz, float3(0.0), float3(1.0));
                                                    float3 _26645 = select(powr((_26636 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _26636 * float3(0.077399380505084991455078125), _26636 <= float3(0.040449999272823333740234375));
                                                    float4 _33120 = _26627;
                                                    _33120.x = _26645.x;
                                                    _33120.y = _26645.y;
                                                    _33120.z = _26645.z;
                                                    _36100 = _33120;
                                                }
                                                else
                                                {
                                                    _36100 = _26627;
                                                }
                                                float _26685;
                                                do
                                                {
                                                    if (_27564)
                                                    {
                                                        _26685 = 1.0;
                                                        break;
                                                    }
                                                    if (_27563 >= 3.0)
                                                    {
                                                        _26685 = 0.0;
                                                        break;
                                                    }
                                                    _26685 = (sin(3.1415927410125732421875 * _27563) * sin(_27563 * 1.0471975803375244140625)) / ((_27563 * _27563) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26686 = _26685 * _26351;
                                                float4 _26704 = srcTex.read(uint2(int3(_4794 + _29565, 0).xy), 0);
                                                float4 _36101;
                                                if (_12459)
                                                {
                                                    float3 _26713 = fast::clamp(_26704.xyz, float3(0.0), float3(1.0));
                                                    float3 _26722 = select(powr((_26713 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _26713 * float3(0.077399380505084991455078125), _26713 <= float3(0.040449999272823333740234375));
                                                    float4 _33130 = _26704;
                                                    _33130.x = _26722.x;
                                                    _33130.y = _26722.y;
                                                    _33130.z = _26722.z;
                                                    _36101 = _33130;
                                                }
                                                else
                                                {
                                                    _36101 = _26704;
                                                }
                                                float _26762;
                                                do
                                                {
                                                    if (_27644)
                                                    {
                                                        _26762 = 1.0;
                                                        break;
                                                    }
                                                    if (_27643 >= 3.0)
                                                    {
                                                        _26762 = 0.0;
                                                        break;
                                                    }
                                                    _26762 = (sin(3.1415927410125732421875 * _27643) * sin(_27643 * 1.0471975803375244140625)) / ((_27643 * _27643) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26763 = _26762 * _26351;
                                                float4 _26781 = srcTex.read(uint2(int3(_4794 + _29642, 0).xy), 0);
                                                float4 _36102;
                                                if (_12459)
                                                {
                                                    float3 _26790 = fast::clamp(_26781.xyz, float3(0.0), float3(1.0));
                                                    float3 _26799 = select(powr((_26790 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _26790 * float3(0.077399380505084991455078125), _26790 <= float3(0.040449999272823333740234375));
                                                    float4 _33140 = _26781;
                                                    _33140.x = _26799.x;
                                                    _33140.y = _26799.y;
                                                    _33140.z = _26799.z;
                                                    _36102 = _33140;
                                                }
                                                else
                                                {
                                                    _36102 = _26781;
                                                }
                                                float _26845;
                                                do
                                                {
                                                    if (_29700)
                                                    {
                                                        _26845 = 1.0;
                                                        break;
                                                    }
                                                    if (_29699 >= 3.0)
                                                    {
                                                        _26845 = 0.0;
                                                        break;
                                                    }
                                                    _26845 = (sin(3.1415927410125732421875 * _29699) * sin(_29699 * 1.0471975803375244140625)) / ((_29699 * _29699) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26871;
                                                do
                                                {
                                                    if (_12425)
                                                    {
                                                        _26871 = 1.0;
                                                        break;
                                                    }
                                                    if (_12423 >= 3.0)
                                                    {
                                                        _26871 = 0.0;
                                                        break;
                                                    }
                                                    _26871 = (sin(3.1415927410125732421875 * _12423) * sin(_12423 * 1.0471975803375244140625)) / ((_12423 * _12423) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26872 = _26871 * _26845;
                                                float4 _26890 = srcTex.read(uint2(int3(_4794 + _29751, 0).xy), 0);
                                                float4 _36103;
                                                if (_12459)
                                                {
                                                    float3 _26899 = fast::clamp(_26890.xyz, float3(0.0), float3(1.0));
                                                    float3 _26908 = select(powr((_26899 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _26899 * float3(0.077399380505084991455078125), _26899 <= float3(0.040449999272823333740234375));
                                                    float4 _33151 = _26890;
                                                    _33151.x = _26908.x;
                                                    _33151.y = _26908.y;
                                                    _33151.z = _26908.z;
                                                    _36103 = _33151;
                                                }
                                                else
                                                {
                                                    _36103 = _26890;
                                                }
                                                float _26948;
                                                do
                                                {
                                                    if (_27324)
                                                    {
                                                        _26948 = 1.0;
                                                        break;
                                                    }
                                                    if (_27323 >= 3.0)
                                                    {
                                                        _26948 = 0.0;
                                                        break;
                                                    }
                                                    _26948 = (sin(3.1415927410125732421875 * _27323) * sin(_27323 * 1.0471975803375244140625)) / ((_27323 * _27323) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _26949 = _26948 * _26845;
                                                float4 _26967 = srcTex.read(uint2(int3(_4794 + _29828, 0).xy), 0);
                                                float4 _36104;
                                                if (_12459)
                                                {
                                                    float3 _26976 = fast::clamp(_26967.xyz, float3(0.0), float3(1.0));
                                                    float3 _26985 = select(powr((_26976 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _26976 * float3(0.077399380505084991455078125), _26976 <= float3(0.040449999272823333740234375));
                                                    float4 _33161 = _26967;
                                                    _33161.x = _26985.x;
                                                    _33161.y = _26985.y;
                                                    _33161.z = _26985.z;
                                                    _36104 = _33161;
                                                }
                                                else
                                                {
                                                    _36104 = _26967;
                                                }
                                                float _27025;
                                                do
                                                {
                                                    if (_27404)
                                                    {
                                                        _27025 = 1.0;
                                                        break;
                                                    }
                                                    if (_27403 >= 3.0)
                                                    {
                                                        _27025 = 0.0;
                                                        break;
                                                    }
                                                    _27025 = (sin(3.1415927410125732421875 * _27403) * sin(_27403 * 1.0471975803375244140625)) / ((_27403 * _27403) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _27026 = _27025 * _26845;
                                                float4 _27044 = srcTex.read(uint2(int3(_4794 + _29905, 0).xy), 0);
                                                float4 _36105;
                                                if (_12459)
                                                {
                                                    float3 _27053 = fast::clamp(_27044.xyz, float3(0.0), float3(1.0));
                                                    float3 _27062 = select(powr((_27053 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _27053 * float3(0.077399380505084991455078125), _27053 <= float3(0.040449999272823333740234375));
                                                    float4 _33171 = _27044;
                                                    _33171.x = _27062.x;
                                                    _33171.y = _27062.y;
                                                    _33171.z = _27062.z;
                                                    _36105 = _33171;
                                                }
                                                else
                                                {
                                                    _36105 = _27044;
                                                }
                                                float _27102;
                                                do
                                                {
                                                    if (_27484)
                                                    {
                                                        _27102 = 1.0;
                                                        break;
                                                    }
                                                    if (_27483 >= 3.0)
                                                    {
                                                        _27102 = 0.0;
                                                        break;
                                                    }
                                                    _27102 = (sin(3.1415927410125732421875 * _27483) * sin(_27483 * 1.0471975803375244140625)) / ((_27483 * _27483) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _27103 = _27102 * _26845;
                                                float4 _27121 = srcTex.read(uint2(int3(_4794 + _29982, 0).xy), 0);
                                                float4 _36106;
                                                if (_12459)
                                                {
                                                    float3 _27130 = fast::clamp(_27121.xyz, float3(0.0), float3(1.0));
                                                    float3 _27139 = select(powr((_27130 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _27130 * float3(0.077399380505084991455078125), _27130 <= float3(0.040449999272823333740234375));
                                                    float4 _33181 = _27121;
                                                    _33181.x = _27139.x;
                                                    _33181.y = _27139.y;
                                                    _33181.z = _27139.z;
                                                    _36106 = _33181;
                                                }
                                                else
                                                {
                                                    _36106 = _27121;
                                                }
                                                float _27151 = ((((((((((((((((((((((((((((((((_12542 + _24470) + _24550) + _24630) + _24710) + _24790) + _24896) + _24973) + _25050) + _25127) + _25204) + _25281) + _25390) + _25467) + _25544) + _25621) + _25698) + _25775) + _25884) + _25961) + _26038) + _26115) + _26192) + _26269) + _26378) + _26455) + _26532) + _26609) + _26686) + _26763) + _26872) + _26949) + _27026) + _27103;
                                                float _27179;
                                                do
                                                {
                                                    if (_27564)
                                                    {
                                                        _27179 = 1.0;
                                                        break;
                                                    }
                                                    if (_27563 >= 3.0)
                                                    {
                                                        _27179 = 0.0;
                                                        break;
                                                    }
                                                    _27179 = (sin(3.1415927410125732421875 * _27563) * sin(_27563 * 1.0471975803375244140625)) / ((_27563 * _27563) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _27180 = _27179 * _26845;
                                                float4 _27198 = srcTex.read(uint2(int3(_4794 + _30059, 0).xy), 0);
                                                float4 _36107;
                                                if (_12459)
                                                {
                                                    float3 _27207 = fast::clamp(_27198.xyz, float3(0.0), float3(1.0));
                                                    float3 _27216 = select(powr((_27207 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _27207 * float3(0.077399380505084991455078125), _27207 <= float3(0.040449999272823333740234375));
                                                    float4 _33191 = _27198;
                                                    _33191.x = _27216.x;
                                                    _33191.y = _27216.y;
                                                    _33191.z = _27216.z;
                                                    _36107 = _33191;
                                                }
                                                else
                                                {
                                                    _36107 = _27198;
                                                }
                                                float3 _27227 = ((((((((((((((((_25822 + (_36091.xyz * _25884)) + (_36092.xyz * _25961)) + (_36093.xyz * _26038)) + (_36094.xyz * _26115)) + (_36095.xyz * _26192)) + (_36096.xyz * _26269)) + (_36097.xyz * _26378)) + (_36098.xyz * _26455)) + (_36099.xyz * _26532)) + (_36100.xyz * _26609)) + (_36101.xyz * _26686)) + (_36102.xyz * _26763)) + (_36103.xyz * _26872)) + (_36104.xyz * _26949)) + (_36105.xyz * _27026)) + (_36106.xyz * _27103)) + (_36107.xyz * _27180);
                                                float _27256;
                                                do
                                                {
                                                    if (_27644)
                                                    {
                                                        _27256 = 1.0;
                                                        break;
                                                    }
                                                    if (_27643 >= 3.0)
                                                    {
                                                        _27256 = 0.0;
                                                        break;
                                                    }
                                                    _27256 = (sin(3.1415927410125732421875 * _27643) * sin(_27643 * 1.0471975803375244140625)) / ((_27643 * _27643) * 3.28986835479736328125);
                                                    break;
                                                } while(false);
                                                float _27257 = _27256 * _26845;
                                                float4 _27275 = srcTex.read(uint2(int3(_4794 + _30136, 0).xy), 0);
                                                float4 _36108;
                                                if (_12459)
                                                {
                                                    float3 _27284 = fast::clamp(_27275.xyz, float3(0.0), float3(1.0));
                                                    float3 _27293 = select(powr((_27284 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _27284 * float3(0.077399380505084991455078125), _27284 <= float3(0.040449999272823333740234375));
                                                    float4 _33201 = _27275;
                                                    _33201.x = _27293.x;
                                                    _33201.y = _27293.y;
                                                    _33201.z = _27293.z;
                                                    _36108 = _33201;
                                                }
                                                else
                                                {
                                                    _36108 = _27275;
                                                }
                                                _13403 = mix(_12384, (_27227 + (_36108.xyz * _27257)) / float3(fast::max((_27151 + _27180) + _27257, 9.9999997473787516355514526367188e-06)), float3(_4640));
                                            }
                                            else
                                            {
                                                _13403 = _12384;
                                            }
                                            _13619 = float4(_13403, 1.0);
                                            break;
                                        }
                                        else
                                        {
                                            if (_395.g_format == 10)
                                            {
                                                float _4819 = 1.0 / fast::max(0.0500000007450580596923828125, _395.g_vrZoom);
                                                float3 _4851 = fast::normalize(float3(((_3592 * 2.0) - 1.0) * _4819, (1.0 - (in.i_uv.y * 2.0)) * (_4819 / fast::max(9.9999997473787516355514526367188e-05, (_395.g_paneH > 0.0) ? (_395.g_paneW / fast::max(1.0, _395.g_paneH)) : 1.0)), 1.0));
                                                float _4854 = cos(_395.g_vrPitch);
                                                float _4857 = sin(_395.g_vrPitch);
                                                float _4859 = _4851.x;
                                                float _4862 = _4851.y;
                                                float _4866 = _4851.z;
                                                float _4877 = (_4857 * _4862) + (_4854 * _4866);
                                                float _4881 = cos(_395.g_vrYaw);
                                                float _4884 = sin(_395.g_vrYaw);
                                                float _4911 = precise::atan2((_4881 * _4859) + (_4884 * _4877), ((-_4884) * _4859) + (_4881 * _4877));
                                                if ((_395.g_vrIs360 == 0) && ((_4911 < (-1.57079637050628662109375)) || (_4911 > 1.57079637050628662109375)))
                                                {
                                                    _13619 = float4(0.0, 0.0, 0.0, 1.0);
                                                    break;
                                                }
                                                float _4936 = (_395.g_vrIs360 == 1) ? ((_4911 * 0.15915493667125701904296875) + 0.5) : ((_4911 * 0.3183098733425140380859375) + 0.5);
                                                float _4939 = 0.5 - (asin(fast::clamp((_4854 * _4862) - (_4857 * _4866), -1.0, 1.0)) * 0.3183098733425140380859375);
                                                float2 _13395;
                                                if (_395.g_vrIsSBS == 1)
                                                {
                                                    float _4946 = _4936 * 0.5;
                                                    _13395 = float2(_13391 ? (0.5 + _4946) : _4946, _4939);
                                                }
                                                else
                                                {
                                                    float _4957 = _4939 * 0.5;
                                                    _13395 = float2(_4936, _13391 ? (0.5 + _4957) : _4957);
                                                }
                                                float4 _13396;
                                                do
                                                {
                                                    if (_395.g_srcDecode < 0.5)
                                                    {
                                                        _13396 = srcTex.sample(samp, _13395, level(0.0));
                                                        break;
                                                    }
                                                    uint2 _12722 = uint2(srcTex.get_width(), srcTex.get_height());
                                                    uint _12724 = _12722.x;
                                                    uint _12726 = _12722.y;
                                                    float2 _12735 = (_13395 * float2(float(_12724), float(_12726))) - float2(0.5);
                                                    int2 _12742 = int2(int(_12724), int(_12726)) - int2(1);
                                                    float2 _12744 = rint(_12735);
                                                    if (all(abs(_12735 - _12744) < float2(0.001953125)))
                                                    {
                                                        float4 _12826 = srcTex.read(uint2(int3(clamp(int2(_12744), int2(0), _12742), 0).xy), 0);
                                                        float4 _35956;
                                                        if (_395.g_srcDecode > 0.5)
                                                        {
                                                            float3 _12835 = fast::clamp(_12826.xyz, float3(0.0), float3(1.0));
                                                            float3 _12858 = select(powr((_12835 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _12835 * float3(0.077399380505084991455078125), _12835 <= float3(0.040449999272823333740234375));
                                                            float4 _32420 = _12826;
                                                            _32420.x = _12858.x;
                                                            _32420.y = _12858.y;
                                                            _32420.z = _12858.z;
                                                            _35956 = _32420;
                                                        }
                                                        else
                                                        {
                                                            _35956 = _12826;
                                                        }
                                                        _13396 = _35956;
                                                        break;
                                                    }
                                                    float2 _12762 = fract(_12735);
                                                    int2 _12765 = int2(floor(_12735));
                                                    int2 _12767 = clamp(_12765, int2(0), _12742);
                                                    int2 _12774 = clamp(_12765 + int2(1), int2(0), _12742);
                                                    int _12776 = _12767.x;
                                                    float4 _12868 = srcTex.read(uint2(int3(_12776, _12767.y, 0).xy), 0);
                                                    bool _12871 = _395.g_srcDecode > 0.5;
                                                    float4 _35952;
                                                    if (_12871)
                                                    {
                                                        float3 _12877 = fast::clamp(_12868.xyz, float3(0.0), float3(1.0));
                                                        float3 _12900 = select(powr((_12877 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _12877 * float3(0.077399380505084991455078125), _12877 <= float3(0.040449999272823333740234375));
                                                        float4 _32429 = _12868;
                                                        _32429.x = _12900.x;
                                                        _32429.y = _12900.y;
                                                        _32429.z = _12900.z;
                                                        _35952 = _32429;
                                                    }
                                                    else
                                                    {
                                                        _35952 = _12868;
                                                    }
                                                    int _12782 = _12774.x;
                                                    float4 _12910 = srcTex.read(uint2(int3(_12782, _12767.y, 0).xy), 0);
                                                    float4 _35953;
                                                    if (_12871)
                                                    {
                                                        float3 _12919 = fast::clamp(_12910.xyz, float3(0.0), float3(1.0));
                                                        float3 _12942 = select(powr((_12919 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _12919 * float3(0.077399380505084991455078125), _12919 <= float3(0.040449999272823333740234375));
                                                        float4 _32438 = _12910;
                                                        _32438.x = _12942.x;
                                                        _32438.y = _12942.y;
                                                        _32438.z = _12942.z;
                                                        _35953 = _32438;
                                                    }
                                                    else
                                                    {
                                                        _35953 = _12910;
                                                    }
                                                    float4 _12952 = srcTex.read(uint2(int3(_12776, _12774.y, 0).xy), 0);
                                                    float4 _35954;
                                                    if (_12871)
                                                    {
                                                        float3 _12961 = fast::clamp(_12952.xyz, float3(0.0), float3(1.0));
                                                        float3 _12984 = select(powr((_12961 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _12961 * float3(0.077399380505084991455078125), _12961 <= float3(0.040449999272823333740234375));
                                                        float4 _32447 = _12952;
                                                        _32447.x = _12984.x;
                                                        _32447.y = _12984.y;
                                                        _32447.z = _12984.z;
                                                        _35954 = _32447;
                                                    }
                                                    else
                                                    {
                                                        _35954 = _12952;
                                                    }
                                                    float4 _12994 = srcTex.read(uint2(int3(_12782, _12774.y, 0).xy), 0);
                                                    float4 _35955;
                                                    if (_12871)
                                                    {
                                                        float3 _13003 = fast::clamp(_12994.xyz, float3(0.0), float3(1.0));
                                                        float3 _13026 = select(powr((_13003 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13003 * float3(0.077399380505084991455078125), _13003 <= float3(0.040449999272823333740234375));
                                                        float4 _32456 = _12994;
                                                        _32456.x = _13026.x;
                                                        _32456.y = _13026.y;
                                                        _32456.z = _13026.z;
                                                        _35955 = _32456;
                                                    }
                                                    else
                                                    {
                                                        _35955 = _12994;
                                                    }
                                                    float4 _12803 = float4(_12762.x);
                                                    _13396 = mix(mix(_35952, _35953, _12803), mix(_35954, _35955, _12803), float4(_12762.y));
                                                    break;
                                                } while(false);
                                                _13619 = float4(_13396.xyz, 1.0);
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        float _13393;
        if (_395.g_format == 11)
        {
            _13393 = (in.i_uv.y * 0.5) + 0.25;
        }
        else
        {
            _13393 = in.i_uv.y;
        }
        float _4995 = _3592 * 0.5;
        float2 _5002 = float2(_13391 ? (0.5 + _4995) : _4995, _13393);
        float4 _13394;
        do
        {
            if (_395.g_srcDecode < 0.5)
            {
                _13394 = srcTex.sample(samp, _5002, level(0.0));
                break;
            }
            uint2 _13070 = uint2(srcTex.get_width(), srcTex.get_height());
            uint _13072 = _13070.x;
            uint _13074 = _13070.y;
            float2 _13083 = (_5002 * float2(float(_13072), float(_13074))) - float2(0.5);
            int2 _13090 = int2(int(_13072), int(_13074)) - int2(1);
            float2 _13092 = rint(_13083);
            if (all(abs(_13083 - _13092) < float2(0.001953125)))
            {
                float4 _13174 = srcTex.read(uint2(int3(clamp(int2(_13092), int2(0), _13090), 0).xy), 0);
                float4 _35951;
                if (_395.g_srcDecode > 0.5)
                {
                    float3 _13183 = fast::clamp(_13174.xyz, float3(0.0), float3(1.0));
                    float3 _13206 = select(powr((_13183 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13183 * float3(0.077399380505084991455078125), _13183 <= float3(0.040449999272823333740234375));
                    float4 _35879 = _13174;
                    _35879.x = _13206.x;
                    _35879.y = _13206.y;
                    _35879.z = _13206.z;
                    _35951 = _35879;
                }
                else
                {
                    _35951 = _13174;
                }
                _13394 = _35951;
                break;
            }
            float2 _13110 = fract(_13083);
            int2 _13113 = int2(floor(_13083));
            int2 _13115 = clamp(_13113, int2(0), _13090);
            int2 _13122 = clamp(_13113 + int2(1), int2(0), _13090);
            int _13124 = _13115.x;
            float4 _13216 = srcTex.read(uint2(int3(_13124, _13115.y, 0).xy), 0);
            bool _13219 = _395.g_srcDecode > 0.5;
            float4 _35947;
            if (_13219)
            {
                float3 _13225 = fast::clamp(_13216.xyz, float3(0.0), float3(1.0));
                float3 _13248 = select(powr((_13225 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13225 * float3(0.077399380505084991455078125), _13225 <= float3(0.040449999272823333740234375));
                float4 _35888 = _13216;
                _35888.x = _13248.x;
                _35888.y = _13248.y;
                _35888.z = _13248.z;
                _35947 = _35888;
            }
            else
            {
                _35947 = _13216;
            }
            int _13130 = _13122.x;
            float4 _13258 = srcTex.read(uint2(int3(_13130, _13115.y, 0).xy), 0);
            float4 _35948;
            if (_13219)
            {
                float3 _13267 = fast::clamp(_13258.xyz, float3(0.0), float3(1.0));
                float3 _13290 = select(powr((_13267 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13267 * float3(0.077399380505084991455078125), _13267 <= float3(0.040449999272823333740234375));
                float4 _35897 = _13258;
                _35897.x = _13290.x;
                _35897.y = _13290.y;
                _35897.z = _13290.z;
                _35948 = _35897;
            }
            else
            {
                _35948 = _13258;
            }
            float4 _13300 = srcTex.read(uint2(int3(_13124, _13122.y, 0).xy), 0);
            float4 _35949;
            if (_13219)
            {
                float3 _13309 = fast::clamp(_13300.xyz, float3(0.0), float3(1.0));
                float3 _13332 = select(powr((_13309 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13309 * float3(0.077399380505084991455078125), _13309 <= float3(0.040449999272823333740234375));
                float4 _35906 = _13300;
                _35906.x = _13332.x;
                _35906.y = _13332.y;
                _35906.z = _13332.z;
                _35949 = _35906;
            }
            else
            {
                _35949 = _13300;
            }
            float4 _13342 = srcTex.read(uint2(int3(_13130, _13122.y, 0).xy), 0);
            float4 _35950;
            if (_13219)
            {
                float3 _13351 = fast::clamp(_13342.xyz, float3(0.0), float3(1.0));
                float3 _13374 = select(powr((_13351 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _13351 * float3(0.077399380505084991455078125), _13351 <= float3(0.040449999272823333740234375));
                float4 _35915 = _13342;
                _35915.x = _13374.x;
                _35915.y = _13374.y;
                _35915.z = _13374.z;
                _35950 = _35915;
            }
            else
            {
                _35950 = _13342;
            }
            float4 _13151 = float4(_13110.x);
            _13394 = mix(mix(_35947, _35948, _13151), mix(_35949, _35950, _13151), float4(_13110.y));
            break;
        } while(false);
        _13619 = _13394;
        break;
    } while(false);
    float4 _35924 = _13619;
    _35924.w = 1.0;
    out._entryPointOutput = _35924;
    return out;
}
