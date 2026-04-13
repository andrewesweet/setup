#!/usr/bin/env bash
# test-plan-layer1c.sh — acceptance tests for Layer 1c (ghq + ghorg + shell helpers)
#
# Platform-aware: runs on macOS and WSL2/Linux.
#
# Usage:
#   bash scripts/test-plan-layer1c.sh              # safe tests only
#   bash scripts/test-plan-layer1c.sh --full       # + invasive tests (runs tools, spawns bash -ic)
#
# Each AC from the Layer 1c plan is implemented as a labelled check.
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

echo "Layer 1c acceptance tests (ghq + ghorg + shell helpers)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1: Brewfile installs ghq and ghorg ──────────────────────────────
echo "AC-1: Brewfile installs ghq and ghorg"
check "Brewfile has brew \"ghq\""        grep -qE '^\s*brew\s+"ghq"' Brewfile
check "Brewfile has brew \"ghorg\""      grep -qE '^\s*brew\s+"ghorg"' Brewfile
if [[ "$FULL" == true ]]; then
  check "ghq is on PATH"                 command -v ghq
  check "ghorg is on PATH"               command -v ghorg
else
  skp "ghq on PATH" "safe mode"
  skp "ghorg on PATH" "safe mode"
fi

# ── AC-2: tools.txt manifest consistency ──────────────────────────────
echo ""
echo "AC-2: tools.txt manifest consistency"
check "check-tool-manifest.sh passes"    bash scripts/check-tool-manifest.sh

# AC-3 through AC-14 — stubs to be filled by later tasks.

# ── AC-3: git/.gitconfig sets ghq.root ────────────────────────────────
echo ""
echo "AC-3: git/.gitconfig declares ghq.root"
check "git config ghq.root = ~/code" \
  bash -c 'root=$(git config --file git/.gitconfig ghq.root 2>/dev/null); [[ "$root" == "~/code" ]]'

# ── AC-4: ghq root resolves to $HOME/code (full only) ────────────────
echo ""
echo "AC-4: ghq root command resolves"
if [[ "$FULL" == true ]] && command -v ghq &>/dev/null; then
  actual="$(ghq root 2>/dev/null)"
  expected="$HOME/code"
  if [[ "$actual" == "$expected" ]]; then
    ok "ghq root = \$HOME/code"
  else
    nok "ghq root = \$HOME/code (got: $actual)"
  fi
else
  skp "ghq root = \$HOME/code" "requires --full + ghq installed + symlinks"
fi

# ── AC-5: `repo` function defined ─────────────────────────────────────
echo ""
echo "AC-5: repo function invokes ghq+fzf"
check "bash/.bash_aliases defines repo()" \
  bash -c "awk '/^repo\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'ghq list --full-path'"
check "repo body pipes through fzf" \
  bash -c "awk '/^repo\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'fzf'"

# ── AC-6: `gclone` function with -e -p and guard ─────────────────────
echo ""
echo "AC-6: gclone uses exact-path lookup with a guard"
check "gclone uses 'ghq get -u'" \
  bash -c "awk '/^gclone\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'ghq get -u'"
check "gclone uses 'ghq list -e -p'" \
  bash -c "awk '/^gclone\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'ghq list -e -p'"
check "gclone has a guard against empty/missing target" \
  bash -c "awk '/^gclone\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -qE 'return 1|-d '"

# ── AC-7: `ghorg-gh` function ─────────────────────────────────────────
echo ""
echo "AC-7: ghorg-gh pins --path into the ghq tree"
check "ghorg-gh calls 'ghorg clone'" \
  bash -c "awk '/^ghorg-gh\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'ghorg clone'"
check "ghorg-gh passes '--path ~/code/github.com'" \
  bash -c "awk '/^ghorg-gh\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'path ~/code/github.com'"
check "ghorg-gh does NOT pass --output-dir" \
  bash -c "! awk '/^ghorg-gh\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'output-dir'"

# ── AC-8: Alt-R bound to repo in bash readline ────────────────────────
echo ""
echo "AC-8: Alt-R binding for repo"
# Structural check: a bind line for \er that calls repo exists
check "bash/.bashrc binds \\er to repo" \
  grep -qE '^[[:space:]]*bind[[:space:]]+.*\\er.*repo' bash/.bashrc

if [[ "$FULL" == true ]]; then
  bind_out="$(bash --rcfile bash/.bashrc -ic 'bind -P 2>/dev/null | grep "\\\\er" || true' 2>/dev/null)"
  if printf '%s' "$bind_out" | grep -q 'repo'; then
    ok "interactive bash binds Alt-R to repo"
  else
    nok "interactive bash binds Alt-R to repo"
  fi
else
  skp "interactive bash binds Alt-R to repo" "requires --full"
fi

# ── AC-9: install-wsl.sh aborts if $HOME under /mnt/c ─────────────────
echo ""
echo "AC-9: WSL /mnt/c precondition"
# Static: the precondition function exists and guards DrvFs drive-letter mounts
check "install-wsl.sh contains check_home_on_ext4() function" \
  bash -c "awk '/^check_home_on_ext4\\(\\) \\{/,/^\\}/' install-wsl.sh | grep -qE '/mnt/\\[a-zA-Z\\]/'"
check "install-wsl.sh supports --check-preconditions" \
  grep -qE '\-\-check-preconditions' install-wsl.sh

# Full: spawn with simulated HOME
if [[ "$FULL" == true ]]; then
  # Case A: HOME under /mnt/c should abort
  set +e
  HOME=/mnt/c/Users/test bash install-wsl.sh --check-preconditions >/tmp/wsl-a.out 2>/tmp/wsl-a.err
  rc_a=$?
  set -e 2>/dev/null || true
  if [[ $rc_a -ne 0 ]] && grep -q '9P-mounted' /tmp/wsl-a.err; then
    ok "HOME=/mnt/c/... aborts with 9P-specific message"
  else
    nok "HOME=/mnt/c/... should abort citing 9P (rc=$rc_a)"
  fi
  # Case B: HOME on ext4 should succeed
  set +e
  HOME=/home/test-ext4-simulated bash install-wsl.sh --check-preconditions >/tmp/wsl-b.out 2>/tmp/wsl-b.err
  rc_b=$?
  set -e 2>/dev/null || true
  if [[ $rc_b -eq 0 ]]; then
    ok "HOME=/home/... passes preconditions"
  else
    nok "HOME=/home/... should pass preconditions (rc=$rc_b)"
  fi
else
  skp "HOME=/mnt/c/... aborts" "requires --full"
  skp "HOME=/home/... passes" "requires --full"
fi

# ── AC-10: AGENTS.md snippet exists with required content ─────────────
echo ""
echo "AC-10: agents/AGENTS.md.snippet"
check "snippet file exists"          test -f agents/AGENTS.md.snippet
check "snippet has Local repo layout heading" \
  grep -q '^## Local repo layout' agents/AGENTS.md.snippet
check "snippet mentions ghq get" \
  grep -q 'ghq get' agents/AGENTS.md.snippet
check "snippet forbids /mnt/c clones" \
  grep -q '/mnt/c' agents/AGENTS.md.snippet

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
