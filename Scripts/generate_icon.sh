#!/bin/bash
# Regenerates Resources/AppIcon.icns from Scripts/generate_icon.swift.
# Only needs to be rerun if the icon design changes.
set -euo pipefail

cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

swift Scripts/generate_icon.swift "$TMP/icon_1024.png"

mkdir -p "$TMP/AppIcon.iconset"
sips -z 16 16     "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_16x16.png" > /dev/null
sips -z 32 32     "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_32x32.png" > /dev/null
sips -z 64 64     "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_128x128.png" > /dev/null
sips -z 256 256   "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_256x256.png" > /dev/null
sips -z 512 512   "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_512x512.png" > /dev/null
cp "$TMP/icon_1024.png" "$TMP/AppIcon.iconset/icon_512x512@2x.png"

iconutil -c icns "$TMP/AppIcon.iconset" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
