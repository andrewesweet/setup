# Dotfiles — Design Document

This document gives Claude Code (and future contributors) the context,
constraints, and decisions behind this dotfiles repository. Read this
file and all files in `docs/design/` before making any changes.

---

## What this repo is

A personal dotfiles repository for a macOS-based senior engineering
leader at a regulated financial institution (Deutsche Bank). The setup
is designed to be team-shareable as a baseline for engineers adopting
a CLI/TUI-driven development workflow.

The owner uses GitHub Enterprise Managed Users (EMU) and GitHub Copilot
as the sole AI provider. All tooling must be compatible with that
constraint.

---

## Design documents

Read these in order before implementing anything:

| File | Covers |
|------|--------|
| `docs/design/dotfiles-setup.md` | Core setup: bash, kitty, starship, tmux, lazygit, git config, fzf, zoxide, delta, bat, ripgrep, fd, jq, yq, httpie, lnav, btop, glow, the full alias scheme |
| `docs/design/dotfiles-opencode-critique.md` | OpenCode config, critique shell functions, tui.jsonc keybinds, instruction files, vim keybinding reference |
| `docs/design/dotfiles-language-ecosystem.md` | mise, uv, direnv, pinact, prek, team-baseline `.pre-commit-config.yaml`, per-language quality tools |
| `docs/design/dotfiles-neovim.md` | LazyVim config, all LSP setup, formatter/linter config, lazygit.nvim, fzf-lua, gitsigns, vim-tmux-navigator, direnv.vim |
| `docs/design/dotfiles-container.md` | Podman + Wolfi container environment, multi-stage Containerfile, `dev` lifecycle script, mount strategy, security hardening |
| `docs/design/dotfiles-cross-platform.md` | macOS / WSL2 / container platform guards, install scripts, OSC 9 notifications, dynamic Homebrew prefix |
| `docs/design/dotfiles-review-fixes.md` | All fixes from adversarial reviews: alias changes, keybind fixes, cheatsheet, UX improvements |

---

## Key constraints

### Must not violate these

- **GitHub Copilot only** as the AI provider for OpenCode. No direct
  Anthropic API, no Vertex AI, no OpenRouter. The model string format
  is `github-copilot/<model>`. Credentials are managed by
  `opencode auth login` and stored in `~/.local/share/opencode/auth.json`.
  Never hardcode tokens in config files.

- **No secrets in dotfiles**. All credentials come from environment
  variables, `gh auth token`, or tool-managed credential stores.
  `.gitignore` must cover all common secret file patterns.

- **Defensive OpenCode permissions**. The global default is `"*": "ask"`.
  Specific safe patterns are explicitly allowed. `rm -rf *`, `sudo *`,
  and `chmod 777 *` are explicitly denied. See `opencode.jsonc`.

- **vim keybindings everywhere possible**. The single scheme investment
  transfers across lazygit, btop, lnav, tmux copy mode, Neovim, and
  the shell. The only hardcoded exception is the OpenCode input area,
  which uses emacs-style bindings that cannot be changed.

- **No `require('lspconfig')` in Neovim config**. Use `vim.lsp.config`
  and `vim.lsp.enable` (Neovim 0.11+ native API). nvim-lspconfig is
  still a dependency for its server definitions, but the old setup{}
  pattern is deprecated.

- **ty is not installed via Mason**. It is installed via
  `uv tool install ty@latest`. Do not add it to Mason's
  `ensure_installed` list.

- **prek is not on Homebrew**. It is installed via `uv tool install prek`.

- **pinact is managed via mise**, not Homebrew. See `~/.config/mise/config.toml`.

### Strongly preferred

- Single binary / Rust-native tools preferred over Python/Node wrappers
  where equivalent quality exists (e.g. delta over diff-highlight,
  fd over find, rg over grep, zoxide over autojump, prek over pre-commit).

- Aliases follow a prefix scheme: `g*` for git, `f*` for search,
  `p*` for process/ports, `t*` for tmux, `pk*` for prek, `uv*` for uv,
  `m*` for mise, `cr*` for critique, `gha-*` for GitHub Actions tooling.
  New aliases should follow this scheme.

