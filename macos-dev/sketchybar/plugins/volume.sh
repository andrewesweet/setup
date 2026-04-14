#!/usr/bin/env sh
# shellcheck shell=sh
# volume.sh — renders current output volume, event-driven.
#
# SketchyBar provides INFO env var with the new volume level on
# volume_change events.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"
# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/icons.sh"

vol="${INFO:-$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)}"
vol="${vol:-0}"

if [ "$vol" -eq 0 ]; then
  icon="$ICON_VOLUME_MUTED"
else
  icon="$ICON_VOLUME"
fi

sketchybar --set "$NAME" \
  icon="$icon" \
  icon.color="$COLOR_FG" \
  label="${vol}%"
