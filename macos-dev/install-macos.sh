#!/usr/bin/env bash
# install-macos.sh — install dotfiles on macOS
#
# This script:
#   1. Self-resolves DOTFILES from its own location
#   2. Verifies Homebrew is installed
#   3. Runs `brew bundle` against Brewfile
#   4. Installs post-brew tools: uv tools (ty, prek), bun global packages
#      (opencode, critique), gcloud components
#   5. Symlinks configuration files from the repo into $HOME, backing up
#      any existing non-symlink files to ~/.dotfiles-backup/<timestamp>/
#   6. (Later plans will add: LaunchAgent for Podman Machine, more symlinks)
#
# Usage:
#   bash install-macos.sh             # fresh install
#   bash install-macos.sh --restore   # uninstall: restore from latest backup
#
# Idempotent: re-running is safe. Symlinks already pointing at this repo
# are not touched. Non-symlink files are backed up before being replaced.

set -uo pipefail

# ── Self-resolve DOTFILES ────────────────────────────────────────────────────
# Resolves to the directory containing this script, regardless of where
# the user runs it from. Follows symlinks so `install-macos.sh` invoked
# via a symlink still finds the real repo.
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
DOTFILES="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
export DOTFILES

# ── Dracula Pro preflight (Wave A) ───────────────────────────────────────────
# Tier 1 theming requires ~/dracula-pro/ present. On CI or machines without a
# Pro licence, set SKIP_DRACULA_PRO=1 to skip Tier 1 steps and continue.
# See macos-dev/docs/design/theming.md § 4.3.
# shellcheck source=scripts/lib/dracula-pro-palette.sh disable=SC1091
source "$DOTFILES/scripts/lib/dracula-pro-palette.sh"
DRACULA_PRO_OK=0
if [[ -d "$HOME/dracula-pro" ]]; then
  DRACULA_PRO_OK=1
elif [[ "${SKIP_DRACULA_PRO:-0}" == 1 ]]; then
  printf "WARN: SKIP_DRACULA_PRO=1 — Tier 1 theming skipped\n" >&2
else
  printf "error: ~/dracula-pro/ not found. Install Dracula Pro from draculatheme.com/pro before running this script.\n" >&2
  printf "       (To skip Tier 1 on CI, rerun with SKIP_DRACULA_PRO=1 in the environment.)\n" >&2
  exit 1
fi
export DRACULA_PRO_OK

BACKUP_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$HOME/.dotfiles-backup/$BACKUP_TIMESTAMP"

# ── Modes ────────────────────────────────────────────────────────────────────
MODE="install"
if [[ "${1:-}" == "--restore" ]]; then
  MODE="restore"
fi

# ── Colours ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[0;33m'
  C_RED='\033[0;31m'
  C_RESET='\033[0m'
else
  C_GREEN='' C_YELLOW='' C_RED='' C_RESET=''
fi

log()  { printf "${C_GREEN}==>${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}WARN:${C_RESET} %s\n" "$*" >&2; }
err()  { printf "${C_RED}ERROR:${C_RESET} %s\n" "$*" >&2; }

# ── link() helper ────────────────────────────────────────────────────────────
# Usage: link <src-relative-to-DOTFILES> <dst-relative-to-HOME>
#
# If $dst exists and is not already a symlink, it is moved to the backup
# directory (preserving relative path structure). Then $dst is created as
# a symlink to $DOTFILES/$src.
link() {
  local src_rel="$1" dst_rel="$2"
  local src="$DOTFILES/$src_rel"
  local dst="$HOME/$dst_rel"

  if [[ ! -e "$src" ]]; then
    warn "source missing, skipping: $src"
    return 0
  fi

  # If dst is already a symlink pointing at src, nothing to do
  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    printf "  unchanged %s\n" "$dst"
    return 0
  fi

  # If dst exists as a regular file/dir/other-symlink, back it up
  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$dst_rel")"
    mv "$dst" "$BACKUP_DIR/$dst_rel"
    printf "  backed up %s → %s\n" "$dst" "$BACKUP_DIR/$dst_rel"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
  printf "  linked    %s\n" "$dst"
}