- Config files use JSONC (JSON with comments) where the tool supports it.
  Comments explain non-obvious decisions, especially permission rules.

---

## OS targets

Three platforms, one set of configs:

- **macOS** (Apple Silicon, Homebrew). Bash 5 via Homebrew. Kitty
  terminal emulator. Starship prompt. Homebrew prefix detected
  dynamically (not hardcoded to `/opt/homebrew`).
- **WSL2** (Ubuntu on Windows 11). Kitty via WSLg (primary), Windows
  Terminal (fallback). Tools via apt + install scripts.
- **Container** (Wolfi Linux under Podman). Accessed via `dev shell`.
  See `dotfiles-container.md` and `dotfiles-cross-platform.md`.

---

## Architecture decisions

### Version management: mise

mise manages Python, Go, and pinact versions. It replaces pyenv and
goenv. The global config is at `~/.config/mise/config.toml`. Each repo
gets a `.mise.toml` pinning its language versions.

`auto_install = true` is set globally so mise installs missing tools
when entering a directory with a `.mise.toml`.

### Python toolchain: full Astral stack

- **mise** manages the Python interpreter version
- **uv** manages packages, virtual environments, and globally installed tools
- **ruff** handles linting and formatting (replaces flake8, black, isort)
- **ty** handles type checking and LSP (replaces pyright/basedpyright)

ty is in beta as of April 2026. It is the chosen type checker. If it
causes persistent problems on a repo, the fallback is
`vim.g.lazyvim_python_lsp = "basedpyright"` in Neovim and installing
basedpyright via Mason.

### Neovim: LazyVim distribution

LazyVim is the chosen starting point, not a hand-rolled config. The
config in `lua/plugins/` overrides and extends LazyVim defaults rather
than replacing them. Do not fight LazyVim's defaults — extend them.

The Python LSP is switched from basedpyright to ty via the single global:
`vim.g.lazyvim_python_lsp = "ty"` in `lua/plugins/lsp.lua`.

### GitHub Actions LSP scoping

The GitHub Actions Language Server (`gh_actions_ls`) must only activate
on workflow and composite action files — not on all YAML. This is
achieved by:

1. Defining a custom `yaml.github` filetype in `lua/config/autocmds.lua`
   using `vim.filetype.add()` with path-based Lua patterns
2. Configuring `gh_actions_ls` with `filetypes = { "yaml.github" }`
3. Configuring `yamlls` with `filetypes = { "yaml" }` (explicitly
   excludes `yaml.github`)

The patterns cover:
- `.github/workflows/*.yml` / `.yaml`
- `.github/actions/<name>/action.yml` / `.yaml`
- Root-level `action.yml` / `action.yaml` (standalone action repos)

Root-level action files are matched by filename only, which may produce
false positives in repos with unrelated `action.yml` files. The escape
hatch is a modeline: `# vim: ft=yaml`

### zizmor vs pinact division of labour

- **zizmor** runs as a prek hook (blocking gate at commit time) and as
  an nvim-lint linter (inline diagnostics while editing). It enforces
  both security issues and SHA pinning via its `unpinned-uses` rule.
- **pinact** is an interactive tool for pinning actions when authoring
  workflows. It requires a `GITHUB_TOKEN` to resolve SHAs and is not
  suitable as a blocking commit hook.

The workflow is: `gha-pin` (pinact) to pin while authoring, then zizmor
catches anything missed at commit time.

### tmux clipboard

`pbcopy` is macOS-only. tmux is configured with `set-clipboard on` to
forward OSC 52 sequences to Kitty, which writes to the macOS clipboard.
This is the mechanism that will also work in the future container variant.

### OpenCode `/tmp` access

`$TMPDIR` on macOS resolves to a session-specific path under
`/private/var/folders/...` and cannot be referenced by environment
variable name in OpenCode permission patterns (only `~` and `$HOME`
expansion is supported).

