# VS Code integration

Extends all prior design documents. Covers VS Code as a parallel
editor for team members who prefer a GUI workflow, and as a fallback
for TUI-first users learning the CLI/TUI stack.

---

## Two personas

### TUI-first (primary editor: Neovim)

- Uses Neovim as `$EDITOR`, tmux for sessions, lazygit for git
- Falls back to VS Code for specific tasks (complex merges, visual
  diff review, Jupyter notebooks, large refactors)
- `$EDITOR` is `nvim` when present (conditional in `.bashrc`)
- VS Code is available but not the default

### VS Code-primary (primary editor: VS Code)

- Uses VS Code for all editing, may not use tmux
- Still benefits from the full CLI toolchain (fzf, rg, fd, bat,
  delta, lazygit, mise, uv, prek, gcloud, etc.)
- `$EDITOR` is `code --wait`
- Terminal inside VS Code uses the same bash config, aliases, and
  completions

Both personas share the same dotfiles repo. The difference is the
`$EDITOR` conditional and whether they launch tmux.

---

## Platforms and remote backends

| Platform | VS Code model | Notes |
|----------|--------------|-------|
| macOS | Local backend | VS Code runs natively, accesses local filesystem |
| WSL2 | Remote-WSL | VS Code on Windows, backend in WSL2 Ubuntu VM. Extensions run inside WSL2. |
| Container | Dev Containers | VS Code on host, backend inside Podman container. Extensions run inside container. |

### macOS

Standard local installation. Homebrew cask:

```ruby
cask "visual-studio-code"
```

### WSL2

VS Code is installed on Windows (not inside WSL2). The Remote-WSL
extension connects to the Ubuntu VM automatically. All file editing,
terminal, and extensions run inside WSL2.

The bash config, aliases, and all CLI tools are available in the
VS Code integrated terminal because it opens a WSL2 bash shell.

No special dotfiles config needed — the Remote-WSL extension handles
the connection transparently.

### Container (Dev Containers)

VS Code's Dev Containers extension can attach to a running Podman
container. Two usage modes:

**Mode A: Attach to existing `dev` container**

The user runs `dev shell` from the host first, then uses
"Dev Containers: Attach to Running Container" in VS Code. This
preserves the `dev` script's mount strategy, security settings, and
named volumes.

**Mode B: Dev Container config (`.devcontainer/`)**

A `.devcontainer/devcontainer.json` in each repo tells VS Code how
to build/start the container. This is the more integrated approach
but means the container lifecycle is managed by VS Code, not the
`dev` script.

Recommendation: **Mode A** for TUI-first users (they already have
`dev shell` running). **Mode B** for VS Code-primary users who don't
use `dev shell`.

For Mode B, provide a template `.devcontainer/devcontainer.json`:

```jsonc
// .devcontainer/devcontainer.json
// Uses the same Containerfile from the dotfiles repo.
{
  "name": "dev",
  "build": {
    "dockerfile": "Containerfile",
    "target": "full"
  },
  "containerUser": "dev",
  "remoteUser": "dev",

  // Mount strategy matches dev.sh
  "mounts": [
    "source=${localWorkspaceFolder},target=/home/dev/workspace,type=bind",
    "source=dev-cache-uv,target=/home/dev/.cache/uv,type=volume",
    "source=dev-cache-go,target=/home/dev/.local/go,type=volume",
    "source=dev-cache-mise,target=/home/dev/.local/share/mise,type=volume",
    "source=dev-cache-mason,target=/home/dev/.local/share/nvim/mason,type=volume",
    "source=dev-data-opencode,target=/home/dev/.local/share/opencode,type=volume"
  ],

  // Extensions to install inside the container
  "customizations": {
    "vscode": {
      "extensions": [
        // See extensions list below
      ]
    }
  },

  "postCreateCommand": "echo 'Dev container ready.'"
}
```

Note: Dev Containers with Podman requires setting
`"dev.containers.dockerPath": "podman"` in VS Code user settings.

---

## VS Code settings template

`vscode/settings.json` — committed to dotfiles, symlinked to
`~/.config/Code/User/settings.json` (macOS) or
`~/.vscode-server/data/Machine/settings.json` (remote).

