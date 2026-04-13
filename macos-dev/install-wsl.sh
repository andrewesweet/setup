#!/usr/bin/env bash
# install-wsl.sh — install dotfiles on WSL2 Ubuntu
#
# This script:
#   1. Self-resolves DOTFILES from its own location
#   2. Verifies we are on WSL2 Ubuntu
#   3. Runs apt install for basic tools
#   4. Installs scripts for tools not in apt (starship, mise, uv, etc.)
#      — STUBBED in this plan; later plans fill in the exact install commands
#   5. Installs post-bootstrap tools: uv tools (ty, prek), bun global
#      (opencode, critique)
#   6. Symlinks configuration files (deferred — no configs exist yet)
#
# Usage:
#   bash install-wsl.sh             # fresh install
#   bash install-wsl.sh --restore   # uninstall: restore from latest backup
#
# Idempotent: re-running is safe.

set -uo pipefail

# ── Self-resolve DOTFILES ────────────────────────────────────────────────────
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

# ── link() helper (identical to install-macos.sh) ────────────────────────────
link() {
  local src_rel="$1" dst_rel="$2"
  local src="$DOTFILES/$src_rel"
  local dst="$HOME/$dst_rel"

  if [[ ! -e "$src" ]]; then
    warn "source missing, skipping: $src"
    return 0
  fi

  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    printf "  unchanged %s\n" "$dst"
    return 0
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$dst_rel")"
    mv "$dst" "$BACKUP_DIR/$dst_rel"
    printf "  backed up %s → %s\n" "$dst" "$BACKUP_DIR/$dst_rel"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
  printf "  linked    %s\n" "$dst"
}

# Precondition: $HOME must be on a native Linux filesystem (ext4), not on
# /mnt/c/ (9P bridge to Windows — ~10× slower, kills git perf on ghq tree).
check_home_on_ext4() {
  local home_real
  home_real="$(readlink -f "$HOME" 2>/dev/null || echo "$HOME")"
  case "$home_real" in
    /mnt/[a-zA-Z]/*)
      err "HOME ($home_real) is on a 9P-mounted Windows path."
      err "ghq tree (~/code) would be crippling slow here."
      err "Move your Linux home to ext4 before running this installer."
      err "See: docs/plans/2026-04-12-shell-modernisation-design.md § 3.11.6"
      return 1
      ;;
  esac
  return 0
}

# ── restore() (identical to install-macos.sh) ────────────────────────────────
restore() {
  if [[ ! -d "$HOME/.dotfiles-backup" ]]; then
    err "no backup directory found at $HOME/.dotfiles-backup/"
    exit 1
  fi

  # Use find -type d so a stray file in ~/.dotfiles-backup/ doesn't get
  # picked as "latest backup" and silently break restore.
  local latest
  latest="$(find "$HOME/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r | head -n1)"
  latest="${latest##*/}"
  if [[ -z "$latest" ]]; then
    err "no backups found in $HOME/.dotfiles-backup/"
    exit 1
  fi

  local backup="$HOME/.dotfiles-backup/$latest"
  log "restoring from $backup"

  # See install-macos.sh for the \( ... \) grouping rationale.
  (cd "$backup" && find . \( -type f -o -type l \) -print) | while IFS= read -r rel; do
    rel="${rel#./}"
    local dst="$HOME/$rel"
    if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$DOTFILES"/* ]]; then
      rm "$dst"
    fi
    mkdir -p "$(dirname "$dst")"
    cp -a "$backup/$rel" "$dst"
    printf "  restored %s\n" "$dst"
  done

  log "restore complete"
}

# ── Main ─────────────────────────────────────────────────────────────────────

# Print DOTFILES resolution result up front for the self-resolution test.
log "DOTFILES=$DOTFILES"

# Handle --check-preconditions flag: run the check and exit without installing
if [[ "${1:-}" == "--check-preconditions" ]]; then
  check_home_on_ext4 || exit 1
  log "preconditions OK"
  exit 0
fi

# Normal install path also runs the precondition early
check_home_on_ext4 || exit 1

if [[ "$MODE" == "restore" ]]; then
  restore
  exit 0
fi

# Verify we're on WSL2 or native Linux
if [[ "$(uname)" != "Linux" ]]; then
  err "install-wsl.sh is for WSL2/Linux. On macOS, use install-macos.sh."
  exit 1
fi

