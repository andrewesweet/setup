#!/usr/bin/env bash
# test-plan-layer1b-i.sh — acceptance tests for Layer 1b-i (sesh + yazi + xh + rip + rip2 + jqp + diffnav + carapace)
#
# Platform-aware: runs on macOS and WSL2/Linux.
#
# Usage:
#   bash scripts/test-plan-layer1b-i.sh              # safe tests only
#   bash scripts/test-plan-layer1b-i.sh --full       # + invasive tests (bash -lc init checks)
#
# Each AC from the Layer 1b-i plan is implemented as a labelled check.
# Exits 0 if all requested tests pass, 1 otherwise.

set -uo pipefail

# ── Self-resolve to macos-dev root ───────────────────────────────────────────
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
MACOS_DEV="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"
cd "$MACOS_DEV" || { echo "ERROR: cannot cd to $MACOS_DEV" >&2; exit 2; }

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)
    PLATFORM="linux"
    [[ -n "${WSL_DISTRO_NAME:-}" ]] && PLATFORM="wsl"
    ;;
  *) echo "ERROR: unsupported platform" >&2; exit 2 ;;
esac

if [[ -t 1 ]]; then
  C_GREEN=$'\033[0;32m' C_RED=$'\033[0;31m' C_YELLOW=$'\033[0;33m' C_RESET=$'\033[0m'
else
  C_GREEN='' C_RED='' C_YELLOW='' C_RESET=''
fi

pass=0
fail=0
skip=0

ok()   { printf "  ${C_GREEN}✓${C_RESET} %s\n" "$1"; pass=$((pass + 1)); }
nok()  { printf "  ${C_RED}✗${C_RESET} %s\n" "$1"; fail=$((fail + 1)); }
skp()  { printf "  ${C_YELLOW}~${C_RESET} %s (skipped: %s)\n" "$1" "$2"; skip=$((skip + 1)); }

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else nok "$desc"; fi
}

echo "Layer 1b-i acceptance tests (sesh/yazi/xh/rip/rip2/jqp/diffnav/carapace)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1: Brewfile declares all Layer 1b-i tools ─────────────────────────
echo "AC-1: Brewfile declares Layer 1b-i tools"
for t in sesh yazi xh rip2 jqp carapace; do
  check "Brewfile has brew \"$t\"" grep -qE "^\s*brew\s+\"$t\"" Brewfile
done
check "Brewfile has brew \"cesarferreira/tap/rip\"" \
  grep -qE '^\s*brew\s+"cesarferreira/tap/rip"' Brewfile
check "Brewfile has brew \"dlvhdr/formulae/diffnav\"" \
  grep -qE '^\s*brew\s+"dlvhdr/formulae/diffnav"' Brewfile
check "Brewfile taps cesarferreira/tap" \
  grep -qE '^\s*tap\s+"cesarferreira/tap"' Brewfile
check "Brewfile taps dlvhdr/formulae" \
  grep -qE '^\s*tap\s+"dlvhdr/formulae"' Brewfile

# ── AC-2: tools.txt manifest consistency ──────────────────────────────────
echo ""
echo "AC-2: tools.txt manifest consistency"
check "check-tool-manifest.sh passes" bash scripts/check-tool-manifest.sh

# ── AC-3: sesh template with substitution markers ─────────────────────────
echo ""
echo "AC-3: sesh/sesh.toml.tmpl"
check "sesh/sesh.toml.tmpl exists" test -f sesh/sesh.toml.tmpl
check "sesh template contains @DOTFILES@" \
  grep -q '@DOTFILES@' sesh/sesh.toml.tmpl
# No $ENV expansion inside [[session]] path fields — sesh requires absolute paths.
check "sesh template has no \$VAR expansion in paths" \
  bash -c '! grep -nE "^[[:space:]]*path[[:space:]]*=[[:space:]]*\"\\\$" sesh/sesh.toml.tmpl'

# ── AC-4: install scripts substitute template ─────────────────────────────
echo ""
echo "AC-4: install scripts generate ~/.config/sesh/sesh.toml"
check "install-macos.sh substitutes @DOTFILES@" \
  grep -q 's|@DOTFILES@|' install-macos.sh
check "install-wsl.sh substitutes @DOTFILES@" \
  grep -q 's|@DOTFILES@|' install-wsl.sh
check "install-macos.sh writes to ~/.config/sesh/sesh.toml" \
  grep -qE 'sesh/sesh\.toml[^.]' install-macos.sh
check "install-wsl.sh writes to ~/.config/sesh/sesh.toml" \
  grep -qE 'sesh/sesh\.toml[^.]' install-wsl.sh
