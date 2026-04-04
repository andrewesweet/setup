# Adversarial review fixes

Documents all fixes adopted from the adversarial reviews of the
original design documents. These changes apply across all prior
design documents and must be incorporated during implementation.

**Precedence rule**: where this document or `dotfiles-cross-platform.md`
conflicts with earlier documents (`dotfiles-setup.md`, `dotfiles-neovim.md`,
etc.), the later document wins. The implementation must use the final
resolved version, not the original.

---

## Critical fixes

### `lsp.lua` syntax error (CRITICAL)

The `vim.g.lazyvim_python_lsp = "ty"` and `vim.g.lazyvim_python_formatter`
assignments sit inside the `return` table literal in `dotfiles-neovim.md`.
Lua will fail at runtime.

**Fix**: Move both assignments **before** the `return` statement:

```lua
-- lua/plugins/lsp.lua
vim.g.lazyvim_python_lsp       = "ty"
vim.g.lazyvim_python_formatter = "ruff"

return {
  {
    "neovim/nvim-lspconfig",
    ...
  },
}
```

### `lsp.lua` uses `require("lspconfig.util")` (CRITICAL)

`gh_actions_ls` root_dir uses `require("lspconfig.util").find_git_ancestor()`.
This creates a dependency on lspconfig loading order and contradicts the
"no require('lspconfig')" constraint.

**Fix**: Replace with Neovim 0.11+ native API:

```lua
root_dir = function(fname)
  return vim.fs.root(fname, ".git")
end,
```

### `PROMPT_COMMAND` clobbered by starship (CRITICAL)

Starship's `eval "$(starship init bash)"` overwrites `PROMPT_COMMAND`.
If the OSC 9 notification hook is set before starship init, it's wiped.

**Fix**: The notification hook must be appended **after** starship init.
Order in `.bashrc`:

```bash
# 1. Tool evals (fzf, zoxide, mise, direnv, gh, starship)
command -v starship &>/dev/null && eval "$(starship init bash)"

# 2. OSC 9 notification (after starship, appended to PROMPT_COMMAND)
NOTIFY_THRESHOLD="${NOTIFY_THRESHOLD:-10}"
# ... timer functions ...
PROMPT_COMMAND="__cmd_timer_notify;${PROMPT_COMMAND}"
```

Guard against duplication on re-source:

```bash
if [[ "$PROMPT_COMMAND" != *"__cmd_timer_notify"* ]]; then
  PROMPT_COMMAND="__cmd_timer_notify;${PROMPT_COMMAND}"
fi
```

---

## Alias fixes

### `fd` alias shadows binary (HIGH)

`alias fd='fd --type d'` breaks `FZF_DEFAULT_COMMAND` and any tool
that calls `fd` directly.

**Fix**: Rename to `fdd='fd --type d'`.

### POSIX command shadows (HIGH)

`alias ps='ps aux'`, `alias grep='rg'`, `alias find='fd'`,
`alias cat='bat --paging=never'` shadow standard commands.

