#!/usr/bin/env bash
# test-plan-desktop-layer2.sh — acceptance tests for Desktop Layer 2 (Hammerspoon + skhd + dormant Karabiner)
#
# Platform-aware: runs on macOS and WSL2/Linux.
#
# Usage:
#   bash scripts/test-plan-desktop-layer2.sh              # safe tests only
#   bash scripts/test-plan-desktop-layer2.sh --full       # + invasive tests (skhd --parse, plutil)
#
# Each AC from the Desktop Layer 2 plan is implemented as a labelled check.
# Exits 0 if all requested tests pass, 1 otherwise.

set -uo pipefail

# ── Self-resolve to macos-dev root ───────────────────────────────────────────
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
MACOS_DEV="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"
cd "$MACOS_DEV" || { echo "ERROR: cannot cd to $MACOS_DEV" >&2; exit 2; }

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)
    PLATFORM="linux"
    [[ -n "${WSL_DISTRO_NAME:-}" ]] && PLATFORM="wsl"
    ;;
  *) echo "ERROR: unsupported platform" >&2; exit 2 ;;
esac

if [[ -t 1 ]]; then
  C_GREEN=$'\033[0;32m' C_RED=$'\033[0;31m' C_YELLOW=$'\033[0;33m' C_RESET=$'\033[0m'
else
  C_GREEN='' C_RED='' C_YELLOW='' C_RESET=''
fi

pass=0
fail=0
skip=0

ok()   { printf "  ${C_GREEN}✓${C_RESET} %s\n" "$1"; pass=$((pass + 1)); }
nok()  { printf "  ${C_RED}✗${C_RESET} %s\n" "$1"; fail=$((fail + 1)); }
skp()  { printf "  ${C_YELLOW}~${C_RESET} %s (skipped: %s)\n" "$1" "$2"; skip=$((skip + 1)); }

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else nok "$desc"; fi
}

echo "Desktop Layer 2 acceptance tests (Hammerspoon + skhd + dormant Karabiner)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1: Brewfile declares Hammerspoon + skhd ──────────────────────
echo ""
echo "AC-1: Brewfile declares keyboard-layer tooling"
check "Brewfile has cask \"hammerspoon\"" \
  grep -qE '^cask "hammerspoon"' Brewfile
check "Brewfile has tap \"koekeishiya/formulae\"" \
  grep -qE '^tap "koekeishiya/formulae"' Brewfile
check "Brewfile has brew \"koekeishiya/formulae/skhd\"" \
  grep -qE '^brew "koekeishiya/formulae/skhd"' Brewfile

# ── AC-2: tools.txt declares skhd; casks intentionally absent ────────
echo ""
echo "AC-2: tools.txt declares skhd formula (no cask rows)"
check "tools.txt has brew:koekeishiya/formulae/skhd" \
  grep -qE '^skhd[[:space:]]+brew:koekeishiya/formulae/skhd' tools.txt
if grep -qE '^[a-z].*brew:hammerspoon' tools.txt; then
  nok "tools.txt does NOT list hammerspoon (cask)"
else
  ok "tools.txt does NOT list hammerspoon (cask)"
fi
check "check-tool-manifest.sh still passes" \
  bash scripts/check-tool-manifest.sh

# ── AC-3: init.lua parses via luac -p ────────────────────────────────
echo ""
echo "AC-3: hammerspoon/init.lua parses via luac -p"
if command -v luac &>/dev/null; then
  if luac -p hammerspoon/init.lua >/dev/null 2>&1; then
    ok "luac -p hammerspoon/init.lua"
  else
    nok "luac -p hammerspoon/init.lua"
  fi
else
  skp "luac -p hammerspoon/init.lua" "luac not available"
fi

# ── AC-4: init.lua registers eventtap on keycode 57 (Caps Lock) ──────
echo ""
echo "AC-4: init.lua handles Caps Lock keycode 57"
lua_body="$(sed 's/--.*//' hammerspoon/init.lua)"
if printf '%s' "$lua_body" | grep -q 'hs\.eventtap\.new'; then
  ok "init.lua calls hs.eventtap.new"
else
  nok "init.lua calls hs.eventtap.new"
fi
if printf '%s' "$lua_body" | grep -qE 'keyCode\(\)[^=]*==[^0-9]*57|57\b'; then
  ok "init.lua references keycode 57"
else
  nok "init.lua references keycode 57"
fi
for typ in 'keyDown' 'keyUp'; do
  if printf '%s' "$lua_body" | grep -q "types\\.$typ"; then
    ok "init.lua subscribes to hs.eventtap.event.types.$typ"
  else
    nok "init.lua subscribes to hs.eventtap.event.types.$typ"
  fi
done

