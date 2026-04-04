# Adversarial review fixes

Documents all fixes adopted from adversarial reviews (rounds 1 and 2)
of the design documents. These changes apply across all prior design
documents and must be incorporated during implementation.

**Precedence rule**: where this document or `dotfiles-cross-platform.md`
conflicts with earlier documents (`dotfiles-setup.md`, `dotfiles-neovim.md`,
etc.), the later document wins. The implementation must use the final
resolved version, not the original.

---

## Critical fixes

### `lsp.lua` syntax error

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

### `lsp.lua` uses `require("lspconfig.util")`

`gh_actions_ls` root_dir uses `require("lspconfig.util").find_git_ancestor()`.
This creates a dependency on lspconfig loading order.

**Fix**: Replace with Neovim 0.11+ native API:

```lua
root_dir = function(fname)
  return vim.fs.root(fname, ".git")
end,
```

### `PROMPT_COMMAND` clobbered by starship

Starship's `eval "$(starship init bash)"` overwrites `PROMPT_COMMAND`.

**Fix**: The notification hook must be appended **after** starship init.
Guard against duplication on re-source:

```bash
if [[ "$PROMPT_COMMAND" != *"__cmd_timer_notify"* ]]; then
  PROMPT_COMMAND="__cmd_timer_notify;${PROMPT_COMMAND}"
fi
```

### `dev-data-opencode` volume shadows auth bind mount

Named volume at `/home/dev/.local/share/opencode` shadows the
read-only bind mount of `auth.json` inside that same path.

**Fix**: Mount `auth.json` to a separate path and configure OpenCode
to read from there:

```bash
-v ~/.local/share/opencode/auth.json:/home/dev/.opencode-auth/auth.json:ro
```

Set `OPENCODE_AUTH_FILE=/home/dev/.opencode-auth/auth.json` in the
container environment (verify this env var with OpenCode docs at
implementation time).

---

## Security fixes

### OpenCode permissions — restrict read scope

`"read": "allow"` lets the agent read any file including mounted
credentials. Scope to workspace, tmp, and specific config paths.

**Fix**: Replace broad `read` allow with path-scoped rules:

```jsonc
"read": {
  "*": "ask",
  "~/workspace/**": "allow",
  "/home/dev/workspace/**": "allow",
  "/tmp/**": "allow",
  "~/.config/opencode/**": "allow",
  "~/.config/mise/**": "allow"
},
```

Similarly restrict `cat` in bash permissions:

```jsonc
"cat /home/dev/workspace/*": "allow",
"cat /tmp/*": "allow",
```

Remove the broad `"cat *": "allow"` rule. Keep `"bat *": "allow"`
for syntax-highlighted viewing (bat is read-only).

### OpenCode permissions — restrict edit scope

```jsonc
"edit": {
  "*": "ask",
  "~/workspace/**": "allow",
  "/home/dev/workspace/**": "allow",
  "/tmp/**": "allow"
},
```

### `.gitignore_global` coverage gaps

Add missing patterns:

```gitignore
# Secrets and credentials
.env
.env.*
*.pem
*.key
*.p12
*.pfx
auth.json
credentials.json
application_default_credentials.json
*.keystore

# Dotfiles local overrides
.bashrc.local
dev.env
```

### SSH agent: require confirmation

Document that `ssh-add -c` must be enabled on the host so each
SSH key use inside the container requires user confirmation:

```bash
# On macOS host
ssh-add -c ~/.ssh/id_ed25519
```

### Container capabilities: drop SETUID/SETGID

`SETUID` and `SETGID` are not needed at runtime. Only `CHOWN`,
`DAC_OVERRIDE`, and `FOWNER` are required.

```bash
--cap-drop=ALL \
--cap-add=CHOWN,DAC_OVERRIDE,FOWNER \
```

### `GITHUB_TOKEN` in shell history

`gha-pin` alias expands `$(gh auth token)` into shell history.

**Fix**: Add `HISTIGNORE` pattern in `.bashrc`:

```bash
HISTIGNORE="*GITHUB_TOKEN*:*TOKEN*:*SECRET*:*PASSWORD*:*KEY*"
```

### Supply chain: version pinning for curl-pipe-bash installs

`install-wsl.sh` uses `curl | bash` for mise, uv, and starship.

**Fix**: Pin versions and verify checksums in `install-wsl.sh`.
Document the expected checksums. The Containerfile must also pin
versions with checksums for all static binary downloads.

---

## Alias fixes

### `fd` alias shadows binary (HIGH)

**Fix**: Rename to `fdd='fd --type d'`.

### POSIX command shadows (HIGH)

