#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="/Applications/MatePadControl.app"
BIN="$APP/Contents/MacOS/MatePadControl"
PLIST_SRC="$ROOT/launchd/com.ai-book.matepad-control.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.ai-book.matepad-control.plist"

mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/macos/Info.plist" "$APP/Contents/Info.plist"

clang -O2 -Wall \
  -framework ApplicationServices \
  -framework CoreGraphics \
  "$ROOT/src/matepad_control.c" \
  -o "$BIN"

codesign --force --deep --sign - "$APP" >/dev/null

mkdir -p "$HOME/Library/LaunchAgents"
cp "$PLIST_SRC" "$PLIST_DST"

launchctl bootout "gui/$(id -u)" "$PLIST_DST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"

echo "MatePadControl installed at $APP"
echo "Open System Settings > Privacy & Security > Accessibility, enable MatePadControl, then run:"
echo "curl http://127.0.0.1:18765/health"
