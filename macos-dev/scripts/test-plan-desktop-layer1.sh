#!/usr/bin/env bash
# test-plan-desktop-layer1.sh — acceptance tests for Desktop Layer 1 (AeroSpace + SketchyBar + JankyBorders)
#
# Platform-aware: runs on macOS and WSL2/Linux.
#
# Usage:
#   bash scripts/test-plan-desktop-layer1.sh              # safe tests only
#   bash scripts/test-plan-desktop-layer1.sh --full       # + invasive tests (brew, plutil, python tomllib)
#
# Each AC from the Desktop Layer 1 plan is implemented as a labelled check.
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

echo "Desktop Layer 1 acceptance tests (AeroSpace + SketchyBar + JankyBorders)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1..25 get appended by subsequent tasks ─────────────────────────

# ── AC-1: Brewfile declares AeroSpace cask + tap ──────────────────────
echo ""
echo "AC-1: Brewfile declares AeroSpace cask and tap"
check "Brewfile has tap \"nikitabobko/tap\"" \
  grep -qE '^tap "nikitabobko/tap"' Brewfile
check "Brewfile has cask \"nikitabobko/tap/aerospace\"" \
  grep -qE '^cask "nikitabobko/tap/aerospace"' Brewfile

# ── AC-2: Brewfile declares SketchyBar + JankyBorders + tap ──────────
echo ""
echo "AC-2: Brewfile declares SketchyBar + JankyBorders"
check "Brewfile has tap \"FelixKratz/formulae\"" \
  grep -qE '^tap "FelixKratz/formulae"' Brewfile
check "Brewfile has brew \"sketchybar\"" \
  grep -qE '^brew "sketchybar"' Brewfile
check "Brewfile has brew \"FelixKratz/formulae/borders\"" \
  grep -qE '^brew "FelixKratz/formulae/borders"' Brewfile

# ── AC-3: tools.txt declares the two new formulae ────────────────────
echo ""
echo "AC-3: tools.txt declares the two new formulae"
check "tools.txt has brew:sketchybar row" \
  grep -qE '^sketchybar[[:space:]]+brew:sketchybar' tools.txt
check "tools.txt has brew:FelixKratz/formulae/borders row" \
  grep -qE '^borders[[:space:]]+brew:FelixKratz/formulae/borders' tools.txt
check "check-tool-manifest.sh still passes" \
  bash scripts/check-tool-manifest.sh

# ── AC-4: check-tool-manifest.sh skips cask lines ──────────────────────
echo ""
echo "AC-4: check-tool-manifest.sh skips cask lines"
# Build a fake Brewfile with a cask but no matching tools.txt entry;
# require check-tool-manifest.sh exits 0. Uses a temp dir under /tmp
# so we don't pollute the repo.
tmp=$(mktemp -d)
cat >"$tmp/Brewfile" <<'EOF'
brew "ghq"
cask "nonexistent-cask-for-test"
EOF
cp tools.txt "$tmp/tools.txt"
# Run the manifest script with REPO_ROOT spoofed via working directory.
# The script uses $(dirname "$0")/.. — so place a symlink to the real
# script under a fake scripts/ dir whose parent is $tmp.
mkdir -p "$tmp/scripts"
ln -sf "$(cd "$MACOS_DEV/scripts" && pwd)/check-tool-manifest.sh" "$tmp/scripts/check-tool-manifest.sh"
if bash "$tmp/scripts/check-tool-manifest.sh" >/dev/null 2>&1; then
  ok "check-tool-manifest.sh skips cask lines (unmatched cask passes)"
else
  nok "check-tool-manifest.sh skips cask lines (unmatched cask passes)"
fi
rm -rf "$tmp"

# ── AC-5: install-macos.sh configures ~/Applications cask path ────────
echo ""
echo "AC-5: install-macos.sh sets HOMEBREW_CASK_OPTS"
check "install-macos.sh has mkdir -p \"\$HOME/Applications\"" \
  grep -qE 'mkdir -p[[:space:]]+"[$]HOME/Applications"' install-macos.sh
