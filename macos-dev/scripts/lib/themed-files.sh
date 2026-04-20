# shellcheck shell=bash
# scripts/lib/themed-files.sh
#
# Authoritative file-glob set for theming QA scans. See
# docs/design/theming-qa.md § 4.3 for the spec.
#
# Sourced file, not executable. Exposes a single function:
#
#   themed_files   prints newline-separated absolute paths to every file
#                  matching the glob set below, filtered to files that
#                  actually exist. Missing files are skipped silently.
#
# Globs are anchored at the macos-dev/ root, which is resolved relative to
# this file's location (../ from scripts/lib/).

set -uo pipefail

# Resolve macos-dev/ root once at source time. Walk symlinks so the script
# works when invoked via a dotfiles symlink farm.
__THEMED_FILES_SRC="${BASH_SOURCE[0]}"
while [[ -L "$__THEMED_FILES_SRC" ]]; do
  __THEMED_FILES_DIR="$(cd -P "$(dirname "$__THEMED_FILES_SRC")" && pwd)"
  __THEMED_FILES_SRC="$(readlink "$__THEMED_FILES_SRC")"
  [[ "$__THEMED_FILES_SRC" != /* ]] && __THEMED_FILES_SRC="$__THEMED_FILES_DIR/$__THEMED_FILES_SRC"
done
THEMED_FILES_ROOT="$(cd -P "$(dirname "$__THEMED_FILES_SRC")/../.." && pwd)"
export THEMED_FILES_ROOT

# The authoritative glob set. Keep in lock-step with
# docs/design/theming-qa.md § 4.3.
THEMED_FILES_GLOBS=(
  "opencode/themes/*.json"
  "opencode/tui.jsonc"
  "opencode/opencode.jsonc"
  "starship/starship.toml"
  "tmux/.tmux.conf"
  "lazygit/config.yml"
  "gh-dash/config.yml"
  "yazi/theme.toml"
  "btop/themes/*.theme"
  "k9s/skins/*.yaml"
  "bat/themes/*.tmTheme"
  "jqp/.jqp.yaml"
  "glow/styles/*.json"
  "freeze/*.json"
  "lazydocker/config.yml"
  "lnav/formats/**/*.json"
  "television/themes/*.toml"
  "atuin/config.toml"
  "sketchybar/colors.sh"
  "bash/.bashrc"
  "bash/.dir_colors"
  ".gitconfig"
  "ghostty/config"
  "kitty/kitty.conf"
)
export THEMED_FILES_GLOBS

# Prints absolute paths, one per line, to every existing file matched by
# any glob in THEMED_FILES_GLOBS. Missing files are dropped silently.
themed_files() {
  # Run in a subshell so our shopt / cd changes do not leak.
  (
    shopt -s globstar nullglob
    cd "$THEMED_FILES_ROOT" || return 1
    local glob match
    for glob in "${THEMED_FILES_GLOBS[@]}"; do
      # Expand relative to macos-dev/ root. nullglob ensures non-matching
      # patterns produce zero iterations instead of the literal glob.
      for match in $glob; do
        if [[ -f "$match" ]]; then
          printf '%s/%s\n' "$THEMED_FILES_ROOT" "$match"
        fi
      done
    done
  )
}