```jsonc
// settings.json
{
  // ── Editor ────────────────────────────────────────────────────────
  "editor.fontSize": 13,
  "editor.fontFamily": "JetBrains Mono, monospace",
  "editor.fontLigatures": true,
  "editor.tabSize": 2,
  "editor.insertSpaces": true,
  "editor.formatOnSave": true,
  "editor.defaultFormatter": null,
  "editor.rulers": [100],
  "editor.renderWhitespace": "trailing",
  "editor.bracketPairColorization.enabled": true,
  "editor.minimap.enabled": false,

  // ── Terminal ──────────────────────────────────────────────────────
  // Uses the same bash config as the standalone terminal
  "terminal.integrated.defaultProfile.osx": "bash",
  "terminal.integrated.defaultProfile.linux": "bash",
  "terminal.integrated.fontFamily": "JetBrains Mono",
  "terminal.integrated.fontSize": 13,

  // ── Files ─────────────────────────────────────────────────────────
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.trimFinalNewlines": true,
  "files.exclude": {
    "**/.DS_Store": true,
    "**/__pycache__": true,
    "**/.pytest_cache": true,
    "**/node_modules": true
  },

  // ── Git ───────────────────────────────────────────────────────────
  "git.autofetch": true,
  "git.confirmSync": false,
  "git.enableSmartCommit": true,
  "diffEditor.renderSideBySide": true,

  // ── Python ────────────────────────────────────────────────────────
  // Ruff handles formatting and linting; ty handles type checking
  "[python]": {
    "editor.defaultFormatter": "charliermarsh.ruff",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.fixAll.ruff": "explicit",
      "source.organizeImports.ruff": "explicit"
    }
  },

  // ── Go ────────────────────────────────────────────────────────────
  "[go]": {
    "editor.defaultFormatter": "golang.go",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.organizeImports": "explicit"
    }
  },
  "go.lintTool": "golangci-lint",
  "go.formatTool": "gofumpt",
  "go.useLanguageServer": true,

  // ── Terraform ─────────────────────────────────────────────────────
  "[terraform]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true
  },

  // ── YAML ──────────────────────────────────────────────────────────
  "[yaml]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.tabSize": 2
  },

  // ── JSON / JSONC ──────────────────────────────────────────────────
  "[json]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[jsonc]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },

  // ── Markdown ──────────────────────────────────────────────────────
  "[markdown]": {
    "editor.defaultFormatter": "DavidAnson.vscode-markdownlint",
    "editor.wordWrap": "on",
    "editor.formatOnSave": true
  },

  // ── Shell ─────────────────────────────────────────────────────────
  "[shellscript]": {
    "editor.defaultFormatter": "mkhl.shfmt",
    "editor.formatOnSave": true
  },
  "shellformat.flag": "-i 2 -ci -bn",

  // ── Dev Containers (Podman) ───────────────────────────────────────
  "dev.containers.dockerPath": "podman",

  // ── Telemetry ─────────────────────────────────────────────────────
  "telemetry.telemetryLevel": "off"
}
```

---

## VS Code extensions

`vscode/extensions.json` — recommended extensions list. Symlinked
or used as a reference. On remote backends (WSL2, container),
extensions install inside the remote environment.

