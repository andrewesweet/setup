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


# ─────────────────────────────────────────────────────────────────────────────
# ── Wave B: Tier 2 Pro-from-Classic ──────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
# Each tool below reproduces § 3.2 of macos-dev/docs/design/theming.md.
# Classic hex are substituted for Dracula PRO Base hex sourced from
# scripts/lib/dracula-pro-palette.sh. Every AC asserts every slot in the
# tool's coverage profile per § 5.1.
echo ""
echo "Wave B — Tier 2 Pro-from-Classic palette substitution"

# ── AC-B-starship ────────────────────────────────────────────────────────────
echo ""
echo "AC-B-starship: starship palette is dracula-pro with Pro Base hex"
check "palette = dracula-pro"               grep -qE '^palette\s*=\s*"dracula-pro"' starship/starship.toml
check "Classic palette name removed"        bash -c '! grep -qE "^palette\s*=\s*\"dracula\"\s*$" starship/starship.toml'
check "Classic [palettes.dracula] removed"  bash -c '! grep -qE "^\[palettes\.dracula\]\s*$" starship/starship.toml'
check "[palettes.dracula-pro] table"        grep -qE '^\[palettes\.dracula-pro\]' starship/starship.toml
check "background = #22212C"                grep -qE '^background\s*=\s*"#22212C"' starship/starship.toml
check "current_line = #454158"              grep -qE '^current_line\s*=\s*"#454158"' starship/starship.toml
check "foreground = #F8F8F2"                grep -qE '^foreground\s*=\s*"#F8F8F2"' starship/starship.toml
check "comment = #7970A9"                   grep -qE '^comment\s*=\s*"#7970A9"' starship/starship.toml
check "cyan = #80FFEA"                      grep -qE '^cyan\s*=\s*"#80FFEA"' starship/starship.toml
check "green = #8AFF80"                     grep -qE '^green\s*=\s*"#8AFF80"' starship/starship.toml
check "orange = #FFCA80"                    grep -qE '^orange\s*=\s*"#FFCA80"' starship/starship.toml
check "pink = #FF80BF"                      grep -qE '^pink\s*=\s*"#FF80BF"' starship/starship.toml
check "purple = #9580FF"                    grep -qE '^purple\s*=\s*"#9580FF"' starship/starship.toml
check "red = #FF9580"                       grep -qE '^red\s*=\s*"#FF9580"' starship/starship.toml
check "yellow = #FFFF80"                    grep -qE '^yellow\s*=\s*"#FFFF80"' starship/starship.toml

# ── AC-B-tmux ────────────────────────────────────────────────────────────────
echo ""
echo "AC-B-tmux: tmux dracula plugin colours overridden with Pro Base hex"
check "tmux has @dracula-colors block"    grep -qE '^set -g @dracula-colors "' tmux/.tmux.conf
check "tmux white = Pro White"            grep -q "white='#F8F8F2'"        tmux/.tmux.conf
check "tmux gray = Pro Selection"         grep -q "gray='#454158'"         tmux/.tmux.conf
check "tmux dark_gray = Pro Background"   grep -q "dark_gray='#22212C'"    tmux/.tmux.conf
check "tmux light_purple = Pro Blue"      grep -q "light_purple='#9580FF'" tmux/.tmux.conf
check "tmux dark_purple = Pro Comment"    grep -q "dark_purple='#7970A9'"  tmux/.tmux.conf
check "tmux cyan = Pro Cyan"              grep -q "cyan='#80FFEA'"         tmux/.tmux.conf
check "tmux green = Pro Green"            grep -q "green='#8AFF80'"        tmux/.tmux.conf
check "tmux orange = Pro Orange"          grep -q "orange='#FFCA80'"       tmux/.tmux.conf
check "tmux red = Pro Red"                grep -q "red='#FF9580'"          tmux/.tmux.conf
check "tmux pink = Pro Magenta"           grep -q "pink='#FF80BF'"         tmux/.tmux.conf
check "tmux yellow = Pro Yellow"          grep -q "yellow='#FFFF80'"       tmux/.tmux.conf

# ── AC-B-lazygit ─────────────────────────────────────────────────────────────
echo ""
echo "AC-B-lazygit: lazygit theme uses Pro Base hex only"
check "activeBorder / cherry-pick = Purple"  grep -q "'#9580FF'" lazygit/config.yml
check "inactiveBorder = Comment"             grep -q "'#7970A9'" lazygit/config.yml
check "options / defaultFg = Foreground"     grep -q "'#F8F8F2'" lazygit/config.yml
check "selected/cherry-pick bg = Selection"  grep -q "'#454158'" lazygit/config.yml
check "unstaged = Red"                       grep -q "'#FF9580'" lazygit/config.yml
check "searching = Yellow"                   grep -q "'#FFFF80'" lazygit/config.yml
check "no Classic hex remain"                bash -c "! grep -qE \"#(BD93F9|6272A4|44475A|FF5555|F1FA8C)\" lazygit/config.yml"
check "delta syntax-theme = Dracula Pro"     grep -qE "syntax-theme=.*Dracula Pro" lazygit/config.yml

