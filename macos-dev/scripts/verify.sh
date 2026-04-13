#!/usr/bin/env bash
# verify.sh — post-install verification script
#
# Checks:
#   1. Symlink verification (platform-aware: macOS vs WSL/Linux)
#   2. bash -n on all bash config files
#   3. Config parse validation (delegates to check-configs.sh)
#   4. Tool availability spot-checks
#   5. Prints remaining manual steps
#
# Usage: bash scripts/verify.sh
# Exit: 0 if all checks pass, 1 if any fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass=0
fail=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

ok() {
  printf "  ${GREEN}ok${RESET}  %s\n" "$1"
  pass=$((pass + 1))
}

nok() {
  printf "  ${RED}NOK${RESET} %s\n" "$1"
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

# ── Platform detection ──────────────────────────────────────────────────────
detect_platform() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos"
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    echo "wsl"
  else
    echo "linux"
  fi
}

PLATFORM="$(detect_platform)"
echo "verify.sh — post-install verification"
echo "Platform: $PLATFORM"
echo ""

# ── 1. Symlink verification ────────────────────────────────────────────────
echo "Symlink checks:"

# Common symlinks (all platforms)
common_links=(
  ".bash_profile"
  ".bashrc"
  ".bash_aliases"
  ".inputrc"
  ".gitconfig"
  ".gitignore_global"
  ".tmux.conf"
  ".config/kitty/kitty.conf"
  ".config/starship.toml"
  ".config/lazygit/config.yml"
  ".config/opencode/opencode.jsonc"
  ".config/opencode/tui.jsonc"
  ".config/opencode/instructions/git-conventions.md"
  ".config/opencode/instructions/scratch-dirs.md"
  ".config/mise/config.toml"
  ".config/nvim"
  ".local/bin/dev"
)

for link in "${common_links[@]}"; do
  check "symlink: ~/$link" test -L "$HOME/$link"
done

# Platform-specific symlinks
if [[ "$PLATFORM" == "macos" ]]; then
  check "symlink: VS Code settings (macOS)" \
    test -L "$HOME/Library/Application Support/Code/User/settings.json"
  check "symlink: VS Code extensions (macOS)" \
    test -L "$HOME/Library/Application Support/Code/User/extensions.json"
elif [[ "$PLATFORM" == "wsl" || "$PLATFORM" == "linux" ]]; then
  check "symlink: VS Code settings (WSL)" \
    test -L "$HOME/.vscode-server/data/Machine/settings.json"
fi

# ── 2. Bash syntax check ───────────────────────────────────────────────────
echo ""
echo "Bash syntax checks:"
for f in bash/.bash_profile bash/.bashrc bash/.bash_aliases; do
  check "bash -n $f" bash -n "$REPO_ROOT/$f"
done

# ── 3. Config parse validation ──────────────────────────────────────────────
echo ""
echo "Config validation (check-configs.sh):"
if [[ -x "$REPO_ROOT/scripts/check-configs.sh" ]]; then
  if bash "$REPO_ROOT/scripts/check-configs.sh" >/dev/null 2>&1; then
    ok "check-configs.sh passed"
  else
    nok "check-configs.sh failed"
  fi
else
  nok "check-configs.sh not found or not executable"
fi

# ── 4. Tool availability spot-checks ───────────────────────────────────────
echo ""
echo "Tool availability:"
tools=(git delta starship mise uv fzf bat rg fd)
for tool in "${tools[@]}"; do
  check "$tool available" command -v "$tool"
done

# ── Layer 1a tools ────────────────────────────────────────────────────────
echo ""
echo "Layer 1a tools:"
check "atuin on PATH"            command -v atuin
check "tv (television) on PATH"  command -v tv
# Symlink must exist AND its target must resolve (catches dangling symlinks).
check "atuin config symlink resolves" \
  bash -c 'test -L "$HOME/.config/atuin/config.toml" && test -e "$HOME/.config/atuin/config.toml"'
check "television config symlink resolves" \
  bash -c 'test -L "$HOME/.config/television/config.toml" && test -e "$HOME/.config/television/config.toml"'

# ── Layer 1c tools ────────────────────────────────────────────────────────
echo ""
echo "Layer 1c tools:"
check "ghq on PATH"              command -v ghq
check "ghorg on PATH"            command -v ghorg
if command -v ghq &>/dev/null; then
  ghq_root_actual="$(ghq root 2>/dev/null)"
  if [[ "$ghq_root_actual" == "$HOME/code" ]]; then
    ok "ghq root resolves to \$HOME/code"
  else
    nok "ghq root resolves to \$HOME/code (got: $ghq_root_actual)"
  fi
fi

# ── 5. Manual steps reminder ───────────────────────────────────────────────
echo ""
echo "${YELLOW}── Remaining manual steps ──${RESET}"
echo "  1. Neovim: open nvim and let LSP servers install via Mason"
echo "  2. OpenCode: run 'opencode auth login' for GitHub Copilot"
echo "  3. GCP: run 'gcloud auth login' and 'gcloud auth application-default login'"
echo "  4. Switch shell: chsh -s \$(brew --prefix)/bin/bash  (macOS)"
echo ""

# ── Summary ─────────────────────────────────────────────────────────────────
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (${RED}%d failed${RESET})" "$fail"
fi
echo ""

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
