#!/usr/bin/env bash
# test-plan13.sh — smoke tests for Plan 13 (container configuration)
#
# Validates:
#   - All 7 container files exist
#   - Containerfile structure (2 stages, wolfi-base, procps, adduser, checksums)
#   - dev.sh: all 11 commands, security flags, features, volumes
#   - Supporting files: plist markers, wrapper, test script, dockerignore
#   - .gitignore: dev.env pattern
#   - Install scripts: dev.sh link, LaunchAgent setup
#   - Regression: Plans 2–12 link() calls preserved
#
# Usage: bash scripts/test-plan13.sh
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

echo "Plan 13: Container configuration smoke tests"
echo ""

# ── File existence (7 checks) ───────────────────────────────────────────────
echo "File existence:"
check "Containerfile exists"            test -f "$REPO_ROOT/container/Containerfile"
check "dev.sh exists"                   test -f "$REPO_ROOT/container/dev.sh"
check "dev.env.example exists"          test -f "$REPO_ROOT/container/dev.env.example"
check "io.podman.machine.plist exists"  test -f "$REPO_ROOT/container/io.podman.machine.plist"
check "podman-machine-start.sh exists"  test -f "$REPO_ROOT/container/podman-machine-start.sh"
check "test-tool-installs.sh exists"    test -f "$REPO_ROOT/container/test-tool-installs.sh"
check ".dockerignore exists"            test -f "$REPO_ROOT/container/.dockerignore"

# ── Containerfile structure (6 checks) ──────────────────────────────────────
echo ""
echo "Containerfile structure:"
check "2 FROM stages"                   test "$(grep -c '^FROM' "$REPO_ROOT/container/Containerfile")" -eq 2
check "uses wolfi-base"                 grep -q 'wolfi-base' "$REPO_ROOT/container/Containerfile"
check "procps installed"                grep -q 'procps' "$REPO_ROOT/container/Containerfile"
check "adduser dev"                     grep -q 'adduser.*dev' "$REPO_ROOT/container/Containerfile"
check "SHA256 checksum verification"    grep -q 'sha256' "$REPO_ROOT/container/Containerfile"
check "base stage label"               grep -q 'AS base' "$REPO_ROOT/container/Containerfile"

# ── dev.sh commands (11 checks) ─────────────────────────────────────────────
echo ""
echo "dev.sh commands:"
check "build command"                   grep -q 'cmd_build' "$REPO_ROOT/container/dev.sh"
check "shell command"                   grep -q 'cmd_shell' "$REPO_ROOT/container/dev.sh"
check "stop command"                    grep -q 'cmd_stop' "$REPO_ROOT/container/dev.sh"
check "rebuild command"                 grep -q 'cmd_rebuild' "$REPO_ROOT/container/dev.sh"
check "status command"                  grep -q 'cmd_status' "$REPO_ROOT/container/dev.sh"
check "prune command"                   grep -q 'cmd_prune' "$REPO_ROOT/container/dev.sh"
check "clean-sessions command"          grep -q 'cmd_clean_sessions\|clean-sessions' "$REPO_ROOT/container/dev.sh"
check "init-machine command"            grep -q 'cmd_init_machine\|init-machine' "$REPO_ROOT/container/dev.sh"
check "machine-start command"           grep -q 'cmd_machine_start\|machine-start' "$REPO_ROOT/container/dev.sh"
check "machine-stop command"            grep -q 'cmd_machine_stop\|machine-stop' "$REPO_ROOT/container/dev.sh"
check "machine-status command"          grep -q 'cmd_machine_status\|machine-status' "$REPO_ROOT/container/dev.sh"

# ── dev.sh security flags (7 checks) ────────────────────────────────────────
echo ""
echo "dev.sh security flags:"
check "--read-only flag"                grep -q '\-\-read-only' "$REPO_ROOT/container/dev.sh"
check "--cap-drop=ALL flag"             grep -q 'cap-drop=ALL' "$REPO_ROOT/container/dev.sh"
check "--cap-add=CHOWN,DAC_OVERRIDE,FOWNER" grep -q 'cap-add=CHOWN,DAC_OVERRIDE,FOWNER' "$REPO_ROOT/container/dev.sh"
check "--security-opt=no-new-privileges" grep -q 'no-new-privileges' "$REPO_ROOT/container/dev.sh"
check "--userns=keep-id"               grep -q 'userns=keep-id' "$REPO_ROOT/container/dev.sh"
check "MUST NOT use --privileged"       bash -c "! grep -q '\-\-privileged' '$REPO_ROOT/container/dev.sh'"
check "opencode-auth mount path"        grep -q 'opencode-auth' "$REPO_ROOT/container/dev.sh"

# ── dev.sh features (12 checks) ─────────────────────────────────────────────
echo ""
echo "dev.sh features:"
check "_ensure_machine helper"          grep -q '_ensure_machine' "$REPO_ROOT/container/dev.sh"
check "SSH_AUTH_SOCK handling"          grep -q 'SSH_AUTH_SOCK' "$REPO_ROOT/container/dev.sh"
check "slirp4netns platform guard"      grep -q 'slirp4netns' "$REPO_ROOT/container/dev.sh"
check "dev-cache-uv volume"            grep -q 'dev-cache-uv' "$REPO_ROOT/container/dev.sh"
check "dev-cache-go volume"            grep -q 'dev-cache-go' "$REPO_ROOT/container/dev.sh"
check "dev-cache-mise volume"          grep -q 'dev-cache-mise' "$REPO_ROOT/container/dev.sh"
check "dev-cache-mason volume"         grep -q 'dev-cache-mason' "$REPO_ROOT/container/dev.sh"
check "dev-cache-bun volume"           grep -q 'dev-cache-bun' "$REPO_ROOT/container/dev.sh"
check "dev-data-opencode volume"       grep -q 'dev-data-opencode' "$REPO_ROOT/container/dev.sh"
check "container naming dev-<repo>"    grep -q 'dev-' "$REPO_ROOT/container/dev.sh"
check "dev.env loading"                grep -q 'dev\.env' "$REPO_ROOT/container/dev.sh"
check "GIT_AUTHOR auto-set"           grep -q 'GIT_AUTHOR_NAME\|GIT_AUTHOR_EMAIL' "$REPO_ROOT/container/dev.sh"

