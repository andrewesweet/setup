# Terminal — Kitty, tmux, Starship

This design specification defines the terminal configuration for dotfiles across macOS and WSL2. All three core components—Kitty, tmux, and Starship—are shared across platforms with container inheritance from host terminal.

## Overview

- **Kitty**: Terminal emulator with shared configuration across macOS and WSL2 (via WSLg)
- **tmux**: Terminal multiplexer with vi-mode navigation and cross-platform clipboard
- **Starship**: Prompt configuration with git integration and language version displays
- **Container**: Inherits terminal from host environment

## Kitty Configuration

### Font and Display

- Font family: JetBrains Mono
- Font size: 13.0 points
- `shell_integration` MUST be enabled
- `scrollback_lines` SHOULD be set to 10000

### Audio and Visual Feedback

- `enable_audio_bell` SHOULD be disabled (no)
- `visual_bell_duration` SHOULD be 0
- `window_alert_on_bell` SHOULD be disabled (no)
- `confirm_os_window_close` SHOULD be set to 0 (close without confirmation)

### Selection and Clipboard

- `copy_on_select` SHOULD be set to clipboard (auto-copy on selection)

Note: On WSL2 via WSLg, `copy_on_select` copies to the Wayland clipboard, not the Windows system clipboard. For reliable cross-environment clipboard access (e.g., copying from container to host), use OSC 52 via tmux with `set -s set-clipboard on` instead.

### Key Bindings

Kitty key bindings MUST be configured as follows:

| Binding | Action |
|---------|--------|
| Ctrl+Shift+T | New tab with current working directory |
| Ctrl+Shift+N | New window with current working directory |
| Ctrl+Shift+Right | Navigate to next tab |
| Ctrl+Shift+Left | Navigate to previous tab |
| Ctrl+Shift+H | Open scrollback buffer |
| Ctrl+Shift+Equal | Increase font size |
| Ctrl+Shift+Minus | Decrease font size |
| Ctrl+Shift+0 | Reset font size to default |

### Integration with tmux

When tmux is active, Kitty acts as a dumb terminal. Users MUST use tmux bindings for window/pane operations rather than Kitty's native bindings. Kitty's terminal integration (tabs, new windows) is available only when tmux is not running.

## tmux Configuration

### Session and Server Settings

- Prefix key: Ctrl+A (unbind default Ctrl+B)
- Default terminal: tmux-256color
- Terminal overrides MUST include RGB support for Kitty
- `escape-time` MUST be set to 10 milliseconds
- `history-limit` MUST be set to 50000 lines
- `mouse` MUST be enabled (on)
- `base-index` MUST be set to 1 (not 0)
- `pane-base-index` MUST be set to 1 (not 0)
- `renumber-windows` MUST be enabled (on)

### Split Navigation and Creation

- Vertical split: prefix + | (pipe)
- Horizontal split: prefix + - (hyphen)
- New splits MUST preserve the current working directory

### Pane Navigation

- Prefix + h: move to left pane
- Prefix + j: move to down pane
- Prefix + k: move to up pane
- Prefix + l: move to right pane

Navigation bindings use vi keys and integrate with vim-tmux-navigator (see section below).

### Pane Resizing

- Prefix + H: resize pane left by 5 units (repeatable)
- Prefix + J: resize pane down by 5 units (repeatable)
- Prefix + K: resize pane up by 5 units (repeatable)

Note: `prefix + L` is bound to `last-window` (see Known Friction Points below). To resize right, use `prefix + Right` arrow instead with `bind -r Right resize-pane -R 5`.

### Copy Mode

Copy mode MUST use vi key bindings:

- Prefix + Enter: enter copy mode
- v: begin selection
- y: copy selection and exit copy mode (via copy-selection-and-cancel)
- Escape: cancel copy mode without copying

**Clipboard Integration (CRITICAL):**
- `set -s set-clipboard on` MUST be configured
- Copy operations MUST use OSC 52 escape sequences
- MUST NOT use pbcopy or platform-specific clipboard commands
- OSC 52 ensures cross-platform clipboard support for Kitty and Windows Terminal
- This configuration is REQUIRED for WSL2 clipboard functionality

### Session and Config Management

- Prefix + s: choose-session (interactive session switcher)
- Prefix + r: reload configuration file

### Status Bar Configuration

Status bar MUST be positioned at bottom with the following settings:

