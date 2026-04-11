#!/usr/bin/env bash
# test-tool-installs.sh — verify tool availability inside dev container
# Usage: test-tool-installs.sh [--full]
set -euo pipefail

pass=0; fail=0
check() { if command -v "$1" >/dev/null 2>&1; then echo "  ✓ $1"; ((pass++)); else echo "  ✗ $1"; ((fail++)); fi; }

echo "Container tool verification"
echo ""

# Base tools (agent-usable CLIs)
echo "Base tools:"
for tool in bash git curl ssh mise uv python3 go node bun opencode critique ruff ty prek \
            shellcheck shfmt golangci-lint gofumpt actionlint tflint zizmor \
            fd rg tree jq yq kubectl gcloud; do
  check "$tool"
done

# Full tools (human TUI layer, only checked with --full flag)
if [[ "${1:-}" == "--full" ]]; then
  echo ""
  echo "Full tools:"
  for tool in tmux starship lazygit btop fzf zoxide bat delta glow nvim k9s lazydocker; do
    check "$tool"
  done
fi

echo ""
echo "Results: $pass passed, $fail failed"
exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
