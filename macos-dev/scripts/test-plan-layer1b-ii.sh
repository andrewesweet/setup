#!/usr/bin/env bash
# test-plan-layer1b-ii.sh — acceptance tests for Layer 1b-ii (tmux + TPM + plugins + Dracula theming)
#
# Platform-aware: runs on macOS and WSL2/Linux.
#
# Usage:
#   bash scripts/test-plan-layer1b-ii.sh              # safe tests only
#   bash scripts/test-plan-layer1b-ii.sh --full       # + invasive tests (bash -lc init checks)
#
# Each AC from the Layer 1b-ii plan is implemented as a labelled check.
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

echo "Layer 1b-ii acceptance tests (tmux plugins + Dracula theming rollout)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1: tmux plugin block present ───────────────────────────────────────
echo "AC-1: tmux.conf plugin block"
for p in 'tmux-plugins/tpm' 'tmux-plugins/tmux-sensible' 'tmux-plugins/tmux-yank' \
         'tmux-plugins/tmux-resurrect' 'tmux-plugins/tmux-continuum' \
         'fcsonline/tmux-thumbs' 'sainnhe/tmux-fzf' 'wfxr/tmux-fzf-url' \
         'omerxx/tmux-sessionx' 'omerxx/tmux-floax' 'dracula/tmux'; do
  check "plugin '$p' declared" grep -qE "^\s*set -g @plugin '$p'" tmux/.tmux.conf
done

# ── AC-2: TPM bootstrap is the last non-comment line ─────────────────────
echo ""
echo "AC-2: TPM bootstrap is last non-comment non-blank line"
last_line="$(awk '!/^[[:space:]]*#/ && NF' tmux/.tmux.conf | tail -1)"
if [[ "$last_line" == "run '~/.tmux/plugins/tpm/tpm'" ]]; then
  ok "TPM bootstrap is last effective line"
else
  nok "TPM bootstrap not last (got: $last_line)"
fi

# ── AC-3: sensible-overlap settings removed ──────────────────────────────
echo ""
echo "AC-3: sensible-overlap settings removed"
check "escape-time 10 is removed"  bash -c "! grep -qE 'set -sg escape-time 10' tmux/.tmux.conf"
check "history-limit 50000 removed" bash -c "! grep -qE 'set -g history-limit 50000' tmux/.tmux.conf"
check "default-terminal tmux-256color KEPT" \
  grep -qE 'set +-g +default-terminal +"tmux-256color"' tmux/.tmux.conf
check "xterm-kitty:RGB override KEPT" \
  grep -qE 'set +-sa +terminal-overrides +",xterm-kitty:RGB"' tmux/.tmux.conf

# ── AC-4: resurrect + continuum ──────────────────────────────────────────
echo ""
echo "AC-4: resurrect + continuum"
check "continuum-restore on"  grep -qE "@continuum-restore +'on'"  tmux/.tmux.conf
check "resurrect-strategy-nvim session" grep -qE "@resurrect-strategy-nvim +'session'" tmux/.tmux.conf

# ── AC-5: clipboard + detach-on-destroy ──────────────────────────────────
echo ""
echo "AC-5: clipboard + session destruction behaviour"
check "set-clipboard on"       grep -qE 'set +-g +set-clipboard +on'       tmux/.tmux.conf
check "detach-on-destroy off"  grep -qE 'set +-g +detach-on-destroy +off'  tmux/.tmux.conf

# ── AC-6: floax ──────────────────────────────────────────────────────────
echo ""
echo "AC-6: floax"
check "@floax-bind 'p'"          grep -qE "@floax-bind +'p'"          tmux/.tmux.conf
check "@floax-width '80%'"       grep -qE "@floax-width +'80%'"       tmux/.tmux.conf
check "@floax-height '80%'"      grep -qE "@floax-height +'80%'"      tmux/.tmux.conf
check "@floax-change-path true"  grep -qE "@floax-change-path +'true'" tmux/.tmux.conf

# ── AC-7: sessionx ───────────────────────────────────────────────────────
echo ""
echo "AC-7: sessionx"
check "@sessionx-bind 'o'"                 grep -qE "@sessionx-bind +'o'"                 tmux/.tmux.conf
check "@sessionx-zoxide-mode 'on'"         grep -qE "@sessionx-zoxide-mode +'on'"         tmux/.tmux.conf
check "@sessionx-window-height '85%'"      grep -qE "@sessionx-window-height +'85%'"      tmux/.tmux.conf
check "@sessionx-window-width '75%'"       grep -qE "@sessionx-window-width +'75%'"       tmux/.tmux.conf
check "@sessionx-filter-current 'false'"   grep -qE "@sessionx-filter-current +'false'"   tmux/.tmux.conf

# ── AC-8: fzf-url ────────────────────────────────────────────────────────
echo ""
echo "AC-8: fzf-url"
check "@fzf-url-history-limit '2000'" grep -qE "@fzf-url-history-limit +'2000'" tmux/.tmux.conf

# ── AC-9: Dracula plugin ─────────────────────────────────────────────────
echo ""
echo "AC-9: Dracula tmux plugin configuration"
check "@dracula-show-powerline true"    grep -qE '@dracula-show-powerline +true'    tmux/.tmux.conf
check '@dracula-plugins "git time"'     grep -qE '@dracula-plugins +"git time"'     tmux/.tmux.conf
check '@dracula-show-left-icon session' grep -qE '@dracula-show-left-icon +session' tmux/.tmux.conf
check '@dracula-military-time true'     grep -qE '@dracula-military-time +true'     tmux/.tmux.conf

# ── AC-10: manual theme removed ──────────────────────────────────────────
echo ""
echo "AC-10: hand-rolled catppuccin theme removed"
check "no status-style bg=#1e1e2e" bash -c "! grep -qE 'status-style.*#1e1e2e'  tmux/.tmux.conf"
check "no window-status-current-style #89b4fa" bash -c "! grep -qE 'window-status-current-style.*#89b4fa' tmux/.tmux.conf"
check "no remaining #1e1e2e or #89b4fa refs"   bash -c "! grep -qE '#1e1e2e|#89b4fa' tmux/.tmux.conf"

# Later tasks append AC-11 through AC-20.

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
