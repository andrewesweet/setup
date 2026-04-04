# Container environment — Podman + Wolfi

## Purpose

1. AI agent sandbox (primary) — OpenCode runs inside with filesystem access
2. Reproducible team dev environment (secondary)

## Base image

`cgr.dev/chainguard/wolfi-base` — Chainguard signed, glibc, daily CVE patching.

## Multi-stage Containerfile

Single Containerfile, two stages: base and full.
Build: `podman build --target base -t dotfiles-base .` or `podman build -t dotfiles-full .`

### Stage: base

System packages (apk): bash, git, curl, openssh-client, ca-certificates, build-base, python, go, nodejs, bun, glibc-locales, procps

Tools: mise, uv, ty, prek, ruff, golangci-lint, gofumpt, shellcheck, shfmt, tflint, actionlint, zizmor, gcloud CLI (via apk), codeql, OpenCode + critique (bun)

Configs: git, opencode, mise

User: `adduser -D -h /home/dev -s /bin/bash dev`

Locale: `ENV LANG=C.UTF-8`

Layer ordering (MUST): apk → tool installs (mise, uv) → global packages (bun, uv tools) → configs

### Stage: full

Extends base. Adds: tmux, starship, lazygit, btop, lnav, fzf, zoxide, bat, delta, fd, ripgrep, glow, tree, jq, yq, httpie, neovim, pandoc, k9s, kubectl, kubectx, lazydocker

Configs: bash, tmux, starship, lazygit, nvim

`SHELL ["/bin/bash", "-c"]`, `CMD ["bash", "-l"]`

### Not in image

Repos (bind-mounted), credentials (mounted read-only), caches (named volumes)

## Mount strategy

### Read-write

| Host | Container | Purpose |
|------|-----------|---------|
| `$(git rev-parse --show-toplevel)` | `/home/dev/workspace` | Active repo |

`dev shell` MUST resolve to git root, warn if $PWD differs.

### Read-only

| Host | Container | Purpose |
|------|-----------|---------|
| Repos via --ref | `/home/dev/refs/<name>` | Cross-reference |
| `~/.local/share/opencode/auth.json` | `/home/dev/.opencode-auth/auth.json` | Copilot token (separate path to avoid volume shadow) |
| `~/.config/gh/` | `/home/dev/.config/gh/` | GitHub CLI |
| `~/.config/gcloud/` | `/home/dev/.config/gcloud/` | GCP ADC (IAM is security boundary) |
| `~/.codeql/` | `/home/dev/.codeql/` | CodeQL packs |
| `$SSH_AUTH_SOCK` | `/run/ssh-agent.sock` | SSH (host MUST use ssh-add -c) |

OpenCode auth MUST be at `/home/dev/.opencode-auth/` not inside `.local/share/opencode/` to avoid shadow by named volume.

`dev.sh` MUST validate $SSH_AUTH_SOCK exists before mounting.

### Named volumes

dev-cache-uv, dev-cache-go, dev-cache-mise, dev-cache-mason, dev-cache-bun, dev-data-opencode

### tmpfs

/tmp, /home/dev/.cache/tmp

### Read-only root

`--read-only` flag. Image filesystem immutable at runtime.

## Security

```
--read-only
--cap-drop=ALL
--cap-add=CHOWN,DAC_OVERRIDE,FOWNER
--security-opt=no-new-privileges
--network=slirp4netns
--userns=keep-id
```

MUST NOT add SETUID/SETGID. MUST NOT use --privileged.

On macOS Podman Machine, consider `--userns=keep-id:uid=1000,gid=1000`.

SSH agent REQUIRES ssh-add -c on host.

Optional --port for dev servers.

## dev script

Lives at container/dev.sh → ~/.local/bin/dev

Commands: build [--base], shell [--base] [--ref] [--port] [--skip-check], stop, rebuild [--clean], status, prune, uninstall (restore backups)

Container naming: dev-<repo-dir-name>

Attach: idempotent (create/start/exec)

Stale image: blocks by default, --skip-check to bypass

Env vars: via container/dev.env (gitignored), dev.env.example committed. Auto-sets GIT_AUTHOR_NAME/EMAIL from host git config.

If dev.env missing: print message, offer to copy from example.

WSL2: pass --dns from host /etc/resolv.conf.

## gcloud in container

gcloud components MUST be installed as individual apk packages (NOT `gcloud components install` which is disabled for package-managed installs).

## .dockerignore

```
.git
docs/
*.md
container/dev.env
```

## Brewfile

```ruby
brew "podman"
```
