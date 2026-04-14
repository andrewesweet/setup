#!/usr/bin/env sh
# shellcheck shell=sh
# battery.sh — percent + charge indicator.
#
# Parses `pmset -g batt` — stable across macOS versions.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"
# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/icons.sh"

batt_out="$(pmset -g batt 2>/dev/null)"
pct="$(printf '%s' "$batt_out" | grep -oE '[0-9]+%' | head -1 | tr -d '%')"
pct="${pct:-0}"

if printf '%s' "$batt_out" | grep -qi 'charging\|ac power'; then
  icon="$ICON_BATTERY_CHARGING"
  color="$COLOR_GREEN"
elif [ "$pct" -le 20 ]; then
  icon="$ICON_BATTERY_LOW"
  color="$COLOR_YELLOW"
else
  icon="$ICON_BATTERY"
  color="$COLOR_FG"
fi

sketchybar --set "$NAME" \
  icon="$icon" \
  icon.color="$color" \
  label="${pct}%"
