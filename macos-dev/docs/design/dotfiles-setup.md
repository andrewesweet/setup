# CLI/TUI Developer Environment — macOS + Bash 5 + Kitty

A cohesive, team-shareable setup tying together the full tool stack.
Keybinding philosophy: **vi-style throughout** — one scheme to learn, transfers
across lazygit, btop, lnav, tmux, and the shell itself.

---

## 0. Dotfiles repo structure

Commit this entire setup to a repo (e.g. `~/.dotfiles`) and share it with
your team. The `install.sh` symlinks everything into place.

```
~/.dotfiles/
├── Brewfile                  # reproducible installs
├── install.sh                # symlinks all configs
├── bash/
│   ├── .bash_profile         # login shell entry point
│   ├── .bashrc               # interactive shell config
│   └── .bash_aliases         # all aliases
├── git/
│   ├── .gitconfig
│   └── .gitignore_global
├── kitty/
│   └── kitty.conf
├── tmux/
│   └── .tmux.conf
├── starship/
│   └── starship.toml
└── lazygit/
    └── config.yml
```

### install.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$HOME/.dotfiles"

link() {
  local src="$DOTFILES/$1" dst="$HOME/$2"
  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
  echo "  linked $dst"
}

echo "Linking dotfiles..."
link bash/.bash_profile      .bash_profile
link bash/.bashrc             .bashrc
link bash/.bash_aliases       .bash_aliases
link git/.gitconfig           .gitconfig
link git/.gitignore_global    .gitignore_global
link tmux/.tmux.conf          .tmux.conf
link kitty/kitty.conf         .config/kitty/kitty.conf
link starship/starship.toml   .config/starship.toml
link lazygit/config.yml       .config/lazygit/config.yml

echo "Done. Restart your shell."
```

---

## 1. Brewfile — reproducible installs

```ruby
# Brewfile — commit this, share with your team
# Usage: brew bundle

tap "homebrew/bundle"

# Shell
brew "bash"                  # bash 5 (macOS ships with 3.2)
brew "bash-completion@2"     # completion framework for bash 5
brew "starship"              # cross-shell prompt

# Git core
brew "git"
brew "git-delta"             # diff pager
brew "difftastic"            # structural/AST diff tool
brew "lazygit"               # git TUI
brew "git-cliff"             # changelog generator
brew "cocogitto"             # conventional commits + semver
brew "gh"                    # GitHub CLI

# Navigation & search
brew "fzf"                   # fuzzy finder (history, files, processes)
brew "zoxide"                # smart cd with frecency
brew "fd"                    # fast find replacement
brew "ripgrep"               # fast grep replacement

# File viewing
brew "bat"                   # cat with syntax highlighting
brew "glow"                  # markdown renderer
brew "lnav"                  # log file TUI

# Process monitoring
brew "btop"                  # top/htop replacement

# Terminal multiplexer
brew "tmux"

# Data wrangling
brew "jq"                    # JSON processor
brew "yq"                    # YAML/TOML processor (same syntax as jq)
brew "miller"                # CSV/TSV processor
brew "httpie"                # human-friendly HTTP client

# Utilities
brew "tree"                  # directory tree view
brew "wget"
```

Install everything: `brew bundle --file=~/.dotfiles/Brewfile`

---

## 2. Bash config

### .bash_profile

```bash
# .bash_profile — login shell entry point
# On macOS, login shells source .bash_profile, not .bashrc.
# We keep all config in .bashrc and just source it here.

[[ -f "$HOME/.bashrc" ]] && source "$HOME/.bashrc"
```

### .bashrc

```bash
# .bashrc — interactive shell configuration

# ─── Guard: only run for interactive shells ───────────────────────────────────
[[ $- != *i* ]] && return

# ─── Bash 5 (Homebrew) ────────────────────────────────────────────────────────
# Ensure we're running Homebrew bash 5, not macOS system bash 3.2
# Add /opt/homebrew/bin/bash to /etc/shells and run:
#   chsh -s /opt/homebrew/bin/bash
# to make this permanent.

