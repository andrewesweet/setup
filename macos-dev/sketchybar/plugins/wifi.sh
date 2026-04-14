#!/usr/bin/env sh
# shellcheck shell=sh
# wifi.sh — renders SSID or disconnect glyph.
#
# Uses `networksetup -getairportnetwork en0` which is stable across
# modern macOS. Device name en0 is the standard Wi-Fi interface on
# Apple Silicon laptops; falls back to en1 on Intel.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"
# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/icons.sh"

iface="$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi/{getline; print $2}' | head -1)"
iface="${iface:-en0}"

ssid="$(networksetup -getairportnetwork "$iface" 2>/dev/null | sed 's/^Current Wi-Fi Network: //')"

if [ -n "$ssid" ] && [ "$ssid" != "You are not associated with an AirPort network." ]; then
  sketchybar --set "$NAME" \
    icon="$ICON_WIFI" \
    icon.color="$COLOR_CYAN" \
    label="$ssid"
else
  sketchybar --set "$NAME" \
    icon="$ICON_WIFI_OFF" \
    icon.color="$COLOR_COMMENT" \
    label=""
fi
