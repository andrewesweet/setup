# .bashrc — interactive shell configuration
# Structured as 14 numbered sections. See docs/design/shell.md for the spec.

# ── 1. Guard ────────────────────────────────────────────────────────────────
[[ $- != *i* ]] && return

# ── 2. Platform detection ───────────────────────────────────────────────────
case "$OSTYPE" in
  darwin*)  _OS=macos ;;
  linux*)
    if [[ -n "$WSL_DISTRO_NAME" ]]; then
      _OS=wsl
    else
      _OS=linux
    fi
    ;;
  *)        _OS=unknown ;;
esac

# ── 3. PATH setup ──────────────────────────────────────────────────────────
# Homebrew prefix — detect without forking brew (~100ms saved per shell).
# Known locations: /opt/homebrew (Apple Silicon), /usr/local (Intel),
# $HOME/homebrew (custom installs on managed Macs).
if [[ $_OS == macos ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    HOMEBREW_PREFIX=/opt/homebrew
  elif [[ -x /usr/local/bin/brew ]]; then
    HOMEBREW_PREFIX=/usr/local
  elif [[ -x "$HOME/homebrew/bin/brew" ]]; then
    HOMEBREW_PREFIX="$HOME/homebrew"
  elif command -v brew &>/dev/null; then
    HOMEBREW_PREFIX=$(brew --prefix)
  fi
  if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
  fi
fi

# DOTFILES — self-resolve from this file's symlink target.
# .bashrc is a symlink: $HOME/.bashrc -> $DOTFILES/bash/.bashrc.
# Following the symlink and walking up one level gives us $DOTFILES.
# This means the repo can live anywhere — no need for ~/.dotfiles.
# Falls back to $HOME/.dotfiles if BASH_SOURCE is somehow empty
# (e.g., bashrc executed instead of sourced).
if [[ -z "${DOTFILES:-}" ]]; then
  _src="${BASH_SOURCE[0]:-}"
  if [[ -n "$_src" ]]; then
    # Resolve symlinks portably (BSD readlink lacks -f).
    while [[ -L "$_src" ]]; do
      _dir="$(cd -P "$(dirname "$_src")" && pwd)"
      _src="$(readlink "$_src")"
      [[ "$_src" != /* ]] && _src="$_dir/$_src"
    done
    _dir="$(cd -P "$(dirname "$_src")" && pwd)"
    # _dir is $DOTFILES/bash; DOTFILES is its parent.
    DOTFILES="$(cd -P "$_dir/.." && pwd)"
    unset _src _dir
  fi
fi
export DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

# User-local tool paths. Prepended so user-installed versions take priority.
# Security note: these directories MUST NOT contain untrusted binaries —
# an attacker with write access here could shadow tools invoked by eval below.
[[ -d "$HOME/.bun/bin" ]] && export PATH="$HOME/.bun/bin:$PATH"
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# OpenCode personal overrides (layers between global and project config).
# Team baseline:  ~/.config/opencode/         (symlinked from dotfiles)
# Personal:       ~/.config/opencode-local/   (gitignored, scaffolded by installer)
export OPENCODE_CONFIG="$HOME/.config/opencode-local/opencode.jsonc"
export OPENCODE_CONFIG_DIR="$HOME/.config/opencode-local"

# carapace — cross-shell completion bridges. MUST be exported before
# section 9 (Completions) so `carapace _carapace bash` sees it at init.
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'

# ── 4. Bash completion ─────────────────────────────────────────────────────
if [[ $_OS == macos ]] && [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  [[ -f "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh" ]] && \
    source "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
else
  [[ -f /usr/share/bash-completion/bash_completion ]] && \
    source /usr/share/bash-completion/bash_completion
fi

# ── 5. Vi mode + readline bindings ─────────────────────────────────────────
set -o vi
bind -m vi-command '"j": history-down'
bind -m vi-command '"k": history-up'
bind -m vi-insert '"\C-l": clear-screen'
bind -m vi-insert '"\C-a": beginning-of-line'
bind -m vi-insert '"\C-e": end-of-line'

# ── 6. History ──────────────────────────────────────────────────────────────
export HISTSIZE=100000
export HISTFILESIZE=200000
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT='%F %T '
shopt -s histappend
shopt -s cmdhist
export HISTIGNORE="*GITHUB_TOKEN*:*GH_TOKEN*:*GITHUB_PAT*:*TOKEN*:*SECRET*:*PASSWORD*:*KEY*:*BEARER*:*AUTHORIZATION*:*AWS_ACCESS*:*AWS_SECRET*:*AWS_SESSION*:*ANTHROPIC*:*OPENAI*"

# ── 7. Shell options ───────────────────────────────────────────────────────
shopt -s checkwinsize
shopt -s nocaseglob
# globstar, autocd, cdspell require bash 4+. macOS ships bash 3.2 by
# default — guard so .bashrc degrades gracefully before the user switches
# to Homebrew bash 5.
if ((BASH_VERSINFO[0] >= 4)); then
  shopt -s globstar
  shopt -s cdspell
  shopt -s autocd
fi

# ── 8. Tool evals (guarded, starship LAST) ─────────────────────────────────
# fzf
if command -v fzf &>/dev/null; then
  eval "$(fzf --bash)"
fi

# atuin — OPT-IN via ENABLE_ATUIN=1 in .bashrc.local.
# Leaves Ctrl-R bound to default readline reverse-search-history when unset,
# preserving existing bash muscle memory until the user explicitly opts in.
if [[ "${ENABLE_ATUIN:-0}" == 1 ]] && command -v atuin &>/dev/null; then
  eval "$(atuin init bash)"
fi

# television — OPT-IN via ENABLE_TV=1 in .bashrc.local.
# tv shell integration binds Ctrl-T to the smart_autocomplete channel picker.
# Ctrl-R is NOT bound by tv — it remains with readline or atuin if enabled.
if [[ "${ENABLE_TV:-0}" == 1 ]] && command -v tv &>/dev/null; then
  eval "$(tv init bash)"
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

# starship (MUST be last eval in section 8 — it sets PROMPT_COMMAND)
# Only initialize for interactive shells with a non-dumb TERM.
# Avoids breakage when tools like OpenCode run shell commands non-interactively.
if command -v starship &>/dev/null && [[ "${TERM:-dumb}" != "dumb" ]]; then
  eval "$(starship init bash)"
fi

# ── 9. Completions (guarded) ───────────────────────────────────────────────
if command -v mise &>/dev/null; then
  eval "$(mise completion bash)"
fi

if command -v uv &>/dev/null; then
  eval "$(uv generate-shell-completion bash)"
fi

if command -v cog &>/dev/null; then
  eval "$(cog generate-completions bash)"
fi

# git-cliff: no shell completions command as of v2.12.0

# carapace (completion backstop for tools without native bash support).
# Requires CARAPACE_BRIDGES to be set earlier in this file (section 3).
if command -v carapace &>/dev/null; then
  source <(carapace _carapace bash)
fi

# gcloud (platform-specific path)
if [[ $_OS == macos ]] && [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  [[ -f "$HOMEBREW_PREFIX/share/google-cloud-sdk/completion.bash.inc" ]] && \
    source "$HOMEBREW_PREFIX/share/google-cloud-sdk/completion.bash.inc"
else
  # Interactive installer path (~/google-cloud-sdk/) takes precedence over
  # apt-installed path (/usr/share/google-cloud-sdk/).
  if [[ -f "$HOME/google-cloud-sdk/completion.bash.inc" ]]; then
    source "$HOME/google-cloud-sdk/completion.bash.inc"
  elif [[ -f /usr/share/google-cloud-sdk/completion.bash.inc ]]; then
    source /usr/share/google-cloud-sdk/completion.bash.inc
  fi
fi

# ── 10. OSC 9 notification hook (after starship, with duplication guard) ───
# OSC 9 is supported by Windows Terminal, WezTerm, iTerm2, and Kitty.
# Other terminals may display garbage escape sequences. Guard on known
# terminals, with an override: export NOTIFY_OSC9=1 in .bashrc.local.
_osc9_supported=false
case "${TERM_PROGRAM:-}" in
  WezTerm|iTerm.app|vscode) _osc9_supported=true ;;
esac
# Kitty sets TERM=xterm-kitty, not TERM_PROGRAM
[[ "${TERM:-}" == xterm-kitty ]] && _osc9_supported=true
# Windows Terminal sets WT_SESSION
[[ -n "${WT_SESSION:-}" ]] && _osc9_supported=true
# Manual override
[[ "${NOTIFY_OSC9:-}" == 1 ]] && _osc9_supported=true

if [[ "$_osc9_supported" == true ]]; then
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
fi
unset _osc9_supported

# ── 11. Environment variables ──────────────────────────────────────────────
if command -v nvim &>/dev/null; then
  export EDITOR='nvim'
  export VISUAL='nvim'
  export MANPAGER='nvim +Man!'
else
  export EDITOR='code --wait'
  export VISUAL="$EDITOR"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# difftastic: DFT_BACKGROUND=dark → $DRACULA_PRO_BACKGROUND #22212C
# difftastic renders added/removed with terminal ANSI red/green;
# Pro terminal ANSI red=#FF9580 / green=#8AFF80 so no per-colour override
# is required — DFT_BACKGROUND=dark ensures the contrast direction is
# correct for the Pro dark background.
export DFT_BACKGROUND="dark"
export BAT_THEME="Dracula"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude .env --exclude .aws --exclude .ssh --exclude .gnupg --exclude .config/gh'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude .env --exclude .aws --exclude .ssh --exclude .gnupg --exclude .config/gh'
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

# ── 12. Source aliases ─────────────────────────────────────────────────────
[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"

# ── 13. Layer 1c keybindings ───────────────────────────────────────────────
# Alt-R: invoke the `repo` function (ghq+fzf interactive picker).
# Only bind in interactive shells to avoid noisy errors in non-interactive contexts.
if [[ $- == *i* ]]; then
  bind '"\er":"repo\n"'
fi

# ── 14. Local overrides ───────────────────────────────────────────────────
# .bashrc.local is gitignored. Use it for per-machine overrides, e.g.:
#   export EDITOR='code --wait'      # VS Code-primary users
#   export NOTIFY_OSC9=1             # enable OSC 9 on unsupported terminals
#   set keyseq-timeout 200           # higher timeout for high-latency SSH
#   export NOTIFY_THRESHOLD=30       # longer threshold before notification
[[ -f "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"