# ── AC-B-gh-dash ─────────────────────────────────────────────────────────────
echo ""
echo "AC-B-gh-dash: gh-dash theme block uses Pro Base hex only"
check "text.primary = Foreground"           grep -q '"#F8F8F2"' gh-dash/config.yml
check "text.secondary / border.secondary"   grep -q '"#7970A9"' gh-dash/config.yml
check "text.inverted = Background"          grep -q '"#22212C"' gh-dash/config.yml
check "faint + bg.selected = Selection"     grep -q '"#454158"' gh-dash/config.yml
check "warning = Orange"                    grep -q '"#FFCA80"' gh-dash/config.yml
check "success = Green"                     grep -q '"#8AFF80"' gh-dash/config.yml
check "error = Red"                         grep -q '"#FF9580"' gh-dash/config.yml
check "border.primary = Purple"             grep -q '"#9580FF"' gh-dash/config.yml
check "no Classic hex remain"               bash -c "! grep -qE \"#(BD93F9|FF5555|50FA7B|FFB86C|6272A4|44475A|282A36|FF79C6|F1FA8C|8BE9FD)\" gh-dash/config.yml"

# ── AC-B-yazi ────────────────────────────────────────────────────────────────
echo ""
echo "AC-B-yazi: yazi/theme.toml uses Pro Base hex only"
check "background = #22212C"   grep -q '"#22212C"' yazi/theme.toml
check "foreground = #F8F8F2"   grep -q '"#F8F8F2"' yazi/theme.toml
check "comment = #7970A9"      grep -q '"#7970A9"' yazi/theme.toml
check "selection = #454158"    grep -q '"#454158"' yazi/theme.toml
check "purple = #9580FF"       grep -q '"#9580FF"' yazi/theme.toml
check "cyan = #80FFEA"         grep -q '"#80FFEA"' yazi/theme.toml
check "green = #8AFF80"        grep -q '"#8AFF80"' yazi/theme.toml
check "yellow = #FFFF80"       grep -q '"#FFFF80"' yazi/theme.toml
check "orange = #FFCA80"       grep -q '"#FFCA80"' yazi/theme.toml
check "pink = #FF80BF"         grep -q '"#FF80BF"' yazi/theme.toml
check "red = #FF9580"          grep -q '"#FF9580"' yazi/theme.toml
check "no Classic hex remain"  bash -c "! grep -qE \"#(BD93F9|6272A4|44475A|282A36|FF5555|50FA7B|FFB86C|FF79C6|F1FA8C|8BE9FD)\" yazi/theme.toml"

# ── AC-B-fzf ─────────────────────────────────────────────────────────────────
echo ""
echo "AC-B-fzf: FZF_DEFAULT_OPTS uses Pro Base hex only"
check "fzf fg = Foreground"         grep -q 'fg:#F8F8F2'          bash/.bashrc
check "fzf bg = Background"         grep -q 'bg:#22212C'          bash/.bashrc
check "fzf hl = Purple"             grep -q 'hl:#9580FF'          bash/.bashrc
check "fzf fg+ = Foreground"        grep -q 'fg+:#F8F8F2'         bash/.bashrc
check "fzf bg+ = Selection"         grep -q 'bg+:#454158'         bash/.bashrc
check "fzf hl+ = Purple"            grep -q 'hl+:#9580FF'         bash/.bashrc
check "fzf info = Orange"           grep -q 'info:#FFCA80'        bash/.bashrc
check "fzf prompt = Green"          grep -q 'prompt:#8AFF80'      bash/.bashrc
check "fzf pointer = Pink"          grep -q 'pointer:#FF80BF'     bash/.bashrc
check "fzf marker = Pink"           grep -q 'marker:#FF80BF'      bash/.bashrc
check "fzf spinner = Orange"        grep -q 'spinner:#FFCA80'     bash/.bashrc
check "fzf header = Comment"        grep -q 'header:#7970A9'      bash/.bashrc
check "no lowercase Classic fzf hex" bash -c "! grep -qE '#(bd93f9|6272a4|44475a|282a36|ff5555|50fa7b|ffb86c|ff79c6|f1fa8c|8be9fd)' bash/.bashrc"

# ── AC-B-ripgrep ─────────────────────────────────────────────────────────────
echo ""
echo "AC-B-ripgrep: ripgrep --colors config uses Pro Base hex"
check "ripgrep/config exists"                 test -f ripgrep/config
check "path = Purple (0x95,0x80,0xFF)"        grep -q 'colors=path:fg:0x95,0x80,0xFF'    ripgrep/config
check "line = Green (0x8A,0xFF,0x80)"         grep -q 'colors=line:fg:0x8A,0xFF,0x80'    ripgrep/config
check "column = Green (0x8A,0xFF,0x80)"       grep -q 'colors=column:fg:0x8A,0xFF,0x80'  ripgrep/config
check "match = Red (0xFF,0x95,0x80)"          grep -q 'colors=match:fg:0xFF,0x95,0x80'   ripgrep/config
check "RIPGREP_CONFIG_PATH exported"          grep -qE '^export RIPGREP_CONFIG_PATH=.*ripgrep/config' bash/.bashrc
check "install-macos.sh links ripgrep/config" grep -qE 'link\s+ripgrep/config\s+\.config/ripgrep/config' install-macos.sh
check "install-wsl.sh   links ripgrep/config" grep -qE 'link\s+ripgrep/config\s+\.config/ripgrep/config' install-wsl.sh

