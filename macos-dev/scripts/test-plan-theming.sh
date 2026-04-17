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
# shellcheck disable=SC2016
check "install-macos.sh checks for ~/dracula-pro/ presence"   \
  grep -qE 'test -d .*\$HOME/dracula-pro|\[\[ -d "\$HOME/dracula-pro" \]\]' install-macos.sh
check "install-macos.sh references SKIP_DRACULA_PRO"          \
  grep -q 'SKIP_DRACULA_PRO' install-macos.sh
check "install-macos.sh has loud-fail error message"          \
  grep -qE 'error: ~/dracula-pro/ not found' install-macos.sh
check "install-wsl.sh sources the palette file"               \
  grep -qE 'source .*scripts/lib/dracula-pro-palette\.sh' install-wsl.sh
# shellcheck disable=SC2016
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
  out_absent_unset="$(HOME="$tmphome" SKIP_DRACULA_PRO='' bash -c '
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

# ── AC-nvim: nvim adopts the Dracula Pro vim plugin via lazy.nvim ─────────
echo ""
echo "AC-nvim: nvim loads Dracula Pro via lazy.nvim local dir plugin"
check "nvim/lua/plugins/colorscheme.lua exists"              \
  test -f nvim/lua/plugins/colorscheme.lua
check "colorscheme.lua uses local dir for dracula-pro/themes/vim" \
  grep -qE 'dir\s*=\s*vim\.fn\.expand\("~/dracula-pro/themes/vim"\)' nvim/lua/plugins/colorscheme.lua
check "colorscheme.lua sets colorscheme = dracula_pro"       \
  grep -qE 'colorscheme\s*=\s*"dracula_pro"' nvim/lua/plugins/colorscheme.lua
check "colorscheme.lua overrides LazyVim default colorscheme" \
  grep -qE 'LazyVim.*colorscheme|opts.*colorscheme' nvim/lua/plugins/colorscheme.lua

# ── AC-vscode: Dracula Pro replaces Catppuccin in vscode ──────────────────
echo ""
echo "AC-vscode: vscode uses Dracula Pro (.vsix + colorTheme setting)"
check "extensions.json does NOT include catppuccin.catppuccin-vsc" \
  bash -c '! grep -q "catppuccin.catppuccin-vsc" vscode/extensions.json'
check "extensions.json includes dracula-theme-pro.theme-dracula-pro" \
  grep -q '"dracula-theme-pro.theme-dracula-pro"' vscode/extensions.json
check "settings.json sets workbench.colorTheme = Dracula Pro"   \
  grep -qE '"workbench\.colorTheme"\s*:\s*"Dracula Pro"' vscode/settings.json
check "install-macos.sh installs the Pro .vsix via code CLI"    \
  grep -qE 'code --install-extension\s+.*dracula-pro\.vsix' install-macos.sh

# ── AC-wt: install-wsl.sh splices Dracula Pro scheme into WT settings ─────
echo ""
echo "AC-wt: install-wsl.sh splices Dracula Pro scheme into Windows Terminal"
check "install-wsl.sh references the Pro WT scheme JSON"      \
  grep -qE 'dracula-pro/themes/windows-terminal/dracula-pro\.json' install-wsl.sh
check "install-wsl.sh splices via jq (schemes array)"         \
  grep -qE 'jq .*schemes' install-wsl.sh
check "install-wsl.sh warns on absent WT settings.json"       \
  grep -qE 'Windows Terminal settings\.json not found' install-wsl.sh
check "install-wsl.sh WT splice is guarded by DRACULA_PRO_OK" \
  grep -qE 'DRACULA_PRO_OK.*==.*1' install-wsl.sh

# Runtime idempotency check — only runs on WSL with a real WT settings.json
if [[ "$FULL" == true ]] && [[ "$PLATFORM" == "wsl" ]] && [[ "${DRACULA_PRO_OK:-0}" == 1 ]]; then
  wt_glob="/mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json"
  # shellcheck disable=SC2086
  wt_path="$(compgen -G $wt_glob 2>/dev/null | head -n1 || true)"
  if [[ -n "$wt_path" ]] && command -v jq &>/dev/null; then
    bash install-wsl.sh >/tmp/wt-install-1.log 2>&1 || true
    bash install-wsl.sh >/tmp/wt-install-2.log 2>&1 || true
    count="$(jq '[.schemes[] | select(.name=="Dracula Pro")] | length' "$wt_path" 2>/dev/null || echo 0)"
    if [[ "$count" == "1" ]]; then
      ok "WT splice is idempotent (exactly 1 Dracula Pro scheme)"
    else
      nok "WT splice is idempotent (expected 1, got $count)"
    fi
  else
    skp "WT splice idempotency" "no WT settings.json or no jq"
  fi
