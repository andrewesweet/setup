#!/usr/bin/env bash
# test-plan6-8.sh — smoke tests for Plans 6–8 (starship, lazygit, mise)
#
# Validates:
#   - All three config files exist
#   - Starship prompt format, modules, and settings
#   - Lazygit theme, paging, keybindings
#   - Mise tool versions and settings
#   - Install scripts have correct link() mappings
#   - Plans 2–5 link() calls are preserved (regression)
#
# Usage: bash scripts/test-plan6-8.sh
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

echo "Plans 6–8: starship, lazygit, mise smoke tests"
echo ""

# ── File existence ─────────────────────────────────────────────────────────
echo "File existence:"
check "starship.toml exists"  test -f "$REPO_ROOT/starship/starship.toml"
check "lazygit config.yml exists"  test -f "$REPO_ROOT/lazygit/config.yml"
check "mise config.toml exists"  test -f "$REPO_ROOT/mise/config.toml"

# ══════════════════════════════════════════════════════════════════════════
# STARSHIP
# ══════════════════════════════════════════════════════════════════════════

echo ""
echo "Starship — prompt format:"
check "format string present"         grep -q '^\$directory' "$REPO_ROOT/starship/starship.toml"
check "scan_timeout = 30"             grep -q 'scan_timeout.*30' "$REPO_ROOT/starship/starship.toml"

echo ""
echo "Starship — directory module:"
check "truncation_length = 4"         grep -q 'truncation_length.*4' "$REPO_ROOT/starship/starship.toml"
check "truncate_to_repo = true"       grep -q 'truncate_to_repo.*true' "$REPO_ROOT/starship/starship.toml"
check "directory style bold blue"     grep -q 'style.*bold blue' "$REPO_ROOT/starship/starship.toml"

echo ""
echo "Starship — git modules:"
check "git_branch symbol"             grep -qF 'symbol = " "' "$REPO_ROOT/starship/starship.toml"
check "git_branch style bold purple"  grep -q 'style.*bold purple' "$REPO_ROOT/starship/starship.toml"
check "git_status conflicted"         grep -qF 'conflicted = "⚡"' "$REPO_ROOT/starship/starship.toml"
check "git_status ahead"              grep -qF 'ahead      = "↑${count}"' "$REPO_ROOT/starship/starship.toml"
check "git_status behind"             grep -qF 'behind     = "↓${count}"' "$REPO_ROOT/starship/starship.toml"
check "git_status diverged"           grep -qF 'diverged   = "⇕"' "$REPO_ROOT/starship/starship.toml"
check "git_status modified"           grep -qF 'modified = "*"' "$REPO_ROOT/starship/starship.toml"
check "git_status staged"             grep -qF 'staged = "+"' "$REPO_ROOT/starship/starship.toml"
check "git_status untracked"          grep -qF 'untracked = "?"' "$REPO_ROOT/starship/starship.toml"
check "git_status stashed"            grep -qF 'stashed = "$"' "$REPO_ROOT/starship/starship.toml"

echo ""
echo "Starship — character module:"
check "vicmd_symbol N green"          grep -q 'vicmd_symbol.*N.*bold green' "$REPO_ROOT/starship/starship.toml"
check "success_symbol I yellow"       grep -q 'success_symbol.*I.*bold yellow' "$REPO_ROOT/starship/starship.toml"
check "error_symbol I red"            grep -q 'error_symbol.*I.*bold red' "$REPO_ROOT/starship/starship.toml"

# MUST NOT include vimins_symbol (not a valid Starship key)
if grep -q 'vimins_symbol' "$REPO_ROOT/starship/starship.toml"; then
  nok "vimins_symbol absent (invalid key)"
else
  ok "vimins_symbol absent (invalid key)"
fi

echo ""
echo "Starship — cmd_duration:"
check "min_time = 2000"               grep -q 'min_time.*2000' "$REPO_ROOT/starship/starship.toml"
check "duration format yellow"        grep -q 'format.*duration.*yellow' "$REPO_ROOT/starship/starship.toml"

echo ""
echo "Starship — language modules:"
check "nodejs format"                 grep -q '\[nodejs\]' "$REPO_ROOT/starship/starship.toml"
check "nodejs detect_files"           grep -q 'detect_files.*package.json' "$REPO_ROOT/starship/starship.toml"
check "python format"                 grep -q '\[python\]' "$REPO_ROOT/starship/starship.toml"
check "golang format"                 grep -q '\[golang\]' "$REPO_ROOT/starship/starship.toml"
check "kubernetes disabled false"     grep -q 'disabled.*false' "$REPO_ROOT/starship/starship.toml"
check "kubernetes format"             grep -q '\[kubernetes\]' "$REPO_ROOT/starship/starship.toml"
check "terraform format"              grep -q '\[terraform\]' "$REPO_ROOT/starship/starship.toml"

# Section count
check "10 TOML sections"             test "$(grep -c '^\[' "$REPO_ROOT/starship/starship.toml")" -eq 10

# ══════════════════════════════════════════════════════════════════════════
# LAZYGIT
# ══════════════════════════════════════════════════════════════════════════