**Fix**: Remove all shadows. Replace with distinct aliases:
- `psa='ps aux'`
- `psg='ps aux | rg'`
- Keep `rg` as `rg` (don't alias `grep`)
- Keep `fd` as `fd` (don't alias `find`)
- Keep `bat` as `bat` (don't alias `cat`)

### `alias ~='cd ~'` unnecessary (LOW)

`cd` with no args already goes home. Remove the alias.

### lazygit alias: `gl` to `lg` (LOW)

`gl` conflicts with common `git log` mnemonics. `lg` is the
near-universal convention for lazygit.

**Fix**: `alias lg='lazygit'`

### `alias uvx='uvx'` is a no-op (LOW)

Maps a command to itself. Remove it.

### Missing aliases (LOW)

Add:
- `drd='direnv deny'` — complement `da`/`dr`
- `gha-fix='zizmor --fix'` — complement `gha-*` family
- `notify='printf "\e]9;Done\a"'` — manual OSC 9 notification
- `cql='codeql'` — CodeQL CLI
- `cql-db='codeql database create'`
- `cql-analyze='codeql database analyze'`
- `lzd='lazydocker'`
- `tfsum='tf-summarize'`

---

## Alias discoverability (MEDIUM)

No runtime way to discover 70+ aliases and functions.

**Fix**: Add an `aliases` function to `.bash_aliases` that covers
shell aliases, shell functions (`cr`, `crw`, `crs`, `cheat`), and
git aliases:

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

Usage: `aliases` (all), `aliases git` (filtered).

---

## Integration fixes

### lazygit delta syntax theme (MEDIUM)

lazygit invokes delta directly, bypassing gitconfig.

**Fix**: Change lazygit `config.yml`:

```yaml
git:
  paging:
    pager: delta --paging=never --syntax-theme='Monokai Extended'
```

### Starship missing language modules (MEDIUM)

`$golang` and `$rust` are in the format string but have no config
sections. Display is inconsistent with other language modules.

**Fix**: Add to `starship.toml`:

```toml
[golang]
format = "[ $version](cyan) "

[rust]
format = "[ $version](red) "
```

### fzf-lua zoxide picker (MEDIUM)

**Fix**: Add to `integrations.lua` fzf-lua keys:

```lua
{ "<leader>fz", "<cmd>FzfLua zoxide<cr>", desc = "Zoxide dirs" },
```

### fzf-lua inherits shell `FZF_DEFAULT_OPTS` (HIGH)

Shell opts set `ctrl-j:down,ctrl-k:up` which conflict with Neovim
keymaps inside fzf-lua pickers.

**Fix**: Set `fzf_opts` explicitly in fzf-lua plugin spec to isolate
from shell environment:

```lua
opts = {
  fzf_opts = {
    ["--bind"] = "ctrl-j:down,ctrl-k:up",
  },
  -- ... winopts ...
},
```

### fzf-lua mnemonic swap (LOW)

`<leader>fs` is `grep_cword` in Neovim but `fs` means "find string"
(rg) in shell aliases. `<leader>fg` is live grep.

**Fix**: Swap:
- `<leader>fs` → `FzfLua live_grep` (find string, matches shell)
- `<leader>fw` → `FzfLua grep_cword` (find word under cursor)

### `httpie` alias theme (LOW)

`--style=monokai` is not the same palette as bat/delta's `Monokai
Extended`. Drop the `--style` flag — httpie's adaptive default is fine.

**Fix**: `alias http='http'` (remove the alias entirely, use httpie
directly).

### `glow` dark mode (LOW)

glow can misdetect light/dark in tmux. Pin dark mode.

**Fix**: `alias md='glow -s dark'`

### Missing completions (MEDIUM)

Add completions for tools that support them:

```bash
command -v mise      &>/dev/null && eval "$(mise completion bash)"
command -v uv        &>/dev/null && eval "$(uv generate-shell-completion bash)"
command -v cog       &>/dev/null && eval "$(cog generate-completions bash)"
command -v git-cliff &>/dev/null && eval "$(git-cliff completions bash)"
```

Check if prek and pinact expose completion generators — add if so.

### `git stash show` bypasses delta (LOW)

**Fix**: Add to `.gitconfig`:

```ini
[stash]
    showPatch = true
```

---

## Keybind fixes

### Ctrl+L in vim-tmux-navigator (HIGH)

The `bind-key -n 'C-l'` intercepts clear-screen in all tmux panes.

**Fix**: Add a separate binding for clear-screen:

```conf
bind C-l send-keys C-l    # Prefix + Ctrl+L = clear screen
```

Document that `Ctrl+A Ctrl+L` clears screen when in tmux. Add a
comment in `.tmux.conf` near the prefix binding.

### Ctrl+A collision: tmux prefix vs OpenCode input (HIGH)

**Fix**: Not worth changing the prefix. Document prominently:
- `Ctrl+A Ctrl+A` sends literal `Ctrl+A` to the inner process
- Add a one-line tip on first `dev shell` attach

### Ctrl+U/D collision in OpenCode (HIGH)

`messages_half_page_up` is bound to `ctrl+u` but the input area's
hardcoded emacs `Ctrl+U` (delete to start of line) fires when the
input box has focus.

**Fix**: Remove bare `ctrl+u`/`ctrl+d` from `tui.jsonc` message
scrolling. Use only the `ctrl+alt+u`/`ctrl+alt+d` variants:

```jsonc
"messages_half_page_up":   "ctrl+alt+u",
"messages_half_page_down": "ctrl+alt+d",
```

### Esc in lazygit inside Neovim (MEDIUM)

Pressing `Esc` in lazygit's floating terminal can be intercepted by
Neovim's terminal mode.

**Fix**: LazyVim's default floating terminal config typically handles
this. Verify during implementation. If needed, add to `keymaps.lua`:

```lua
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
```

### btop half-page scroll (LOW)

btop uses bare `d`/`u`, not configurable.

**Fix**: Document in cheatsheet only.

### Delta `n`/`N` override search-next (LOW)

With `navigate=true`, `n`/`N` jump between hunks, overriding
`less` search-next after `/pattern`.

**Fix**: Document in cheatsheet. This is a known trade-off of
`navigate=true`.

### lnav yank is `c`, not `y` (LOW)

lnav's default and not configurable. Flag prominently in cheatsheet
as the one yank outlier.

---

## Cheatsheet

A single `docs/cheatsheet.md` serves as both terminal reference and
printable document.

### Terminal access

`cheat` function renders via `glow`. The function processes raw
markdown (not ANSI output) for section filtering:

```bash
cheat() {
  local dotfiles="${DOTFILES:-$HOME/.dotfiles}"
  local file="$dotfiles/docs/cheatsheet.md"
  case "${1:-}" in
    keys)
      sed -n '/^## Key bindings/,/^## Tool reference/p' "$file" \
        | head -n -1 | glow -s dark -p ;;
    tools)
      sed -n '/^## Tool reference/,$p' "$file" \
        | glow -s dark -p ;;
    *)
      glow "$file" -s dark -p ;;
  esac
}
```

### Print

`pandoc` generates landscape A4 PDF. Use `typst` as the PDF engine
(lighter than xelatex, no full TeX Live install required):

```bash
pandoc docs/cheatsheet.md \
  -o docs/cheatsheet.pdf \
  --pdf-engine=typst \
  -V geometry:landscape \
  -V geometry:margin=1.5cm
