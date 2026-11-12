#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/direct-stereo
swiftc -parse-as-library Sources/DirectStereoDemo/DemoViewpoint.swift \
    Sources/DirectStereoDemo/DemoDiagnostics.swift \
    Tests/DirectStereoViewpointChecks/main.swift -o .build/direct-stereo/DirectStereoViewpointChecks
.build/direct-stereo/DirectStereoViewpointChecks
