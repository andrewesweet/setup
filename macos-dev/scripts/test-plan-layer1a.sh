#!/usr/bin/env bash
# test-plan-layer1a.sh — acceptance tests for Layer 1a (atuin + television + starship Dracula)
#
# Platform-aware: runs on macOS and WSL2/Linux.
#
# Usage:
#   bash scripts/test-plan-layer1a.sh              # safe tests only
#   bash scripts/test-plan-layer1a.sh --full       # + invasive tests (bash -lc init checks)
#
# Each AC from the Layer 1a plan is implemented as a labelled check.
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

echo "Layer 1a acceptance tests (atuin + television + Dracula starship)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1: Brewfile installs atuin and television ──────────────────────────
echo "AC-1: Brewfile installs atuin and television"
check "Brewfile has brew \"atuin\""          grep -qE '^\s*brew\s+"atuin"' Brewfile
check "Brewfile has brew \"television\""     grep -qE '^\s*brew\s+"television"' Brewfile
if [[ "$FULL" == true ]]; then
  check "atuin is on PATH"                   command -v atuin
  check "television (tv) is on PATH"         command -v tv
else
  skp "atuin on PATH" "safe mode"
  skp "tv on PATH" "safe mode"
fi

# ── AC-2: tools.txt is consistent with Brewfile ─────────────────────────
echo ""
echo "AC-2: tools.txt manifest consistency"
check "check-tool-manifest.sh passes"        bash scripts/check-tool-manifest.sh

# ── AC-4: atuin auto_sync = false ─────────────────────────────────────────
echo ""
echo "AC-4: atuin config disables sync"
check "atuin/config.toml exists"             test -f atuin/config.toml
check "auto_sync = false"                    grep -qE '^\s*auto_sync\s*=\s*false' atuin/config.toml

# ── AC-5: history_filter covers token/secret prefixes ───────────────────
echo ""
echo "AC-5: atuin history_filter coverage"
for pat in GITHUB_TOKEN GH_TOKEN SECRET PASSWORD BEARER AUTHORIZATION \
           AWS_ACCESS AWS_SECRET AWS_SESSION ANTHROPIC OPENAI \
           'ghp_' 'gho_' 'github_pat_' 'glpat-' 'sk-' 'xoxb-' 'xoxp-'; do
  check "history_filter contains pattern '$pat'" \
    bash -c "awk '/^history_filter = \[/,/^\]/' atuin/config.toml | grep -Fq '$pat'"
done

# ── AC-7: television does NOT claim Ctrl-R ────────────────────────────────
echo ""
echo "AC-7: television shell integration owns Ctrl-T only"
check "television/config.toml exists"         test -f television/config.toml
check "smart_autocomplete = ctrl-t present"   \
  grep -qE 'smart_autocomplete\s*=\s*"ctrl-t"' television/config.toml
check "command_history key is ABSENT"         \
  bash -c "! grep -qE 'command_history\s*=' television/config.toml"

# ── AC-10: Starship uses Dracula palette ──────────────────────────────────
echo ""
echo "AC-10: Starship Dracula palette"
check "starship palette = dracula"            \
  grep -qE '^palette\s*=\s*"dracula"' starship/starship.toml
check "[palettes.dracula] table exists"       \
  grep -qE '^\[palettes\.dracula\]' starship/starship.toml
for color in background current_line foreground comment cyan green orange pink purple red yellow; do
  check "palette has '$color'"                \
    grep -qE "^$color\s*=" starship/starship.toml
done

# ── AC-8: atuin init is opt-in via ENABLE_ATUIN ───────────────────────────
echo ""
echo "AC-8: atuin bash init gated behind ENABLE_ATUIN"
check "bash/.bashrc mentions ENABLE_ATUIN"    grep -q 'ENABLE_ATUIN' bash/.bashrc
# Structural multiline match: must find an `if` that gates on ENABLE_ATUIN and
# wraps `atuin init bash` before the closing `fi`. Comments alone cannot match.
check "atuin init is guarded by if/fi block" \
  bash -c "grep -Pzo '(?s)if[^\n]*ENABLE_ATUIN[^\n]*==[^\n]*1[^\n]*\n[^\n]*atuin init bash[^\n]*\nfi' bash/.bashrc | grep -q ."

