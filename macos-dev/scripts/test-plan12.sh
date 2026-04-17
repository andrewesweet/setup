#!/usr/bin/env bash
# test-plan12.sh — smoke tests for Plan 12 (VS Code configuration)
#
# Validates:
#   - Both config files exist and are valid JSON
#   - settings.json has required editor, terminal, file, git, and language settings
#   - extensions.json has all 21 recommended extensions
#   - Install scripts have correct link() mappings (platform-specific paths)
#   - Plans 2–11 link() calls preserved (regression)
#
# Usage: bash scripts/test-plan12.sh
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

echo "Plan 12: VS Code configuration smoke tests"
echo ""

# ── File existence and validity ───────────────────────────────────────────
echo "File existence and validity:"
check "settings.json exists"         test -f "$REPO_ROOT/vscode/settings.json"
check "extensions.json exists"       test -f "$REPO_ROOT/vscode/extensions.json"
check "settings.json valid JSON"     python3 -c "import json; json.load(open('$REPO_ROOT/vscode/settings.json'))"
check "extensions.json valid JSON"   python3 -c "import json; json.load(open('$REPO_ROOT/vscode/extensions.json'))"

# ── settings.json — editor ───────────────────────────────────────────────
echo ""
echo "settings.json — editor:"
check "fontSize = 13"                grep -q 'editor.fontSize.*13' "$REPO_ROOT/vscode/settings.json"
check "fontFamily JetBrains Mono"    grep -q 'JetBrains Mono' "$REPO_ROOT/vscode/settings.json"
check "tabSize = 2"                  grep -qF '"editor.tabSize": 2' "$REPO_ROOT/vscode/settings.json"
check "formatOnSave = true"          grep -qF '"editor.formatOnSave": true' "$REPO_ROOT/vscode/settings.json"
check "rulers 100"                   grep -q 'editor.rulers.*100' "$REPO_ROOT/vscode/settings.json"
check "minimap disabled"             grep -qF '"editor.minimap.enabled": false' "$REPO_ROOT/vscode/settings.json"

# ── settings.json — terminal ─────────────────────────────────────────────
echo ""
echo "settings.json — terminal:"
check "terminal profile osx = bash"  grep -qF '"terminal.integrated.defaultProfile.osx": "bash"' "$REPO_ROOT/vscode/settings.json"
check "terminal profile linux = bash" grep -qF '"terminal.integrated.defaultProfile.linux": "bash"' "$REPO_ROOT/vscode/settings.json"

# ── settings.json — files ────────────────────────────────────────────────
echo ""
echo "settings.json — files:"
check "trimTrailingWhitespace"       grep -qF '"files.trimTrailingWhitespace": true' "$REPO_ROOT/vscode/settings.json"
check "insertFinalNewline"           grep -qF '"files.insertFinalNewline": true' "$REPO_ROOT/vscode/settings.json"

# ── settings.json — git ──────────────────────────────────────────────────
echo ""
echo "settings.json — git:"
check "autofetch = false"            grep -qF '"git.autofetch": false' "$REPO_ROOT/vscode/settings.json"
check "renderSideBySide"             grep -qF '"diffEditor.renderSideBySide": true' "$REPO_ROOT/vscode/settings.json"

# ── settings.json — language formatters ───────────────────────────────────
echo ""
echo "settings.json — language formatters:"
check "python: ruff formatter"       grep -q 'charliermarsh.ruff' "$REPO_ROOT/vscode/settings.json"
check "go: golang.go formatter"      grep -q 'golang.go' "$REPO_ROOT/vscode/settings.json"
check "go: golangci-lint"            grep -qF '"go.lintTool": "golangci-lint"' "$REPO_ROOT/vscode/settings.json"
check "go: gofumpt"                  grep -qF '"go.formatTool": "gofumpt"' "$REPO_ROOT/vscode/settings.json"
check "terraform: hashicorp"         grep -q 'hashicorp.terraform' "$REPO_ROOT/vscode/settings.json"
check "yaml: prettier"               grep -q 'prettier-vscode' "$REPO_ROOT/vscode/settings.json"
check "shell: shfmt"                 grep -q 'mkhl.shfmt' "$REPO_ROOT/vscode/settings.json"
check "shfmt flags -i 2 -ci -bn"    grep -qF '"shellformat.flag": "-i 2 -ci -bn"' "$REPO_ROOT/vscode/settings.json"
check "markdown: prettier + wordWrap" grep -q 'wordWrap.*on' "$REPO_ROOT/vscode/settings.json"