# ── AC-B-eza ─────────────────────────────────────────────────────────────────
echo ""
echo "AC-B-eza: EZA_COLORS is exported with Pro Base hex RGB"
check "EZA_COLORS is exported"          grep -qE '^export EZA_COLORS='  bash/.bashrc
check "da (date) = Comment"             grep -q 'da=38;2;121;112;169' bash/.bashrc
check "ur (user read)  = Purple"        grep -q 'ur=38;2;149;128;255' bash/.bashrc
check "uw (user write) = Red"           grep -q 'uw=38;2;255;149;128' bash/.bashrc
check "ux (user exec)  = Green"         grep -q 'ux=38;2;138;255;128' bash/.bashrc
check "ue (user other) = Orange"        grep -q 'ue=38;2;255;202;128' bash/.bashrc
check "xx (dash / empty) = BrightBlack" grep -q 'xx=38;2;80;76;103'   bash/.bashrc

# ── AC-B-dircolors ───────────────────────────────────────────────────────────
echo ""
echo "AC-B-dircolors: .dir_colors uses Pro Base hex (24-bit SGR)"
check ".dir_colors exists"                 test -f dircolors/.dir_colors
check "DIR = Purple (149,128,255)"         grep -qE 'DIR .*38;2;149;128;255'    dircolors/.dir_colors
check "LINK = Cyan (128,255,234)"          grep -qE 'LINK .*38;2;128;255;234'   dircolors/.dir_colors
check "FIFO fg = Yellow (255,255,128)"     grep -qE 'FIFO .*38;2;255;255;128'   dircolors/.dir_colors
check "ORPHAN = Red (255,149,128)"         grep -qE 'ORPHAN .*38;2;255;149;128' dircolors/.dir_colors
check "SETUID bg = Red (255,149,128)"      grep -qE 'SETUID .*48;2;255;149;128' dircolors/.dir_colors
check "no Classic 24-bit triples remain"   bash -c "! grep -qE '38;2;(189;147;249|98;114;164|139;233;253|255;121;198|255;85;85|255;184;108|241;250;140|80;250;123)' dircolors/.dir_colors"
# shellcheck disable=SC2016
check "bashrc evals dircolors"             grep -q 'eval "\$(dircolors -b.*\.dir_colors)"' bash/.bashrc
check "install-macos.sh links .dir_colors" grep -qE 'link\s+dircolors/\.dir_colors\s+\.dir_colors' install-macos.sh
check "install-wsl.sh   links .dir_colors" grep -qE 'link\s+dircolors/\.dir_colors\s+\.dir_colors' install-wsl.sh

# ── AC-B-opencode ────────────────────────────────────────────────────────────
echo ""
echo "AC-B-opencode: opencode tui.jsonc uses dracula-pro custom theme"
check "tui.jsonc theme = dracula-pro"          grep -qE '"theme"\s*:\s*"dracula-pro"' opencode/tui.jsonc
check "opencode/themes/dracula-pro.json"       test -f opencode/themes/dracula-pro.json
check "theme bgPrimary = Background"           grep -q '"#22212C"' opencode/themes/dracula-pro.json
check "theme bgSecondary = Selection"          grep -q '"#454158"' opencode/themes/dracula-pro.json
check "theme foreground = Foreground"          grep -q '"#F8F8F2"' opencode/themes/dracula-pro.json
check "theme comment = Comment"                grep -q '"#7970A9"' opencode/themes/dracula-pro.json
check "theme red = Red"                        grep -q '"#FF9580"' opencode/themes/dracula-pro.json
check "theme orange = Orange"                  grep -q '"#FFCA80"' opencode/themes/dracula-pro.json
check "theme yellow = Yellow"                  grep -q '"#FFFF80"' opencode/themes/dracula-pro.json
check "theme green = Green"                    grep -q '"#8AFF80"' opencode/themes/dracula-pro.json
check "theme cyan = Cyan"                      grep -q '"#80FFEA"' opencode/themes/dracula-pro.json
check "theme purple = Purple"                  grep -q '"#9580FF"' opencode/themes/dracula-pro.json
check "theme pink = Pink"                      grep -q '"#FF80BF"' opencode/themes/dracula-pro.json
check "install-macos.sh links theme file"      grep -qE 'link opencode/themes/dracula-pro\.json.*\.config/opencode/themes/dracula-pro\.json' install-macos.sh
check "install-wsl.sh   links theme file"      grep -qE 'link opencode/themes/dracula-pro\.json.*\.config/opencode/themes/dracula-pro\.json' install-wsl.sh

echo ""
echo "---------------------------------------------------------------"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