if [[ "$FULL" == true ]] && command -v atuin &>/dev/null; then
  # Spawn an interactive-ish bash with ENABLE_ATUIN unset
  unset_out="$(ENABLE_ATUIN= bash --rcfile bash/.bashrc -ic 'bind -P 2>/dev/null | grep "^reverse-search-history" || true' 2>/dev/null)"
  if printf '%s' "$unset_out" | grep -q 'reverse-search-history'; then
    ok "with ENABLE_ATUIN unset: Ctrl-R is default readline"
  else
    nok "with ENABLE_ATUIN unset: Ctrl-R is default readline"
  fi

  set_out="$(ENABLE_ATUIN=1 bash --rcfile bash/.bashrc -ic 'bind -P 2>/dev/null | grep "C-r" || true' 2>/dev/null)"
  if printf '%s' "$set_out" | grep -qi 'atuin\|_atuin'; then
    ok "with ENABLE_ATUIN=1: Ctrl-R is rebound"
  else
    nok "with ENABLE_ATUIN=1: Ctrl-R is rebound"
  fi
else
  skp "with ENABLE_ATUIN unset: Ctrl-R default" "requires --full + atuin installed"
  skp "with ENABLE_ATUIN=1: Ctrl-R rebound"    "requires --full + atuin installed"
fi

# ── AC-9: television init is opt-in via ENABLE_TV ─────────────────────────
echo ""
echo "AC-9: television bash init gated behind ENABLE_TV"
check "bash/.bashrc mentions ENABLE_TV"       grep -q 'ENABLE_TV' bash/.bashrc
# Structural multiline match: must find an `if` that gates on ENABLE_TV and
# wraps `tv init bash` before the closing `fi`. Comments alone cannot match.
check "tv init is guarded by if/fi block" \
  bash -c "grep -Pzo '(?s)if[^\n]*ENABLE_TV[^\n]*==[^\n]*1[^\n]*\n[^\n]*tv init bash[^\n]*\nfi' bash/.bashrc | grep -q ."

# ── AC-3 + AC-6: atuin and television configs are symlinked ─────────────
echo ""
echo "AC-3 + AC-6: install script creates atuin + television symlinks"
check "install-macos.sh links atuin config"      \
  grep -qE 'link\s+atuin/config\.toml\s+\.config/atuin/config\.toml' install-macos.sh
check "install-macos.sh links television config" \
  grep -qE 'link\s+television/config\.toml\s+\.config/television/config\.toml' install-macos.sh

if [[ "$FULL" == true ]]; then
  # Check actual symlinks — only meaningful after install-macos.sh has run
  if [[ -L "$HOME/.config/atuin/config.toml" ]]; then
    actual="$(readlink "$HOME/.config/atuin/config.toml")"
    expected="$MACOS_DEV/atuin/config.toml"
    if [[ "$actual" == "$expected" ]]; then
      ok "~/.config/atuin/config.toml → \$DOTFILES/atuin/config.toml"
    else
      nok "~/.config/atuin/config.toml → \$DOTFILES/atuin/config.toml (got: $actual)"
    fi
  else
    skp "~/.config/atuin/config.toml symlink" "install not yet run"
  fi
  if [[ -L "$HOME/.config/television/config.toml" ]]; then
    actual="$(readlink "$HOME/.config/television/config.toml")"
    expected="$MACOS_DEV/television/config.toml"
    if [[ "$actual" == "$expected" ]]; then
      ok "~/.config/television/config.toml → \$DOTFILES/television/config.toml"
    else
      nok "~/.config/television/config.toml → \$DOTFILES/television/config.toml (got: $actual)"
    fi
  else
    skp "~/.config/television/config.toml symlink" "install not yet run"
  fi
else
  skp "~/.config/atuin/config.toml symlink" "safe mode"
  skp "~/.config/television/config.toml symlink" "safe mode"
fi

# ── AC-12: --restore reverts Layer 1a symlinks ────────────────────────────
echo ""
echo "AC-12: install --restore handles atuin + television"
# Static check: restore() iterates the backup dir, which will include any
# file that had an original non-symlink replaced. We verify by checking the
# restore() function does not hardcode a path list that excludes our new ones.
check "restore() walks backup dir dynamically" \
  grep -qE 'find.*-type' install-macos.sh
# Full mode: actually run install + restore would be destructive.
# We document the manual verification path instead.
if [[ "$FULL" == true ]]; then
  skp "install + restore round-trip" "destructive — requires manual verification"
fi

# ── AC-11 etc. — stubs to be filled by later tasks ──────────────────────
# (Placeholders for each AC; each will become a real check as features land.)

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
