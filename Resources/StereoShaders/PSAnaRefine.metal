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
    char _m1_pad[68];
    float g_lvlToSrcX;
};

struct main0_out
{
    float4 _entryPointOutput [[color(0)]];
};

struct main0_in
{
    float2 i_uv [[user(locn0)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant Params& _290 [[buffer(0)]], texture2d<uint> descTexA [[texture(0)]], texture2d<uint> descTexB [[texture(1)]], texture2d<uint> descTexC [[texture(2)]], texture2d<uint> descTexD [[texture(3)]], texture2d<float> dispTex [[texture(4)]], sampler samp [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float _651 = 1.0 / fast::max(_290.g_coarseW, 1.0);
    int2 _655 = int2(gl_FragCoord.xy);
    int _658 = int(_290.g_coarseW);
    float4 _663 = dispTex.sample(samp, in.i_uv, level(0.0));
    float _668 = float(_658) / _290.g_lvlToSrcX;
    int _877 = _655.x;
    int _878 = _655.y;
    int2 _880 = int3(_877, _878, 0).xy;
    uint4 _886 = descTexA.read(uint2(_880), 0);
    uint _925 = _886.x;
    float2 _926 = float2(as_type<half2>(_925));
    float _927 = _926.x;
    float2 _932 = float2(as_type<half2>(_925 >> uint(16)));
    float _933 = _932.x;
    uint _936 = _886.y;
    float2 _937 = float2(as_type<half2>(_936));
    float _938 = _937.x;
    float2 _943 = float2(as_type<half2>(_936 >> uint(16)));
    float _944 = _943.x;
    uint _947 = _886.z;
    float2 _948 = float2(as_type<half2>(_947));
    float _949 = _948.x;
    float2 _954 = float2(as_type<half2>(_947 >> uint(16)));
    float _955 = _954.x;
    uint _958 = _886.w;
    float2 _959 = float2(as_type<half2>(_958));
    float _960 = _959.x;
    float2 _965 = float2(as_type<half2>(_958 >> uint(16)));
    float _966 = _965.x;
    uint4 _900 = descTexB.read(uint2(_880), 0);
    uint _970 = _900.x;
    float2 _971 = float2(as_type<half2>(_970));
    float _972 = _971.x;
    float2 _977 = float2(as_type<half2>(_970 >> uint(16)));
    float _978 = _977.x;
    uint _981 = _900.y;
    float2 _982 = float2(as_type<half2>(_981));
    float _983 = _982.x;
    float2 _988 = float2(as_type<half2>(_981 >> uint(16)));
    float _989 = _988.x;
    uint _992 = _900.z;
    float2 _993 = float2(as_type<half2>(_992));
    float _994 = _993.x;
    float2 _999 = float2(as_type<half2>(_992 >> uint(16)));
    float _1000 = _999.x;
    uint _1003 = _900.w;
    float2 _1004 = float2(as_type<half2>(_1003));
    float _1005 = _1004.x;
    float2 _1010 = float2(as_type<half2>(_1003 >> uint(16)));
    float _1011 = _1010.x;
    uint4 _1032 = descTexC.read(uint2(_880), 0);
    uint _1071 = _1032.x;
    float2 _1072 = float2(as_type<half2>(_1071));
    float _1073 = _1072.x;
    float2 _1078 = float2(as_type<half2>(_1071 >> uint(16)));
    float _1079 = _1078.x;
    uint _1082 = _1032.y;
    float2 _1083 = float2(as_type<half2>(_1082));
    float _1084 = _1083.x;
    float2 _1089 = float2(as_type<half2>(_1082 >> uint(16)));
    float _1090 = _1089.x;
    uint _1093 = _1032.z;
    float2 _1094 = float2(as_type<half2>(_1093));
    float _1095 = _1094.x;
    float2 _1100 = float2(as_type<half2>(_1093 >> uint(16)));
    float _1101 = _1100.x;
    uint _1104 = _1032.w;
    float2 _1105 = float2(as_type<half2>(_1104));
    float _1106 = _1105.x;
    float2 _1111 = float2(as_type<half2>(_1104 >> uint(16)));
    float _1112 = _1111.x;
    uint4 _1046 = descTexD.read(uint2(_880), 0);
    uint _1116 = _1046.x;
    float2 _1117 = float2(as_type<half2>(_1116));
    float _1118 = _1117.x;
    float2 _1123 = float2(as_type<half2>(_1116 >> uint(16)));
    float _1124 = _1123.x;
    uint _1127 = _1046.y;
    float2 _1128 = float2(as_type<half2>(_1127));
    float _1129 = _1128.x;
    float2 _1134 = float2(as_type<half2>(_1127 >> uint(16)));
    float _1135 = _1134.x;
    uint _1138 = _1046.z;
    float2 _1139 = float2(as_type<half2>(_1138));
    float _1140 = _1139.x;
    float2 _1145 = float2(as_type<half2>(_1138 >> uint(16)));
    float _1146 = _1145.x;
    uint _1149 = _1046.w;
    float2 _1150 = float2(as_type<half2>(_1149));
    float _1151 = _1150.x;
    float2 _1156 = float2(as_type<half2>(_1149 >> uint(16)));
    float _1157 = _1156.x;
    uint2 _676 = uint2(dispTex.get_width(), dispTex.get_height());
    uint _678 = _676.x;
    uint _680 = _676.y;
    int2 _691 = int2(floor((in.i_uv * float2(float(_678), float(_680))) - float2(0.5)));
    float _1705;
    float _1706;
    _1706 = _663.y;
    _1705 = _663.x;
    float _1728;
    float _1738;
    float _1743;
    float _1751;
    int _1704 = 0;
    float _1730 = 1000000000.0;
    float _1740 = 1000000000.0;
    for (; _1704 < 5; _1706 = _1751, _1705 = _1743, _1704++, _1740 = _1738, _1730 = _1728)
    {
        bool _704 = _1704 > 0;
        float2 _3396;
        if (_704)
        {
            int _708 = _1704 - 1;
            _3396 = dispTex.read(uint2(int3(clamp(_691 + int2(_708 & 1, _708 >> 1), int2(0), int2(int(_678 - 1u), int(_680 - 1u))), 0).xy), 0).xy;
        }
        else
        {
            _3396 = _663.xy;
        }
        int _743 = int(rint(_3396.x * _290.g_coarseW));
        int _750 = int(rint(_3396.y * _290.g_coarseW));
        int _753 = (_1704 == 0) ? 6 : 2;
        int _755 = -_753;
        _1738 = _1740;
        _1728 = _1730;
        _1751 = _1706;
        _1743 = _1705;
        float _3317;
        float _3318;
        float _1746;
        float _1753;
        for (int _1708 = _755; _1708 <= _753; _1738 = _3318, _1728 = _3317, _1708++, _1751 = _1753, _1743 = _1746)
        {
            int _767 = (_877 + _743) + _1708;
            int _773 = (_877 + _750) + _1708;
            int _776 = _658 - 1;
            int2 _1172 = int3(clamp(_767, 0, _776), _878, 0).xy;
            uint4 _1178 = descTexC.read(uint2(_1172), 0);
            uint _1217 = _1178.x;
            float2 _1218 = float2(as_type<half2>(_1217));
            float _1219 = _1218.x;
            float2 _1224 = float2(as_type<half2>(_1217 >> uint(16)));
            float _1225 = _1224.x;
            uint _1228 = _1178.y;
            float2 _1229 = float2(as_type<half2>(_1228));
            float _1230 = _1229.x;
            float2 _1235 = float2(as_type<half2>(_1228 >> uint(16)));
            float _1236 = _1235.x;
            uint _1239 = _1178.z;
            float2 _1240 = float2(as_type<half2>(_1239));
            float _1241 = _1240.x;
            float2 _1246 = float2(as_type<half2>(_1239 >> uint(16)));
            float _1247 = _1246.x;
            uint _1250 = _1178.w;
            float2 _1251 = float2(as_type<half2>(_1250));
            float _1252 = _1251.x;
            float2 _1257 = float2(as_type<half2>(_1250 >> uint(16)));
            float _1258 = _1257.x;
            uint4 _1192 = descTexD.read(uint2(_1172), 0);
            uint _1262 = _1192.x;
            float2 _1263 = float2(as_type<half2>(_1262));
            float _1264 = _1263.x;
            float2 _1269 = float2(as_type<half2>(_1262 >> uint(16)));
            float _1270 = _1269.x;
            uint _1273 = _1192.y;
            float2 _1274 = float2(as_type<half2>(_1273));
            float _1275 = _1274.x;
            float2 _1280 = float2(as_type<half2>(_1273 >> uint(16)));
            float _1281 = _1280.x;
            uint _1284 = _1192.z;
            float2 _1285 = float2(as_type<half2>(_1284));
            float _1286 = _1285.x;
            float2 _1291 = float2(as_type<half2>(_1284 >> uint(16)));
            float _1292 = _1291.x;
            uint _1295 = _1192.w;
            float2 _1296 = float2(as_type<half2>(_1295));
            float _1297 = _1296.x;
            float2 _1302 = float2(as_type<half2>(_1295 >> uint(16)));
            float _1303 = _1302.x;
            int2 _1318 = int3(clamp(_773, 0, _776), _878, 0).xy;
            uint4 _1324 = descTexA.read(uint2(_1318), 0);
            uint _1363 = _1324.x;
            float2 _1364 = float2(as_type<half2>(_1363));
            float _1365 = _1364.x;
            float2 _1370 = float2(as_type<half2>(_1363 >> uint(16)));
            float _1371 = _1370.x;
            uint _1374 = _1324.y;
            float2 _1375 = float2(as_type<half2>(_1374));
            float _1376 = _1375.x;
            float2 _1381 = float2(as_type<half2>(_1374 >> uint(16)));
            float _1382 = _1381.x;
            uint _1385 = _1324.z;
            float2 _1386 = float2(as_type<half2>(_1385));
            float _1387 = _1386.x;
            float2 _1392 = float2(as_type<half2>(_1385 >> uint(16)));
            float _1393 = _1392.x;
            uint _1396 = _1324.w;
            float2 _1397 = float2(as_type<half2>(_1396));
            float _1398 = _1397.x;
            float2 _1403 = float2(as_type<half2>(_1396 >> uint(16)));
            float _1404 = _1403.x;
            uint4 _1338 = descTexB.read(uint2(_1318), 0);
            uint _1408 = _1338.x;
            float2 _1409 = float2(as_type<half2>(_1408));
            float _1410 = _1409.x;
            float2 _1415 = float2(as_type<half2>(_1408 >> uint(16)));
            float _1416 = _1415.x;
            uint _1419 = _1338.y;
            float2 _1420 = float2(as_type<half2>(_1419));
            float _1421 = _1420.x;
            float2 _1426 = float2(as_type<half2>(_1419 >> uint(16)));
            float _1427 = _1426.x;
            uint _1430 = _1338.z;
            float2 _1431 = float2(as_type<half2>(_1430));
            float _1432 = _1431.x;
            float2 _1437 = float2(as_type<half2>(_1430 >> uint(16)));
            float _1438 = _1437.x;
            uint _1441 = _1338.w;
            float2 _1442 = float2(as_type<half2>(_1441));
            float _1443 = _1442.x;
            float2 _1448 = float2(as_type<half2>(_1441 >> uint(16)));
            float _1449 = _1448.x;
            float _801 = (abs(float(_1708)) + float(_704)) * 0.00200000009499490261077880859375;
            float _2307 = (((((((((((((abs(_927 - _1219) + abs(_933 - _1225)) + abs(_938 - _1230)) + abs(_944 - _1236)) + abs(_949 - _1241)) + abs(_955 - _1247)) + abs(_960 - _1252)) + abs(_966 - _1258)) + abs(_972 - _1264)) + abs(_978 - _1270)) + abs(_983 - _1275)) + abs(_989 - _1281)) + abs(_994 - _1286)) + abs(_1000 - _1292)) + abs(_1005 - _1297);
            float _2336 = ((((((((((((((abs(_927) + abs(_933)) + abs(_938)) + abs(_944)) + abs(_949)) + abs(_955)) + abs(_960)) + abs(_966)) + abs(_972)) + abs(_978)) + abs(_983)) + abs(_989)) + abs(_994)) + abs(_1000)) + abs(_1005)) + abs(_1011);
            float _2340 = ((((((((((((((abs(_1219) + abs(_1225)) + abs(_1230)) + abs(_1236)) + abs(_1241)) + abs(_1247)) + abs(_1252)) + abs(_1258)) + abs(_1264)) + abs(_1270)) + abs(_1275)) + abs(_1281)) + abs(_1286)) + abs(_1292)) + abs(_1297)) + abs(_1303);
            float _806 = mix(0.4000000059604644775390625, (_2307 + abs(_1011 - _1303)) / ((_2336 + _2340) + 0.1500000059604644775390625), fast::clamp(fast::min(_2336, _2340) * 1.66666662693023681640625, 0.0, 1.0)) + _801;
            float _2682 = (((((((((((((abs(_1073 - _1365) + abs(_1079 - _1371)) + abs(_1084 - _1376)) + abs(_1090 - _1382)) + abs(_1095 - _1387)) + abs(_1101 - _1393)) + abs(_1106 - _1398)) + abs(_1112 - _1404)) + abs(_1118 - _1410)) + abs(_1124 - _1416)) + abs(_1129 - _1421)) + abs(_1135 - _1427)) + abs(_1140 - _1432)) + abs(_1146 - _1438)) + abs(_1151 - _1443);
            float _2711 = ((((((((((((((abs(_1073) + abs(_1079)) + abs(_1084)) + abs(_1090)) + abs(_1095)) + abs(_1101)) + abs(_1106)) + abs(_1112)) + abs(_1118)) + abs(_1124)) + abs(_1129)) + abs(_1135)) + abs(_1140)) + abs(_1146)) + abs(_1151)) + abs(_1157);
            float _2715 = ((((((((((((((abs(_1365) + abs(_1371)) + abs(_1376)) + abs(_1382)) + abs(_1387)) + abs(_1393)) + abs(_1398)) + abs(_1404)) + abs(_1410)) + abs(_1416)) + abs(_1421)) + abs(_1427)) + abs(_1432)) + abs(_1438)) + abs(_1443)) + abs(_1449);
            float _811 = mix(0.4000000059604644775390625, (_2682 + abs(_1157 - _1449)) / ((_2711 + _2715) + 0.1500000059604644775390625), fast::clamp(fast::min(_2711, _2715) * 1.66666662693023681640625, 0.0, 1.0)) + _801;
            bool _822 = ((_806 < _1728) && (_767 >= 0)) && (float(_767) < _668);
            if (_822)
            {
                _1746 = float(_743 + _1708) * _651;
            }
            else
            {
                _1746 = _1743;
            }
            _3317 = _822 ? _806 : _1728;
            bool _842 = ((_811 < _1738) && (_773 >= 0)) && (float(_773) < _668);
            if (_842)
            {
                _1753 = float(_750 + _1708) * _651;
            }
            else
            {
                _1753 = _1751;
            }
            _3318 = _842 ? _811 : _1738;
        }
    }
    out._entryPointOutput = float4(_1705, _1706, _663.zw);
    return out;
}
