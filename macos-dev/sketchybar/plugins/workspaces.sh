#!/usr/bin/env sh
# shellcheck shell=sh
# workspaces.sh — repaints workspace pill on aerospace_workspace_change.
#
# Invoked by SketchyBar in two modes:
#   - update_freq=5 fallback poll
#   - aerospace_workspace_change trigger (sets FOCUSED_WORKSPACE env var)
#
# NAME is "workspace.<N>" and the literal workspace number is the last
# segment. Active pill shows Dracula Purple background; inactive shows
# Dracula Current-Line.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"

ws="${NAME##*.}"
focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"

if [ "$ws" = "$focused" ]; then
  sketchybar --set "$NAME" \
    background.color="$COLOR_PURPLE" \
    background.corner_radius=6 \
    background.height=22 \
    background.drawing=on \
    label.color="$COLOR_BG"
else
  sketchybar --set "$NAME" \
    background.color="$COLOR_CURRENT_LINE" \
    background.corner_radius=6 \
    background.height=22 \
    background.drawing=on \
    label.color="$COLOR_FG"
fi
