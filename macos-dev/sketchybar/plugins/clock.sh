#!/usr/bin/env sh
# shellcheck shell=sh
# clock.sh — date + time, 30-second poll.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"

sketchybar --set "$NAME" \
  label="$(date '+%a %d %b  %H:%M')" \
  label.color="$COLOR_FG"
