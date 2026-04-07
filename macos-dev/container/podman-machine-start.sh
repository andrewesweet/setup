#!/bin/bash
# container/podman-machine-start.sh
# Wrapper for LaunchAgent — safe on first run, idempotent, no-loop on failure modes
set -e

# Platform guard (plist is only installed on macOS, but defence in depth)
[[ "$(uname)" == "Darwin" ]] || exit 0

# If podman isn't on PATH, exit cleanly rather than letting launchd loop
PODMAN="@HOMEBREW_PREFIX@/bin/podman"
[[ -x "$PODMAN" ]] || exit 0

# If the dotfiles machine doesn't exist, exit cleanly (user hasn't run init-machine yet)
"$PODMAN" machine list -q 2>/dev/null | grep -qx 'dotfiles' || exit 0

# Check current state; only start if stopped/configured
state=$("$PODMAN" machine inspect dotfiles --format '{{.State}}' 2>/dev/null || echo missing)
case "$state" in
  running|starting) exit 0 ;;
  stopped|configured) exec "$PODMAN" machine start dotfiles ;;
  *) exit 0 ;;
esac
