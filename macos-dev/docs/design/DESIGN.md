# Design Specification Index

This repository contains unified design specifications for a personal dotfiles repository managed as a senior engineering leader's configuration baseline, with design choices documented to support team-shareable standardization.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY",
and "OPTIONAL" in these documents are to be interpreted as described
in BCP 14 [RFC 2119] [RFC 8174] when, and only when, they appear in
all capitals, as shown here.

## What this repo is

A personal dotfiles repository for a macOS-based senior engineering leader at a regulated financial institution. Team-shareable baseline. Uses GitHub Enterprise Managed Users and GitHub Copilot as sole AI provider. Three platforms: macOS (Apple Silicon, Homebrew), WSL2 (Ubuntu on Windows 11, Kitty via WSLg primary / Windows Terminal fallback), Container (Wolfi Linux under Podman). The repo lives in `andrewesweet/setup` under the `macos-dev/` subdirectory.

## Design documents

| File | Covers |
|------|--------|
| shell.md | Bash config, aliases, completions, platform guards, notifications, .inputrc |
| terminal.md | Kitty, tmux, starship |
| git.md | .gitconfig, .gitignore_global, delta, lazygit, conventional commits |
| editor-neovim.md | LazyVim, LSP, formatters, linters, integrations |
| editor-vscode.md | VS Code settings, extensions, remote backends, two personas |
| languages.md | mise, uv, direnv, prek, per-language quality tools, markdownlint-cli2 |
| opencode.md | OpenCode config, tui.jsonc, instruction files, critique |
| container.md | Podman + Wolfi, Containerfile, dev script, mounts, security |
| install.md | install-macos.sh, install-wsl.sh, tools.txt, Brewfile, verification |
| security.md | OpenCode permissions, credentials, .gitignore_global, container hardening |
| cheatsheet-spec.md | Cheatsheet design, cheat function, PDF generation |

## Key constraints (MUST NOT violate)

- GitHub Copilot only as AI provider for OpenCode. Model format `github-copilot/<model>`. Credentials managed by `opencode auth login`. MUST NOT hardcode tokens.
- No secrets in dotfiles. All credentials from env vars, `gh auth token`, or tool-managed stores. `.gitignore` MUST cover common secret patterns.
- Defensive OpenCode permissions. Global default `"*": "ask"`. Read scoped to workspace + tmp + specific config paths. `rm -rf *`, `sudo *`, `chmod 777 *` explicitly denied.
- vim keybindings everywhere possible. One scheme across lazygit, btop, lnav, tmux copy mode, Neovim, shell. Exception: OpenCode input area (hardcoded emacs).
- No `require('lspconfig')` in Neovim config. Use `vim.lsp.config` / `vim.lsp.enable`. nvim-lspconfig is a dependency for server definitions only.
- ty installed via `uv tool install ty@latest`, NOT Mason.
- prek installed via `uv tool install prek`, NOT Homebrew.
- pinact installed via Homebrew.
- Single-binary / Rust-native tools SHOULD be preferred over Python/Node wrappers.
- Aliases MUST follow prefix scheme: g* git, f* search, p* process, t* tmux, pk* prek, uv* uv, m* mise, cr* critique, gha-* GitHub Actions, gc/gcp/gcl/gca/gcr/gce/gke/gsq gcloud, cql* codeql.
- Config files SHOULD use JSONC where supported. Comments MUST explain non-obvious decisions.

## OS targets

Three platforms, one set of configs:
- macOS (Apple Silicon, Homebrew — prefix detected dynamically)
- WSL2 (Ubuntu on Windows 11, Kitty via WSLg primary, Windows Terminal fallback)
- Container (Wolfi Linux under Podman, accessed via `dev shell`)

## Architecture decisions (brief summaries pointing to detailed docs)

- Version management: mise (see languages.md)
- Python toolchain: full Astral stack — mise + uv + ruff + ty (see languages.md)
- Neovim: LazyVim distribution (see editor-neovim.md)
- GitHub Actions LSP scoping: yaml.github filetype (see editor-neovim.md)
- zizmor vs pinact: zizmor = blocking gate, pinact = interactive authoring (see languages.md)
- tmux clipboard: OSC 52 everywhere, no pbcopy (see terminal.md)
- Container: AI agent sandbox primary, team dev env secondary (see container.md)
- Notifications: OSC 9 escape sequences, no terminal-notifier (see shell.md)
- Editor: conditional — nvim if present, code --wait fallback (see shell.md)

## Deferred — do not implement without new design document

- Proxy-based allowlist and audit (mitmproxy + cntlm)
- Shell startup caching (measure first with `time bash -ic exit`)
- Shell history sync across machines
- sops + age secrets management

## What to ask about vs fill in

Ask: exact Copilot model strings, tool versions, DB-specific infrastructure, experimental OpenCode features.
Fill in: LazyVim bootstrap init.lua (from starter repo), lazy.nvim plugin specs, Mason tool names, prek hook revisions.
Do not invent: API keys/tokens/credentials, GitHub org names/repo names/Enterprise URLs, DB-internal config, behaviour not in design docs.

## Repo structure

```
macos-dev/
├── README.md
├── Brewfile
├── tools.txt
├── install-macos.sh
├── install-wsl.sh
├── .gitignore
├── docs/
│   ├── cheatsheet.md
│   └── design/
│       ├── DESIGN.md
│       ├── shell.md
│       ├── terminal.md
│       ├── git.md
│       ├── editor-neovim.md
│       ├── editor-vscode.md
│       ├── languages.md
│       ├── opencode.md
│       ├── container.md
│       ├── install.md
│       ├── security.md
│       └── cheatsheet-spec.md
├── bash/
│   ├── .bash_profile
│   ├── .bashrc
│   ├── .bash_aliases
│   └── .inputrc
├── git/
│   ├── .gitconfig
│   └── .gitignore_global
├── kitty/
│   └── kitty.conf
├── tmux/
│   └── .tmux.conf
├── starship/
│   └── starship.toml
├── lazygit/
│   └── config.yml
├── opencode/
│   ├── opencode.jsonc
│   ├── tui.jsonc
│   └── instructions/
│       ├── git-conventions.md
│       └── scratch-dirs.md
├── mise/
│   └── config.toml
├── nvim/
│   ├── init.lua
│   ├── lazy-lock.json
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
├── prek/
│   └── .pre-commit-config.yaml
├── vscode/
│   ├── settings.json
│   └── extensions.json
├── container/
│   ├── Containerfile
│   ├── dev.sh
│   ├── dev.env.example
│   ├── test-tool-installs.sh
│   └── .dockerignore
└── scripts/
    ├── verify.sh
    ├── check-configs.sh
    └── check-tool-manifest.sh
```

## Implementation order

1. .gitignore, tools.txt, Brewfile
2. install-macos.sh, install-wsl.sh
3. bash/ (.bash_profile, .bashrc, .bash_aliases, .inputrc)
4. git/ (.gitconfig, .gitignore_global)
5. kitty/kitty.conf
6. tmux/.tmux.conf
7. starship/starship.toml
8. lazygit/config.yml
9. mise/config.toml
10. opencode/ (all files)
11. nvim/ (init.lua first, then lua/)
12. prek/.pre-commit-config.yaml
13. vscode/ (settings.json, extensions.json)
14. container/ (Containerfile, dev.sh, dev.env.example, .dockerignore)
15. scripts/ (verify.sh, check-configs.sh, check-tool-manifest.sh)
16. docs/cheatsheet.md
17. README.md
