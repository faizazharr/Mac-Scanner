#!/bin/bash
# Double-click helper for users blocked by "Apple could not verify MacScanner
# is free of malware" on first launch. MacScanner isn't notarized (no paid
# Apple Developer Program enrollment yet — see ROADMAP.md), so macOS flags it
# the same way it flags any app downloaded via a browser. This just removes
# the quarantine flag the browser attached and reopens the app — it does not
# change how the app itself behaves.
set -e

APP_PATH="/Applications/MacScanner.app"
if [ ! -d "$APP_PATH" ]; then
    APP_PATH="$(cd "$(dirname "$0")" && pwd)/MacScanner.app"
fi

if [ ! -d "$APP_PATH" ]; then
    osascript -e 'display dialog "Could not find MacScanner.app. Drag it into Applications first, then run this again." buttons {"OK"} with icon caution'
    exit 1
fi

xattr -cr "$APP_PATH"
open "$APP_PATH"
