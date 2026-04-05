# Shell configuration

This is the consolidated bash config specification. All platform guards, all aliases, all completions, all evals — in one place. No contradictions. Self-consistent.

## Platform detection

All platform-conditional logic MUST use this guard:

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

## .bash_profile

MUST contain only:

```bash
[[ -f "$HOME/.bashrc" ]] && source "$HOME/.bashrc"
```

## .bashrc structure

MUST follow this exact order:

### 1. Guard (REQUIRED)

```bash
[[ $- != *i* ]] && return
```

Ensures non-interactive shells exit early.

### 2. Platform detection (REQUIRED)

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

### 3. PATH setup (MUST be before any evals)

```bash
# Homebrew prefix (dynamic detection)
if [[ $_OS == macos ]]; then
  HOMEBREW_PREFIX=$(brew --prefix)
  export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
fi

# Set by install script. Defaults to script's own directory.
export DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

# ~/.bun/bin (Node.js toolchain)
[[ -d "$HOME/.bun/bin" ]] && export PATH="$HOME/.bun/bin:$PATH"

# ~/.local/bin (user-installed tools)
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
```

### 4. Bash completion (REQUIRED)

Platform-specific sourcing:

```bash
if [[ $_OS == macos ]]; then
  [[ -f "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh" ]] && \
    source "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
else
  [[ -f /usr/share/bash-completion/bash_completion ]] && \
    source /usr/share/bash-completion/bash_completion
fi
```

### 5. Vi mode + readline bindings

```bash
set -o vi
bind -m vi-command '"j": history-down'
bind -m vi-command '"k": history-up'
bind -m vi-insert '"\C-l": clear-screen'
bind -m vi-insert '"\C-a": beginning-of-line'
bind -m vi-insert '"\C-e": end-of-line'
```

### 6. History (REQUIRED)

MUST include secret pattern ignoring:

```bash
export HISTSIZE=100000
export HISTFILESIZE=200000
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT='%F %T '
shopt -s histappend
shopt -s cmdhist
export HISTIGNORE="*GITHUB_TOKEN*:*TOKEN*:*SECRET*:*PASSWORD*:*KEY*"
```

### 7. Shell options

```bash
shopt -s checkwinsize
shopt -s globstar
shopt -s nocaseglob
shopt -s cdspell
shopt -s autocd
```

### 8. Tool evals (MUST be guarded with `command -v`, MUST be before starship)

Each eval MUST check tool existence:

```bash
# fzf
if command -v fzf &>/dev/null; then
  eval "$(fzf --bash)"
fi

# zoxide
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash)"
fi

# mise
if command -v mise &>/dev/null; then
  eval "$(mise activate bash)"
fi

# direnv
if command -v direnv &>/dev/null; then
  eval "$(direnv hook bash)"
fi

# gh
if command -v gh &>/dev/null; then
  eval "$(gh completion -s bash)"
fi

# starship (MUST be last eval — it sets PROMPT_COMMAND)
if command -v starship &>/dev/null; then
  eval "$(starship init bash)"
fi
```

### 9. Completions (guarded)

```bash
if command -v mise &>/dev/null; then
  eval "$(mise completion bash)"
fi

if command -v uv &>/dev/null; then
  eval "$(uv generate-shell-completion bash)"
fi

if command -v cog &>/dev/null; then
  eval "$(cog generate-completions bash)"
fi

if command -v git-cliff &>/dev/null; then
  eval "$(git-cliff completions bash)"
fi

# gcloud (platform-specific path)
if [[ $_OS == macos ]]; then
  [[ -f "$HOMEBREW_PREFIX/share/google-cloud-sdk/completion.bash.inc" ]] && \
    source "$HOMEBREW_PREFIX/share/google-cloud-sdk/completion.bash.inc"
else
  [[ -f /usr/share/google-cloud-sdk/completion.bash.inc ]] && \
    source /usr/share/google-cloud-sdk/completion.bash.inc
fi
```

### 10. OSC 9 notification hook (MUST be after starship, with duplication guard)

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
    printf '\e]9;Command finished — took %ds (exit %d)\a' "$duration" "$last_exit"
  fi
}

trap '__cmd_timer_start' DEBUG
if [[ "$PROMPT_COMMAND" != *"__cmd_timer_notify"* ]]; then
  PROMPT_COMMAND="__cmd_timer_notify;${PROMPT_COMMAND}"
fi
```

### 11. Environment variables

MUST include conditional editor setup:

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

export BAT_THEME="Monokai Extended"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --info=inline
  --bind=ctrl-j:down,ctrl-k:up
'
```

### 12. Source aliases (REQUIRED)

```bash
[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"
```

### 13. Local overrides (REQUIRED)

```bash
[[ -f "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"
```

The `.bashrc.local` file is gitignored and used for per-user `EDITOR` overrides by VS Code-primary users.

## .bash_aliases — Complete consolidated list

MUST NOT shadow POSIX commands. No `alias grep=`, `alias find=`, `alias cat=`, `alias ps=`.

### Navigation

```bash
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
```

### File viewing

```bash
alias ll='ls -lAh'
alias la='ls -A'
alias lt='tree -L 2'
alias llt='tree -L 3'
alias md='glow -s dark'
```

### Git — prefix: g (REQUIRED)

```bash
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add --all'
alias gcm='git commit -m'
alias gam='git commit --amend'
alias gd='git diff'
alias gdc='git diff --cached'
alias gp='git push'
alias gpl='git pull --rebase'
alias gco='git checkout'
alias gsw='git switch'
alias gb='git branch -vv'
alias glog='git log --oneline --graph --decorate --all'
alias lg='lazygit'
```

Conventional commits:

