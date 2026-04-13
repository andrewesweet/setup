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
# eza replaces ls with git-aware, colour, icon support.
# Falls back to plain ls if eza is not installed.
if command -v eza &>/dev/null; then
  alias ls='eza --color=auto --icons=auto --group-directories-first'
  alias ll='eza --long --all --git --icons=auto --group-directories-first --header'
  alias la='eza --all --icons=auto --group-directories-first'
  alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
  alias llt='eza --tree --level=3 --long --icons=auto --group-directories-first'
else
  alias ll='ls -lAh'
  alias la='ls -A'
  alias lt='tree -L 2'
  alias llt='tree -L 3'
fi
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
    "")
      glow "$file" -s dark -p ;;
    keys)
      sed -n '/^## Key bindings/,/^## Tool reference/{/^## Tool reference/d;p}' "$file" \
        | glow -s dark -p ;;
    tools)
      sed -n '/^## Tool reference/,$p' "$file" \
        | glow -s dark -p ;;

    # ── Per-tool discovery ───────────────────────────────────────────
    # The cheatsheet is intentionally minimal (2 pages of A4). For
    # the complete, up-to-date binding list, every tool ships its own
    # discovery key — these subcommands tell you which key, and where
    # possible dump the live config so you don't have to leave the
    # shell.

    nvim|vim)
      cat <<'EOF'
nvim / LazyVim — discover bindings inside the editor:
  <space>          which-key popup (LazyVim leader menu)
  :WhichKey        full which-key tree
  :help index      all built-in normal-mode commands
  :Lazy            installed plugins (each has its own keys)
  :Mason           installed LSP servers / formatters / linters
  :Tutor           30-min interactive vimtutor
EOF
      ;;
    lazygit|lg)      echo "Inside lazygit: press '?' for the full keybinding overlay." ;;
    lazydocker|lzd)  echo "Inside lazydocker: press '?' for the full keybinding overlay." ;;
    k9s)             echo "Inside k9s: press '?' for help, ':' for command mode." ;;
    btop)            echo "Inside btop: press 'h' for the help screen." ;;
    lnav)            echo "Inside lnav: press '?' for help." ;;
    fzf)
      echo "In any fzf prompt: '?' toggles preview header."
      echo "Full reference: man fzf"
      ;;
    tmux)
      echo "In tmux: prefix (Ctrl+A) then '?' to list all bindings."
      echo "From shell: tmux list-keys"
      ;;
    bash|shell|readline)
      echo "Readline bindings (top 20):"
      bind -P 2>/dev/null | grep -v 'not bound' | head -20
      echo "Full list: bind -P"
      ;;
    git)
      echo "All git subcommands: git help -a"
      echo "Aliases in this repo: grep -A100 '^\[alias\]' \"\$DOTFILES/git/.gitconfig\""
      ;;
    starship)
      command -v starship >/dev/null && starship explain || echo "starship not on PATH"
      ;;
    delta)
      command -v delta >/dev/null && delta --show-config | head -30 || echo "delta not on PATH"
      ;;
    opencode|oc)
      echo "OpenCode TUI bindings: \$DOTFILES/opencode/tui.jsonc"
      [[ -f "$dotfiles/opencode/tui.jsonc" ]] && cat "$dotfiles/opencode/tui.jsonc"
      ;;

    -h|--help|help)
      cat <<'EOF'
cheat — quick reference for keys, tools, and per-tool discovery

  cheat            Render full cheatsheet
  cheat keys       Page 1: key bindings by action
  cheat tools      Page 2: tool for the job
  cheat <tool>     Per-tool "how to discover bindings" hint
  cheat help       This message

Per-tool subcommands:
  bash, btop, delta, fzf, git, k9s, lazydocker, lazygit, lnav,
  nvim, opencode, starship, tmux

The cheatsheet is intentionally limited to 2 pages of A4 — it is a
muscle-memory refresher, not a complete reference. For the full
current binding list of any tool, use its own discovery key.
EOF
      ;;
    *)
      echo "cheat: unknown subcommand '$1'" >&2
      echo "Run 'cheat help' for usage." >&2
      return 1
      ;;
  esac
}

# ── Repo organisation (Layer 1c: ghq + ghorg) ────────────────────────────────
# Interactive repo picker — bound to Alt-R (see bash/.bashrc).
repo() {
  local dir
  dir=$(ghq list --full-path | fzf --preview 'ls -la {}') || return
  if [[ -n "$dir" && -d "$dir" ]]; then
    cd "$dir"
  else
    echo "repo: cannot cd to '$dir' (deleted between list and select?)" >&2
    return 1
  fi
}

# Clone-and-go: ghq get + cd to the canonical path.
# Uses `ghq list -e -p` (exact match, full path) to avoid substring+head hazard.
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

# Bulk-clone a GitHub org into the ghq tree.
# Pins --path to ~/code/github.com; never pass --output-dir (renames org folder).
ghorg-gh() {
  local org="$1"; shift
  ghorg clone "$org" --path ~/code/github.com "$@"
}

# ── Yazi — cd-on-quit wrapper (Layer 1b-i) ──────────────────────────────────
# Launches yazi and, on exit, cd's the parent shell to whatever directory
# yazi was last in. `yazi` alone can't do this because a child process
# can't change the parent's cwd — it writes the final cwd to a temp file
# and the wrapper reads it back.
y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  cwd="$(cat -- "$tmp" 2>/dev/null)"
  if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
