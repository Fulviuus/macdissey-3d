#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/depth-map-checks
swiftc -parse-as-library Sources/OdysseyConversion/ConversionGPU.swift \
    Sources/OdysseyConversion/DepthMapResampler.swift Tests/DepthMapResamplingChecks/main.swift \
    -o .build/depth-map-checks/DepthMapResamplingChecks
.build/depth-map-checks/DepthMapResamplingChecks
