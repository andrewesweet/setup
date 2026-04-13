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

### tmux plugin keybindings

All bindings are relative to `prefix` (Ctrl-A).

| Action | Binding | Plugin |
|--------|---------|--------|
| Install plugins | `prefix + I` | TPM |
| Update plugins | `prefix + U` | TPM |
| Floating pane | `prefix + p` | tmux-floax |
| Session picker | `prefix + o` | tmux-sessionx |
| Highlight on-screen patterns | `prefix + Space` | tmux-thumbs |
| URL picker (scrollback) | `prefix + u` | tmux-fzf-url |
| Fuzzy tmux command | `prefix + F` | tmux-fzf |
| Save session | `prefix + Ctrl-S` | tmux-resurrect |
| Restore session | `prefix + Ctrl-R` | tmux-resurrect |

### Television channel triggers

Ctrl-T invokes television; the channel is chosen by context (the command being typed). Add the trigger to `[shell_integration.channel_triggers]` in `~/.config/television/config.toml`.

| Command typed | Channel |
|---------------|---------|
| `cat`, `less`, `vim`, `nvim`, `bat`, `cp`, `mv`, `rm` | files |
| `cd`, `ls`, `z`, `rmdir` | dirs |
| `alias`, `unalias` | alias |
| `export`, `unset` | env |
| `git checkout`, `git branch`, `git merge`, `git rebase`, `git pull`, `git push` | git-branch |
| `git add`, `git restore` | git-diff |
| `git log`, `git show` | git-log |
| `podman exec`, `podman stop`, `podman rm` | docker-containers |
| `podman run` | docker-images |
| `kubectl exec`, `kubectl logs` | k8s-pods |
| `kubectx` | k8s-contexts |
| `make` | make-targets |
| `ssh`, `scp` | ssh-hosts |
| `nvim`, `code`, `git clone` | git-repos (from ghq tree) |

Invoke manually: `tv <channel>` (e.g. `tv git-log`, `tv gcloud-configs`, `tv procs`).

## Tool reference

Tool for the job — quick commands and aliases.

### Searching

| Task | Tool | Command | Alias |
|------|------|---------|-------|
| Find file by name | fd | `fd <pattern>` | `ff`, `ft`, `fdd` |
| Search file contents | ripgrep | `rg <pattern>` | `fs` |
| Fuzzy find file (smart autocomplete) | television (if `ENABLE_TV=1`) / fzf default | Ctrl+T | — |
| Fuzzy search history | atuin (if `ENABLE_ATUIN=1`) / fzf default | Ctrl+R | — |
| Jump to directory | zoxide | `z <partial>` | — |
| Interactive dir picker | zoxide+fzf | `zi` | — |
| Pick a repo (ghq tree) | ghq+fzf | `repo` | Alt-R |
| Clone and cd into it | ghq | `gclone <url>` | — |
| Bulk-clone a GitHub org | ghorg | `ghorg-gh <org>` | — |

### Layer 1b-i tools

| Task | Tool | Command | Alias |
|------|------|---------|-------|
| tmux session manager (CLI) | sesh | `sesh connect <name>` | `sx` |
| List sesh sessions | sesh | `sesh list` | `sxl` |
| File manager (cd-on-quit) | yazi | `yazi` | `y` (function) |
| HTTP client | xh | `xh GET httpbin.org/get` | `http` |
| Safe rm (undo-able) | rip2 | `rip2 file` | `rm-safe` |
| Undo last rip2 delete | rip2 | `rip2 -u` | `rrip` |
| Interactive jq playground | jqp | `cat file.json \| jqp` | `jqi` |
| Navigate diffs (delta UI) | diffnav | `git diff \| diffnav` | `dn` |
| Cross-shell completions | carapace | auto (via bash init) | — |

### gh-dash workflow

gh-dash is the PR/issue dashboard. `ghd` launches it.

| Task | Binding | Result |
|------|---------|--------|
| Preview PR | Enter | Inline preview pane |
| Open repo in lazygit | g | `cd <repo>; lazygit` |
| Open PR in opencode | C | `tmux new-window -c <repo> "opencode"` (custom binding) |
| View diff | d | Delta-rendered diff via diffnav |
| Open PR in browser | o | `gh browse` on the selection |
| Refresh section | r | Re-fetch from GitHub |

Pager for diffs is `diffnav` (file-tree nav UI over delta output). Delta's syntax theme is Dracula via `git/.gitconfig`.

| Task | Tool | Command | Alias |
|------|------|---------|-------|
| PR/issue dashboard | gh-dash | `gh dash` | `ghd` |
| Explain a command | gh-copilot | `gh copilot explain <cmd>` | `ghce` |
| Suggest a command | gh-copilot | `gh copilot suggest <q>` | `ghcs` |
| Prune merged branches | gh-poi | `gh poi` | `ghp` |
| Render GFM locally | gh-markdown-preview | `gh markdown-preview <file>` | `ghmd` |
| Cross-repo grep | gh-grep | `gh grep <q>` | `ghg` |
| Agentic workflows | gh-aw | `gh aw ...` | `ghaw` |
| Installation token helper | gh-token | `gh token -i <id>` (automation) | — |

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

### Vim training

| Task | Tool | Command |
|------|------|---------|
| Block bad-habit keys (hjkl spam, arrows, mouse) | hardtime.nvim | `:Hardtime toggle` / `:Hardtime report` |
| Show motion hints on the current line | precognition.nvim | `:Precognition toggle` / `:Precognition peek` |
| Practice game (delete-me, ci{, whackamole, …) | vim-be-good | `:VimBeGood` |
| Built-in interactive tutor | vimtutor | `:Tutor` (or `vimtutor` from shell) |

### Discover full bindings inside each tool

This cheatsheet is intentionally limited (two pages of A4) — it is a muscle-memory refresher, not a complete reference. Every tool ships its own discovery key. The shell function `cheat <tool>` summarises each one without leaving your terminal.

| Tool | Discovery key / command |
|------|--------------------------|
| nvim / LazyVim | `<space>` (which-key), `:WhichKey`, `:help index`, `:Lazy`, `:Mason`, `:Tutor` |
| OpenCode | `cheat opencode` (dumps `tui.jsonc`) |
| tmux | `Ctrl+A` then `?`, or `tmux list-keys` from shell |
| lazygit | `?` |
| lazydocker | `?` |
| k9s | `?` |
| btop | `h` |
| lnav | `?` |
| fzf | `?` in any prompt; `man fzf` for full reference |
| starship | `starship explain` |
| delta | `delta --show-config` |
| bash readline | `bind -P` |
| git | `git help -a` |
| sesh | `cheat sesh` |
| yazi | Inside yazi: `?` for help overlay |
| jqp | Inside jqp: `Ctrl+H` for help |
| diffnav | Inside diffnav: `?` for help |
| xh | `xh --help`; `cheat xh` for quickstart |
| rip2 | `cheat rip2` |
