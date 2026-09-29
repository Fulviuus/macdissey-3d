#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/build-vision.py
python3 scripts/prepare-inference.py
python3 scripts/prepare-face-inference.py
for check in CoreChecks FactoryCalibrationChecks DisplayColorChecks DesktopCompositorChecks; do
    swift run "$check"
done
swift run -c release GLSurfaceChecks
sh scripts/check-app-settings.sh