# ─── Completion ───────────────────────────────────────────────────────────────
# bash-completion@2 (required for bash 5)
[[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] && \
  source "/opt/homebrew/etc/profile.d/bash_completion.sh"

# gh CLI completion
eval "$(gh completion -s bash)"

# ─── Vi mode ──────────────────────────────────────────────────────────────────
# Single keybinding scheme across shell + all TUIs.
# Esc enters normal mode (hjkl navigation, w/b word movement, etc.)
set -o vi

# Restore Ctrl+L (clear screen) in both modes — muscle memory from GUI terminals
bind -m vi-insert 'Control-l: clear-screen'
bind -m vi-command 'Control-l: clear-screen'

# Show vi mode in readline (requires bash 5 + capable prompt — Starship handles this)
# Ctrl+E and Ctrl+A still work in insert mode for end/start of line
bind -m vi-insert 'Control-a: beginning-of-line'
bind -m vi-insert 'Control-e: end-of-line'

# ─── History ──────────────────────────────────────────────────────────────────
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups   # no duplicates, no lines starting with space
HISTTIMEFORMAT="%F %T "
shopt -s histappend                # append rather than overwrite on exit
shopt -s cmdhist                   # store multi-line commands as one entry

# ─── Shell options ────────────────────────────────────────────────────────────
shopt -s checkwinsize              # update LINES/COLUMNS after each command
shopt -s globstar                  # ** recursive glob
shopt -s nocaseglob                # case-insensitive globbing
shopt -s cdspell                   # fix minor typos in cd paths
shopt -s autocd                    # type a directory name to cd into it

# ─── fzf ──────────────────────────────────────────────────────────────────────
# Shell key bindings:
#   Ctrl+R  — fuzzy history search (replaces default history cycling)
#   Ctrl+T  — fuzzy file finder, inserts path at cursor
#   Alt+C   — fuzzy cd into subdirectory
eval "$(fzf --bash)"

# Use fd as the fzf file source (respects .gitignore, shows hidden files)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# Consistent fzf appearance across all uses
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --info=inline
  --bind=ctrl-j:down,ctrl-k:up
'
# Note: ctrl-j/k for list navigation mirrors vim-style without requiring
# you to exit insert mode in the shell just to move through results.

# ─── zoxide ───────────────────────────────────────────────────────────────────
# z <partial>   — jump to most-frecent matching directory
# zi            — interactive fuzzy picker over directory history (uses fzf)
eval "$(zoxide init bash)"

# ─── Starship ─────────────────────────────────────────────────────────────────
eval "$(starship init bash)"

# ─── Aliases ──────────────────────────────────────────────────────────────────
[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"

# ─── PATH ─────────────────────────────────────────────────────────────────────
export PATH="/opt/homebrew/bin:$PATH"

# ─── Default editor ───────────────────────────────────────────────────────────
export EDITOR='code --wait'        # VS Code for commit messages etc.
export VISUAL="$EDITOR"

# ─── bat ──────────────────────────────────────────────────────────────────────
export BAT_THEME="Monokai Extended"   # change to "GitHub" for light terminal
# bat as the man page viewer (syntax-highlighted manual pages)
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
```

### .bash_aliases

All aliases follow a consistent prefix scheme so they're easy to remember
and tab-complete as a group:

```bash
# ─── Navigation ───────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# ─── Better defaults ──────────────────────────────────────────────────────────
# These are transparent replacements — same command names you already know
alias cat='bat --paging=never'     # syntax-highlighted cat; --paging=never
                                   # keeps it non-interactive like real cat
alias find='fd'                    # fd has the same intent, saner syntax
alias grep='rg'                    # ripgrep; same flags mostly work
alias top='btop'                   # drop-in visual upgrade

# ─── Git — prefix: g ──────────────────────────────────────────────────────────
alias g='git'
alias gs='git status -sb'          # short status with branch info
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gd='git diff'                # uses delta automatically (set in .gitconfig)
alias gdc='git diff --cached'      # staged changes
alias gp='git push'
alias gpl='git pull --rebase'      # pull with rebase (encourage the habit)
alias gco='git checkout'
alias gsw='git switch'             # modern alternative to checkout for branches
alias gb='git branch -vv'          # branches with tracking info
alias glog='git log --oneline --graph --decorate --all'
alias gl='lazygit'                 # main TUI — gl is short and memorable

# Conventional commits (cocogitto)
alias cz='cog commit'              # interactive conventional commit prompt
alias clog='git cliff'             # preview changelog
alias cver='cog bump --auto'       # auto-bump version from commits

# ─── GitHub CLI — prefix: gh (already prefixed) ───────────────────────────────
# gh is already short; just add a few shortcuts for the most common flows
alias ghpr='gh pr create'
alias ghprl='gh pr list'
alias ghprc='gh pr checkout'
alias ghrv='gh repo view --web'    # open repo in browser

# ─── Search & find — prefix: f ────────────────────────────────────────────────
alias ff='fd'                      # ff = find file
alias ft='fd --type f'             # ft = find (regular) files only
alias fd='fd --type d'             # fd = find directories (shadows fd binary
                                   # — remove this if it causes confusion)
alias fs='rg'                      # fs = find string (search in files)
alias fh='history | fzf'           # fh = find in history interactively

# ─── Process & ports — prefix: p ──────────────────────────────────────────────
alias ps='ps aux'
alias psg='ps aux | rg'            # psg <name> = grep processes
alias ports='lsof -i -P -n | rg LISTEN'   # list listening ports
alias port='lsof -i'               # port <:8080> = what's on this port

# ─── Data wrangling — memorable full words ────────────────────────────────────
alias json='jq'
alias yaml='yq'
alias csv='mlr --csv'              # mlr with CSV mode pre-set
alias http='http --style=monokai'  # httpie with consistent colouring

# ─── File viewing ─────────────────────────────────────────────────────────────
alias md='glow'                    # md <file.md> = render markdown
alias ll='ls -lAh'
alias la='ls -A'
alias lt='tree -L 2'               # lt = list tree (2 levels)
alias llt='tree -L 3'

# ─── tmux — prefix: t ─────────────────────────────────────────────────────────
alias t='tmux'
alias ta='tmux attach -t'          # ta <name> = attach to session
alias tl='tmux list-sessions'
alias tn='tmux new -s'             # tn <name> = new named session
alias tk='tmux kill-session -t'    # tk <name> = kill session
```

---

## 3. Git config

### .gitconfig

```ini
[user]
    name  = Your Name
    email = you@example.com

[core]
    pager       = delta          # delta handles all git output
    editor      = code --wait    # VS Code for commit messages
    excludesfile = ~/.gitignore_global
    autocrlf    = input

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate        = true       # n/N to jump between diff sections (vim-style)
    side-by-side    = true       # GitHub-style split view
    line-numbers    = true
    syntax-theme    = Monokai Extended  # match bat theme above
    features        = decorations

[delta "decorations"]
    file-style                   = bold yellow
    file-decoration-style        = none
    hunk-header-style            = line-number syntax

[diff]
    colorMoved = default
    tool       = difftastic      # use AST diff when you run git difftool

[difftool]
    prompt = false

[difftool "difftastic"]
    cmd = difft "$LOCAL" "$REMOTE"

[merge]
    conflictstyle = diff3        # shows base in conflict markers (very helpful)
    tool          = vscode

[mergetool "vscode"]
    cmd = code --wait --merge $REMOTE $LOCAL $BASE $MERGED

[mergetool]
    keepBackup = false

[pull]
    rebase = true                # gpl (git pull --rebase) as default

[rebase]
    autoStash   = true           # stash/unstash automatically around rebase
    autoSquash  = true           # honour fixup! and squash! commit prefixes

[push]
    default        = current     # push current branch to same-named remote branch
    autoSetupRemote = true       # auto-set upstream on first push

[fetch]
    prune = true                 # remove stale remote-tracking branches

[branch]
    sort = -committerdate        # git branch lists most-recently-used first

[log]
    date = relative              # "3 days ago" instead of full timestamps

[alias]
    # Useful one-liners that don't fit as shell aliases
    undo    = reset HEAD~1 --mixed   # undo last commit, keep changes staged
    wip     = !git add -A && git commit -m "WIP"
    unwip   = !git log -1 --format='%s' | grep -q 'WIP' && git reset HEAD~1
    aliases = config --get-regexp alias
```

### .gitignore_global

```gitignore
# macOS
.DS_Store
.AppleDouble
.LSOverride
._*

# Editor artefacts
.vscode/
.idea/
*.swp
*.swo
*~
.aider*

# OS / tools
Thumbs.db
.env.local
.direnv/
```

---

## 4. Kitty config

Kitty is already a strong choice. Key goals here: consistent colours with
bat/delta, vi-style copy/paste (no reaching for mouse), and clean tmux
integration.

```conf
# kitty.conf

# ─── Font ─────────────────────────────────────────────────────────────────────
font_family      JetBrains Mono
bold_font        JetBrains Mono Bold
italic_font      JetBrains Mono Italic
font_size        13.0

# ─── Shell integration ────────────────────────────────────────────────────────
# Enables: Ctrl+Shift+Z to jump to previous prompt output,
#          mouse click to move cursor, OSC title updates from starship
shell_integration enabled

# ─── Scrollback ───────────────────────────────────────────────────────────────
# When using tmux, kitty scrollback is bypassed — tmux handles it.
# Keep this large for non-tmux usage.
scrollback_lines 10000

# ─── Behaviour ────────────────────────────────────────────────────────────────
enable_audio_bell no
visual_bell_duration 0
window_alert_on_bell no
confirm_os_window_close 0         # don't ask when closing with tmux running

# ─── Copy/paste — vi-style ────────────────────────────────────────────────────
# Consistent with the vi-everywhere philosophy.
# In kitty's scrollback, Enter hint mode with Ctrl+Shift+H, then f (urls),
# p (paths), w (words) — all keyboard driven.
copy_on_select clipboard           # selecting text auto-copies (like most GUIs)

# ─── Key bindings ─────────────────────────────────────────────────────────────
# Kitty's modifier is Ctrl+Shift by default.
# Keep standard kitty bindings — they don't conflict with tmux (which uses Ctrl+A)
# or vim-style TUIs (which use unmodified keys).

# New tab / window (Ctrl+Shift+T / Ctrl+Shift+N — familiar from browsers/GUI)
map ctrl+shift+t new_tab_with_cwd
map ctrl+shift+n new_os_window_with_cwd

# Tab navigation
map ctrl+shift+right next_tab
map ctrl+shift+left  previous_tab

# Scrollback in vi mode — Ctrl+Shift+H opens scrollback in less (respects vi)
map ctrl+shift+h show_scrollback

# Font size
map ctrl+shift+equal change_font_size all +1.0
map ctrl+shift+minus change_font_size all -1.0
map ctrl+shift+0     change_font_size all 0

# ─── tmux integration ─────────────────────────────────────────────────────────
# When running tmux inside kitty, kitty acts as a dumb terminal.
# tmux handles splits, windows, and sessions.
# Avoid kitty's own splits/tabs when tmux is active — use tmux bindings instead.
```

---

## 5. tmux config

Prefix is `Ctrl+A` (more ergonomic than default `Ctrl+B`, matches GNU Screen
muscle memory if you have it). Pane navigation is vim-style `hjkl`.

```conf
# .tmux.conf

# ─── Prefix ───────────────────────────────────────────────────────────────────
unbind C-b
set -g prefix C-a
bind C-a send-prefix           # Ctrl+A Ctrl+A = send literal Ctrl+A to shell

# ─── General ──────────────────────────────────────────────────────────────────
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"  # true colour in kitty
set -g escape-time 10          # faster Esc (important for vi mode in shell)
set -g history-limit 50000
set -g mouse on                # mouse scrolling and pane selection
set -g base-index 1            # windows numbered from 1 (easier to reach)
set -g pane-base-index 1
set -g renumber-windows on     # re-number after closing a window

# ─── Splits — memorable symbols ───────────────────────────────────────────────
# | = vertical bar = split into left|right panes
# - = horizontal bar = split into top-bottom panes
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# ─── Pane navigation — vim-style ──────────────────────────────────────────────
# Prefix + h/j/k/l to move between panes
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Pane resizing — Prefix + H/J/K/L (shift + hjkl)
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# ─── Copy mode — vi-style ─────────────────────────────────────────────────────
set -g mode-keys vi             # vi bindings in copy mode

bind Enter copy-mode            # Prefix + Enter = enter copy/scroll mode
bind -T copy-mode-vi v   send-keys -X begin-selection
bind -T copy-mode-vi y   send-keys -X copy-pipe-and-cancel "pbcopy"
bind -T copy-mode-vi Escape send-keys -X cancel
# In copy mode: / to search down, ? to search up (vim-style)

# ─── Session management ───────────────────────────────────────────────────────
bind s choose-session           # Prefix + s = session picker (fzf-style list)
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# ─── Status bar ───────────────────────────────────────────────────────────────
set -g status-position bottom
set -g status-style 'bg=#1e1e2e fg=#cdd6f4'
set -g status-left '#[bold]  #S  '    # session name on left
set -g status-right '%H:%M  %d %b '  # time and date on right
set -g window-status-current-format '#[bold,fg=#89b4fa] #I:#W '
set -g window-status-format ' #I:#W '
```

### Key bindings summary (print this out)

| What           | Keys                        |
|----------------|-----------------------------|
| New split →    | `Ctrl+A` then `\|`          |
| New split ↓    | `Ctrl+A` then `-`           |
| Move to pane   | `Ctrl+A` then `h/j/k/l`     |
| New window     | `Ctrl+A` then `c`           |
| Next window    | `Ctrl+A` then `n`           |
| Switch session | `Ctrl+A` then `s`           |
| Scroll mode    | `Ctrl+A` then `Enter`       |
| Copy (in mode) | `v` to select, `y` to copy  |
| Detach         | `Ctrl+A` then `d`           |
| Reload config  | `Ctrl+A` then `r`           |

---

## 6. Starship config

Shows everything you need for multi-repo work. Kept minimal — no noise.

```toml
# starship.toml

# Format: working dir > git branch/status > language > vi mode indicator
format = """
$directory\
$git_branch\
$git_status\
$nodejs$python$golang$rust$terraform\
$cmd_duration\
$line_break\
$character"""

[directory]
truncation_length = 4          # show last 4 path segments
truncate_to_repo  = true       # truncate to git root when inside a repo
style             = "bold blue"

[git_branch]
symbol = " "
style  = "bold purple"

[git_status]
# Shows: ?=untracked *=modified +=staged !=renamed »=renamed $=stashed
# ↑=ahead ↓=behind ⇕=diverged
conflicted = "⚡"
ahead      = "↑${count}"
behind     = "↓${count}"
diverged   = "⇕"
modified   = "*"
staged     = "+"
untracked  = "?"
stashed    = "$"

[character]
# Shows [N] in normal mode, [I] in insert mode — vi mode awareness in prompt
vicmd_symbol   = "[N](bold green) "   # normal mode
vimins_symbol  = "[I](bold yellow) "  # insert mode (default)
success_symbol = "[I](bold yellow) "
error_symbol   = "[I](bold red) "

[cmd_duration]
min_time = 2000               # only show duration for commands > 2s
format   = " [$duration](yellow)"

[nodejs]
format = "[ $version](green) "
detect_files = ["package.json", ".nvmrc"]

[python]
format = "[ $version](yellow) "

[terraform]
format = "[ $version](purple) "
```

---

## 7. lazygit config

```yaml
# config.yml
# Location: ~/.config/lazygit/config.yml

gui:
  theme:
    activeBorderColor:
      - '#89b4fa'
      - bold
    selectedLineBgColor:
      - '#313244'

  # Side panel widths as ratios
  sidePanelWidth: 0.25
  expandFocusedSidePanel: true

  # Show commit author
  showFileTree: true
  nerdFontsVersion: "3"

git:
  paging:
    colorArg: always
    pager: delta --paging=never --dark   # delta inside lazygit

  # Conventional commit helpers in commit message box
  commit:
    signOff: false

  # Auto-fetch interval (seconds)
  fetching:
    interval: 60

# Key bindings — keep as close to default vim as possible
keybinding:
  universal:
    quit:            q
    return:          "<esc>"
    scrollUpMain:    k
    scrollDownMain:  j
    prevItem:        k
    nextItem:        j
    scrollLeft:      h
    scrollRight:     l
    nextTab:         "]"
    prevTab:         "["
    openRecentRepos: "<c-r>"     # Ctrl+R = recent repos (mirrors fzf history)
```

---

## 8. Key binding consistency — the full picture

| Layer            | Scheme      | Notes                                      |
|------------------|-------------|--------------------------------------------|
| Bash readline    | vi mode     | Esc=normal, hjkl, w/b words, /=search      |
| fzf (in shell)   | Ctrl+R/T    | Works in vi insert mode without mode switch|
| kitty            | Ctrl+Shift  | Terminal-level; doesn't conflict with rest |
| tmux             | Ctrl+A + *  | Prefix scheme; hjkl for panes              |
| lazygit          | vim-style   | hjkl, q, /, Enter — default                |
| btop             | vim-style   | hjkl navigation, q to quit                 |
| lnav             | vim-style   | hjkl, /, ?, q                              |
| delta (in git)   | n/N         | jump between hunks (set by `navigate=true`)|

The one friction point: **Esc in bash vi mode has ~100ms latency** before the
shell registers it. Fix: `set -g escape-time 10` in tmux (already in config
above) and `set keyseq-timeout 50` in `~/.inputrc`.

### ~/.inputrc

```
# Readline config — applies to bash and anything using GNU readline

# Set vi mode (belt-and-suspenders with .bashrc set -o vi)
set editing-mode vi

# Reduce Esc recognition delay from 1000ms to 50ms
set keyseq-timeout 50

# Show current vi mode in readline prompt (works with Starship's vicmd_symbol)
set show-mode-in-prompt on

# Tab completion tweaks
set completion-ignore-case on      # case-insensitive tab completion
set completion-map-case on         # treat - and _ as equivalent
set show-all-if-ambiguous on       # show all options on first Tab (not second)
set mark-symlinked-directories on  # add / to symlinked dirs on completion
```

---

## 9. Team onboarding

Share the dotfiles repo with new team members. Their onboarding is:

```bash
# 1. Clone
git clone https://github.com/your-org/dotfiles ~/.dotfiles

# 2. Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. Install all tools
brew bundle --file=~/.dotfiles/Brewfile

# 4. Switch to Homebrew bash 5
echo "/opt/homebrew/bin/bash" | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/bash

# 5. Symlink all config files
bash ~/.dotfiles/install.sh

# 6. Install fzf shell bindings (one-time)
$(brew --prefix)/opt/fzf/install --all --no-update-rc

# 7. Restart terminal
```

Total time: ~10 minutes. Everything else — zoxide learning your directories,
fzf building its understanding of your repos — happens automatically with use.