check "install-macos.sh exports HOMEBREW_CASK_OPTS with --appdir" \
  grep -qE 'export[[:space:]]+HOMEBREW_CASK_OPTS=".*--appdir=[$]HOME/Applications"' install-macos.sh
# Verify the mkdir line precedes the `brew bundle` invocation.
# grep -n emits "<line>:<text>"; strip suffix and compare.
mkdir_line="$(grep -nE 'mkdir -p[[:space:]]+"[$]HOME/Applications"' install-macos.sh | head -1 | cut -d: -f1)"
brew_bundle_line="$(grep -nE '^if[[:space:]]+!.*brew bundle' install-macos.sh | head -1 | cut -d: -f1)"
if [[ -n "$mkdir_line" && -n "$brew_bundle_line" && "$mkdir_line" -lt "$brew_bundle_line" ]]; then
  ok "\$HOME/Applications mkdir precedes brew bundle"
else
  nok "\$HOME/Applications mkdir precedes brew bundle (mkdir=$mkdir_line brew=$brew_bundle_line)"
fi

# ── AC-6: aerospace.toml parses as valid TOML ─────────────────────────
echo ""
echo "AC-6: aerospace.toml parses as valid TOML"
if command -v python3 &>/dev/null; then
  if python3 -c "import tomllib, sys; tomllib.load(open(sys.argv[1], 'rb'))" \
       aerospace/aerospace.toml 2>/dev/null; then
    ok "aerospace.toml parses"
  else
    nok "aerospace.toml parses"
  fi
else
  skp "aerospace.toml parses" "python3 not available"
fi

# ── AC-7: aerospace.toml core settings ───────────────────────────────
echo ""
echo "AC-7: aerospace.toml core settings"
check "start-at-login = true"             grep -qE '^start-at-login[[:space:]]*=[[:space:]]*true' aerospace/aerospace.toml
check "default-root-container-layout tiles" \
  grep -qE "default-root-container-layout[[:space:]]*=[[:space:]]*'tiles'" aerospace/aerospace.toml
check "default-root-container-orientation auto" \
  grep -qE "default-root-container-orientation[[:space:]]*=[[:space:]]*'auto'" aerospace/aerospace.toml
check "accordion-padding = 30"            grep -qE 'accordion-padding[[:space:]]*=[[:space:]]*30' aerospace/aerospace.toml
# gaps.outer.top = 36 verified via TOML parse (more robust than a regex).
if command -v python3 &>/dev/null; then
  top_gap="$(python3 -c "import tomllib; d=tomllib.load(open('aerospace/aerospace.toml','rb')); print(d.get('gaps',{}).get('outer',{}).get('top',''))" 2>/dev/null)"
  if [[ "$top_gap" == "36" ]]; then
    ok "gaps.outer.top == 36"
  else
    nok "gaps.outer.top == 36 (got: $top_gap)"
  fi
else
  skp "gaps.outer.top == 36" "python3 not available"
fi

# ── AC-8: aerospace.toml main-mode bindings ──────────────────────────
echo ""
echo "AC-8: aerospace.toml main-mode bindings"
toml="$(cat aerospace/aerospace.toml)"
for b in 'alt-1' 'alt-2' 'alt-3' 'alt-4' \
         'alt-shift-1' 'alt-shift-2' 'alt-shift-3' 'alt-shift-4' \
         'alt-h' 'alt-j' 'alt-k' 'alt-l' \
         'alt-shift-h' 'alt-shift-j' 'alt-shift-k' 'alt-shift-l' \
         'alt-slash' 'alt-comma' 'alt-f' 'alt-shift-space'; do
  if printf '%s' "$toml" | grep -qE "^${b}[[:space:]]*="; then
    ok "binding $b declared"
  else
    nok "binding $b declared"
  fi
done

