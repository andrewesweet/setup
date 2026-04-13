# Shell Modernisation & Tool Integration Design

**Date**: 2026-04-12
**Status**: Approved — design complete, ready for implementation planning

## 1. Goals

1. Migrate interactive shell from Bash to Zsh (primary) and Nushell (first-class secondary)
2. Integrate atuin (history), television (fuzzy finding), and sesh (session management)
3. Add tmux plugin ecosystem via TPM
4. Add supporting tools: yazi, xh, rip (process killer), rip2 (safe rm), jqp, gh-dash, diffnav, carapace
5. Maintain bash as the scripting shell for team/CI work
6. Preserve existing dotfiles architecture (tools.txt, Brewfile, install scripts, symlink deployment)

## 2. Architecture

### 2.1 Shell Hierarchy

```
┌─────────────────────────────────────────────────────┐
│  Login shell: zsh                                    │
│  ├── Interactive use, aliases, tool integrations     │
│  └── chsh -s "$(which zsh)"  (platform-portable)    │
│                                                      │
│  First-class secondary: nushell                      │
│  ├── Same tool integrations, aliases, keybindings    │
│  ├── Launched explicitly: `nu` or via tmux           │
│  └── NOT the login shell                             │
│                                                      │
│  Scripting shell: bash                               │
│  ├── All CI/CD pipelines                             │
│  ├── Team-shared scripts                             │
│  └── install-macos.sh, install-wsl.sh, etc.          │
└─────────────────────────────────────────────────────┘
```

### 2.2 Keybinding Ownership

```
Ctrl-R  →  atuin      (history search — sole owner, no other tool claims this)
Ctrl-T  →  television (smart autocomplete — context-aware channel picker)
Alt-C   →  zoxide     (directory jump — unchanged from current fzf binding)
Alt-R   →  ghq+fzf    (repo picker — `repo` shell function; Layer 1c)
z / zi  →  zoxide     (cd replacement — unchanged)
```

Television's `[shell_integration.keybindings]` ONLY claims `smart_autocomplete = "ctrl-t"`.
The `command_history` key is **removed** from television's shell integration config —
atuin is the sole owner of Ctrl-R. This eliminates the triple-claim chain
(fzf → television → atuin) that creates silent fallback confusion.

Television's internal UI keybinding `ctrl-r` is rebound from `toggle_remote_control`
to avoid confusion with the shell-level Ctrl-R (atuin). Internal `ctrl-t` is rebound
from `toggle_layout` to `ctrl-shift-t` to avoid confusion with the shell-level Ctrl-T.

**Rejected: Ctrl-G for `repo`.** Ctrl-G is bash readline's `abort` (cancels
incremental search, multi-key sequences). Rebinding it would break standard
muscle memory across every bash environment. Alt-R parallels Alt-C (zoxide)
in the meta-modifier "navigation jumpers" group and is unclaimed by readline,
fzf, atuin, or television.

### 2.3 Tool Init Ordering

Init ordering matters — later inits override earlier keybindings.

**Zsh (.zshrc) order:**
```
1.  Guard + version check (warn if zsh < 5.9)
2.  Platform detection
3.  XDG + PATH setup (export XDG_CONFIG_HOME, HOMEBREW_PREFIX, DOTFILES, user-local paths)
4.  Zsh options and completion system (compinit, case-insensitive matching)
5.  Zsh plugins — autosuggestions ONLY here (syntax-highlighting MUST be last)
    - Source zsh-autosuggestions from platform-conditional path:
      probe $HOMEBREW_PREFIX/share/, /usr/share/, /usr/local/share/
6.  Vi-mode keybindings
    - bindkey -v
    - KEYTIMEOUT=1 (fast mode switching — required for jj binding)
    - bindkey -M viins 'jj' vi-cmd-mode
    - bindkey '^L' clear-screen
    - bindkey '^A' beginning-of-line
    - bindkey '^E' end-of-line
    - bindkey -M vicmd 'k' up-line-or-search
    - bindkey -M vicmd 'j' down-line-or-search
7.  History (HISTSIZE=100000, SAVEHIST=200000, share_history, hist_ignore_dups, etc.)
8.  Shell options (auto_cd, correct, glob_dots, extended_glob, etc.)
9.  Tool evals — ORDER MATTERS:
    a. fzf         (provides base fuzzy infrastructure — library only)
    b. television  (claims Ctrl-T ONLY — Ctrl-R NOT claimed)
    c. atuin       (claims Ctrl-R — sole owner)
    d. zoxide
    e. mise
    f. direnv
    g. sesh        (no shell init, CLI only)
    h. starship    (LAST eval — sets precmd/PROMPT_COMMAND)
10. Completions (gh, mise, uv, cog, gcloud, carapace for extras)
11. OSC 9 notification hook (ported from bash)
12. Environment variables (EDITOR, BAT_THEME, RIP_GRAVEYARD, etc.)
13. Source aliases (.zsh_aliases)
14. zsh-syntax-highlighting (MUST be sourced LAST — after all plugins, evals, and aliases)
    - Source from platform-conditional path (same probe as autosuggestions)
15. Local overrides (.zshrc.local)
```

**Nushell (env.nu + config.nu) order:**

Nushell cannot `eval` — tools must pre-generate init scripts to cache files.

```
env.nu:
  1. XDG + PATH setup (homebrew, .local/bin, mise shims)
     - export XDG_CONFIG_HOME = ($env.HOME | path join ".config")
  2. Pre-generate cached inits (use $nu.cache-dir for nushell-idiomatic paths):
     - starship init nu  | save -f $"($nu.cache-dir)/starship-init.nu"
     - zoxide init nushell | save -f $"($nu.cache-dir)/zoxide-init.nu"
     - mise activate nu   | save -f $"($nu.cache-dir)/mise-init.nu"
     - carapace _carapace nushell | save -f $"($nu.cache-dir)/carapace-init.nu"
     - tv init nu         | save -f $"($nu.cache-dir)/television-init.nu"
     Note: atuin uses its own path: ~/.local/share/atuin/init.nu (upstream convention)
  3. Environment variables (EDITOR, BAT_THEME, STARSHIP_CONFIG, GRAVEYARD, etc.)
  4. CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'

config.nu:
  1. Theme (dark, Dracula Pro)
  2. Table display settings (rounded, wrapping)
  3. History settings (100_000, sync_on_enter)
  4. Completions (carapace as external completer)
  5. Vi-mode (edit_mode: vi, cursor shapes)
  6. Shell integration (osc2, osc7, osc8, osc133 — platform-conditional for WSL2)
  7. Keybindings (vi-mode, jj escape, Ctrl-L clear)
  8. Hooks:
     - pre_prompt: direnv integration
     - display_output: responsive table sizing
  9. Source cached inits (use $nu.cache-dir; atuin uses its own path):
     - source $"($nu.cache-dir)/zoxide-init.nu"
     - source $"($nu.cache-dir)/carapace-init.nu"
     - source ~/.local/share/atuin/init.nu  (atuin upstream convention)
     - source $"($nu.cache-dir)/television-init.nu"
     - use $"($nu.cache-dir)/starship-init.nu"
     - use $"($nu.cache-dir)/mise-init.nu"
  10. Aliases and custom commands (NO `ls` alias — keep nushell's native structured ls)
  11. Local overrides (source if exists)
```

### 2.4 Directory Structure

New directories and files in the dotfiles repo:

```
macos-dev/
├── zsh/
│   ├── .zshrc              # Main config (15-section structure)
│   └── .zsh_aliases        # Aliases (ported from bash/.bash_aliases)
├── nushell/
│   ├── config.nu           # Main config
│   └── env.nu              # Environment and cached init generation
├── atuin/
│   └── config.toml         # Atuin configuration
├── television/
│   ├── config.toml         # Television main config
│   └── cable/              # Custom cable channels
│       ├── alias.toml
│       ├── brew-packages.toml
│       ├── dirs.toml
│       ├── docker-compose.toml
│       ├── docker-containers.toml  # Uses podman, not docker
│       ├── dotfiles.toml
│       ├── env.toml                # Excludes sensitive var patterns
│       ├── files.toml
│       ├── gcloud-configs.toml       # Custom — GCP configurations
│       ├── gcloud-instances.toml     # Custom — GCP Compute instances
│       ├── gcloud-run-services.toml  # Custom — GCP Cloud Run
│       ├── gcloud-sql.toml           # Custom — GCP Cloud SQL
│       ├── gh-issues.toml
│       ├── gh-prs.toml
│       ├── git-branch.toml
│       ├── git-diff.toml
│       ├── git-log.toml
│       ├── git-reflog.toml
│       ├── git-remotes.toml
│       ├── git-repos.toml
│       ├── git-stash.toml
│       ├── git-worktrees.toml
│       ├── k8s-contexts.toml
│       ├── k8s-deployments.toml
│       ├── k8s-pods.toml
│       ├── k8s-services.toml
│       ├── make-targets.toml
│       ├── man-pages.toml
│       ├── path.toml
│       ├── procs.toml              # Cross-platform ps flags
│       ├── recent-files.toml
│       ├── sesh.toml
│       ├── ssh-hosts.toml
│       ├── text.toml
│       ├── tmux-sessions.toml
│       ├── todo-comments.toml
│       └── zoxide.toml
├── sesh/
│   └── sesh.toml.tmpl      # Sesh config template (@DOTFILES@ substituted at install)
├── yazi/
│   ├── yazi.toml           # Core config
│   ├── keymap.toml         # Keybindings (vi-centric)
│   └── theme.toml          # Theme (Dracula / Dracula Pro)
├── gh-dash/
│   └── config.yml          # GitHub dashboard config
├── jqp/
│   └── .jqp.yaml           # jqp theme config (symlinked to ~/.jqp.yaml)
├── diffnav/
│   └── config.yml          # diffnav config
├── Brewfile                # Updated
├── tools.txt               # Updated
├── bash/                   # PRESERVED — no changes to existing files
│   ├── .bash_profile
│   ├── .bashrc
│   ├── .bash_aliases
│   └── .inputrc
└── ...existing dirs unchanged...
```

### 2.5 Symlink Mapping

New `link()` calls in install-macos.sh:

```bash
# zsh
link zsh/.zshrc           .zshrc
link zsh/.zsh_aliases     .zsh_aliases

# nushell
link nushell/config.nu    .config/nushell/config.nu
link nushell/env.nu       .config/nushell/env.nu

# atuin
link atuin/config.toml    .config/atuin/config.toml

# television (directory symlink for cable/)
link television/config.toml       .config/television/config.toml
link television/cable             .config/television/cable

# sesh (generated from template — not a symlink, see install script)
# sed "s|@DOTFILES@|$DOTFILES|g" "$DOTFILES/sesh/sesh.toml.tmpl" > "$HOME/.config/sesh/sesh.toml"

# yazi
link yazi/yazi.toml       .config/yazi/yazi.toml
link yazi/keymap.toml     .config/yazi/keymap.toml
link yazi/theme.toml      .config/yazi/theme.toml

# gh-dash
link gh-dash/config.yml   .config/gh-dash/config.yml

# jqp
link jqp/.jqp.yaml        .jqp.yaml

# diffnav
link diffnav/config.yml   .config/diffnav/config.yml
```