```bash
alias cz='cog commit'
alias clog='git cliff'
alias cver='cog bump --auto'
```

### GitHub CLI (REQUIRED)

```bash
alias ghpr='gh pr create'
alias ghprl='gh pr list'
alias ghprc='gh pr checkout'
alias ghrv='gh repo view --web'
```

### Search & find — prefix: f (REQUIRED)

```bash
alias ff='fd'
alias ft='fd --type f'
alias fdd='fd --type d'
alias fs='rg'
alias fh='history | fzf'
```

### Process & ports — prefix: p (REQUIRED)

```bash
alias psa='ps aux'
alias psg='ps aux | rg --'
```

Platform-conditional ports alias (see Platform-conditional section below).

### Data wrangling

```bash
alias json='jq'
alias yaml='yq'
alias csv='mlr --csv'
```

### tmux — prefix: t (REQUIRED)

```bash
alias t='tmux'
alias ta='tmux attach -t'
alias tl='tmux list-sessions'
alias tn='tmux new -s'
alias tk='tmux kill-session -t'
```

### Neovim

```bash
alias v='nvim'
alias vd='nvim -d'
```

### mise — prefix: m (REQUIRED)

```bash
alias mx='mise exec --'
alias mu='mise use'
alias ml='mise list'
alias mug='mise upgrade'
```

### uv — prefix: uv (REQUIRED)

```bash
alias uva='uv add'
alias uvr='uv run'
alias uvs='uv sync'
alias uvt='uv tool install'
```

### direnv

```bash
alias da='direnv allow'
alias dr='direnv reload'
alias drd='direnv deny'
```

### GitHub Actions — prefix: gha (REQUIRED)

```bash
alias gha-pin='GITHUB_TOKEN=$(gh auth token) pinact run'
alias gha-check='GITHUB_TOKEN=$(gh auth token) pinact run --check'
alias gha-update='GITHUB_TOKEN=$(gh auth token) pinact run --update'
alias gha-lint='actionlint'
alias gha-audit='zizmor'
alias gha-fix='zizmor --fix'
```

### prek — prefix: pk (REQUIRED)

```bash
alias pk='prek run'
alias pka='prek run --all-files'
alias pkl='prek list'
alias pki='prek install && prek install-hooks'
alias pku='prek autoupdate'
```

**Note on pku:** The `--cooldown-days` flag is from Python pre-commit and MAY not be supported by prek. Verify against prek CLI at implementation time.

### GCP — prefix: gc (REQUIRED)

```bash
alias gc='gcloud'
alias gcp='gcloud config configurations'
alias gcl='gcloud config configurations list'
alias gca='gcloud config configurations activate'
alias gcr='gcloud run'
alias gce='gcloud compute'
alias gke='gcloud container clusters'
alias gsq='gcloud sql'
```

### CodeQL — prefix: cql (REQUIRED)

```bash
alias cql='codeql'
alias cql-db='codeql database create'
alias cql-analyze='codeql database analyze'
```

### Container tools

```bash
alias lzd='lazydocker'
alias tfsum='tf-summarize'
alias mdl='markdownlint-cli2'
```

### Notifications

```bash
alias notify='printf "\e]9;Done\a"'
```

### Platform-conditional

```bash
if [[ $_OS == macos ]]; then
  alias ports='lsof -i -P -n | rg LISTEN'
  alias port='lsof -i'
else
  alias ports='ss -tlnp'
  alias port='ss -tlnp'
fi
```

## critique functions (in .bash_aliases)

MUST be defined in .bash_aliases:

```bash
cr() { critique review "$@"; }

crw() { critique review --web --open "$@"; }

crs() {
  local session_id
  session_id=$(
    opencode session list 2>/dev/null \
      | fzf --height=40% --layout=reverse --border \
            --prompt="OpenCode session > " \
      | awk '{print $1}'
  )
  [[ -z "$session_id" ]] && { echo "No session selected." >&2; return 1; }
  critique review --agent opencode --session "$session_id" "$@"
}
```

## aliases discovery function (in .bash_aliases)

```bash
aliases() {
  local filter="${1:-}"
  echo "─── Shell aliases ───"
  if [[ -n "$filter" ]]; then
    alias | rg "$filter"
  else
    alias | column -t -s '='
  fi
  echo ""
  echo "─── Shell functions ───"
  declare -F | awk '{print $3}' | rg -v '^_' | sort
  echo ""
  echo "─── Git aliases ───"
  git config --get-regexp alias | sed 's/alias\.//' | column -t
}
```

## cheat function (in .bash_aliases)

```bash
cheat() {
  local dotfiles="${DOTFILES:-$HOME/.dotfiles}"
  local file="$dotfiles/docs/cheatsheet.md"
  case "${1:-}" in
    keys)
      sed -n '/^## Key bindings/,/^## Tool reference/p' "$file" \
        | sed '$d' | glow -s dark -p ;;
    tools)
      sed -n '/^## Tool reference/,$p' "$file" \
        | glow -s dark -p ;;
    *)
      glow "$file" -s dark -p ;;
  esac
}
```

## Brewfile notes

**Note**: The Brewfile includes `gofumpt` but SHOULD also include `goimports` (golang.org/x/tools/cmd/goimports). See install.md for Brewfile updates.

## .inputrc

MUST contain:

```
set editing-mode vi
set keyseq-timeout 50
set show-mode-in-prompt on
set completion-ignore-case on
set completion-map-case on
set show-all-if-ambiguous on
set mark-symlinked-directories on
```

## Performance note

Shell startup with 8+ evals is estimated at 300-600ms. Caching eval output to `~/.cache/dotfiles/<tool>.bash` is deferred — measure with `time bash -ic exit` first before implementing shell startup caching.
