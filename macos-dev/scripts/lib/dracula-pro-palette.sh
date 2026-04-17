# shellcheck shell=bash
# scripts/lib/dracula-pro-palette.sh
#
# Dracula PRO Base / Terminal Standard — single source of truth.
# Values copied verbatim from ~/dracula-pro/design/palette.md,
# section "Color Palette - Terminal Standard / Dracula PRO - Base".
# Facts (hex triples) — not the licensed theme files.

# ANSI 0-7
export DRACULA_PRO_BLACK="#22212C"         # ANSI 0 (= Background)
export DRACULA_PRO_RED="#FF9580"           # ANSI 1
export DRACULA_PRO_GREEN="#8AFF80"         # ANSI 2
export DRACULA_PRO_YELLOW="#FFFF80"        # ANSI 3
export DRACULA_PRO_BLUE="#9580FF"          # ANSI 4  (Base alias: Purple)
export DRACULA_PRO_MAGENTA="#FF80BF"       # ANSI 5  (Base alias: Pink)
export DRACULA_PRO_CYAN="#80FFEA"          # ANSI 6
export DRACULA_PRO_WHITE="#F8F8F2"         # ANSI 7 (= Foreground)

# ANSI 8-15 (Bright)
export DRACULA_PRO_BRIGHT_BLACK="#504C67"  # ANSI 8
export DRACULA_PRO_BRIGHT_RED="#FFAA99"
export DRACULA_PRO_BRIGHT_GREEN="#A2FF99"
export DRACULA_PRO_BRIGHT_YELLOW="#FFFF99"
export DRACULA_PRO_BRIGHT_BLUE="#AA99FF"
export DRACULA_PRO_BRIGHT_MAGENTA="#FF99CC"
export DRACULA_PRO_BRIGHT_CYAN="#99FFEE"
export DRACULA_PRO_BRIGHT_WHITE="#FFFFFF"

# Dim (muted / inactive states)
export DRACULA_PRO_DIM_BLACK="#1B1A23"
export DRACULA_PRO_DIM_RED="#CC7766"
export DRACULA_PRO_DIM_GREEN="#6ECC66"
export DRACULA_PRO_DIM_YELLOW="#CCCC66"
export DRACULA_PRO_DIM_BLUE="#7766CC"
export DRACULA_PRO_DIM_MAGENTA="#CC6699"
export DRACULA_PRO_DIM_CYAN="#66CCBB"
export DRACULA_PRO_DIM_WHITE="#C6C6C2"

# Structural
export DRACULA_PRO_BACKGROUND="#22212C"
export DRACULA_PRO_FOREGROUND="#F8F8F2"
export DRACULA_PRO_COMMENT="#7970A9"
export DRACULA_PRO_SELECTION="#454158"
export DRACULA_PRO_CURSOR="#7970A9"

# Extra semantic accent (Base palette)
export DRACULA_PRO_ORANGE="#FFCA80"

# Non-terminal aliases (used where a tool's theme vocabulary is non-terminal)
export DRACULA_PRO_PURPLE="$DRACULA_PRO_BLUE"     # #9580FF
export DRACULA_PRO_PINK="$DRACULA_PRO_MAGENTA"    # #FF80BF