install-wsl.sh receives equivalent additions.

Note: carapace requires no config file — it is configured entirely via environment
variables ($CARAPACE_BRIDGES) set in shell init files.

### 2.6 Bash Preservation

The existing `bash/` directory is **unchanged**. `.bash_profile`, `.bashrc`,
`.bash_aliases`, `.inputrc` continue to be symlinked. Bash remains fully functional for:
- CI/CD pipelines
- Team-shared scripts
- `bash` command to drop into a bash shell when needed
- All existing install scripts

Atuin and television inits are **optionally** added to `.bashrc` section 8, gated
behind an env var so they can be disabled without editing config:

```bash
# atuin (opt-in via ENABLE_ATUIN=1 in .bashrc.local)
if [[ "${ENABLE_ATUIN:-0}" == 1 ]] && command -v atuin &>/dev/null; then
  eval "$(atuin init bash)"
fi

# television (opt-in via ENABLE_TV=1 in .bashrc.local)
if [[ "${ENABLE_TV:-0}" == 1 ]] && command -v tv &>/dev/null; then
  eval "$(tv init bash)"
fi
```

This prevents breaking existing bash muscle memory. Users can opt in when ready.

## 3. Tool Configurations

### 3.1 Atuin (atuin/config.toml)

```toml
# Compact UI, execute on enter (tab to edit first)
style = "compact"
enter_accept = true

# Fuzzy search by default, workspace-aware filtering
search_mode = "fuzzy"
filter_mode = "global"
workspaces = true

# Shell up-key scoped to current directory
filter_mode_shell_up_key_binding = "directory"

# Vi-compatible keymap (auto-detects from shell)
keymap_mode = "auto"

# Secret filtering on (default regexes: AWS keys, GitHub PATs, Slack tokens, etc.)
secrets_filter = true

# Custom history filter — comprehensive token/secret patterns
# Covers both variable-assignment style AND raw token prefixes
history_filter = [
  "^.*GITHUB_TOKEN.*$",
  "^.*GH_TOKEN.*$",
  "^.*SECRET.*$",
  "^.*PASSWORD.*$",
  "^.*BEARER.*$",
  "^.*AUTHORIZATION.*$",
  "^.*AWS_ACCESS.*$",
  "^.*AWS_SECRET.*$",
  "^.*AWS_SESSION.*$",
  "^.*ANTHROPIC.*$",
  "^.*OPENAI.*$",
  "^.*ghp_[A-Za-z0-9_]+.*$",
  "^.*gho_[A-Za-z0-9_]+.*$",
  "^.*github_pat_[A-Za-z0-9_]+.*$",
  "^.*glpat-[A-Za-z0-9_-]+.*$",
  # OpenAI sk-/sk-proj-/sk-ant- style keys; lower bound of 20 chars
  # after the sk- prefix rejects false positives like "disk-utils".
  "^.*sk-[A-Za-z0-9_-]{20,}.*$",
  "^.*xoxb-[A-Za-z0-9-]+.*$",
  "^.*xoxp-[A-Za-z0-9-]+.*$",
  "^.*PRIVATE.KEY.*$",
]

# Sync DISABLED by default — opt-in only
# To enable: set auto_sync = true and configure sync_address
# For self-hosted: sync_address = "https://your-atuin-server.example.com"
# For atuin.sh cloud: sync_address = "https://api.atuin.sh"
# History is E2E encrypted with a key stored at ~/.local/share/atuin/key
# Even with encryption, syncing sends metadata (cwd, hostname, timestamps) to the server.
auto_sync = false

[sync]
records = true

[stats]
common_subcommands = [
  "cargo", "docker", "git", "go", "gcloud",
  "kubectl", "npm", "podman", "terraform", "tmux",
]
```

### 3.2 Television (television/config.toml)

```toml
tick_rate = 50
default_channel = "files"
history_size = 200
global_history = false

[ui]
ui_scale = 100
orientation = "landscape"
theme = "dracula"

[ui.input_bar]
position = "top"
prompt = ">"
border_type = "rounded"

[ui.results_panel]
border_type = "rounded"

[ui.preview_panel]
size = 65
scrollbar = true
border_type = "rounded"

[ui.help_panel]
show_categories = true
hidden = true

[keybindings]
esc = "quit"
ctrl-c = "quit"
down = "select_next_entry"
ctrl-n = "select_next_entry"
ctrl-j = "select_next_entry"
up = "select_prev_entry"
ctrl-p = "select_prev_entry"
ctrl-k = "select_prev_entry"
tab = "toggle_selection_down"
backtab = "toggle_selection_up"
enter = "confirm_selection"
ctrl-d = "scroll_preview_half_page_down"
ctrl-u = "scroll_preview_half_page_up"
ctrl-f = "cycle_previews"
ctrl-y = "copy_entry_to_clipboard"
ctrl-s = "cycle_sources"
# Rebound from ctrl-r to avoid confusion with shell-level atuin Ctrl-R
ctrl-g = "toggle_remote_control"
ctrl-x = "toggle_action_picker"
ctrl-o = "toggle_preview"
f9 = "toggle_help"
f10 = "toggle_status_bar"
# Rebound from ctrl-t to avoid confusion with shell-level television Ctrl-T
ctrl-shift-t = "toggle_layout"

[shell_integration]
fallback_channel = "files"

[shell_integration.channel_triggers]
"alias" = ["alias", "unalias"]
"env" = ["export", "unset"]
"dirs" = ["cd", "ls", "rmdir", "z"]
"files" = [
  "cat", "less", "head", "tail", "vim", "nvim",
  "bat", "cp", "mv", "rm", "touch", "chmod",
  "chown", "ln", "tar", "zip", "unzip",
]
"git-diff" = ["git add", "git restore"]
"git-branch" = [
  "git checkout", "git branch", "git merge",
  "git rebase", "git pull", "git push",
]
"git-log" = ["git log", "git show"]
"docker-containers" = ["podman exec", "podman stop", "podman rm"]
"docker-images" = ["podman run"]
"git-repos" = ["nvim", "code", "git clone"]
"k8s-pods" = ["kubectl exec", "kubectl logs"]
"k8s-contexts" = ["kubectx"]
"make-targets" = ["make"]
"ssh-hosts" = ["ssh", "scp"]

[shell_integration.keybindings]
# Television ONLY claims Ctrl-T. Ctrl-R is NOT claimed here —
# atuin is the sole owner of Ctrl-R.
smart_autocomplete = "ctrl-t"
```

**Cable channel security notes:**
- All cable channels that interpolate user-selected values use single-quoted `'{}'`
  placeholders and `--` separators before user input where applicable
- The `env.toml` channel filters out lines matching sensitive variable patterns
  (GITHUB_TOKEN, AWS_*, SECRET, PASSWORD, KEY, etc.) before display
- The `procs.toml` channel uses POSIX-compatible `ps -e -o pid=,ucomm=` flags
  (works on both macOS BSD ps and Linux GNU ps)
- The `docker-*.toml` channels use `podman` instead of `docker` to match the user's
  container setup
- The `git-repos.toml` channel sources from `ghq list --full-path` once Layer 1c
  lands (depends on ghq being installed). Until then, it falls back to
  `fd --exclude Library --exclude 'Application Support' -t d -d 8 .git$ ~ -X dirname`
  flags which are harmless no-ops on Linux where those directories don't exist.
  Layer 1b's `git-repos.toml` channel SHOULD pre-emptively use the `ghq list`
  source so Layer 1c is purely additive (ghq install makes the channel work
  without re-editing the cable file).

### 3.3 Sesh (sesh/sesh.toml.tmpl → sesh.toml)

Template file in repo (`sesh/sesh.toml.tmpl`):
```toml
[default_session]
startup_command = ""

[[session]]
name = "dotfiles"
path = "@DOTFILES@"
startup_command = "nvim"
```

sesh requires absolute paths — no env var expansion. The install script generates
`~/.config/sesh/sesh.toml` from the template at install time:
```bash
sed "s|@DOTFILES@|$DOTFILES|g" "$DOTFILES/sesh/sesh.toml.tmpl" > "$HOME/.config/sesh/sesh.toml"
```
This follows the same pattern as the podman LaunchAgent plist.

### 3.4 Yazi

**yazi/yazi.toml** — core configuration:
```toml
[manager]
layout = [1, 4, 3]        # parent:current:preview ratio
sort_by = "natural"
sort_sensitive = false
sort_reverse = false
sort_dir_first = true
show_hidden = false
show_symlink = true

[preview]
tab_size = 2
max_width = 600
max_height = 900

[opener]
edit = [
  { run = '${EDITOR:-nvim} "$@"', block = true, for = "unix" },
]
```

**yazi/keymap.toml** — vi-centric keybindings (yazi defaults are already vi-native).

**yazi/theme.toml** — Dracula theme (official community theme from draculatheme.com/yazi).

**Shell integration** — cd-on-quit wrapper for zsh, nushell, and bash:

Zsh (in .zsh_aliases):
```zsh
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
```

Nushell (in config.nu):
```nu
def --env y [...args] {
  let tmp = (mktemp -t "yazi-cwd.XXXXXX")
  yazi ...$args --cwd-file $tmp
  let cwd = (open $tmp | str trim)
  if $cwd != "" and $cwd != $env.PWD {
    cd $cwd
  }
  rm -fp $tmp
}
```

### 3.5 gh-dash (gh-dash/config.yml)

```yaml
prSections:
  - title: My Pull Requests
    filters: is:open author:@me
  - title: Needs My Review
    filters: is:open review-requested:@me
  - title: Involved
    filters: is:open involves:@me -author:@me

issuesSections:
  - title: My Issues
    filters: is:open author:@me
  - title: Assigned
    filters: is:open assignee:@me

defaults:
  preview:
    open: false
    width: 70
  prsLimit: 20
  issuesLimit: 20
  view: prs
  refetchIntervalMinutes: 30

keybindings:
  universal:
    - key: g
      name: lazygit
      command: >
        cd {{.RepoPath}}; lazygit

pager:
  diff: "diffnav"

confirmQuit: false
showAuthorIcons: true
```

**PR review workflow (end-to-end):**
1. `ghd` → opens gh-dash, shows PRs needing review
2. Select PR → press Enter for preview, or `g` to open lazygit in the repo
3. Diff view uses diffnav as pager (navigate multi-file diffs)
4. `ghprc <PR#>` → checkout PR branch locally
5. `v` → open in nvim for code review
6. `cr` → run critique review

