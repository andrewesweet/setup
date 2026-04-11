#!/bin/bash
# container/podman-machine-start.sh
# Wrapper for LaunchAgent — safe on first run, idempotent, no-loop on failure modes
set -e

# Platform guard (plist is only installed on macOS, but defence in depth)
[[ "$(uname)" == "Darwin" ]] || exit 0

# If podman isn't on PATH, exit cleanly rather than letting launchd loop
PODMAN="@HOMEBREW_PREFIX@/bin/podman"
[[ -x "$PODMAN" ]] || exit 0

# If no machines exist, exit cleanly
"$PODMAN" machine list -q 2>/dev/null | grep -q . || exit 0

# Check if default machine is already running
state=$("$PODMAN" machine info --format '{{.Host.MachineState}}' 2>/dev/null || echo unknown)
case "$state" in
  Running|running) exit 0 ;;
  *) exec "$PODMAN" machine start ;;
esac
