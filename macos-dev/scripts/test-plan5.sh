#!/usr/bin/env bash
# test-plan5.sh — smoke tests for Plan 5 (tmux configuration)
#
# Validates:
#   - .tmux.conf exists
#   - Server/session settings (terminal, escape-time, history, mouse, base-index)
#   - Prefix key is Ctrl+A (Ctrl+B unbound)
#   - Split creation preserves cwd
#   - Pane navigation with vi keys
#   - Pane resizing (repeatable)
#   - Copy mode (vi keys, OSC 52 clipboard)
#   - vim-tmux-navigator with pgrep fallback
#   - Workarounds (Ctrl+L, last-window)
#   - Status bar styling
#   - Install scripts have correct link() mapping
#   - Plans 2–4 link() calls are preserved (regression)
#
# Usage: bash scripts/test-plan5.sh
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

echo "Plan 5: tmux configuration smoke tests"
echo ""

# ── File existence ─────────────────────────────────────────────────────────
echo "File existence:"
check ".tmux.conf exists"  test -f "$REPO_ROOT/tmux/.tmux.conf"

# ── Server and session settings ───────────────────────────────────────────
echo ""
echo "Server and session settings:"
check "default-terminal = tmux-256color"  grep -q 'default-terminal.*tmux-256color' "$REPO_ROOT/tmux/.tmux.conf"
check "terminal-overrides RGB for kitty"  grep -q 'terminal-overrides.*xterm-kitty:RGB' "$REPO_ROOT/tmux/.tmux.conf"
# escape-time + history-limit are now provided by tmux-plugins/tmux-sensible (1b-ii)
check "escape-time delegated to tmux-sensible (1b-ii)" \
  bash -c "grep -qE \"^set -g @plugin 'tmux-plugins/tmux-sensible'\" \"$REPO_ROOT/tmux/.tmux.conf\""
check "history-limit delegated to tmux-sensible (1b-ii)" \
  bash -c "! grep -qE 'set -g history-limit 50000' \"$REPO_ROOT/tmux/.tmux.conf\""
check "mouse = on"                       grep -q 'mouse.*on' "$REPO_ROOT/tmux/.tmux.conf"
check "base-index = 1"                   grep -q 'base-index.*1' "$REPO_ROOT/tmux/.tmux.conf"
check "pane-base-index = 1"              grep -q 'pane-base-index.*1' "$REPO_ROOT/tmux/.tmux.conf"
check "renumber-windows = on"            grep -q 'renumber-windows.*on' "$REPO_ROOT/tmux/.tmux.conf"

# ── Prefix key ────────────────────────────────────────────────────────────
echo ""
echo "Prefix key:"
check "unbind C-b"                       grep -q 'unbind C-b' "$REPO_ROOT/tmux/.tmux.conf"
check "prefix C-a"                       grep -q 'prefix C-a' "$REPO_ROOT/tmux/.tmux.conf"
check "send-prefix"                      grep -q 'send-prefix' "$REPO_ROOT/tmux/.tmux.conf"

# ── Split creation ────────────────────────────────────────────────────────
echo ""
echo "Split creation:"
check "vertical split with |"            grep -q 'bind |.*split-window -h' "$REPO_ROOT/tmux/.tmux.conf"
check "horizontal split with -"          grep -q 'bind -.*split-window -v' "$REPO_ROOT/tmux/.tmux.conf"
check "splits preserve cwd"              grep -q 'pane_current_path' "$REPO_ROOT/tmux/.tmux.conf"

# ── Pane navigation ──────────────────────────────────────────────────────
echo ""
echo "Pane navigation:"
check "bind h select-pane -L"            grep -q 'bind h select-pane -L' "$REPO_ROOT/tmux/.tmux.conf"
check "bind j select-pane -D"            grep -q 'bind j select-pane -D' "$REPO_ROOT/tmux/.tmux.conf"
check "bind k select-pane -U"            grep -q 'bind k select-pane -U' "$REPO_ROOT/tmux/.tmux.conf"
check "bind l select-pane -R"            grep -q 'bind l select-pane -R' "$REPO_ROOT/tmux/.tmux.conf"

# ── Pane resizing ─────────────────────────────────────────────────────────
echo ""
echo "Pane resizing:"
check "bind -r H resize left 5"          grep -q 'bind -r H resize-pane -L 5' "$REPO_ROOT/tmux/.tmux.conf"
check "bind -r J resize down 5"          grep -q 'bind -r J resize-pane -D 5' "$REPO_ROOT/tmux/.tmux.conf"
check "bind -r K resize up 5"            grep -q 'bind -r K resize-pane -U 5' "$REPO_ROOT/tmux/.tmux.conf"
check "bind -r Right resize right 5"     grep -q 'bind -r Right resize-pane -R 5' "$REPO_ROOT/tmux/.tmux.conf"

