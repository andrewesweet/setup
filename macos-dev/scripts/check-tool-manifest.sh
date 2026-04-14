#!/usr/bin/env bash
# check-tool-manifest.sh — verify Brewfile and tools.txt are consistent
#
# Exits 0 if every `brew "name"` or `brew "tap/name"` entry in Brewfile has a
# matching `brew:name` or `brew:tap/name` entry in tools.txt.
# Cask lines are intentionally skipped (Brewfile-only, per design §5.3/§5.4).
#
# Does NOT check the reverse direction (tools.txt entries without Brewfile
# matches) because some tools are installed by non-brew means (bun, uv, etc.)
# and still appear in tools.txt as platform-specific install names.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BREWFILE="$REPO_ROOT/Brewfile"
TOOLS_TXT="$REPO_ROOT/tools.txt"

if [[ ! -f "$BREWFILE" ]]; then
  echo "ERROR: $BREWFILE not found" >&2
  exit 2
fi

if [[ ! -f "$TOOLS_TXT" ]]; then
  echo "ERROR: $TOOLS_TXT not found" >&2
  exit 2
fi

# Extract formula names from Brewfile.
# Casks are intentionally skipped — they are Brewfile-only per design
# docs/plans/2026-04-14-macos-desktop-env-design.md §5.3 / §5.4.
# tools.txt is the formula manifest, not the full Brewfile mirror.
brewfile_formulas=$(
  grep -E '^brew "' "$BREWFILE" \
    | sed -E 's/^brew "([^"]+)".*/\1/'
)

# Extract brew: fields from tools.txt.
# Matches the second whitespace-separated field that starts with brew:
# Strips the "brew:" prefix.
tools_txt_brew=$(
  grep -v '^#' "$TOOLS_TXT" \
    | grep -v '^[[:space:]]*$' \
    | awk '{for (i=1;i<=NF;i++) if ($i ~ /^brew:/) print substr($i,6)}' \
    | grep -v '^-$'
)

missing=0
while IFS= read -r formula; do
  [[ -z "$formula" ]] && continue
  if ! echo "$tools_txt_brew" | grep -qx "$formula"; then
    echo "MISSING in tools.txt: $formula (from Brewfile)" >&2
    missing=$((missing + 1))
  fi
done <<< "$brewfile_formulas"

if (( missing > 0 )); then
  echo "" >&2
  echo "check-tool-manifest: $missing formula(s) in Brewfile are not listed in tools.txt" >&2
  echo "Add them to tools.txt with the correct category, or remove from Brewfile." >&2
  exit 1
fi

echo "check-tool-manifest: all $(echo "$brewfile_formulas" | wc -l | tr -d ' ') Brewfile entries present in tools.txt"
exit 0
