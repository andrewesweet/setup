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
printf "  (no config files to link yet — added by later plans)\n"

# ── Step 4: Next steps ───────────────────────────────────────────────────────
log "install complete"
cat <<EOF

Next steps:
  1. Switch shell to Homebrew bash 5:
       echo "$HOMEBREW_PREFIX/bin/bash" | sudo tee -a /etc/shells
       chsh -s $HOMEBREW_PREFIX/bin/bash
  2. Install fzf shell bindings (one-time, interactive):
       $HOMEBREW_PREFIX/opt/fzf/install --all --no-update-rc
  3. Authenticate tools:
       opencode auth login   # select GitHub Copilot
       gh auth login
       gcloud auth login     # only if gcloud is installed (see prerequisites)
  4. Restart terminal.

Prerequisites NOT installed by this script:
  - Google Cloud SDK (gcloud) — see warnings above if missing. The
    Homebrew cask download is often blocked by corporate proxies.
    Install via your organisation's managed software catalogue before
    using any gcloud-dependent workflows.

If install-macos.sh --restore is needed, backups are in:
  $HOME/.dotfiles-backup/
EOF
