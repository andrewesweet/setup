#!/usr/bin/env sh
# shellcheck shell=sh
# focused_app.sh — renders the front application's name in the bar.
#
# Invoked by SketchyBar on front_app_switched. SketchyBar provides
# INFO env var containing the app name.

sketchybar --set "$NAME" label="$INFO"