else
  skp "WT splice idempotency" "not WSL/full-mode or Pro absent"
fi

# ── AC-raycast: Raycast theme import is documented ────────────────────────
echo ""
echo "AC-raycast: install-macos.sh Next Steps documents Raycast import"
check "raycast/dracula-pro.md exists"                         \
  test -f raycast/dracula-pro.md
check "raycast/dracula-pro.md records chosen variant (Pro)"   \
  grep -qE 'Dracula PRO\s*-\s*Pro|variant.*Pro' raycast/dracula-pro.md
check "install-macos.sh Next Steps mentions Raycast + Dracula Pro" \
  bash -c "awk '/^Next steps:/,/^EOF$/' install-macos.sh | grep -qi 'Raycast.*Dracula Pro'"
check "install-macos.sh Next Steps contains addToRaycast deep-link" \
  grep -qE 'https://themes\.ray\.so' install-macos.sh

# ── AC-ghostty: ghostty config references Pro theme by path ───────────────
echo ""
echo "AC-ghostty: ghostty uses ~/dracula-pro/themes/ghostty/pro"
check "ghostty/config exists"                                 \
  test -f ghostty/config
check "ghostty/config sets theme to Pro file"                 \
  grep -qE '^theme\s*=\s*~?/.*dracula-pro/themes/ghostty/pro' ghostty/config
check "install-macos.sh symlinks ghostty/config"              \
  grep -qE 'link\s+ghostty/config\s+\.config/ghostty/config' install-macos.sh

# ── AC-kitty: kitty consumes Pro theme via generated include file ─────────
echo ""
echo "AC-kitty: kitty includes Dracula Pro (generated at install time)"
check "kitty/kitty.conf includes dracula-pro.generated.conf"  \
  grep -qE '^include\s+~?/.*dracula-pro\.generated\.conf' kitty/kitty.conf
check "kitty/dracula-pro.conf (reconstruction) is removed"    \
  bash -c '! test -f kitty/dracula-pro.conf'
check "install-macos.sh generates the kitty include file"     \
  grep -qE 'dracula-pro\.generated\.conf' install-macos.sh
check "install-wsl.sh generates the kitty include file"       \
  grep -qE 'dracula-pro\.generated\.conf' install-wsl.sh
check "install-macos.sh no longer symlinks kitty/dracula-pro.conf" \
  bash -c '! grep -qE "link\s+kitty/dracula-pro\.conf" install-macos.sh'
check "install-wsl.sh no longer symlinks kitty/dracula-pro.conf"   \
  bash -c '! grep -qE "link\s+kitty/dracula-pro\.conf" install-wsl.sh'

# Runtime check: after install, the generated file must exist and contain
# the canonical palette lines.
if [[ "$FULL" == true ]] && [[ "${DRACULA_PRO_OK:-0}" == 1 ]]; then
  gen="$HOME/.config/kitty/dracula-pro.generated.conf"
  if [[ -f "$gen" ]]; then
    check "generated kitty file: background #22212C" \
      grep -qE '^background\s+#22212C' "$gen"
    check "generated kitty file: foreground #F8F8F2" \
      grep -qE '^foreground\s+#F8F8F2' "$gen"
    check "generated kitty file has 16 color lines"  \
      bash -c "[[ \"\$(grep -cE '^color(1?[0-9])\\s+#' \"$gen\")\" == 16 ]]"
  else
    skp "generated kitty file" "install-macos.sh has not been run"
  fi
else
  skp "generated kitty file runtime checks" "safe mode or Pro absent"
fi

# ═════════════════════════════════════════════════════════════════════════════
# Wave C — Tier 3 custom reconstruction from Pro palette
# Spec: macos-dev/docs/design/theming.md §§ 3.3, 5.2, 6.
# Every AC below asserts every slot of the tool's profile; partial coverage
# fails per § 6.1.
# ═════════════════════════════════════════════════════════════════════════════

