#!/usr/bin/env bash
# desktop-layer2-switch-to-karabiner.sh — switch Layer 2 from Hammerspoon
# to Karabiner-Elements (Appendix B upgrade path).
#
# Preconditions:
#   1. IT has added pqrs.org team ID G43BCU2T37 to the MDM System
#      Extensions allow-list. Verify with:
#          systemextensionsctl list
#   2. Karabiner-Elements cask is available to brew (if not, run
#      `brew install --cask karabiner-elements` first).
#
# What this script does:
#   1. Stops Hammerspoon.
#   2. Removes the ~/.hammerspoon/init.lua symlink.
#   3. Re-runs install-macos.sh with DESKTOP_LAYER2_USE_KARABINER=true
#      so the Karabiner JSON gets symlinked.
#   4. Prints a reminder to enable the rule in Karabiner prefs + grant
#      Accessibility to Karabiner-Elements.app.
#
# Usage: bash scripts/desktop-layer2-switch-to-karabiner.sh

set -uo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
DOTFILES="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"

echo "==> stopping Hammerspoon"
killall Hammerspoon 2>/dev/null || true

echo "==> removing Hammerspoon init symlink"
rm -f "$HOME/.hammerspoon/init.lua"

echo "==> re-running install-macos.sh with DESKTOP_LAYER2_USE_KARABINER=true"
DESKTOP_LAYER2_USE_KARABINER=true bash "$DOTFILES/install-macos.sh"

cat <<'EOF'

─────────────────────────────────────────────────────────────
Manual steps to complete the switch:

  1. Open Karabiner-Elements.app (install via Homebrew if missing:
     brew install --cask karabiner-elements).
  2. Grant Accessibility permission when prompted (JIT admin window).
  3. Prefs → Complex Modifications → Add rule → select
     "Desktop Layer 2 — Caps Lock → Escape on tap / Hyper on hold".
  4. Prefs → Simple Modifications → delete any stale Caps Lock rule
     from Hammerspoon's prior session (belt-and-braces).
  5. Test: Caps-tap should emit Escape; Caps-hold + letter should
     emit Hyper+letter (same behaviour as Hammerspoon default).
  6. (Optional) Disable "Launch Hammerspoon at login" in Hammerspoon
     prefs to avoid duplicate keyboard handlers.

Walk docs/manual-smoke/desktop-layer2.md under "Karabiner upgrade path".
─────────────────────────────────────────────────────────────
EOF
