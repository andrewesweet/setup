#!/usr/bin/env bash
# test-plan4.sh — smoke tests for Plan 4 (kitty terminal configuration)
#
# Validates:
#   - kitty.conf exists
#   - Font, display, and shell integration settings are correct
#   - Audio/visual bell settings are correct
#   - Clipboard selection is configured
#   - All 8 required key bindings are present
#   - Install scripts have correct link() mapping for kitty
#   - Plans 2–3 link() calls are preserved (regression)
#
# Usage: bash scripts/test-plan4.sh
# Exit: 0 if all tests pass, 1 if any fail

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass=0
fail=0

ok() {
  printf "  \033[0;32m✓\033[0m %s\n" "$1"
  pass=$((pass + 1))
}

nok() {
  printf "  \033[0;31m✗\033[0m %s\n" "$1"
  fail=$((fail + 1))
}

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "$desc"
  else
    nok "$desc"
  fi
}

echo "Plan 4: kitty terminal configuration smoke tests"
echo ""

# ── File existence ─────────────────────────────────────────────────────────
echo "File existence:"
check "kitty.conf exists"  test -f "$REPO_ROOT/kitty/kitty.conf"

# ── Font and display ──────────────────────────────────────────────────────
echo ""
echo "Font and display:"
check "font_family = JetBrains Mono"    grep -qF 'font_family      JetBrains Mono' "$REPO_ROOT/kitty/kitty.conf"
check "font_size = 13.0"               grep -q 'font_size.*13\.0' "$REPO_ROOT/kitty/kitty.conf"
check "shell_integration enabled"       grep -q 'shell_integration.*enabled' "$REPO_ROOT/kitty/kitty.conf"
check "scrollback_lines = 10000"        grep -q 'scrollback_lines.*10000' "$REPO_ROOT/kitty/kitty.conf"

# ── Audio and visual feedback ─────────────────────────────────────────────
echo ""
echo "Audio and visual feedback:"
check "enable_audio_bell = no"          grep -q 'enable_audio_bell.*no' "$REPO_ROOT/kitty/kitty.conf"
check "visual_bell_duration = 0"        grep -q 'visual_bell_duration.*0' "$REPO_ROOT/kitty/kitty.conf"
check "window_alert_on_bell = no"       grep -q 'window_alert_on_bell.*no' "$REPO_ROOT/kitty/kitty.conf"
check "confirm_os_window_close = 0"     grep -q 'confirm_os_window_close.*0' "$REPO_ROOT/kitty/kitty.conf"

# ── Selection and clipboard ───────────────────────────────────────────────
echo ""
echo "Selection and clipboard:"
check "copy_on_select = clipboard"      grep -q 'copy_on_select.*clipboard' "$REPO_ROOT/kitty/kitty.conf"

# ── Key bindings ──────────────────────────────────────────────────────────
echo ""
echo "Key bindings:"
check "map ctrl+shift+t new_tab_with_cwd"       grep -q 'map ctrl+shift+t.*new_tab_with_cwd' "$REPO_ROOT/kitty/kitty.conf"
check "map ctrl+shift+n new_os_window_with_cwd"  grep -q 'map ctrl+shift+n.*new_os_window_with_cwd' "$REPO_ROOT/kitty/kitty.conf"
check "map ctrl+shift+right next_tab"            grep -q 'map ctrl+shift+right.*next_tab' "$REPO_ROOT/kitty/kitty.conf"
check "map ctrl+shift+left previous_tab"         grep -q 'map ctrl+shift+left.*previous_tab' "$REPO_ROOT/kitty/kitty.conf"
check "map ctrl+shift+h show_scrollback"         grep -q 'map ctrl+shift+h.*show_scrollback' "$REPO_ROOT/kitty/kitty.conf"
check "map ctrl+shift+equal font size increase"  grep -q 'map ctrl+shift+equal.*change_font_size.*+1' "$REPO_ROOT/kitty/kitty.conf"
check "map ctrl+shift+minus font size decrease"  grep -q 'map ctrl+shift+minus.*change_font_size.*-1' "$REPO_ROOT/kitty/kitty.conf"
check "map ctrl+shift+0 font size reset"         grep -q 'map ctrl+shift+0.*change_font_size.*0' "$REPO_ROOT/kitty/kitty.conf"

# Total key bindings count
check "exactly 8 key bindings"  test "$(grep -c '^map ' "$REPO_ROOT/kitty/kitty.conf")" -eq 8

# ── Install script link() calls ──────────────────────────────────────────
echo ""
echo "Install scripts:"
check "macos: kitty.conf mapping"       grep -q 'link kitty/kitty.conf.*\.config/kitty/kitty.conf' "$REPO_ROOT/install-macos.sh"
check "wsl: kitty.conf mapping"         grep -q 'link kitty/kitty.conf.*\.config/kitty/kitty.conf' "$REPO_ROOT/install-wsl.sh"

# Regression: Plans 2–3 link() calls preserved
check "macos: bash links preserved"     test "$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: git links preserved"      test "$(grep -c 'link git/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "wsl: bash links preserved"       test "$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: git links preserved"        test "$(grep -c 'link git/' "$REPO_ROOT/install-wsl.sh")" -eq 2

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Current count: 25 tests. Floor should be within ~10% of actual.
if (( total < 22 )); then
  echo "WARNING: only $total tests ran (expected >= 22). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
