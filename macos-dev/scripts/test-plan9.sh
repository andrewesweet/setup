#!/usr/bin/env bash
# test-plan9.sh — smoke tests for Plan 9 (opencode configuration)
#
# Validates:
#   - All four config files exist
#   - opencode.jsonc: model, permissions, security denials, no broad cat/echo
#   - tui.jsonc: leader key, collision-safe half-page bindings
#   - Instruction files: correct content
#   - Install scripts have correct link() mappings
#   - Plans 2–8 link() calls are preserved (regression)
#
# Usage: bash scripts/test-plan9.sh
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

echo "Plan 9: opencode configuration smoke tests"
echo ""

# ── File existence ─────────────────────────────────────────────────────────
echo "File existence:"
check "opencode.jsonc exists"            test -f "$REPO_ROOT/opencode/opencode.jsonc"
check "tui.jsonc exists"                 test -f "$REPO_ROOT/opencode/tui.jsonc"
check "git-conventions.md exists"        test -f "$REPO_ROOT/opencode/instructions/git-conventions.md"
check "scratch-dirs.md exists"           test -f "$REPO_ROOT/opencode/instructions/scratch-dirs.md"

# ── opencode.jsonc — model and provider ───────────────────────────────────
echo ""
echo "opencode.jsonc — model and provider:"
check "model = claude-sonnet-4-6"        grep -q 'github-copilot/claude-sonnet-4-6' "$REPO_ROOT/opencode/opencode.jsonc"
check "small_model = gpt-4o-mini"        grep -q 'github-copilot/gpt-4o-mini' "$REPO_ROOT/opencode/opencode.jsonc"
check "2 github-copilot model refs"      test "$(grep -c 'github-copilot' "$REPO_ROOT/opencode/opencode.jsonc")" -eq 2

# ── opencode.jsonc — permissions ──────────────────────────────────────────
echo ""
echo "opencode.jsonc — permissions:"
check "global default = ask"             grep -qF '"*": "ask"' "$REPO_ROOT/opencode/opencode.jsonc"
check "grep = allow"                     grep -qF '"grep": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "glob = allow"                     grep -qF '"glob": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "list = allow"                     grep -qF '"list": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "skill = allow"                    grep -qF '"skill": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "todowrite = allow"               grep -qF '"todowrite": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "webfetch = ask"                   grep -qF '"webfetch": "ask"' "$REPO_ROOT/opencode/opencode.jsonc"
check "websearch = ask"                  grep -qF '"websearch": "ask"' "$REPO_ROOT/opencode/opencode.jsonc"
check "doom_loop = ask"                  grep -qF '"doom_loop": "ask"' "$REPO_ROOT/opencode/opencode.jsonc"

# ── opencode.jsonc — read scoping ─────────────────────────────────────────
echo ""
echo "opencode.jsonc — read scoping:"
check "read ~/workspace/** allow"        grep -q 'workspace/\*\*.*allow' "$REPO_ROOT/opencode/opencode.jsonc"
check "read /tmp/** allow"               grep -q '/tmp/\*\*.*allow' "$REPO_ROOT/opencode/opencode.jsonc"
check "read opencode config allow"       grep -q 'opencode/\*\*.*allow' "$REPO_ROOT/opencode/opencode.jsonc"
check "read mise config allow"           grep -q 'mise/\*\*.*allow' "$REPO_ROOT/opencode/opencode.jsonc"

# ── opencode.jsonc — bash permissions ─────────────────────────────────────
echo ""
echo "opencode.jsonc — bash permissions:"
check "git status allow"                 grep -qF '"git status *": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "git diff allow"                   grep -qF '"git diff *": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "git log allow"                    grep -qF '"git log *": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "rg allow"                         grep -qF '"rg *": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "fd allow"                         grep -qF '"fd *": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "cat scoped to workspace"          grep -qF '"cat /home/dev/workspace/*": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "cat scoped to tmp"               grep -qF '"cat /tmp/*": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "git show allow"                   grep -qF '"git show *": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "git branch allow"                 grep -qF '"git branch *": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "ls allow"                         grep -qF '"ls *": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "bat scoped to workspace"          grep -qF '"bat /home/dev/workspace/*": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"

