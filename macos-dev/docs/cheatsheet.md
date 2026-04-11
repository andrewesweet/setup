# Cheatsheet

Quick reference for key bindings and tool commands. Render in terminal with `cheat`, `cheat keys`, or `cheat tools`.

## Key bindings

Key bindings by action across all tools. Vi-mode everywhere except OpenCode input (hardcoded emacs).

### Navigation

| Action | Shell | tmux | Neovim | lazygit | OpenCode | btop | lnav |
|--------|-------|------|--------|---------|----------|------|------|
| Down | j | j (copy mode) | j | j | ↓ | j | j |
| Up | k | k (copy mode) | k | k | ↑ | k | k |
| Half page ↓ | Ctrl+D | Ctrl+D | Ctrl+D | Ctrl+D | Ctrl+Alt+D | d | Ctrl+D |
| Half page ↑ | Ctrl+U | Ctrl+U | Ctrl+U | Ctrl+U | Ctrl+Alt+U | u | Ctrl+U |

### Search

| Action | Shell | tmux | Neovim | lazygit | lnav | delta |
|--------|-------|------|--------|---------|------|-------|
| Search | / (normal) | / (copy mode) | / | / | / | / |
| Next | n | n | n | n | n | n (hunks) |
| Previous | N | N | N | N | N | N (hunks) |
| Fuzzy history | Ctrl+R | — | — | Ctrl+R (repos) | — | — |

> **Note:** delta n/N jumps between hunks (`navigate=true`), overriding less search-next.

### Copy/yank

| Action | Shell | tmux | Neovim | lazygit | OpenCode | lnav |
|--------|-------|------|--------|---------|----------|------|
| Begin selection | — | v (copy mode) | v | — | — | — |
| Yank/copy | y (vi) | y (OSC 52) | y | y | Ctrl+X y | c |

> **Note:** lnav uses `c` for copy — the one outlier. Not configurable.

### Quit/back

| Action | Shell | tmux | lazygit | OpenCode | btop | lnav |
|--------|-------|------|---------|----------|------|------|
| Quit | q (vi normal) | — | q | — | q | q |
| Back/cancel | Esc | Esc (copy mode) | Esc | Esc (interrupt) | Esc | — |

### Known friction points

| Issue | Workaround |
|-------|------------|
| Ctrl+L lost in tmux (vim-tmux-nav) | Ctrl+A Ctrl+L to clear screen |
| Ctrl+A captured by tmux (OpenCode) | Ctrl+A Ctrl+A for literal Ctrl+A |
| btop uses d/u not Ctrl+D/U | No fix — btop's default, not configurable |
| Ctrl+P/K captured by VS Code | Use OpenCode leader bindings in VS Code terminal |
| Delta n/N jumps hunks not search results | Use `less` search separately, or disable `navigate=true` in delta |
| Stale Neovim float obscures buffer | `:fclose!` (closes orphaned floating windows from cmdline popup / hover / etc.) |

## Tool reference

Tool for the job — quick commands and aliases.

### Searching

| Task | Tool | Command | Alias |
|------|------|---------|-------|
| Find file by name | fd | `fd <pattern>` | `ff`, `ft`, `fdd` |
| Search file contents | ripgrep | `rg <pattern>` | `fs` |
| Fuzzy find file | fzf | Ctrl+T | — |
| Fuzzy search history | fzf | Ctrl+R | — |
| Jump to directory | zoxide | `z <partial>` | — |
| Interactive dir picker | zoxide+fzf | `zi` | — |

### Git

| Task | Tool | Command | Alias |
|------|------|---------|-------|
| Git TUI | lazygit | `lazygit` | `lg` |
| Short status | git | `git status -sb` | `gs` |
| Diff (delta) | git | `git diff` | `gd` |
| Staged diff | git | `git diff --cached` | `gdc` |
| AST diff | difftastic | `git difftool` | — |
| Commit message | cocogitto | `cog commit` | `cz` |
| Changelog | git-cliff | `git cliff` | `clog` |
| Code review | critique | `critique review` | `cr`, `crw`, `crs` |

### Formatting & Linting

| Task | Tool | Command | Alias |
|------|------|---------|-------|
| Run all hooks | prek | `prek run --all-files` | `pka` |
| Run one hook | prek | `prek run <id>` | `pk <id>` |
| Update hooks | prek | `prek autoupdate` | `pku` |
| Pin GH Actions | pinact | `pinact run` | `gha-pin` |
| Audit GH Actions | zizmor | `zizmor` | `gha-audit` |

### GCP

| Task | Tool | Command | Alias |
|------|------|---------|-------|
| gcloud CLI | gcloud | `gcloud` | `gc` |
| Switch config | gcloud | `gcloud config configurations activate` | `gca` |
| List configs | gcloud | `gcloud config configurations list` | `gcl` |
| BigQuery | bq | `bq` | — |

### Container

| Task | Tool | Command | Alias |
|------|------|---------|-------|
| Dev shell | dev | `dev shell` | — |
| Build image | dev | `dev build` | — |
| Container TUI | lazydocker | `lazydocker` | `lzd` |
| Kubernetes TUI | k9s | `k9s` | — |
