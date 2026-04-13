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

# ── AC-2: television/cable directory symlink ─────────────────────────────
echo ""
echo "AC-2: install scripts symlink television/cable as directory"
check "install-macos.sh links television/cable" \
  grep -qE '^link television/cable[[:space:]]+\.config/television/cable' install-macos.sh
check "install-wsl.sh links television/cable" \
  grep -qE '^link television/cable[[:space:]]+\.config/television/cable' install-wsl.sh

# ── AC-8: gh-dash config ─────────────────────────────────────────────────
echo ""
echo "AC-8: gh-dash/config.yml"
check "gh-dash/config.yml exists" test -f gh-dash/config.yml
check "gh-dash has prSections (>= 3)" \
  bash -c "grep -cE '^[[:space:]]*- title:' gh-dash/config.yml | awk '{exit !(\$1 >= 3)}'"
check "gh-dash defaults.view = prs"   grep -qE 'view:[[:space:]]*prs' gh-dash/config.yml
check "gh-dash pager.diff = diffnav"  grep -qE 'diff:[[:space:]]*"?diffnav"?' gh-dash/config.yml
check "gh-dash has lazygit keybinding" \
  grep -qE 'name:[[:space:]]*lazygit' gh-dash/config.yml
check "gh-dash has C → opencode binding" \
  bash -c 'grep -B1 -A4 -E "key:[[:space:]]*C\b" gh-dash/config.yml | grep -qE "tmux new-window|opencode"'
check "gh-dash theme uses Dracula palette (#BD93F9 or #6272A4)" \
  grep -qE '#BD93F9|#6272A4|#50FA7B' gh-dash/config.yml
check "install-macos.sh links gh-dash config" \
  grep -qE 'link\s+gh-dash/config\.yml' install-macos.sh
check "install-wsl.sh links gh-dash config" \
  grep -qE 'link\s+gh-dash/config\.yml' install-wsl.sh

# ── AC-9: install scripts install all gh extensions ──────────────────────
echo ""
echo "AC-9: gh extensions installed"
exts=(dlvhdr/gh-dash github/gh-copilot seachicken/gh-poi yusukebe/gh-markdown-preview k1Low/gh-grep github/gh-aw Link-/gh-token)
for e in "${exts[@]}"; do
  # Case-insensitive (-i) so either "k1Low" or "k1low" matches.
  check "install-macos.sh installs $e" \
    grep -iqE "gh extension install[[:space:]]+$e\b" install-macos.sh
  check "install-wsl.sh installs $e" \
    grep -iqE "gh extension install[[:space:]]+$e\b" install-wsl.sh
done
# -Pzo (not -PzoE; E+P are mutually exclusive in GNU grep). Allow up to 400
# chars of code between the gh guard and the first `gh extension install`.
check "install-macos.sh guards gh extension install on command -v gh" \
  bash -c "grep -Pzo '(?s)command -v gh[^\\n]*\\n.{0,400}gh extension install' install-macos.sh >/dev/null 2>&1"
check "install-wsl.sh guards gh extension install on command -v gh" \
  bash -c "grep -Pzo '(?s)command -v gh[^\\n]*\\n.{0,400}gh extension install' install-wsl.sh >/dev/null 2>&1"

# ── AC-10: new gh aliases exist with exact definitions ───────────────────
echo ""
echo "AC-10: gh extension aliases in bash/.bash_aliases"
check "alias ghd='gh dash'"                grep -qE "^alias ghd='gh dash'"                bash/.bash_aliases
check "alias ghce='gh copilot explain'"    grep -qE "^alias ghce='gh copilot explain'"    bash/.bash_aliases
check "alias ghcs='gh copilot suggest'"    grep -qE "^alias ghcs='gh copilot suggest'"    bash/.bash_aliases
check "alias ghp='gh poi'"                 grep -qE "^alias ghp='gh poi'"                 bash/.bash_aliases
check "alias ghmd='gh markdown-preview'"   grep -qE "^alias ghmd='gh markdown-preview'"   bash/.bash_aliases
check "alias ghg='gh grep'"                grep -qE "^alias ghg='gh grep'"                bash/.bash_aliases
check "alias ghaw='gh aw'"                 grep -qE "^alias ghaw='gh aw'"                 bash/.bash_aliases
check "no alias for gh-token (automation-only per design)" \
  bash -c "! grep -qE \"^alias .*='gh token\" bash/.bash_aliases"

# ── AC-11: cheat() has gh-ext + ghd + channels arms ──────────────────────
echo ""
echo "AC-11: cheat() arms for gh extensions and TV channels"
# Pre-materialise cheat body into a variable (here-string) to avoid SIGPIPE
# flakiness under `set -o pipefail` — see test-plan-layer1b-i.sh for detail.
CHEAT_BODY="$(awk '/^cheat\(\) \{/,/^\}/' bash/.bash_aliases | sed 's/#.*//')"
# Accept either separate `channels)` / `tv-channels)` arms or a combined
# `channels|tv-channels)` arm — both are valid bash case-label syntax.
for arm in 'gh-ext' 'ghd'; do
  if grep -qE "^[[:space:]]*${arm}\)" <<< "$CHEAT_BODY"; then
    ok "cheat: arm matching '$arm' present"
  else
    nok "cheat: arm matching '$arm' present"
  fi
done
if grep -qE '^[[:space:]]*(channels|tv-channels)[|)]' <<< "$CHEAT_BODY"; then
  ok "cheat: arm matching 'channels|tv-channels' present"
else
  nok "cheat: arm matching 'channels|tv-channels' present"
fi
check "cheat gh-ext runs gh extension list" grep -q 'gh extension list' <<< "$CHEAT_BODY"
check "cheat ghd mentions C → opencode"    grep -qiE 'C.*opencode|opencode.*C' <<< "$CHEAT_BODY"

# ── AC-12: cheatsheet.md sections ────────────────────────────────────────
echo ""
echo "AC-12: cheatsheet additions"
check "cheatsheet has TV channel triggers section" \
  grep -qE '^### Television channel triggers|^### TV channel triggers' docs/cheatsheet.md
check "cheatsheet has gh-dash workflow section" \
  grep -qE '^### gh-dash workflow|^### PR review via gh-dash' docs/cheatsheet.md
for a in ghd ghce ghcs ghp ghmd ghg ghaw; do
  check "cheatsheet lists $a" grep -qE "\\b$a\\b" docs/cheatsheet.md
done

# ── AC-13: verify.sh Layer 1b-iii block ──────────────────────────────────
echo ""
echo "AC-13: verify.sh Layer 1b-iii coverage"
check "verify.sh checks television/cable symlink" \
  grep -qE 'television/cable' scripts/verify.sh
check "verify.sh checks gh-dash config symlink" \
  grep -qE 'gh-dash/config\.yml' scripts/verify.sh
check "verify.sh iterates gh extensions" \
  grep -qE 'gh extension list' scripts/verify.sh

# ── AC-14: structural invariants preserved ───────────────────────────────
echo ""
echo "AC-14: structural invariants"
check ".bashrc section count unchanged (test-plan2.sh)" bash scripts/test-plan2.sh
check "starship unchanged (test-plan6-8.sh)"            bash scripts/test-plan6-8.sh

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
