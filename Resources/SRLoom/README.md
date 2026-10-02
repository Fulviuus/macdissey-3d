# SR-Loom stereo shader source

Pinned source: [effcol/SR-Loom](https://github.com/effcol/SR-Loom/blob/d0b93f308d5aaf7c57fd02f5a3bd61402fe31f8b/src/shaders/Converter.hlsl).
`Converter.hlsl` is unchanged apart from the leading provenance comments.
MIT copyright 2026 SR Loom contributors; full license and additional
acknowledgements are in `../Licenses/SR-Loom-LICENSE.txt`.

The checked-in Metal programs in `../StereoShaders` are generated, not hand-edited:

```sh
python3 scripts/translate-stereo-shaders.py
```

Run from the repository with glslang and SPIRV-Cross on PATH. The translator uses
HLSL → optimized Vulkan 1.1 SPIR-V → Metal 3.0. Regular builds do not need these
tools. The runtime compiles the selected Metal pipelines before capture starts.

`StereoInputConverter.swift` supplies layout uniforms, typed texture bindings,
linear-light anaglyph processing, disparity pyramids and temporal history.
It skips upstream page/tint-region detection and change-region caching. Recovery
uses the per-pixel refine path rather than the optional full-width pair pass.
Frame-sequential assignment explicitly alternates eye phase; capture losses can
still invalidate parity. Calibration and the final optical weaver are unchanged.
