# Language ecosystem and quality tooling

## mise — version management

mise MUST replace pyenv/goenv and MUST read .mise.toml per project.

Shell hook MUST be configured as `eval "$(mise activate bash)"` in .bashrc, guarded appropriately.

Global config in `~/.config/mise/config.toml` MUST include:

```toml
[tools]
python = "3.13"
go     = "1.24"

[settings]
auto_install = true
```

Per-project `.mise.toml` files MUST be provided as a template with versions adjusted per repository.

NOTE: `auto_install = true` MAY block prompt on cd if tools require downloading.

## uv — Python package management

uv MUST replace pip, virtualenv, pipx, and pip-tools.

ty MUST be installed via `uv tool install ty@latest` and MUST NOT use Mason.

prek MUST be installed via `uv tool install prek`.

Project workflow MUST use: uv init, uv add, uv sync, uv run.

## direnv — per-directory environment

Hook MUST be configured as `eval "$(direnv hook bash)"` in .bashrc, guarded appropriately.

direnv MUST be included in Brewfile as `brew "direnv"`.

Typical .envrc patterns MUST support: `source .venv/bin/activate`, environment variables, and GOPATH.

`direnv allow` MUST be executed once per new or changed .envrc.

## pinact — pin GitHub Actions to SHAs

pinact MUST be installed via Homebrew as `brew "pinact"`.

GITHUB_TOKEN MUST be provided to resolve SHAs — this is an interactive tool and MUST NOT be a blocking gate.

Config file `.pinact.yaml` MUST be provided per repository as a template.

Workflow: `gha-pin` MUST be used to pin Actions while authoring; zizmor MUST catch missed pins at commit.

## prek — hook runner

prek MUST be installed via `uv tool install prek` and MUST NOT be installed via Homebrew.

prek is a Rust-native drop-in replacement for pre-commit and MUST use the same .pre-commit-config.yaml format.

Commands MUST include: install, install-hooks, run, run --all-files, list, autoupdate.

## Team-baseline .pre-commit-config.yaml

The complete configuration MUST include the following hook groups:

- Universal file hygiene (pre-commit-hooks v5.0.0): trailing-whitespace, end-of-file-fixer, check-yaml, check-json, check-toml, check-merge-conflict, check-added-large-files (500kb), detect-private-key, check-executables-have-shebangs, mixed-line-ending (lf)
- Conventional commits (conventional-pre-commit v3.4.0): commit-msg stage with types feat, fix, docs, style, refactor, perf, test, chore, ci
- Secrets detection (gitleaks v8.21.2)
- Bash: shellcheck-py v0.10.0.1 (--severity=warning), shfmt v3.10.0-1 (-i 2 -ci)
- Python: ruff-pre-commit v0.9.0 (ruff --fix, ruff-format)
- Go: pre-commit-golang v0.5.1 (go-fmt, go-vet, go-unit-tests at manual stage)
- Terraform: pre-commit-terraform v1.96.0 (terraform_fmt, terraform_validate, terraform_tflint)
- GitHub Actions: actionlint v1.7.4, zizmor-pre-commit v1.5.0
- YAML: yamllint v1.35.1 (MUST exclude .github/workflows and .github/actions)
- Markdown: markdownlint-cli2 v0.17.1

## yamllint config template

```yaml
extends: default
rules:
  line-length: { max: 120, level: warning }
  truthy: { allowed-values: ['true', 'false'], check-keys: false }
  comments: { min-spaces-from-content: 1 }
```

## markdownlint config template

```jsonc
{
  "default": true,
  "MD013": { "line_length": 120 },
  "MD033": false,
  "MD041": false
}
```

## Per-language quality tools summary

| Language | Linter | Formatter | Type checker | LSP |
|----------|--------|-----------|-------------|-----|
| Python | ruff | ruff | ty | ty + ruff |
| Go | golangci-lint | gofumpt + goimports | gopls | gopls |
| Bash | shellcheck | shfmt | — | bash-language-server |
| Terraform | tflint | terraform fmt | — | terraform-ls |
| YAML | yamllint | prettier | — | yaml-language-server |
| GitHub Actions | actionlint + zizmor | prettier | — | gh-actions-language-server |
| JSON | — | prettier | — | json-lsp |
| Markdown | markdownlint-cli2 | prettier | — | — |

## zizmor vs pinact

zizmor MUST be a blocking gate (prek hook + nvim-lint). zizmor enforces both security requirements and SHA pinning.

pinact MUST be an interactive authoring tool. pinact requires GITHUB_TOKEN and MUST NOT be a blocking hook.