```jsonc
// extensions.json
{
  "recommendations": [
    // ── Python ──────────────────────────────────────────────────────
    "charliermarsh.ruff",          // Ruff linter + formatter
    // ty: no VS Code extension yet (beta). Use Pylance as fallback.
    "ms-python.python",            // Python language support
    "ms-python.vscode-pylance",    // Type checking fallback (when ty unavailable)

    // ── Go ──────────────────────────────────────────────────────────
    "golang.go",                   // Go language support + gopls

    // ── Terraform ───────────────────────────────────────────────────
    "hashicorp.terraform",         // Terraform language support

    // ── YAML ────────────────────────────────────────────────────────
    "redhat.vscode-yaml",          // YAML language server

    // ── GitHub Actions ──────────────────────────────────────────────
    "github.vscode-github-actions", // Workflow syntax + completions

    // ── Markdown ────────────────────────────────────────────────────
    "DavidAnson.vscode-markdownlint", // markdownlint
    "yzhang.markdown-all-in-one",  // Preview, TOC, shortcuts

    // ── Shell ───────────────────────────────────────────────────────
    "timonwong.shellcheck",        // ShellCheck integration
    "mkhl.shfmt",                  // shfmt formatter

    // ── Git ─────────────────────────────────────────────────────────
    "eamodio.gitlens",             // Git blame, history, graph
    "mhutchie.git-graph",          // Visual branch graph

    // ── JSON ────────────────────────────────────────────────────────
    "ZainChen.json",               // JSON tools

    // ── Security ────────────────────────────────────────────────────
    "github.vscode-codeql",        // CodeQL query authoring + results
    "gitleaks.gitleaks",           // Secrets detection

    // ── Remote development ──────────────────────────────────────────
    "ms-vscode-remote.remote-wsl",        // WSL2 backend
    "ms-vscode-remote.remote-containers", // Dev Containers (Podman)

    // ── Formatting ──────────────────────────────────────────────────
    "esbenp.prettier-vscode",      // YAML, JSON, Markdown fallback

    // ── Theme ───────────────────────────────────────────────────────
    "catppuccin.catppuccin-vsc",   // Catppuccin theme (matches tmux status bar palette)

    // ── Utilities ───────────────────────────────────────────────────
    "EditorConfig.EditorConfig",   // .editorconfig support
    "streetsidesoftware.code-spell-checker" // Spell checking
  ]
}
```

---

## Install script additions

Add to `install-macos.sh`:

```bash
# VS Code (macOS only — on WSL2 it's installed on Windows)
link vscode/settings.json   ".config/Code/User/settings.json"
link vscode/extensions.json ".config/Code/User/extensions.json"
```

For WSL2, VS Code settings sync handles the Windows-side config.
The WSL2 remote backend uses the VS Code Server settings inside WSL2:

```bash
# install-wsl.sh
link vscode/settings.json   ".vscode-server/data/Machine/settings.json"
```

### Installing extensions

```bash
# Install all recommended extensions
code --install-extension charliermarsh.ruff
code --install-extension ms-python.python
# ... etc (script can read extensions.json and loop)
```

Or users install them via VS Code's "Install Recommended Extensions"
prompt when opening a project with `.vscode/extensions.json`.

---

## Brewfile additions

```ruby
cask "visual-studio-code"   # macOS only
```

Not added to `install-wsl.sh` — VS Code is installed on the Windows
host, not inside WSL2.

---

## Repo structure additions

```
vscode/
├── settings.json        # user settings
└── extensions.json      # recommended extensions
```

---

## Integration with the toolchain

### What VS Code-primary users get from the dotfiles

Even without Neovim or tmux, the VS Code-primary user benefits from:

- **Bash config**: aliases, completions, vi mode (or emacs mode if
  they prefer — the config works either way in VS Code's terminal)
- **Git config**: delta as diff pager, difftastic, merge settings
- **fzf/fd/rg/bat/zoxide**: works in VS Code's integrated terminal
- **lazygit**: runs in VS Code's terminal (`lg` alias)
- **mise/uv/direnv**: language version management
- **prek**: git hooks run regardless of editor
- **gcloud/gh/codeql**: CLI tools in terminal
- **Starship prompt**: renders in VS Code's integrated terminal

### What they don't need

- Neovim config (`nvim/`)
- tmux config (`tmux/`)
- kitty config (`kitty/`) — VS Code has its own terminal
- vim-tmux-navigator

### `$EDITOR` for VS Code-primary users

The conditional in `.bashrc` prefers nvim if present. For VS Code-
primary users who have nvim installed but prefer VS Code:

```bash
# Override in ~/.bashrc.local (sourced at end of .bashrc if present)
export EDITOR='code --wait'
export VISUAL='code --wait'
```

Add to `.bashrc`:

```bash
# ── Local overrides ──────────────────────────────────────────────────────────
[[ -f "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"
```

This keeps the shared config clean while allowing per-user
preferences. `.bashrc.local` is gitignored.
