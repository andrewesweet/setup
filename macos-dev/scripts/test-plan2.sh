#!/usr/bin/env bash
# test-plan2.sh — smoke tests for Plan 2 (bash configuration)
#
# Validates:
#   - All four bash config files exist
#   - .bashrc has all 13 numbered sections in correct order
#   - .bash_aliases has no POSIX shadows
#   - .bash_aliases has required prefix aliases and functions
#   - .inputrc has vi mode and all 7 readline settings
#   - Install scripts have correct link() mappings for bash files
#   - All bash files pass syntax check (bash -n)
#   - Security: HISTIGNORE, FZF excludes, gha-* are functions
#   - Cross-platform: brew prefix detection, bash 4+ guard, _OS fallback
#
# What bash -n does NOT check: unbound variables, missing commands,
# wrong argument counts, logic errors. This test suite adds structural
# and content checks to compensate. Behavioral validation requires a
# live shell with tools installed (done manually on macOS hardware).
#
# Usage: bash scripts/test-plan2.sh
# Exit: 0 if all tests pass, 1 if any fail

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass=0
fail=0

ok() {
  printf "  \033[0;32m✓\033[0m %s\n" "$1"
  pass=$((pass + 1))
}

nok() {
  printf "  \033[0;31m✗\033[0m %s\n" "$1"
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

echo "Plan 2: bash configuration smoke tests"
echo ""

# ── File existence ─────────────────────────────────────────────────────────
echo "File existence:"
check ".bash_profile exists"  test -f "$REPO_ROOT/bash/.bash_profile"
check ".bashrc exists"        test -f "$REPO_ROOT/bash/.bashrc"
check ".bash_aliases exists"  test -f "$REPO_ROOT/bash/.bash_aliases"
check ".inputrc exists"       test -f "$REPO_ROOT/bash/.inputrc"

# ── Syntax checks ─────────────────────────────────────────────────────────
echo ""
echo "Syntax checks:"
check ".bash_profile syntax"  bash -n "$REPO_ROOT/bash/.bash_profile"
check ".bashrc syntax"        bash -n "$REPO_ROOT/bash/.bashrc"
# .bash_aliases needs _OS defined (set by .bashrc which sources it)
# shellcheck disable=SC2016
check ".bash_aliases syntax (macos)" bash -n <(echo '_OS=macos'; cat "$REPO_ROOT/bash/.bash_aliases")
# shellcheck disable=SC2016
check ".bash_aliases syntax (linux)" bash -n <(echo '_OS=linux'; cat "$REPO_ROOT/bash/.bash_aliases")
# shellcheck disable=SC2016
check ".bash_aliases syntax (wsl)"   bash -n <(echo '_OS=wsl'; cat "$REPO_ROOT/bash/.bash_aliases")

# ── .bashrc structure ──────────────────────────────────────────────────────
echo ""
echo ".bashrc structure:"

section_count=$(grep -c '^# ── [0-9]' "$REPO_ROOT/bash/.bashrc")
if [[ "$section_count" -eq 13 ]]; then
  ok ".bashrc has 13 numbered sections"
else
  nok ".bashrc has $section_count sections, expected 13"
fi

# Section ordering: extract the leading number from each section header.
# Uses sed (not grep -oE) to avoid picking up extra digits like "9" from "OSC 9".
section_order=$(grep '^# ── [0-9]' "$REPO_ROOT/bash/.bashrc" | sed 's/^# ── \([0-9]*\).*/\1/' | tr '\n' ' ')
expected_order="1 2 3 4 5 6 7 8 9 10 11 12 13 "
if [[ "$section_order" == "$expected_order" ]]; then
  ok ".bashrc sections in correct order (1-13)"
else
  nok ".bashrc section order: got '$section_order', expected '$expected_order'"
fi

check ".bashrc has interactive guard"     grep -qF '[[ $- != *i* ]] && return' "$REPO_ROOT/bash/.bashrc"
check ".bashrc has platform detection"    grep -q 'case.*OSTYPE' "$REPO_ROOT/bash/.bashrc"
check ".bashrc has _OS fallback"          grep -q '_OS=unknown' "$REPO_ROOT/bash/.bashrc"
check ".bashrc has DOTFILES default"      grep -q 'DOTFILES=.*HOME/.dotfiles' "$REPO_ROOT/bash/.bashrc"
# Self-resolution: .bashrc walks its own symlink chain to discover
# the repo location, so the user can clone anywhere (not only ~/.dotfiles).
check ".bashrc self-resolves DOTFILES"    grep -q 'BASH_SOURCE\[0\]' "$REPO_ROOT/bash/.bashrc"
check ".bashrc walks symlink chain"       grep -q 'while \[\[ -L "$_src" \]\]' "$REPO_ROOT/bash/.bashrc"
check ".bashrc has expanded HISTIGNORE"   grep -q 'HISTIGNORE.*GH_TOKEN.*GITHUB_PAT.*BEARER.*ANTHROPIC.*OPENAI' "$REPO_ROOT/bash/.bashrc"
check ".bashrc sources .bash_aliases"     grep -q 'source.*\.bash_aliases' "$REPO_ROOT/bash/.bashrc"
check ".bashrc sources .bashrc.local"     grep -q 'source.*\.bashrc\.local' "$REPO_ROOT/bash/.bashrc"
check ".bashrc has starship eval"         grep -q 'starship init bash' "$REPO_ROOT/bash/.bashrc"
check ".bashrc has vi mode"               grep -q 'set -o vi' "$REPO_ROOT/bash/.bashrc"

# Starship must be the last eval in section 8 (not section 9)
last_eval_in_s8=$(sed -n '/^# ── 8\./,/^# ── 9\./p' "$REPO_ROOT/bash/.bashrc" \
  | grep 'eval.*init\|eval.*activate\|eval.*hook\|eval.*completion.*-s' | tail -1)
if echo "$last_eval_in_s8" | grep -q 'starship init bash'; then
  ok "starship is last eval in section 8"
else
  nok "starship is NOT last eval in section 8 (got: $last_eval_in_s8)"
fi

# ── .bashrc cross-platform and security checks ────────────────────────────
echo ""
echo ".bashrc cross-platform and security:"
check "brew prefix detection without fork"  grep -q '/opt/homebrew/bin/brew' "$REPO_ROOT/bash/.bashrc"
check "bash 4+ shopt guard"                 grep -q 'BASH_VERSINFO\[0\] >= 4' "$REPO_ROOT/bash/.bashrc"
check "OSC 9 terminal guard"                grep -q 'TERM_PROGRAM' "$REPO_ROOT/bash/.bashrc"
check "OSC 9 NOTIFY_OSC9 override"          grep -q 'NOTIFY_OSC9' "$REPO_ROOT/bash/.bashrc"
check "OSC 9 NOTIFY_THRESHOLD default"      grep -q 'NOTIFY_THRESHOLD.*:-10' "$REPO_ROOT/bash/.bashrc"
# shellcheck disable=SC2016
check "OSC 9 duplication guard"             grep -qF '[[ "$PROMPT_COMMAND" != *"__cmd_timer_notify"' "$REPO_ROOT/bash/.bashrc"
check "OSC 9 _osc9_supported cleanup"       grep -q 'unset _osc9_supported' "$REPO_ROOT/bash/.bashrc"
check "OSC 9 DEBUG trap"                    grep -q "trap '__cmd_timer_start' DEBUG" "$REPO_ROOT/bash/.bashrc"
check "FZF excludes .aws"                   grep -q 'FZF_DEFAULT_COMMAND.*exclude .aws' "$REPO_ROOT/bash/.bashrc"
check "FZF excludes .ssh"                   grep -q 'FZF_DEFAULT_COMMAND.*exclude .ssh' "$REPO_ROOT/bash/.bashrc"
check "PATH security comment"               grep -q 'MUST NOT contain untrusted binaries' "$REPO_ROOT/bash/.bashrc"
check ".bashrc.local examples in comment"   grep -q '# .bashrc.local is gitignored' "$REPO_ROOT/bash/.bashrc"
check "gcloud WSL2 home path"               grep -q 'HOME/google-cloud-sdk/completion' "$REPO_ROOT/bash/.bashrc"

# ── .bashrc env vars ───────────────────────────────────────────────────────
echo ""
echo ".bashrc environment variables:"
check "BAT_THEME set"          grep -q 'BAT_THEME=' "$REPO_ROOT/bash/.bashrc"
check "FZF_DEFAULT_COMMAND set" grep -q 'FZF_DEFAULT_COMMAND=' "$REPO_ROOT/bash/.bashrc"
check "FZF_CTRL_T_COMMAND set" grep -q 'FZF_CTRL_T_COMMAND=' "$REPO_ROOT/bash/.bashrc"
check "FZF_ALT_C_COMMAND set"  grep -q 'FZF_ALT_C_COMMAND=' "$REPO_ROOT/bash/.bashrc"
check "FZF_DEFAULT_OPTS set"   grep -q 'FZF_DEFAULT_OPTS=' "$REPO_ROOT/bash/.bashrc"

# ── .bash_aliases constraints ──────────────────────────────────────────────
echo ""
echo ".bash_aliases constraints:"

# No POSIX shadows
if grep -qE "^alias (grep|find|cat|ps)=" "$REPO_ROOT/bash/.bash_aliases"; then
  nok "no POSIX command shadows (found grep/find/cat/ps alias)"
else
  ok "no POSIX command shadows"
fi

# Prefix checks
check "git: gc=git commit"        grep -q "^alias gc='git commit'" "$REPO_ROOT/bash/.bash_aliases"
check "git: lg=lazygit"           grep -q "^alias lg='lazygit'" "$REPO_ROOT/bash/.bash_aliases"
check "git: gam=amend"            grep -q "^alias gam='git commit --amend'" "$REPO_ROOT/bash/.bash_aliases"
check "search: fdd"               grep -q "^alias fdd=" "$REPO_ROOT/bash/.bash_aliases"
check "tmux: ta"                  grep -q "^alias ta=" "$REPO_ROOT/bash/.bash_aliases"
check "mise: mx"                  grep -q "^alias mx=" "$REPO_ROOT/bash/.bash_aliases"
check "uv: uva"                   grep -q "^alias uva=" "$REPO_ROOT/bash/.bash_aliases"
check "prek: pk=prek run"         grep -q "^alias pk='prek run'" "$REPO_ROOT/bash/.bash_aliases"
check "gcloud: gx=gcloud"        grep -q "^alias gx='gcloud'" "$REPO_ROOT/bash/.bash_aliases"
check "gcloud: gxa=activate"     grep -q "^alias gxa='gcloud config configurations activate'" "$REPO_ROOT/bash/.bash_aliases"
check "codeql: cql"              grep -q "^alias cql='codeql'" "$REPO_ROOT/bash/.bash_aliases"
check "markdown: mdv=glow"       grep -q "^alias mdv='glow -s dark'" "$REPO_ROOT/bash/.bash_aliases"

# No collisions
if grep -qE "^alias fd=" "$REPO_ROOT/bash/.bash_aliases"; then
  nok "no fd= alias (would shadow fd command)"
else
  ok "no fd= alias (fdd used instead)"
fi

if grep -qE "^alias gl=" "$REPO_ROOT/bash/.bash_aliases"; then
  nok "no gl= alias (lg used for lazygit)"
else
  ok "no gl= alias (lg used for lazygit)"
fi

if grep -q "^alias md=" "$REPO_ROOT/bash/.bash_aliases"; then
  nok "no md= alias (mdv used instead)"
else
  ok "no md= alias (mdv used instead)"
fi

# gha-* must be functions, not aliases (security.md)
check "gha-pin() function exists"   grep -qE '^gha-pin[[:space:]]*\(\)' "$REPO_ROOT/bash/.bash_aliases"
check "gha-check() function exists" grep -qE '^gha-check[[:space:]]*\(\)' "$REPO_ROOT/bash/.bash_aliases"
check "gha-update() function exists" grep -qE '^gha-update[[:space:]]*\(\)' "$REPO_ROOT/bash/.bash_aliases"
check "gha-* functions check gh auth" grep -q 'gh auth status' "$REPO_ROOT/bash/.bash_aliases"

# Linux port differs from ports
linux_port_val=$(grep "alias port='ss" "$REPO_ROOT/bash/.bash_aliases" | head -1)
linux_ports_val=$(grep "alias ports='ss" "$REPO_ROOT/bash/.bash_aliases" | head -1)
if [[ -n "$linux_port_val" && -n "$linux_ports_val" && "$linux_port_val" != "$linux_ports_val" ]]; then
  ok "port and ports differ on Linux"
else
  nok "port and ports should have different values on Linux"
fi

# Functions exist (flexible pattern matching for function definitions)
check "cr() function exists"      grep -qE '^cr[[:space:]]*\(\)' "$REPO_ROOT/bash/.bash_aliases"
check "crw() function exists"     grep -qE '^crw[[:space:]]*\(\)' "$REPO_ROOT/bash/.bash_aliases"
check "crs() function exists"     grep -qE '^crs[[:space:]]*\(\)' "$REPO_ROOT/bash/.bash_aliases"
check "aliases() function exists" grep -qE '^aliases[[:space:]]*\(\)' "$REPO_ROOT/bash/.bash_aliases"
check "cheat() function exists"   grep -qE '^cheat[[:space:]]*\(\)' "$REPO_ROOT/bash/.bash_aliases"
check "cheat() validates DOTFILES" grep -q 'Cheatsheet not found' "$REPO_ROOT/bash/.bash_aliases"
# Per-tool discovery subcommands (option B from cheatsheet design discussion).
# Each delegates to the tool's own help — keeps cheatsheet.md scannable
# while still providing one-command discovery for installed tools.
check "cheat nvim subcommand"     grep -qE 'nvim\|vim\)' "$REPO_ROOT/bash/.bash_aliases"
check "cheat lazygit subcommand"  grep -qE 'lazygit\|lg\)' "$REPO_ROOT/bash/.bash_aliases"
check "cheat tmux subcommand"     grep -qE '^[[:space:]]*tmux\)' "$REPO_ROOT/bash/.bash_aliases"
check "cheat opencode subcommand" grep -qE 'opencode\|oc\)' "$REPO_ROOT/bash/.bash_aliases"
check "cheat help subcommand"     grep -qE '\-h\|--help\|help\)' "$REPO_ROOT/bash/.bash_aliases"
check "cheat unknown rejects"     grep -q "unknown subcommand" "$REPO_ROOT/bash/.bash_aliases"

# Platform-conditional
check "platform ports alias"      grep -q 'ports=.*lsof\|ports=.*ss' "$REPO_ROOT/bash/.bash_aliases"

# ── .inputrc ───────────────────────────────────────────────────────────────
echo ""
echo ".inputrc:"
check "vi editing mode"              grep -q 'editing-mode vi' "$REPO_ROOT/bash/.inputrc"
check "keyseq-timeout"               grep -q 'keyseq-timeout' "$REPO_ROOT/bash/.inputrc"
check "show-mode-in-prompt"          grep -q 'show-mode-in-prompt on' "$REPO_ROOT/bash/.inputrc"
check "completion-ignore-case"       grep -q 'completion-ignore-case on' "$REPO_ROOT/bash/.inputrc"
check "completion-map-case"          grep -q 'completion-map-case on' "$REPO_ROOT/bash/.inputrc"
check "show-all-if-ambiguous"        grep -q 'show-all-if-ambiguous on' "$REPO_ROOT/bash/.inputrc"
check "mark-symlinked-directories"   grep -q 'mark-symlinked-directories on' "$REPO_ROOT/bash/.inputrc"

# Individual settings are tested above; a count test would be a change-detector.

# ── Install script link() calls ───────────────────────────────────────────
echo ""
echo "Install scripts:"

macos_links=$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh" 2>/dev/null || echo 0)
if [[ "$macos_links" -eq 4 ]]; then
  ok "install-macos.sh has 4 bash link() calls"
else
  nok "install-macos.sh has $macos_links bash link() calls, expected 4"
fi

# Verify correct source→destination mappings
check "macos: .bash_profile mapping" grep -q 'link bash/.bash_profile .bash_profile' "$REPO_ROOT/install-macos.sh"
check "macos: .bashrc mapping"       grep -q 'link bash/.bashrc.*\.bashrc' "$REPO_ROOT/install-macos.sh"
check "macos: .bash_aliases mapping" grep -q 'link bash/.bash_aliases .bash_aliases' "$REPO_ROOT/install-macos.sh"
check "macos: .inputrc mapping"      grep -q 'link bash/.inputrc.*\.inputrc' "$REPO_ROOT/install-macos.sh"
check "macos: log line preserved"    grep -q 'log "symlinking configs"' "$REPO_ROOT/install-macos.sh"

wsl_links=$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh" 2>/dev/null || echo 0)
if [[ "$wsl_links" -eq 4 ]]; then
  ok "install-wsl.sh has 4 bash link() calls"
else
  nok "install-wsl.sh has $wsl_links bash link() calls, expected 4"
fi

check "wsl: .bash_profile mapping" grep -q 'link bash/.bash_profile .bash_profile' "$REPO_ROOT/install-wsl.sh"
check "wsl: .bashrc mapping"       grep -q 'link bash/.bashrc.*\.bashrc' "$REPO_ROOT/install-wsl.sh"
check "wsl: .bash_aliases mapping" grep -q 'link bash/.bash_aliases .bash_aliases' "$REPO_ROOT/install-wsl.sh"
check "wsl: .inputrc mapping"      grep -q 'link bash/.inputrc.*\.inputrc' "$REPO_ROOT/install-wsl.sh"
check "wsl: log line preserved"    grep -q 'log "symlinking configs"' "$REPO_ROOT/install-wsl.sh"

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Sanity check: if the test count drops significantly, a test was likely
# deleted by accident. Adjust this floor when adding new tests.
# Current count: ~83 tests. Floor should be within ~10% of actual.
if (( total < 75 )); then
  echo "WARNING: only $total tests ran (expected >= 75). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
