#!/usr/bin/env sh
# shellcheck shell=sh
# sketchybar/colors.sh — Dracula Pro palette alias layer.
#
# Sourced by sketchybarrc, every sketchybar/plugins/*.sh, and
# jankyborders/bordersrc. Hex values are DERIVED from
# $DOTFILES/scripts/lib/dracula-pro-palette.sh — the single source of
# truth per `docs/design/theming.md` § 6.3. Do NOT hardcode hex here.
#
# Format on export: 0xff<RRGGBB> — SketchyBar/JankyBorders AARRGGBB
# notation with ff = fully opaque alpha. The helper `_sb_color` strips
# the leading '#' from the palette variable and prefixes 0xff.

# Resolve $DOTFILES at source time. Installers set $DOTFILES; when this
# file is sourced standalone (e.g. bordersrc at login), fall back to
# the canonical install location.
: "${DOTFILES:=$HOME/andrewesweet/setup/macos-dev}"
# shellcheck source=../scripts/lib/dracula-pro-palette.sh disable=SC1091
. "$DOTFILES/scripts/lib/dracula-pro-palette.sh"

_sb_color() {
  # $1 = #RRGGBB hex → 0xffRRGGBB
  printf '0xff%s' "$(printf '%s' "$1" | sed -E 's/^#//')"
}

# Structural slots
COLOR_BG="$(_sb_color "$DRACULA_PRO_BACKGROUND")"           # #22212C
export COLOR_BG
COLOR_FG="$(_sb_color "$DRACULA_PRO_FOREGROUND")"           # #F8F8F2
export COLOR_FG
COLOR_COMMENT="$(_sb_color "$DRACULA_PRO_COMMENT")"         # #7970A9
export COLOR_COMMENT
COLOR_SELECTION="$(_sb_color "$DRACULA_PRO_SELECTION")"     # #454158
export COLOR_SELECTION
# Legacy alias — pre-Pro code referred to "Current Line"; map to Selection.
export COLOR_CURRENT_LINE="$COLOR_SELECTION"

# Accents (Terminal Standard names + Pro non-terminal aliases)
COLOR_RED="$(_sb_color "$DRACULA_PRO_RED")"                 # #FF9580
export COLOR_RED
COLOR_GREEN="$(_sb_color "$DRACULA_PRO_GREEN")"             # #8AFF80
export COLOR_GREEN
COLOR_YELLOW="$(_sb_color "$DRACULA_PRO_YELLOW")"           # #FFFF80
export COLOR_YELLOW
COLOR_CYAN="$(_sb_color "$DRACULA_PRO_CYAN")"               # #80FFEA
export COLOR_CYAN
COLOR_ORANGE="$(_sb_color "$DRACULA_PRO_ORANGE")"           # #FFCA80
export COLOR_ORANGE
# Non-terminal aliases — preserve existing sketchybarrc / plugin refs.
COLOR_PURPLE="$(_sb_color "$DRACULA_PRO_BLUE")"             # #9580FF
export COLOR_PURPLE
COLOR_PINK="$(_sb_color "$DRACULA_PRO_MAGENTA")"            # #FF80BF
export COLOR_PINK