# ── restore() ────────────────────────────────────────────────────────────────
# Finds the most recent backup directory under ~/.dotfiles-backup/ and
# restores its contents to $HOME. Removes any symlinks currently pointing
# into $DOTFILES before restoring.
restore() {
  if [[ ! -d "$HOME/.dotfiles-backup" ]]; then
    err "no backup directory found at $HOME/.dotfiles-backup/"
    exit 1
  fi

  local latest
  latest="$(find "$HOME/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r | head -n1)"
  latest="${latest##*/}"
  if [[ -z "$latest" ]]; then
    err "no backups found in $HOME/.dotfiles-backup/"
    exit 1
  fi

  local backup="$HOME/.dotfiles-backup/$latest"
  log "restoring from $backup"

  # Unload LaunchAgent if present
  launchctl bootout "gui/$(id -u)/io.podman.machine" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/io.podman.machine.plist"
  rm -f "$HOME/.local/bin/podman-machine-start"
  rm -f "$HOME/.local/bin/dev"

  # Walk the backup tree and restore each file.
  # Note the explicit grouping with \( ... \) — without it, find's operator
  # precedence parses "-type f -o -type l" as "(-type f) -o (-type l -print)"
  # on some implementations, silently dropping regular files.
  (cd "$backup" && find . \( -type f -o -type l \) -print) | while IFS= read -r rel; do
    rel="${rel#./}"
    local dst="$HOME/$rel"
    # Remove current file if it's a symlink into DOTFILES
    if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$DOTFILES"/* ]]; then
      rm "$dst"
    fi
    mkdir -p "$(dirname "$dst")"
    cp -a "$backup/$rel" "$dst"
    printf "  restored %s\n" "$dst"
  done

  log "restore complete from $backup"
  log "backup directory preserved for safety. Remove manually when satisfied:"
  log "  rm -rf $backup"
}

# ── Main ─────────────────────────────────────────────────────────────────────

# Print DOTFILES resolution result up front, BEFORE any platform or
# prerequisite checks. This ensures the self-resolution test in the plan
# can capture the value regardless of where the script exits afterwards.
log "DOTFILES=$DOTFILES"

if [[ "$MODE" == "restore" ]]; then
  restore
  exit 0
fi

# Verify we're on macOS
if [[ "$(uname)" != "Darwin" ]]; then
  err "install-macos.sh is for macOS. On WSL2/Linux, use install-wsl.sh."
  exit 1
fi

# Verify Homebrew is installed
if ! command -v brew &>/dev/null; then
  err "Homebrew is not installed. Install it first:"
  # shellcheck disable=SC2016
  # Single quotes are intentional — we want to show the user the literal
  # command to copy-paste, with $() unexpanded.
  err '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
fi

HOMEBREW_PREFIX="$(brew --prefix)"
log "HOMEBREW_PREFIX=$HOMEBREW_PREFIX"

# ── Desktop: cask install directory (Layer 1 desktop) ────────────────────────
# /Applications is commonly MDM-locked on managed Macs. Install all casks
# into ~/Applications/ instead — benign on non-managed Macs (user-local is a
# valid Homebrew cask target). Must be exported BEFORE `brew bundle` so every
# cask (including pre-desktop ones like codeql, visual-studio-code) inherits.
mkdir -p "$HOME/Applications"
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"

# ── Step 1: Brew bundle ──────────────────────────────────────────────────────
# Note: install.md lists `brew install charmbracelet/tap/freeze` as a separate
# step, but we include it in the Brewfile (under its tap declaration) instead.
# `brew bundle` handles tapped formulas correctly, so one step covers both.
log "running brew bundle"
if [[ ! -f "$DOTFILES/Brewfile" ]]; then
  err "Brewfile not found at $DOTFILES/Brewfile"
  exit 1
fi
if ! brew bundle --file="$DOTFILES/Brewfile"; then
  err "brew bundle failed — aborting install"
  err "check the output above for the specific formula that failed"
  exit 1
fi

