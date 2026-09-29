#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
source="Resources/Artwork/AppIcon.png"
iconset=".build/Macdissey.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    doubled=$((size * 2))
    sips -z "$size" "$size" "$source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -z "$doubled" "$doubled" "$source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Resources/AppIcon.icns
sips -z 64 64 Resources/Artwork/MenuBarIcon.png --out Resources/MenuBarIcon.png >/dev/null
