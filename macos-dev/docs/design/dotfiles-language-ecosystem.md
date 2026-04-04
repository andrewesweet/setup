# Language ecosystem & quality tooling

Extends `dotfiles-setup.md`. Covers version management, per-language
quality tools, direnv, prek, and the team-baseline hook config.

---

## Dotfiles additions

```
~/.dotfiles/
├── Brewfile
├── mise/
│   └── config.toml              # global default tool versions
├── bash/
│   └── .bash_aliases            # new aliases
└── prek/
    └── .pre-commit-config.yaml  # team baseline hook config (template)
```

Add to `install.sh`:

```bash
link mise/config.toml   .config/mise/config.toml
```

The prek config belongs in each repo root, not the dotfiles repo itself.
The file in `~/.dotfiles/prek/` is a template to copy when initialising
a new repo.

---

## Brewfile additions

```ruby
# Version management
brew "mise"          # Python + Go (+ others) version manager

# Python
brew "uv"            # package manager, venv, tool runner

# Go quality
brew "golangci-lint"
brew "gofumpt"

# Bash quality
brew "shellcheck"
brew "shfmt"

# Terraform quality
brew "tflint"

# GitHub Actions quality
brew "actionlint"
brew "zizmor"

# pinact — pin actions to SHAs (interactive, not a CI gate)
# Install via mise rather than brew (mise handles version pinning)
# See section 4 below.

# Hooks runner
# prek is not on Homebrew main — installed via uv (see section 5)

# Neovim (see dotfiles-neovim.md)
brew "neovim"
brew "node"          # required by some Mason-managed LSP servers
```

---

## 1. mise — version management

mise replaces pyenv and goenv with a single tool. It reads `.mise.toml`
per project directory and activates shims automatically on `cd`.

Install the shell hook in `.bashrc` (add after the fzf and zoxide hooks):

```bash
# mise — multi-language version manager
eval "$(mise activate bash)"
```

### Global defaults: `~/.config/mise/config.toml`

```toml
# ~/.config/mise/config.toml
# Sets default versions used when no project-level .mise.toml is found.
# These are starting points — update as new stable versions ship.

[tools]
python = "3.13"
go     = "1.24"

# pinact managed here so mise handles binary versioning
pinact = "latest"

[settings]
# Automatically install missing tools when entering a directory
# with a .mise.toml that references them
auto_install = true
```

### Per-project `.mise.toml` (commit to each repo)

```toml
# .mise.toml — pin language versions per repo
[tools]
python = "3.11"   # adjust per project
go     = "1.23"   # adjust per project
```

### Useful mise aliases (add to `.bash_aliases`)

```bash
# ── mise ──────────────────────────────────────────────────────────────────────
alias mx='mise exec --'         # mx python script.py  (run in managed env)
alias mu='mise use'             # mu python@3.12       (set version in project)
alias ml='mise list'            # list active tools
alias mug='mise upgrade'        # upgrade all tools to latest allowed version
```

---

## 2. uv — Python package and environment management

uv replaces pip, virtualenv, pipx, and pip-tools. It manages project
environments and globally installed tools independently.

No shell hook required — uv integrates with mise's Python shims
automatically.

```bash
# Install ty (Python LSP/type checker) — not on Homebrew or Mason
uv tool install ty@latest

# Install prek (hook runner)
uv tool install prek

# Project workflow
uv init              # initialise new project (creates pyproject.toml)
uv add <package>     # add dependency
uv sync              # install all deps into .venv
uv run <script>      # run a script in the project environment
uv tool run ruff .   # run a tool without installing it permanently
```

### uv aliases (add to `.bash_aliases`)

```bash
# ── uv ────────────────────────────────────────────────────────────────────────
alias uva='uv add'
alias uvr='uv run'
alias uvs='uv sync'
alias uvt='uv tool install'
alias uvx='uvx'          # uvx = uv tool run (already short enough)
```

---

## 3. direnv — per-directory environment loading

direnv loads and unloads `.envrc` files as you move between directories.
Each repo's environment variables, `GOPATH` overrides, and tool versions
become active automatically.

Add the hook in `.bashrc` (after mise):

```bash
# direnv — auto-load .envrc on directory change
eval "$(direnv hook bash)"
```

