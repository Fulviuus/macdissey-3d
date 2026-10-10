# Third-party notices

The project’s MIT license covers its original source code. It does not replace
the licenses of the components below or license recovered vendor assets.

## SR-Loom stereo input conversion

`Resources/SRLoom/Converter.hlsl` is from
[effcol/SR-Loom](https://github.com/effcol/SR-Loom/tree/d0b93f308d5aaf7c57fd02f5a3bd61402fe31f8b),
commit `d0b93f308d5aaf7c57fd02f5a3bd61402fe31f8b`, copyright (c) 2026
SR Loom contributors, MIT license. `Resources/StereoShaders` contains Metal
translations produced by glslang and SPIRV-Cross. The native host adapts its
layout conversion and anaglyph recovery pipeline. This open-source shader code
is distinct from the recovered Samsung/Leia vendor assets.

The full upstream license and attribution, including its frame-packing
3DToElse/NTM-3D acknowledgement, are in `Resources/Licenses/SR-Loom-LICENSE.txt`
and bundled in the application. See `Resources/SRLoom/README.md` for regeneration.

## ONNX Runtime 1.30.0 and detector ordering

Face inference and monocular video-depth inference use ONNX Runtime 1.30.0,
under the MIT license. Video conversion also uses Apple's system Core ML framework.
Its license and bundled dependency notices are included in the application at
`Contents/Resources/ONNX-Runtime-Licenses/`.

`DetectionOrder.h` adapts the Microsoft C++ Standard Library sorting algorithm
from tag `vs-2019-16.6`, with simplified iterator plumbing and heap operations
checked against the original Blink binary. Copyright (c) Microsoft Corporation,
Apache-2.0 WITH LLVM-exception. The full license is in
`Resources/Licenses/Microsoft-STL-LICENSE.txt` and is copied into the app.
Source: https://github.com/microsoft/STL/tree/vs-2019-16.6

## OpenCV 4.3.0

EyeGeometry.swift follows the arithmetic of the Rodrigues and inverse-distortion
functions in OpenCV 4.3.0. The applicable OpenCV license follows.

By downloading, copying, installing or using the software you agree to this license.
If you do not agree to this license, do not download, install,
copy or use the software.


                          License Agreement
               For Open Source Computer Vision Library
                       (3-clause BSD License)

Copyright (C) 2000-2020, Intel Corporation, all rights reserved.
Copyright (C) 2009-2011, Willow Garage Inc., all rights reserved.
Copyright (C) 2009-2016, NVIDIA Corporation, all rights reserved.
Copyright (C) 2010-2013, Advanced Micro Devices, Inc., all rights reserved.
Copyright (C) 2015-2016, OpenCV Foundation, all rights reserved.
Copyright (C) 2015-2016, Itseez Inc., all rights reserved.
Copyright (C) 2019-2020, Xperience AI, all rights reserved.
Third party copyrights are property of their respective owners.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

  * Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

  * Neither the names of the copyright holders nor the names of the contributors
    may be used to endorse or promote products derived from this software
    without specific prior written permission.

This software is provided by the copyright holders and contributors "as is" and
any express or implied warranties, including, but not limited to, the implied
warranties of merchantability and fitness for a particular purpose are disclaimed.
In no event shall copyright holders or contributors be liable for any direct,
indirect, incidental, special, exemplary, or consequential damages
(including, but not limited to, procurement of substitute goods or services;
loss of use, data, or profits; or business interruption) however caused
and on any theory of liability, whether in contract, strict liability,
or tort (including negligence or otherwise) arising in any way out of
the use of this software, even if advised of the possibility of such damage.

## LiteRT 2.2.0

The native landmark inference backend links Google's LiteRT CPU runtime,
including its XNNPACK delegate. LiteRT is licensed under the Apache License,
Version 2.0. The complete license is included in
`Contents/Resources/LiteRT-Licenses/LiteRT-LICENSE` in the application bundle.
The C API headers are obtained from the original versioned SDK, and the native
macOS library is extracted from the hash-pinned official Python distribution;
no Python interpreter or Python extension is included in the application.

Sources: https://github.com/google-ai-edge/LiteRT/releases/tag/v2.2.0
and https://pypi.org/project/ai-edge-litert/2.2.0/.
The private local build copies the recovered vendor face and landmark weights
and the original GLSL shaders from the user's installation into its Resources.
These vendor assets are not covered by the open-source runtime licenses above.
The source repository does not contain those weights or shader resources.

Experimental 2D conversion uses recovered Samsung Player 1.5.0 depth weights,
sampling data, and conversion shader programs translated for Metal. These vendor
resources likewise retain their own terms and are excluded from the project's
MIT license and source repository. Core ML compilation caches stay on the user's
Mac and are not bundled.
## Native archive helper

The local application bundle includes the separately executed 7-Zip 26.03
helper, Copyright (C) 1999–2026 Igor Pavlov. Its license and third-party notices
are bundled under `Contents/Resources/7-Zip-Licenses`. The exact upstream source
archive is [7z2603-src.tar.xz](https://github.com/ip7z/7zip/releases/download/26.03/7z2603-src.tar.xz),
SHA256 `9cbde5099c6deb73691b0579063da5827522ccbbcba3f0020fd04e8c8c16c0d4`.
The unmodified helper comes from Homebrew's `sevenzip` formula and can be
replaced independently of the Swift application. The archive helper is used
only for the three factory optical calibration files.

## Bundled Video Depth Anything Small

The application bundles Video Depth Anything Small as two compiled FP16 Core ML
programs. Learned weights and generated programs are not stored in this source
repository. `scripts/prepare-video-depth.py` pins and verifies the public checkpoint:

- Source: https://huggingface.co/AEmotionStudio/Video-Depth-Anything-Small
- Revision: `50aafe6478a8932fd1380df4847feb009962afad`
- SHA-256: `85c583474dcafda4d417776431343afcdfdfc97952d8ec00029d3452c55a05a2`
- Weight license: Apache 2.0, separate from the application's MIT license.

The safetensors checkpoint is a conversion of the original Depth Anything model:
https://huggingface.co/depth-anything/Video-Depth-Anything-Small.
The architecture and streaming cache algorithm are adapted from
https://github.com/DepthAnything/Video-Depth-Anything at commit
`4f5ae23172ba60fd7bc11ef671cca678842c7072`, Copyright (2025) Bytedance Ltd. and/or
its affiliates, Apache-2.0. Its motion modules derive from AnimateDiff
(Apache-2.0). Modifications: fixed 518 × 294 inference, precomputed upstream
position embeddings, FP16 Core ML operations and history tensors, native Swift
streaming, and separately compiled first-frame/recurrent programs.

The full license is in `Resources/Licenses/Video-Depth-Anything-LICENSE.txt`, copied
into the application. The developer export uses coremltools 9.0 (BSD-3-Clause)
and PyTorch 2.7.0 (BSD-style license); neither is distributed with the app.
No recovered Samsung model or shader is stored in these source files.

Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
