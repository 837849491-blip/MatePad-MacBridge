#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="MatePad MacBridge"
GITHUB_REPO="837849491-blip/MatePad-MacBridge"
RAW_INSTALL_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh"
TARBALL_URL="https://github.com/$GITHUB_REPO/archive/refs/heads/main.tar.gz"
SIDESCREEN_REPO="https://github.com/tranvuongquocdat/SideScreen"
SIDESCREEN_TAG="0.9.1"

INSTALL_HOME="${MATEPAD_MACBRIDGE_HOME:-$HOME/.matepad-macbridge}"
INSTALL_REPO="$INSTALL_HOME/MatePad-MacBridge"
BIN_DIR="$INSTALL_HOME/bin"
START_CMD="$BIN_DIR/matepad-macbridge-start"
BUILD_DIR="$INSTALL_HOME/build"

DRY_RUN=0
ANDROID_BUILD=0
START_AFTER=1
REPO_DIR_ARG=""
ARGS=()

usage() {
  cat <<EOF
$PROJECT_NAME installer

Usage:
  curl -fsSL $RAW_INSTALL_URL | bash
  curl -fsSL $RAW_INSTALL_URL | bash -s -- --with-android-build

Options:
  --with-android-build   Also try to build and install the patched SideScreen Android client.
  --skip-android-build   Install only the Mac bridge and start helper. This is the default.
  --no-start             Do not start SideScreen/ADB reverse after installation.
  --dry-run              Print planned actions without changing the system.
  --repo-dir PATH        Use an already-downloaded repository directory.
  -h, --help             Show this help.

Daily start command after install:
  $START_CMD
EOF
}

log() {
  printf '\n==> %s\n' "$*"
}

