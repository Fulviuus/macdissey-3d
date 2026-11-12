#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/build-vision.py
python3 scripts/prepare-inference.py
python3 scripts/prepare-face-inference.py
for check in CoreChecks FactoryCalibrationChecks DisplayColorChecks DesktopCompositorChecks ConversionChecks DepthModelChecks; do
    swift run --build-system native "$check"
done
swift run --build-system native -c release StereoInputChecks
swift run --build-system native -c release GLSurfaceChecks
swift run --build-system native DirectStereoChecks
swift run --build-system native StereoViewTrackingChecks
swift build --build-system native --product DirectStereoDemo
sh scripts/check-direct-stereo-viewpoint.sh
sh scripts/check-direct-stereo-coverage.sh
.build/debug/DirectStereoChecks --demo .build/debug/DirectStereoDemo
sh scripts/check-app-settings.sh
sh scripts/check-depth-model-settings.sh
sh scripts/check-depth-map-resampling.sh
sh scripts/check-depth-inference-worker.sh