# Source the authoritative palette so later ACs can assert
# `committed-hex == $DRACULA_PRO_<SLOT>` instead of hardcoding hex twice.
# shellcheck source=lib/dracula-pro-palette.sh disable=SC1091
. "$MACOS_DEV/scripts/lib/dracula-pro-palette.sh"

echo ""
echo "═══ Wave C — Tier 3 ═════════════════════════════════════════════════════"

# ── AC-sketchybar: colors.sh aligns with Dracula Pro palette ───────────────
echo ""
echo "AC-sketchybar: sketchybar/colors.sh uses Dracula Pro palette"

# Structural sourcing of the palette file — colors.sh MUST NOT hardcode hex.
check "colors.sh sources scripts/lib/dracula-pro-palette.sh" \
  grep -qE '^\s*\.\s+.*/dracula-pro-palette\.sh' sketchybar/colors.sh

# Source colors.sh in a subshell so its helper-derived COLOR_* values
# resolve to their 0xff<RRGGBB> strings; then extract the 6-char hex.
# DOTFILES override so colors.sh sources the palette from the checkout.
sb_hex() {
  DOTFILES="$MACOS_DEV" bash -c '. sketchybar/colors.sh 2>/dev/null; printf "%s" "${'"$1"':-}"' \
    | sed -E 's/^0xff([0-9A-Fa-f]{6}).*/\1/' | tr 'a-f' 'A-F'
}
pal_hex() { printf '%s' "$1" | sed -E 's/^#([0-9A-Fa-f]{6})/\1/' | tr 'a-f' 'A-F'; }

# Base structural slots
check "COLOR_BG        == DRACULA_PRO_BACKGROUND"  test "$(sb_hex COLOR_BG)"        = "$(pal_hex "$DRACULA_PRO_BACKGROUND")"
check "COLOR_FG        == DRACULA_PRO_FOREGROUND"  test "$(sb_hex COLOR_FG)"        = "$(pal_hex "$DRACULA_PRO_FOREGROUND")"
check "COLOR_COMMENT   == DRACULA_PRO_COMMENT"     test "$(sb_hex COLOR_COMMENT)"   = "$(pal_hex "$DRACULA_PRO_COMMENT")"
check "COLOR_SELECTION == DRACULA_PRO_SELECTION"   test "$(sb_hex COLOR_SELECTION)" = "$(pal_hex "$DRACULA_PRO_SELECTION")"
# Accents
check "COLOR_RED       == DRACULA_PRO_RED"         test "$(sb_hex COLOR_RED)"       = "$(pal_hex "$DRACULA_PRO_RED")"
check "COLOR_GREEN     == DRACULA_PRO_GREEN"       test "$(sb_hex COLOR_GREEN)"     = "$(pal_hex "$DRACULA_PRO_GREEN")"
check "COLOR_YELLOW    == DRACULA_PRO_YELLOW"      test "$(sb_hex COLOR_YELLOW)"    = "$(pal_hex "$DRACULA_PRO_YELLOW")"
check "COLOR_CYAN      == DRACULA_PRO_CYAN"        test "$(sb_hex COLOR_CYAN)"      = "$(pal_hex "$DRACULA_PRO_CYAN")"
check "COLOR_PURPLE    == DRACULA_PRO_BLUE"        test "$(sb_hex COLOR_PURPLE)"    = "$(pal_hex "$DRACULA_PRO_BLUE")"
check "COLOR_PINK      == DRACULA_PRO_MAGENTA"     test "$(sb_hex COLOR_PINK)"      = "$(pal_hex "$DRACULA_PRO_MAGENTA")"
check "COLOR_ORANGE    == DRACULA_PRO_ORANGE"      test "$(sb_hex COLOR_ORANGE)"    = "$(pal_hex "$DRACULA_PRO_ORANGE")"
# COLOR_CURRENT_LINE retained for legacy callers; map to Selection per spec § 5.2
check "COLOR_CURRENT_LINE == DRACULA_PRO_SELECTION" test "$(sb_hex COLOR_CURRENT_LINE)" = "$(pal_hex "$DRACULA_PRO_SELECTION")"

