#!/usr/bin/env bash
# test-dev-shell.sh — verify dev container runtime environment
#
# Runs health checks against the dev container non-interactively. Uses
# `podman exec -i` (NOT -it) so the container's bash runs as a
# non-interactive shell reading stdin as a script — no prompt echo,
# no starship rendering, clean PASS/FAIL output.
#
# Usage:
#   bash container/test-dev-shell.sh [log-file]
#
# Default log file: /tmp/dev-shell-test.log
#
# If the container doesn't exist yet this script will bootstrap it by
# calling `dev.sh shell </dev/null` (stdin closed → interactive attach
# exits immediately → detached container survives).
#
# Leaves the container running afterwards — safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${1:-/tmp/dev-shell-test.log}"

# Container name must match dev.sh's _container_name (dev-<repo-basename>).
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
container_name="dev-$(basename "$repo_root")"

# ── Ensure container exists and is running ────────────────────────────────
if ! podman container exists "$container_name" 2>/dev/null; then
  echo "==> Container '$container_name' not found — bootstrapping via dev.sh shell..." >&2
  bash "$SCRIPT_DIR/dev.sh" shell </dev/null >/dev/null 2>&1 || true
fi

state=$(podman inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null || echo missing)
case "$state" in
  running) : ;;
  exited|stopped|created)
    echo "==> Starting container '$container_name'..." >&2
    podman start "$container_name" >/dev/null
    ;;
  missing)
    echo "==> Failed to create container '$container_name'. Run 'bash container/dev.sh shell' directly to diagnose." >&2
    exit 1
    ;;
esac

# ── Verification script (runs INSIDE the container) ───────────────────────
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
    return 0  # expected on macOS launchd (forwarding was skipped)
  fi
  [ -S "$SSH_AUTH_SOCK" ] || { echo "socket missing at $SSH_AUTH_SOCK"; return 1; }
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
  # dev.sh: --cap-drop=ALL --cap-add=CHOWN,DAC_OVERRIDE,FOWNER
  #   CHOWN=bit 0, DAC_OVERRIDE=bit 1, FOWNER=bit 3
  #   bounding set bits = 1<<0 | 1<<1 | 1<<3 = 0xb
  # Check CapBnd (what the container is allowed to use), not CapEff
  # (which is always 0 for a non-root process regardless).
  local cap_bnd
  cap_bnd=$(awk '/^CapBnd:/ {print $2}' /proc/1/status)
  if [ "$cap_bnd" = "000000000000000b" ]; then
    return 0
  fi
  echo "CapBnd=$cap_bnd (expected 000000000000000b = CHOWN+DAC_OVERRIDE+FOWNER)"
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

# ── Run the checks ────────────────────────────────────────────────────────
echo "==> Running dev shell checks against $container_name" >&2
: >"$LOG_FILE"

# podman exec -i (NO -t) — pipe stdin is not a tty, so bash runs
# non-interactively: no prompt echo, no starship rendering, clean
# script execution.
set +eu
printf '%s\n' "$INSIDE" | podman exec -i "$container_name" bash -l 2>&1 \
  | tee "$LOG_FILE" \
  | grep -E '^(FAIL|SUMMARY|FAILED|Error)'
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
