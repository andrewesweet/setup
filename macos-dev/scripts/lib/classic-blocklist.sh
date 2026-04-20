# shellcheck shell=bash
# scripts/lib/classic-blocklist.sh
#
# Dracula Classic hex blocklist. See docs/design/theming-qa.md § 4.2.
#
# These 16 hex values are the full set of distinct Classic named-slot
# colours (including the eight Ansi bright variants per
# spec.draculatheme.com) minus the Foreground (#F8F8F2), which is shared
# between Classic and Dracula Pro Base and therefore MUST NOT be blocked.
#
# Values are stored lowercase for case-insensitive matching via grep -i.
# Sourced file, not executable.

set -uo pipefail

CLASSIC_HEX_BLOCKLIST=(
  "#282a36"  # Background
  "#6272a4"  # Current Line / Comment
  "#44475a"  # Selection
  "#ff5555"  # Red
  "#ffb86c"  # Orange
  "#f1fa8c"  # Yellow
  "#50fa7b"  # Green
  "#8be9fd"  # Cyan
  "#bd93f9"  # Purple
  "#ff79c6"  # Pink
  "#ff6e6e"  # Bright Red
  "#69ff94"  # Bright Green
  "#ffffa5"  # Bright Yellow
  "#d6acff"  # Bright Blue
  "#ff92df"  # Bright Magenta
  "#a4ffff"  # Bright Cyan
)
export CLASSIC_HEX_BLOCKLIST

# Pre-built alternation regex for grep -iE. Assembled here so each call
# site doesn't duplicate the join logic.
__classic_hex_join() {
  local IFS='|'
  printf '(%s)' "${CLASSIC_HEX_BLOCKLIST[*]}"
}
CLASSIC_HEX_REGEX="$(__classic_hex_join)"
export CLASSIC_HEX_REGEX
unset -f __classic_hex_join