# ── Step 1b: TPM (tmux plugin manager) ───────────────────────────────────
# TPM is not a brew formula. Clone directly; plugins install on first
# tmux launch with `prefix + I` (or continuum auto-restore). Idempotent.
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  log "installing TPM"
  if ! git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"; then
    warn "TPM clone failed — install manually before first tmux launch"
  fi
else
  log "TPM already installed at ~/.tmux/plugins/tpm"
fi

# ── Step 2: Post-brew tool installs ──────────────────────────────────────────

# uv tools (ty and prek are NOT in Homebrew)
if command -v uv &>/dev/null; then
  log "installing uv tools (ty, prek)"
  uv tool install ty@latest || warn "ty install failed"
  uv tool install prek       || warn "prek install failed"
else
  warn "uv not available, skipping uv tool installs"
fi

# bun global installs (OpenCode and critique)
if command -v bun &>/dev/null; then
  log "installing bun global packages (opencode-ai, critique)"
  bun install -g opencode-ai critique || warn "bun global install failed"
else
  warn "bun not available, skipping opencode/critique install"
fi

# ── gh extensions (Layer 1b-iii) ─────────────────────────────────────────
# Each install is idempotent: `gh extension install` is a no-op if already
# installed. `|| true` avoids failing the whole script if a single extension
# is unavailable (e.g. corporate network blocks a release asset).
if command -v gh &>/dev/null; then
  log "installing gh extensions"
  gh extension install dlvhdr/gh-dash             || true
  gh extension install github/gh-copilot          || true
  gh extension install seachicken/gh-poi          || true
  gh extension install yusukebe/gh-markdown-preview || true
  gh extension install k1Low/gh-grep              || true
  gh extension install github/gh-aw               || true
  gh extension install Link-/gh-token             || true
else
  warn "gh not on PATH — skipping gh extension installs"
fi

# gcloud SDK — PREREQUISITE, not installed by this script.
#
# Homebrew migrated google-cloud-sdk from a formula to the gcloud-cli cask.
# On restrictive corporate networks (e.g. with TLS-inspecting proxies that
# block large binary downloads from dl.google.com), the cask download is
# firewalled and cannot be installed via `brew install`. This has been
# empirically confirmed on the target environment.
#
# Fresh installs MUST obtain gcloud via an organisation-approved path:
#   - a managed Mac image that ships gcloud pre-installed, or
#   - an internal software catalogue / IT ticket, or
#   - a direct download from https://cloud.google.com/sdk/docs/install-sdk
#     over a network that permits the download
#
# This script does not attempt to install gcloud. It checks for presence,
# warns clearly if absent, and continues — the rest of the dotfiles work
# without gcloud.
if command -v gcloud &>/dev/null; then
  log "gcloud detected: $(gcloud --version 2>/dev/null | head -1)"

  # gcloud components — only runs if gcloud was installed via Homebrew or
  # the Google SDK installer (which support `components install`).
  # Package-managed installs (apt, apk) disable the component manager.
  log "installing gcloud components"
  gcloud components install --quiet \
    alpha beta bq gke-gcloud-auth-plugin \
    pubsub-emulator cloud-datastore-emulator cloud-firestore-emulator \
    cloud-build-local bigtable spanner-emulator || warn "gcloud components install failed (component manager may be disabled for package-managed installs)"
else
  warn "gcloud SDK not installed — this is a PREREQUISITE for the dotfiles"
  warn ""
  warn "gcloud is not installed by this script because the Google SDK cask"
  warn "(~400MB) is commonly blocked by corporate network proxies. Install"
  warn "via one of:"
  warn "  - your organisation's managed Mac image / software catalogue"
  warn "  - an internal mirror if one exists"
  warn "  - a direct download from https://cloud.google.com/sdk/docs/install-sdk"
  warn "    on a network that permits the download"
  warn ""
  warn "After installing gcloud, re-run this script to install components."
  warn "Continuing without gcloud — the rest of the install proceeds normally."
fi

# ── Step 3: Symlink config files ─────────────────────────────────────────────
# (Intentionally empty in Plan 1. Later plans add link() calls as configs
# get created.)
log "symlinking configs"