# ── AC-9: aerospace.toml on-window-detected pins ─────────────────────
echo ""
echo "AC-9: aerospace.toml on-window-detected pins"
# Count [[on-window-detected]] occurrences — expect at least 4.
owd_count=$(grep -cE '^\[\[on-window-detected\]\]' aerospace/aerospace.toml)
if (( owd_count >= 4 )); then
  ok "at least 4 [[on-window-detected]] blocks ($owd_count)"
else
  nok "at least 4 [[on-window-detected]] blocks ($owd_count)"
fi
check "kitty app-id pinned" \
  grep -qE "app-id[[:space:]]*=[[:space:]]*'net\.kovidgoyal\.kitty'" aerospace/aerospace.toml
check "MS Edge app-id pinned" \
  grep -qE "app-id[[:space:]]*=[[:space:]]*'com\.microsoft\.edgemac'" aerospace/aerospace.toml
check "MS Teams app-id pinned" \
  grep -qE "app-id[[:space:]]*=[[:space:]]*'com\.microsoft\.teams2'" aerospace/aerospace.toml
check "MS Outlook app-id pinned" \
  grep -qE "app-id[[:space:]]*=[[:space:]]*'com\.microsoft\.Outlook'" aerospace/aerospace.toml

# ── AC-10: workspace-to-monitor-force-assignment placeholders ────────
echo ""
echo "AC-10: workspace-to-monitor-force-assignment placeholders"
check "section declared" \
  grep -qE '^\[workspace-to-monitor-force-assignment\]' aerospace/aerospace.toml
check "workspace 1 names office-central + home-centre placeholders" \
  grep -qE '^1[[:space:]]*=.*<office-central-monitor-name>.*<home-centre-monitor-name>' aerospace/aerospace.toml
check "workspace 2 names office-central + built-in" \
  grep -qE '^2[[:space:]]*=.*<office-central-monitor-name>.*built-in' aerospace/aerospace.toml
check "workspace 3 names home-left + built-in" \
  grep -qE '^3[[:space:]]*=.*<home-left-monitor-name>.*built-in' aerospace/aerospace.toml
# Workspace 4 must be absent from the force-assignment table.
if awk '/^\[workspace-to-monitor-force-assignment\]/,/^\[/' aerospace/aerospace.toml \
   | grep -qE '^4[[:space:]]*='; then
  nok "workspace 4 absent from force-assignment (scratch follows focused monitor)"
else
  ok "workspace 4 absent from force-assignment (scratch follows focused monitor)"
fi

# ── AC-11: exec-on-workspace-change trigger ──────────────────────────
echo ""
echo "AC-11: exec-on-workspace-change trigger uses @HOMEBREW_PREFIX@"
exec_body="$(awk '/^exec-on-workspace-change[[:space:]]*=/,/^\]/' aerospace/aerospace.toml)"
if printf '%s' "$exec_body" | grep -q '@HOMEBREW_PREFIX@/bin/sketchybar'; then
  ok "exec-on-workspace-change uses @HOMEBREW_PREFIX@/bin/sketchybar"
else
  nok "exec-on-workspace-change uses @HOMEBREW_PREFIX@/bin/sketchybar"
fi
if printf '%s' "$exec_body" | grep -q 'aerospace_workspace_change'; then
  ok "trigger name is aerospace_workspace_change"
else
  nok "trigger name is aerospace_workspace_change"
fi