# ── settings.json — security/privacy ─────────────────────────────────────
echo ""
echo "settings.json — security/privacy:"
check "telemetry off"                grep -qF '"telemetry.telemetryLevel": "off"' "$REPO_ROOT/vscode/settings.json"
check "podman for dev containers"    grep -qF '"dev.containers.dockerPath": "podman"' "$REPO_ROOT/vscode/settings.json"

# ── extensions.json ───────────────────────────────────────────────────────
echo ""
echo "extensions.json:"
check "21 recommended extensions"    test "$(python3 -c "import json; print(len(json.load(open('$REPO_ROOT/vscode/extensions.json'))['recommendations']))")" -eq 21
check "ruff extension"               grep -qF 'charliermarsh.ruff' "$REPO_ROOT/vscode/extensions.json"
check "python extension"             grep -qF 'ms-python.python' "$REPO_ROOT/vscode/extensions.json"
check "go extension"                 grep -qF 'golang.go' "$REPO_ROOT/vscode/extensions.json"
check "terraform extension"          grep -qF 'hashicorp.terraform' "$REPO_ROOT/vscode/extensions.json"
check "gitleaks extension"           grep -qF 'gitleaks.gitleaks' "$REPO_ROOT/vscode/extensions.json"
check "codeql extension"             grep -qF 'github.vscode-codeql' "$REPO_ROOT/vscode/extensions.json"
check "remote-wsl extension"         grep -qF 'ms-vscode-remote.remote-wsl' "$REPO_ROOT/vscode/extensions.json"
check "remote-containers extension"  grep -qF 'ms-vscode-remote.remote-containers' "$REPO_ROOT/vscode/extensions.json"
# Theming assertions moved to scripts/test-plan-theming.sh (docs/design/theming.md).
# catppuccin was superseded by `dracula-theme-pro.theme-dracula-pro` in Wave A.
check "prettier extension"           grep -qF 'esbenp.prettier-vscode' "$REPO_ROOT/vscode/extensions.json"

# ── Install script link() calls ──────────────────────────────────────────
echo ""
echo "Install scripts:"
check "macos: settings.json mapping"   grep -q 'link vscode/settings.json' "$REPO_ROOT/install-macos.sh"
check "macos: extensions.json mapping" grep -q 'link vscode/extensions.json' "$REPO_ROOT/install-macos.sh"
check "macos: Application Support path" grep -q 'Application Support/Code/User' "$REPO_ROOT/install-macos.sh"
check "wsl: settings.json mapping"     grep -q 'link vscode/settings.json' "$REPO_ROOT/install-wsl.sh"
check "wsl: extensions.json mapping"   grep -q 'link vscode/extensions.json' "$REPO_ROOT/install-wsl.sh"
check "wsl: vscode-server path"        grep -q 'vscode-server/data/Machine' "$REPO_ROOT/install-wsl.sh"

# Regression: Plans 2–11 link() calls preserved
check "macos: bash links preserved"    test "$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: git links preserved"     test "$(grep -c 'link git/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "macos: kitty link preserved (kitty.conf only — dracula-pro.conf removed by theming Wave A)"  test "$(grep -c 'link kitty/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: tmux links preserved"    test "$(grep -c 'link tmux/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: starship links preserved" test "$(grep -c 'link starship/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: lazygit links preserved" test "$(grep -c 'link lazygit/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: mise links preserved"    test "$(grep -c 'link mise/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: opencode links preserved" test "$(grep -c 'link opencode/' "$REPO_ROOT/install-macos.sh")" -eq 5
check "macos: nvim links preserved"    test "$(grep -c 'link nvim' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: prek links preserved"    test "$(grep -c 'link prek/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "wsl: bash links preserved"      test "$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: git links preserved"       test "$(grep -c 'link git/' "$REPO_ROOT/install-wsl.sh")" -eq 2
check "wsl: kitty link preserved (kitty.conf only — dracula-pro.conf removed by theming Wave A)"    test "$(grep -c 'link kitty/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: tmux links preserved"      test "$(grep -c 'link tmux/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: starship links preserved"  test "$(grep -c 'link starship/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: lazygit links preserved"   test "$(grep -c 'link lazygit/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: mise links preserved"      test "$(grep -c 'link mise/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: opencode links preserved"  test "$(grep -c 'link opencode/' "$REPO_ROOT/install-wsl.sh")" -eq 5
check "wsl: nvim links preserved"      test "$(grep -c 'link nvim' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: prek links preserved"      test "$(grep -c 'link prek/' "$REPO_ROOT/install-wsl.sh")" -eq 1

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Current count: 66 tests. Floor should be within ~10% of actual.
if (( total < 59 )); then
  echo "WARNING: only $total tests ran (expected >= 59). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