### Typical `.envrc` patterns

```bash
# .envrc — commit a .envrc.example, each dev fills their own .envrc

# Python virtual environment (uv-managed)
source .venv/bin/activate 2>/dev/null || true

# Project-specific env vars
export SERVICE_PORT=8080
export LOG_LEVEL=debug

# Load secrets from sops-encrypted file (optional)
# eval "$(sops exec-env secrets.enc.yaml env)"
```

```bash
# .envrc for Go projects
export GOPATH="$PWD/.gopath"
export PATH="$GOPATH/bin:$PATH"
```

Always allow a new `.envrc` explicitly:

```bash
direnv allow    # required once per new/changed .envrc
direnv deny     # revoke if needed
```

---

## 4. pinact — pin GitHub Actions to SHAs

pinact edits workflow and composite action files, replacing mutable tags
with full commit SHAs and a tag comment. Used interactively, not as a
blocking gate (it needs a `GITHUB_TOKEN` to resolve SHAs).

Installed via mise (see `~/.config/mise/config.toml` above).

```bash
# Authenticate (uses $GITHUB_TOKEN from env or gh CLI token)
export GITHUB_TOKEN=$(gh auth token)

# Pin all actions in a repo
pinact run

# Verify current state without modifying (exit 1 if unpinned found)
pinact run --check

# Update pinned actions to latest SHA for each tag
pinact run --update
```

### pinact config (commit to each repo)

```yaml
# .pinact.yaml
version: 3
files:
  - pattern: .github/workflows/*.yml
  - pattern: .github/workflows/*.yaml
  - pattern: .github/actions/*/action.yml
  - pattern: .github/actions/*/action.yaml
  # Root-level action for standalone action repos:
  - pattern: action.yml
  - pattern: action.yaml

ignore_actions:
  # slsa-framework/slsa-github-generator MUST be referenced by tag
  - name: slsa-framework/slsa-github-generator
```

### pinact alias (add to `.bash_aliases`)

```bash
# ── GitHub Actions ────────────────────────────────────────────────────────────
alias gha-pin='GITHUB_TOKEN=$(gh auth token) pinact run'
alias gha-check='pinact run --check'
alias gha-update='GITHUB_TOKEN=$(gh auth token) pinact run --update'
```

---

## 5. prek — hook runner

prek is a Rust-native drop-in replacement for pre-commit. It uses the
same `.pre-commit-config.yaml` format, runs hooks 7x faster, and ships
as a single binary with no Python runtime dependency.

Install via uv (done in section 2 above):

```bash
uv tool install prek
```

Install git shims in a repo:

```bash
prek install             # installs pre-commit, commit-msg hooks
prek install-hooks       # pre-installs all hook environments (faster first run)
prek run --all-files     # run all hooks on all files (CI-equivalent check)
prek run <hook-id>       # run a single hook by ID
prek list                # list all hooks in current config
prek autoupdate          # update hook revisions in config
```

### prek aliases (add to `.bash_aliases`)

```bash
alias pk='prek run'
alias pka='prek run --all-files'
alias pkl='prek list'
alias pki='prek install && prek install-hooks'
alias pku='prek autoupdate --cooldown-days 7'
```

---

## 6. Team-baseline `.pre-commit-config.yaml`

Copy `~/.dotfiles/prek/.pre-commit-config.yaml` into a new repo and run
`pki` (prek install + install-hooks). Adjust language versions to match
the repo's `.mise.toml`.

The hooks are grouped by language with explicit stage assignments so they
only fire at the right point in the commit lifecycle.