```

Add `pandoc` and `typst` to Brewfile.

### Content structure

**Page 1: Key bindings by action**

Columns: Action | Shell | tmux | Neovim | lazygit | OpenCode | btop/lnav

Grouped by action (navigate, search, copy, quit) not by tool.

**Page 2: Tool for the job**

Columns: Task | Tool | Quick command | Alias

Grouped by workflow: searching, git, editing, formatting, linting,
containers, kubernetes, terraform, GCP.

---

## `.bashrc` ordering and structure

The final `.bashrc` must follow this order to avoid dependency and
override issues:

```bash
# 1. Guard: only for interactive shells
[[ $- != *i* ]] && return

# 2. Platform detection (_OS)

# 3. PATH setup (Homebrew, bun, local bin) — BEFORE any evals
if [[ $_OS == macos ]]; then
  HOMEBREW_PREFIX="$(brew --prefix)"
  export PATH="$HOMEBREW_PREFIX/bin:$PATH"
fi
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

# 4. Bash-completion (platform-specific path)

# 5. Vi mode + readline bindings

# 6. History settings + shell options

# 7. Tool evals (all guarded with command -v)
#    fzf, zoxide, mise, direnv, gh, starship — in that order

# 8. Completions (mise, uv, cog, git-cliff)

# 9. OSC 9 notification hook (AFTER starship, with duplication guard)

# 10. Environment variables (EDITOR, VISUAL, MANPAGER, BAT_THEME, FZF_*)