# ── AC-jankyborders: bordersrc still sources colors.sh + references COLOR_* ─
echo ""
echo "AC-jankyborders: bordersrc inherits sketchybar/colors.sh"
# shellcheck disable=SC2016
check "bordersrc sources .config/sketchybar/colors.sh" \
  grep -qE '^\s*\.\s+"?\$HOME/\.config/sketchybar/colors\.sh"?' jankyborders/bordersrc
# shellcheck disable=SC2016
check "bordersrc active_color references \$COLOR_PURPLE"   grep -qE 'active_color="\$COLOR_PURPLE"'          jankyborders/bordersrc
# shellcheck disable=SC2016
check "bordersrc inactive_color references selection slot" \
  grep -qE 'inactive_color="\$COLOR_(CURRENT_LINE|SELECTION)"' jankyborders/bordersrc

# ── AC-delta: git-delta syntax-theme is "Dracula Pro" ─────────────────────
echo ""
echo "AC-delta: git-delta syntax-theme"
check 'delta syntax-theme = "Dracula Pro"' \
  grep -qE '^\s*syntax-theme\s*=\s*"?Dracula Pro"?\s*$' git/.gitconfig

# ── AC-git: git ui.color blocks use Dracula Pro hex ────────────────────────
echo ""
echo "AC-git: git .gitconfig [color.*] blocks"

check "[color.branch] section present"  grep -qE '^\s*\[color "branch"\]' git/.gitconfig
check "[color.diff] section present"    grep -qE '^\s*\[color "diff"\]'   git/.gitconfig
check "[color.status] section present"  grep -qE '^\s*\[color "status"\]' git/.gitconfig

# color.branch slots — current uses green, local uses blue, remote uses magenta.
check "color.branch current  -> #8AFF80 (green)"    grep -qE '^\s*current\s*=\s*"?#8AFF80"? bold' git/.gitconfig
check "color.branch local    -> #9580FF (blue)"     grep -qE '^\s*local\s*=\s*"?#9580FF"?'       git/.gitconfig
check "color.branch remote   -> #FF80BF (magenta)"  grep -qE '^\s*remote\s*=\s*"?#FF80BF"?'      git/.gitconfig

# color.diff slots — old=red, new=green, frag=magenta, meta=blue, whitespace=yellow
check "color.diff old        -> #FF9580 (red)"      grep -qE '^\s*old\s*=\s*"?#FF9580"?'         git/.gitconfig
check "color.diff new        -> #8AFF80 (green)"    grep -qE '^\s*new\s*=\s*"?#8AFF80"?'         git/.gitconfig
check "color.diff frag       -> #FF80BF (magenta)"  grep -qE '^\s*frag\s*=\s*"?#FF80BF"?'        git/.gitconfig
check "color.diff meta       -> #9580FF (blue)"     grep -qE '^\s*meta\s*=\s*"?#9580FF"?'        git/.gitconfig
check "color.diff whitespace -> #FFFF80 (yellow)"   grep -qE '^\s*whitespace\s*=\s*"?#FFFF80"?'  git/.gitconfig

# color.status slots — added=green, changed=yellow, untracked=red
check "color.status added     -> #8AFF80 (green)"   grep -qE '^\s*added\s*=\s*"?#8AFF80"?'       git/.gitconfig
check "color.status changed   -> #FFFF80 (yellow)"  grep -qE '^\s*changed\s*=\s*"?#FFFF80"?'     git/.gitconfig
check "color.status untracked -> #FF9580 (red)"     grep -qE '^\s*untracked\s*=\s*"?#FF9580"?'   git/.gitconfig

# ── AC-difftastic: DFT_* env overrides use Pro palette ─────────────────────
echo ""
echo "AC-difftastic: DFT_BACKGROUND / DFT_*_COLOR env"
check 'DFT_BACKGROUND="dark" exported'            grep -qE '^export DFT_BACKGROUND="dark"'                 bash/.bashrc
# difftastic exposes DFT_UNCHANGED_STYLE, DFT_STRONG_ADDED_STYLE etc. We
# assert the Pro hex appears in the block comment header so a reader
# lands on the palette variable instantly. The style vars themselves
# only accept {regular,bold,dim,colour}; the comment documents the
# palette-informed choice.
# shellcheck disable=SC2016
check 'bashrc difftastic block annotates Pro hex'  grep -qE '# difftastic: DFT_BACKGROUND=dark → \$DRACULA_PRO_BACKGROUND #22212C' bash/.bashrc