### 3.6 Tmux Plugin Additions

Added to tmux/.tmux.conf. Settings that overlap with tmux-sensible are **removed**
from the manual config section:

**Removed** (now provided by tmux-sensible):
- `set -sg escape-time 10` → sensible sets 0 (faster, better for vi-mode)
- `set -g history-limit 50000` → sensible sets a large default

**Kept** (user-specific, not in sensible):
- `set -g default-terminal "tmux-256color"` (sensible uses screen-256color)
- `set -sa terminal-overrides ",xterm-kitty:RGB"`
- `set -g mouse on`
- `set -g base-index 1` / `pane-base-index 1`
- `set -g renumber-windows on`
- All prefix, split, navigation, copy-mode, and vim-tmux-navigator bindings

**Plugin block:**
```tmux
# ── Plugin manager ──────────────────────────────────────────────────────
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'fcsonline/tmux-thumbs'
set -g @plugin 'sainnhe/tmux-fzf'
set -g @plugin 'wfxr/tmux-fzf-url'
set -g @plugin 'omerxx/tmux-sessionx'
set -g @plugin 'omerxx/tmux-floax'

# ── Plugin configuration ───────────────────────────────────────────────
# Resurrect + Continuum
set -g @continuum-restore 'on'
set -g @resurrect-strategy-nvim 'session'

# Yank — platform-conditional clipboard
# On WSL2, tmux-yank uses clip.exe automatically if detected.
# On macOS, it uses pbcopy. set-clipboard enables OSC 52 passthrough.
set -g set-clipboard on

# Floax — prefix+p for floating pane
# Note: prefix+p does NOT shadow previous-window (that's prefix+n/prefix+p
# in default tmux, but we use prefix+h/j/k/l for navigation, not p/n)
set -g @floax-width '80%'
set -g @floax-height '80%'
set -g @floax-border-color 'magenta'
set -g @floax-text-color 'blue'
set -g @floax-bind 'p'
set -g @floax-change-path 'true'

# SessionX
set -g @sessionx-bind 'o'
set -g @sessionx-zoxide-mode 'on'
set -g @sessionx-window-height '85%'
set -g @sessionx-window-width '75%'
set -g @sessionx-filter-current 'false'

# Thumbs (text pattern selection)
# Default trigger: prefix + Space

# fzf-url
set -g @fzf-url-fzf-options '-p 60%,30% --prompt="   " --border-label=" Open URL "'
set -g @fzf-url-history-limit '2000'

# Detach behaviour — switch to next session instead of detaching
set -g detach-on-destroy off

# ── TPM bootstrap (must be last line) ──────────────────────────────────
run '~/.tmux/plugins/tpm/tpm'
```

**tmux-thumbs note:** On WSL2 or Alpine without a Rust toolchain, tmux-thumbs compiles
from source on first `prefix + I`. If the Rust toolchain is not available, the install
will fail silently for thumbs only — all other plugins will work. Document this in
post-install steps and provide a fallback (pre-built binary from GitHub releases).

### 3.7 Zsh Configuration (.zshrc)

