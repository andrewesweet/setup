#!/usr/bin/env bash
# install-ai-conventions.sh — append the Local repo layout section to ~/AGENTS.md
# Idempotent: running twice produces exactly one copy of the snippet.
#
# Both OpenCode and GitHub Copilot Coding Agent (VS Code) honour ~/AGENTS.md.

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
DOTFILES="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"

SNIPPET="$DOTFILES/agents/AGENTS.md.snippet"
TARGET="$HOME/AGENTS.md"

[[ -f "$SNIPPET" ]] || { echo "error: snippet not found at $SNIPPET" >&2; exit 1; }

mkdir -p "$(dirname "$TARGET")"
touch "$TARGET"

# Sentinel: the snippet's H2 heading. If already present, no-op.
if grep -qF '## Local repo layout' "$TARGET"; then
  echo "AGENTS.md already contains 'Local repo layout' — no change."
  exit 0
fi

# Separate with a blank line if file is non-empty and doesn't already end in one.
if [[ -s "$TARGET" ]]; then
  # Check if last char is a newline; if not, add one.
  last_char="$(tail -c1 "$TARGET" 2>/dev/null | od -An -c | tr -d ' ')"
  if [[ "$last_char" != '\n' ]]; then
    printf '\n' >> "$TARGET"
  fi
  # Add a blank separator line
  printf '\n' >> "$TARGET"
fi

cat "$SNIPPET" >> "$TARGET"
echo "Appended Local repo layout snippet to $TARGET"