# ── sesh (generated from template — absolute paths required by schema) ──
mkdir -p "$HOME/.config/sesh"
# shellcheck disable=SC2016  # $DOTFILES/$HOME expand at install time, intentional
sed -e "s|@DOTFILES@|$DOTFILES|g" -e "s|@HOME@|$HOME|g" \
  "$DOTFILES/sesh/sesh.toml.tmpl" > "$HOME/.config/sesh/sesh.toml"
printf "  generated %s\n" "$HOME/.config/sesh/sesh.toml"

# bash config (Plan 2)
link bash/.bash_profile .bash_profile
link bash/.bashrc       .bashrc
link bash/.bash_aliases .bash_aliases
link bash/.inputrc      .inputrc

# git config (Plan 3)
link git/.gitconfig         .gitconfig
link git/.gitignore_global  .gitignore_global

# kitty terminal (Plan 4, Dracula Pro palette added in Layer 1b-ii)
link kitty/kitty.conf        .config/kitty/kitty.conf

# kitty Dracula Pro theme (Wave A Tier 1) — ~/dracula-pro/themes/ ships no
# kitty-native file, so generate one from the palette file at install time.
# Palette hex values are facts (spec § 4.1 — reproduction authorised).
if [[ "${DRACULA_PRO_OK:-0}" == 1 ]]; then
  mkdir -p "$HOME/.config/kitty"
  gen="$HOME/.config/kitty/dracula-pro.generated.conf"
  cat > "$gen" <<KITTYEOF
# AUTO-GENERATED by install-macos.sh from scripts/lib/dracula-pro-palette.sh
# Do not edit by hand — edits are overwritten on next install.
# Source: macos-dev/docs/design/theming.md § 3.1, § 6.3.

background            $DRACULA_PRO_BACKGROUND
foreground            $DRACULA_PRO_FOREGROUND
selection_foreground  $DRACULA_PRO_FOREGROUND
selection_background  $DRACULA_PRO_SELECTION
cursor                $DRACULA_PRO_CURSOR
cursor_text_color     $DRACULA_PRO_BACKGROUND

url_color             $DRACULA_PRO_CYAN

active_tab_foreground   $DRACULA_PRO_BACKGROUND
active_tab_background   $DRACULA_PRO_PURPLE
inactive_tab_foreground $DRACULA_PRO_FOREGROUND
inactive_tab_background $DRACULA_PRO_SELECTION

color0  $DRACULA_PRO_BLACK
color1  $DRACULA_PRO_RED
color2  $DRACULA_PRO_GREEN
color3  $DRACULA_PRO_YELLOW
color4  $DRACULA_PRO_BLUE
color5  $DRACULA_PRO_MAGENTA
color6  $DRACULA_PRO_CYAN
color7  $DRACULA_PRO_WHITE
color8  $DRACULA_PRO_BRIGHT_BLACK
color9  $DRACULA_PRO_BRIGHT_RED
color10 $DRACULA_PRO_BRIGHT_GREEN
color11 $DRACULA_PRO_BRIGHT_YELLOW
color12 $DRACULA_PRO_BRIGHT_BLUE
color13 $DRACULA_PRO_BRIGHT_MAGENTA
color14 $DRACULA_PRO_BRIGHT_CYAN
color15 $DRACULA_PRO_BRIGHT_WHITE
KITTYEOF
  printf "  generated %s\n" "$gen"
else
  warn "DRACULA_PRO_OK=0 — skipping kitty Dracula Pro generated file"
fi

# ghostty (Wave A Tier 1) — theme referenced directly via `theme = ~/dracula-pro/...`
link ghostty/config  .config/ghostty/config

# tmux (Plan 5)
link tmux/.tmux.conf  .tmux.conf

# starship, lazygit, mise (Plans 6–8)
link starship/starship.toml  .config/starship.toml
link lazygit/config.yml      .config/lazygit/config.yml
link mise/config.toml        .config/mise/config.toml

# atuin (Plan Layer 1a)
link atuin/config.toml        .config/atuin/config.toml