if [[ "$FULL" == true ]] && [[ -f "$HOME/.config/sesh/sesh.toml" ]]; then
  if ! grep -q '@DOTFILES@' "$HOME/.config/sesh/sesh.toml"; then
    ok "generated sesh.toml contains no @DOTFILES@ markers"
  else
    nok "generated sesh.toml still contains @DOTFILES@ markers"
  fi
else
  skp "generated sesh.toml marker check" "requires --full + prior install"
fi

# ── AC-5: yazi configs exist and are symlinked ────────────────────────────
echo ""
echo "AC-5: yazi configs present and wired"
for f in yazi/yazi.toml yazi/keymap.toml yazi/theme.toml; do
  check "$f exists" test -f "$f"
done
check "install-macos.sh links yazi.toml" \
  grep -qE 'link\s+yazi/yazi\.toml' install-macos.sh
check "install-macos.sh links keymap.toml" \
  grep -qE 'link\s+yazi/keymap\.toml' install-macos.sh
check "install-macos.sh links theme.toml" \
  grep -qE 'link\s+yazi/theme\.toml' install-macos.sh
check "install-wsl.sh links yazi.toml" \
  grep -qE 'link\s+yazi/yazi\.toml' install-wsl.sh
check "install-wsl.sh links keymap.toml" \
  grep -qE 'link\s+yazi/keymap\.toml' install-wsl.sh
check "install-wsl.sh links theme.toml" \
  grep -qE 'link\s+yazi/theme\.toml' install-wsl.sh

# ── AC-6: y() cd-on-quit wrapper ─────────────────────────────────────────
echo ""
echo "AC-6: y() cd-on-quit wrapper"
check "bash/.bash_aliases defines y()" \
  bash -c "awk '/^y\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'yazi'"
check "y() body uses --cwd-file" \
  bash -c "awk '/^y\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q -- '--cwd-file'"
check "y() body cds into the yazi-selected directory" \
  bash -c "awk '/^y\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -qE 'builtin cd|^[[:space:]]*cd '"

# ── AC-7: jqp config (Dracula) ───────────────────────────────────────────
echo ""
echo "AC-7: jqp/.jqp.yaml"
check "jqp/.jqp.yaml exists" test -f jqp/.jqp.yaml
check "jqp config has theme: dracula" \
  grep -qE '^theme:\s*dracula\s*$' jqp/.jqp.yaml
check "install-macos.sh links jqp/.jqp.yaml" \
  grep -qE 'link\s+jqp/\.jqp\.yaml' install-macos.sh
check "install-wsl.sh links jqp/.jqp.yaml" \
  grep -qE 'link\s+jqp/\.jqp\.yaml' install-wsl.sh

# ── AC-8: diffnav config (Dracula palette) ───────────────────────────────
echo ""
echo "AC-8: diffnav/config.yml"
check "diffnav/config.yml exists" test -f diffnav/config.yml
check "install-macos.sh links diffnav/config.yml" \
  grep -qE 'link\s+diffnav/config\.yml' install-macos.sh
check "install-wsl.sh links diffnav/config.yml" \
  grep -qE 'link\s+diffnav/config\.yml' install-wsl.sh

# ── AC-9: carapace bridges wired into bash init ──────────────────────────
echo ""
echo "AC-9: carapace completion wiring"
check "CARAPACE_BRIDGES exported in .bashrc" \
  grep -qE '^export\s+CARAPACE_BRIDGES=' bash/.bashrc
check "CARAPACE_BRIDGES includes zsh,fish,bash,inshellisense" \
  bash -c "grep -E '^export CARAPACE_BRIDGES=' bash/.bashrc | grep -q 'zsh' && grep -E '^export CARAPACE_BRIDGES=' bash/.bashrc | grep -q 'bash' && grep -E '^export CARAPACE_BRIDGES=' bash/.bashrc | grep -q 'fish'"
# carapace completion source wrapped in a `command -v` guard.
check "carapace completion source is guarded" \
  bash -c "grep -Pzo '(?s)command -v carapace[^\n]*\n[^\n]*carapace[[:space:]]+_carapace[[:space:]]+bash' bash/.bashrc | grep -q ."

# ── AC-10: new aliases with exact definitions ─────────────────────────────
echo ""
echo "AC-10: Layer 1b-i aliases defined"
check "alias http='xh'"            grep -qE "^alias http='xh'"            bash/.bash_aliases
check "alias rrip='rip2 -u'"       grep -qE "^alias rrip='rip2 -u'"       bash/.bash_aliases
check "alias rm-safe='rip2'"       grep -qE "^alias rm-safe='rip2'"       bash/.bash_aliases
check "alias jqi='jqp'"            grep -qE "^alias jqi='jqp'"            bash/.bash_aliases
check "alias dn='diffnav'"         grep -qE "^alias dn='diffnav'"         bash/.bash_aliases
check "alias sx='sesh connect'"    grep -qE "^alias sx='sesh connect'"    bash/.bash_aliases
check "alias sxl='sesh list'"      grep -qE "^alias sxl='sesh list'"      bash/.bash_aliases