# ── Copy mode ─────────────────────────────────────────────────────────────
echo ""
echo "Copy mode:"
check "mode-keys vi"                     grep -q 'mode-keys vi' "$REPO_ROOT/tmux/.tmux.conf"
check "set-clipboard on (OSC 52)"        grep -qE 'set-clipboard[[:space:]]+on' "$REPO_ROOT/tmux/.tmux.conf"
check "bind Enter copy-mode"             grep -q 'bind Enter copy-mode' "$REPO_ROOT/tmux/.tmux.conf"
check "v begins selection"               grep -q 'copy-mode-vi v.*begin-selection' "$REPO_ROOT/tmux/.tmux.conf"
check "y copies and cancels"             grep -q 'copy-mode-vi y.*copy-selection-and-cancel' "$REPO_ROOT/tmux/.tmux.conf"
check "Escape cancels copy mode"         grep -q 'copy-mode-vi Escape.*cancel' "$REPO_ROOT/tmux/.tmux.conf"

# ── Session and config management ─────────────────────────────────────────
echo ""
echo "Session and config management:"
check "bind s choose-session"            grep -q 'bind s choose-session' "$REPO_ROOT/tmux/.tmux.conf"
check "bind r source-file ~/.tmux.conf"  grep -q 'bind r source-file.*tmux.conf' "$REPO_ROOT/tmux/.tmux.conf"

# ── vim-tmux-navigator ────────────────────────────────────────────────────
echo ""
echo "vim-tmux-navigator:"
check "is_vim ps detection"              grep -q 'ps -o state=.*comm=' "$REPO_ROOT/tmux/.tmux.conf"
check "is_vim pgrep fallback"            grep -q 'pgrep -t' "$REPO_ROOT/tmux/.tmux.conf"
check "C-h navigator binding"            grep -q "bind-key -n 'C-h'" "$REPO_ROOT/tmux/.tmux.conf"
check "C-j navigator binding"            grep -q "bind-key -n 'C-j'" "$REPO_ROOT/tmux/.tmux.conf"
check "C-k navigator binding"            grep -q "bind-key -n 'C-k'" "$REPO_ROOT/tmux/.tmux.conf"
check "C-l navigator binding"            grep -q "bind-key -n 'C-l'" "$REPO_ROOT/tmux/.tmux.conf"

# ── Workarounds ───────────────────────────────────────────────────────────
echo ""
echo "Workarounds:"
check "bind C-l send-keys C-l"           grep -q 'bind C-l send-keys C-l' "$REPO_ROOT/tmux/.tmux.conf"
check "bind L last-window"               grep -q 'bind L last-window' "$REPO_ROOT/tmux/.tmux.conf"

# ── Status bar (Layer 1b-ii: now provided by dracula/tmux plugin) ─────────
echo ""
echo "Status bar (dracula/tmux plugin, 1b-ii):"
check "dracula plugin declared"          grep -q "^set -g @plugin 'dracula/tmux'" "$REPO_ROOT/tmux/.tmux.conf"
check "@dracula-plugins 'git time'"      grep -qE '@dracula-plugins +"git time"' "$REPO_ROOT/tmux/.tmux.conf"
check "@dracula-show-left-icon session"  grep -qE '@dracula-show-left-icon +session' "$REPO_ROOT/tmux/.tmux.conf"
check "@dracula-military-time true"      grep -qE '@dracula-military-time +true' "$REPO_ROOT/tmux/.tmux.conf"
check "@dracula-show-powerline true"     grep -qE '@dracula-show-powerline +true' "$REPO_ROOT/tmux/.tmux.conf"
check "old catppuccin colors removed"    bash -c "! grep -qE '#1e1e2e|#89b4fa|#cdd6f4' \"$REPO_ROOT/tmux/.tmux.conf\""

# ── Install script link() calls ──────────────────────────────────────────
echo ""
echo "Install scripts:"
check "macos: .tmux.conf mapping"        grep -q 'link tmux/.tmux.conf.*\.tmux.conf' "$REPO_ROOT/install-macos.sh"
check "wsl: .tmux.conf mapping"          grep -q 'link tmux/.tmux.conf.*\.tmux.conf' "$REPO_ROOT/install-wsl.sh"

# Regression: Plans 2–4 link() calls preserved
check "macos: bash links preserved"      test "$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: git links preserved"       test "$(grep -c 'link git/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "macos: kitty links preserved (kitty.conf + dracula-pro.conf, 1b-ii)"  test "$(grep -c 'link kitty/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "wsl: bash links preserved"        test "$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: git links preserved"         test "$(grep -c 'link git/' "$REPO_ROOT/install-wsl.sh")" -eq 2
check "wsl: kitty links preserved (kitty.conf + dracula-pro.conf, 1b-ii)"    test "$(grep -c 'link kitty/' "$REPO_ROOT/install-wsl.sh")" -eq 2

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Current count: 53 tests. Floor should be within ~10% of actual.
if (( total < 48 )); then
  echo "WARNING: only $total tests ran (expected >= 48). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
