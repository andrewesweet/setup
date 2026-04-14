#!/usr/bin/env sh
# shellcheck shell=sh
# sketchybar/colors.sh — Dracula Pro palette, single source of truth.
#
# Sourced by sketchybarrc, every sketchybar/plugins/*.sh, and
# jankyborders/bordersrc. Hex values match the parent shell design's
# §3.9 (docs/plans/2026-04-12-shell-modernisation-design.md).
#
# Format: 0xff<RRGGBB>  — SketchyBar/JankyBorders AARRGGBB notation
# with ff = fully opaque alpha.

export COLOR_BG=0xff282A36            # Background
export COLOR_CURRENT_LINE=0xff44475A  # Current Line (also inactive border)
export COLOR_SELECTION=0xff44475A     # Selection (same hex as Current Line)
export COLOR_FG=0xffF8F8F2            # Foreground
export COLOR_COMMENT=0xff6272A4       # Comment / muted

export COLOR_RED=0xffFF5555           # Red    — Zscaler disconnect / errors
export COLOR_ORANGE=0xffFFB86C        # Orange — warnings
export COLOR_YELLOW=0xffF1FA8C        # Yellow — battery low
export COLOR_GREEN=0xff50FA7B         # Green  — Zscaler connected / ok
export COLOR_CYAN=0xff8BE9FD          # Cyan   — wifi connected
export COLOR_PURPLE=0xffBD93F9        # Purple — active focus / accent
export COLOR_PINK=0xffFF79C6          # Pink   — unused (kept for completeness)
