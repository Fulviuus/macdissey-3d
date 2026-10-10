#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/depth-map-checks
swiftc -parse-as-library Sources/OdysseyConversion/DepthInferenceWorker.swift \
    Sources/OdysseyConversion/DepthRuntimeCache.swift \
    Sources/OdysseyConversion/VideoSceneDetector.swift \
    Sources/OdysseyConversion/ConversionFrameDelivery.swift \
    Tests/DepthInferenceWorkerChecks/main.swift Tests/DepthInferenceWorkerChecks/SceneChecks.swift -o .build/depth-map-checks/DepthInferenceWorkerChecks
.build/depth-map-checks/DepthInferenceWorkerChecks