# 11. Aliases
[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"

# 12. Local overrides (gitignored)
[[ -f "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"
```

---

## `dev` script fixes

### `dev` with no args prints usage (LOW)

### `dev.env` missing check (MEDIUM)

Prints message, offers to copy from example.

### `dev shell` resolves to git root (MEDIUM)

Mount `$(git rev-parse --show-toplevel)` instead of `$PWD`. Warn
if they differ.

### `dev.sh` validates `$SSH_AUTH_SOCK` (MEDIUM)

Check that `$SSH_AUTH_SOCK` exists and is a socket before mounting.
Print diagnostic if missing.

### `dev.sh` passes `--dns` on WSL2 (LOW)

Pass `--dns` from host `/etc/resolv.conf` nameserver to avoid
WSL2 Podman DNS resolution issues.

### Stale image detection blocks by default (LOW)

`--skip-check` to bypass.

---

## Container fixes

### Containerfile: explicit `adduser` (LOW)

```dockerfile
RUN adduser -D -h /home/dev -s /bin/bash dev
```

### Containerfile: locale (MEDIUM)

```dockerfile
RUN apk add glibc-locales
ENV LANG=C.UTF-8
```

### `--userns=keep-id` on macOS Podman Machine (MEDIUM)

Document that on macOS, Podman runs inside a VM and `keep-id` maps
to the VM user, not the host user. Consider explicit UID mapping:
`--userns=keep-id:uid=1000,gid=1000` for deterministic behaviour.

---

## `.gitconfig` fix

### Remove hardcoded editor (HIGH)

Remove `editor = code --wait` from `.gitconfig`. Git falls back to
`$EDITOR`. Also use canonical `excludesFile` (camelCase):

```ini
[core]
    pager        = delta
    excludesFile = ~/.gitignore_global
    autocrlf     = input
```

### Add stash showPatch (LOW)

```ini
[stash]
    showPatch = true
```

---

## Install script fixes

### Backup before overwriting (HIGH)

Both install scripts back up existing non-symlink config files to
`~/.dotfiles-backup/<timestamp>/` before creating symlinks.

### `.inputrc` missing from symlinks (MEDIUM)

Add `link bash/.inputrc .inputrc` to both install scripts.

### `tools.txt` format (MEDIUM)

Simple format: one tool per line, `#` comments, optional
`brew:<name>` / `apt:<name>` / `apk:<name>` / `uv:<name>` prefixes
for platform-specific install names.

Validation script: checks that every tool in `tools.txt` is
referenced in Brewfile, `install-wsl.sh`, and the Containerfile.

---

## Markdownlint-cli2

### Brewfile

```ruby
brew "markdownlint-cli2"
```

### Mason

Add `"markdownlint-cli2"` to Mason's `ensure_installed`.

### nvim-lint

Add to `linting.lua`:

```lua
markdown = { "markdownlint-cli2" },
```

### conform.nvim

Add to `formatting.lua`:

```lua
markdown = { "markdownlint-cli2" },
```

### prek baseline

Add to `.pre-commit-config.yaml`:

```yaml
  # ── Markdown ──────────────────────────────────────────────────────────
  - repo: https://github.com/DavidAnson/markdownlint-cli2
    rev: v0.17.1
    hooks:
      - id: markdownlint-cli2
```

### Config file

`.markdownlint.jsonc` (committed to each repo):

```jsonc
{
  "default": true,
  "MD013": { "line_length": 120 },
  "MD033": false,
  "MD041": false
}
```

- `MD013`: line length warning at 120 (matches yamllint)
- `MD033`: allow inline HTML (common in GitHub READMEs)
- `MD041`: don't require first line to be h1

---

## GCP / gcloud

### Brewfile

```ruby
brew "google-cloud-sdk"
brew "cloud-sql-proxy"
```

### Post-install gcloud components

```bash
gcloud components install \
  alpha beta bq \
  gke-gcloud-auth-plugin \
  pubsub-emulator \
  cloud-datastore-emulator \
  cloud-firestore-emulator \
  cloud-build-local \
  bigtable \
  spanner-emulator
```

### Credentials

Application Default Credentials stored at `~/.config/gcloud/`.
Mounted read-only into the container.

Never hardcode GCP project IDs, service account keys, or org-specific
config in dotfiles.

### Aliases

```bash
# ── GCP ──────────────────────────────────────────────────────────────────────
alias gc='gcloud'
alias gcp='gcloud config configurations'
alias gcl='gcloud config configurations list'
alias gca='gcloud config configurations activate'
alias gcr='gcloud run'
alias gce='gcloud compute'
alias gke='gcloud container clusters'
alias gsq='gcloud sql'
```

Note: `gc` may shadow `git commit` alias if someone uses that.
Since our git commit alias is `gcm` (with message), `gc` is safe.

---

## CodeQL

### Brewfile

```ruby
brew "codeql"
```

### Pack storage

Query packs downloaded to `~/.codeql/` on the host. Mounted
read-only into the container at `/home/dev/.codeql/`.

### Container Containerfile

CodeQL CLI installed in base stage (agents may use it for security
analysis). `--search-path` set via environment variable or config.

---

## Verification and testing

### `verify.sh` (NEW)

Add a `verify.sh` at repo root, run after install:

1. Symlink check — every expected symlink exists and points correctly
2. `bash -n` on all bash config files — syntax validation
3. `bash container/test-tool-installs.sh` — all tools present
4. Config parse validation (tmux, starship, opencode JSONC)
5. `dev build --base` — container builds (if Podman present)
6. Print manual verification steps (Neovim LSP check)

### CI (GitHub Actions)

```yaml
on: [push, pull_request]
jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@...
      - name: Shell syntax check
        run: bash -n bash/.bashrc bash/.bash_aliases bash/.bash_profile
      - name: Config validation
        run: bash scripts/check-configs.sh
      - name: tools.txt drift check
        run: bash scripts/check-tool-manifest.sh
      - name: Container base build
        run: podman build --target base -t dotfiles-base container/
```

### `test-tool-installs.sh` gaps

Add missing tools:
- `ruff` (critical, installed via Mason/mise)
- `bun` (runtime for opencode/critique)

Fix: `pinact` install method is `brew` (correct per current design).

---

## Repo structure additions

```
vscode/
├── settings.json            # user settings
└── extensions.json          # recommended extensions

docs/
├── cheatsheet.md            # key bindings + tool reference
└── cheatsheet.pdf           # generated (gitignored)

scripts/
├── verify.sh                # post-install verification
├── check-configs.sh         # config parse validation
└── check-tool-manifest.sh   # tools.txt drift detection
```

Add to `.gitignore`:
- `docs/cheatsheet.pdf`
- `container/dev.env`
- `.bashrc.local`
