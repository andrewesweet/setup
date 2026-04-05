# Installation and Brewfile

## Consolidated Brewfile

The single source of truth for tool installation across macOS and WSL. One Brewfile contains ALL tools organized by category with comments for navigation.

### Brewfile Structure

The Brewfile MUST contain the following tools organized by functional category:

```ruby
# Shell
brew "bash"
brew "bash-completion@2"
brew "starship"

# Git core
brew "git"
brew "git-delta"
brew "difftastic"
brew "lazygit"
brew "git-cliff"
brew "cocogitto"
brew "gh"

# Navigation & search
brew "fzf"
brew "zoxide"
brew "fd"
brew "ripgrep"

# File viewing
brew "bat"
brew "glow"
brew "lnav"

# Process monitoring
brew "btop"

# Terminal multiplexer
brew "tmux"

# Data wrangling
brew "jq"
brew "yq"
brew "miller"
brew "httpie"

# Utilities
brew "tree"
brew "wget"
brew "pandoc"
brew "typst"

# Version management
brew "mise"

# Python
brew "uv"

# Go quality
brew "golangci-lint"
brew "gofumpt"
brew "goimports"

# Bash quality
brew "shellcheck"
brew "shfmt"

# Markdown quality
brew "markdownlint-cli2"

# Terraform
brew "tflint"

# GitHub Actions
brew "actionlint"
brew "zizmor"
brew "pinact"

# Kubernetes
brew "kubernetes-cli"
brew "k9s"
brew "kubectx"

# Container
brew "podman"
brew "lazydocker"

# Terraform extras
brew "tenv"
brew "tf-summarize"

# Terminal recording
brew "vhs"
brew "asciinema"

# GCP
brew "google-cloud-sdk"
brew "cloud-sql-proxy"

# Security
brew "codeql"

# OpenCode runtime
brew "bun"

# Neovim
brew "neovim"

# direnv
brew "direnv"

**Note on node:** Node is managed via mise (`nodejs = "lts"` in global config) to avoid PATH conflicts with Homebrew.

# Taps
tap "charmbracelet/tap"
brew "charmbracelet/tap/freeze"

# VS Code (macOS only)
cask "visual-studio-code"
```

### Brewfile Requirements

The Brewfile MUST satisfy the following requirements:

- `tap "homebrew/bundle"` MUST NOT be included (deprecated since Homebrew 4.x)
- tenv conflicts with atmos in Homebrew. If atmos is present, unlink it first.
- tf-summarize uses `-v` for version (not `--version`)

## install-macos.sh

The macOS installation script MUST perform the following steps in order:

1. Back up existing non-symlink configs to `~/.dotfiles-backup/<timestamp>/`
2. Detect HOMEBREW_PREFIX dynamically via `$(brew --prefix)`
3. Execute `brew bundle`
4. Execute `brew install charmbracelet/tap/freeze`
5. Execute `gcloud components install alpha beta bq gke-gcloud-auth-plugin pubsub-emulator cloud-datastore-emulator cloud-firestore-emulator cloud-build-local bigtable spanner-emulator`
6. Execute `uv tool install ty@latest && uv tool install prek`
7. Execute `bun install -g opencode-ai critique`
8. Symlink all configuration files using the link() function:
   - bash/.bash_profile → .bash_profile
   - bash/.bashrc → .bashrc
   - bash/.bash_aliases → .bash_aliases
   - bash/.inputrc → .inputrc
   - git/.gitconfig → .gitconfig
   - git/.gitignore_global → .gitignore_global
   - tmux/.tmux.conf → .tmux.conf
   - kitty/kitty.conf → .config/kitty/kitty.conf
   - starship/starship.toml → .config/starship.toml
   - lazygit/config.yml → .config/lazygit/config.yml
   - opencode/opencode.jsonc → .config/opencode/opencode.jsonc
   - opencode/tui.jsonc → .config/opencode/tui.jsonc
   - opencode/instructions/git-conventions.md → .config/opencode/instructions/git-conventions.md
   - opencode/instructions/scratch-dirs.md → .config/opencode/instructions/scratch-dirs.md
   - mise/config.toml → .config/mise/config.toml
   - nvim → .config/nvim (entire directory)
   - vscode/settings.json → "Library/Application Support/Code/User/settings.json"
   - vscode/extensions.json → "Library/Application Support/Code/User/extensions.json"
9. Symlink container/dev.sh → ~/.local/bin/dev
10. Verify all bash configuration files with `bash -n`

### link() Function

The link() function MUST be implemented as follows:

```bash
DOTFILES="$(cd "$(dirname "$0")" && pwd)"

link() {
  local src="$DOTFILES/$1" dst="$HOME/$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    local backup="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup/$(dirname "$2")"
    mv "$dst" "$backup/$2"
    echo "  backed up $dst"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
  echo "  linked $dst"
}
```

The DOTFILES variable MUST self-resolve from the script location (not hardcoded path).

## install-wsl.sh

The WSL installation script MUST follow the same structure as install-macos.sh with the following modifications:

1. Execute `sudo apt install` for available tools
2. fzf installation version MUST be >= 0.48. Installation MUST be from GitHub releases, NOT apt.
3. Install scripts MUST be provided for tools not in apt or with stale versions: starship, mise, uv, fzf, zoxide, bat, delta, fd, ripgrep, lazygit, btop, lnav, glow, neovim, kitty, bun, podman, gcloud SDK, codeql
4. gcloud components MUST be installed as separate apt packages (NOT `gcloud components install`)
5. VS Code symlink MUST point to `~/.vscode-server/data/Machine/settings.json`
6. Supply chain considerations SHOULD pin versions and verify checksums for curl-pipe-bash installs

## tools.txt

A shared manifest file containing all tools. The tools.txt file format MUST be one tool per line with # comments allowed.

Format:
```
# tool-name  brew:formula  apt:package  apk:package
bash          bash          bash          bash
delta         git-delta     -             -
```

A validation script MUST check that all tools referenced in the Brewfile, install-wsl.sh, and Containerfile are present in tools.txt.

## verify.sh

A verification script at the repository root MUST perform the following checks:

1. Symlink check (platform-aware paths)
2. `bash -n` on all bash config files
3. Execute `bash container/test-tool-installs.sh`
4. Config parse validation (tmux, starship, opencode JSONC)
5. Execute `dev build --base` if Podman is present
6. gcloud component checks
7. `code --version` if VS Code is expected
8. Print manual steps (Neovim LSP)

## CI (GitHub Actions)

GitHub Actions workflow MUST verify the following on push and pull request:

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

## Team Onboarding

New contributors MUST follow these consolidated steps for macOS setup:

1. Clone repository
2. Install Homebrew
3. Switch to Homebrew bash 5 via `chsh -s $(brew --prefix)/bin/bash`
4. Run `bash install-macos.sh`
5. Execute `opencode auth login` (GitHub Copilot)
6. Execute `gcloud auth login`
7. Restart terminal

The `install-macos.sh` script handles all remaining steps including `brew bundle`, fzf bindings, `uv tool install` commands, `bun install` commands, and configuration symlinking.
