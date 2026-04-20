#!/usr/bin/env bash
# scripts/lib/retint.sh
#
# Re-tint a Classic-derived colour against the Pro background, per the
# procedure in docs/design/theming-qa.md § 6.3:
#
#   Δ = C - B_classic                (per-channel integer sRGB)
#   P = clamp( B_pro + Δ, [0, 255] ) (per-channel)
#
# Usage:
#   ./retint.sh <C_hex> <B_classic_hex> <B_pro_hex>
#
# Example:
#   $ ./retint.sh '#2B3A2F' '#282A36' '#22212C'
#   #253125
#
# Also sourceable — exposes a `retint` function that prints the same result
# to stdout. Pure bash; no external tools required.

set -uo pipefail

# Parse a hex colour like "#RRGGBB" or "RRGGBB" into three integer RGB
# channels, echoed space-separated. Returns non-zero on malformed input.
_retint_parse_hex() {
  local hex="${1#\#}"
  if [[ ! "$hex" =~ ^[0-9A-Fa-f]{6}$ ]]; then
    echo "retint: invalid hex colour: '$1'" >&2
    return 2
  fi
  local r g b
  r=$(printf '%d' "0x${hex:0:2}")
  g=$(printf '%d' "0x${hex:2:2}")
  b=$(printf '%d' "0x${hex:4:2}")
  printf '%d %d %d\n' "$r" "$g" "$b"
}

# Clamp an integer to [0, 255].
_retint_clamp() {
  local v=$1
  (( v < 0 ))   && v=0
  (( v > 255 )) && v=255
  printf '%d\n' "$v"
}

# retint <C_hex> <B_classic_hex> <B_pro_hex>
# Prints the re-tinted Pro hex (uppercase, "#RRGGBB") to stdout.
retint() {
  if (( $# != 3 )); then
    echo "usage: retint <C_hex> <B_classic_hex> <B_pro_hex>" >&2
    return 2
  fi

  local c_rgb bc_rgb bp_rgb
  c_rgb=$(_retint_parse_hex "$1")  || return $?
  bc_rgb=$(_retint_parse_hex "$2") || return $?
  bp_rgb=$(_retint_parse_hex "$3") || return $?

  # shellcheck disable=SC2206
  local -a c=( $c_rgb ) bc=( $bc_rgb ) bp=( $bp_rgb )
  local -a p=()
  local i v
  for i in 0 1 2; do
    v=$(( bp[i] + c[i] - bc[i] ))
    v=$(_retint_clamp "$v")
    p+=( "$v" )
  done

  printf '#%02X%02X%02X\n' "${p[0]}" "${p[1]}" "${p[2]}"
}

# CLI entry point when executed directly.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  retint "$@"
fi