- Background color: #1e1e2e
- Foreground color: #cdd6f4
- Left side: session name
- Right side: time and date
- Current window: bold, blue (#89b4fa), visually distinct from other windows

### vim-tmux-navigator Integration

The following bindings MUST be configured to enable seamless vim-tmux pane navigation:

```conf
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"
bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'
```

These bindings enable Ctrl+h/j/k/l to move between vim windows and tmux panes transparently.

#### Platform Compatibility Note

The `is_vim` detection uses BSD `ps` flags. On WSL2 or in containers, procps `ps` MAY behave differently. Implementers SHOULD test navigation on all platforms. If vim-tmux-navigator fails, implementers SHOULD fall back to `pgrep`-based detection. Containerfile MUST install `procps` package.

### Known Friction Points and Workarounds

#### Ctrl+L Clear Screen (Workaround Required)

Ctrl+L is consumed by the vim-tmux-navigator binding. To clear screen in tmux:

```conf
bind C-l send-keys C-l
```

This configuration allows `prefix + Ctrl+L` to send Ctrl+L to the current pane, clearing the screen.

#### Last Window Navigation

The vim-tmux-navigator bindings repurpose `prefix + l` for left pane navigation, removing the default last-window behavior. Restore this functionality:

```conf
bind L last-window
```

Use `prefix + Shift+L` to return to the previously active window.

## Starship Configuration

Starship MUST be configured with the following prompt format and module settings:

### Prompt Format

```toml
format = """
$directory\
$git_branch\
$git_status\
$kubernetes\
$nodejs$python$golang$terraform\
$cmd_duration\
$line_break\
$character"""

scan_timeout = 30
```

The prompt displays directory, git information, detected language versions, command duration, and character indicator on separate lines.

### Directory Module

```toml
[directory]
truncation_length = 4
truncate_to_repo  = true
style             = "bold blue"
```

- Truncates to 4 path segments
- Truncates further when inside git repository
- Displayed in bold blue

### Git Branch Module

```toml
[git_branch]
symbol = " "
style  = "bold purple"
```

- Uses Git icon symbol
- Displayed in bold purple

### Git Status Module

```toml
[git_status]
conflicted = "⚡"
ahead      = "↑${count}"
behind     = "↓${count}"
diverged   = "⇕"
modified   = "*"
staged     = "+"
untracked  = "?"
stashed    = "$"
```

Status indicators for merge conflicts, commit divergence, modified files, staged changes, untracked files, and stashed changes.

### Character Module

```toml
[character]
vicmd_symbol   = "[N](bold green) "
success_symbol = "[I](bold yellow) "
error_symbol   = "[I](bold red) "
```

- Normal/command mode: bold green "N"
- Success (exit code 0): bold yellow "I"
- Error (non-zero exit): bold red "I"

**Note:** `vimins_symbol` is NOT a valid Starship configuration key and MUST NOT be included.

### Command Duration Module

```toml
[cmd_duration]
min_time = 2000
format   = " [$duration](yellow)"
```

Shows command execution time in yellow when duration exceeds 2000 milliseconds (2 seconds).

### Language Version Modules

#### Node.js

```toml
[nodejs]
format = "[ $version](green) "
detect_files = ["package.json", ".nvmrc"]
```

#### Python

```toml
[python]
format = "[ $version](yellow) "
```

#### Go

```toml
[golang]
format = "[ $version](cyan) "
```

#### Kubernetes

```toml
[kubernetes]
format = "[⎈ $context](blue) "
```

#### Terraform

```toml
[terraform]
format = "[ $version](purple) "
```

Language version indicators are displayed when tools are detected in the working directory.

## Keybinding Reference

### Kitty Shortcuts

| Binding | Action |
|---------|--------|
| Ctrl+Shift+T | New tab with current directory |
| Ctrl+Shift+N | New window with current directory |
| Ctrl+Shift+Right | Next tab |
| Ctrl+Shift+Left | Previous tab |
| Ctrl+Shift+H | Open scrollback buffer |
| Ctrl+Shift+Equal | Increase font size |
| Ctrl+Shift+Minus | Decrease font size |
| Ctrl+Shift+0 | Reset font size |

### tmux Prefix Actions

| Binding | Action |
|---------|--------|
| prefix + \| | Vertical split (preserve cwd) |
| prefix + - | Horizontal split (preserve cwd) |
| prefix + h | Move to left pane |
| prefix + j | Move to down pane |
| prefix + k | Move to up pane |
| prefix + l | Move to right pane |
| prefix + H | Resize pane left (5 units, repeatable) |
| prefix + J | Resize pane down (5 units, repeatable) |
| prefix + K | Resize pane up (5 units, repeatable) |
| prefix + Right | Resize pane right (5 units, repeatable) |
| prefix + s | Choose session |
| prefix + r | Reload configuration |
| prefix + Shift+L | Last window |
| prefix + Ctrl+L | Clear screen in current pane |

### tmux Copy Mode

| Binding | Action |
|---------|--------|
| prefix + Enter | Enter copy mode |
| v | Begin selection |
| y | Copy selection and exit (copy-selection-and-cancel) |
| Escape | Cancel copy mode |

### vim-tmux-navigator (Without prefix)

| Binding | Action |
|---------|--------|
| Ctrl+h | Move to left pane (or vim left window) |
| Ctrl+j | Move to down pane (or vim down window) |
| Ctrl+k | Move to up pane (or vim up window) |
| Ctrl+l | Move to right pane (or vim right window) |

**Friction Point:** `Ctrl+l` typically clears screen but is consumed by navigator. Use `prefix + Ctrl+L` as workaround.

### Known Friction Points

| Issue | Workaround |
|-------|-----------|
| Ctrl+L consumed by navigator | Use `prefix + Ctrl+L` to clear screen |
| Ctrl+A double-tap for OpenCode | Reserved; use prefix binding for other commands |
| vim-tmux-navigator on WSL2 | Test and fallback to pgrep if ps detection fails |
| Delta n/N for next/prev hunk | In diff tools, conflicts with vim keybinds; use arrow keys or custom binding |

## Platform Compatibility

- **macOS**: Native Kitty, tmux, Starship
- **WSL2**: Kitty via WSLg, tmux, Starship
- **Containers**: Inherits terminal configuration from host; Containerfile MUST install `procps` for vim-tmux-navigator compatibility

All configurations are shared across platforms with no platform-specific overrides required.

## Implementation Requirements

1. Kitty MUST use JetBrains Mono 13.0 with shell_integration enabled
2. tmux MUST bind Ctrl+A as prefix and disable default Ctrl+B
3. `set -s set-clipboard on` MUST be configured for OSC 52 clipboard
4. vim-tmux-navigator SHOULD be tested on all platforms; fallback to pgrep on WSL2 if needed
5. Starship prompt format MUST match the specified format string exactly
6. Container implementations MUST install procps for ps-based vim-tmux-navigator detection
7. Workarounds for Ctrl+L and last-window MUST be included in tmux configuration
