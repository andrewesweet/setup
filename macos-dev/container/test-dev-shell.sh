#!/usr/bin/env bash
# test-dev-shell.sh — verify dev container runtime environment
#
# Runs all "dev shell" health checks non-interactively by piping a
# verification script into `dev.sh shell`. Produces one line per
# check: "PASS <name>" or "FAIL <name>: detail".
#
# Usage:
#   bash container/test-dev-shell.sh [log-file]
#
# Default log file: /tmp/dev-shell-test.log
#
# Leaves the container running afterwards — safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${1:-/tmp/dev-shell-test.log}"

# Verification commands — evaluated INSIDE the container.
# `run` is silent on PASS, prints one line on FAIL, counts both.
# Final output: SUMMARY + optional FAILED list. Happy path = 1 line.
read -r -d '' INSIDE <<'INSIDE_EOF' || true
set +e
pass=0
fail=0
fails=()

run() {
  local name="$1"; shift
  local out
  out=$("$@" 2>&1)
  local rc=$?
  if [ $rc -eq 0 ]; then
    pass=$((pass+1))
  else
    echo "FAIL $name: ${out:-exit $rc}"
    fail=$((fail+1))
    fails+=("$name")
  fi
}

check_opencode_auth() {
  [ -d /home/dev/.opencode-auth ] || { echo "mount missing"; return 1; }
  [ -r /home/dev/.opencode-auth/auth.json ] || { echo "auth.json not readable"; return 1; }
}

check_ssh_agent() {
  if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    echo "SKIP (SSH_AUTH_SOCK unset — expected on macOS launchd)"
    return 0
  fi
  [ -S "$SSH_AUTH_SOCK" ] || { echo "socket missing at $SSH_AUTH_SOCK"; return 1; }
  ssh-add -l >/dev/null 2>&1 || ssh-add -l 2>&1 | grep -q "no identities" || { echo "ssh-add failed"; return 1; }
}

check_workspace_write() {
  touch /home/dev/workspace/.dev-shell-test 2>&1 || return 1
  rm /home/dev/workspace/.dev-shell-test
}

check_rootfs_readonly() {
  if touch /rootfs-write-test 2>/dev/null; then
    rm /rootfs-write-test
    echo "rootfs is writable — --read-only not applied"
    return 1
  fi
}

check_cache_writable() {
  touch /home/dev/.cache/.test 2>&1 || return 1
  rm /home/dev/.cache/.test
}

check_caps_dropped() {
  local cap_eff
  cap_eff=$(awk '/^CapEff:/ {print $2}' /proc/1/status)
  # --cap-drop=ALL + --cap-add=CHOWN,DAC_OVERRIDE,FOWNER gives
  # 00000000000000000007 (bits 0,1,3). Anything beyond that is unexpected.
  if [ "$cap_eff" = "0000000000000007" ]; then
    return 0
  fi
  echo "CapEff=$cap_eff (expected 0000000000000007)"
  return 1
}

check_user() {
  local u g
  u=$(id -un)
  g=$(id -gn)
  [ "$u" = "dev" ] && [ "$g" = "dev" ] || { echo "id=$(id)"; return 1; }
}

check_tool() {
  command -v "$1" >/dev/null 2>&1 || { echo "not in PATH"; return 1; }
}

check_starship_prompt() {
  # Render the prompt once, succeed if no error bleeds through.
  starship prompt >/dev/null 2>&1 || return 1
}

run "user=dev"              check_user
run "rootfs read-only"      check_rootfs_readonly
run "caps dropped"          check_caps_dropped
run "workspace writable"    check_workspace_write
run ".cache writable"       check_cache_writable
run "opencode auth mount"   check_opencode_auth
run "ssh-agent"             check_ssh_agent
run "starship prompt"       check_starship_prompt

# Base tools (agent-usable CLIs)
for t in bash git curl ssh \
         mise uv python3 go node bun \
         opencode critique ruff ty prek \
         shellcheck shfmt golangci-lint gofumpt actionlint tflint zizmor \
         fd rg tree jq yq kubectl gcloud; do
  run "tool:$t" check_tool "$t"
done

# Full tools (human TUI layer)
for t in tmux starship lazygit btop fzf zoxide bat delta glow nvim k9s lazydocker; do
  run "tool:$t" check_tool "$t"
done

echo "---"
echo "SUMMARY: $pass passed, $fail failed"
if [ $fail -gt 0 ]; then
  echo "FAILED: ${fails[*]}"
fi
exit $fail
INSIDE_EOF

echo "==> Running dev shell checks — full log: $LOG_FILE" >&2
: >"$LOG_FILE"

# Pipe the verification commands into dev.sh shell.
# Keep only FAIL / SUMMARY / FAILED / WARN / Error lines on stdout;
# everything (including PASS counts) still goes to the log file.
#
# set +eu around the pipeline: `pipefail` from the top-level set would
# make grep's non-zero exit (no matches) kill the script, and set -u
# makes PIPESTATUS[N] dereference unsafe after `|| true`. Parsing the
# SUMMARY line from the log is simpler and more robust.
set +eu
printf '%s\n' "$INSIDE" | bash "$SCRIPT_DIR/dev.sh" shell 2>&1 \
  | tee "$LOG_FILE" \
  | grep -E '^(FAIL|SUMMARY|FAILED|WARN:|Error)'
set -eu

rc=99
summary=$(grep -E '^SUMMARY:' "$LOG_FILE" | tail -1 || true)
if [ -n "$summary" ] && [[ "$summary" =~ ([0-9]+)\ failed ]]; then
  rc="${BASH_REMATCH[1]}"
fi

echo "" >&2
if [ "$rc" = "0" ]; then
  echo "==> All checks passed. Log: $LOG_FILE" >&2
elif [ "$rc" = "99" ]; then
  echo "==> No SUMMARY line — container never finished. Full log: $LOG_FILE" >&2
else
  echo "==> $rc check(s) failed. Full log: $LOG_FILE" >&2
fi
exit "$rc"
