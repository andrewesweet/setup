# macos-dev

Personal dotfiles for macOS (Apple Silicon) + WSL2 (Ubuntu) + Podman container (Wolfi Linux). Team-shareable baseline for a senior engineering leader at a regulated financial institution.

## Quick start

### macOS

```bash
git clone <repo-url> ~/setup
cd ~/setup/macos-dev

# Install Homebrew if not present
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Switch to Homebrew bash 5
chsh -s "$(brew --prefix)/bin/bash"

# Run the installer
bash install-macos.sh

# Post-install manual steps
opencode auth login       # GitHub Copilot
gcloud auth login         # GCP
```

### WSL2

```bash
git clone <repo-url> ~/setup
cd ~/setup/macos-dev

bash install-wsl.sh

# Post-install manual steps
opencode auth login
gcloud auth login
```

After installation, restart your terminal.

## What's included

- **Shell:** Bash 5, starship prompt, vi-mode, fzf/zoxide integration
- **Terminal:** Kitty, tmux (Ctrl+A prefix, vim-tmux-navigator)
- **Git:** delta (side-by-side diffs), lazygit, difftastic, cocogitto, git-cliff, critique
- **Editor:** Neovim (LazyVim), VS Code (remote backend support)
- **Languages:** mise (version management), uv (Python), direnv
- **Search:** fd, ripgrep, fzf, zoxide, bat
- **Linting:** shellcheck, shfmt, markdownlint-cli2, golangci-lint, tflint, actionlint
- **GitHub Actions:** zizmor (audit), pinact (pin actions)
- **Pre-commit:** prek (Rust-native pre-commit replacement)
- **Cloud:** gcloud SDK, bq, kubernetes-cli, k9s, kubectx
- **Container:** Podman + Wolfi-based dev container, lazydocker
- **AI:** OpenCode with GitHub Copilot

## Repository structure

```
macos-dev/
├── README.md
├── Brewfile                    # All Homebrew formulae and casks
├── tools.txt                   # Shared tool manifest
├── install-macos.sh            # macOS installer
├── install-wsl.sh              # WSL2 installer
├── .gitignore
├── docs/
│   ├── cheatsheet.md           # Key bindings and tool reference
│   └── design/                 # Design specifications
├── bash/                       # .bash_profile, .bashrc, .bash_aliases, .inputrc
├── git/                        # .gitconfig, .gitignore_global
├── kitty/                      # kitty.conf
├── tmux/                       # .tmux.conf
├── starship/                   # starship.toml
├── lazygit/                    # config.yml
├── opencode/                   # opencode.jsonc, tui.jsonc, instructions/
├── mise/                       # config.toml (global tool versions)
├── nvim/                       # Neovim config (LazyVim)
├── prek/                       # .pre-commit-config.yaml
├── vscode/                     # settings.json, extensions.json
├── container/                  # Containerfile, dev.sh, supporting files
└── scripts/                    # verify.sh, check-configs.sh, test suites
```

## Repo layout

All git checkouts live under a single root, organised by host/org/repo:

```
~/code/<host>/<org>/<repo>

Examples:
  ~/code/github.com/anthropics/claude-code
  ~/code/gitlab.com/some-org/service
  ~/code/gitlab.mycompany.com/team/repo
```