**Fix**: Remove all shadows. Replace with distinct aliases:
- `psa='ps aux'`
- `psg='ps aux | rg'`
- Keep `rg` as `rg` (don't alias `grep`)
- Keep `fd` as `fd` (don't alias `find`)
- Keep `bat` as `bat` (don't alias `cat`)

### `gc` alias collision (HIGH)

`dotfiles-setup.md` defines `gc='git commit'`.
GCP aliases define `gc='gcloud'`.

**Fix**: Remove `gc='git commit'` (redundant — `gcm` exists for
commit-with-message, and `git commit` is what you type for
interactive commits). `gc='gcloud'` takes the slot.

### `alias ~='cd ~'` unnecessary

Remove. `cd` with no args already goes home.

### lazygit alias: `gl` to `lg`

**Fix**: `alias lg='lazygit'`

### `alias uvx='uvx'` is a no-op

Remove it.

### Missing aliases

Add:
- `drd='direnv deny'`
- `gha-fix='zizmor --fix'`
- `notify='printf "\e]9;Done\a"'`
- `cql='codeql'`
- `cql-db='codeql database create'`
- `cql-analyze='codeql database analyze'`
- `lzd='lazydocker'`
- `tfsum='tf-summarize'`
- `mdl='markdownlint-cli2'`

### `httpie` alias

Drop `--style=monokai` — httpie's adaptive default is fine.
Remove the alias entirely.

### `glow` alias

Pin dark mode: `alias md='glow -s dark'`

---

## Alias discoverability (MEDIUM)

**Fix**: Add an `aliases` function to `.bash_aliases` that covers
shell aliases, shell functions, and git aliases:

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

---

## Integration fixes

### lazygit delta syntax theme

**Fix**: `pager: delta --paging=never --syntax-theme='Monokai Extended'`

### Starship fixes

Add missing language modules:

```toml
[golang]
format = "[ $version](cyan) "

[rust]
format = "[ $version](red) "
```

Remove `vimins_symbol` — not a valid Starship key. `success_symbol`
and `error_symbol` already cover insert mode.

Add prompt scan timeout:

```toml
scan_timeout = 30
```

### fzf-lua fixes

Add zoxide picker:

```lua
{ "<leader>fz", "<cmd>FzfLua zoxide<cr>", desc = "Zoxide dirs" },
```

Isolate from shell `FZF_DEFAULT_OPTS`:

```lua
opts = {
  fzf_opts = {
    ["--bind"] = "ctrl-j:down,ctrl-k:up",
  },
},
```

Swap mnemonics:
- `<leader>fs` → `FzfLua live_grep` (matches shell `fs`)
- `<leader>fw` → `FzfLua grep_cword` (find word)

### Missing completions

```bash
command -v mise      &>/dev/null && eval "$(mise completion bash)"
command -v uv        &>/dev/null && eval "$(uv generate-shell-completion bash)"
command -v cog       &>/dev/null && eval "$(cog generate-completions bash)"
command -v git-cliff &>/dev/null && eval "$(git-cliff completions bash)"
```

Add gcloud completion (platform-specific):

```bash
if [[ $_OS == macos ]]; then
  local _gcloud_comp="$HOMEBREW_PREFIX/share/google-cloud-sdk/completion.bash.inc"
  [[ -r "$_gcloud_comp" ]] && source "$_gcloud_comp"
elif [[ $_OS == wsl || $_OS == linux ]]; then
  [[ -r /usr/share/google-cloud-sdk/completion.bash.inc ]] && \
    source /usr/share/google-cloud-sdk/completion.bash.inc
fi
```

### `git stash show` bypasses delta

**Fix**: Add `[stash] showPatch = true` to `.gitconfig`.

### `direnv` missing from Brewfile

**Fix**: Add `brew "direnv"` to consolidated Brewfile.

### `tap "homebrew/bundle"` deprecated

Remove from Brewfile. Unnecessary since Homebrew 4.x.

### Theme consistency note

The tmux status bar uses Catppuccin Mocha hex values. bat, delta,
and lazygit use `Monokai Extended`. These are different palettes.
Document this as intentional — tmux UI chrome uses Catppuccin, code
rendering tools use Monokai Extended. No action needed.

---

## Keybind fixes

### Ctrl+L in vim-tmux-navigator

**Fix**: Add binding: `bind C-l send-keys C-l`
Document `Ctrl+A Ctrl+L` for clear-screen in tmux.

### Ctrl+A collision: tmux prefix vs OpenCode input

**Fix**: Document prominently. Add comment in `.tmux.conf` and tip
on first `dev shell` attach.

### Ctrl+U/D collision in OpenCode

**Fix**: Remove bare `ctrl+u`/`ctrl+d` from `tui.jsonc`. Use only:

```jsonc
"messages_half_page_up":   "ctrl+alt+u",
"messages_half_page_down": "ctrl+alt+d",
```

### VS Code Ctrl+P and Ctrl+K intercept

VS Code captures `Ctrl+P` (Quick Open) and `Ctrl+K` (chord prefix)
before they reach OpenCode or bash in the integrated terminal.

**Fix**: Document as known limitation. Users running OpenCode in
VS Code's terminal should use OpenCode's `<leader>` bindings
instead.

### tmux `bind l` shadows `last-window`

**Fix**: Add `bind L last-window` to restore the shortcut on
Shift+L.

### Esc in lazygit inside Neovim

Verify LazyVim handles this during implementation. Fallback:

```lua
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
```

### btop, delta, lnav quirks

Document in cheatsheet only. No config changes possible.

---

## Cross-platform fixes

### `is_vim` tmux detection breaks on Linux

`ps -o state= -o comm= -t '#{pane_tty}'` uses BSD semantics.

**Fix**: Test on WSL2/container during implementation. If it breaks,
use `pgrep`-based detection as portable alternative. Ensure `procps`
is installed in the Containerfile.

### VS Code settings path on macOS

`~/.config/Code/User/settings.json` is the Linux path. macOS uses
`~/Library/Application Support/Code/User/settings.json`.

**Fix**: `install-macos.sh` uses the correct macOS path:

```bash
link vscode/settings.json \
  "Library/Application Support/Code/User/settings.json"
```

### `gcloud components install` fails when package-managed

When gcloud is installed via apt or apk, `gcloud components install`
is disabled.

**Fix**:
- macOS (Homebrew): `gcloud components install` works
- WSL2 (apt): install components as separate apt packages
  (e.g. `google-cloud-sdk-gke-gcloud-auth-plugin`)
- Container (apk): install as separate apk packages or download
  binaries directly

### `head -n -1` not portable

BSD `head` on macOS doesn't support negative line counts.

**Fix**: Replace `head -n -1` with `sed '$d'` in the `cheat`
function.

### `fzf --bash` version requirement

Requires fzf >= 0.48. WSL2 apt ships 0.29.

**Fix**: `install-wsl.sh` must install fzf from GitHub releases,
not apt. No version guard needed in `.bashrc` — the install script
ensures the correct version.

### `opencode.jsonc` project template missing comma

```jsonc
// Before the comment, add the missing comma:
{
  "instructions": [
    ".opencode/AGENTS.md"
  ],
  // Uncomment to override model:
}
```

---

## `.bashrc` ordering and structure

The final `.bashrc` must follow this order:

```bash
# 1.  Guard: only for interactive shells
[[ $- != *i* ]] && return

# 2.  Platform detection (_OS)

# 3.  PATH setup (Homebrew, bun, local bin) — BEFORE any evals
if [[ $_OS == macos ]]; then
  HOMEBREW_PREFIX="$(brew --prefix)"
  export PATH="$HOMEBREW_PREFIX/bin:$PATH"
fi
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

# 4.  Bash-completion (platform-specific path)

# 5.  Vi mode + readline bindings

# 6.  History settings + shell options + HISTIGNORE

# 7.  Tool evals (all guarded with command -v)
#     fzf, zoxide, mise, direnv, gh — then starship LAST

# 8.  Completions (mise, uv, cog, git-cliff, gcloud)

# 9.  OSC 9 notification hook (AFTER starship, with guard)

# 10. Environment variables (EDITOR, VISUAL, MANPAGER, BAT_THEME, FZF_*)

# 11. Aliases
[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"

# 12. Local overrides (gitignored)
[[ -f "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"
```

---

## `.gitconfig` fixes

Remove hardcoded `editor`. Use canonical `excludesFile` (camelCase).
Add `stash.showPatch`:

```ini
[core]
    pager        = delta
    excludesFile = ~/.gitignore_global
    autocrlf     = input

[stash]
    showPatch = true
```

---

## `dev` script fixes

- `dev` with no args prints usage
- `dev.env` missing: print message, offer to copy from example
- `dev shell` resolves to git root (`git rev-parse --show-toplevel`),
  warns if `$PWD` differs
- Validate `$SSH_AUTH_SOCK` exists before mounting; print diagnostic
- Pass `--dns` from host `/etc/resolv.conf` on WSL2
- Stale image detection blocks by default, `--skip-check` to bypass
- Add `dev uninstall` command that restores backups from
  `~/.dotfiles-backup/`

---

## Container fixes

### Containerfile

- Explicit adduser: `adduser -D -h /home/dev -s /bin/bash dev`
- Locale: `apk add glibc-locales` + `ENV LANG=C.UTF-8`
- Install `procps` for `is_vim` tmux detection
- Layer ordering: apk installs → tool installs (mise, uv) →
  global packages (bun, uv tools) → configs and user setup
- Install gcloud CLI and codeql in base stage
- gcloud components: install as individual apk packages (not
  `gcloud components install`)

### `--userns=keep-id` on macOS Podman Machine

Document that on macOS, Podman runs inside a VM. Consider explicit
UID mapping: `--userns=keep-id:uid=1000,gid=1000`.

---

## Install script fixes

### Backup before overwriting

Both scripts back up existing non-symlink config files to
`~/.dotfiles-backup/<timestamp>/`.

### `.inputrc` in symlinks

Add `link bash/.inputrc .inputrc` to both install scripts.

### `tools.txt` format

One tool per line, `#` comments, optional platform-specific install
name suffixes:

```
# tool-name  brew:formula  apt:package  apk:package
bash          bash          bash          bash
delta         git-delta     -             -
```

Validation script checks all tools are referenced in Brewfile,
`install-wsl.sh`, and Containerfile.

---

## Markdownlint-cli2

### Brewfile

```ruby
brew "markdownlint-cli2"
```

### Mason

Add `"markdownlint-cli2"` to Mason's `ensure_installed`.

### nvim-lint (linting only — not conform)

Add to `linting.lua`:

```lua
markdown = { "markdownlint-cli2" },
```

Do NOT add to conform.nvim — markdownlint-cli2 is a linter with
`--fix`, not a conform-compatible formatter. Use prettier for
markdown formatting via conform:

```lua
markdown = { "prettier" },
```

### prek baseline

Add to `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/DavidAnson/markdownlint-cli2
    rev: v0.17.1
    hooks:
      - id: markdownlint-cli2
```

### Config file

`.markdownlint.jsonc` template for each repo:

```jsonc
{
  "default": true,
  "MD013": { "line_length": 120 },
  "MD033": false,
  "MD041": false
}
```

---

## GCP / gcloud

### Brewfile

```ruby
brew "google-cloud-sdk"
brew "cloud-sql-proxy"
```

### Post-install (macOS only — Homebrew SDK)

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

WSL2 and container: install as individual packages via apt/apk.

### Credentials

Mounted read-only into container. IAM is the security boundary.
No secrets in dotfiles.

### Aliases

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

The original `gc='git commit'` from `dotfiles-setup.md` is removed
(redundant — `gcm` covers commit-with-message).

---

## CodeQL

### Brewfile

```ruby
brew "codeql"
```

### Pack storage

`~/.codeql/` on host, mounted read-only into container.

### Container

CodeQL CLI installed in base stage. `--search-path` configured
via environment or config file.

---

## Cheatsheet

A single `docs/cheatsheet.md` for terminal and print.

### Terminal access

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

### Print

```bash
pandoc docs/cheatsheet.md \
  -o docs/cheatsheet.pdf \
  --pdf-engine=typst \
  -V geometry:landscape \
  -V geometry:margin=1.5cm
```

Add `pandoc` and `typst` to Brewfile.

---

## Verification and testing

### `verify.sh`

1. Symlink check (platform-aware paths for VS Code)
2. `bash -n` on all bash config files
3. `bash container/test-tool-installs.sh` — all tools present
4. Config parse validation (tmux, starship, opencode JSONC)
5. `dev build --base` (if Podman present)
6. `gke-gcloud-auth-plugin --version` and other gcloud components
7. `code --version` (if VS Code expected)
8. `codeql resolve packs` (if codeql packs downloaded)
9. Print manual steps (Neovim LSP, VS Code extensions)

### `test-tool-installs.sh` gaps

Add missing tools:
- `ruff`
- `bun`
- `gcloud`
- `codeql`
- `markdownlint-cli2`
- `code` (VS Code CLI, skip if not installed)

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

---

## Performance (deferred)

### Shell startup caching — MEASURE FIRST

Eight sequential `eval` calls add ~300-600ms to shell startup.
Caching eval output to `~/.cache/dotfiles/<tool>.bash` could reduce
this by 90%.

**Decision**: Measure actual startup time on target hardware before
implementing. Add a `time bash -ic exit` benchmark to `verify.sh`.
If startup exceeds 500ms, implement caching.

### Other performance notes (implement now)

- Starship `scan_timeout = 30` — prevents slow prompts in large repos
- Containerfile layer ordering — enforce expensive ops first
- `fzf --max-depth 6` — optional tuning for large monorepos
  (add to FZF_DEFAULT_COMMAND if needed, not by default)

---

## Deferred (future design documents)

- **Proxy-based allowlist and audit** — mitmproxy + cntlm for
  credential injection, destination allowlisting, and traffic audit.
  Significant infrastructure; design separately.
- **`--network=none` for offline agent runs** — requires proxy above
  to be practical.
- **Shell startup caching** — measure before implementing.

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