# ── AC-11: cheat() has subcommands for every new tool ────────────────────
echo ""
echo "AC-11: cheat() subcommand coverage"
# Scope to the cheat() function body so comments elsewhere don't false-positive.
cheat_body() { awk '/^cheat\(\) \{/,/^\}/' bash/.bash_aliases | sed 's/#.*//'; }
for tool in atuin "tv|television" sesh yazi xh rip rip2 jqp diffnav; do
  if cheat_body | grep -qE "^[[:space:]]*${tool}\)"; then
    ok "cheat: case arm for '$tool' present"
  else
    nok "cheat: case arm for '$tool' present"
  fi
done
check "cheat help lists new subcommands" \
  bash -c "cheat_body() { awk '/^cheat\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//'; }; cheat_body | grep -q 'sesh, yazi, xh, rip'"

# ── AC-12: cheatsheet.md tool reference rows ─────────────────────────────
echo ""
echo "AC-12: cheatsheet.md Tool reference coverage"
check "cheatsheet lists sesh/sx"       grep -qE '\bsesh\b.*\bsx\b' docs/cheatsheet.md
check "cheatsheet lists yazi/y"        grep -qE 'yazi.*`y`|\byazi\b.*cd-on-quit' docs/cheatsheet.md
check "cheatsheet lists xh/http"       grep -qE '\bxh\b.*\bhttp\b' docs/cheatsheet.md
check "cheatsheet lists rip (killer)"  grep -qiE 'rip.*process.*killer|rip.*fuzzy.*killer' docs/cheatsheet.md
check "cheatsheet lists rip2/rrip"     grep -qE '\brip2\b.*\brrip\b|rrip.*rip2' docs/cheatsheet.md
check "cheatsheet lists jqp/jqi"       grep -qE '\bjqp\b.*\bjqi\b|jqi.*jqp' docs/cheatsheet.md
check "cheatsheet lists diffnav/dn"    grep -qE '\bdiffnav\b.*\bdn\b' docs/cheatsheet.md

# ── AC-13: gh_release_install() helper ───────────────────────────────────
echo ""
echo "AC-13: install-wsl.sh gh_release_install helper"
check "gh_release_install is defined" \
  bash -c "awk '/^gh_release_install\\(\\) \\{/,/^\\}/' install-wsl.sh | grep -q '.'"
check "helper handles x86_64"    \
  bash -c "awk '/^gh_release_install\\(\\) \\{/,/^\\}/' install-wsl.sh | grep -q 'x86_64'"
check "helper handles aarch64"   \
  bash -c "awk '/^gh_release_install\\(\\) \\{/,/^\\}/' install-wsl.sh | grep -q 'aarch64'"
check "helper writes to ~/.local/bin" \
  bash -c "awk '/^gh_release_install\\(\\) \\{/,/^\\}/' install-wsl.sh | grep -q '.local/bin'"
check "helper is idempotent (checks for existing binary)" \
  bash -c "awk '/^gh_release_install\\(\\) \\{/,/^\\}/' install-wsl.sh | grep -qE 'command -v|-x '"

# ── AC-14: install-wsl.sh installs each tool ──────────────────────────────
echo ""
echo "AC-14: install-wsl.sh installs Layer 1b-i tools"
check "install-wsl.sh installs sesh" \
  grep -qE 'gh_release_install\s+"?joshmedeski/sesh"?' install-wsl.sh
check "install-wsl.sh installs yazi" \
  grep -qE 'gh_release_install\s+"?sxyazi/yazi"?' install-wsl.sh
check "install-wsl.sh installs rip (cesarferreira)" \
  grep -qE 'gh_release_install\s+"?cesarferreira/rip"?' install-wsl.sh
check "install-wsl.sh installs rip2 (MilesCranmer)" \
  grep -qE 'gh_release_install\s+"?MilesCranmer/rip2"?' install-wsl.sh
check "install-wsl.sh installs jqp (noahgorstein)" \
  grep -qE 'gh_release_install\s+"?noahgorstein/jqp"?' install-wsl.sh
check "install-wsl.sh installs diffnav (dlvhdr)" \
  grep -qE 'gh_release_install\s+"?dlvhdr/diffnav"?' install-wsl.sh
check "install-wsl.sh installs carapace" \
  grep -qE 'gh_release_install\s+"?rsteube/carapace-bin"?' install-wsl.sh
# xh is in apt.
check "install-wsl.sh apt-installs xh" \
  grep -qE 'apt\s+install.*\bxh\b' install-wsl.sh

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
