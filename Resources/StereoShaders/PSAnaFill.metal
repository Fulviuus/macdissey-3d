// Generated from SR-Loom Converter.hlsl (MIT). Copyright (c) 2026 SR Loom contributors.
// Upstream d0b93f308d5aaf7c57fd02f5a3bd61402fe31f8b. See Resources/Licenses/SR-Loom-LICENSE.txt.
// Regenerate with scripts/translate-stereo-shaders.py.
#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct Params
{
    char _m0_pad[52];
    float g_coarseW;
    char _m1_pad[80];
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

fragment main0_out main0(main0_in in [[stage_in]], constant Params& _78 [[buffer(0)]], texture2d<float> srcTex [[texture(0)]], texture2d<float> dispTex [[texture(1)]], sampler samp [[sampler(0)]])
{
    main0_out out = {};
    float4 _1430;
    do
    {
        float _545 = 1.0 / fast::max(_78.g_coarseW, 1.0);
        float _549 = _78.g_coarseW * 0.104166664183139801025390625;
        float4 _554 = dispTex.sample(samp, in.i_uv, level(0.0));
        float _563 = _554.x;
        float _576 = _554.y;
        float _598 = fast::clamp(1.0 - (fast::max(abs(_563 + dispTex.sample(samp, float2(in.i_uv.x + _563, in.i_uv.y), level(0.0)).y), abs(_576 + dispTex.sample(samp, float2(in.i_uv.x + _576, in.i_uv.y), level(0.0)).x)) * _549), 0.0, 1.0);
        if (_598 > 0.5)
        {
            _1430 = float4(_554.xy, _554.z * _598, _554.w * _598);
            break;
        }
        float _737;
        bool _738;
        float4 _1401;
        do
        {
            _737 = _78.g_srcDecode;
            _738 = _737 < 0.5;
            if (_738)
            {
                _1401 = srcTex.sample(samp, in.i_uv, level(0.0));
                break;
            }
            uint2 _748 = uint2(srcTex.get_width(), srcTex.get_height());
            uint _750 = _748.x;
            uint _752 = _748.y;
            float2 _761 = (in.i_uv * float2(float(_750), float(_752))) - float2(0.5);
            int2 _768 = int2(int(_750), int(_752)) - int2(1);
            float2 _770 = rint(_761);
            if (all(abs(_761 - _770) < float2(0.001953125)))
            {
                float4 _852 = srcTex.read(uint2(int3(clamp(int2(_770), int2(0), _768), 0).xy), 0);
                float4 _1941;
                if (_737 > 0.5)
                {
                    float3 _861 = fast::clamp(_852.xyz, float3(0.0), float3(1.0));
                    float3 _884 = select(powr((_861 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _861 * float3(0.077399380505084991455078125), _861 <= float3(0.040449999272823333740234375));
                    float4 _1789 = _852;
                    _1789.x = _884.x;
                    _1789.y = _884.y;
                    _1789.z = _884.z;
                    _1941 = _1789;
                }
                else
                {
                    _1941 = _852;
                }
                _1401 = _1941;
                break;
            }
            float2 _788 = fract(_761);
            int2 _791 = int2(floor(_761));
            int2 _793 = clamp(_791, int2(0), _768);
            int2 _800 = clamp(_791 + int2(1), int2(0), _768);
            int _802 = _793.x;
            float4 _894 = srcTex.read(uint2(int3(_802, _793.y, 0).xy), 0);
            bool _897 = _737 > 0.5;
            float4 _1937;
            if (_897)
            {
                float3 _903 = fast::clamp(_894.xyz, float3(0.0), float3(1.0));
                float3 _926 = select(powr((_903 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _903 * float3(0.077399380505084991455078125), _903 <= float3(0.040449999272823333740234375));
                float4 _1798 = _894;
                _1798.x = _926.x;
                _1798.y = _926.y;
                _1798.z = _926.z;
                _1937 = _1798;
            }
            else
            {
                _1937 = _894;
            }
            int _808 = _800.x;
            float4 _936 = srcTex.read(uint2(int3(_808, _793.y, 0).xy), 0);
            float4 _1938;
            if (_897)
            {
                float3 _945 = fast::clamp(_936.xyz, float3(0.0), float3(1.0));
                float3 _968 = select(powr((_945 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _945 * float3(0.077399380505084991455078125), _945 <= float3(0.040449999272823333740234375));
                float4 _1807 = _936;
                _1807.x = _968.x;
                _1807.y = _968.y;
                _1807.z = _968.z;
                _1938 = _1807;
            }
            else
            {
                _1938 = _936;
            }
            float4 _978 = srcTex.read(uint2(int3(_802, _800.y, 0).xy), 0);
            float4 _1939;
            if (_897)
            {
                float3 _987 = fast::clamp(_978.xyz, float3(0.0), float3(1.0));
                float3 _1010 = select(powr((_987 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _987 * float3(0.077399380505084991455078125), _987 <= float3(0.040449999272823333740234375));
                float4 _1816 = _978;
                _1816.x = _1010.x;
                _1816.y = _1010.y;
                _1816.z = _1010.z;
                _1939 = _1816;
            }
            else
            {
                _1939 = _978;
            }
            float4 _1020 = srcTex.read(uint2(int3(_808, _800.y, 0).xy), 0);
            float4 _1940;
            if (_897)
            {
                float3 _1029 = fast::clamp(_1020.xyz, float3(0.0), float3(1.0));
                float3 _1052 = select(powr((_1029 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _1029 * float3(0.077399380505084991455078125), _1029 <= float3(0.040449999272823333740234375));
                float4 _1825 = _1020;
                _1825.x = _1052.x;
                _1825.y = _1052.y;
                _1825.z = _1052.z;
                _1940 = _1825;
            }
            else
            {
                _1940 = _1020;
            }
            float4 _829 = float4(_788.x);
            _1401 = mix(mix(_1937, _1938, _829), mix(_1939, _1940, _829), float4(_788.y));
            break;
        } while(false);
        bool _1403;
        float2 _1404;
        _1404 = _554.xy;
        _1403 = false;
        float _1757;
        float2 _1758;
        bool _1759;
        int _1402 = 1;
        float _1416 = 1000000000.0;
        for (; _1402 <= 24; _1404 = _1758, _1403 = _1759, _1402++, _1416 = _1757)
        {
            float _633 = float(_1402);
            float _643 = in.i_uv.x + (_633 * _545);
            float2 _646 = float2(_643, in.i_uv.y);
            float4 _651 = dispTex.sample(samp, _646, level(0.0));
            float _654 = _651.x;
            bool _1432;
            float2 _1441;
            float _1451;
            if (fast::clamp(1.0 - (abs(_654 + dispTex.sample(samp, float2(_643 + _654, in.i_uv.y), level(0.0)).y) * _549), 0.0, 1.0) > 0.5)
            {
                float4 _1407;
                do
                {
                    if (_738)
                    {
                        _1407 = srcTex.sample(samp, _646, level(0.0));
                        break;
                    }
                    uint2 _1088 = uint2(srcTex.get_width(), srcTex.get_height());
                    uint _1090 = _1088.x;
                    uint _1092 = _1088.y;
                    float2 _1101 = (_646 * float2(float(_1090), float(_1092))) - float2(0.5);
                    int2 _1108 = int2(int(_1090), int(_1092)) - int2(1);
                    float2 _1110 = rint(_1101);
                    if (all(abs(_1101 - _1110) < float2(0.001953125)))
                    {
                        float4 _1192 = srcTex.read(uint2(int3(clamp(int2(_1110), int2(0), _1108), 0).xy), 0);
                        float4 _1955;
                        if (_737 > 0.5)
                        {
                            float3 _1201 = fast::clamp(_1192.xyz, float3(0.0), float3(1.0));
                            float3 _1224 = select(powr((_1201 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _1201 * float3(0.077399380505084991455078125), _1201 <= float3(0.040449999272823333740234375));
                            float4 _1841 = _1192;
                            _1841.x = _1224.x;
                            _1841.y = _1224.y;
                            _1841.z = _1224.z;
                            _1955 = _1841;
                        }
                        else
                        {
                            _1955 = _1192;
                        }
                        _1407 = _1955;
                        break;
                    }
                    float2 _1128 = fract(_1101);
                    int2 _1131 = int2(floor(_1101));
                    int2 _1133 = clamp(_1131, int2(0), _1108);
                    int2 _1140 = clamp(_1131 + int2(1), int2(0), _1108);
                    int _1142 = _1133.x;
                    float4 _1234 = srcTex.read(uint2(int3(_1142, _1133.y, 0).xy), 0);
                    bool _1237 = _737 > 0.5;
                    float4 _1942;
                    if (_1237)
                    {
                        float3 _1243 = fast::clamp(_1234.xyz, float3(0.0), float3(1.0));
                        float3 _1266 = select(powr((_1243 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _1243 * float3(0.077399380505084991455078125), _1243 <= float3(0.040449999272823333740234375));
                        float4 _1850 = _1234;
                        _1850.x = _1266.x;
                        _1850.y = _1266.y;
                        _1850.z = _1266.z;
                        _1942 = _1850;
                    }
                    else
                    {
                        _1942 = _1234;
                    }
                    int _1148 = _1140.x;
                    float4 _1276 = srcTex.read(uint2(int3(_1148, _1133.y, 0).xy), 0);
                    float4 _1945;
                    if (_1237)
                    {
                        float3 _1285 = fast::clamp(_1276.xyz, float3(0.0), float3(1.0));
                        float3 _1308 = select(powr((_1285 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _1285 * float3(0.077399380505084991455078125), _1285 <= float3(0.040449999272823333740234375));
                        float4 _1859 = _1276;
                        _1859.x = _1308.x;
                        _1859.y = _1308.y;
                        _1859.z = _1308.z;
                        _1945 = _1859;
                    }
                    else
                    {
                        _1945 = _1276;
                    }
                    float4 _1318 = srcTex.read(uint2(int3(_1142, _1140.y, 0).xy), 0);
                    float4 _1948;
                    if (_1237)
                    {
                        float3 _1327 = fast::clamp(_1318.xyz, float3(0.0), float3(1.0));
                        float3 _1350 = select(powr((_1327 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _1327 * float3(0.077399380505084991455078125), _1327 <= float3(0.040449999272823333740234375));
                        float4 _1868 = _1318;
                        _1868.x = _1350.x;
                        _1868.y = _1350.y;
                        _1868.z = _1350.z;
                        _1948 = _1868;
                    }
                    else
                    {
                        _1948 = _1318;
                    }
                    float4 _1360 = srcTex.read(uint2(int3(_1148, _1140.y, 0).xy), 0);
                    float4 _1950;
                    if (_1237)
                    {
                        float3 _1369 = fast::clamp(_1360.xyz, float3(0.0), float3(1.0));
                        float3 _1392 = select(powr((_1369 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _1369 * float3(0.077399380505084991455078125), _1369 <= float3(0.040449999272823333740234375));
                        float4 _1877 = _1360;
                        _1877.x = _1392.x;
                        _1877.y = _1392.y;
                        _1877.z = _1392.z;
                        _1950 = _1877;
                    }
                    else
                    {
                        _1950 = _1360;
                    }
                    float4 _1169 = float4(_1128.x);
                    _1407 = mix(mix(_1942, _1945, _1169), mix(_1948, _1950, _1169), float4(_1128.y));
                    break;
                } while(false);
                float _687 = distance(_1401.xyz, _1407.xyz) + (_633 * 0.0199999995529651641845703125);
                bool _690 = _687 < _1416;
                _1451 = _690 ? _687 : _1416;
                _1441 = select(_1404, _651.xy, bool2(_690));
                _1432 = _690 ? true : _1403;
            }
            else
            {
                _1451 = _1416;
                _1441 = _1404;
                _1432 = _1403;
            }
            float _1477 = in.i_uv.x + ((-_633) * _545);
            float2 _1480 = float2(_1477, in.i_uv.y);
            float4 _1484 = dispTex.sample(samp, _1480, level(0.0));
            float _1487 = _1484.x;
            if (fast::clamp(1.0 - (abs(_1487 + dispTex.sample(samp, float2(_1477 + _1487, in.i_uv.y), level(0.0)).y) * _549), 0.0, 1.0) > 0.5)
            {
                float4 _1744;
                do
                {
                    if (_738)
                    {
                        _1744 = srcTex.sample(samp, _1480, level(0.0));
                        break;
                    }
                    uint2 _1519 = uint2(srcTex.get_width(), srcTex.get_height());
                    uint _1521 = _1519.x;
                    uint _1523 = _1519.y;
                    float2 _1529 = (_1480 * float2(float(_1521), float(_1523))) - float2(0.5);
                    int2 _1534 = int2(int(_1521), int(_1523)) - int2(1);
                    float2 _1535 = rint(_1529);
                    if (all(abs(_1529 - _1535) < float2(0.001953125)))
                    {
                        float4 _1550 = srcTex.read(uint2(int3(clamp(int2(_1535), int2(0), _1534), 0).xy), 0);
                        float4 _1969;
                        if (_737 > 0.5)
                        {
                            float3 _1559 = fast::clamp(_1550.xyz, float3(0.0), float3(1.0));
                            float3 _1568 = select(powr((_1559 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _1559 * float3(0.077399380505084991455078125), _1559 <= float3(0.040449999272823333740234375));
                            float4 _1893 = _1550;
                            _1893.x = _1568.x;
                            _1893.y = _1568.y;
                            _1893.z = _1568.z;
                            _1969 = _1893;
                        }
                        else
                        {
                            _1969 = _1550;
                        }
                        _1744 = _1969;
                        break;
                    }
                    float2 _1578 = fract(_1529);
                    int2 _1580 = int2(floor(_1529));
                    int2 _1581 = clamp(_1580, int2(0), _1534);
                    int2 _1586 = clamp(_1580 + int2(1), int2(0), _1534);
                    int _1588 = _1581.x;
                    float4 _1596 = srcTex.read(uint2(int3(_1588, _1581.y, 0).xy), 0);
                    bool _1599 = _737 > 0.5;
                    float4 _1956;
                    if (_1599)
                    {
                        float3 _1605 = fast::clamp(_1596.xyz, float3(0.0), float3(1.0));
                        float3 _1614 = select(powr((_1605 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _1605 * float3(0.077399380505084991455078125), _1605 <= float3(0.040449999272823333740234375));
                        float4 _1902 = _1596;
                        _1902.x = _1614.x;
                        _1902.y = _1614.y;
                        _1902.z = _1614.z;
                        _1956 = _1902;
                    }
                    else
                    {
                        _1956 = _1596;
                    }
                    int _1624 = _1586.x;
                    float4 _1632 = srcTex.read(uint2(int3(_1624, _1581.y, 0).xy), 0);
                    float4 _1959;
                    if (_1599)
                    {
                        float3 _1641 = fast::clamp(_1632.xyz, float3(0.0), float3(1.0));
                        float3 _1650 = select(powr((_1641 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _1641 * float3(0.077399380505084991455078125), _1641 <= float3(0.040449999272823333740234375));
                        float4 _1911 = _1632;
                        _1911.x = _1650.x;
                        _1911.y = _1650.y;
                        _1911.z = _1650.z;
                        _1959 = _1911;
                    }
                    else
                    {
                        _1959 = _1632;
                    }
                    float4 _1668 = srcTex.read(uint2(int3(_1588, _1586.y, 0).xy), 0);
                    float4 _1962;
                    if (_1599)
                    {
                        float3 _1677 = fast::clamp(_1668.xyz, float3(0.0), float3(1.0));
                        float3 _1686 = select(powr((_1677 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _1677 * float3(0.077399380505084991455078125), _1677 <= float3(0.040449999272823333740234375));
                        float4 _1920 = _1668;
                        _1920.x = _1686.x;
                        _1920.y = _1686.y;
                        _1920.z = _1686.z;
                        _1962 = _1920;
                    }
                    else
                    {
                        _1962 = _1668;
                    }
                    float4 _1704 = srcTex.read(uint2(int3(_1624, _1586.y, 0).xy), 0);
                    float4 _1964;
                    if (_1599)
                    {
                        float3 _1713 = fast::clamp(_1704.xyz, float3(0.0), float3(1.0));
                        float3 _1722 = select(powr((_1713 + float3(0.054999999701976776123046875)) * float3(0.947867333889007568359375), float3(2.400000095367431640625)), _1713 * float3(0.077399380505084991455078125), _1713 <= float3(0.040449999272823333740234375));
                        float4 _1929 = _1704;
                        _1929.x = _1722.x;
                        _1929.y = _1722.y;
                        _1929.z = _1722.z;
                        _1964 = _1929;
                    }
                    else
                    {
                        _1964 = _1704;
                    }
                    float4 _1733 = float4(_1578.x);
                    _1744 = mix(mix(_1956, _1959, _1733), mix(_1962, _1964, _1733), float4(_1578.y));
                    break;
                } while(false);
                float _1749 = distance(_1401.xyz, _1744.xyz) + (_633 * 0.0199999995529651641845703125);
                bool _1750 = _1749 < _1451;
                _1757 = _1750 ? _1749 : _1451;
                _1758 = select(_1441, _1484.xy, bool2(_1750));
                _1759 = _1750 ? true : _1432;
            }
            else
            {
                _1757 = _1451;
                _1758 = _1441;
                _1759 = _1432;
            }
        }
        float _705 = _1403 ? 0.4000000059604644775390625 : 0.20000000298023223876953125;
        _1430 = float4(_1404, _705, _705);
        break;
    } while(false);
    out._entryPointOutput = _1430;
    return out;
}