`/tmp` is used instead — it is a stable symlink to `/private/tmp` on
macOS. The `external_directory` permission allows `/tmp/**`. The
`scratch-dirs.md` instruction file tells the agent to prefer `/tmp`.

There is a known upstream bug (opencode issue #20045) where `edit`
permissions use relative paths internally while `external_directory`
uses absolute paths, meaning an `edit` allow rule for `/tmp/**` may
not match. Agent writes to `/tmp` typically go via `bash` commands
rather than the edit tool directly, so this is unlikely to cause
friction in practice.

---

## What is deferred / not yet designed

Now designed and ready to implement:

- **vhs, freeze, asciinema** — terminal recording tools. Add to
  Brewfile (freeze via `charmbracelet/tap`). No config files needed.
- **k9s, kubectl, kubectx** — Kubernetes tools. Add to Brewfile.
- **tenv** — Terraform version manager. Add to Brewfile. Note:
  conflicts with `atmos` in Homebrew (both install `atmos` binary).
- **tf-summarize** — Terraform plan formatter. Add to Brewfile.
  Alias: `tfsum`. Uses `-v` for version (not `--version`).
- **lazydocker** — Container TUI. Add to Brewfile. Alias: `lzd`.
- **Podman / Wolfi container** — see `dotfiles-container.md`.
- **Cross-platform (macOS + WSL2)** — see `dotfiles-cross-platform.md`.
- **Notifications** — OSC 9 replaces terminal-notifier. See
  `dotfiles-cross-platform.md`.
- **Cheatsheet** — key bindings + tool reference. See
  `dotfiles-review-fixes.md`.

Still deferred — do not implement without a new design document:

- **Shell history sync across machines** — evaluated and skipped.
  Re-evaluate if multi-machine workflow becomes a need.
- **sops + age** — secrets management. Not included in this iteration.

---

## What to ask about vs what to fill in

### Ask the user before deciding

- Exact model strings for GitHub Copilot (verify with
  `opencode models list | grep copilot` after auth)
- Specific tool versions in the Brewfile (prefer `latest` / no version
  pin for Homebrew formulae unless there is a known compatibility issue)
- Any config that touches DB-specific infrastructure (Terraform workspaces,
  GCP project IDs, GitHub Enterprise endpoint URLs)
- Whether to enable experimental OpenCode features
  (`OPENCODE_EXPERIMENTAL_LSP_TOOL`)

### Fill in from upstream documentation

- LazyVim bootstrap `init.lua` — copy from
  https://github.com/LazyVim/starter verbatim
- Exact lazy.nvim plugin specs — follow LazyVim conventions
- Mason tool names — verify against `:Mason` search or
  https://mason-registry.dev
- prek hook revisions — run `prek autoupdate` after initial install
  rather than hardcoding versions

### Do not invent

- API keys, tokens, or credentials of any kind
- GitHub organisation names, repo names, or Enterprise URLs
- DB-internal configuration or compliance-specific settings
- Behaviour not described in the design documents

---

## Repo structure (target)

```
macos-dev/
├── README.md                        # index + team onboarding
├── Brewfile                         # all Homebrew installs
├── tools.txt                        # shared tool manifest
├── install-macos.sh                 # macOS install + symlinks
├── install-wsl.sh                   # WSL2 Ubuntu install + symlinks
├── .gitignore
│
├── docs/
│   ├── cheatsheet.md                # key bindings + tool reference
│   └── design/                      # design documents
│       ├── DESIGN.md
│       ├── dotfiles-setup.md
│       ├── dotfiles-opencode-critique.md
│       ├── dotfiles-language-ecosystem.md
│       ├── dotfiles-neovim.md
│       ├── dotfiles-container.md
│       ├── dotfiles-cross-platform.md
│       └── dotfiles-review-fixes.md
│
├── bash/
│   ├── .bash_profile
│   ├── .bashrc
│   ├── .bash_aliases
│   └── .inputrc
│
├── git/
│   ├── .gitconfig
│   └── .gitignore_global
│
├── kitty/
│   └── kitty.conf
│
├── tmux/
│   └── .tmux.conf
│
├── starship/
│   └── starship.toml
│
├── lazygit/
│   └── config.yml
│
├── opencode/
│   ├── opencode.jsonc
│   ├── tui.jsonc
│   └── instructions/
│       ├── git-conventions.md
│       └── scratch-dirs.md
│
├── mise/
│   └── config.toml
│
├── nvim/
│   ├── init.lua                     # LazyVim bootstrap
│   ├── lazy-lock.json               # generated; commit for reproducibility
│   └── lua/
│       ├── config/
│       │   ├── options.lua
│       │   ├── keymaps.lua
│       │   └── autocmds.lua
│       └── plugins/
│           ├── lsp.lua
│           ├── formatting.lua
│           ├── linting.lua
│           └── integrations.lua
│
├── prek/
│   └── .pre-commit-config.yaml      # team baseline template
│
└── container/
    ├── Containerfile                 # multi-stage (base + full)
    ├── dev.sh                        # lifecycle management script
    ├── dev.env.example               # env var template
    ├── test-tool-installs.sh         # tool verification script
    └── .dockerignore
```

---

## Implementation order

When implementing from scratch, follow this order to avoid dependency
issues:

1. `.gitignore`, `tools.txt`, and `Brewfile`
2. `install-macos.sh` and `install-wsl.sh`
3. `bash/` — `.bash_profile`, `.bashrc`, `.bash_aliases`, `.inputrc`
4. `git/` — `.gitconfig`, `.gitignore_global`
5. `kitty/kitty.conf`
6. `tmux/.tmux.conf`
7. `starship/starship.toml`
8. `lazygit/config.yml`
9. `mise/config.toml`
10. `opencode/` — all files
11. `nvim/` — init.lua bootstrap first, then lua/ files
12. `prek/.pre-commit-config.yaml`
13. `container/` — Containerfile, dev.sh, dev.env.example, .dockerignore
14. `docs/cheatsheet.md`
15. `README.md` — after everything else exists

---

## Relationship between documents

```
dotfiles-setup.md
  └── establishes: bash, git, kitty, tmux, starship, lazygit,
                   core CLI tools, alias scheme, keybinding scheme

dotfiles-opencode-critique.md
  ├── extends: bash aliases (adds cr*, crs functions)
  ├── extends: tmux (OSC 52 clipboard note)
  └── adds: opencode/, tui.jsonc, instruction files

dotfiles-language-ecosystem.md
  ├── extends: bash aliases (adds uv*, mx, pk*, gha-*, da, dr)
  ├── extends: Brewfile (language tools)
  └── adds: mise/, prek/, direnv hook in .bashrc

dotfiles-neovim.md
  ├── extends: bash (sets $EDITOR=nvim, $MANPAGER)
  ├── extends: bash aliases (adds v, vd)
  ├── extends: tmux (adds vim-tmux-navigator bindings)
  ├── extends: Brewfile (neovim, node)
  └── adds: nvim/

dotfiles-container.md
  ├── extends: Brewfile (adds podman)
  └── adds: container/ (Containerfile, dev.sh, dev.env.example)

dotfiles-cross-platform.md
  ├── modifies: bash (.bashrc platform guards, guarded evals,
  │             OSC 9 notifications, conditional EDITOR/MANPAGER)
  ├── modifies: bash aliases (conditional ports)
  ├── modifies: tmux (OSC 52 only, no pbcopy)
  ├── modifies: git (removes editor from .gitconfig)
  ├── renames: install.sh → install-macos.sh
  └── adds: install-wsl.sh, tools.txt

dotfiles-review-fixes.md
  ├── modifies: bash aliases (fd→fdd, removes shadows, lg not gl,
  │             adds aliases function, adds drd, gha-fix, notify)
  ├── modifies: lazygit (delta syntax-theme)
  ├── modifies: starship (adds golang module)
  ├── modifies: nvim integrations (fzf-lua zoxide picker)
  ├── modifies: tmux (Ctrl+L workaround)
  └── adds: docs/cheatsheet.md, pandoc to Brewfile
```
