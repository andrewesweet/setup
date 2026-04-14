#!/usr/bin/env sh
# shellcheck shell=sh
# zscaler.sh — SketchyBar liveness indicator for the Zscaler daemon.
#
# Primary check is `pgrep -qx ZscalerTunnel` (exact match). Fallback is
# a case-insensitive substring match because the binary name has shifted
# between 3.x and 4.x (design §A.2.1). Never shells out to Zscaler IPC.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"

if pgrep -qx ZscalerTunnel || pgrep -q -fi 'zscaler'; then
  sketchybar --set "$NAME" \
    icon.color="$COLOR_GREEN" \
    drawing=on \
    label=""
else
  sketchybar --set "$NAME" \
    icon.color="$COLOR_RED" \
    drawing=on \
    label=""
fi