# television (Plan Layer 1a)
link television/config.toml   .config/television/config.toml

# television cable channels (Layer 1b-iii) — directory-level symlink so
# additional .toml files added later require no re-wire.
link television/cable         .config/television/cable

# ripgrep (Wave B — Dracula Pro via --colors config)
link ripgrep/config  .config/ripgrep/config

# dircolors (Wave B — ls/LS_COLORS Dracula Pro via dircolors -b)
link dircolors/.dir_colors  .dir_colors

# yazi (Plan Layer 1b-i)
link yazi/yazi.toml    .config/yazi/yazi.toml
link yazi/keymap.toml  .config/yazi/keymap.toml
link yazi/theme.toml   .config/yazi/theme.toml

# jqp (Plan Layer 1b-i)
link jqp/.jqp.yaml  .jqp.yaml

# diffnav (Plan Layer 1b-i)
link diffnav/config.yml  .config/diffnav/config.yml

# gh-dash (Plan Layer 1b-iii)
link gh-dash/config.yml  .config/gh-dash/config.yml

# opencode (Plan 9 + Wave B theme)
link opencode/opencode.jsonc                    .config/opencode/opencode.jsonc
link opencode/tui.jsonc                         .config/opencode/tui.jsonc
link opencode/themes/dracula-pro.json           .config/opencode/themes/dracula-pro.json
link opencode/instructions/git-conventions.md   .config/opencode/instructions/git-conventions.md
link opencode/instructions/scratch-dirs.md      .config/opencode/instructions/scratch-dirs.md

# OpenCode personal overrides (peer directory, scaffolded if absent)
if [[ ! -f "$HOME/.config/opencode-local/opencode.jsonc" ]]; then
  mkdir -p "$HOME/.config/opencode-local"
  echo '{}' > "$HOME/.config/opencode-local/opencode.jsonc"
  printf "  created  %s\n" "$HOME/.config/opencode-local/opencode.jsonc"
fi
mkdir -p "$HOME/.config/opencode-local"

# nvim (Plan 10)
link nvim  .config/nvim

# prek (Plan 11)
link prek/.pre-commit-config.yaml  .pre-commit-config.yaml

# vscode (Plan 12) — macOS settings path
link vscode/settings.json    "Library/Application Support/Code/User/settings.json"
link vscode/extensions.json  "Library/Application Support/Code/User/extensions.json"

# vscode — Dracula Pro .vsix (Wave A Tier 1). Only attempt if ~/dracula-pro/
# is present (DRACULA_PRO_OK=1) and `code` CLI is available. `code
# --install-extension` is idempotent: running with the same .vsix is a
# no-op once installed.
if [[ "${DRACULA_PRO_OK:-0}" == 1 ]] && command -v code &>/dev/null; then
  VSIX_PATH="$HOME/dracula-pro/themes/visual-studio-code/dracula-pro.vsix"
  if [[ -f "$VSIX_PATH" ]]; then
    log "installing Dracula Pro vscode extension"
    code --install-extension "$HOME/dracula-pro/themes/visual-studio-code/dracula-pro.vsix" || warn "vscode extension install failed (non-fatal)"
  else
    warn "Dracula Pro .vsix not found at $VSIX_PATH — skipping vscode theme install"
  fi
elif [[ "${DRACULA_PRO_OK:-0}" != 1 ]]; then
  warn "DRACULA_PRO_OK=0 — skipping vscode Pro .vsix install"
else
  warn "code CLI not on PATH — install vscode or run 'Shell Command: Install code command in PATH' from the command palette"
fi

# container dev script (Plan 13)
mkdir -p "$HOME/.local/bin"
link container/dev.sh  .local/bin/dev

# ── Desktop Layer 1 configs (aerospace + sketchybar + jankyborders) ─────
link aerospace/aerospace.toml  .config/aerospace/aerospace.toml
link sketchybar/sketchybarrc   .config/sketchybar/sketchybarrc
link sketchybar/colors.sh      .config/sketchybar/colors.sh
link sketchybar/icons.sh       .config/sketchybar/icons.sh
link sketchybar/plugins        .config/sketchybar/plugins
link jankyborders/bordersrc    .config/borders/bordersrc

