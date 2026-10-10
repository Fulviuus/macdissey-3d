#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/build-vision.py
python3 scripts/prepare-inference.py
python3 scripts/prepare-face-inference.py
for check in CoreChecks FactoryCalibrationChecks DisplayColorChecks DesktopCompositorChecks ConversionChecks DepthModelChecks; do
    swift run "$check"
done
swift run -c release StereoInputChecks
swift run -c release GLSurfaceChecks
sh scripts/check-app-settings.sh
sh scripts/check-depth-model-settings.sh
sh scripts/check-depth-map-resampling.sh
sh scripts/check-depth-inference-worker.sh
