#!/usr/bin/env sh
# shellcheck shell=sh
# focus_mode.sh — renders a Focus-Mode indicator when macOS DnD is on.
#
# Reads ~/Library/DoNotDisturb/DB/Assertions.json — an Apple-internal
# path that has been stable across Sonoma and Sequoia (design §7.6).
# Wraps the read in `jq -e` so a parse failure or missing file silently
# degrades to drawing=off rather than crashing the bar.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"

assertions="$HOME/Library/DoNotDisturb/DB/Assertions.json"

if [ -r "$assertions" ] && jq -e '.data[0].storeAssertionRecords | length > 0' "$assertions" >/dev/null 2>&1; then
  sketchybar --set "$NAME" \
    icon.color="$COLOR_PURPLE" \
    drawing=on
else
  # No active Focus Mode — or file unreadable/malformed. Hide the item.
  sketchybar --set "$NAME" drawing=off
fi