# ── opencode.jsonc — security denials ─────────────────────────────────────
echo ""
echo "opencode.jsonc — security denials:"
check "rm -rf /tmp/opencode-* allow"     grep -qF '"rm -rf /tmp/opencode-*": "allow"' "$REPO_ROOT/opencode/opencode.jsonc"
check "rm -rf denied"                    grep -qF '"rm -rf *": "deny"' "$REPO_ROOT/opencode/opencode.jsonc"
check "rm -fr denied"                    grep -qF '"rm -fr *": "deny"' "$REPO_ROOT/opencode/opencode.jsonc"
check "sudo denied"                      grep -qF '"sudo *": "deny"' "$REPO_ROOT/opencode/opencode.jsonc"
check "chmod 777 denied"                 grep -qF '"chmod 777 *": "deny"' "$REPO_ROOT/opencode/opencode.jsonc"

# MUST NOT have broad cat or echo allow (security.md)
if grep -q '"cat \*".*allow' "$REPO_ROOT/opencode/opencode.jsonc"; then
  nok "no broad cat * allow (security)"
else
  ok "no broad cat * allow (security)"
fi

if grep -q '"echo \*".*allow' "$REPO_ROOT/opencode/opencode.jsonc"; then
  nok "no echo * allow (security)"
else
  ok "no echo * allow (security)"
fi

# ── opencode.jsonc — sharing and updates ──────────────────────────────────
echo ""
echo "opencode.jsonc — sharing and updates:"
check "share = disabled"                 grep -qF '"share": "disabled"' "$REPO_ROOT/opencode/opencode.jsonc"
check "autoupdate = false"               grep -q 'autoupdate.*false' "$REPO_ROOT/opencode/opencode.jsonc"

# ── opencode.jsonc — instruction paths ────────────────────────────────────
echo ""
echo "opencode.jsonc — instruction paths:"
check "git-conventions instruction"      grep -q 'git-conventions.md' "$REPO_ROOT/opencode/opencode.jsonc"
check "scratch-dirs instruction"         grep -q 'scratch-dirs.md' "$REPO_ROOT/opencode/opencode.jsonc"

# ── tui.jsonc ─────────────────────────────────────────────────────────────
echo ""
echo "tui.jsonc — keybindings:"
check "leader = ctrl+x"                 grep -qF '"leader": "ctrl+x"' "$REPO_ROOT/opencode/tui.jsonc"
check "half_page_up = ctrl+alt+u"        grep -qF '"messages_half_page_up": "ctrl+alt+u"' "$REPO_ROOT/opencode/tui.jsonc"
check "half_page_down = ctrl+alt+d"      grep -qF '"messages_half_page_down": "ctrl+alt+d"' "$REPO_ROOT/opencode/tui.jsonc"
check "session_interrupt = escape"       grep -qF '"session_interrupt": "escape"' "$REPO_ROOT/opencode/tui.jsonc"
check "command_list = ctrl+p"            grep -qF '"command_list": "ctrl+p"' "$REPO_ROOT/opencode/tui.jsonc"
check "agent_cycle = tab"               grep -qF '"agent_cycle": "tab"' "$REPO_ROOT/opencode/tui.jsonc"
check "session_new = leader+n"          grep -qF '"session_new": "<leader>n"' "$REPO_ROOT/opencode/tui.jsonc"
check "session_list = leader+L"         grep -qF '"session_list": "<leader>L"' "$REPO_ROOT/opencode/tui.jsonc"
check "session_export = leader+X"       grep -qF '"session_export": "<leader>X"' "$REPO_ROOT/opencode/tui.jsonc"
check "sidebar_toggle = leader+b"       grep -qF '"sidebar_toggle": "<leader>b"' "$REPO_ROOT/opencode/tui.jsonc"
# Subagent navigation: vim hjkl, NOT arrow keys.
# Arrow chords (ctrl+x then arrow) collide with macOS Mission Control,
# which intercepts ctrl+arrow before the terminal sees it.
check "session_child_first = leader+j (down)"         grep -qF '"session_child_first": "<leader>j"' "$REPO_ROOT/opencode/tui.jsonc"
check "session_parent = leader+k (up)"                grep -qF '"session_parent": "<leader>k"' "$REPO_ROOT/opencode/tui.jsonc"
check "session_child_cycle_reverse = leader+h (left)" grep -qF '"session_child_cycle_reverse": "<leader>h"' "$REPO_ROOT/opencode/tui.jsonc"
check "session_child_cycle = leader+l (right)"        grep -qF '"session_child_cycle": "<leader>l"' "$REPO_ROOT/opencode/tui.jsonc"

