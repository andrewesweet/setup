# .bash_aliases — all shell aliases and utility functions
# Prefix scheme: g*/gc* git, f* search, p* process, t* tmux, m* mise,
#   uv* uv, pk* prek, cr* critique, gha-* GitHub Actions,
#   gx* gcloud, cql* codeql
#
# MUST NOT shadow POSIX commands: no alias grep=, find=, cat=, ps=

# ── Navigation ──────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ── File viewing ────────────────────────────────────────────────────────────
alias ll='ls -lAh'
alias la='ls -A'
alias lt='tree -L 2'
alias llt='tree -L 3'
alias mdv='glow -s dark'

# ── Git — prefix: g ─────────────────────────────────────────────────────────
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
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

# ── Conventional commits ───────────────────────────────────────────────────
alias cz='cog commit'
alias clog='git cliff'
alias cver='cog bump --auto'

# ── GitHub CLI ──────────────────────────────────────────────────────────────
alias ghpr='gh pr create'
alias ghprl='gh pr list'
alias ghprc='gh pr checkout'
alias ghrv='gh repo view --web'

# ── Search & find — prefix: f ──────────────────────────────────────────────
alias ff='fd'
alias ft='fd --type f'
alias fdd='fd --type d'
alias fs='rg'
alias fh='history | fzf'

# ── Process & ports — prefix: p ────────────────────────────────────────────
alias psa='ps aux'
alias psg='ps aux | rg --'

# ── Data wrangling ─────────────────────────────────────────────────────────
alias json='jq'
alias yaml='yq'
alias csv='mlr --csv'

# ── tmux — prefix: t ──────────────────────────────────────────────────────
alias t='tmux'
alias ta='tmux attach -t'
alias tl='tmux list-sessions'
alias tn='tmux new -s'
alias tk='tmux kill-session -t'

# ── Neovim ─────────────────────────────────────────────────────────────────
alias v='nvim'
alias vd='nvim -d'

# ── mise — prefix: m ──────────────────────────────────────────────────────
alias mx='mise exec --'
alias mu='mise use'
alias ml='mise list'
alias mug='mise upgrade'

# ── uv — prefix: uv ───────────────────────────────────────────────────────
alias uva='uv add'
alias uvr='uv run'
alias uvs='uv sync'
alias uvt='uv tool install'

# ── direnv ─────────────────────────────────────────────────────────────────
alias da='direnv allow'
alias dr='direnv reload'
alias drd='direnv deny'

# ── GitHub Actions — prefix: gha ───────────────────────────────────────────
# Functions (not aliases) so GITHUB_TOKEN is passed as an env var prefix
# rather than expanded into the command line visible in /proc/*/cmdline.
# Note: the token is still visible in /proc/<pid>/environ during the
# lifetime of the pinact process. This is an inherent limitation of
# shell-based env var injection. See security.md § "GITHUB_TOKEN in
# shell history".
gha-pin() {
  gh auth status &>/dev/null || { echo "gh: not authenticated. Run: gh auth login" >&2; return 1; }
  GITHUB_TOKEN=$(gh auth token) pinact run "$@"
}
gha-check() {
  gh auth status &>/dev/null || { echo "gh: not authenticated. Run: gh auth login" >&2; return 1; }
  GITHUB_TOKEN=$(gh auth token) pinact run --check "$@"
}
gha-update() {
  gh auth status &>/dev/null || { echo "gh: not authenticated. Run: gh auth login" >&2; return 1; }
  GITHUB_TOKEN=$(gh auth token) pinact run --update "$@"
}
alias gha-lint='actionlint'
alias gha-audit='zizmor'
alias gha-fix='zizmor --fix'

# ── prek — prefix: pk ─────────────────────────────────────────────────────
alias pk='prek run'
alias pka='prek run --all-files'
alias pkl='prek list'
alias pki='prek install && prek install-hooks'
alias pku='prek autoupdate'

# ── GCP — prefix: gx ──────────────────────────────────────────────────────
# gcloud uses gx* prefix to avoid collision with gc* git aliases.
alias gx='gcloud'
alias gxc='gcloud config configurations'
alias gxl='gcloud config configurations list'
alias gxa='gcloud config configurations activate'
alias gxr='gcloud run'
alias gxe='gcloud compute'
alias gxk='gcloud container clusters'
alias gxs='gcloud sql'

# ── CodeQL — prefix: cql ──────────────────────────────────────────────────
alias cql='codeql'
alias cql-db='codeql database create'
alias cql-analyze='codeql database analyze'

# ── Container tools ────────────────────────────────────────────────────────
alias lzd='lazydocker'
alias tfsum='tf-summarize'
alias mdl='markdownlint-cli2'

# ── Podman Machine (macOS only) ───────────────────────────────────────────
alias pm-start='dev machine-start'
alias pm-stop='dev machine-stop'
alias pm-status='dev machine-status'

# ── Notifications ──────────────────────────────────────────────────────────
alias notify='printf "\e]9;Done\a"'

# ── Platform-conditional ───────────────────────────────────────────────────
if [[ $_OS == macos ]]; then
  alias ports='lsof -i -P -n | rg LISTEN'
  alias port='lsof -i'
else
  alias ports='ss -tlnp'
  alias port='ss -anp'
fi

# ── critique functions ─────────────────────────────────────────────────────
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

# ── aliases discovery function ─────────────────────────────────────────────
aliases() {
  local filter="${1:-}"
  echo "─── Shell aliases ───"
  if [[ -n "$filter" ]]; then
    alias | rg -- "$filter" 2>/dev/null || alias | grep -- "$filter"
  else
    alias | sort
  fi
  echo ""
  echo "─── Shell functions ───"
  declare -F | awk '{print $3}' | grep -v '^_' | sort
  echo ""
  echo "─── Git aliases ───"
  git config --get-regexp alias | sed 's/alias\.//' | sort
}

# ── cheat function ─────────────────────────────────────────────────────────
cheat() {
  local dotfiles="${DOTFILES:-$HOME/.dotfiles}"
  local file="$dotfiles/docs/cheatsheet.md"
  if [[ ! -f "$file" ]]; then
    echo "Cheatsheet not found at: $file" >&2
    echo "Check that DOTFILES is set correctly (current: ${DOTFILES:-unset})" >&2
    return 1
  fi
  case "${1:-}" in
    keys)
      sed -n '/^## Key bindings/,/^## Tool reference/{/^## Tool reference/d;p}' "$file" \
        | glow -s dark -p ;;
    tools)
      sed -n '/^## Tool reference/,$p' "$file" \
        | glow -s dark -p ;;
    *)
      glow "$file" -s dark -p ;;
  esac
}
