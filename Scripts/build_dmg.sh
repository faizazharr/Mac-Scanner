#!/bin/bash
# Builds MacScanner.dmg, a drag-and-drop installer disk image for macOS.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"

echo "==> Building MacScanner.app ($CONFIG)..."
./Scripts/build_app.sh "$CONFIG"

APP_PATH="build/MacScanner.app"
DMG_PATH="build/MacScanner.dmg"
STAGING_DIR="build/dmg_staging"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found."
    exit 1
fi

echo "==> Creating DMG staging directory..."
hdiutil detach /Volumes/MacScanner 2>/dev/null || true
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copy the app bundle
cp -R "$APP_PATH" "$STAGING_DIR/MacScanner.app"

# Create drag-and-drop symlink to /Applications
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Packaging MacScanner.dmg..."
hdiutil create \
    -volname "MacScanner" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Code sign the DMG if an identity is available
SIGN_ID="Apple Development: faizazharr@gmail.com (X5AA45NR8V)"
if security find-identity -v -p codesigning | grep -qF "$SIGN_ID"; then
    echo "==> Code signing MacScanner.dmg..."
    codesign --force --timestamp=none --sign "$SIGN_ID" "$DMG_PATH"
fi

rm -rf "$STAGING_DIR"

echo "========================================="
echo "✅ DMG Installer successfully built:"
echo "   $DMG_PATH"
echo "========================================="
