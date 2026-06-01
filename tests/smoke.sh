#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$ROOT/$file" || fail "$file is missing: $needle"
}

[[ -f "$ROOT/install.sh" ]] || fail "install.sh is missing"
[[ -x "$ROOT/install.sh" ]] || fail "install.sh is not executable"

bash -n "$ROOT/install.sh"
bash -n "$ROOT/scripts/install-mac-bridge.sh"
bash -n "$ROOT/scripts/start-matepad-workspace.sh"

help_output="$("$ROOT/install.sh" --help)"
[[ "$help_output" == *"MatePad MacBridge"* ]] || fail "help does not name the project"
[[ "$help_output" == *"--with-android-build"* ]] || fail "help misses --with-android-build"
[[ "$help_output" == *"--skip-android-build"* ]] || fail "help misses --skip-android-build"
[[ "$help_output" == *"--dry-run"* ]] || fail "help misses --dry-run"
[[ "$help_output" == *"matepad-macbridge-start"* ]] || fail "help misses the start command"

dry_run_output="$("$ROOT/install.sh" --dry-run --no-start)"
[[ "$dry_run_output" == *"DRY-RUN"* ]] || fail "dry run did not mark planned actions"
[[ "$dry_run_output" == *"scripts/install-mac-bridge.sh"* ]] || fail "dry run misses Mac bridge installer"
[[ "$dry_run_output" == *"matepad-macbridge-start"* ]] || fail "dry run misses persistent start command"

assert_contains "README.md" "curl -fsSL https://raw.githubusercontent.com/837849491-blip/MatePad-MacBridge/main/install.sh | bash"
assert_contains "README.md" "一键安装"
assert_contains "README.md" "macOS 辅助功能权限"
assert_contains "README.md" "MatePad USB 调试"
