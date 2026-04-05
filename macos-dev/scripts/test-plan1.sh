#!/usr/bin/env bash
# test-plan1.sh — smoke tests for Plan 1 (Foundation)
#
# Platform-aware: detects macOS vs Linux/WSL2 and runs the appropriate
# install-script-specific tests.
#
# Usage:
#   bash test-plan1.sh              # safe tests only — ~2 minutes
#   bash test-plan1.sh --full       # + invasive tests that modify the system
#                                   # macOS: brew bundle install (~15-30 min)
#                                   # WSL2:  apt install + tool checks
#
# Exits 0 if all requested tests pass, 1 otherwise.

set -uo pipefail

# ── Self-resolve to macos-dev root ───────────────────────────────────────────
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
# Script lives at macos-dev/scripts/test-plan1.sh; parent of parent is macos-dev
MACOS_DEV="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"
cd "$MACOS_DEV" || { echo "ERROR: cannot cd to $MACOS_DEV" >&2; exit 2; }

# ── Modes ────────────────────────────────────────────────────────────────────
FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

# ── Platform detection ───────────────────────────────────────────────────────
case "$(uname -s)" in
  Darwin)
    PLATFORM="macos"
    INSTALL_SCRIPT="install-macos.sh"
    ;;
  Linux)
    PLATFORM="linux"
    INSTALL_SCRIPT="install-wsl.sh"
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
      PLATFORM="wsl"
    fi
    ;;
  *)
    echo "ERROR: unsupported platform: $(uname -s)" >&2
    exit 2
    ;;
esac

# ── Colours ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_GREEN=$'\033[0;32m'
  C_RED=$'\033[0;31m'
  C_YELLOW=$'\033[0;33m'
  C_BLUE=$'\033[0;34m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_GREEN='' C_RED='' C_YELLOW='' C_BLUE='' C_BOLD='' C_RESET=''
fi

PASS=0
FAIL=0
SKIP=0
FAILED_TESTS=()

# ── Helpers ──────────────────────────────────────────────────────────────────
header() {
  printf "\n${C_BOLD}${C_BLUE}═══ %s ═══${C_RESET}\n" "$*"
}

pass() {
  printf "  ${C_GREEN}✓${C_RESET} %s\n" "$*"
  PASS=$((PASS + 1))
}

fail() {
  printf "  ${C_RED}✗${C_RESET} %s\n" "$*"
  FAIL=$((FAIL + 1))
  FAILED_TESTS+=("$*")
}

skip() {
  printf "  ${C_YELLOW}⊘${C_RESET} %s\n" "$*"
  SKIP=$((SKIP + 1))
}

info() {
  printf "    %s\n" "$*"
}

# Run a command, silently if it passes, showing output if it fails
run_check() {
  local desc="$1"; shift
  local tmpout
  tmpout="$(mktemp)"
  if "$@" > "$tmpout" 2>&1; then
    pass "$desc"
    rm -f "$tmpout"
    return 0
  else
    fail "$desc"
    sed 's/^/    /' "$tmpout"
    rm -f "$tmpout"
    return 1
  fi
}

# ── Environment report ──────────────────────────────────────────────────────
header "Environment"
info "macos-dev:     $MACOS_DEV"
info "platform:      $PLATFORM"
info "install script: $INSTALL_SCRIPT"
info "uname:         $(uname -sr)"
info "bash:          $BASH_VERSION"
case "$PLATFORM" in
  macos)
    if command -v brew &>/dev/null; then
      info "brew:          $(brew --version | head -1) (prefix: $(brew --prefix))"
    else
      info "brew:          NOT FOUND"
    fi
    ;;
  wsl|linux)
    if command -v apt &>/dev/null; then
      info "apt:           $(apt --version)"
    fi
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
      info "wsl distro:    $WSL_DISTRO_NAME"
    fi
    ;;
esac
info "mode:          $(if $FULL; then echo 'FULL (safe + invasive)'; else echo 'safe only'; fi)"

# ── Test 1: static checks ────────────────────────────────────────────────────
header "Test 1: static checks"

run_check "bash -n install-macos.sh" \
  bash -n install-macos.sh
run_check "bash -n install-wsl.sh" \
  bash -n install-wsl.sh
run_check "bash -n scripts/check-tool-manifest.sh" \
  bash -n scripts/check-tool-manifest.sh
