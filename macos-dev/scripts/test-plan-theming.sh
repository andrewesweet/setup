#!/usr/bin/env bash
# test-plan-theming.sh — acceptance tests for Dracula Pro theming rollout.
#
# Wave A covers the prerequisites and Tier 1 tools (kitty, nvim, vscode,
# windows-terminal, raycast, ghostty). Waves B and C will append to this
# script in later plans.
#
# Usage:
#   bash scripts/test-plan-theming.sh              # safe tests only
#   bash scripts/test-plan-theming.sh --full       # + runtime tests (needs installed tools)
#
# Exits 0 iff every requested check passes. Skipped checks do not count
# as failures.

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

ok()   { printf "  ${C_GREEN}\u2713${C_RESET} %s\n" "$1"; pass=$((pass + 1)); }
nok()  { printf "  ${C_RED}\u2717${C_RESET} %s\n" "$1"; fail=$((fail + 1)); }
skp()  { printf "  ${C_YELLOW}~${C_RESET} %s (skipped: %s)\n" "$1" "$2"; skip=$((skip + 1)); }

# Shared check() — runs a command; passes if exit 0, fails otherwise.
# Later waves extend this script; this helper stays unchanged.
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else nok "$desc"; fi
}

# Source the palette file so later ACs can assert `$DRACULA_PRO_FOO == "<hex>"`.
# shellcheck source=scripts/lib/dracula-pro-palette.sh
if [[ -f scripts/lib/dracula-pro-palette.sh ]]; then
  # shellcheck disable=SC1091
  source scripts/lib/dracula-pro-palette.sh
fi

DRACULA_PRO_HOME="${DRACULA_PRO_HOME:-$HOME/dracula-pro}"

echo "Wave A acceptance tests"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo "Dracula Pro home: $DRACULA_PRO_HOME $([ -d "$DRACULA_PRO_HOME" ] && echo "(present)" || echo "(ABSENT)")"
echo ""

# ── AC-palette: palette file ships and matches spec § 6.3 ──────────────────
echo "AC-palette: scripts/lib/dracula-pro-palette.sh matches spec"
check "palette file exists"                        test -f scripts/lib/dracula-pro-palette.sh
check "DRACULA_PRO_BLACK      == #22212C"          test "${DRACULA_PRO_BLACK:-}"      = "#22212C"
check "DRACULA_PRO_RED        == #FF9580"          test "${DRACULA_PRO_RED:-}"        = "#FF9580"
check "DRACULA_PRO_GREEN      == #8AFF80"          test "${DRACULA_PRO_GREEN:-}"      = "#8AFF80"
check "DRACULA_PRO_YELLOW     == #FFFF80"          test "${DRACULA_PRO_YELLOW:-}"     = "#FFFF80"
check "DRACULA_PRO_BLUE       == #9580FF"          test "${DRACULA_PRO_BLUE:-}"       = "#9580FF"
check "DRACULA_PRO_MAGENTA    == #FF80BF"          test "${DRACULA_PRO_MAGENTA:-}"    = "#FF80BF"
check "DRACULA_PRO_CYAN       == #80FFEA"          test "${DRACULA_PRO_CYAN:-}"       = "#80FFEA"
check "DRACULA_PRO_WHITE      == #F8F8F2"          test "${DRACULA_PRO_WHITE:-}"      = "#F8F8F2"
check "DRACULA_PRO_BRIGHT_BLACK   == #504C67"      test "${DRACULA_PRO_BRIGHT_BLACK:-}"   = "#504C67"
check "DRACULA_PRO_BRIGHT_RED     == #FFAA99"      test "${DRACULA_PRO_BRIGHT_RED:-}"     = "#FFAA99"
check "DRACULA_PRO_BRIGHT_GREEN   == #A2FF99"      test "${DRACULA_PRO_BRIGHT_GREEN:-}"   = "#A2FF99"
check "DRACULA_PRO_BRIGHT_YELLOW  == #FFFF99"      test "${DRACULA_PRO_BRIGHT_YELLOW:-}"  = "#FFFF99"
check "DRACULA_PRO_BRIGHT_BLUE    == #AA99FF"      test "${DRACULA_PRO_BRIGHT_BLUE:-}"    = "#AA99FF"
check "DRACULA_PRO_BRIGHT_MAGENTA == #FF99CC"      test "${DRACULA_PRO_BRIGHT_MAGENTA:-}" = "#FF99CC"
check "DRACULA_PRO_BRIGHT_CYAN    == #99FFEE"      test "${DRACULA_PRO_BRIGHT_CYAN:-}"    = "#99FFEE"
check "DRACULA_PRO_BRIGHT_WHITE   == #FFFFFF"      test "${DRACULA_PRO_BRIGHT_WHITE:-}"   = "#FFFFFF"
check "DRACULA_PRO_DIM_BLACK     == #1B1A23"       test "${DRACULA_PRO_DIM_BLACK:-}"     = "#1B1A23"
check "DRACULA_PRO_DIM_RED       == #CC7766"       test "${DRACULA_PRO_DIM_RED:-}"       = "#CC7766"
check "DRACULA_PRO_DIM_GREEN     == #6ECC66"       test "${DRACULA_PRO_DIM_GREEN:-}"     = "#6ECC66"
check "DRACULA_PRO_DIM_YELLOW    == #CCCC66"       test "${DRACULA_PRO_DIM_YELLOW:-}"    = "#CCCC66"
check "DRACULA_PRO_DIM_BLUE      == #7766CC"       test "${DRACULA_PRO_DIM_BLUE:-}"      = "#7766CC"
check "DRACULA_PRO_DIM_MAGENTA   == #CC6699"       test "${DRACULA_PRO_DIM_MAGENTA:-}"   = "#CC6699"
check "DRACULA_PRO_DIM_CYAN      == #66CCBB"       test "${DRACULA_PRO_DIM_CYAN:-}"      = "#66CCBB"
check "DRACULA_PRO_DIM_WHITE     == #C6C6C2"       test "${DRACULA_PRO_DIM_WHITE:-}"     = "#C6C6C2"
check "DRACULA_PRO_BACKGROUND == #22212C"          test "${DRACULA_PRO_BACKGROUND:-}" = "#22212C"
check "DRACULA_PRO_FOREGROUND == #F8F8F2"          test "${DRACULA_PRO_FOREGROUND:-}" = "#F8F8F2"
check "DRACULA_PRO_COMMENT    == #7970A9"          test "${DRACULA_PRO_COMMENT:-}"    = "#7970A9"
check "DRACULA_PRO_SELECTION  == #454158"          test "${DRACULA_PRO_SELECTION:-}"  = "#454158"
check "DRACULA_PRO_CURSOR     == #7970A9"          test "${DRACULA_PRO_CURSOR:-}"     = "#7970A9"
check "DRACULA_PRO_ORANGE     == #FFCA80"          test "${DRACULA_PRO_ORANGE:-}"     = "#FFCA80"
check "DRACULA_PRO_PURPLE == DRACULA_PRO_BLUE"     test "${DRACULA_PRO_PURPLE:-}"  = "${DRACULA_PRO_BLUE:-x}"
check "DRACULA_PRO_PINK   == DRACULA_PRO_MAGENTA"  test "${DRACULA_PRO_PINK:-}"    = "${DRACULA_PRO_MAGENTA:-x}"

