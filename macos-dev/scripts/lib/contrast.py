#!/usr/bin/env python3
"""WCAG 2.1 relative-luminance contrast ratio calculator.

Implements `theming-qa.md` § 5.4 verbatim. Stdlib only.

CLI:
    python3 contrast.py <fg_hex> <bg_hex> --threshold 4.5

Hex args accept '#RRGGBB' case-insensitively. Always prints the ratio
to stdout as 'ratio=<N.NN>'. Exits 0 iff ratio >= threshold, exits 1
if below threshold, and exits 2 on invalid input.
"""

from __future__ import annotations

import argparse
import re
import sys

_HEX_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")


def rel_luminance(hex_str: str) -> float:
    r, g, b = (int(hex_str[i:i + 2], 16) / 255 for i in (1, 3, 5))

    def c(x: float) -> float:
        return x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4

    r, g, b = c(r), c(g), c(b)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(fg: str, bg: str) -> float:
    l1, l2 = rel_luminance(fg), rel_luminance(bg)
    lo, hi = sorted((l1, l2))
    return (hi + 0.05) / (lo + 0.05)


def _validate_hex(value: str) -> str:
    if not _HEX_RE.match(value):
        raise ValueError(f"invalid hex color: {value!r} (expected #RRGGBB)")
    # Normalise to uppercase so downstream comparisons are case-stable.
    return "#" + value[1:].upper()


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Compute WCAG 2.1 relative-luminance contrast ratio.",
    )
    parser.add_argument("fg", help="foreground hex color (#RRGGBB)")
    parser.add_argument("bg", help="background hex color (#RRGGBB)")
    parser.add_argument(
        "--threshold",
        type=float,
        default=4.5,
        help="minimum required ratio (default: 4.5 = WCAG AA normal text)",
    )
    args = parser.parse_args(argv)

    try:
        fg = _validate_hex(args.fg)
        bg = _validate_hex(args.bg)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    ratio = contrast_ratio(fg, bg)
    print(f"ratio={ratio:.2f}")
    return 0 if ratio >= args.threshold else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