# ── dev.sh executable ───────────────────────────────────────────────────────
echo ""
echo "dev.sh executable:"
check "dev.sh is executable"            test -x "$REPO_ROOT/container/dev.sh"
check "dev.sh passes bash -n"          bash -n "$REPO_ROOT/container/dev.sh"

# ── Supporting files (12 checks) ────────────────────────────────────────────
echo ""
echo "Supporting files:"
check "dev.env.example not empty"       test -s "$REPO_ROOT/container/dev.env.example"
check "plist has @HOME@ marker"         grep -q '@HOME@' "$REPO_ROOT/container/io.podman.machine.plist"
check "plist has @SCRIPT_PATH@ marker"  grep -q '@SCRIPT_PATH@' "$REPO_ROOT/container/io.podman.machine.plist"
check "plist has RunAtLoad"             grep -q 'RunAtLoad' "$REPO_ROOT/container/io.podman.machine.plist"
check "plist has ThrottleInterval"      grep -q 'ThrottleInterval' "$REPO_ROOT/container/io.podman.machine.plist"
check "wrapper has @HOMEBREW_PREFIX@"   grep -q '@HOMEBREW_PREFIX@' "$REPO_ROOT/container/podman-machine-start.sh"
check "wrapper has platform guard"      grep -q 'Darwin' "$REPO_ROOT/container/podman-machine-start.sh"
check "wrapper has dotfiles machine check" grep -q 'dotfiles' "$REPO_ROOT/container/podman-machine-start.sh"
check "test-tool-installs.sh executable" test -x "$REPO_ROOT/container/test-tool-installs.sh"
check "test-tool-installs.sh has --full" grep -q '\-\-full' "$REPO_ROOT/container/test-tool-installs.sh"
check ".dockerignore has .git"          grep -q '^\.git$' "$REPO_ROOT/container/.dockerignore"
check "dockerignore has dev.env"        grep -q 'dev\.env' "$REPO_ROOT/container/.dockerignore"

# ── Gitignore (1 check) ─────────────────────────────────────────────────────
echo ""
echo "Gitignore:"
check "dev.env in repo .gitignore"      grep -q 'dev\.env' "$REPO_ROOT/.gitignore"

# ── Install scripts (6 checks) ──────────────────────────────────────────────
echo ""
echo "Install scripts:"
check "macos: dev.sh link"             grep -q 'link container/dev.sh' "$REPO_ROOT/install-macos.sh"
check "macos: LaunchAgent code"        grep -q 'io.podman.machine' "$REPO_ROOT/install-macos.sh"
check "macos: launchctl bootstrap"     grep -q 'launchctl bootstrap' "$REPO_ROOT/install-macos.sh"
check "macos: restore removes dev"     grep -q 'rm.*\.local/bin/dev' "$REPO_ROOT/install-macos.sh"
check "wsl: dev.sh link"              grep -q 'link container/dev.sh' "$REPO_ROOT/install-wsl.sh"
check "wsl: no LaunchAgent"           bash -c "! grep -q 'launchctl' '$REPO_ROOT/install-wsl.sh'"

# ── Regression: Plans 2–12 link() calls preserved ──────────────────────────
echo ""
echo "Regression — macOS link() calls:"
check "macos: bash links preserved"     test "$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: git links preserved"      test "$(grep -c 'link git/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "macos: kitty links preserved"    test "$(grep -c 'link kitty/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: tmux links preserved"     test "$(grep -c 'link tmux/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: starship links preserved" test "$(grep -c 'link starship/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: lazygit links preserved"  test "$(grep -c 'link lazygit/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: mise links preserved"     test "$(grep -c 'link mise/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: opencode links preserved" test "$(grep -c 'link opencode/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: nvim links preserved"     test "$(grep -c 'link nvim' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: prek links preserved"     test "$(grep -c 'link prek/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: vscode links preserved"   test "$(grep -c 'link vscode/' "$REPO_ROOT/install-macos.sh")" -eq 2

echo ""
echo "Regression — WSL link() calls:"
check "wsl: bash links preserved"       test "$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: git links preserved"        test "$(grep -c 'link git/' "$REPO_ROOT/install-wsl.sh")" -eq 2
check "wsl: kitty links preserved"      test "$(grep -c 'link kitty/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: tmux links preserved"       test "$(grep -c 'link tmux/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: starship links preserved"   test "$(grep -c 'link starship/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: lazygit links preserved"    test "$(grep -c 'link lazygit/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: mise links preserved"       test "$(grep -c 'link mise/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: opencode links preserved"   test "$(grep -c 'link opencode/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: nvim links preserved"       test "$(grep -c 'link nvim' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: prek links preserved"       test "$(grep -c 'link prek/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: vscode links preserved"     test "$(grep -c 'link vscode/' "$REPO_ROOT/install-wsl.sh")" -eq 2

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Floor check: expect ~80 tests
if (( total < 72 )); then
  echo "WARNING: only $total tests ran (expected >= 72). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
