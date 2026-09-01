#!/bin/bash
# Builds MacScanner.app, a proper double-clickable macOS app bundle.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"

BIN_PATH=".build/$(swift build -c "$CONFIG" --show-bin-path | xargs basename)"
BIN_PATH=$(swift build -c "$CONFIG" --show-bin-path)/MacScanner

APP_DIR="build/MacScanner.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/MacScanner"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

# Sign with a real (Apple Development) identity, not ad-hoc. Two reasons:
# 1. Without ANY signature, RunningBoard/symptomsd treat this as a stray
#    background process and kill it outright on the first sustained-CPU scan.
# 2. Ad-hoc signatures (`--sign -`) are derived from the binary's own content,
#    so they change on every rebuild — macOS TCC treats each rebuild as a
#    "different app" and re-prompts for folder access every time. A real
#    identity's Team ID stays constant across rebuilds, so TCC grants persist.
SIGN_ID="Apple Development: faizazharr@gmail.com (X5AA45NR8V)"
if ! security find-identity -v -p codesigning | grep -qF "$SIGN_ID"; then
    echo "Signing identity not found, falling back to ad-hoc (TCC prompts may repeat on rebuild)."
    SIGN_ID="-"
fi
codesign --force --deep --timestamp=none --sign "$SIGN_ID" "$APP_DIR"

echo "Built: $APP_DIR"
