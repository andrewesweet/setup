# Editor — VS Code

## Overview

This document specifies the VS Code configuration for the dotfiles repository. VS Code integrates with the shared dotfiles environment to serve two distinct user personas while maintaining consistent tooling and settings across macOS, WSL2, and container-based development.

## User Personas

### TUI-first Developer

The TUI-first persona prioritizes terminal-based editing in Neovim while using VS Code as a secondary fallback editor.

**Primary characteristics:**
- $EDITOR environment variable set to `nvim`
- Uses Neovim for day-to-day editing
- Uses VS Code for:
  - Complex git merge conflict resolution
  - Jupyter notebook editing and exploration
  - Large-scale refactoring operations requiring visual inspection
  - Projects without adequate Neovim language server support

**dotfiles interaction:**
- Inherits default .bashrc configuration with Neovim as primary editor
- No additional configuration required for default behavior

### VS Code-primary Developer

The VS Code-primary persona relies on VS Code for all editing tasks and may not use tmux or Neovim.

**Primary characteristics:**
- $EDITOR environment variable set to `code --wait`
- Uses VS Code exclusively for all editing
- May not have Neovim or tmux installed or configured
- Requires complete development environment support from VS Code extensions and settings

**dotfiles interaction:**
- SHOULD override .bashrc EDITOR setting via ~/.bashrc.local
- Both personas use the same dotfiles repository; per-user overrides via ~/.bashrc.local provide persona-specific behavior
- The conditional logic in .bashrc prefers Neovim when present, so explicit override is necessary for VS Code-primary workflows

**Example ~/.bashrc.local override:**
```bash
export EDITOR='code --wait'
```

## Supported Platforms

| Platform | Deployment Mode | Notes |
|----------|---|---|
| macOS | Local | Native VS Code installation via Homebrew |
| WSL2 | Remote-WSL | VS Code runs on Windows host; backend and workspace reside in WSL2 VM |
| Container | Dev Containers | RECOMMENDED: Attach to running `dev` container from dev.sh. OPTIONAL: Use .devcontainer/devcontainer.json template for alternative workflows |

### VS Code Settings Location

- **macOS:** `~/Library/Application Support/Code/User/settings.json`
- **WSL2:** `~/.vscode-server/data/Machine/settings.json`

Settings propagate across installations when using the same GitHub account for VS Code Settings Sync.

## settings.json Configuration

The following settings MUST be applied to the VS Code user configuration:

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
    "editor.defaultFormatter": "esbenp.prettier-vscode",
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

## extensions.json Recommendations

The following extensions MUST be included in `.vscode/extensions.json`:

```json
{
  "recommendations": [
    "charliermarsh.ruff",
    "ms-python.python",
    "ms-python.vscode-pylance",
    "golang.go",
    "hashicorp.terraform",
    "redhat.vscode-yaml",
    "github.vscode-github-actions",
    "DavidAnson.vscode-markdownlint",
    "yzhang.markdown-all-in-one",
    "timonwong.shellcheck",
    "mkhl.shfmt",
    "eamodio.gitlens",
    "mhutchie.git-graph",
    "github.vscode-codeql",
    "gitleaks.gitleaks",
    "ms-vscode-remote.remote-wsl",
    "ms-vscode-remote.remote-containers",
    "esbenp.prettier-vscode",
    "catppuccin.catppuccin-vsc",
    "EditorConfig.EditorConfig",
    "streetsidesoftware.code-spell-checker"
  ]
}
```

### Extension Categories

**Python:**
- `charliermarsh.ruff`: Linting and formatting via Ruff
- `ms-python.python`: Official Python extension
- `ms-python.vscode-pylance`: Static type checking and language features

**Go:**
- `golang.go`: Official Go extension with golangci-lint integration

**Infrastructure:**
- `hashicorp.terraform`: Terraform language support and formatting
- `redhat.vscode-yaml`: YAML language server

**GitHub and Actions:**
- `github.vscode-github-actions`: GitHub Actions workflow editing and validation

**Markdown:**
- `DavidAnson.vscode-markdownlint`: Markdown linting via markdownlint
- `yzhang.markdown-all-in-one`: Markdown convenience features

**Shell:**
- `timonwong.shellcheck`: Shell script linting
- `mkhl.shfmt`: Shell script formatting

**Git:**
- `eamodio.gitlens`: Git blame and history inspection
- `mhutchie.git-graph`: Interactive git graph visualization

**Security:**
- `github.vscode-codeql`: CodeQL query development
- `gitleaks.gitleaks`: Secrets detection

**Remote Development:**
- `ms-vscode-remote.remote-wsl`: WSL2 integration
- `ms-vscode-remote.remote-containers`: Dev Containers integration