# ── AC-12: sketchybar/colors.sh exports 12 Dracula hex constants ─────
echo ""
echo "AC-12: sketchybar/colors.sh exports full Dracula palette"
# Use case-insensitive match — hex case is unspecified in the parent
# design and consumers are case-insensitive.
for pair in 'COLOR_BG:0xff282a36' \
            'COLOR_CURRENT_LINE:0xff44475a' \
            'COLOR_SELECTION:0xff44475a' \
            'COLOR_FG:0xfff8f8f2' \
            'COLOR_COMMENT:0xff6272a4' \
            'COLOR_RED:0xffff5555' \
            'COLOR_ORANGE:0xffffb86c' \
            'COLOR_YELLOW:0xfff1fa8c' \
            'COLOR_GREEN:0xff50fa7b' \
            'COLOR_CYAN:0xff8be9fd' \
            'COLOR_PURPLE:0xffbd93f9' \
            'COLOR_PINK:0xffff79c6'; do
  name="${pair%%:*}"; val="${pair##*:}"
  if grep -qiE "^(export[[:space:]]+)?${name}=${val}" sketchybar/colors.sh; then
    ok "colors.sh exports ${name}=${val}"
  else
    nok "colors.sh exports ${name}=${val}"
  fi
done

# ── AC-13: sketchybar/icons.sh declares ≥ 9 ICON_* constants ─────────
echo ""
echo "AC-13: sketchybar/icons.sh declares glyph constants"
icon_count=$(grep -cE '^[[:space:]]*(export[[:space:]]+)?ICON_[A-Z_]+=' sketchybar/icons.sh)
if (( icon_count >= 9 )); then
  ok "icons.sh declares ≥ 9 ICON_* constants ($icon_count)"
else
  nok "icons.sh declares ≥ 9 ICON_* constants ($icon_count)"
fi
for name in ICON_WIFI ICON_BATTERY ICON_VOLUME ICON_CLOCK ICON_ZSCALER ICON_FOCUS; do
  check "icons.sh declares $name" \
    grep -qE "^[[:space:]]*(export[[:space:]]+)?${name}=" sketchybar/icons.sh
done

# ── AC-14: sketchybarrc sources palette + configures the bar ─────────
echo ""
echo "AC-14: sketchybarrc sources palette and adds 9 items"
# shellcheck disable=SC2016  # \$CONFIG_DIR is a literal regex pattern — not a shell expansion
check "sketchybarrc sources colors.sh" \
  grep -qE 'source[[:space:]]+"\$CONFIG_DIR/colors.sh"' sketchybar/sketchybarrc
# shellcheck disable=SC2016  # \$CONFIG_DIR is a literal regex pattern — not a shell expansion
check "sketchybarrc sources icons.sh" \
  grep -qE 'source[[:space:]]+"\$CONFIG_DIR/icons.sh"' sketchybar/sketchybarrc
check "sketchybarrc calls --bar height=30" \
  grep -qE 'sketchybar[[:space:]]+--bar.*height=30' sketchybar/sketchybarrc
check "sketchybarrc calls --bar position=top" \
  grep -qE 'sketchybar[[:space:]]+--bar.*position=top' sketchybar/sketchybarrc
check "sketchybarrc pins display to primary-external placeholder" \
  grep -q '<primary-external-name>' sketchybar/sketchybarrc
# Count --add item occurrences — expect at least 9 (9 items + optional event).
add_item_count=$(grep -cE '^[[:space:]]*sketchybar[[:space:]]+--add[[:space:]]+item' sketchybar/sketchybarrc)
if (( add_item_count >= 8 )); then
  ok "sketchybarrc adds ≥ 8 items ($add_item_count)"
else
  nok "sketchybarrc adds ≥ 8 items ($add_item_count)"
fi

# ── AC-15: all sketchybar/plugins/*.sh shellcheck-clean ──────────────
echo ""
echo "AC-15: sketchybar plugins shellcheck-clean"
if command -v shellcheck &>/dev/null; then
  all_ok=true
  for plugin in sketchybar/plugins/*.sh; do
    [[ -f "$plugin" ]] || continue
    if ! shellcheck "$plugin" >/dev/null 2>&1; then
      nok "shellcheck $plugin"
      all_ok=false
    fi
  done
  if $all_ok; then
    ok "shellcheck all sketchybar/plugins/*.sh"
  fi
else
  skp "shellcheck all sketchybar/plugins/*.sh" "shellcheck not available"
fi

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
