# Cross-platform support — macOS, WSL2, container

Extends all prior design documents. Covers the changes needed to make
one set of dotfile configs work across macOS, WSL2 Ubuntu, and the
Wolfi container.

---

## Platforms

| Platform | Package manager | Terminal | Install script |
|----------|----------------|----------|---------------|
| macOS (Apple Silicon) | Homebrew | Kitty | `install-macos.sh` |
| WSL2 (Ubuntu on Windows 11) | apt + install scripts | Kitty via WSLg (primary), Windows Terminal (fallback) | `install-wsl.sh` |
| Container (Wolfi) | apk (build-time only) | inherited from host | N/A (configs baked into image) |

The macOS host, WSL2 environment, and container are all first-class.
The container is an opt-in addition, not a replacement for host-native
work. You can work on the host, in a container, or both simultaneously.

---

## Platform detection

A single check near the top of `.bashrc`:

```bash
case "$OSTYPE" in
  darwin*)  _OS=macos ;;
  linux*)
    if [[ -n "$WSL_DISTRO_NAME" ]]; then
      _OS=wsl
    else
      _OS=linux
    fi
    ;;
esac
```

Three contexts:
- `macos` — Homebrew, native Kitty
- `wsl` — apt-based, Kitty via WSLg or Windows Terminal
- `linux` — inside the container (everything pre-installed)

---

## What needs platform guards

### Homebrew prefix (macOS only)

Homebrew is not always at `/opt/homebrew`. Detect dynamically:

```bash
if [[ $_OS == macos ]]; then
  HOMEBREW_PREFIX="$(brew --prefix)"
  export PATH="$HOMEBREW_PREFIX/bin:$PATH"
  [[ -r "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh" ]] && \
    source "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
fi
```

### bash-completion (platform-specific paths)

```bash
if [[ $_OS == macos ]]; then
  # handled by HOMEBREW_PREFIX block above
  :
elif [[ $_OS == wsl || $_OS == linux ]]; then
  [[ -r /usr/share/bash-completion/bash_completion ]] && \
    source /usr/share/bash-completion/bash_completion
fi
```

### Shell evals (guard against missing tools)

All shell evals must be guarded so partial installs don't break the
shell:

```bash
command -v fzf      &>/dev/null && eval "$(fzf --bash)"
command -v zoxide   &>/dev/null && eval "$(zoxide init bash)"
command -v starship &>/dev/null && eval "$(starship init bash)"
command -v mise     &>/dev/null && eval "$(mise activate bash)"
command -v direnv   &>/dev/null && eval "$(direnv hook bash)"
command -v gh       &>/dev/null && eval "$(gh completion -s bash)"
```

Additional completions to add:

```bash
command -v mise &>/dev/null && eval "$(mise completion bash)"
command -v uv   &>/dev/null && eval "$(uv generate-shell-completion bash)"
```

### `ports` alias (platform-specific)

```bash
if [[ $_OS == macos ]]; then
  alias ports='lsof -i -P -n | rg LISTEN'
else
  alias ports='ss -tlnp'
fi
```

### Notifications (OSC 9 — works everywhere)

`terminal-notifier` is removed from the stack. Notifications use
OSC 9 escape sequences, which work in Kitty on macOS, Kitty on WSLg,
Windows Terminal, and pass through tmux from inside containers.

```bash
NOTIFY_THRESHOLD="${NOTIFY_THRESHOLD:-10}"

__cmd_timer_start() {
  __cmd_start=${__cmd_start:-$SECONDS}
}

__cmd_timer_notify() {
  local last_exit=$?
  local duration=$(( SECONDS - ${__cmd_start:-$SECONDS} ))
  unset __cmd_start
  if (( duration >= NOTIFY_THRESHOLD )); then
    printf '\e]9;Command finished — took %ds (exit %d)\a' \
      "$duration" "$last_exit"
  fi
}

trap '__cmd_timer_start' DEBUG
PROMPT_COMMAND="__cmd_timer_notify;${PROMPT_COMMAND}"
```

Default threshold: 10 seconds. Override with
`export NOTIFY_THRESHOLD=30`.

### Clipboard in tmux

Drop `pbcopy` entirely. Rely on `set -s set-clipboard on` (OSC 52)
for all platforms. Kitty and Windows Terminal both support OSC 52
natively. Works through tmux and from inside containers.

tmux copy mode binding becomes:

```conf
bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel
```

No platform guard needed — same config everywhere.

### `EDITOR` and `MANPAGER` (conditional)

```bash
if command -v nvim &>/dev/null; then
  export EDITOR='nvim'
  export VISUAL='nvim'
  export MANPAGER='nvim +Man!'
else
  export EDITOR='code --wait'
  export VISUAL="$EDITOR"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
```

### git config — no hardcoded editor

