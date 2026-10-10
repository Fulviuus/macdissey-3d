#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
bundle="${1:-$PWD/dist/Stereo Cube.app}"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
# Reuse the input enum/settings only, with no camera, vendor model or runtime dependencies.
swiftc -O -parse-as-library -target arm64-apple-macos14.0 \
    -file-prefix-map "$PWD=." \
    Sources/OdysseyConversion/StereoInput.swift Sources/StereoCube/*.swift \
    -o "$bundle/Contents/MacOS/StereoCube"
cp Resources/StereoCube/Cube.metal "$bundle/Contents/Resources/"
cp LICENSE "$bundle/Contents/Resources/"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>StereoCube</string>
<key>CFBundleIdentifier</key><string>io.github.fulviuus.macdissey.stereocube</string>
<key>CFBundleName</key><string>Stereo Cube</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$bundle"
codesign --verify --deep --strict "$bundle"
printf '%s\n' "$bundle"