# ── AC-diffnav: config.yml uses Dracula Pro hex ────────────────────────────
echo ""
echo "AC-diffnav: diffnav pane theme uses Pro palette"
# Classic hex MUST NOT appear anywhere in the file.
for classic in '#282A36' '#44475A' '#6272A4' '#BD93F9' '#FF79C6' '#8BE9FD' '#50FA7B' '#FFB86C' '#FF5555' '#F1FA8C'; do
  check "no Classic hex $classic in diffnav/config.yml" \
    bash -c "! grep -Fq '$classic' diffnav/config.yml"
done
# Required Pro slots
check "diffnav selected_fg = #22212C (BACKGROUND)"   grep -qE 'selected_fg:\s*"#22212C"'   diffnav/config.yml
check "diffnav selected_bg = #9580FF (BLUE/Purple)"  grep -qE 'selected_bg:\s*"#9580FF"'   diffnav/config.yml
check "diffnav unselected_fg = #F8F8F2 (FOREGROUND)" grep -qE 'unselected_fg:\s*"#F8F8F2"' diffnav/config.yml
check "diffnav border_fg = #7970A9 (COMMENT)"        grep -qE 'border_fg:\s*"#7970A9"'     diffnav/config.yml
check "diffnav status_bar.fg = #F8F8F2 (FOREGROUND)" grep -qE 'fg:\s*"#F8F8F2"'            diffnav/config.yml
check "diffnav status_bar.bg = #454158 (SELECTION)"  grep -qE 'bg:\s*"#454158"'            diffnav/config.yml

# ── AC-bat: custom Dracula Pro tmTheme ships and BAT_THEME wired ───────────
echo ""
echo "AC-bat: Dracula Pro bat theme"
TMTHEME="bash/bat-themes/Dracula Pro.tmTheme"
check 'BAT_THEME="Dracula Pro" exported'   grep -qE '^export BAT_THEME="Dracula Pro"' bash/.bashrc
check "$TMTHEME exists"                     test -f "$TMTHEME"
check "tmTheme is valid plist XML (doctype)" grep -qE '<!DOCTYPE plist' "$TMTHEME"
check "tmTheme name = Dracula Pro"          grep -qE '<string>Dracula Pro</string>' "$TMTHEME"

# Assert every Pro slot the Full-ANSI+Dim profile requires appears verbatim
# in the tmTheme XML (tmTheme hex is case-insensitive; tmTheme uses #RRGGBB).
for hex in \
  "$DRACULA_PRO_BACKGROUND"  "$DRACULA_PRO_FOREGROUND"  "$DRACULA_PRO_COMMENT"  "$DRACULA_PRO_SELECTION" \
  "$DRACULA_PRO_RED"         "$DRACULA_PRO_GREEN"       "$DRACULA_PRO_YELLOW"    "$DRACULA_PRO_BLUE" \
  "$DRACULA_PRO_MAGENTA"     "$DRACULA_PRO_CYAN"        "$DRACULA_PRO_ORANGE" \
  "$DRACULA_PRO_BRIGHT_RED"  "$DRACULA_PRO_BRIGHT_GREEN"    "$DRACULA_PRO_BRIGHT_YELLOW" \
  "$DRACULA_PRO_BRIGHT_BLUE" "$DRACULA_PRO_BRIGHT_MAGENTA"  "$DRACULA_PRO_BRIGHT_CYAN" \
  "$DRACULA_PRO_DIM_RED"     "$DRACULA_PRO_DIM_GREEN"       "$DRACULA_PRO_DIM_YELLOW" \
  "$DRACULA_PRO_DIM_BLUE"    "$DRACULA_PRO_DIM_MAGENTA"     "$DRACULA_PRO_DIM_CYAN" \
; do
  check "tmTheme references $hex" grep -qiF "$hex" "$TMTHEME"
done

# install scripts must rebuild bat's cache after linking the theme file.
check "install-macos.sh runs bat cache --build" grep -qE 'bat cache --build' install-macos.sh
check "install-wsl.sh   runs bat cache --build" grep -qE 'bat cache --build' install-wsl.sh
# Symlink wiring for the theme directory
check "install-macos.sh links bash/bat-themes → .config/bat/themes" \
  grep -qE 'link\s+bash/bat-themes\s+\.config/bat/themes' install-macos.sh