Remove `editor = code --wait` from `.gitconfig`. Git falls back to
`$EDITOR` automatically. This ensures the gitconfig is
platform-agnostic.

---

## What works everywhere without guards

| Tool/Config | Notes |
|-------------|-------|
| Starship prompt | Cross-platform Rust binary |
| fzf + fd integration | Same config, same binaries |
| zoxide | Same config |
| lazygit + delta | Same config, delta syntax-theme explicit |
| tmux (vi copy mode) | OSC 52 clipboard, no platform-specific commands |
| Kitty config | Shared across macOS and WSL2 |
| Neovim + LazyVim | Same lua config tree |
| OpenCode config | Same jsonc, same instruction files |
| mise, uv, prek | Same config |
| Git aliases | Same gitconfig (minus editor line) |
| OSC 9 notifications | Works in all terminals |
| Container `dev` script | Works on macOS and WSL2 (Podman on both) |

---

## Install scripts

### `install-macos.sh`

1. Back up existing config files to `~/.dotfiles-backup/<timestamp>/`
   (only files that exist and are not already symlinks to this repo)
2. Detect `HOMEBREW_PREFIX` dynamically
3. `brew bundle` for all tools (includes gcloud SDK, codeql, VS Code)
4. `brew install charmbracelet/tap/freeze` (from tap)
5. `gcloud components install alpha beta bq gke-gcloud-auth-plugin
   pubsub-emulator cloud-datastore-emulator cloud-firestore-emulator
   cloud-build-local bigtable spanner-emulator`
6. `uv tool install ty@latest && uv tool install prek`
7. `bun install -g opencode-ai critique`
8. Symlink all configs into place (including `.inputrc`, VS Code
   settings, VS Code extensions.json)
9. Symlink `container/dev.sh` to `~/.local/bin/dev`
10. Verify: run `bash -n` on all bash config files

### `install-wsl.sh`

1. Back up existing config files (same pattern as macOS)
2. `sudo apt install` for tools in Ubuntu repos
3. Install scripts for tools not in apt or stale:
   starship, mise, uv, fzf (>= 0.48, from GitHub releases), zoxide,
   bat, delta, fd, ripgrep, lazygit, btop, lnav, glow, neovim,
   kitty, bun, podman, gcloud SDK, codeql
4. `gcloud components install` (same list as macOS)
5. `uv tool install ty@latest && uv tool install prek`
6. `bun install -g opencode-ai critique`
7. Same symlink logic as macOS
8. Symlink VS Code settings to `~/.vscode-server/data/Machine/settings.json`
9. Optional: create Kitty WSLg desktop entry for Windows Start menu

### Preventing install script drift

Maintain a `tools.txt` manifest listing all tool names. A validation
script checks that both install scripts and the Containerfile
reference every tool in the manifest.

---

## WSL2-specific notes

### Kitty on WSL2

Kitty runs as a Wayland app via WSLg. Launch from Windows:

```
wsl --exec kitty
```

Or create a Windows shortcut. Same `kitty.conf` as macOS.

Fallback to Windows Terminal if WSLg has issues. OSC 52 and OSC 9
work in both.

### Filesystem performance

Repos must live under `~/` (ext4), never `/mnt/c` (NTFS via 9P).
Git operations on `/mnt/c` are 5-10x slower. The WSL onboarding
docs should warn about this.

### SSH agent

If using Windows OpenSSH agent, a `socat` relay is needed to forward
the agent socket into WSL2. Document this in onboarding. If using
WSL-native `ssh-agent`, no special handling needed.

### Podman

Native on Ubuntu — no VM needed (unlike macOS where Podman Machine
runs a Linux VM). The `dev` script works identically.

---

## Dotfile changes summary

### Removed from stack

- `terminal-notifier` — replaced by OSC 9

### New files

| File | Purpose |
|------|---------|
| `install-wsl.sh` | WSL2 Ubuntu install script |
| `tools.txt` | Shared tool manifest |

### Renamed files

| From | To |
|------|-----|
| `install.sh` | `install-macos.sh` |

### Modified files

| File | Change |
|------|--------|
| `.bashrc` | `_OS` guard, dynamic `HOMEBREW_PREFIX`, guarded evals, conditional `EDITOR`/`MANPAGER`, OSC 9 notification (after starship init), mise/uv/cog/git-cliff completions, `~/.bun/bin` on PATH, `~/.bashrc.local` sourcing |
| `.bash_aliases` | Conditional `ports` and `port` aliases |
| `.tmux.conf` | Replace `pbcopy` with `copy-selection-and-cancel` |
| `.gitconfig` | Remove `editor` line |
| `Brewfile` | Add `podman`, `google-cloud-sdk`, `cloud-sql-proxy`, `codeql`, `markdownlint-cli2`, `pandoc`, `cask "visual-studio-code"`, `tap "charmbracelet/tap"`. Remove `terminal-notifier`. |