# WSL_DISTRO_NAME is set automatically inside WSL2. Native Linux is also
# supported (the install steps work identically). The check below is a
# soft warning rather than a hard exit because native Linux is a valid
# target — if you're on Ubuntu/Debian without WSL, this script still works.
if [[ -z "${WSL_DISTRO_NAME:-}" ]]; then
  warn "WSL_DISTRO_NAME not set — assuming native Linux (proceeding anyway)"
fi

# ── Step 1: apt install ──────────────────────────────────────────────────────
# Only tools that are acceptably up-to-date in Ubuntu apt go here.
# Stale or missing tools are installed via GitHub releases in step 2.
log "apt update + install"
if ! sudo apt update; then
  err "apt update failed — aborting install"
  err "check that you have passwordless sudo or run interactively"
  exit 1
fi
if ! sudo apt install -y \
  bash bash-completion \
  git tmux tree wget curl \
  jq \
  shellcheck \
  direnv; then
  err "apt install failed — aborting install"
  exit 1
fi

# ── Step 2: GitHub release / install script installs ─────────────────────────
# STUBBED: this plan creates the skeleton only. Later plans add:
#   - fzf (>= 0.48, from github.com/junegunn/fzf releases)
#   - starship, mise, uv, zoxide, bat, delta, fd, ripgrep
#   - lazygit, btop, lnav, glow, neovim
#   - bun, podman, gcloud SDK, codeql, typst, pandoc
#   - atuin (no apt — installer at https://setup.atuin.sh)              [Layer 1a]
#   - television (no apt — github.com/alexpasmantier/television releases) [Layer 1a]
warn "step 2 (GitHub releases) is stubbed — later plans add tool installs"
warn "atuin/television not installed: install manually until WSL tool installer is built"
warn "  atuin:      bash <(curl -fsSL https://setup.atuin.sh)"
warn "  television: see github.com/alexpasmantier/television/releases (binary is 'tv')"

# ── Step 3: Post-bootstrap tool installs ─────────────────────────────────────
if command -v uv &>/dev/null; then
  log "installing uv tools (ty, prek)"
  uv tool install ty@latest || warn "ty install failed"
  uv tool install prek       || warn "prek install failed"
else
  warn "uv not available, skipping uv tool installs (added in later plan)"
fi

if command -v bun &>/dev/null; then
  log "installing bun global packages (opencode-ai, critique)"
  bun install -g opencode-ai critique || warn "bun global install failed"
else
  warn "bun not available, skipping (added in later plan)"
fi

# ── Step 4: Symlink configs (deferred) ───────────────────────────────────────
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

# kitty terminal (Plan 4)
link kitty/kitty.conf  .config/kitty/kitty.conf

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

# yazi (Plan Layer 1b-i)
link yazi/yazi.toml    .config/yazi/yazi.toml
link yazi/keymap.toml  .config/yazi/keymap.toml
link yazi/theme.toml   .config/yazi/theme.toml

# jqp (Plan Layer 1b-i)
link jqp/.jqp.yaml  .jqp.yaml

# opencode (Plan 9)
link opencode/opencode.jsonc                    .config/opencode/opencode.jsonc
link opencode/tui.jsonc                         .config/opencode/tui.jsonc
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

# vscode (Plan 12) — WSL settings path
link vscode/settings.json    .vscode-server/data/Machine/settings.json
link vscode/extensions.json  .vscode-server/data/Machine/extensions.json

# container dev script (Plan 13)
mkdir -p "$HOME/.local/bin"
link container/dev.sh  .local/bin/dev

# ── Step 5: Next steps ───────────────────────────────────────────────────────
log "install complete"
cat <<EOF

Next steps:
  1. Restart your shell.
  2. Create ~/.gitconfig.local with your identity:
       git config --file ~/.gitconfig.local user.name "Your Name"
       git config --file ~/.gitconfig.local user.email "you@example.com"
  3. Authenticate tools (once bun/opencode are available in a later plan):
       opencode auth login
       gh auth login
       gcloud auth login

Layer 1a tools (manual install on WSL2 — automated in a later plan):
  atuin:      bash <(curl -fsSL https://setup.atuin.sh)
  television: download from https://github.com/alexpasmantier/television/releases
              (binary name is 'tv')

If install-wsl.sh --restore is needed, backups are in:
  $HOME/.dotfiles-backup/
EOF