```yaml
# .pre-commit-config.yaml
# Compatible with prek (and pre-commit for teams not yet migrated).
# Run: prek install && prek install-hooks

default_stages: [pre-commit]

repos:

  # ── Universal file hygiene ─────────────────────────────────────────────────
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
        args: [--allow-multiple-documents]
      - id: check-json
      - id: check-toml
      - id: check-merge-conflict
      - id: check-added-large-files
        args: [--maxkb=500]
      - id: detect-private-key
      - id: check-executables-have-shebangs
      - id: mixed-line-ending
        args: [--fix=lf]

  # ── Conventional commits ────────────────────────────────────────────────────
  # Validates commit message format; runs at commit-msg stage.
  - repo: https://github.com/compilerla/conventional-pre-commit
    rev: v3.4.0
    hooks:
      - id: conventional-pre-commit
        stages: [commit-msg]
        args: [feat, fix, docs, style, refactor, perf, test, chore, ci]

  # ── Secrets detection ────────────────────────────────────────────────────────
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks

  # ── Bash ────────────────────────────────────────────────────────────────────
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.10.0.1
    hooks:
      - id: shellcheck
        args: [--severity=warning]
  - repo: https://github.com/scop/pre-commit-shfmt
    rev: v3.10.0-1
    hooks:
      - id: shfmt
        args: [-i, "2", -ci]    # 2-space indent, case-indent

  # ── Python ──────────────────────────────────────────────────────────────────
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.9.0
    hooks:
      - id: ruff              # linting with auto-fix
        args: [--fix]
      - id: ruff-format       # formatting

  # ── Go ──────────────────────────────────────────────────────────────────────
  - repo: https://github.com/dnephin/pre-commit-golang
    rev: v0.5.1
    hooks:
      - id: go-fmt
      - id: go-vet
      - id: go-unit-tests
        stages: [manual]      # slow — run manually with: prek run go-unit-tests

  # ── Terraform ───────────────────────────────────────────────────────────────
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
        args:
          - --args=--minimum-failure-severity=warning

  # ── GitHub Actions ──────────────────────────────────────────────────────────
  # actionlint: syntax + semantic validation of workflow YAML
  - repo: https://github.com/rhysd/actionlint
    rev: v1.7.4
    hooks:
      - id: actionlint

  # zizmor: security static analysis for workflows
  # Also enforces pinning via the unpinned-uses audit rule, so zizmor
  # acts as the gate for both security issues and SHA pinning.
  # Use `pinact run` manually to fix unpinned actions before committing.
  - repo: https://github.com/zizmorcore/zizmor-pre-commit
    rev: v1.5.0
    hooks:
      - id: zizmor

  # ── YAML ────────────────────────────────────────────────────────────────────
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint
        args: [-c, .yamllint.yaml]
        exclude: |
          (?x)^(
            .github/workflows/|
            .github/actions/
          )
        # Workflow files handled by actionlint + zizmor above;
        # yamllint would double-report and has different style expectations.
```

### yamllint config

```yaml
# .yamllint.yaml — committed to each repo
extends: default
rules:
  line-length:
    max: 120
    level: warning
  truthy:
    allowed-values: ['true', 'false']
    check-keys: false
  comments:
    min-spaces-from-content: 1
```

---

## 7. All new aliases consolidated

Add to `~/.bash_aliases`:

```bash
# ── mise ──────────────────────────────────────────────────────────────────────
alias mx='mise exec --'
alias mu='mise use'
alias ml='mise list'
alias mug='mise upgrade'

# ── uv ────────────────────────────────────────────────────────────────────────
alias uva='uv add'
alias uvr='uv run'
alias uvs='uv sync'
alias uvt='uv tool install'

# ── direnv ────────────────────────────────────────────────────────────────────
alias da='direnv allow'
alias dr='direnv reload'

# ── GitHub Actions ────────────────────────────────────────────────────────────
alias gha-pin='GITHUB_TOKEN=$(gh auth token) pinact run'
alias gha-check='pinact run --check'
alias gha-update='GITHUB_TOKEN=$(gh auth token) pinact run --update'
alias gha-lint='actionlint'
alias gha-audit='zizmor'

# ── prek ──────────────────────────────────────────────────────────────────────
alias pk='prek run'
alias pka='prek run --all-files'
alias pkl='prek list'
alias pki='prek install && prek install-hooks'
alias pku='prek autoupdate --cooldown-days 7'
```

---

## 8. Team onboarding additions

```bash
# Install mise and activate
brew install mise
echo 'eval "$(mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

# Install global language versions
mise install

# Install uv + tools
brew install uv
uv tool install ty@latest
uv tool install prek

# Install pinact via mise
mise use -g pinact@latest

# Install direnv
brew install direnv
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# In each repo: install git hooks
cd <repo>
pki    # prek install + install-hooks
```
