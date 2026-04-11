#!/usr/bin/env bash
# test-dev-shell.sh — verify dev container runtime environment
#
# Runs the full set of "dev shell" health checks non-interactively by
# piping a verification script into `dev.sh shell`. The container's
# bash -l reads from stdin, runs the checks, and exits on EOF.
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
# Single-quoted heredoc: no host-side expansion.
read -r -d '' INSIDE <<'INSIDE_EOF' || true
set +e  # keep going on individual check failures

echo "=== user/id ==="
id

echo
echo "=== cwd ==="
pwd

echo
echo "=== opencode auth mount ==="
if [ -d /home/dev/.opencode-auth ]; then
  ls -la /home/dev/.opencode-auth/
  if [ -r /home/dev/.opencode-auth/auth.json ]; then
    echo "auth.json readable (size: $(stat -c %s /home/dev/.opencode-auth/auth.json) bytes)"
  else
    echo "auth.json NOT readable"
  fi
else
  echo "(mount missing — host ~/.local/share/opencode/auth.json may not exist)"
fi

echo
echo "=== ssh agent forwarding ==="
echo "SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-unset}"
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
  ssh-add -l 2>&1 || echo "(ssh-add exit $?)"
else
  echo "socket missing or not a socket"
fi

echo
echo "=== workspace mount write test ==="
if touch /home/dev/workspace/.dev-shell-test 2>err.log; then
  rm /home/dev/workspace/.dev-shell-test
  echo "workspace WRITABLE"
else
  echo "workspace NOT writable:"
  cat err.log
fi
rm -f err.log

echo
echo "=== capability drops (expect mostly zeros) ==="
grep -E '^Cap(Bnd|Eff|Prm|Inh|Amb)' /proc/1/status

echo
echo "=== read-only rootfs test ==="
if touch /rootfs-write-test 2>/dev/null; then
  rm /rootfs-write-test
  echo "rootfs IS writable — --read-only flag not applied"
else
  echo "rootfs read-only (expected)"
fi

echo
echo "=== proxy env ==="
env | grep -iE '^(http_|https_|no_)proxy' | sort || echo "(none)"

echo
echo "=== git identity ==="
git config --get user.name  || echo "(unset)"
git config --get user.email || echo "(unset)"

echo
echo "=== key tool availability ==="
missing=0
for t in bash git curl ssh \
         mise uv python3 go node bun \
         opencode critique ruff ty prek \
         shellcheck shfmt golangci-lint gofumpt actionlint tflint zizmor \
         fd rg tree jq yq kubectl gcloud \
         tmux starship lazygit btop fzf zoxide bat delta glow nvim k9s lazydocker; do
  if command -v "$t" >/dev/null 2>&1; then
    printf "  ok   %-18s %s\n" "$t" "$(command -v "$t")"
  else
    printf "  MISS %s\n" "$t"
    missing=$((missing+1))
  fi
done
echo
if [ "$missing" -eq 0 ]; then
  echo "all tools present"
else
  echo "$missing tool(s) missing"
fi

echo
echo "=== versions (key tools) ==="
bash --version      | head -1
git --version
mise --version      2>&1 | head -1
uv --version        2>&1
python3 --version   2>&1
go version          2>&1
node --version      2>&1
bun --version       2>&1
opencode --version  2>&1 | head -1 || true
ruff --version      2>&1
shellcheck --version | grep version || true
actionlint -version 2>&1 | head -1
kubectl version --client --output=yaml 2>&1 | head -4
nvim --version      2>&1 | head -1

echo
echo "=== mise runtimes ==="
mise ls 2>&1 | head -20

echo
echo "=== done ==="
exit
INSIDE_EOF

echo "==> Running dev shell checks — output to $LOG_FILE" >&2
echo "==> (container will stay running afterwards; run 'dev stop' to clean up)" >&2
echo "" >"$LOG_FILE"

# Pipe the verification commands into dev.sh shell.
# dev.sh runs `podman run -dit ...` to create the container, then
# `exec podman exec -it ... bash -l`. bash -l reads the piped stdin,
# runs every command, and exits on EOF.
#
# stdin NOT a tty → podman warns "input device is not a TTY" but
# still works fine; warning goes to stderr and into the log.
printf '%s\n' "$INSIDE" | bash "$SCRIPT_DIR/dev.sh" shell 2>&1 | tee -a "$LOG_FILE"

echo "" >&2
echo "==> Done. Full log: $LOG_FILE" >&2