# ── Desktop Layer 2 configs (Hammerspoon + skhd) ────────────────────
link hammerspoon/init.lua  .hammerspoon/init.lua
link skhd/.skhdrc          .config/skhd/skhdrc

# Karabiner JSON — dormant by default. Only symlinked when the user
# has opted into the Appendix-B upgrade path by exporting
# DESKTOP_LAYER2_USE_KARABINER=true.
if [[ "${DESKTOP_LAYER2_USE_KARABINER:-false}" == "true" ]]; then
  link karabiner/complex_modifications/desktop-layer2.json .config/karabiner/assets/complex_modifications/desktop-layer2.json
  log "Karabiner complex modification linked (DESKTOP_LAYER2_USE_KARABINER=true)"
fi

# Podman Machine LaunchAgent (macOS only)
if [[ "$(uname)" == "Darwin" ]]; then
  # Substitute markers in LaunchAgent wrapper
  wrapper_src="$DOTFILES/container/podman-machine-start.sh"
  wrapper_dst="$HOME/.local/bin/podman-machine-start"
  sed "s|@HOMEBREW_PREFIX@|$HOMEBREW_PREFIX|g" "$wrapper_src" > "$wrapper_dst"
  chmod +x "$wrapper_dst"
  printf "  linked    %s\n" "$wrapper_dst"

  # Substitute markers in plist and install
  mkdir -p "$HOME/Library/LaunchAgents"
  plist_src="$DOTFILES/container/io.podman.machine.plist"
  plist_dst="$HOME/Library/LaunchAgents/io.podman.machine.plist"
  sed -e "s|@HOME@|$HOME|g" -e "s|@SCRIPT_PATH@|$wrapper_dst|g" "$plist_src" > "$plist_dst"
  printf "  linked    %s\n" "$plist_dst"

  # Load LaunchAgent (idempotent)
  launchctl bootout "gui/$(id -u)/io.podman.machine" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist_dst"
  log "Podman Machine LaunchAgent loaded"

  # ── Desktop LaunchAgents (macOS only) ─────────────────────────────────
  for plist in com.felixkratz.sketchybar.plist \
               com.felixkratz.borders.plist \
               com.koekeishiya.skhd.plist; do
    plist_src="$DOTFILES/launchagents/$plist"
    plist_dst="$HOME/Library/LaunchAgents/$plist"
    if [[ ! -f "$plist_src" ]]; then
      warn "missing plist: $plist_src — skipping"
      continue
    fi
    sed -e "s|@HOMEBREW_PREFIX@|$HOMEBREW_PREFIX|g" -e "s|@HOME@|$HOME|g" \
        "$plist_src" > "$plist_dst"
    launchctl bootout "gui/$(id -u)/${plist%.plist}" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$plist_dst"
    printf "  linked    %s\n" "$plist_dst"
  done
  log "Desktop LaunchAgents loaded"
fi

# ── Step 4: Next steps ───────────────────────────────────────────────────────
log "install complete"
cat <<EOF

