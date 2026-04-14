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

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