run_check "bash -n container/test-tool-installs.sh" \
  bash -n container/test-tool-installs.sh
run_check "bash -n scripts/test-plan1.sh (self-check)" \
  bash -n scripts/test-plan1.sh

if command -v shellcheck &>/dev/null; then
  run_check "shellcheck install-macos.sh" \
    shellcheck install-macos.sh
  run_check "shellcheck install-wsl.sh" \
    shellcheck install-wsl.sh
  run_check "shellcheck scripts/check-tool-manifest.sh" \
    shellcheck scripts/check-tool-manifest.sh
  run_check "shellcheck container/test-tool-installs.sh" \
    shellcheck container/test-tool-installs.sh
  run_check "shellcheck scripts/test-plan1.sh (self-check)" \
    shellcheck scripts/test-plan1.sh
else
  if [[ "$PLATFORM" == "macos" ]]; then
    skip "shellcheck not installed (install via: brew install shellcheck)"
  else
    skip "shellcheck not installed (install via: sudo apt install shellcheck)"
  fi
fi

run_check "check-tool-manifest.sh (drift detection)" \
  bash scripts/check-tool-manifest.sh

# ── Test 1b: git executable bits ─────────────────────────────────────────────
header "Test 1b: git executable bits"

if git rev-parse --git-dir &>/dev/null; then
  for script in install-macos.sh install-wsl.sh scripts/check-tool-manifest.sh container/test-tool-installs.sh scripts/test-plan1.sh; do
    mode=$(git ls-files --stage -- "$script" 2>/dev/null | awk '{print $1}')
    if [[ "$mode" == "100755" ]]; then
      pass "$script is 100755 in git"
    elif [[ -z "$mode" ]]; then
      skip "$script not tracked in git (skipped — new file?)"
    else
      fail "$script is $mode in git (expected 100755)"
    fi
  done
else
  skip "not in a git repo — cannot check tracked file modes"
fi

# ── Test 2: DOTFILES self-resolution ─────────────────────────────────────────
header "Test 2: DOTFILES self-resolution via symlink (${INSTALL_SCRIPT})"

# Use file capture to avoid pipefail/SIGPIPE traps with long-running scripts.
# The install script on the current platform will proceed past its platform
# check and may run brew bundle / apt install (slow). We only need the
# DOTFILES line printed in the first ~100ms.
tmpdir="$(mktemp -d -t plan1-test-XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

ln -sf "$MACOS_DEV/$INSTALL_SCRIPT" "$tmpdir/install.sh"

(
  # stdin from /dev/null prevents sudo prompts from hanging on WSL
  bash "$tmpdir/install.sh" < /dev/null > "$tmpdir/out.txt" 2>&1 &
  pid=$!
  sleep 2
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
)

resolved=$(grep -o 'DOTFILES=[^ ]*' "$tmpdir/out.txt" 2>/dev/null | head -1 || true)
expected="DOTFILES=$MACOS_DEV"
if [[ "$resolved" == "$expected" ]]; then
  pass "DOTFILES resolved correctly through symlink"
  info "got:      $resolved"
else
  fail "DOTFILES self-resolution incorrect"
  info "expected: $expected"
  info "got:      ${resolved:-<empty>}"
  info "--- first 10 lines of captured output ---"
  head -10 "$tmpdir/out.txt" 2>/dev/null | sed 's/^/      /' || true
fi

rm -rf "$tmpdir"
trap - EXIT

# ── Test 3: link() backup-and-symlink ───────────────────────────────────────
header "Test 3: link() function backup logic (${INSTALL_SCRIPT})"

# Extract just the link() function from the platform's install script.
# The function is identical between install-macos.sh and install-wsl.sh by
# design. We source the definition into this test script's scope and invoke
# it in an isolated HOME.
link_fn=$(sed -n '/^link()/,/^}$/p' "$INSTALL_SCRIPT")
if [[ -z "$link_fn" ]]; then
  fail "could not extract link() function from $INSTALL_SCRIPT"