15-section structure (extending .bashrc's 13 sections with zsh-specific additions):

```
Section 1:  Guard + version check
            - Return if non-interactive
            - Warn if zsh < 5.9 (macOS ships 5.8; Homebrew provides current)
Section 2:  Platform detection (same case statement as bash)
Section 3:  XDG + PATH setup
            - export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
            - HOMEBREW_PREFIX detection (same fast path as bash — no fork)
            - DOTFILES resolution (same symlink-following logic)
            - User-local tool paths (~/.bun/bin AFTER system paths, ~/.local/bin)
Section 4:  Zsh completion system
            - zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' (case-insensitive)
            - autoload -Uz compinit && compinit
Section 5:  Zsh plugins (platform-conditional source paths)
            - autosuggestions: probe $HOMEBREW_PREFIX/share/, /usr/share/, /usr/local/share/
            - syntax-highlighting: same probe pattern
Section 6:  Vi-mode + keybindings
            - bindkey -v
            - bindkey 'jj' vi-cmd-mode
            - bindkey '^L' clear-screen
            - bindkey '^A' beginning-of-line
            - bindkey '^E' end-of-line
            - bindkey '^K' up-line-or-search (vi-mode history)
            - bindkey '^J' down-line-or-search
Section 7:  History
            - HISTSIZE=100000, SAVEHIST=200000
            - setopt share_history hist_ignore_dups hist_ignore_space
            - HISTIGNORE equivalent via hist_ignore_patterns (or rely on atuin)
Section 8:  Shell options
            - setopt auto_cd correct glob_dots extended_glob no_case_glob
Section 9:  Tool evals (ORDER MATTERS):
            a. fzf (--zsh)
            b. television (tv init zsh — claims Ctrl-T only)
            c. atuin (atuin init zsh — claims Ctrl-R)
            d. zoxide (zoxide init zsh)
            e. mise (mise activate zsh)
            f. direnv (direnv hook zsh)
            g. starship (starship init zsh — LAST, sets precmd)
Section 10: Completions (gh, mise, uv, cog, gcloud)
Section 11: OSC 9 notification hook (ported from bash)
Section 12: Environment variables
            - EDITOR, VISUAL, MANPAGER (same logic as bash)
            - BAT_THEME, FZF_DEFAULT_COMMAND, FZF_CTRL_T_COMMAND, FZF_ALT_C_COMMAND, FZF_DEFAULT_OPTS
            - RIP_GRAVEYARD="$HOME/.local/share/graveyard" (rip2 safe delete location)
Section 13: Source aliases (.zsh_aliases)
Section 14: Local overrides (.zshrc.local)
```

### 3.8 Aliases

**Zsh (.zsh_aliases)** — ported from .bash_aliases with these changes:

- All existing aliases carry over verbatim (zsh alias syntax = bash alias syntax)
- All existing functions carry over (minimal syntax differences)
- `fh` alias **removed** (replaced by atuin Ctrl-R)
- New aliases added:

```zsh
# xh (modern httpie — httpie stays installed for team compat)
alias http='xh'
alias https='xhs'

# rip (cesarferreira/rip — fuzzy process killer)
# Installed via: brew install cesarferreira/tap/rip
# No alias needed — `rip` is the command name

# rip2 (MilesCranmer/rip2 — safe rm with undo, graveyard at ~/.local/share/graveyard)
alias rrip='rip2 -u'    # undo last rip2 deletion
alias rm-safe='rip2'     # explicit safe-rm alias to avoid confusion with rip (process killer)

# yazi — y() function defined separately (cd-on-quit wrapper)

# jqp (interactive jq playground)
alias jqi='jqp'

# gh-dash
alias ghd='gh dash'

# diffnav
alias dn='diffnav'

# sesh — 'sx' prefix to avoid collision with Linux `ss` network utility
alias sx='sesh connect'
alias sxl='sesh list'
```

- `cheat` function extended with new subcommands: `atuin`, `television`/`tv`,
  `sesh`, `yazi`, `xh`, `rip2`, `jqp`, `gh-dash`/`ghd`, `diffnav`
- `cheat` help text updated to list all new subcommands
- `cheatsheet.md` updated: Ctrl-R now labelled "atuin", Ctrl-T now labelled "television"
- `aliases` function ported to work in zsh (uses `alias` builtin — same as bash)

**Nushell aliases (in config.nu):**

- All aliases ported to nushell syntax
- `ls` is **NOT aliased** — nushell's native `ls` returns structured table data,
  which is the primary reason for using nushell. `eza` available as `ll`, `la`, `lt`, `llt`.
- External commands use `^command` prefix where shadowing builtins
- Functions use `def` or `def --env` (for directory-changing commands)

### 3.9 Theming — Dracula Pro

**Principle**: Dracula Pro everywhere possible, then Dracula (free), then custom theme
matching the Dracula Pro palette. Font: JetBrainsMono Nerd Font with ligatures.

**Dracula Pro palette** (standard dark variant):

```
Background:    #282A36
Current Line:  #44475A
Selection:     #44475A
Foreground:    #F8F8F2
Comment:       #6272A4
Red:           #FF5555
Orange:        #FFB86C
Yellow:        #F1FA8C
Green:         #50FA7B
Cyan:          #8BE9FD
Purple:        #BD93F9
Pink:          #FF79C6
```

**Theme source for each tool:**

Verified against the `dracula` GitHub org (400+ repos) and the Dracula Pro app list.

*Tier 1 — Dracula Pro (paid, from v2.2.2 download):*

| Tool | Install Method |
|------|---------------|
| **Kitty** | Copy `dracula-pro.conf` to `~/.config/kitty/`, `include dracula-pro.conf` in kitty.conf |
| **Neovim / Vim** | Pro vim theme via lazy.nvim plugin |
| **VS Code** | Dracula Pro extension from marketplace |
| **JetBrains IDEs** | Dracula Pro theme from download |
| **Xcode** | Dracula Pro theme from download |
| **Windows Terminal** | Import Pro color scheme JSON |
| **iTerm** | Import Pro .itermcolors profile |
| **Alacritty** | Dracula Pro TOML/YAML config |
| **Ghostty** | Dracula Pro config from download |
| **WezTerm** | Dracula Pro Lua config from download |

*Tier 2 — Official Dracula (free, from github.com/dracula/\<tool\>):*

| Tool | Repo | Install Method |
|------|------|---------------|
| **Tmux** | `dracula/tmux` | TPM plugin: `set -g @plugin 'dracula/tmux'` |
| **Starship** | `dracula/starship` | Copy starship.toml or palette section |
| **Lazygit** | `dracula/lazygit` | Copy theme to lazygit config.yml |
| **fzf** | `dracula/fzf` | `FZF_DEFAULT_OPTS` color string |
| **Yazi** | `dracula/yazi` | Copy theme.toml to yazi config |
| **gh-dash** | `dracula/gh-dash` | Theme section in config.yml |
| **Zsh** | `dracula/zsh` | Source zsh theme file |
| **zsh-syntax-highlighting** | `dracula/zsh-syntax-highlighting` | Source dracula highlighter config |
| **Fish** | `dracula/fish` | Fish theme integration (for nushell compatibility layer) |
| **eza** | `dracula/eza` | Theme config for eza colors |
| **lnav** | `dracula/lnav` | Copy lnav theme file |
| **dircolors** | `dracula/dircolors` | Source .dir_colors file |
| **OpenCode** | `dracula/opencode` | Theme config in opencode.jsonc |
| **man-pages** | `dracula/man-pages` | MANPAGER color environment variables |
| **ripgrep** | `dracula/ripgrep` | ripgrep color config |
| **lsd** | `dracula/lsd` | Theme config (if we adopt lsd alongside eza) |

*Tier 3 — Dracula built-in (ships with the tool):*

| Tool | Config |
|------|--------|
| **bat** | `BAT_THEME="Dracula"` (bat ships Dracula as a built-in theme) |
| **delta** | `syntax-theme = Dracula` in gitconfig (uses bat's theme) |
| **jqp** | `theme: dracula` in `.jqp.yaml` |
| **Pygments** | `dracula/pygments` (Python syntax highlighting used by various tools) |

*Tier 4 — Custom Dracula palette (no official theme, built from spec):*

| Tool | Approach |
|------|----------|
| **Television** | Custom TOML theme in `~/.config/television/themes/dracula.toml` |
| **Nushell** | Color config record in config.nu using Dracula hex values |
| **k9s** | Custom skin YAML using Dracula hex values |
| **btop** | Custom theme file using Dracula hex values |
| **diffnav** | Custom config.yml using Dracula hex values |

**Starship** uses the official `dracula/starship` theme. The repo provides a complete
`starship.toml` with Dracula palette and pre-configured module styles. Our
`starship/starship.toml` will be based on this, with our existing module customisations
(kubernetes enabled, terraform, golang, python, nodejs) merged in. Key palette values
for reference:

```toml
palette = "dracula"

[palettes.dracula]
background = "#282A36"
current_line = "#44475A"
foreground = "#F8F8F2"
comment = "#6272A4"
cyan = "#8BE9FD"
green = "#50FA7B"
orange = "#FFB86C"
pink = "#FF79C6"
purple = "#BD93F9"
red = "#FF5555"
yellow = "#F1FA8C"
```

Module styles follow Dracula conventions:
```toml
[directory]
style = "bold purple"

[git_branch]
style = "bold pink"

[character]
vicmd_symbol = "[N](bold green) "
success_symbol = "[I](bold yellow) "
error_symbol = "[I](bold red) "

[cmd_duration]
format = " [$duration](yellow)"

[kubernetes]
format = "[⎈ $context](cyan) "
```

**fzf Dracula colors** (in shell env vars):

```bash
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --info=inline
  --bind=ctrl-j:down,ctrl-k:up
  --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
  --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
  --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
  --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
'
```

**Tmux Dracula plugin** replaces the manual theme. The existing 4-line manual theme
(`bg=#1e1e2e`, `fg=#cdd6f4`) is removed. Configuration:

```tmux
set -g @plugin 'dracula/tmux'
# Dracula tmux plugin configuration
set -g @dracula-show-powerline true
set -g @dracula-plugins "git time"
set -g @dracula-show-left-icon session
set -g @dracula-military-time true
```

Note: this reverses the earlier "keep manual theme" decision — Dracula has an
official tmux plugin, unlike catppuccin where manual was simpler. The Dracula tmux
plugin is well-maintained (76k+ views on draculatheme.com).

**Kitty font + theme** (kitty/kitty.conf):

```
font_family      JetBrainsMono Nerd Font
font_size        13.0
disable_ligatures never

include dracula-pro.conf
```

The `dracula-pro.conf` file is extracted from the Dracula Pro download and placed
in `kitty/dracula-pro.conf` in the dotfiles repo. Symlinked alongside kitty.conf.

**Lazygit** uses the official `dracula/lazygit` theme. The repo provides the
complete theme section for `config.yml`. Merge with our existing lazygit config
(pager, keybindings, gui settings).

**bat theme**: `BAT_THEME="Dracula"` (bat ships with Dracula theme built-in).

**delta theme**: `syntax-theme = Dracula` in git/.gitconfig delta section.

**Existing configs updated** (not just new tools):
- kitty/kitty.conf: font → JetBrainsMono Nerd Font, add ligatures, include dracula-pro.conf
- lazygit/config.yml: theme colors → Dracula
- git/.gitconfig: delta syntax-theme → Dracula
- bash/.bashrc: BAT_THEME → Dracula, FZF_DEFAULT_OPTS → Dracula colors
- starship/starship.toml: palette → dracula

**Dracula Pro files in dotfiles repo:**
The Dracula Pro download (v2.2.2) contains theme files for supported tools. These
are placed in a `themes/dracula-pro/` directory in the dotfiles repo. The install
script copies/symlinks the appropriate files. Since Dracula Pro is paid software,
this directory should be in `.gitignore` if the repo is public, or the files can be
committed to a private repo.

## 3.10 Keybindings, Completions & Cross-Tool Integration

### 3.10.1 Keybinding Consistency

**Goal**: consistent h/j/k/l navigation across the entire terminal stack. Space-as-leader
is only available in tmux (and neovim, already configured) — TUI tools don't have the
"leader" concept. For tools without vi-mode, document the alternative keys in `cheat`.

**Vim-mode capability per tool:**

| Tool | Vi-mode | Config | h/j/k/l | Notes |
|------|---------|--------|---------|-------|
| zsh | ✓ | `bindkey -v` + `KEYTIMEOUT=1` | N/A (line editing) | `jj` escape to normal mode |
| nushell | ✓ | `edit_mode: vi` in config.nu | N/A | Same jj escape via keybinding |
| tmux | ✓ | `setw -g mode-keys vi` | ✓ (copy mode) | Space as leader available but we keep prefix C-a |
| neovim | ✓ | Already configured | ✓ | Space as leader (LazyVim default) |
| yazi | ✓ (native) | keymap.toml fully customisable | ✓ (default) | Most vim-friendly TUI |
| lazygit | ✓ (implicit) | keybinding section in config.yml | ✓ (default) | Already configured with h/j/k/l |
| gh-dash | ✓ (overridable) | keybindings section | ✓ (default) | g/G, ctrl-d/u supported |
| lnav | ✓ (native) | Fixed | ✓ (default) | Default j/k/h/l, / for search |
| television | No vi-mode, but configurable | config.toml [keybindings] | ✓ (via ctrl-j/k default) | We add j/k bindings explicitly |
| k9s | No vi-mode | hotkeys.yaml | Partial | Customisable hotkeys, not full vi-mode |
| atuin | No vi-mode (auto keymap from shell) | Limited | N/A | Emacs-style but inherits shell vi-mode if configured |
| btop | No vi-mode | Fixed (arrow keys) | No | Document alternative keys in cheat |
| jqp | No vi-mode | Fixed | Partial | Tab navigation between panels |
| sesh | N/A | tmux-dependent | N/A | Sesh is CLI picker, navigation is fzf-based |
| diffnav | TBD | TBD | TBD | Docs sparse — verify at install time |

**Leader key strategy:**
- **Space** → neovim (existing)
- **Ctrl-A** → tmux (existing — not changing to space to preserve bash/CI muscle memory)
- **No universal leader** in TUI land — each tool has its own top-level key

This is a realistic constraint; forcing space-as-leader everywhere isn't possible.
Instead we add `cheat <tool>` entries documenting each tool's navigation patterns.

### 3.10.2 Completions Matrix

**Zsh completions** (exact init/command per tool):

| Tool | Completion Method | Command |
|------|-------------------|---------|
| atuin | Bundled with init | `eval "$(atuin init zsh)"` |
| television | Bundled with init | `eval "$(tv init zsh)"` |
| zoxide | Bundled with init | `eval "$(zoxide init zsh)"` |
| mise | Separate file (in fpath) | `mise completion zsh > $HOMEBREW_PREFIX/share/zsh/site-functions/_mise` |
| starship | Init only (no completions) | `eval "$(starship init zsh)"` |
| direnv | Hook only (no completions) | `eval "$(direnv hook zsh)"` |
| gh | `gh completion -s zsh` | Sourced in .zshrc section 10 |
| sesh | Separate command | `source <(sesh completion zsh)` |
| xh | Static file generation | `xh --generate complete-zsh > _xh` (placed in fpath) |
| rip2 | Separate command | `rip2 completions zsh > _rip2` (placed in fpath) |
| fd | Static file (bundled with package) | `$HOMEBREW_PREFIX/share/zsh/site-functions/_fd` |
| ripgrep | Generated | `rg --generate complete-zsh > _rg` (placed in fpath) |
| bat | Static file (bundled with package) | Automatic via fpath |
| eza | Static file (bundled with package) | `FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"` |
| carapace | Self-contained | `source <(carapace --shell zsh --script)` |
| cog (cocogitto) | Generated | `eval "$(cog generate-completions zsh)"` |
| uv | Generated | `eval "$(uv generate-shell-completion zsh)"` |
| yazi | No native completion | Use carapace bridge |
| jqp | No native completion | Use carapace bridge |
| diffnav | No native completion | Use carapace bridge |
| gh-dash | Via gh extension | `gh completion -s zsh` covers it |

**Nushell completions** (native init + carapace fallback):

| Tool | Native Init | Carapace Bridge |
|------|-------------|-----------------|
| atuin | `atuin init nu` (bundled completions) | N/A |
| television | `tv init nu` (shell integration) | Partial — carapace covers `tv` command flags |
| starship | `starship init nu` (0.96+) | N/A |
| zoxide | `zoxide init nushell` | N/A |
| mise | `mise activate nu` | Yes — for subcommand completion |
| gh | `gh completion -s nu` | Yes |
| rip2 | Generated via clap | Yes |
| carapace | `carapace _carapace nushell` | Self |
| sesh | No native | No — not in carapace |
| yazi | No native | Yes (via carapace) |
| xh | No native | Yes |
| jqp | No native | Unlikely |
| diffnav | No native | Unlikely |
| direnv | pre_prompt hook | Yes (for subcommand completion) |
| bat/eza/fd/ripgrep | None (utilities) | Yes (all covered by carapace) |

**Key principle**: carapace is the completion backstop in nushell. For every tool
without native nushell support, carapace's bridging (via `CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'`)
provides completion. ~1000+ tools are supported by carapace-bin directly.

**Implementation**: in both .zshrc section 10 and nushell config.nu, add all completion
sources in a consistent order. For nushell, use the external_completer pattern:

```nu
let carapace_completer = {|spans|
    carapace $spans.0 nushell ...$spans | from json
}
$env.config.completions.external = {
    enable: true
    max_results: 100
    completer: $carapace_completer
}
```

### 3.10.3 Cross-Tool Integrations

The tools compose in several ways. Document the integrations that add real value;
avoid forcing integrations where composition at shell level is cleaner.

**Tmux ecosystem:**
- **sesh + tmux-sessionx — complementary, keep both**: sesh is a CLI session manager
  (`sx <Tab>` at shell prompt); sessionx is an in-tmux plugin (`prefix+o`). Different
  entry points, same goal.
- **sesh + zoxide — automatic**: `sesh list -z` includes zoxide entries. `sort_order`
  in sesh.toml controls priority; `blacklist` excludes unwanted paths. No init needed.
- **sesh windows — define in config**: `[[window]]` blocks in sesh.toml let sesh launch
  tools in dedicated tmux windows on session creation. Example:
  ```toml
  [[session]]
  name = "dotfiles"
  path = "@DOTFILES@"
  windows = ["editor", "git", "files"]

  [[window]]
  name = "editor"
  startup_script = "nvim"

  [[window]]
  name = "git"
  startup_script = "lazygit"

  [[window]]
  name = "files"
  startup_script = "yazi"
  ```
- **gh-dash → lazygit — confirmed pattern**: `command: "cd {{.RepoPath}} && lazygit"`.
  Go template substitution for `{{.RepoPath}}`.
- **television in tmux popups**: no native awareness, but works in any pane.
  Optional binding: `bind-key T display-popup -E -w 80% -h 80% tv`
- **yazi/lazygit in tmux-floax**: no special integration. Launch normally; floax just
  provides the floating pane.

**Git / GitHub ecosystem:**
- **diffnav wraps delta, not replaces it**: `pager.diff: diffnav` in gh-dash gives
  you a file-tree navigation UI on top of delta's rendering. Delta still does the
  syntax highlighting via bat themes.
- **lazygit + delta**: configured via lazygit's `git.paging` section (existing):
  ```yaml
  git:
    paging:
      colorArg: always
      pager: delta --paging=never --syntax-theme=Dracula
  ```
  Delta's `--hyperlinks-file-link-format="lazygit-edit://{path}:{line}"` enables
  clickable paths that open files in the editor — worth adding.
- **lazygit + diffnav**: theoretically `pager: diffnav --paging=never` works but
  undocumented. Stay with delta inside lazygit for now.
- **delta + bat themes**: delta reads bat's bundled themes. `syntax-theme = Dracula`
  in gitconfig works because bat ships Dracula as a built-in theme.
- **git-cliff + cocogitto — complementary**: cocogitto enforces conventional commits
  and manages semver (`cog commit`, `cog bump`); git-cliff generates the changelog
  (`git cliff -o CHANGELOG.md`). Workflow: cocogitto drives release versioning,
  git-cliff drives release notes. Keep both.
- **television git cable channels**: all 10 channels (branch, diff, log, stash,
  worktrees, reflog, remotes, repos) confirmed working with git CLI.
- **atuin workspaces**: `workspaces = true` filters history to the current git repo
  tree. Not worktree-aware (each worktree is a separate filesystem root) — but that's
  often what you want: per-worktree history scope.

**Navigation / file / content ecosystem:**
- **FZF + fd + bat — standard pattern**:
  ```bash
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  # preview via bat
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
  ```
  Already 80% configured in existing .bashrc. Add the `--preview` opt for bat
  integration and port to .zshrc + nushell.
- **television previews use shell commands**: in cable channel `[preview]` sections,
  use `bat --color=always '{}'` for file previews. BAT_THEME env var respected
  because the command inherits shell env.
- **yazi + zoxide**: not automatic; requires yazi plugin from the community
  (`github.com/yazi-rs/plugins/zoxide.yazi`). Adds `z` command inside yazi to jump
  to zoxide entries.
- **yazi + bat/fd/ripgrep**: yazi uses these if installed. bat is used for file
  preview automatically (when yazi detects it). fd and rg power the built-in
  search (`/` key for fuzzy search).
- **direnv + mise — complementary, not interoperable**:
  - direnv reads `.envrc` (shell code; flexible)
  - mise reads `.mise.toml` and `.tool-versions` (tool versions; structured)
  Both can coexist in the same project. Keep both in shell init.
- **atuin + zoxide**: independent databases. `filter_mode_shell_up_key_binding = "directory"`
  uses atuin's own directory metadata (captured per-command), not zoxide's frecency.

### 3.10.4 Integration Wiring Decisions

Decisions incorporated into the design based on the research:

1. **Sesh config**: Add `[[window]]` definitions for editor (nvim), git (lazygit),
   files (yazi) — auto-launches tools per session.
2. **gh-dash keybinding**: Add `C` for "open PR in opencode via tmux new-window"
   (omerxx's pattern, adapted for our workflow).
3. **Lazygit delta config**: Add `--hyperlinks-file-link-format` for clickable paths.
4. **Television cable previews**: Use `bat --color=always` in all file/text previews
   to inherit BAT_THEME (Dracula).
5. **Yazi zoxide plugin**: Install `yazi-rs/plugins/zoxide.yazi` via yazi's plugin
   system (to be set up in yazi config).
6. **Carapace bridging**: Set `CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'` in
   both zsh and nushell to maximise completion coverage.
7. **Zsh completion order**: fpath-based completions (bat, eza, fd) registered via
   compinit; generated completions (mise, rg, xh, rip2, uv, cog) sourced after.

## 3.11 Repo Organisation (ghq + ghorg)

GOPATH-style local checkout layout, enforced by tooling. Solves the
"where-did-I-clone-that" pain point and makes bulk org cloning predictable.

### 3.11.1 Layout

All git checkouts live under `~/code/<host>/<org>/<repo>`. Examples:
- `~/code/github.com/anthropics/claude-code`
- `~/code/gitlab.com/some-org/service`
- `~/code/gitlab.mycompany.com/team/repo`

Single root, single git identity (no work/personal split).

### 3.11.2 Tools

| Tool | Source | Purpose |
|------|--------|---------|
| `ghq` | brew (`ghq`) | Replaces `git clone`. Enforces the `<host>/<org>/<repo>` layout. |
| `ghorg` | brew (`ghorg`) | Bulk-clones whole GitHub/GitLab orgs. Used occasionally. |

Both available via Homebrew on macOS and Linuxbrew on WSL2.

### 3.11.3 git/.gitconfig

Add to the tracked `git/.gitconfig`:

```ini
[ghq]
  root = ~/code
```

NOT in `~/.gitconfig.local` — `ghq.root` is structural, not personal.

### 3.11.4 Shell functions (bash and zsh — always-on)

```bash
# Interactive repo picker — Alt-R binding
repo() {
  local dir
  dir=$(ghq list --full-path | fzf --preview 'ls -la {}') && cd "$dir" || return
}

# Clone-and-go: ghq get + cd to the resolved canonical path
gclone() {
  if ghq get -u "$1"; then
    local target
    target="$(ghq list -e -p "$1" 2>/dev/null | head -1)"
    if [[ -n "$target" && -d "$target" ]]; then
      cd "$target"
    else
      echo "ghq: cannot resolve path for '$1'" >&2
      return 1
    fi
  fi
}

# Bulk-clone a GitHub org into the ghq tree
ghorg-gh() {
  local org="$1"; shift
  ghorg clone "$org" --path ~/code/github.com "$@"
}

# Alt-R binding for repo
bind '"\er":"repo\n"'    # bash
# zsh equivalent: bindkey -s '^[r' 'repo\n'
```

`ghq list -e -p <ref>` returns the canonical path for an exact match (URL,
`host/org/repo`, or `org/repo`), avoiding the false-match risk of substring
search. The guard ensures a failed lookup does not `cd` somewhere wrong.

### 3.11.5 ghorg ↔ ghq interop

ghorg's default output is `~/ghorg/<org>/<repo>` — flat, no host level — which
breaks the ghq layout. Always invoke ghorg with `--path` pointing at the
correct host directory:

```bash
# GitHub org
ghorg clone myorg --path ~/code/github.com

# Self-hosted GitLab (with subgroup preservation)
ghorg clone myorg --scm gitlab --base-url https://gitlab.myco.com \
  --path ~/code/gitlab.myco.com --preserve-dir
```

Notes:
- Do NOT pass `--output-dir` (renames the org folder, breaks ghq's expected
  `<org>` level).
- After ghorg finishes, `ghq list` discovers new clones automatically (ghq
  walks the filesystem under `ghq.root`).
- Use `--clone-protocol=ssh` for SSH cloning.

### 3.11.6 WSL2 critical rule

`~/code` MUST live on the Linux ext4 filesystem (under `~`), NEVER under
`/mnt/c/`. 9P-mounted Windows paths are ~10× slower for git operations.

`install-wsl.sh` MUST hard-abort if `$HOME` resolves under `/mnt/c/` (or if
`~/code` is somehow already symlinked there). Manual install step (one-time):
add `\\wsl$\Ubuntu\home\<user>\code` to Windows Defender exclusions.

### 3.11.7 AI coding-tool convention

Both supported coding agents (OpenCode and GitHub Copilot Coding Agent inside
VS Code) honour `~/AGENTS.md` per the emerging cross-vendor spec. Add a
"Local repo layout" section to a tracked file at `agents/AGENTS.md.snippet`
plus a one-shot installer `scripts/install-ai-conventions.sh` that appends
the snippet to `~/AGENTS.md` if not already present.

Snippet content (verbatim):

```markdown
## Local repo layout

Clone git repos via `ghq get <url>` — never plain `git clone`. The repo root
is `~/code` and the enforced layout is `<host>/<org>/<repo>`. For bulk-cloning
an org, use `ghorg clone <org> --path ~/code/<host>` so repos land inside the
ghq tree. On WSL2 never clone into `/mnt/c/...`.

To navigate to an existing checkout, prefer `cd "$(ghq list -e -p <ref>)"` or
the interactive `repo` function (Alt-R) over `cd ~/code/...` paths.
```

The installer is a separate script (not auto-run in install-macos.sh /
install-wsl.sh) because `~/AGENTS.md` may be user-curated and merging into
it requires user consent.

### 3.11.8 Verification

- `ghq root` prints `$HOME/code`.
- `ghq get github.com/anthropics/claude-code` lands at `~/code/github.com/anthropics/claude-code`.
- `repo` opens an fzf picker listing all ghq-managed repos.
- `ghorg clone <small-test-org> --path ~/code/github.com` drops repos in
  `~/code/github.com/<test-org>/` and `ghq list` shows them.
- `bind -P | grep '"\er"'` shows the Alt-R binding.

## 4. Implementation Layers

### Layer 1a: Keybinding Changes (atuin + television only)

The smallest possible change that replaces Ctrl-R and Ctrl-T behaviour:
1. Brewfile + tools.txt: add atuin, television
2. atuin/config.toml
3. television/config.toml (main config only — cable channels come in 1b)
4. Zsh tool evals for atuin + television (or bash evals gated behind env var)
5. Starship palette update (visual refresh, no behaviour change)
6. install-macos.sh + install-wsl.sh symlink additions for atuin + television
7. Verification: Ctrl-R opens atuin, Ctrl-T opens television files channel

**Stabilise here.** Get comfortable with the new Ctrl-R/Ctrl-T before adding more.

### Layer 1b: Remaining Shell-Agnostic Tools

Everything else that doesn't require a shell change:
1. Brewfile + tools.txt: sesh, yazi, xh, rip, rip2, jqp, diffnav, carapace (gh-dash via gh extension, not brew)
2. Television cable channels (all 30+ TOML files) — `git-repos.toml` MUST source from
   `ghq list --full-path` (forward-references Layer 1c; channel is broken until 1c lands
   but the file lives in 1b for cohesion with the other channels)
3. TPM + all tmux plugin configuration
4. sesh, yazi, gh-dash configs
5. New aliases (http, rrip, jqi, ghd, dn, sx, y)
6. `cheat` function updated with new tool subcommands
7. `cheatsheet.md` updated
8. install-macos.sh + install-wsl.sh: TPM clone, gh-dash extension, symlinks
9. Verification: all tools functional, tmux plugins installed

### Layer 1c: Repo Organisation (ghq + ghorg)

Self-contained capability. Sits between Layer 1b (tools) and Layer 2 (zsh).
Doesn't block 1b or 2 — can run in parallel with planning.

1. Brewfile + tools.txt: ghq, ghorg
2. git/.gitconfig: add `[ghq] root = ~/code`
3. bash/.bashrc (or .bash_aliases): always-on `repo()`, `gclone()`, `ghorg-gh()` functions
4. Alt-R binding for `repo` in bash readline (`bind '"\er":"repo\n"'`)
5. install-macos.sh + install-wsl.sh: link git/.gitconfig already in place; add ghq/ghorg
   to install verification step
6. install-wsl.sh: hard-abort precondition if `$HOME` is under `/mnt/c/`
7. agents/AGENTS.md.snippet (tracked): "Local repo layout" convention text
8. scripts/install-ai-conventions.sh: appends snippet to `~/AGENTS.md` if not present (idempotent)
9. docs/cheatsheet.md: rows for `repo`, `gclone`, `ghorg-gh`, Alt-R chord
10. README.md: short "Repo layout" section
11. scripts/verify.sh: smoke-check ghq root + ghorg PATH + git config
12. scripts/test-plan-layer1c.sh: ATDD with ACs for: ghq.root config, install symlink,
    function defined, Alt-R bound, WSL precondition trips correctly under simulated
    `/mnt/c/` HOME, AGENTS.md snippet idempotency.

Forward dependencies: Layer 1b's `git-repos.toml` channel becomes functional once
Layer 1c lands.

### Layer 2: Zsh as Interactive Shell

1. zsh/.zshrc (15-section structure)
2. zsh/.zsh_aliases (ported from bash, new tool aliases, fh removed)
3. zsh-autosuggestions + zsh-syntax-highlighting (brew install + platform-conditional source)
4. All tool inits ported to zsh
5. install scripts updated: symlinks, `chsh` instruction uses `$(which zsh)`
6. Verification: all tools functional in zsh, vi-mode, autosuggestions, syntax highlighting

### Layer 3: Nushell as First-Class Secondary

1. nushell/env.nu (PATH, cached init generation with mkdir, env vars)
2. nushell/config.nu (theme, vi-mode, completions, hooks, keybindings, aliases)
3. carapace init for cross-shell completions
4. All tool inits (atuin, television, zoxide, mise, starship, direnv) via cached files
5. yazi cd-on-quit nushell wrapper
6. Nushell-specific aliases (no `ls` alias, structured data patterns)
7. install scripts updated: symlinks for nushell configs
8. Verification: all tools functional in nushell

### Layer 4: Evaluate & Consolidate (future)

1. Log tooling evaluation (gonzo or alternatives) — depends on hands-on testing with
   GCP Cloud Logging output formats and GitHub Actions log structure
2. Trunk vs individual linters — depends on CI pipeline compatibility testing
   (Trunk may not play well with existing prek + GitHub Actions workflows)
3. Television channel refinement based on daily use

### Decisions Resolved at Plan Time

**Stow vs link() helper → Keep link().**
Stow requires the dotfiles directory structure to mirror the target XDG layout exactly
(e.g., `atuin/.config/atuin/config.toml`). Our repo uses flat structures
(e.g., `atuin/config.toml`) with link() mapping arbitrary source → dest. Restructuring
the entire repo for stow gains nothing — link() already handles backup/restore, is
tested across macOS and WSL2, and supports non-XDG targets (e.g., `~/.tmux.conf`,
`~/.gitconfig`). No change.

**Tmux theme → Dracula tmux plugin (replaces manual theme).**
The earlier decision to keep the manual catppuccin theme is reversed. Dracula has an official,
well-maintained tmux TPM plugin (`dracula/tmux`, 76k+ views). This replaces the 4-line manual
hex theme and provides a richer status bar with segments (git, time, etc.) that matches the
Dracula palette across all tools.

**Atuin sync → Disabled, with self-hosted documentation.**
`auto_sync = false` in config. The design documents how to enable sync:
- Self-hosted: `sync_address = "https://your-server.example.com"`, `auto_sync = true`
- Cloud (atuin.sh): `sync_address = "https://api.atuin.sh"`, `auto_sync = true`
- E2E encryption key at `~/.local/share/atuin/key` — never synced
This is a personal opt-in decision, not a dotfiles default.

**TPM plugin pinning → Not pinned, manual updates only.**
TPM clones from default branch (main/master). Plugin updates are manual (`prefix + U`).
The plugins are well-established community projects with thousands of stars. Pinning to
commit SHAs adds maintenance burden (must manually bump SHAs) for marginal security gain.
If a plugin is compromised, the broader tmux community would flag it quickly.
Future option: vendor plugins into the dotfiles repo if supply chain becomes a concern.

**sesh config paths → Template substitution at install time.**
sesh.toml `path` field requires absolute paths (per schema: "Absolute path to the
session's working directory"). No env var expansion. The install script generates
`sesh.toml` from `sesh/sesh.toml.tmpl`, substituting `@DOTFILES@` → `$DOTFILES`
and `@HOME@` → `$HOME` at install time (same pattern as the podman LaunchAgent plist).

**tmux-sessionx config keys → Confirmed, with adjusted defaults.**
All `@sessionx-*` keys confirmed in official docs. Adjustments from omerxx's config:
- `@sessionx-bind 'o'` — confirmed (default is `'O'`, we lowercase it)
- `@sessionx-zoxide-mode 'on'` — confirmed (default is `'off'`, we enable it)
- `@sessionx-filter-current 'false'` — confirmed (default is `'true'`, we show current)
- `@sessionx-window-height '85%'` — confirmed (default is `'90%'`)
- `@sessionx-window-width '75%'` — confirmed (default is `'75%'`)

**jqp config → Managed in dotfiles.**
jqp supports `~/.jqp.yaml` for theme customisation. Add `jqp/` directory with config:
```yaml
theme: dracula
```
Symlinked to `~/.jqp.yaml`. Add to section 2.5 symlink mapping.

**diffnav config → Managed in dotfiles.**
diffnav supports `~/.config/diffnav/config.yml`. Add `diffnav/` directory with config.
Symlinked to `~/.config/diffnav/config.yml`. Add to section 2.5 symlink mapping.

**GCP television channels → Defined now, refined later.**
Channel structure decided. Exact commands may need tuning once tested against live
GCP environments. Initial channels:

- `gcloud-configs.toml`: source `gcloud config configurations list --format='value(name,properties.core.project)'`,
  action: activate configuration
- `gcloud-instances.toml`: source `gcloud compute instances list --format='value(name,zone,status)'`,
  action: ssh, start, stop
- `gcloud-run-services.toml`: source `gcloud run services list --format='value(name,region,status)'`,
  action: describe, logs, open URL
- `gcloud-sql.toml`: source `gcloud sql instances list --format='value(name,region,state)'`,
  action: connect via cloud-sql-proxy

These are added in Layer 1b with the other cable channels. Refinement happens in Layer 4
based on daily use.

## 5. Install Script Changes

### install-macos.sh

New in Step 2 (post-brew):
```bash
# TPM (tmux plugin manager)
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  log "installing TPM"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" || warn "TPM clone failed"
fi

# gh-dash extension
if command -v gh &>/dev/null; then
  gh extension install dlvhdr/gh-dash 2>/dev/null || true
fi
```

New in Step 3 (symlinks): All link() calls from section 2.5.

Updated Step 4 (next steps):
```
Post-install:
  1. Switch shell to zsh:
       echo "$(which zsh)" | sudo tee -a /etc/shells
       chsh -s "$(which zsh)"
  2. Install tmux plugins (first tmux launch):
       prefix + I  (Ctrl-A then Shift-I)
     Note: tmux-thumbs requires a Rust toolchain to compile.
     If compilation fails, install from GitHub releases:
       https://github.com/fcsonline/tmux-thumbs/releases
  3. Login to atuin (optional, for sync):
       atuin login
  ...existing steps...
```

### install-wsl.sh

Equivalent changes. For tools without apt packages (television, sesh, yazi, jqp,
diffnav, carapace), a `gh_release_install()` helper function downloads
architecture-specific binaries (aarch64/x86_64) from GitHub Releases to `~/.local/bin`.

```bash
# gh_release_install <owner/repo> <binary-name> [<asset-pattern>]
# Downloads the latest release binary matching the current arch.
gh_release_install() {
  local repo="$1" binary="$2" pattern="${3:-}"
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64)  arch_pattern="${pattern:-linux.*x86_64}" ;;
    aarch64) arch_pattern="${pattern:-linux.*aarch64}" ;;
    *)       warn "unsupported arch $arch for $binary"; return 1 ;;
  esac
  # ... download logic using gh api or curl ...
}
```

## 6. Cross-Platform Considerations

| Tool | macOS (brew) | WSL/Linux (apt) | Container (apk) |
|------|-------------|-----------------|-----------------|
| zsh | `brew install zsh` | `apt install zsh` | `apk add zsh` |
| nushell | `brew install nushell` | gh_release_install | `apk add nushell` (edge) |
| atuin | `brew install atuin` | Install script / gh_release | `apk add atuin` (edge) |
| television | `brew install television` | gh_release_install | gh_release_install |
| carapace | `brew install carapace` | gh_release_install | gh_release_install |
| sesh | `brew install sesh` | gh_release_install | gh_release_install |
| yazi | `brew install yazi` | gh_release_install | gh_release_install |
| xh | `brew install xh` | `apt install xh` | `apk add xh` |
| rip | `brew install cesarferreira/tap/rip` | gh_release_install | gh_release_install |
| rip2 | `brew install rip2` | gh_release_install | gh_release_install |
| jqp | `brew install jqp` | gh_release_install | gh_release_install |
| diffnav | `brew install dlvhdr/formulae/diffnav` | gh_release_install | gh_release_install |
| gh-dash | gh extension | gh extension | gh extension |
| zsh-autosuggestions | `brew install` | `apt install` | `apk add` |
| zsh-syntax-highlighting | `brew install` | `apt install` | `apk add` |

tools.txt updated with all new entries following existing format:

```
# ── Shell (updated) ─────────────────────────────────────────────────────
zsh                  brew:zsh                       apt:zsh                 apk:zsh
nushell              brew:nushell                   apt:-                   apk:nushell
carapace             brew:carapace                  apt:-                   apk:-

# ── History & search (new) ──────────────────────────────────────────────
atuin                brew:atuin                     apt:-                   apk:atuin
television           brew:television                apt:-                   apk:-

# ── Session management (new) ────────────────────────────────────────────
sesh                 brew:sesh                      apt:-                   apk:-

# ── File management (new) ──────────────────────────────────────────────
yazi                 brew:yazi                      apt:-                   apk:-

# ── Data wrangling (new) ───────────────────────────────────────────────
xh                   brew:xh                        apt:xh                  apk:xh
jqp                  brew:jqp                       apt:-                   apk:-

# ── Utilities (new) ────────────────────────────────────────────────────
rip                  brew:cesarferreira/tap/rip      apt:-                   apk:-
rip2                 brew:rip2                      apt:-                   apk:-
diffnav              brew:dlvhdr/formulae/diffnav    apt:-                   apk:-

# ── Zsh plugins ────────────────────────────────────────────────────────
zsh-autosuggestions      brew:zsh-autosuggestions    apt:zsh-autosuggestions  apk:zsh-autosuggestions
zsh-syntax-highlighting  brew:zsh-syntax-highlighting apt:zsh-syntax-highlighting apk:zsh-syntax-highlighting
```

## 7. Security

### 7.1 History & Secret Filtering

- Atuin `secrets_filter = true` enables built-in detection of AWS keys, GitHub PATs,
  Slack tokens, and Stripe keys
- Custom `history_filter` adds patterns for raw token prefixes (ghp_, gho_, github_pat_,
  glpat-, sk-, xoxb-, xoxp-) and variable-assignment patterns matching existing HISTIGNORE
- Atuin sync **disabled by default** (`auto_sync = false`). Opt-in only, with documentation
  of encryption model and self-hosting option
- Nushell history stored as plaintext SQLite — document this limitation and recommend
  using atuin as the primary history search (which has its own filtered database)

### 7.2 Television Cable Channel Safety

- All channels that pass user-selected input to commands use single-quoted placeholders
  and `--` argument separators where applicable
- The `env.toml` channel excludes lines matching sensitive variable patterns before display
- Channels that execute destructive commands (git reset --hard, kubectl delete, docker rm)
  require explicit action picker (`Ctrl-X`) rather than Enter

### 7.3 rip2 Graveyard

- Default graveyard set to `$HOME/.local/share/graveyard` (not /tmp) via
  `RIP_GRAVEYARD` environment variable in shell configs
- Home directory has 700 permissions by default — no multi-user exposure risk
- rip2 (`brew install rip2`) is the maintained fork — NOT cesarferreira/rip (which is a process killer)

### 7.4 TPM Plugin Supply Chain

- TPM clones plugins over HTTPS from GitHub
- Plugins are NOT pinned to commit SHAs in the initial design (matches omerxx's approach)
- Future consideration: pin to tags or vendor into dotfiles repo
- Risk is mitigated by: plugins are well-known community projects, TPM updates are
  manual (`prefix + U`), and tmux config is version-controlled

### 7.5 PATH Ordering

- `~/.bun/bin` placed AFTER `$HOMEBREW_PREFIX/bin` and system paths
- `~/.local/bin` prepended (contains user-installed tools like gh_release_install targets)
- Mise shims are in PATH but mise itself validates tool sources

## 8. Discoverability

### 8.1 cheat Function Updates

New subcommands added to `cheat`:

```
cheat atuin       → atuin keybindings, search modes, filter modes
cheat tv          → television channels, shell triggers, Ctrl-T behaviour
cheat sesh        → sesh commands, tmux integration
cheat yazi        → yazi keybindings, shell integration (y for cd-on-quit)
cheat xh          → xh vs httpie syntax, common usage
cheat rip         → rip (fuzzy process killer) usage
cheat rip2        → rip2 (safe rm) usage, undo (rrip), graveyard location
cheat jqp         → jqp usage, interactive jq
cheat ghd         → gh-dash keybindings, sections, pager
cheat diffnav     → diffnav usage, navigation keys
cheat tmux-plugins → all tmux plugin keybindings:
                     prefix+Space (thumbs), prefix+p (floax),
                     prefix+o (sessionx), prefix+F (fzf),
                     prefix+u (fzf-url)
```

### 8.2 cheatsheet.md Updates

- Ctrl-R relabelled from "fzf history" to "atuin history search"
- Ctrl-T relabelled from "fzf file finder" to "television smart autocomplete"
- New section: tmux plugin keybindings
- New section: television channel triggers (which commands trigger which channels)

### 8.3 Nushell aliases Function

A nushell-compatible `aliases` command:
```nu
def aliases [filter?: string] {
  if $filter != null {
    scope aliases | where name =~ $filter
  } else {
    scope aliases
  }
}
```

## 9. Testing Strategy

Each layer has verification steps:

**Layer 1a verification:**
- `atuin history list` returns entries
- `tv` opens television with file channel
- Ctrl-R at shell prompt opens atuin (verify with `bindkey '^R'` in zsh)
- Ctrl-T at shell prompt opens television files channel
- Starship prompt renders with Dracula colours

**Layer 1b verification:**
- `tv git-branch` opens branch picker (inside a git repo)
- `git checkout <Ctrl-T>` opens branch channel (shell integration)
- tmux `prefix + I` installs plugins successfully
- `prefix + Space` (thumbs) highlights patterns on screen
- `prefix + p` (floax) opens floating pane
- `prefix + o` (sessionx) opens session picker
- `prefix + u` (fzf-url) picks URLs from scrollback
- `sx` connects to/creates a sesh session
- `y` opens yazi, cd-on-quit works
- `ghd` opens gh-dash
- `xh httpbin.org/get` returns JSON
- `rip` opens fuzzy process killer
- `rip2` moves files to ~/.local/share/graveyard, `rrip` (`rip2 -u`) restores
- `jqi` opens jqp playground
- `cheat tv` shows television help

**Layer 2 verification:**
- `echo $SHELL` shows zsh path
- All aliases work (`gs`, `lg`, `v`, `ll`, `http`, `sx`, etc.)
- Ctrl-R opens atuin, Ctrl-T opens television (same as Layer 1)
- Vi-mode works (jj exits insert, k/j navigate history)
- Autosuggestions appear as ghost text
- Syntax highlighting colours commands (green=valid, red=invalid)
- `cheat` function works with all new subcommands
- `.zshrc.local` overrides load

**Layer 3 verification:**
- `nu` launches nushell
- `ls` returns structured table data (NOT eza — native nushell)
- `ll`, `la`, `lt` use eza
- Ctrl-R opens atuin, Ctrl-T opens television
- Vi-mode works (jj exits insert)
- `y` opens yazi, cd-on-quit works in nushell
- carapace completions work for external commands
- starship prompt renders
- direnv loads .envrc on directory change

## 10. Deferred Decisions

- **Trunk vs individual linters**: Evaluate after Layer 2. Trunk may replace prek +
  shellcheck + shfmt + markdownlint-cli2 + actionlint, but needs testing against CI
  pipeline compatibility.
- **Stow vs link()**: Evaluate after all configs stable. Current link() has backup/restore
  that stow doesn't. Stow requires XDG-native directory structure.
- **GCP/Terraform/GHA television channels**: Build after daily use of television
  establishes patterns.
- **Log tooling (gonzo etc.)**: Research separately — this is a workflow problem, not
  just a tool install.
- **Dracula tmux plugin configuration**: Refine plugin segments and options based on daily use.
- **Atuin sync**: Start with disabled. Evaluate self-hosted vs atuin.sh cloud after
  security review of encryption model.
- **TPM plugin pinning**: Evaluate after initial adoption. If supply chain risk is
  a concern, pin to tags or vendor plugins.

## Appendix A: Adversarial Review Findings & Resolutions

### UX Review
| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | Critical | Ctrl-R triple-claim (fzf→television→atuin) | Television no longer claims Ctrl-R in shell integration. Atuin is sole owner. |
| 2 | High | Ctrl-T collision inside/outside television | Internal toggle_layout rebound to Ctrl-Shift-T. Documented in cheat. |
| 3 | High | Discoverability not extended for new tools | cheat updated with 10 new subcommands. cheatsheet.md updated. |
| 4 | High | 10 tmux plugins installed blind | Sensible overlaps enumerated. Plugin keybindings in cheat tmux-plugins. |
| 5 | Medium | Layer 1 too large | Split into Layer 1a (keybinding changes only) and 1b (everything else). |
| 6 | Medium | PR review workflow gap | End-to-end workflow documented in gh-dash section. |
| 7 | Medium | Nushell ls alias collision | ls NOT aliased in nushell. Native structured ls preserved. |
| 8 | Low | No rollback for Layer 1 bash changes | Bash atuin/television inits gated behind ENABLE_ATUIN/ENABLE_TV env vars. |

### Consistency Review
| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | Critical | Section count: "13" vs 14 listed | All references updated to 14. |
| 2 | Critical | Television claims Ctrl-R it shouldn't own | Removed from shell_integration.keybindings. |
| 3 | Critical | tools.txt entries missing for new tools | Concrete tools.txt entries provided in Section 6. |
| 4 | High | httpie/xh conflict | Both kept. xh aliased as http. httpie stays for team compat. |
| 5 | High | fh alias not removed | fh removed from zsh aliases. Replaced by atuin Ctrl-R. |
| 6 | High | atuin init path inconsistency | All nushell inits use ~/.cache/ pattern, including atuin. |
| 7 | Medium | Missing carapace symlinks | Documented: carapace needs no config file. |
| 8 | Medium | rip alias no-op | Self-alias removed. Only rrip (undo) alias kept. |
| 9 | Medium | ss alias collides with Linux ss | Renamed to sx (sesh connect) and sxl (sesh list). |
| 10 | Medium | tmux sensible overlap not enumerated | Specific removed settings listed in Section 3.6. |
| 11 | Low | TV internal Ctrl-T confusion | Rebound to Ctrl-Shift-T. |
| 12 | Low | Nushell atuin init path | Added to cache generation step in env.nu. |

### Cross-Platform Review
| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | Critical | WSL2 clipboard broken for TV/tmux | tmux set-clipboard on. tmux-yank auto-detects clip.exe on WSL2. |
| 2 | Critical | Alpine container install undefined | gh_release_install() helper specified in install-wsl.sh. |
| 3 | High | Zsh plugin source paths differ across platforms | Platform-conditional probe of multiple paths in .zshrc Section 5. |
| 4 | High | chsh path not portable | Changed to $(which zsh). |
| 5 | High | XDG_CONFIG_HOME never set | Exported with default in .zshrc Section 3 and env.nu. |
| 6 | High | macOS ships old zsh | Version guard added to .zshrc Section 1. |
| 7 | Medium | procs.toml GNU-specific ps flags | Uses POSIX-compatible ps -e -o flags. |
| 8 | Medium | git-repos fd excludes macOS paths | Uses fd --exclude flags (harmless no-ops on Linux). |
| 9 | Medium | Nushell cache dirs don't exist on first launch | mkdir before each save in env.nu. |
| 10 | Medium | tmux-thumbs needs Rust toolchain | Documented in post-install steps with binary fallback. |
| 11 | Low | sesh path hardcoded | Uses $DOTFILES or template substitution. |
| 12 | Low | Nushell OSC 7 on WSL2 | Flagged for testing. Platform-conditional if needed. |

### Security Review
| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | Critical | Token prefixes not in history_filter | Added ghp_, gho_, github_pat_, glpat-, sk-, xoxb-, xoxp_ patterns. |
| 2 | High | Atuin syncs to third-party by default | auto_sync = false. Opt-in only with documentation. |
| 3 | High | TV cable channels command injection risk | Single-quoted placeholders and -- separators in all channels. |
| 4 | High | rip graveyard in /tmp exposes files | GRAVEYARD set to ~/.local/share/graveyard. |
| 5 | Medium | TPM plugins not pinned | Documented as future consideration. Manual updates only. |
| 6 | Medium | env cable channel exposes secrets | Exclusion filter for sensitive variable patterns. |
| 7 | Medium | PATH ordering allows binary shadowing | ~/.bun/bin placed after system paths. |
| 8 | Low | Nushell plaintext history | Documented. Atuin recommended as primary search. |

## Appendix B: Documentation Verification (2026-04-12)

All tools verified against current official documentation. Corrections applied:

| Tool | Version | Correction Applied |
|------|---------|--------------------|
| atuin | current | Nushell init path: `~/.local/share/atuin/init.nu` (upstream), not `~/.cache/` |
| television | current | `command_history` removed from shell_integration (design intent: atuin owns Ctrl-R) |
| rip | current | cesarferreira/rip confirmed as fuzzy process killer. Brew: `cesarferreira/tap/rip`. Kept as intended. |
| rip2 | current | MilesCranmer/rip2 ADDED as safe rm with undo. Brew: `rip2`. Env var: `RIP_GRAVEYARD`. |
| jqp | current | Config file at `~/.jqp.yaml` (supports theming) |
| xh | v0.25.3 | Confirmed. `xh` + `xhs` binaries. Drop-in httpie replacement. |
| carapace | current | Nushell: use `$nu.cache-dir` not hardcoded paths. Zsh also supported. |
| nushell | 0.95+ | Use `$nu.cache-dir` for cache paths. `def --env` confirmed. PATH via `split row (char esep)` still works. |
| zsh-autosuggestions | current | Known atuin interaction (atuin injects as suggestion strategy). Source from `$(brew --prefix)/share/` |
| zsh-syntax-highlighting | current | **MUST be sourced LAST** in .zshrc. Moved from Section 5 to Section 14. |
| zsh vi-mode | current | `KEYTIMEOUT=1` required for responsive jj binding. `bindkey -M viins 'jj' vi-cmd-mode` |
| gh-dash | v4.23.2 | **NOT in brew**. Install via `gh extension install dlvhdr/gh-dash` only. `confirmQuit` may be deprecated. |
| diffnav | v0.11.0 | Brew requires tap: `brew install dlvhdr/formulae/diffnav`. Has config at `~/.config/diffnav/config.yml`. |
| sesh | v2.24.2 | No env var expansion in config. Template substitution at install time. |
| yazi | v26.1.22 | Kitty image preview enabled by default. Dracula theme from draculatheme.com/yazi. Lua plugin system. |
| TPM | current | Install/update triggers confirmed: `prefix+I` / `prefix+U` |
| tmux-sensible | current | Sets escape-time=0, history-limit=50000, focus-events=on, aggressive-resize=on |
| tmux-yank | current | Auto-detects clipboard on WSL2 (clip.exe) and macOS (pbcopy). No explicit set-clipboard config needed by plugin. |
| tmux-thumbs | current | Still requires Rust compilation. Default trigger: `prefix+Space`. No pre-built binaries. |
| tmux-fzf | current | Default trigger: `prefix+F`. Searches sessions, windows, panes, commands, keybindings, clipboard. |
| tmux-fzf-url | current | Default trigger: `prefix+u`. Config keys confirmed. |
| tmux-sessionx | current | `@sessionx-bind` and `@sessionx-zoxide-mode` not confirmed in official docs — verify from repo README at implementation time. |
| tmux-floax | current | `prefix+p` confirmed. DOES shadow native previous-window — acceptable since we use h/j/k/l navigation. Requires tmux 3.3+. |

## Appendix C: TODO — Future Plan Cycles

Scope deliberately excluded from this design. Each is a separate plan cycle
(brainstorming → design → implementation plan → implementation).

### macOS Desktop Environment

**Initial targets:**
- **AeroSpace** (https://github.com/nikitabobko/AeroSpace) — tiling window manager for macOS. Config at `~/.config/aerospace/aerospace.toml`.
- **SketchyBar** (https://github.com/FelixKratz/SketchyBar) — status bar replacement. Config at `~/.config/sketchybar/`.

**Integration scope** (for the future design):
- Workspace-switch events pipe from AeroSpace → SketchyBar via `exec-on-workspace-change`
- Dracula Pro theming for SketchyBar items (AeroSpace has no visual output of its own)
- Keybinding conventions that don't conflict with tmux (C-a), nvim (Space), or shell vi-mode
- Optional adjacent tools: **skhd** (hotkey daemon), **Karabiner-Elements** (keyboard remapping), **JankyBorders** (window border indicator)
- SketchyBar items to consider: git branch, k8s context, AWS/GCP profile, battery, time, calendar — mostly shell-script-driven using the same tools we're already configuring
- macOS-only — no WSL2/Linux equivalent. Out of scope for `install-wsl.sh`.

**Why separate from shell modernisation:**
- Desktop environment is an orthogonal concern from shell tooling
- macOS-only scope would complicate cross-platform install scripts
- Independent validation timeline — no coupling with zsh/nushell migration
- Dracula theming re-use is the only crossover, and it's a data-only dependency (hex values from the design's Dracula Pro palette section)

### gh Extensions — Layer 1b scope

User-selected extensions to add to Layer 1b:

- `github/gh-copilot` — inline command explanation/suggestion (`gh copilot explain`, `gh copilot suggest`)
- `seachicken/gh-poi` — safe pruning of merged branches (checks PR state via API)
- `yusukebe/gh-markdown-preview` — local GitHub-flavored markdown rendering
- `k1LoW/gh-grep` — cross-repo grep via GitHub API
- `github/gh-aw` — agentic workflows for GitHub Actions (user opted in; monitor supply-chain risk surface in corporate CI)
- `Link-/gh-token` — GitHub App installation token helper (user opted in; coexists with existing `gha-pin` PAT flow)

**Installation**: `gh extension install <owner>/<repo>` in `install-macos.sh` and
`install-wsl.sh` post-brew step. No Brewfile or `tools.txt` changes (gh extensions
aren't managed via package managers). Gated on `command -v gh &>/dev/null`.

**Aliases** (to be added in Layer 1b alias files):
```bash
# gh-copilot
alias ghce='gh copilot explain'
alias ghcs='gh copilot suggest'

# gh-poi (prune merged branches)
alias ghp='gh poi'

# gh-markdown-preview
alias ghmd='gh markdown-preview'

# gh-grep
alias ghg='gh grep'

# gh-aw (agentic workflows)
alias ghaw='gh aw'

# gh-token (installation token retrieval)
# No alias — used in automation scripts, not interactive shells
```

**cheat integration** (Layer 1b): extend the `cheat` function with a `cheat gh-ext`
subcommand that lists all installed extensions and their primary commands.

### OpenCode Ecosystem Integration

Separate plan cycle — not part of Layers 1a/1b/2/3.

**Context**: OpenCode (opencode-ai) has a thriving community ecosystem with a
marketplace at [opencode.cafe](https://www.opencode.cafe/) and a curated
[awesome-opencode](https://github.com/awesome-opencode/awesome-opencode) list.
Pattern categories: config profiles, scheduled runs, notifications, git worktree
automation, editor integrations (nvim), async PTY execution.

**Starting-point evaluations** (from 2026-04-13 research pass):

*Strong recommend — warrant inclusion in the eventual plan:*
- `kdcokenny/ocx` — portable `.opencode/` profile manager with SHA-256 verification.
  Aligns with corporate/CyberArk security posture.
- `different-ai/opencode-scheduler` — cron/launchd/systemd scheduling for recurring
  OpenCode tasks (GCP drift checks, Terraform lint, etc.).
- `nickjvandyke/opencode.nvim` — Neovim plugin with LSP-style interaction. Highest
  maturity among nvim integrations.

*Maybe — trial during the plan cycle before committing:*
- `shekohex/opencode-pty` — async PTY execution for long-running tasks.
- `kdcokenny/opencode-worktree` — automated git-worktree setup for parallel branches.
- `mohak34/opencode-notifier` — desktop notifications on completion (if adopted,
  pick ONLY this one; the panta82/notificator and kdcokenny/notify alternatives
  are less mature).

*Skip:*
- `JRedeker/opencode-shell-strategy` — docs, not a plugin. Read once.
- `panta82/opencode-notificator`, `kdcokenny/opencode-notify` — superseded.
- `sudo-tee/opencode.nvim` — admits early-dev status. Use nickjvandyke's instead.
- `different-ai/openwork` — separate product (a Claude alternative), NOT an OpenCode
  extension. Different tool entirely.
- `anomalyco/opencode` — appears to be a fork, not an extension.

**Broader ecosystem to evaluate at plan time**: the OpenCode Marketplace CLI
([NikiforovAll/opencode-marketplace](https://github.com/NikiforovAll/opencode-marketplace))
and the full awesome-opencode list. Research pass should re-survey at plan-writing
time since the ecosystem is moving quickly.

**Scope for the future plan**: installation patterns (marketplace CLI vs direct git
clone vs `opencode plugin install`), profile strategy (how ocx composes with our
existing `opencode/` and `opencode-local/` dual-config approach), scheduler use cases
(integration with our GCP/Terraform/GHA workflow), nvim integration sequencing (fits
alongside existing LazyVim config), cross-platform portability (macOS + WSL2), and
carrying the Dracula Pro theme through to OpenCode-owned UI surfaces.

**When to start**: after the shell modernisation layers stabilise, since OpenCode
integrations depend on the shell integrations (e.g., notifications via shell hooks,
scheduler calling into zsh/nushell).
