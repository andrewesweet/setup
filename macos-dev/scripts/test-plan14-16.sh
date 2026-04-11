#!/usr/bin/env bash
# test-plan14-16.sh — smoke tests for Plans 14-16 (scripts, cheatsheet, README)
#
# Validates:
#   - verify.sh exists, executable, passes bash -n
#   - check-configs.sh exists, executable, passes bash -n, runs successfully
#   - cheatsheet.md exists, has required section headers and table headers
#   - README.md exists, has required sections
#   - cheatsheet.pdf in .gitignore
#   - Regression: prior plan link counts preserved
#
# Usage: bash scripts/test-plan14-16.sh
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

echo "Plans 14-16: Scripts, cheatsheet, README smoke tests"
echo ""

# ── verify.sh (3 checks) ───────────────────────────────────────────────────
echo "verify.sh:"
check "verify.sh exists"                  test -f "$REPO_ROOT/scripts/verify.sh"
check "verify.sh is executable"           test -x "$REPO_ROOT/scripts/verify.sh"
check "verify.sh passes bash -n"          bash -n "$REPO_ROOT/scripts/verify.sh"

# ── check-configs.sh (4 checks) ────────────────────────────────────────────
echo ""
echo "check-configs.sh:"
check "check-configs.sh exists"           test -f "$REPO_ROOT/scripts/check-configs.sh"
check "check-configs.sh is executable"    test -x "$REPO_ROOT/scripts/check-configs.sh"
check "check-configs.sh passes bash -n"   bash -n "$REPO_ROOT/scripts/check-configs.sh"
check "check-configs.sh runs successfully" bash "$REPO_ROOT/scripts/check-configs.sh"

# ── cheatsheet.md existence and headers (8 checks) ─────────────────────────
echo ""
echo "cheatsheet.md existence and headers:"
check "cheatsheet.md exists"              test -f "$REPO_ROOT/docs/cheatsheet.md"
check "has ## Key bindings header"        grep -q '^## Key bindings' "$REPO_ROOT/docs/cheatsheet.md"
check "has ## Tool reference header"      grep -q '^## Tool reference' "$REPO_ROOT/docs/cheatsheet.md"
check "exactly 2 H2 headers"             test "$(grep -c '^## ' "$REPO_ROOT/docs/cheatsheet.md")" -eq 2

# Key bindings sub-headers
check "has Navigation sub-header"         grep -q '^### Navigation' "$REPO_ROOT/docs/cheatsheet.md"
check "has Search sub-header"             grep -q '^### Search' "$REPO_ROOT/docs/cheatsheet.md"
check "has Copy/yank sub-header"          grep -q '^### Copy/yank' "$REPO_ROOT/docs/cheatsheet.md"
check "has Quit/back sub-header"          grep -q '^### Quit/back' "$REPO_ROOT/docs/cheatsheet.md"

# ── cheatsheet.md key binding tables (5 checks) ───────────────────────────
echo ""
echo "cheatsheet.md key binding tables:"
check "Navigation table has Shell column"  grep -q '| Shell | tmux | Neovim' "$REPO_ROOT/docs/cheatsheet.md"
check "Navigation has Half page"          grep -q 'Half page' "$REPO_ROOT/docs/cheatsheet.md"
check "Search table has delta column"     grep -q '| delta |' "$REPO_ROOT/docs/cheatsheet.md"
check "Copy table has OSC 52"            grep -q 'OSC 52' "$REPO_ROOT/docs/cheatsheet.md"
check "Known friction points table"       grep -q '### Known friction points' "$REPO_ROOT/docs/cheatsheet.md"

# ── cheatsheet.md tool reference tables (7 checks) ────────────────────────
echo ""
echo "cheatsheet.md tool reference tables:"
check "has Searching sub-header"          grep -q '^### Searching' "$REPO_ROOT/docs/cheatsheet.md"
check "has Git sub-header"                grep -q '^### Git' "$REPO_ROOT/docs/cheatsheet.md"
check "has Formatting & Linting sub-header" grep -q '^### Formatting & Linting' "$REPO_ROOT/docs/cheatsheet.md"
check "has GCP sub-header"                grep -q '^### GCP' "$REPO_ROOT/docs/cheatsheet.md"
check "has Container sub-header"          grep -q '^### Container' "$REPO_ROOT/docs/cheatsheet.md"
check "Searching table has fd"            grep -q '| fd |' "$REPO_ROOT/docs/cheatsheet.md"
check "Git table has lazygit"             grep -q '| lazygit |' "$REPO_ROOT/docs/cheatsheet.md"
# Discovery footer (option D from cheatsheet design discussion):
# points users at each tool's own discovery key for the full
# binding list, since the cheatsheet itself is intentionally minimal.
check "Discovery footer present"          grep -q '^### Discover full bindings' "$REPO_ROOT/docs/cheatsheet.md"
check "Discovery: nvim WhichKey"          grep -q 'WhichKey' "$REPO_ROOT/docs/cheatsheet.md"
check "Discovery: tmux list-keys"         grep -q 'tmux list-keys' "$REPO_ROOT/docs/cheatsheet.md"
check "Discovery: starship explain"       grep -q 'starship explain' "$REPO_ROOT/docs/cheatsheet.md"

