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

# ── gh_release_install ───────────────────────────────────────────────────
# Download a GitHub release binary and install it into ~/.local/bin.
#
# Usage: gh_release_install <owner/repo> <binary-name> [<asset-pattern>]
#   owner/repo:     e.g. "joshmedeski/sesh"
#   binary-name:    the executable to place in ~/.local/bin (e.g. "sesh")
#   asset-pattern:  optional extra regex to narrow the asset match
#                   (defaults to the arch pattern below)
#
# Idempotent: skips if ~/.local/bin/<binary-name> is already executable.
# This is a coarse idempotency check — for version pinning, delete the
# binary and re-run the installer.
#
# Requires: curl, tar, (optional) jq. Falls back to grep/sed parsing if
# jq is unavailable (which it is during early bootstrap on fresh WSL).
gh_release_install() {
  local repo="$1" binary="$2" extra_pattern="${3:-}"
  local arch os tmp asset url
  mkdir -p "$HOME/.local/bin"

  # Idempotency: already installed.
  if [[ -x "$HOME/.local/bin/$binary" ]] || command -v "$binary" &>/dev/null; then
    printf "  already installed: %s\n" "$binary"
    return 0
  fi

  # Arch detection.
  case "$(uname -m)" in
    x86_64)  arch='x86_64|amd64|x64' ;;
    aarch64|arm64) arch='aarch64|arm64' ;;
    *)       warn "gh_release_install: unsupported arch $(uname -m) for $binary"; return 1 ;;
  esac

  # OS detection.
  case "$(uname -s)" in
    Linux)   os='linux|unknown-linux-(gnu|musl)' ;;
    Darwin)  os='darwin|apple-darwin' ;;
    *)       warn "gh_release_install: unsupported OS $(uname -s)"; return 1 ;;
  esac

  log "fetching latest release metadata: $repo"
  local api="https://api.github.com/repos/$repo/releases/latest"
  local releases_json
  if ! releases_json="$(curl -fsSL "$api" 2>/dev/null)"; then
    warn "gh_release_install: cannot reach GitHub API for $repo"
    return 1
  fi

  # Select a .tar.gz asset matching both arch and os, plus any extra_pattern.
  # Prefer gnu over musl when both exist (glibc on Ubuntu).
  local pattern="($arch).*($os)"
  [[ -n "$extra_pattern" ]] && pattern="$pattern.*$extra_pattern"

  url="$(printf '%s' "$releases_json" \
    | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | sed -E 's/.*"([^"]+)"$/\1/' \
    | grep -E "$pattern" \
    | grep -E '\.tar\.gz$|\.tgz$' \
    | grep -vE 'musl' \
    | head -1)"

  # Fallback: musl-only releases (e.g. some Rust static binaries).
  if [[ -z "$url" ]]; then
    url="$(printf '%s' "$releases_json" \
      | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' \
      | sed -E 's/.*"([^"]+)"$/\1/' \
      | grep -E "$pattern" \
      | grep -E '\.tar\.gz$|\.tgz$' \
      | head -1)"
  fi

  if [[ -z "$url" ]]; then
    warn "gh_release_install: no matching asset found for $repo (arch=$arch os=$os)"
    return 1
  fi

  log "downloading $url"
  tmp="$(mktemp -d)"
  if ! curl -fsSL -o "$tmp/asset.tar.gz" "$url"; then
    warn "gh_release_install: download failed for $url"
    rm -rf "$tmp"
    return 1
  fi

  # Extract and locate the binary. Handles flat archives and subdir archives.
  tar -xzf "$tmp/asset.tar.gz" -C "$tmp"
  asset="$(find "$tmp" -type f -name "$binary" -perm -u+x | head -1)"
  if [[ -z "$asset" ]]; then
    asset="$(find "$tmp" -type f -name "$binary" | head -1)"
  fi
  if [[ -z "$asset" ]]; then
    warn "gh_release_install: binary '$binary' not found in archive for $repo"
    rm -rf "$tmp"
    return 1
  fi

  install -m 0755 "$asset" "$HOME/.local/bin/$binary"
  printf "  installed %s → ~/.local/bin/%s\n" "$binary" "$binary"
  rm -rf "$tmp"
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

# ── Step 1b: TPM (tmux plugin manager) ───────────────────────────────────
# TPM is not in apt. Clone directly; plugins install on first tmux launch
# with `prefix + I` (or continuum auto-restore). Idempotent.
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  log "installing TPM"
  if ! git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"; then
    warn "TPM clone failed — install manually before first tmux launch"
  fi
else
  log "TPM already installed at ~/.tmux/plugins/tpm"
fi

# ── Step 2: GitHub release installs (Layer 1a + 1b-i) ────────────────────
# xh moved here from apt — Ubuntu Jammy (CI image) doesn't ship it; the apt
# package only landed in Noble (24.04). gh_release_install handles both arches.
log "installing release binaries (Layer 1a)"
gh_release_install "atuinsh/atuin"                atuin
gh_release_install "alexpasmantier/television"    tv

log "installing release binaries (Layer 1b-i)"
gh_release_install "ducaale/xh"                   xh
gh_release_install "joshmedeski/sesh"             sesh
gh_release_install "sxyazi/yazi"                  yazi
gh_release_install "MilesCranmer/rip2"            rip2
gh_release_install "noahgorstein/jqp"             jqp
gh_release_install "dlvhdr/diffnav"               diffnav
gh_release_install "rsteube/carapace-bin"         carapace

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

# kitty terminal (Plan 4, Dracula Pro palette added in Layer 1b-ii)
link kitty/kitty.conf        .config/kitty/kitty.conf

# kitty Dracula Pro theme (Wave A Tier 1) — ~/dracula-pro/themes/ ships no
# kitty-native file, so generate one from the palette file at install time.
# Palette hex values are facts (spec § 4.1 — reproduction authorised).
if [[ "${DRACULA_PRO_OK:-0}" == 1 ]]; then
  mkdir -p "$HOME/.config/kitty"
  gen="$HOME/.config/kitty/dracula-pro.generated.conf"
  cat > "$gen" <<KITTYEOF
# AUTO-GENERATED by install-wsl.sh from scripts/lib/dracula-pro-palette.sh
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
# television themes (Wave C Tier 3 — directory symlink so added themes land without re-wire)
link television/themes        .config/television/themes

# yazi (Plan Layer 1b-i)
link yazi/yazi.toml    .config/yazi/yazi.toml
link yazi/keymap.toml  .config/yazi/keymap.toml
link yazi/theme.toml   .config/yazi/theme.toml

# jqp (Plan Layer 1b-i)
link jqp/.jqp.yaml  .jqp.yaml

# diffnav (Plan Layer 1b-i)
link diffnav/config.yml  .config/diffnav/config.yml

# bat themes (Plan theming-wave-c)
# Custom Dracula Pro tmTheme lives under bash/bat-themes/ and is
# symlinked as a directory so adding themes later requires no rewire.
mkdir -p "$HOME/.config/bat/themes"
link bash/bat-themes  .config/bat/themes

# Rebuild bat's theme cache so BAT_THEME="Dracula Pro" resolves.
# Idempotent; bat prints "Writing theme set to ..." on each run.
if command -v bat >/dev/null 2>&1; then
  bat cache --build >/dev/null
  printf "  bat cache --build (Dracula Pro theme registered)\n"
else
  warn "bat not installed — skipping 'bat cache --build'. Run it manually after installing bat."
fi

# btop (Wave C Tier 3) — file-level links so `~/.config/btop/themes/`
# remains a real directory btop can write transient state into.
mkdir -p "$HOME/.config/btop/themes"
link btop/btop.conf           .config/btop/btop.conf
link btop/dracula-pro.theme   .config/btop/themes/dracula-pro.theme

# gh-dash (Plan Layer 1b-iii)
link gh-dash/config.yml  .config/gh-dash/config.yml

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

# ── Wave A Tier 1: Windows Terminal scheme splice ────────────────────────
# Splices ~/dracula-pro/themes/windows-terminal/dracula-pro.json into
# Windows Terminal's schemes[] array. Idempotent via .name == "Dracula Pro".
# See macos-dev/docs/design/theming.md § 4.2.
if [[ "${DRACULA_PRO_OK:-0}" == 1 ]]; then
  wt_scheme_src="$HOME/dracula-pro/themes/windows-terminal/dracula-pro.json"
  wt_settings_glob="/mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json"
  # shellcheck disable=SC2086
  wt_settings="$(compgen -G $wt_settings_glob 2>/dev/null | head -n1 || true)"

  if [[ -z "$wt_settings" ]]; then
    warn "Windows Terminal settings.json not found — copy manually from $wt_scheme_src"
  elif ! command -v jq &>/dev/null; then
    warn "jq not on PATH — install jq (apt install -y jq) then rerun install-wsl.sh"
    warn "Windows Terminal settings.json not found (skipped splice: no jq)"
  elif [[ ! -f "$wt_scheme_src" ]]; then
    warn "Dracula Pro WT scheme not found at $wt_scheme_src — skipping WT splice"
  else
    log "splicing Dracula Pro scheme into $wt_settings"
    tmp="$(mktemp)"
    # Remove any existing "Dracula Pro" scheme, then append the fresh one.
    jq --slurpfile new "$wt_scheme_src" '.schemes = ((.schemes // []) | map(select(.name != "Dracula Pro"))) + $new' "$wt_settings" > "$tmp"
    # Back up once per day; never overwrite an existing backup.
    bak="${wt_settings}.bak.$(date +%Y%m%d)"
    [[ -f "$bak" ]] || cp "$wt_settings" "$bak"
    cp "$tmp" "$wt_settings"
    rm -f "$tmp"
    printf "  spliced   %s\n" "$wt_settings"
  fi
else
  warn "DRACULA_PRO_OK=0 — skipping Windows Terminal scheme splice"
fi

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
  4. Layer 1b-ii tmux plugins (first tmux launch):
       Inside tmux, press \`prefix + I\` (Ctrl-A then Shift-I) to install plugins.
       Note: tmux-thumbs compiles from source and requires a Rust toolchain.
       If compilation fails (common on stripped WSL images), install pre-built
       binary from https://github.com/fcsonline/tmux-thumbs/releases and drop
       it at ~/.tmux/plugins/tmux-thumbs/target/release/tmux-thumbs.

If install-wsl.sh --restore is needed, backups are in:
  $HOME/.dotfiles-backup/
EOF