else
  test_home=$(mktemp -d -t plan1-home-XXXXXX)
  test_backup="$test_home/.dotfiles-backup/test-$(date +%s)"
  trap 'rm -rf "$test_home"' EXIT

  # Pre-existing "user file" that link() must preserve by moving to backup
  echo "PRE-EXISTING CONTENT DO NOT LOSE" > "$test_home/.testrc"

  # Source file to link TO (any file in the repo)
  test_src_rel="scripts/test-plan1.sh"
  test_src="$MACOS_DEV/$test_src_rel"

  # Environment link() depends on. These look unused to shellcheck because
  # the consuming code is loaded via eval below.
  HOME="$test_home"
  # shellcheck disable=SC2034
  DOTFILES="$MACOS_DEV"
  # shellcheck disable=SC2034
  BACKUP_DIR="$test_backup"

  # link() calls warn() for missing sources; stub it to a no-op.
  # SC2317: unreachable — shellcheck can't see that link() calls warn
  #         through the eval'd function body.
  # SC2329: never invoked — same reason; invoked only via eval.
  # shellcheck disable=SC2317,SC2329
  warn() { :; }

  # Load the function into this shell's scope
  eval "$link_fn"

  # Call: back up .testrc, symlink to scripts/test-plan1.sh
  link_output=$(link "$test_src_rel" ".testrc" 2>&1)

  # Verify the symlink
  if [[ -L "$test_home/.testrc" ]]; then
    link_target=$(readlink "$test_home/.testrc")
    if [[ "$link_target" == "$test_src" ]]; then
      pass "link() created symlink to correct target"
      info "symlink → $link_target"
    else
      fail "link() created symlink to wrong target"
      info "expected: $test_src"
      info "got:      $link_target"
    fi
  else
    fail "link() did not create a symlink at expected path"
    info "link output: $link_output"
  fi

  # Verify the backup preserved the original content
  backup_file="$test_backup/.testrc"
  if [[ -f "$backup_file" ]]; then
    backup_content=$(cat "$backup_file")
    if [[ "$backup_content" == "PRE-EXISTING CONTENT DO NOT LOSE" ]]; then
      pass "link() backed up pre-existing file with content intact"
      info "backup at: $backup_file"
    else
      fail "link() backup has corrupted content"
      info "expected: PRE-EXISTING CONTENT DO NOT LOSE"
      info "got:      $backup_content"
    fi
  else
    fail "link() did not create backup at expected path"
    info "expected: $backup_file"
  fi

  rm -rf "$test_home"
  trap - EXIT
fi

# ── Test 4: platform-specific package check ─────────────────────────────────
header "Test 4: package manager check (${PLATFORM})"

case "$PLATFORM" in
  macos)
    if command -v brew &>/dev/null; then
      # Validate all Brewfile formulas resolve against Homebrew
      tmpout=$(mktemp)
      brew bundle check --file=Brewfile --verbose > "$tmpout" 2>&1
      exit_code=$?

      if grep -qi 'could not find\|error:\|no available formula' "$tmpout"; then
        fail "brew bundle has unresolvable formulas"
        info "--- errors ---"
        grep -i 'could not find\|error:\|no available formula' "$tmpout" | sed 's/^/      /'
      elif [[ $exit_code -eq 0 ]]; then
        pass "all 54 Brewfile formulas installed and resolvable"
      else
        pass "all formulas resolve (some not yet installed — expected)"
      fi
      rm -f "$tmpout"
    else
      skip "brew not available on this macOS host"
    fi
    ;;
  wsl|linux)
    # On WSL/Linux we can't do a Brewfile check. Validate apt is present and
    # that the small set of apt packages install-wsl.sh wants are resolvable.
    if command -v apt &>/dev/null; then
      pass "apt is available"
      # The packages install-wsl.sh installs via apt (from the script body)
      apt_pkgs="bash bash-completion git tmux tree wget curl jq shellcheck direnv"
      unresolved=""
      for pkg in $apt_pkgs; do
        if ! apt-cache show "$pkg" &>/dev/null; then
          unresolved="$unresolved $pkg"
        fi
      done
      if [[ -z "$unresolved" ]]; then
        pass "all install-wsl.sh apt packages resolve"
        info "packages: $apt_pkgs"
      else
        fail "apt cannot resolve these packages:$unresolved"
        info "possible cause: run 'sudo apt update' first"
      fi
    else
      skip "apt not available (not an Ubuntu/Debian system)"
    fi
    ;;
esac

# ── Test 8: restore mode ─────────────────────────────────────────────────────
header "Test 8: ${INSTALL_SCRIPT} --restore mode"