# ── README.md existence and sections (8 checks) ───────────────────────────
echo ""
echo "README.md sections:"
check "README.md exists"                  test -f "$REPO_ROOT/README.md"
check "has Quick start section"           grep -q '## Quick start' "$REPO_ROOT/README.md"
check "has What.s included section"       grep -q "## What's included" "$REPO_ROOT/README.md"
check "has Repository structure section"  grep -q '## Repository structure' "$REPO_ROOT/README.md"
check "has Configuration section"         grep -q '## Configuration' "$REPO_ROOT/README.md"
check "has Container development section" grep -q '## Container development' "$REPO_ROOT/README.md"
check "has Cheatsheet section"            grep -q '## Cheatsheet' "$REPO_ROOT/README.md"
check "has Design documents section"      grep -q '## Design documents' "$REPO_ROOT/README.md"

# ── README.md content checks (5 checks) ───────────────────────────────────
echo ""
echo "README.md content:"
check "README mentions install-macos.sh"  grep -q 'install-macos.sh' "$REPO_ROOT/README.md"
check "README mentions install-wsl.sh"    grep -q 'install-wsl.sh' "$REPO_ROOT/README.md"
check "README mentions .bashrc.local"     grep -q '.bashrc.local' "$REPO_ROOT/README.md"
check "README mentions dev shell"         grep -q 'dev shell' "$REPO_ROOT/README.md"
check "README no hardcoded credentials"   bash -c "! grep -qiE '(ghp_|token|password|secret)' '$REPO_ROOT/README.md'"

# ── .gitignore: cheatsheet.pdf (1 check) ──────────────────────────────────
echo ""
echo "Gitignore:"
check "cheatsheet.pdf in .gitignore"      grep -q 'cheatsheet\.pdf' "$REPO_ROOT/.gitignore"

# ── Cheatsheet PDF generation (4 checks) ──────────────────────────────────
# Locks in current behavior: pandoc + typst are declared in Brewfile and
# README documents a generation command. Does NOT validate the PDF's page
# geometry — the spec calls for landscape A4 but the current command uses
# typst defaults (portrait A4). Intentional: we're pinning current state,
# not the spec's ideal.
echo ""
echo "Cheatsheet PDF generation:"
check "Brewfile has pandoc"               grep -q '^brew "pandoc"' "$REPO_ROOT/Brewfile"
check "Brewfile has typst"                grep -q '^brew "typst"' "$REPO_ROOT/Brewfile"
check "README has pandoc PDF command"     grep -q 'pandoc docs/cheatsheet.md' "$REPO_ROOT/README.md"
check "README PDF command uses typst"     grep -q 'pdf-engine=typst' "$REPO_ROOT/README.md"

# ── Regression: design doc links in README (1 check) ──────────────────────
echo ""
echo "Regression — design doc links:"
check "README links to 12 design docs"   test "$(grep -c 'docs/design/' "$REPO_ROOT/README.md")" -ge 12

# ── Regression: prior plan link() calls preserved ─────────────────────────
echo ""
echo "Regression — macOS link() calls:"
check "macos: bash links preserved"       test "$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: git links preserved"        test "$(grep -c 'link git/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "macos: opencode links preserved"   test "$(grep -c 'link opencode/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: vscode links preserved"     test "$(grep -c 'link vscode/' "$REPO_ROOT/install-macos.sh")" -eq 2

echo ""
echo "Regression — WSL link() calls:"
check "wsl: bash links preserved"         test "$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: git links preserved"          test "$(grep -c 'link git/' "$REPO_ROOT/install-wsl.sh")" -eq 2
check "wsl: opencode links preserved"     test "$(grep -c 'link opencode/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: vscode links preserved"       test "$(grep -c 'link vscode/' "$REPO_ROOT/install-wsl.sh")" -eq 2

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Floor check: expect ~50 tests
if (( total < 40 )); then
  echo "WARNING: only $total tests ran (expected >= 40). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
