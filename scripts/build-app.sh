#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
assets="${MACDISSEY_ASSETS:-$PWD/.local-assets}"
for asset in Models/face.onnx Models/landmarks.tflite Weaver/vertex.glsl Weaver/fragment.glsl; do
    if [ ! -s "$assets/$asset" ]; then
        printf 'Missing private build asset: %s\nSee README.md for asset setup.\n' "$asset" >&2
        exit 1
    fi
done
python3 scripts/build-vision.py
python3 scripts/prepare-inference.py
python3 scripts/prepare-face-inference.py
python3 scripts/prepare-archive.py
sh scripts/build-icon.sh
swift build -c release --product OdysseyMenu
bundle="${1:-$PWD/dist/macdissey 3d.app}"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
mkdir -p "$bundle/Contents/Resources/Models" "$bundle/Contents/Resources/Weaver"
cp -f "$assets/Models/face.onnx" "$bundle/Contents/Resources/Models/face.onnx"
cp -f "$assets/Models/landmarks.tflite" "$bundle/Contents/Resources/Models/landmarks.tflite"
cp -f "$assets/Weaver/vertex.glsl" "$bundle/Contents/Resources/Weaver/vertex.glsl"
cp -f "$assets/Weaver/fragment.glsl" "$bundle/Contents/Resources/Weaver/fragment.glsl"
cp -f .build/release/OdysseyMenu "$bundle/Contents/MacOS/OdysseyMenu"
cp -f .tools/sevenzip-native/7zz "$bundle/Contents/MacOS/7zz"
cp -f Resources/AppIcon.icns "$bundle/Contents/Resources/AppIcon.icns"
cp -f Resources/MenuBarIcon.png "$bundle/Contents/Resources/MenuBarIcon.png"
cp -f Resources/Info.plist "$bundle/Contents/Info.plist"
cp -f THIRD_PARTY_NOTICES.md "$bundle/Contents/Resources/THIRD_PARTY_NOTICES.md"
mkdir -p "$bundle/Contents/Resources/Licenses"
cp -f Resources/Licenses/* "$bundle/Contents/Resources/Licenses/"
mkdir -p "$bundle/Contents/Resources/OpenCV-Licenses"
cp -f .tools/opencv43-install/share/licenses/opencv4/* "$bundle/Contents/Resources/OpenCV-Licenses/"
mkdir -p "$bundle/Contents/Frameworks" "$bundle/Contents/Resources/LiteRT-Licenses"
cp -f .tools/litert-native/lib/libLiteRt.dylib "$bundle/Contents/Frameworks/"
cp -f .tools/litert-native/licenses/* "$bundle/Contents/Resources/LiteRT-Licenses/"
cp -f .tools/onnx-native/lib/libonnxruntime.1.30.0.dylib "$bundle/Contents/Frameworks/libonnxruntime.1.dylib"
mkdir -p "$bundle/Contents/Resources/ONNX-Runtime-Licenses"
cp -f .tools/onnx-native/licenses/* "$bundle/Contents/Resources/ONNX-Runtime-Licenses/"
mkdir -p "$bundle/Contents/Resources/7-Zip-Licenses"
cp -f .tools/sevenzip-native/licenses/* "$bundle/Contents/Resources/7-Zip-Licenses/"
install_name_tool -delete_rpath "$PWD/.tools/litert-native/lib" "$bundle/Contents/MacOS/OdysseyMenu"
install_name_tool -delete_rpath "$PWD/.tools/onnx-native/lib" "$bundle/Contents/MacOS/OdysseyMenu"
codesign --force --sign - "$bundle/Contents/Frameworks/libLiteRt.dylib"
codesign --force --sign - "$bundle/Contents/Frameworks/libonnxruntime.1.dylib"
codesign --force --sign - "$bundle/Contents/MacOS/7zz"
codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"
printf '%s\n' "$bundle"