Next steps:
  1. Switch shell to Homebrew bash 5:
       echo "$HOMEBREW_PREFIX/bin/bash" | sudo tee -a /etc/shells
       chsh -s $HOMEBREW_PREFIX/bin/bash
  2. Install tmux plugins (first tmux launch):
       prefix + I  (Ctrl-A then Shift-I)
     Note: tmux-thumbs requires a Rust toolchain to compile on macOS too.
     If compilation fails, install from:
       https://github.com/fcsonline/tmux-thumbs/releases
  3. Create ~/.gitconfig.local with your identity:
       git config --file ~/.gitconfig.local user.name "Your Name"
       git config --file ~/.gitconfig.local user.email "you@example.com"
  4. Install fzf shell bindings (one-time, interactive):
       $HOMEBREW_PREFIX/opt/fzf/install --all --no-update-rc
  5. Authenticate tools:
       opencode auth login   # select GitHub Copilot
       gh auth login
       gcloud auth login     # only if gcloud is installed (see prerequisites)
  6. Restart terminal.
  7. Desktop first-run (macOS only — Layers 1–3):
     a) Launch AeroSpace from ~/Applications/AeroSpace.app (first launch
        triggers the Accessibility prompt; click "Open System Settings").
     b) Within a single JIT-admin window, grant Accessibility to each of:
          - AeroSpace             (~/Applications/AeroSpace.app)
          - skhd                  ($HOMEBREW_PREFIX/bin/skhd — Layer 2)
          - Hammerspoon           (~/Applications/Hammerspoon.app — Layer 2)
          - Raycast               (~/Applications/Raycast.app — Layer 3)
     c) Hide the native menu bar (SketchyBar replaces it):
          defaults write -g _HIHideMenuBar -bool true
          killall SystemUIServer
     d) Capture monitor names at EACH dock location and substitute the
        placeholders in ~/.config/aerospace/aerospace.toml under
        [workspace-to-monitor-force-assignment] (and the <primary-external-name>
        in ~/.config/sketchybar/sketchybarrc):
          aerospace list-monitors
        Edit the TOML + sketchybarrc, replacing each
        <office-central-monitor-name>, <home-centre-monitor-name>,
        <home-left-monitor-name>, <primary-external-name> placeholder,
        then reload:
          aerospace reload-config
          brew services restart sketchybar
     e) In Hammerspoon prefs (menu-bar icon → Preferences), toggle
          "Launch Hammerspoon at login" → enabled
        Then Reload Config (menu-bar icon → Reload Config).
        Caps-Lock-tap should emit Escape; Caps-Lock-hold + key should
        emit Hyper+key.
     f) (Karabiner upgrade path — Appendix B) If IT adds pqrs.org team
        ID G43BCU2T37 to the MDM System Extensions allow-list, run:
          DESKTOP_LAYER2_USE_KARABINER=true bash install-macos.sh
        or, for an already-installed machine:
          bash scripts/desktop-layer2-switch-to-karabiner.sh
     g) Launch Raycast from ~/Applications/Raycast.app. First launch
        prompts for Accessibility — grant in the same JIT-admin window
        as AeroSpace/skhd/Hammerspoon. Prefs: Start at login on,
        Cmd+Space hotkey, Pop to root on, Auto-switch input source off.
        Do NOT sign in. See raycast/extensions.md for the 8-step
        post-install checklist and the 7-extension curated list.
     h) (Corporate Mac — optional) Within the same JIT admin window,
        null Raycast sync endpoints via /etc/hosts (defense in depth
        on top of the no-sign-in rule):
          sudo tee -a /etc/hosts >/dev/null <<EOF_HOSTS
          0.0.0.0  backend.raycast.com
          0.0.0.0  api.raycast.com
          0.0.0.0  sync.raycast.com
          EOF_HOSTS
     i) Walk docs/manual-smoke/desktop-layer{1,2,3}.md at your cadence.
  8. Raycast — Dracula Pro theme (Wave A Tier 1):
     Open this URL in a macOS browser to import the "Dracula PRO - Pro" theme
     into Raycast, then set it in Raycast Preferences -> Appearance -> Theme:
       https://themes.ray.so?version=1&name=Dracula%20PRO%20-%20Pro&author=Lucas%20de%20Fran%C3%A7a&authorUsername=luxonauta&colors=%2322212C,%2322212C,%23F8F8F2,%237970A9,%23454158,%23FFA680,%23FFCA80,%23FFFF80,%238AFF80,%2380FFEA,%239580FF,%23FF80BF&appearance=dark&addToRaycast
     See raycast/dracula-pro.md for variant details and rationale.

Prerequisites NOT installed by this script:
  - Google Cloud SDK (gcloud) — see warnings above if missing. The
    Homebrew cask download is often blocked by corporate proxies.
    Install via your organisation's managed software catalogue before
    using any gcloud-dependent workflows.

If install-macos.sh --restore is needed, backups are in:
  $HOME/.dotfiles-backup/
EOF
