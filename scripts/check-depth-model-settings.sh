#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/settings-checks
swift build -c release --product DepthModelChecks
# Link only current sources; removed model implementations may leave stale .o files.
set --
for source in Sources/OdysseyConversion/*.swift; do
    set -- "$@" ".build/release/OdysseyConversion.build/$(basename "$source").o"
done
for source in Sources/OdysseyInference/*.cpp; do
    set -- "$@" ".build/release/OdysseyInference.build/$(basename "$source").o"
done
swiftc -parse-as-library -I .build/release/Modules \
    -Xcc -fmodule-map-file=.build/release/OdysseyInference.build/module.modulemap \
    Sources/OdysseyMenu/DepthModelsWindowController.swift Tests/DepthModelsLayoutChecks/main.swift \
    "$@" \
    -L .tools/onnx-native/lib -lonnxruntime -L .tools/litert-native/lib -lLiteRt -lc++ \
    -Xlinker -rpath -Xlinker "$PWD/.tools/onnx-native/lib" \
    -Xlinker -rpath -Xlinker "$PWD/.tools/litert-native/lib" \
    -o .build/settings-checks/DepthModelsLayoutChecks
.build/settings-checks/DepthModelsLayoutChecks .build/settings-checks/depth-models
