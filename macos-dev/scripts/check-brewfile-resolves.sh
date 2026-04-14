#!/usr/bin/env bash
# check-brewfile-resolves.sh — verify every Brewfile entry is resolvable
# on the current system, without actually installing anything.
#
# Catches bugs like unqualified `brew "sketchybar"` that require a tap
# but can't auto-resolve under `brew bundle` on a fresh runner (the
# failure mode that slipped past all three desktop-layer PR gates and
# only surfaced on push-to-main via the macos-install job).
#
# Passes, in order:
#   1. Every `tap "X"` line → `brew tap X` (idempotent; adds third-party
#      taps so pass 2 can look up their formulae).
#   2. Every `brew "X"` line → `brew info X` (exit 0 means resolvable).
#   3. Every `cask "X"` line → `brew info --cask X` (exit 0 means resolvable).
#
# Skips silently when brew is not installed (CI's Linux lint job).
#
# Usage: bash scripts/check-brewfile-resolves.sh [path/to/Brewfile]
# Default Brewfile path: macos-dev/Brewfile (relative to repo root).

set -uo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd -P "$SCRIPT_DIR/.." && pwd)"
BREWFILE="${1:-$DOTFILES/Brewfile}"

if [[ ! -f "$BREWFILE" ]]; then
  echo "ERROR: Brewfile not found at $BREWFILE" >&2
  exit 2
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "brew not installed — skipping Brewfile resolve check."
  echo "(This check is intended for macOS runners; Linux lint jobs"
  echo "validate Brewfile syntax via bash -n / shellcheck only.)"
  exit 0
fi

echo "Brewfile resolve check: $BREWFILE"
echo ""

ok=0
fail=0

# ── Pass 1: taps ──────────────────────────────────────────────────────
while IFS= read -r tap; do
  [[ -z "$tap" ]] && continue
  if brew tap "$tap" >/dev/null 2>&1; then
    printf "  \033[0;32m✓\033[0m tap \"%s\"\n" "$tap"
    ok=$((ok + 1))
  else
    printf "  \033[0;31m✗\033[0m tap \"%s\" failed to add\n" "$tap"
    fail=$((fail + 1))
  fi
done < <(grep -oE '^tap "[^"]+"' "$BREWFILE" | sed -E 's/^tap "(.*)"$/\1/')

# ── Pass 2: brew formulae ─────────────────────────────────────────────
while IFS= read -r formula; do
  [[ -z "$formula" ]] && continue
  if brew info "$formula" >/dev/null 2>&1; then
    printf "  \033[0;32m✓\033[0m brew \"%s\"\n" "$formula"
    ok=$((ok + 1))
  else
    printf "  \033[0;31m✗\033[0m brew \"%s\" does not resolve\n" "$formula"
    fail=$((fail + 1))
  fi
done < <(grep -oE '^brew "[^"]+"' "$BREWFILE" | sed -E 's/^brew "(.*)"$/\1/')

# ── Pass 3: casks ─────────────────────────────────────────────────────
while IFS= read -r cask; do
  [[ -z "$cask" ]] && continue
  if brew info --cask "$cask" >/dev/null 2>&1; then
    printf "  \033[0;32m✓\033[0m cask \"%s\"\n" "$cask"
    ok=$((ok + 1))
  else
    printf "  \033[0;31m✗\033[0m cask \"%s\" does not resolve\n" "$cask"
    fail=$((fail + 1))
  fi
done < <(grep -oE '^cask "[^"]+"' "$BREWFILE" | sed -E 's/^cask "(.*)"$/\1/')

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Resolved: \033[0;32m%d\033[0m  Failed: \033[0;31m%d\033[0m\n" "$ok" "$fail"

exit "$(( fail > 0 ? 1 : 0 ))"
