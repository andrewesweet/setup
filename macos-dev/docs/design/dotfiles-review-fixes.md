# Adversarial review fixes

Documents all fixes adopted from the adversarial reviews of the
original design documents. These changes apply across all prior
design documents and must be incorporated during implementation.

---

## Alias fixes

### `fd` alias shadows binary (HIGH)

`alias fd='fd --type d'` breaks `FZF_DEFAULT_COMMAND` and any tool
that calls `fd` directly.

**Fix**: Rename to `fdd='fd --type d'`.

### POSIX command shadows (MEDIUM)

`alias ps='ps aux'`, `alias grep='rg'`, `alias find='fd'` break
pasted scripts and muscle memory.

**Fix**: Remove these shadows. Replace with distinct aliases:
- `psa='ps aux'`
- `psg='ps aux | rg'`
- Keep `rg` as `rg` (don't alias `grep`)
- Keep `fd` as `fd` (don't alias `find`)
- Remove `alias cat='bat --paging=never'` — use `bat` directly

### lazygit alias: `gl` to `lg` (LOW)

`gl` conflicts with common `git log` mnemonics in other dotfile
collections. `lg` is the near-universal convention for lazygit.

**Fix**: `alias lg='lazygit'`

### Missing aliases (LOW)

Add:
- `drd='direnv deny'` — complement `da`/`dr`
- `gha-fix='zizmor --fix'` — complement `gha-*` family
- `notify='printf "\e]9;Done\a"'` — manual OSC 9 notification

---

## Alias discoverability (MEDIUM)

No runtime way to discover 70+ aliases.

**Fix**: Add an `aliases` function to `.bash_aliases`:

```bash
aliases() {
  local filter="${1:-}"
  echo "─── Dotfiles aliases ───"
  if [[ -n "$filter" ]]; then
    alias | rg "$filter"
  else
    alias | column -t -s '='
  fi
}
```

Usage: `aliases` (all), `aliases git` (filtered).

---

## lazygit delta syntax theme (MEDIUM)

lazygit invokes delta directly, bypassing gitconfig. The `--dark`
flag does not select Monokai Extended.

**Fix**: Change lazygit `config.yml`:

```yaml
git:
  paging:
    pager: delta --paging=never --syntax-theme='Monokai Extended'
```

---

## Starship golang module (MEDIUM)

The format string uses `$golang` but no `[golang]` section is
defined. Display format is inconsistent with other language modules.

**Fix**: Add to `starship.toml`:

```toml
[golang]
format = "[ $version](cyan) "
```

---

## fzf-lua zoxide picker (MEDIUM)

fzf-lua supports a zoxide picker but it's not configured.

**Fix**: Add to `integrations.lua` fzf-lua keys:

```lua
{ "<leader>fz", "<cmd>FzfLua zoxide<cr>", desc = "Zoxide dirs" },
```

---

## Keybind fixes

### Ctrl+L in vim-tmux-navigator (HIGH)

The `bind-key -n 'C-l'` intercepts clear-screen in all tmux panes.

**Fix**: The existing `is_vim` conditional already handles this
correctly — non-vim panes get `select-pane -R`. To restore
Ctrl+L for clear-screen, add a separate binding:

```conf
bind C-l send-keys C-l    # Prefix + Ctrl+L = clear screen
```

Document that `Ctrl+A Ctrl+L` clears screen when in tmux.

### Ctrl+A collision: tmux prefix vs OpenCode input (HIGH)

`Ctrl+A` is tmux prefix and OpenCode's start-of-line in the input
area. When OpenCode runs inside tmux, `Ctrl+A` is swallowed.

**Fix**: Not worth changing the prefix — ergonomic value is too
high. Document prominently:
- `Ctrl+A Ctrl+A` sends literal `Ctrl+A` to the inner process
- This is the one known friction point in the keybind scheme

### btop half-page scroll (LOW)

btop uses bare `d`/`u`, everything else uses `Ctrl+D`/`Ctrl+U`.
Not configurable in btop.

**Fix**: Document in the cheatsheet only. No config change.

---

## Cheatsheet

A single `docs/cheatsheet.md` serves as both terminal reference and
printable document.

### Terminal access

`cheat` alias renders via `glow`:

```bash
cheat() {
  local dotfiles="${DOTFILES:-$HOME/.dotfiles}"
  local file="$dotfiles/docs/cheatsheet.md"
  case "${1:-}" in
    keys)  glow "$file" -p | sed -n '/## Key bindings/,/## Tool/p' ;;
    tools) glow "$file" -p | sed -n '/## Tool reference/,$p' ;;
    *)     glow "$file" -p ;;
  esac
}
```

Usage: `cheat` (full), `cheat keys`, `cheat tools`.

### Print

`pandoc` generates landscape A4 PDF:

```bash
pandoc docs/cheatsheet.md \
  -o docs/cheatsheet.pdf \
  --pdf-engine=xelatex \
  -V geometry:landscape \
  -V geometry:margin=1.5cm \
  -V fontsize=9pt \
  -V mainfont="JetBrains Mono"
```

Add `pandoc` to Brewfile. The `Makefile` or a script wraps this as
`make cheatsheet-pdf`.

### Content structure

**Page 1: Key bindings by action**

Columns: Action | Shell | tmux | Neovim | lazygit | OpenCode | btop/lnav

Grouped by action (navigate, search, copy, quit) not by tool.

**Page 2: Tool for the job**

Columns: Task | Tool | Quick command | Alias

Grouped by workflow: searching, git, editing, formatting, linting,
containers, kubernetes, terraform.

---

## `dev` script UX fixes

### `dev` with no args prints usage (LOW)

```
Usage: dev <command> [options]

Commands:
  build [--base]           Build container image
  shell [--base] [--ref <path>] [--port <port>] [--skip-check]
                           Start or attach to dev container
  stop                     Stop container for current repo
  rebuild [--clean]        Rebuild image and recreate container
  status                   Show running dev containers
  prune                    Remove stopped containers and images
```

### `dev.env` missing check (MEDIUM)

On `dev shell`, if `container/dev.env` does not exist:

```
dev.env not found. Creating from dev.env.example...
  cp container/dev.env.example container/dev.env
Review and edit container/dev.env, then re-run dev shell.
```

### Stale image detection blocks by default (LOW)

Changed from warning to blocking. `--skip-check` to bypass.

---

## Repo structure additions

```
docs/
├── cheatsheet.md              # key bindings + tool reference
└── cheatsheet.pdf             # generated (gitignored)
```

Add to `.gitignore`: `docs/cheatsheet.pdf`