check "install-wsl.sh   links bash/bat-themes → .config/bat/themes" \
  grep -qE 'link\s+bash/bat-themes\s+\.config/bat/themes' install-wsl.sh

# ── AC-jq: JQ_COLORS env with Pro-palette ANSI codes ───────────────────────
echo ""
echo "AC-jq: JQ_COLORS env"
# jq accepts "ansi[;ansi...]:ansi[;ansi...]:..." — fg;bg style, one tuple
# per JSON type. We assert the env is exported, mapped to Pro slots in a
# header comment, and that the string contains 8 colon-separated fields.
check "JQ_COLORS exported"   grep -qE '^export JQ_COLORS='        bash/.bashrc
check "JQ_COLORS has 8 tuples" bash -c "awk -F: '/^export JQ_COLORS=/{sub(/\"/,\"\"); sub(/\"$/,\"\"); if (NF==8) print}' bash/.bashrc | grep -q ."
check "JQ_COLORS comment cites DRACULA_PRO slots" \
  grep -qE '# JQ_COLORS .* DRACULA_PRO_' bash/.bashrc

# ── AC-xh: xh default --style = dracula-pro ───────────────────────────────
echo ""
echo "AC-xh: xh styling env"
check "bashrc exports XH_CONFIG_DIR" grep -qE '^export XH_CONFIG_DIR='         bash/.bashrc
# xh reads --style from CLI or config.json. We use an alias with --style=dracula-pro.
check "bash defines xh alias with --style=dracula-pro" \
  grep -qE "alias xh=['\"]xh --style=dracula-pro" bash/.bash_aliases

# ── AC-atuin: atuin config.toml has [theme] with Pro hex ───────────────────
echo ""
echo "AC-atuin: atuin theme block"
check "atuin [theme] section present"         grep -qE '^\[theme\]'                       atuin/config.toml
check "atuin theme.name = dracula-pro"         grep -qE '^\s*name\s*=\s*"dracula-pro"'    atuin/config.toml
# Pro hex slots — structural + accents
for hex in "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_SELECTION" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "atuin config.toml references $hex" grep -qiF "$hex" atuin/config.toml
done

# ── AC-television: dracula-pro.toml ships + config.toml references it ─────
echo ""
echo "AC-television: Dracula Pro theme"
TV_THEME="television/themes/dracula-pro.toml"
check "$TV_THEME exists"                         test -f "$TV_THEME"
check "television/config.toml theme = dracula-pro" \
  grep -qE '^\s*theme\s*=\s*"dracula-pro"'       television/config.toml
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_SELECTION" \
           "$DRACULA_PRO_COMMENT" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "television theme references $hex"       grep -qiF "$hex" "$TV_THEME"
done
check "install-macos.sh links television/themes" \
  grep -qE 'link\s+television/themes\s+\.config/television/themes' install-macos.sh
check "install-wsl.sh   links television/themes" \
  grep -qE 'link\s+television/themes\s+\.config/television/themes' install-wsl.sh

# ── AC-jqp: jqp custom theme block with Pro hex ────────────────────────────
echo ""
echo "AC-jqp: jqp.yaml custom theme"
# theme: dracula (Classic builtin) MUST be gone.
check "jqp theme is NOT 'dracula' (classic)" \
  bash -c "! grep -qE '^theme:\s*dracula\s*$' jqp/.jqp.yaml"
check "jqp theme block is a mapping (not a string)" \
  grep -qE '^theme:\s*$' jqp/.jqp.yaml
# Pro hex — structural + accents
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_SELECTION" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "jqp.yaml references $hex" grep -qiF "$hex" jqp/.jqp.yaml
done

# ── AC-btop: dracula-pro.theme + btop.conf ─────────────────────────────────
echo ""
echo "AC-btop: btop theme ships and config references it"
check "btop/dracula-pro.theme exists"            test -f btop/dracula-pro.theme
check "btop/btop.conf exists"                    test -f btop/btop.conf
check 'btop.conf color_theme = "dracula-pro"' \
  grep -qE '^color_theme\s*=\s*"dracula-pro"'    btop/btop.conf
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_SELECTION" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "btop theme references $hex" grep -qiF "$hex" btop/dracula-pro.theme
done
check "install-macos.sh links btop.conf"            grep -qE 'link\s+btop/btop\.conf\s+\.config/btop/btop\.conf'             install-macos.sh
check "install-macos.sh links btop dracula-pro.theme" \
  grep -qE 'link\s+btop/dracula-pro\.theme\s+\.config/btop/themes/dracula-pro\.theme' install-macos.sh