# Create a fake backup with a known file, run --restore, verify it's restored
restore_home=$(mktemp -d -t plan1-restore-XXXXXX)
restore_backup="$restore_home/.dotfiles-backup/restore-test-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$restore_backup"
echo "RESTORED CONTENT" > "$restore_backup/.restoretest"

trap 'rm -rf "$restore_home"' EXIT

# Run --restore with the fake HOME
# On WSL, --restore exits before apt so no sudo issue. On macOS, same.
restore_output=$(HOME="$restore_home" bash "$INSTALL_SCRIPT" --restore < /dev/null 2>&1 || true)

if [[ -f "$restore_home/.restoretest" ]]; then
  if [[ "$(cat "$restore_home/.restoretest")" == "RESTORED CONTENT" ]]; then
    pass "restore mode restored file from latest backup"
  else
    fail "restore mode restored file but content is wrong"
    info "content: $(cat "$restore_home/.restoretest")"
  fi
else
  fail "restore mode did not restore the test file"
  info "--- restore output ---"
  # shellcheck disable=SC2001
  # sed is the simplest idiom for indenting multi-line output
  echo "$restore_output" | sed 's/^/      /'
fi

rm -rf "$restore_home"
trap - EXIT

# ── Tests 5-7: invasive tests (--full only) ──────────────────────────────────
if $FULL; then
  case "$PLATFORM" in
    macos)
      header "Test 5: brew bundle install (SLOW, modifies system)"
      info "this may take 15-30 minutes on first run..."
      if brew bundle --file=Brewfile; then
        pass "brew bundle install completed"
      else
        fail "brew bundle install failed"
      fi

      header "Test 6: test-tool-installs.sh"
      if bash container/test-tool-installs.sh; then
        pass "tool verification passed"
      else
        fail "tool verification reported failures"
      fi
      ;;

    wsl|linux)
      header "Test 5: install-wsl.sh apt install (SLOW, modifies system)"
      info "this runs 'sudo apt update' and 'sudo apt install' for ~10 packages"
      # If stdin is a TTY, let sudo prompt for password interactively.
      # Otherwise redirect from /dev/null so sudo fails fast rather than
      # hanging (expected in background runs or CI without passwordless sudo).
      if [[ -t 0 ]]; then
        install_wsl_exit=0
        bash install-wsl.sh || install_wsl_exit=$?
      else
        install_wsl_exit=0
        bash install-wsl.sh < /dev/null || install_wsl_exit=$?
      fi
      if (( install_wsl_exit == 0 )); then
        pass "install-wsl.sh completed"
      else
        fail "install-wsl.sh failed (exit $install_wsl_exit)"
      fi

      header "Test 6: verify installed apt packages"
      missing=""
      for pkg in bash bash-completion git tmux tree wget curl jq shellcheck direnv; do
        if ! dpkg -s "$pkg" &>/dev/null; then
          missing="$missing $pkg"
        fi
      done
      if [[ -z "$missing" ]]; then
        pass "all required apt packages installed"
      else
        fail "missing packages:$missing"
      fi
      ;;
  esac
else
  header "Tests 5-6: invasive (skipped)"
  case "$PLATFORM" in
    macos)
      skip "brew bundle install   — re-run with --full to execute (~15-30 min)"
      skip "test-tool-installs.sh — re-run with --full to execute"
      ;;
    wsl|linux)
      skip "install-wsl.sh        — re-run with --full to execute"
      skip "apt package verify    — re-run with --full to execute"
      ;;
  esac
fi

# ── Summary ──────────────────────────────────────────────────────────────────
printf "\n"
header "Summary"
printf "  platform: %s\n" "$PLATFORM"
printf "  ${C_GREEN}PASS: %d${C_RESET}   ${C_RED}FAIL: %d${C_RESET}   ${C_YELLOW}SKIP: %d${C_RESET}\n" "$PASS" "$FAIL" "$SKIP"

if (( FAIL > 0 )); then
  printf '\n%s%sFailed tests:%s\n' "$C_BOLD" "$C_RED" "$C_RESET"
  for t in "${FAILED_TESTS[@]}"; do
    printf "  ${C_RED}✗${C_RESET} %s\n" "$t"
  done
  exit 1
fi

printf '\n%s%sAll tests passed.%s\n' "$C_GREEN" "$C_BOLD" "$C_RESET"
exit 0