echo ""
echo "Lazygit — theme:"
check "activeBorderColor #89b4fa"     grep -qF "'#89b4fa'" "$REPO_ROOT/lazygit/config.yml"
check "selectedLineBgColor #313244"   grep -qF "'#313244'" "$REPO_ROOT/lazygit/config.yml"

echo ""
echo "Lazygit — GUI settings:"
check "sidePanelWidth 0.25"           grep -q 'sidePanelWidth.*0.25' "$REPO_ROOT/lazygit/config.yml"
check "expandFocusedSidePanel true"   grep -q 'expandFocusedSidePanel.*true' "$REPO_ROOT/lazygit/config.yml"
check "showFileTree true"             grep -q 'showFileTree.*true' "$REPO_ROOT/lazygit/config.yml"
check "nerdFontsVersion 3"            grep -qF 'nerdFontsVersion: "3"' "$REPO_ROOT/lazygit/config.yml"

echo ""
echo "Lazygit — git paging:"
check "pager delta with Monokai"      grep -q "pager.*delta.*Monokai Extended" "$REPO_ROOT/lazygit/config.yml"
check "colorArg always"               grep -q 'colorArg.*always' "$REPO_ROOT/lazygit/config.yml"

echo ""
echo "Lazygit — git settings:"
check "signOff false"                 grep -q 'signOff.*false' "$REPO_ROOT/lazygit/config.yml"
check "fetching interval 60"          grep -q 'interval.*60' "$REPO_ROOT/lazygit/config.yml"

echo ""
echo "Lazygit — keybindings:"
check "quit = q"                      grep -q 'quit:.*q' "$REPO_ROOT/lazygit/config.yml"
check "return = esc"                  grep -q 'return:.*esc' "$REPO_ROOT/lazygit/config.yml"
check "scrollUpMain = k"              grep -q 'scrollUpMain:.*k' "$REPO_ROOT/lazygit/config.yml"
check "scrollDownMain = j"            grep -q 'scrollDownMain:.*j' "$REPO_ROOT/lazygit/config.yml"
check "prevItem = k"                  grep -q 'prevItem:.*k' "$REPO_ROOT/lazygit/config.yml"
check "nextItem = j"                  grep -q 'nextItem:.*j' "$REPO_ROOT/lazygit/config.yml"
check "scrollLeft = h"                grep -q 'scrollLeft:.*h' "$REPO_ROOT/lazygit/config.yml"
check "scrollRight = l"               grep -q 'scrollRight:.*l' "$REPO_ROOT/lazygit/config.yml"
check "nextTab = ]"                   grep -qF 'nextTab' "$REPO_ROOT/lazygit/config.yml"
check "prevTab = ["                   grep -qF 'prevTab' "$REPO_ROOT/lazygit/config.yml"
check "openRecentRepos = c-r"         grep -q 'openRecentRepos.*c-r' "$REPO_ROOT/lazygit/config.yml"

# ══════════════════════════════════════════════════════════════════════════
# MISE
# ══════════════════════════════════════════════════════════════════════════

echo ""
echo "Mise — tool versions:"
check "python = 3.13"                 grep -q 'python.*3.13' "$REPO_ROOT/mise/config.toml"
check "go = 1.24"                     grep -q 'go.*1.24' "$REPO_ROOT/mise/config.toml"

echo ""
echo "Mise — settings:"
check "auto_install = false"          grep -q 'auto_install.*false' "$REPO_ROOT/mise/config.toml"

# ══════════════════════════════════════════════════════════════════════════
# INSTALL SCRIPTS
# ══════════════════════════════════════════════════════════════════════════

echo ""
echo "Install scripts:"
check "macos: starship mapping"       grep -q 'link starship/starship.toml.*\.config/starship.toml' "$REPO_ROOT/install-macos.sh"
check "macos: lazygit mapping"        grep -q 'link lazygit/config.yml.*\.config/lazygit/config.yml' "$REPO_ROOT/install-macos.sh"
check "macos: mise mapping"           grep -q 'link mise/config.toml.*\.config/mise/config.toml' "$REPO_ROOT/install-macos.sh"
check "wsl: starship mapping"         grep -q 'link starship/starship.toml.*\.config/starship.toml' "$REPO_ROOT/install-wsl.sh"
check "wsl: lazygit mapping"          grep -q 'link lazygit/config.yml.*\.config/lazygit/config.yml' "$REPO_ROOT/install-wsl.sh"
check "wsl: mise mapping"             grep -q 'link mise/config.toml.*\.config/mise/config.toml' "$REPO_ROOT/install-wsl.sh"

# Regression: Plans 2–5 link() calls preserved
check "macos: bash links preserved"   test "$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: git links preserved"    test "$(grep -c 'link git/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "macos: kitty links preserved"  test "$(grep -c 'link kitty/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: tmux links preserved"   test "$(grep -c 'link tmux/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "wsl: bash links preserved"     test "$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: git links preserved"      test "$(grep -c 'link git/' "$REPO_ROOT/install-wsl.sh")" -eq 2
check "wsl: kitty links preserved"    test "$(grep -c 'link kitty/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: tmux links preserved"     test "$(grep -c 'link tmux/' "$REPO_ROOT/install-wsl.sh")" -eq 1

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Current count: 70 tests. Floor should be within ~10% of actual.
if (( total < 63 )); then
  echo "WARNING: only $total tests ran (expected >= 63). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
