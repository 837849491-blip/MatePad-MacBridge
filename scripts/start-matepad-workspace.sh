#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONTROL_APP="/Applications/MatePadControl.app"
CONTROL_PORT=18765
SIDESCREEN_PORT=54321

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Install with: brew install android-platform-tools"
  exit 1
fi

if ! adb devices | awk 'NR > 1 && $2 == "device" { found=1 } END { exit found ? 0 : 1 }'; then
  echo "MatePad not authorized. Unlock MatePad and allow USB debugging."
  exit 1
fi

if ! lsof -nP -iTCP:$CONTROL_PORT -sTCP:LISTEN >/dev/null 2>&1; then
  launchctl kickstart -k "gui/$(id -u)/com.ai-book.matepad-control" >/dev/null 2>&1 || open -gj "$CONTROL_APP"
fi

adb reverse tcp:$SIDESCREEN_PORT tcp:$SIDESCREEN_PORT >/dev/null
adb reverse tcp:$CONTROL_PORT tcp:$CONTROL_PORT >/dev/null

open /Applications/SideScreen.app
adb shell monkey -p com.sidescreen.app -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true

echo "MatePad workspace ready."
echo "Control panel: http://127.0.0.1:$CONTROL_PORT"
echo "SideScreen: open on MatePad and tap CONNECT if it is not already showing the Mac desktop."