Enforced by [ghq](https://github.com/x-motemen/ghq) (`ghq.root = ~/code`). Helpers:

- **`repo`** — fzf picker over all ghq-managed checkouts. Bound to `Alt-R`.
- **`gclone <url>`** — `ghq get -u` + cd to the canonical path.
- **`ghorg-gh <org>`** — bulk-clone a GitHub org into `~/code/github.com/<org>/`.

For the coding agents' convention (OpenCode, GitHub Copilot), run once:

```bash
bash scripts/install-ai-conventions.sh
```

**WSL2**: `~/code` MUST be on ext4, never `/mnt/c/`. `install-wsl.sh` hard-aborts if `$HOME` resolves under `/mnt/c/`.

## Configuration

### Local overrides

These files allow machine-specific customization without modifying tracked dotfiles.
All are in `.gitignore` and never committed. The installer scaffolds empty defaults where needed.

| File / Directory | Purpose |
|-----------------|---------|
| `~/.bashrc.local` | Extra shell config, aliases, exports |
| `~/.gitconfig.local` | Work-specific Git author, signing key |
| `~/.config/opencode-local/opencode.jsonc` | Personal OpenCode config overrides (model, permissions) |
| `~/.config/opencode-local/` | Personal OpenCode agents, commands, modes, plugins |
| `container/dev.env` | Environment variables for dev container |
| `container/custom-ca.pem` | Corporate TLS proxy CA certificate (for container builds) |

**OpenCode override precedence:**
Remote (org) -> Global (team baseline in `~/.config/opencode/`) -> Custom (personal in `~/.config/opencode-local/`) -> Project (`./opencode.jsonc`).
Each layer overrides the previous. To change where personal overrides are stored, set `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR` in `~/.bashrc.local`.

**VS Code-primary users:** Add `export EDITOR='code --wait'` to `~/.bashrc.local` to use VS Code as the default editor instead of Neovim.

### Environment variables

| Variable | Purpose |
|----------|---------|
| `DOTFILES` | Path to the macos-dev directory (auto-detected) |
| `EDITOR` | Set to `nvim` if available, falls back to `code --wait` |
| `HOMEBREW_PREFIX` | Detected dynamically via `brew --prefix` |
| `OPENCODE_CONFIG` | Personal OpenCode config path (default: `~/.config/opencode-local/opencode.jsonc`) |
| `OPENCODE_CONFIG_DIR` | Personal OpenCode directory for agents/commands/modes/plugins (default: `~/.config/opencode-local/`) |

## Testing

Plan-specific acceptance tests live in `scripts/test-plan*.sh`. Each one validates a single plan's contract end-to-end (typically a few dozen ACs).

```bash
# Layer 1a — atuin + television + Dracula starship
bash scripts/test-plan-layer1a.sh           # safe checks only (CI default)
bash scripts/test-plan-layer1a.sh --full    # + invasive checks (requires installed tools)

# Plan 14–16 — historical
bash scripts/test-plan14-16.sh
```

Both safe-mode and full-mode return non-zero if any check fails. Run safe mode anywhere; full mode requires the corresponding tools installed and (for some checks) macOS.

## Container development

The `dev` script manages a Podman-based development container:

```bash
dev init-machine           # First-time: create Podman machine
dev build                  # Build the dev container image
dev shell                  # Start an interactive shell
dev stop                   # Stop the running container
dev rebuild                # Rebuild and restart
dev status                 # Show container status
dev prune                  # Clean up old images
```

The container runs Wolfi Linux with all CLI tools pre-installed. It mounts your workspace and SSH agent, with read-only filesystem and dropped capabilities for security.

**Corporate proxy:** If your network uses a TLS-inspecting proxy, place your CA bundle at `container/custom-ca.pem` (gitignored). The `dev build` command auto-detects it and injects it into the build. Host `http_proxy`/`https_proxy` env vars are auto-forwarded with loopback addresses rewritten for Podman Machine.

### Container SSH forwarding (macOS)

macOS ships with a launchd-managed `ssh-agent` whose socket lives under `/private/tmp/com.apple.launchd.*`. Those sockets live in per-process launchd namespaces that Podman Machine's virtiofs **cannot** forward into the VM (bind-mounting fails with `statfs: operation not supported`). `dev shell` detects this pattern and skips the mount with a warning — the container still starts, but `ssh-add -l` will be unavailable inside.

To get SSH forwarding working, run a standalone `ssh-agent` in your host shell before launching the container:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519     # or whichever key you use
bash container/dev.sh shell
```

That agent's socket lives under `/tmp/ssh-XXXXXXXX/agent.NNN`, which is a regular directory Podman Machine can share. Add the two commands to a shell alias or `.bashrc.local` if you want them to run automatically.

If you only push to GitHub, `gh auth login` + HTTPS remotes is a lower-friction alternative — `gh` uses its own credentials via the mounted `~/.config/gh` directory, no SSH agent required.

### Known limitations

| Tool | Container | Host | Reason |
|------|-----------|------|--------|
| codeql | Not available | Homebrew cask | No arm64 Linux build; x86_64 only |
| pandoc | Not available | Homebrew | Not in Wolfi apk; used on host for cheatsheet PDF generation |
| lnav | Not available | Homebrew | Not in Wolfi apk |
| kubectx | Not available | Homebrew | Not in Wolfi apk |

## Cheatsheet

A built-in cheatsheet covers key bindings and tool commands:

```bash
cheat                      # Full cheatsheet (rendered with glow)
cheat keys                 # Page 1: key bindings across all tools
cheat tools                # Page 2: tool-for-the-job reference
```

Generate a PDF for printing:

```bash
pandoc docs/cheatsheet.md -o docs/cheatsheet.pdf --pdf-engine=typst
```

## Design documents

Detailed design specifications live in `docs/design/`:

| Document | Covers |
|----------|--------|
| [DESIGN.md](docs/design/DESIGN.md) | Index, constraints, repo structure |
| [shell.md](docs/design/shell.md) | Bash config, aliases, completions |
| [terminal.md](docs/design/terminal.md) | Kitty, tmux, starship |
| [git.md](docs/design/git.md) | Git config, delta, lazygit, conventional commits |
| [editor-neovim.md](docs/design/editor-neovim.md) | LazyVim, LSP, formatters |
| [editor-vscode.md](docs/design/editor-vscode.md) | VS Code settings, extensions |
| [languages.md](docs/design/languages.md) | mise, uv, direnv, prek, quality tools |
| [opencode.md](docs/design/opencode.md) | OpenCode config, instructions |
| [container.md](docs/design/container.md) | Podman, Containerfile, dev script |
| [install.md](docs/design/install.md) | Installation, Brewfile, verification |
| [security.md](docs/design/security.md) | Permissions, credentials, hardening |
| [cheatsheet-spec.md](docs/design/cheatsheet-spec.md) | Cheatsheet design and format |

## License

MIT
