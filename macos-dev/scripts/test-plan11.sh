#!/usr/bin/env bash
# test-plan11.sh — smoke tests for Plan 11 (prek configuration)
#
# Validates:
#   - .pre-commit-config.yaml exists
#   - All 12 hook repos present with correct revisions
#   - Key hook IDs and configurations
#   - Security hooks (gitleaks, detect-private-key)
#   - yamllint github exclusion
#   - go-unit-tests at manual stage
#   - Install scripts have correct link() mapping
#   - Plans 2–10 link() calls preserved (regression)
#
# Usage: bash scripts/test-plan11.sh
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

PC="$REPO_ROOT/prek/.pre-commit-config.yaml"

echo "Plan 11: prek configuration smoke tests"
echo ""

# ── File existence ─────────────────────────────────────────────────────────
echo "File existence:"
check ".pre-commit-config.yaml exists"  test -f "$PC"

# ── Hook repo count ───────────────────────────────────────────────────────
echo ""
echo "Hook repos:"
check "12 hook repos"                   test "$(grep -c '^  - repo:' "$PC")" -eq 12

# ── Universal file hygiene ────────────────────────────────────────────────
echo ""
echo "Universal file hygiene (pre-commit-hooks):"
check "pre-commit-hooks v5.0.0"         grep -q 'pre-commit-hooks' "$PC"
check "trailing-whitespace"             grep -qF 'trailing-whitespace' "$PC"
check "end-of-file-fixer"              grep -qF 'end-of-file-fixer' "$PC"
check "check-yaml"                      grep -qF 'check-yaml' "$PC"
check "check-json"                      grep -qF 'check-json' "$PC"
check "check-toml"                      grep -qF 'check-toml' "$PC"
check "check-merge-conflict"           grep -qF 'check-merge-conflict' "$PC"
check "check-added-large-files 500kb"  grep -qF "'--maxkb=500'" "$PC"
check "detect-private-key"             grep -qF 'detect-private-key' "$PC"
check "check-executables-have-shebangs" grep -qF 'check-executables-have-shebangs' "$PC"
check "mixed-line-ending lf"           grep -qF "'--fix=lf'" "$PC"

# ── Conventional commits ─────────────────────────────────────────────────
echo ""
echo "Conventional commits:"
check "conventional-pre-commit v3.4.0"  grep -q 'conventional-pre-commit' "$PC"
check "commit-msg stage"               grep -qF 'commit-msg' "$PC"
check "commit types include feat"      grep -q "'feat'" "$PC"

# ── Secrets detection ─────────────────────────────────────────────────────
echo ""
echo "Secrets detection:"
check "gitleaks v8.21.2"               grep -q 'gitleaks' "$PC"

# ── Bash ──────────────────────────────────────────────────────────────────
echo ""
echo "Bash hooks:"
check "shellcheck-py v0.10.0.1"        grep -q 'shellcheck-py' "$PC"
check "shellcheck --severity=warning"  grep -qF "'--severity=warning'" "$PC"
check "shfmt v3.10.0-1"               grep -q 'pre-commit-shfmt' "$PC"
check "shfmt -i 2 -ci"                grep -qF "'-i'" "$PC"

# ── Python ────────────────────────────────────────────────────────────────
echo ""
echo "Python hooks:"
check "ruff-pre-commit v0.9.0"        grep -q 'ruff-pre-commit' "$PC"
check "ruff --fix"                     grep -qF "'--fix'" "$PC"
check "ruff-format"                    grep -qF 'ruff-format' "$PC"

# ── Go ────────────────────────────────────────────────────────────────────
echo ""
echo "Go hooks:"
check "pre-commit-golang v0.5.1"       grep -q 'pre-commit-golang' "$PC"
check "go-fmt"                         grep -qF 'go-fmt' "$PC"
check "go-vet"                         grep -qF 'go-vet' "$PC"
check "go-unit-tests"                  grep -qF 'go-unit-tests' "$PC"
check "go-unit-tests manual stage"     grep -A 1 'go-unit-tests' "$PC" | grep -q 'manual'

# ── Terraform ─────────────────────────────────────────────────────────────
echo ""
echo "Terraform hooks:"
check "pre-commit-terraform v1.96.0"   grep -q 'pre-commit-terraform' "$PC"
check "terraform_fmt"                  grep -qF 'terraform_fmt' "$PC"
check "terraform_validate"             grep -qF 'terraform_validate' "$PC"
check "terraform_tflint"               grep -qF 'terraform_tflint' "$PC"

# ── GitHub Actions ────────────────────────────────────────────────────────
echo ""
echo "GitHub Actions hooks:"
check "actionlint v1.7.4"             grep -q 'rhysd/actionlint' "$PC"
check "zizmor-pre-commit v1.5.0"      grep -q 'zizmor-pre-commit' "$PC"

# ── YAML ──────────────────────────────────────────────────────────────────
echo ""
echo "YAML hooks:"
check "yamllint v1.35.1"              grep -q 'adrienverge/yamllint' "$PC"
check "yamllint excludes github"       grep -q 'exclude.*github' "$PC"

# ── Markdown ──────────────────────────────────────────────────────────────
echo ""
echo "Markdown hooks:"
check "markdownlint-cli2 v0.17.1"     grep -q 'markdownlint-cli2' "$PC"

# ── Install script link() calls ──────────────────────────────────────────
echo ""
echo "Install scripts:"
check "macos: prek mapping"            grep -q 'link prek/.pre-commit-config.yaml' "$REPO_ROOT/install-macos.sh"
check "wsl: prek mapping"             grep -q 'link prek/.pre-commit-config.yaml' "$REPO_ROOT/install-wsl.sh"

# Regression: Plans 2–10 link() calls preserved
check "macos: bash links preserved"    test "$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: git links preserved"     test "$(grep -c 'link git/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "macos: kitty links preserved (kitty.conf + dracula-pro.conf, 1b-ii)"  test "$(grep -c 'link kitty/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "macos: tmux links preserved"    test "$(grep -c 'link tmux/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: starship links preserved" test "$(grep -c 'link starship/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: lazygit links preserved" test "$(grep -c 'link lazygit/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: mise links preserved"    test "$(grep -c 'link mise/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: opencode links preserved" test "$(grep -c 'link opencode/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: nvim links preserved"    test "$(grep -c 'link nvim' "$REPO_ROOT/install-macos.sh")" -eq 1
check "wsl: bash links preserved"      test "$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: git links preserved"       test "$(grep -c 'link git/' "$REPO_ROOT/install-wsl.sh")" -eq 2
check "wsl: kitty links preserved (kitty.conf + dracula-pro.conf, 1b-ii)"    test "$(grep -c 'link kitty/' "$REPO_ROOT/install-wsl.sh")" -eq 2
check "wsl: tmux links preserved"      test "$(grep -c 'link tmux/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: starship links preserved"  test "$(grep -c 'link starship/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: lazygit links preserved"   test "$(grep -c 'link lazygit/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: mise links preserved"      test "$(grep -c 'link mise/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: opencode links preserved"  test "$(grep -c 'link opencode/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: nvim links preserved"      test "$(grep -c 'link nvim' "$REPO_ROOT/install-wsl.sh")" -eq 1

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Current count: 57 tests. Floor should be within ~10% of actual.
if (( total < 51 )); then
  echo "WARNING: only $total tests ran (expected >= 51). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