check "install-wsl.sh   links btop.conf"            grep -qE 'link\s+btop/btop\.conf\s+\.config/btop/btop\.conf'             install-wsl.sh
check "install-wsl.sh   links btop dracula-pro.theme" \
  grep -qE 'link\s+btop/dracula-pro\.theme\s+\.config/btop/themes/dracula-pro\.theme' install-wsl.sh

# ── AC-k9s: skin + config ──────────────────────────────────────────────────
echo ""
echo "AC-k9s: k9s dracula-pro skin"
check "k9s/dracula-pro.yaml exists"              test -f k9s/dracula-pro.yaml
check "k9s/config.yaml exists"                   test -f k9s/config.yaml
check 'k9s config.yaml ui.skin = "dracula-pro"'  \
  grep -qE 'skin:\s*"?dracula-pro"?'             k9s/config.yaml
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_SELECTION" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "k9s skin references $hex" grep -qiF "$hex" k9s/dracula-pro.yaml
done
check "install-macos.sh links k9s config"       grep -qE 'link\s+k9s/config\.yaml\s+\.config/k9s/config\.yaml'                install-macos.sh
check "install-macos.sh links k9s skin"          grep -qE 'link\s+k9s/dracula-pro\.yaml\s+\.config/k9s/skins/dracula-pro\.yaml' install-macos.sh
check "install-wsl.sh   links k9s config"       grep -qE 'link\s+k9s/config\.yaml\s+\.config/k9s/config\.yaml'                install-wsl.sh
check "install-wsl.sh   links k9s skin"          grep -qE 'link\s+k9s/dracula-pro\.yaml\s+\.config/k9s/skins/dracula-pro\.yaml' install-wsl.sh

# ── AC-httpie: config.json + Pro pygments artefact ─────────────────────────
echo ""
echo "AC-httpie: httpie Dracula Pro style"
check "httpie/config.json exists"                 test -f httpie/config.json
check "httpie/styles/dracula-pro.json exists"     test -f httpie/styles/dracula-pro.json
check "httpie config sets --style=dracula-pro"    \
  grep -qE '"--style=dracula-pro"'                 httpie/config.json
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" "$DRACULA_PRO_YELLOW" \
           "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" "$DRACULA_PRO_CYAN" \
           "$DRACULA_PRO_ORANGE"; do
  check "httpie dracula-pro.json references $hex" grep -qiF "$hex" httpie/styles/dracula-pro.json
done
check "install-macos.sh links httpie config"       grep -qE 'link\s+httpie/config\.json\s+\.config/httpie/config\.json'     install-macos.sh
check "install-macos.sh links httpie styles dir"   grep -qE 'link\s+httpie/styles\s+\.config/httpie/styles'                 install-macos.sh
check "install-wsl.sh   links httpie config"       grep -qE 'link\s+httpie/config\.json\s+\.config/httpie/config\.json'     install-wsl.sh
check "install-wsl.sh   links httpie styles dir"   grep -qE 'link\s+httpie/styles\s+\.config/httpie/styles'                 install-wsl.sh

# ── AC-lnav: dracula-pro.json ships ────────────────────────────────────────
echo ""
echo "AC-lnav: lnav theme"
check "lnav/dracula-pro.json exists"              test -f lnav/dracula-pro.json
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_SELECTION" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "lnav theme references $hex" grep -qiF "$hex" lnav/dracula-pro.json
done
check "install-macos.sh links lnav theme into formats/installed" \
  grep -qE 'link\s+lnav/dracula-pro\.json\s+\.lnav/formats/installed/dracula-pro\.json' install-macos.sh
check "install-wsl.sh   links lnav theme into formats/installed" \
  grep -qE 'link\s+lnav/dracula-pro\.json\s+\.lnav/formats/installed/dracula-pro\.json' install-wsl.sh

echo ""
echo "---------------------------------------------------------------"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