note() {
  printf '    %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'DRY-RUN:'
    local arg
    for arg in "$@"; do
      printf ' %s' "$arg"
    done
    printf '\n'
  else
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-android-build)
      ANDROID_BUILD=1
      ARGS+=("$1")
      shift
      ;;
    --skip-android-build)
      ANDROID_BUILD=0
      ARGS+=("$1")
      shift
      ;;
    --no-start)
      START_AFTER=0
      ARGS+=("$1")
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      ARGS+=("$1")
      shift
      ;;
    --repo-dir)
      [[ $# -ge 2 ]] || { warn "--repo-dir requires a path"; exit 2; }
      REPO_DIR_ARG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      warn "Unknown option: $1"
      usage
      exit 2
      ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${REPO_DIR_ARG:-$script_dir}"

is_repo_root() {
  local dir="$1"
  [[ -f "$dir/src/matepad_control.c" ]] &&
    [[ -f "$dir/scripts/install-mac-bridge.sh" ]] &&
    [[ -f "$dir/scripts/start-matepad-workspace.sh" ]]
}

bootstrap_from_github() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: download $TARBALL_URL"
    echo "DRY-RUN: extract repository and rerun install.sh"
    exit 0
  fi

  command -v curl >/dev/null 2>&1 || { warn "curl is required"; exit 1; }
  command -v tar >/dev/null 2>&1 || { warn "tar is required"; exit 1; }

  local tmp repo_dir
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/matepad-macbridge.XXXXXX")"
  log "Downloading $PROJECT_NAME"
  curl -fsSL "$TARBALL_URL" -o "$tmp/source.tar.gz"
  tar -xzf "$tmp/source.tar.gz" -C "$tmp"
  repo_dir="$(find "$tmp" -maxdepth 1 -type d -name 'MatePad-MacBridge-*' | head -n 1)"
  [[ -n "$repo_dir" ]] || { warn "Could not unpack repository"; exit 1; }
  exec bash "$repo_dir/install.sh" --repo-dir "$repo_dir" "${ARGS[@]}"
}

if ! is_repo_root "$ROOT"; then
  bootstrap_from_github
fi

copy_project_to_install_home() {
  log "Installing project files"
  note "Target: $INSTALL_REPO"

  local root_real install_repo_real
  root_real="$(cd "$ROOT" && pwd -P)"
  install_repo_real="$INSTALL_REPO"
  if [[ -d "$INSTALL_REPO" ]]; then
    install_repo_real="$(cd "$INSTALL_REPO" && pwd -P)"
  fi

  if [[ "$root_real" == "$install_repo_real" ]]; then
    note "Project files are already in the install directory."
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: copy repository files to $INSTALL_REPO"
    return
  fi

  rm -rf "$INSTALL_REPO.tmp"
  mkdir -p "$INSTALL_REPO.tmp"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude '.git' "$ROOT/" "$INSTALL_REPO.tmp/"
  else
    cp -R "$ROOT/." "$INSTALL_REPO.tmp/"
    rm -rf "$INSTALL_REPO.tmp/.git"
  fi
  rm -rf "$INSTALL_REPO"
  mv "$INSTALL_REPO.tmp" "$INSTALL_REPO"
  ROOT="$INSTALL_REPO"
}

create_start_command() {
  log "Creating daily start command"
  note "$START_CMD"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: create executable matepad-macbridge-start at $START_CMD"
    return
  fi

  mkdir -p "$BIN_DIR"
  cat > "$START_CMD" <<EOF
#!/usr/bin/env bash
set -euo pipefail
bash "$INSTALL_REPO/scripts/start-matepad-workspace.sh" "\$@"
EOF
  chmod +x "$START_CMD"
}

ensure_command_line_tools() {
  if command -v clang >/dev/null 2>&1; then
    return
  fi

  warn "clang is missing. macOS Command Line Tools are required."
  run xcode-select --install || true
  if [[ "$DRY_RUN" -eq 0 ]]; then
    warn "Install Command Line Tools, then rerun this installer."
    exit 1
  fi
}

ensure_adb() {
  if command -v adb >/dev/null 2>&1; then
    note "adb found: $(command -v adb)"
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    log "Installing Android platform tools"
    run brew install android-platform-tools
    return
  fi

  warn "adb was not found, and Homebrew was not found."
  warn "Install adb later with: brew install android-platform-tools"
}

install_mac_bridge() {
  log "Installing Mac control bridge"
  run bash "$ROOT/scripts/install-mac-bridge.sh"
}

open_accessibility_settings() {
  log "Opening macOS Accessibility settings"
  note "Enable MatePadControl and SideScreen in Privacy & Security > Accessibility."
  run open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
}

adb_device_ready() {
  command -v adb >/dev/null 2>&1 &&
    adb devices | awk 'NR > 1 && $2 == "device" { found=1 } END { exit found ? 0 : 1 }'
}

build_android_client() {
  log "Building patched SideScreen Android client"

  for cmd in curl unzip patch; do
    command -v "$cmd" >/dev/null 2>&1 || { warn "$cmd is required for Android build"; return 0; }
  done

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: download $SIDESCREEN_REPO/archive/refs/tags/$SIDESCREEN_TAG.zip"
    echo "DRY-RUN: apply patches/activity_main.xml.patch and patches/MainActivity.kt.patch"
    echo "DRY-RUN: run AndroidClient/gradlew assembleDebug"
    echo "DRY-RUN: adb install patched APK if a MatePad is authorized"
    return
  fi

  mkdir -p "$BUILD_DIR"
  local zip="$BUILD_DIR/SideScreen-$SIDESCREEN_TAG.zip"
  local src="$BUILD_DIR/SideScreen-$SIDESCREEN_TAG"

  rm -rf "$src"
  curl -fsSL "$SIDESCREEN_REPO/archive/refs/tags/$SIDESCREEN_TAG.zip" -o "$zip"
  unzip -q "$zip" -d "$BUILD_DIR"

  (
    cd "$src"
    patch -N -p1 < "$ROOT/patches/activity_main.xml.patch"
    patch -N -p1 < "$ROOT/patches/MainActivity.kt.patch"
    cd AndroidClient
    ./gradlew assembleDebug
  )

  local apk="$src/AndroidClient/app/build/outputs/apk/debug/app-debug.apk"
  if [[ ! -f "$apk" ]]; then
    warn "APK was not found at $apk"
    return 0
  fi

  if adb_device_ready; then
    adb install -r "$apk" || {
      warn "APK install failed. If this is a signature mismatch, run:"
      warn "adb uninstall com.sidescreen.app && adb install \"$apk\""
    }
  else
    warn "MatePad is not authorized over USB Debug. APK built at: $apk"
  fi
}

start_workspace() {
  if [[ "$START_AFTER" -eq 0 ]]; then
    note "Skipping start because --no-start was set."
    return
  fi

  log "Starting MatePad workspace"
  if [[ ! -d "/Applications/SideScreen.app" ]]; then
    warn "SideScreen Mac Host was not found in /Applications."
    warn "Install it from $SIDESCREEN_REPO/releases, then run:"
    warn "$START_CMD"
    run open "$SIDESCREEN_REPO/releases" || true
    return
  fi

  if ! adb_device_ready; then
    warn "MatePad is not authorized yet. Unlock MatePad, allow USB debugging, then run:"
    warn "$START_CMD"
    return
  fi

  run bash "$ROOT/scripts/start-matepad-workspace.sh"
}

print_next_steps() {
  cat <<EOF

Done.

Next steps:
  1. Enable macOS Accessibility permission for MatePadControl and SideScreen.
  2. Connect MatePad by USB and allow MatePad USB Debug when prompted.
  3. Start anytime with:
     $START_CMD

Android client:
  - Default install keeps Android build skipped for reliability.
  - To try building the patched APK automatically:
    curl -fsSL $RAW_INSTALL_URL | bash -s -- --with-android-build

Health check:
  curl http://127.0.0.1:18765/health
EOF
}

main() {
  log "$PROJECT_NAME one-click installer"
  copy_project_to_install_home
  create_start_command
  ensure_command_line_tools
  ensure_adb
  install_mac_bridge
  if [[ "$ANDROID_BUILD" -eq 1 ]]; then
    build_android_client
  else
    note "Skipping Android APK build. Use --with-android-build to try it."
  fi
  open_accessibility_settings
  start_workspace
  print_next_steps
}

main "$@"
