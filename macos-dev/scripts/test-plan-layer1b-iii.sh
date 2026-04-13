#!/usr/bin/env bash
# test-plan-layer1b-iii.sh — acceptance tests for Layer 1b-iii (cable channels + gh extensions + gh-dash)
#
# Platform-aware: runs on macOS and WSL2/Linux.
#
# Usage:
#   bash scripts/test-plan-layer1b-iii.sh              # safe tests only
#   bash scripts/test-plan-layer1b-iii.sh --full       # + invasive tests (bash -lc init checks)
#
# Each AC from the Layer 1b-iii plan is implemented as a labelled check.
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

echo "Layer 1b-iii acceptance tests (TV cable channels + gh extensions + gh-dash)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1: all cable channel files exist ──────────────────────────────────
echo "AC-1: cable channel files"
for c in alias env dirs files procs \
         git-branch git-diff git-log git-stash git-worktrees \
         git-reflog git-remotes git-repos \
         docker-containers docker-images \
         k8s-pods k8s-contexts \
         make-targets ssh-hosts \
         gcloud-configs gcloud-instances gcloud-run-services gcloud-sql; do
  check "television/cable/$c.toml exists" test -f "television/cable/$c.toml"
done

# ── AC-3: git-repos.toml sources from ghq ────────────────────────────────
echo ""
echo "AC-3: git-repos channel sources from ghq list --full-path"
check "git-repos.toml uses 'ghq list --full-path'" \
  grep -qE 'ghq list --full-path' television/cable/git-repos.toml
check "git-repos.toml has no pre-1c fd fallback" \
  bash -c "! grep -qE 'fd.*\\.git\\\$' television/cable/git-repos.toml"

# ── AC-4: env.toml filters secrets ───────────────────────────────────────
echo ""
echo "AC-4: env.toml filters sensitive patterns"
for p in GITHUB_TOKEN GH_TOKEN 'AWS_' SECRET PASSWORD KEY BEARER AUTHORIZATION ANTHROPIC OPENAI; do
  check "env.toml filter covers $p" grep -qE "$p" television/cable/env.toml
done

# ── AC-5: procs.toml uses POSIX ps flags ─────────────────────────────────
echo ""
echo "AC-5: procs.toml POSIX ps flags"
check "procs.toml uses 'ps -e -o pid=,ucomm='" \
  grep -qE 'ps -e -o pid=,ucomm=' television/cable/procs.toml
check "procs.toml avoids GNU-only --no-headers" \
  bash -c "! grep -q -- '--no-headers' television/cable/procs.toml"

# ── AC-6: docker-*.toml use podman ───────────────────────────────────────
echo ""
echo "AC-6: docker channels use podman"
check "docker-containers.toml uses podman" \
  grep -qE '^command = "podman ' television/cable/docker-containers.toml
check "docker-images.toml uses podman" \
  grep -qE '^command = "podman ' television/cable/docker-images.toml
check "docker-containers.toml does not invoke bare docker" \
  bash -c "! grep -qE '^command = \"docker ' television/cable/docker-containers.toml"

# ── AC-7: gcloud channels present with value-format commands ────────────
echo ""
echo "AC-7: gcloud channels"
for g in gcloud-configs gcloud-instances gcloud-run-services gcloud-sql; do
  check "$g.toml exists"                 test -f television/cable/$g.toml
  check "$g.toml uses gcloud"            grep -qE 'command = "gcloud ' television/cable/$g.toml
  check "$g.toml uses --format=value()"  grep -qE "format=.value\\(" television/cable/$g.toml
done

# Later tasks append AC-2, AC-8 through AC-15.

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