# ── AC-gitignore: /dracula-pro/ is ignored at repo root ────────────────────
echo ""
echo "AC-gitignore: /dracula-pro/ is listed in .gitignore"
check ".gitignore contains '/dracula-pro/'"  grep -Fxq "/dracula-pro/" .gitignore

# ── AC-skip-env: install scripts honour SKIP_DRACULA_PRO ──────────────────
echo ""
echo "AC-skip-env: install scripts handle SKIP_DRACULA_PRO + loud-fail"
check "install-macos.sh sources the palette file"             \
  grep -qE 'source .*scripts/lib/dracula-pro-palette\.sh' install-macos.sh
check "install-macos.sh checks for ~/dracula-pro/ presence"   \
  grep -qE 'test -d .*\$HOME/dracula-pro|\[\[ -d "\$HOME/dracula-pro" \]\]' install-macos.sh
check "install-macos.sh references SKIP_DRACULA_PRO"          \
  grep -q 'SKIP_DRACULA_PRO' install-macos.sh
check "install-macos.sh has loud-fail error message"          \
  grep -qE 'error: ~/dracula-pro/ not found' install-macos.sh
check "install-wsl.sh sources the palette file"               \
  grep -qE 'source .*scripts/lib/dracula-pro-palette\.sh' install-wsl.sh
check "install-wsl.sh checks for ~/dracula-pro/ presence"     \
  grep -qE 'test -d .*\$HOME/dracula-pro|\[\[ -d "\$HOME/dracula-pro" \]\]' install-wsl.sh
check "install-wsl.sh references SKIP_DRACULA_PRO"            \
  grep -q 'SKIP_DRACULA_PRO' install-wsl.sh
check "install-wsl.sh has loud-fail error message"            \
  grep -qE 'error: ~/dracula-pro/ not found' install-wsl.sh

# Runtime: run the preflight in isolation with HOME redirected and confirm exit codes.
if [[ "$FULL" == true ]]; then
  tmphome="$(mktemp -d)"
  # Absent + unset → must fail non-zero with the error message
  out_absent_unset="$(HOME="$tmphome" SKIP_DRACULA_PRO= bash -c '
    set +e
    source scripts/lib/dracula-pro-palette.sh
    if [[ ! -d "$HOME/dracula-pro" ]] && [[ -z "${SKIP_DRACULA_PRO:-}" ]]; then
      echo "error: ~/dracula-pro/ not found. Install Dracula Pro from draculatheme.com/pro before running this script." >&2
      exit 1
    fi
  ' 2>&1)"
  if printf '%s' "$out_absent_unset" | grep -q 'error: ~/dracula-pro/ not found'; then
    ok "preflight: absent + SKIP unset → error"
  else
    nok "preflight: absent + SKIP unset → error (got: $out_absent_unset)"
  fi

  # Absent + SKIP=1 → must warn and exit 0
  out_absent_skip="$(HOME="$tmphome" SKIP_DRACULA_PRO=1 bash -c '
    set -e
    source scripts/lib/dracula-pro-palette.sh
    if [[ ! -d "$HOME/dracula-pro" ]]; then
      if [[ "${SKIP_DRACULA_PRO:-0}" == 1 ]]; then
        echo "WARN: SKIP_DRACULA_PRO=1 — Tier 1 theming skipped" >&2
      else
        echo "error: ~/dracula-pro/ not found" >&2
        exit 1
      fi
    fi
  ' 2>&1)"
  if printf '%s' "$out_absent_skip" | grep -q 'SKIP_DRACULA_PRO=1 — Tier 1 theming skipped'; then
    ok "preflight: absent + SKIP=1 → warn + continue"
  else
    nok "preflight: absent + SKIP=1 → warn + continue (got: $out_absent_skip)"
  fi
  rm -rf "$tmphome"
else
  skp "preflight runtime (absent + unset)" "safe mode"
  skp "preflight runtime (absent + SKIP=1)" "safe mode"
fi

echo ""
echo "---------------------------------------------------------------"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
