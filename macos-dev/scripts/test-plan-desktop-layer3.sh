#!/usr/bin/env bash
# test-plan-desktop-layer3.sh — acceptance tests for Desktop Layer 3 (Raycast launcher)
#
# Platform-aware: runs on macOS and WSL2/Linux.
#
# Usage:
#   bash scripts/test-plan-desktop-layer3.sh              # safe tests only
#   bash scripts/test-plan-desktop-layer3.sh --full       # + invasive tests
#
# Each AC from the Desktop Layer 3 plan is implemented as a labelled check.
# Exits 0 if all requested tests pass, 1 otherwise.

set -uo pipefail

# ── Self-resolve to macos-dev root ───────────────────────────────────────────
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
MACOS_DEV="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"
cd "$MACOS_DEV" || { echo "ERROR: cannot cd to $MACOS_DEV" >&2; exit 2; }

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)
    PLATFORM="linux"
    [[ -n "${WSL_DISTRO_NAME:-}" ]] && PLATFORM="wsl"
    ;;
  *) echo "ERROR: unsupported platform" >&2; exit 2 ;;
esac

if [[ -t 1 ]]; then
  C_GREEN=$'\033[0;32m' C_RED=$'\033[0;31m' C_YELLOW=$'\033[0;33m' C_RESET=$'\033[0m'
else
  C_GREEN='' C_RED='' C_YELLOW='' C_RESET=''
fi

pass=0
fail=0
skip=0

ok()   { printf "  ${C_GREEN}✓${C_RESET} %s\n" "$1"; pass=$((pass + 1)); }
nok()  { printf "  ${C_RED}✗${C_RESET} %s\n" "$1"; fail=$((fail + 1)); }
skp()  { printf "  ${C_YELLOW}~${C_RESET} %s (skipped: %s)\n" "$1" "$2"; skip=$((skip + 1)); }

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else nok "$desc"; fi
}

echo "Desktop Layer 3 acceptance tests (Raycast launcher)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1: Brewfile declares Raycast cask ─────────────────────────────
echo ""
echo "AC-1: Brewfile declares Raycast cask"
check "Brewfile has cask \"raycast\"" \
  grep -qE '^cask "raycast"' Brewfile
check "check-tool-manifest.sh still passes" \
  bash scripts/check-tool-manifest.sh

# ── AC-2: raycast/extensions.md two-section structure ────────────────
echo ""
echo "AC-2: raycast/extensions.md two-section structure"
check "file exists" test -f raycast/extensions.md
check "top-level '# Raycast' header" \
  grep -qE '^# Raycast' raycast/extensions.md
check "## Summary header" \
  grep -qE '^## Summary' raycast/extensions.md
check "## Post-install checklist header" \
  grep -qE '^## Post-install checklist' raycast/extensions.md
check "## Recommended extensions header" \
  grep -qE '^## Recommended extensions' raycast/extensions.md

# ── AC-3: Post-install checklist 8 documented steps ──────────────────
echo ""
echo "AC-3: Post-install checklist covers 8 documented steps"
checklist="$(awk '/^## Post-install checklist/,/^## Recommended extensions/' raycast/extensions.md)"
for needle in 'Launch Raycast' \
              'Accessibility' \
              'Start at login' \
              'Cmd.*Space' \
              'Spotlight' \
              'Pop to root' \
              'Auto-switch input source' \
              'sign.in\|Account'; do
  if printf '%s' "$checklist" | grep -qE "$needle"; then
    ok "checklist mentions: $needle"
  else
    nok "checklist mentions: $needle"
  fi
done

# ── AC-4: Recommended extensions — 7 curated items ──────────────────
echo ""
echo "AC-4: Recommended extensions lists 7 curated items"
recommended="$(awk '/^## Recommended extensions/,0' raycast/extensions.md)"
for ext in 'Brew' 'GitHub' 'Kill Process' 'System' 'Clipboard History' 'Color Picker' 'Visual Studio Code'; do
  if printf '%s' "$recommended" | grep -qF "$ext"; then
    ok "Recommended extensions lists: $ext"
  else
    nok "Recommended extensions lists: $ext"
  fi
done

# ── AC-5: Next-steps references raycast/extensions.md ────────────────
echo ""
echo "AC-5: install-macos.sh Next-steps references raycast/extensions.md"
next="$(awk '/Next steps:/,/^EOF$/' install-macos.sh)"
if printf '%s' "$next" | grep -qF 'raycast/extensions.md'; then
  ok "Next-steps mentions raycast/extensions.md"
else
  nok "Next-steps mentions raycast/extensions.md"
fi

# ── AC-6: Next-steps /etc/hosts blackhole commands ──────────────────
echo ""
echo "AC-6: Next-steps includes /etc/hosts blackhole for Raycast sync"
for domain in 'backend.raycast.com' 'api.raycast.com' 'sync.raycast.com'; do
  if printf '%s' "$next" | grep -qF "$domain"; then
    ok "Next-steps mentions $domain"
  else
    nok "Next-steps mentions $domain"
  fi
done
if printf '%s' "$next" | grep -qE '0\.0\.0\.0'; then
  ok "Next-steps uses 0.0.0.0 blackhole target"
else
  nok "Next-steps uses 0.0.0.0 blackhole target"
fi

# ── AC-7: manual-smoke/desktop-layer3.md populated ──────────────────
echo ""
echo "AC-7: manual-smoke/desktop-layer3.md populated"
check "file exists" test -f docs/manual-smoke/desktop-layer3.md
check "has 'When to run' section" \
  grep -qE '^## When to run' docs/manual-smoke/desktop-layer3.md
check "has 'Checklist' section" \
  grep -qE '^## Checklist' docs/manual-smoke/desktop-layer3.md
check "has 'Failure modes' section" \
  grep -qE '^## Failure modes' docs/manual-smoke/desktop-layer3.md
checklist_items=$(awk '/^## Checklist/,/^## Failure modes/' docs/manual-smoke/desktop-layer3.md \
                  | grep -cE '^- \[ \]')
failure_items=$(awk '/^## Failure modes/,0' docs/manual-smoke/desktop-layer3.md \
               | grep -cE '^- \[ \]')
if (( checklist_items >= 6 )); then
  ok "checklist has ≥ 6 items ($checklist_items)"
else
  nok "checklist has ≥ 6 items ($checklist_items)"
fi
if (( failure_items >= 2 )); then
  ok "failure modes has ≥ 2 drill items ($failure_items)"
else
  nok "failure modes has ≥ 2 drill items ($failure_items)"
fi

# ── AC-8: test-plan-desktop-layer3.sh wired into CI ──────────────────
echo ""
echo "AC-8: test-plan-desktop-layer3.sh wired into verify.yml"
REPO_ROOT="$(cd "$MACOS_DEV/.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/verify.yml"
if [[ -f "$WORKFLOW" ]]; then
  hits=$(grep -c 'test-plan-desktop-layer3.sh' "$WORKFLOW" || true)
  if (( hits >= 2 )); then
    ok "verify.yml invokes test-plan-desktop-layer3.sh ($hits times)"
  else
    nok "verify.yml invokes test-plan-desktop-layer3.sh ($hits times; need ≥ 2)"
  fi
else
  skp "verify.yml wiring" "workflow not found"
fi

# ── AC-9 gets appended by subsequent tasks ────────────────────────────

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