# ── Instruction files ─────────────────────────────────────────────────────
echo ""
echo "Instruction files:"
check "git-conventions: conventional commits"  grep -q 'Conventional Commits' "$REPO_ROOT/opencode/instructions/git-conventions.md"
check "git-conventions: cog verify"            grep -q 'cog verify' "$REPO_ROOT/opencode/instructions/git-conventions.md"
check "git-conventions: git-cliff"             grep -q 'git-cliff' "$REPO_ROOT/opencode/instructions/git-conventions.md"
check "scratch-dirs: /tmp prefix"              grep -q '/tmp/opencode-' "$REPO_ROOT/opencode/instructions/scratch-dirs.md"
check "scratch-dirs: cleanup"                  grep -q 'rm -rf /tmp/opencode' "$REPO_ROOT/opencode/instructions/scratch-dirs.md"

# ── Install script link() calls ──────────────────────────────────────────
echo ""
echo "Install scripts:"
check "macos: opencode.jsonc mapping"    grep -q 'link opencode/opencode.jsonc' "$REPO_ROOT/install-macos.sh"
check "macos: tui.jsonc mapping"         grep -q 'link opencode/tui.jsonc' "$REPO_ROOT/install-macos.sh"
check "macos: git-conventions mapping"   grep -q 'link opencode/instructions/git-conventions.md' "$REPO_ROOT/install-macos.sh"
check "macos: scratch-dirs mapping"      grep -q 'link opencode/instructions/scratch-dirs.md' "$REPO_ROOT/install-macos.sh"
check "wsl: opencode.jsonc mapping"      grep -q 'link opencode/opencode.jsonc' "$REPO_ROOT/install-wsl.sh"
check "wsl: tui.jsonc mapping"           grep -q 'link opencode/tui.jsonc' "$REPO_ROOT/install-wsl.sh"
check "wsl: git-conventions mapping"     grep -q 'link opencode/instructions/git-conventions.md' "$REPO_ROOT/install-wsl.sh"
check "wsl: scratch-dirs mapping"        grep -q 'link opencode/instructions/scratch-dirs.md' "$REPO_ROOT/install-wsl.sh"

# Regression: Plans 2–8 link() calls preserved
check "macos: bash links preserved"      test "$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: git links preserved"       test "$(grep -c 'link git/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "macos: kitty links preserved (kitty.conf + dracula-pro.conf, 1b-ii)"  test "$(grep -c 'link kitty/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "macos: tmux links preserved"      test "$(grep -c 'link tmux/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: starship links preserved"  test "$(grep -c 'link starship/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: lazygit links preserved"   test "$(grep -c 'link lazygit/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: mise links preserved"      test "$(grep -c 'link mise/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "wsl: bash links preserved"        test "$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: git links preserved"         test "$(grep -c 'link git/' "$REPO_ROOT/install-wsl.sh")" -eq 2
check "wsl: kitty links preserved (kitty.conf + dracula-pro.conf, 1b-ii)"    test "$(grep -c 'link kitty/' "$REPO_ROOT/install-wsl.sh")" -eq 2
check "wsl: tmux links preserved"        test "$(grep -c 'link tmux/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: starship links preserved"    test "$(grep -c 'link starship/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: lazygit links preserved"     test "$(grep -c 'link lazygit/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: mise links preserved"        test "$(grep -c 'link mise/' "$REPO_ROOT/install-wsl.sh")" -eq 1

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Current count: 82 tests. Floor should be within ~10% of actual.
if (( total < 74 )); then
  echo "WARNING: only $total tests ran (expected >= 74). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