**Formatting and Theme:**
- `esbenp.prettier-vscode`: Formatting for JSON, YAML, Markdown, and JavaScript
- `catppuccin.catppuccin-vsc`: Catppuccin color scheme

**Utilities:**
- `EditorConfig.EditorConfig`: EditorConfig support
- `streetsidesoftware.code-spell-checker`: Spell checking across languages

## Dev Container Configuration

The `.devcontainer/devcontainer.json` template MUST be provided for container-based development workflows.

**Recommended approach (Mode A):**
Attach VS Code to a running `dev` container created by `dev.sh`. This mode requires no additional configuration files and reuses the dotfiles Containerfile with `target=full`.

**Alternative approach (Mode B):**
Use .devcontainer/devcontainer.json for standalone container creation.

### .devcontainer/devcontainer.json Template

```json
{
  "name": "dotfiles-dev",
  "build": {
    "dockerfile": "../Containerfile",
    "target": "full"
  },
  "mounts": [
    // SSH authentication: Use SSH agent socket forwarding instead of direct key file access.
    // This approach is more secure and aligns with container.md SSH strategy.
    // The SSH_AUTH_SOCK environment variable will be forwarded automatically by Dev Containers.
    "source=${localEnv:HOME}/.config/gh,target=/home/dev/.config/gh,type=bind",
    "source=${localEnv:HOME}/.gitconfig,target=/home/dev/.gitconfig,type=bind,readonly"
  ],
  "remoteUser": "dev",
  "postCreateCommand": "git submodule update --init --recursive",
  "forwardPorts": [],
  "customizations": {
    "vscode": {
      "extensions": [
        "charliermarsh.ruff",
        "ms-python.python",
        "ms-python.vscode-pylance",
        "golang.go",
        "hashicorp.terraform",
        "redhat.vscode-yaml",
        "github.vscode-github-actions",
        "DavidAnson.vscode-markdownlint",
        "yzhang.markdown-all-in-one",
        "timonwong.shellcheck",
        "mkhl.shfmt",
        "eamodio.gitlens",
        "mhutchie.git-graph",
        "github.vscode-codeql",
        "gitleaks.gitleaks",
        "ms-vscode-remote.remote-containers",
        "esbenp.prettier-vscode",
        "catppuccin.catppuccin-vsc",
        "EditorConfig.EditorConfig",
        "streetsidesoftware.code-spell-checker"
      ]
    }
  }
}
```

The template mounts GitHub CLI configuration and git configuration to enable authenticated operations within the container. SSH authentication uses agent socket forwarding for enhanced security.

## Known Keybind Limitations

The following keybindings conflict between VS Code and terminal applications running in the integrated terminal:

### Ctrl+P

**Behavior:** Captured by VS Code Quick Open dialog before reaching the shell or OpenCode.

**Impact:** File search and fuzzy finder bindings in OpenCode cannot be triggered from the integrated terminal.

**Workaround:** SHOULD use OpenCode leader key bindings instead of Ctrl+P. Configure alternative OpenCode bindings in shell configuration.

### Ctrl+K

**Behavior:** Captured by VS Code command palette chord prefix before reaching the shell or OpenCode.

**Impact:** Command prefixes in OpenCode cannot be triggered from the integrated terminal.

**Workaround:** SHOULD use OpenCode leader key bindings instead of Ctrl+K. Configure alternative OpenCode bindings in shell configuration.

These limitations are inherent to VS Code's integrated terminal design and cannot be overridden by user configuration. Users MUST use leader key bindings or alternative keybinds for OpenCode operations within VS Code's integrated terminal.

## Benefits for All Personas

Both TUI-first and VS Code-primary developers benefit from shared dotfiles configuration:

- **Shell environment:** bash configuration, aliases, and completions
- **Version management:** mise for multi-language runtime management
- **Package management:** uv for Python, Homebrew for system tools
- **Environment isolation:** direnv for per-project environment activation
- **Git tools:** git, delta for enhanced diffs, lazygit (aliased as `lg`)
- **Search and filtering:** fzf, fd, ripgrep (rg), bat, zoxide
- **Language servers:** Configurable LSP support via mise and language-specific tooling
- **CLI utilities:** prek, gcloud, gh, codeql command-line interfaces
- **Prompt:** starship for cross-platform shell prompt customization

VS Code-primary developers gain these tools and configurations automatically through the dotfiles environment, even without Neovim or tmux.

## Homebrew Installation

The following Homebrew cask MUST be included in the Brewfile for macOS installation:

```ruby
cask "visual-studio-code"
```

Installation:
```bash
brew install --cask visual-studio-code
```

On WSL2 and container platforms, VS Code MUST be installed via the platform-specific installation method (Windows Store, Microsoft's WSL2 extension, or container package manager).