# ── AC-5: init.lua defines THRESHOLD_MS = 200 ────────────────────────
echo ""
echo "AC-5: init.lua defines THRESHOLD_MS = 200"
if printf '%s' "$lua_body" | grep -qE 'THRESHOLD_MS[[:space:]]*=[[:space:]]*200'; then
  ok "THRESHOLD_MS = 200"
else
  nok "THRESHOLD_MS = 200"
fi

# ── AC-6: init.lua emits the four-modifier Hyper chord ───────────────
echo ""
echo "AC-6: init.lua emits Cmd+Alt+Ctrl+Shift on hold"
for mod in 'cmd[[:space:]]*=[[:space:]]*true' \
           'alt[[:space:]]*=[[:space:]]*true' \
           'ctrl[[:space:]]*=[[:space:]]*true' \
           'shift[[:space:]]*=[[:space:]]*true'; do
  if printf '%s' "$lua_body" | grep -qE "$mod"; then
    ok "init.lua sets $mod"
  else
    nok "init.lua sets $mod"
  fi
done

# ── AC-7: init.lua wraps eventtap setup in pcall() ───────────────────
echo ""
echo "AC-7: init.lua wraps setup in pcall()"
if printf '%s' "$lua_body" | grep -q 'pcall('; then
  ok "init.lua contains pcall("
else
  nok "init.lua contains pcall("
fi

# ── AC-8: skhd/.skhdrc parses via skhd --parse (else skp) ────────────
echo ""
echo "AC-8: skhd/.skhdrc parses via skhd --parse"
if [[ "$PLATFORM" == "macos" ]] && command -v skhd &>/dev/null; then
  if skhd --parse skhd/.skhdrc >/dev/null 2>&1; then
    ok "skhd --parse skhd/.skhdrc"
  else
    nok "skhd --parse skhd/.skhdrc"
  fi
else
  skp "skhd --parse skhd/.skhdrc" "skhd not installed"
fi

# ── AC-9: skhd/.skhdrc declares all 11 Hyper bindings ────────────────
echo ""
echo "AC-9: skhd/.skhdrc declares 11 Hyper bindings"
skhd_body="$(sed 's/#.*//' skhd/.skhdrc)"
for key in 'e' 'o' 't' 'k' 'n' 'w' 'x' 'p' 'f' 'space' 'r'; do
  if printf '%s' "$skhd_body" \
       | grep -qE "cmd[[:space:]]*\\+[[:space:]]*alt[[:space:]]*\\+[[:space:]]*ctrl[[:space:]]*\\+[[:space:]]*shift[[:space:]]*-[[:space:]]*${key}[[:space:]]*:"; then
    ok "Hyper+$key binding declared"
  else
    nok "Hyper+$key binding declared"
  fi
done

# ── AC-10: Hyper+r binding uses @HOMEBREW_PREFIX@/bin/aerospace ──────
echo ""
echo "AC-10: Hyper+r calls @HOMEBREW_PREFIX@/bin/aerospace reload-config"
if printf '%s' "$skhd_body" \
     | grep -qE "cmd[[:space:]]*\\+[[:space:]]*alt[[:space:]]*\\+[[:space:]]*ctrl[[:space:]]*\\+[[:space:]]*shift[[:space:]]*-[[:space:]]*r[[:space:]]*:.*@HOMEBREW_PREFIX@/bin/aerospace[[:space:]]+reload-config"; then
  ok "Hyper+r uses @HOMEBREW_PREFIX@/bin/aerospace reload-config"
else
  nok "Hyper+r uses @HOMEBREW_PREFIX@/bin/aerospace reload-config"
fi

# ── AC-11: Karabiner JSON is valid JSON ──────────────────────────────
echo ""
echo "AC-11: karabiner/.../desktop-layer2.json parses via jq empty"
if command -v jq &>/dev/null; then
  if jq empty karabiner/complex_modifications/desktop-layer2.json >/dev/null 2>&1; then
    ok "jq empty desktop-layer2.json"
  else
    nok "jq empty desktop-layer2.json"
  fi
else
  skp "jq empty desktop-layer2.json" "jq not available"
fi

# ── AC-12: Karabiner JSON declares caps_lock → escape/Hyper ──────────
echo ""
echo "AC-12: Karabiner JSON declares Caps → Escape / Hyper semantics"
if command -v jq &>/dev/null; then
  check "title is non-empty" \
    bash -c 'jq -e ".title | length > 0" karabiner/complex_modifications/desktop-layer2.json'
  check ".rules is a non-empty array" \
    bash -c 'jq -e ".rules | type == \"array\" and length > 0" karabiner/complex_modifications/desktop-layer2.json'
  check "at least one rule references caps_lock" \
    bash -c 'jq -e "[.. | .key_code? // empty] | any(. == \"caps_lock\")" karabiner/complex_modifications/desktop-layer2.json'
else
  skp "Karabiner JSON structural checks" "jq not available"
fi

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))

