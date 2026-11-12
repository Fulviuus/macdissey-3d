#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/direct-stereo
swiftc -parse-as-library Sources/DirectStereoDemo/DemoRenderTargets.swift \
    Tests/DirectStereoCoverageChecks/main.swift -o .build/direct-stereo/DirectStereoCoverageChecks
.build/direct-stereo/DirectStereoCoverageChecks
