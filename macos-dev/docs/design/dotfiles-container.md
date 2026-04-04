# Container environment — Podman + Wolfi

Extends all prior design documents. Covers the containerised dev
environment, cross-platform guards, and the `dev` lifecycle script.

---

## Purpose

1. **AI agent sandbox** (primary) — OpenCode runs inside the container
   with direct filesystem access to the working repo. The container
   provides isolation: read-only root filesystem, dropped capabilities,
   no-new-privileges, scoped mounts.

2. **Reproducible team dev environment** (secondary) — the full image
   includes all interactive TUI tools, so any engineer can `dev shell`
   into a consistent environment regardless of host state.

---

## Image architecture

### Base image

`cgr.dev/chainguard/wolfi-base` — Chainguard's signed Wolfi image with
SBOMs. Chosen for aggressive CVE patching (daily rebuilds) and
supply-chain security. Uses glibc (not musl), so Python wheels, Go
binaries, and Node all work without compatibility issues.

### Multi-stage Containerfile

Single `Containerfile` with two stages:

```
Stage: base    — everything an AI agent needs
Stage: full    — base + interactive TUI tools for human use
```

Build targets:

```bash
podman build --target base -t dotfiles-base .
podman build -t dotfiles-full .              # default target is full
```

### Stage: base

System packages via apk:
- bash, git, curl, openssh-client, ca-certificates, build-base
- python (version matching mise config), go, nodejs, bun
- glibc-locales (set `LANG=C.UTF-8` to avoid locale issues)

Tool installs:
- mise (official install script)
- uv (official install script)
- ty (`uv tool install ty@latest`)
- prek (`uv tool install prek`)
- ruff (via mise or apk)
- golangci-lint, gofumpt, shellcheck, shfmt (apk or static binary)
- tflint, actionlint, zizmor (apk or static binary)
- OpenCode + critique (`bun install -g opencode-ai critique`)

Configs copied into image:
- git config (`.gitconfig`, `.gitignore_global`)
- opencode config (`opencode.jsonc`, `tui.jsonc`, instruction files)
- mise config (`config.toml`)

Additional base stage tools:
- gcloud CLI (via apk, components as individual packages)
- codeql CLI
- procps (for `is_vim` tmux detection)

User setup:
```dockerfile
RUN adduser -D -h /home/dev -s /bin/bash dev
USER dev
WORKDIR /home/dev
```

Locale:
```dockerfile
RUN apk add glibc-locales
ENV LANG=C.UTF-8
```

Layer ordering (for cache efficiency):
1. apk installs (system packages)
2. Tool installs (mise, uv scripts)
3. Global packages (bun, uv tools)
4. Configs and user setup (cheapest, changes most often)

### Stage: full

Extends `base`. Adds interactive tools:
- tmux, starship, lazygit, btop, lnav
- fzf, zoxide, bat, delta, fd, ripgrep
- glow, tree, jq, yq, httpie
- neovim, pandoc
- k9s, kubectl, kubectx, lazydocker

Configs copied into image:
- bash (`.bash_profile`, `.bashrc`, `.bash_aliases`, `.inputrc`)
- tmux (`.tmux.conf`)
- starship (`starship.toml`)
- lazygit (`config.yml`)
- nvim (full `nvim/` tree)

```dockerfile
SHELL ["/bin/bash", "-c"]
CMD ["bash", "-l"]
```

### What is NOT in the image

- Repos (bind-mounted at runtime)
- Credentials (mounted read-only at runtime)
- Caches: `.venv`, Go module cache, mise installs, Mason tools,
  bun cache, OpenCode session data (named volumes)

---

## Mount strategy

### Principle

The container is as close to immutable as possible. Writes are
constrained to explicit, purpose-specific locations.

### Read-write bind mount

| Host path | Container path | Purpose |
|-----------|---------------|---------|
| `$PWD` (current repo) | `/home/dev/workspace` | Active working repo |

Only one repo is mounted read-write. `dev shell` resolves to the
git root (`git rev-parse --show-toplevel`), warning if `$PWD`
differs.

### Read-only bind mounts

| Host path | Container path | Purpose |
|-----------|---------------|---------|
| Additional repos (`--ref`) | `/home/dev/refs/<name>` | Cross-reference |
| `~/.local/share/opencode/auth.json` | `/home/dev/.opencode-auth/auth.json` | Copilot token (separate path to avoid volume shadow) |
| `~/.config/gh/` | `/home/dev/.config/gh/` | GitHub CLI auth |
| `~/.config/gcloud/` | `/home/dev/.config/gcloud/` | GCP ADC (IAM is the security boundary) |
| `~/.codeql/` | `/home/dev/.codeql/` | CodeQL query packs |
| `$SSH_AUTH_SOCK` | `/run/ssh-agent.sock` | Git SSH (host must use `ssh-add -c`) |

Note: OpenCode auth is mounted to `/home/dev/.opencode-auth/` (not
inside `.local/share/opencode/`) to avoid being shadowed by the
`dev-data-opencode` named volume. Configure OpenCode to read auth
from this path.

`dev.sh` validates that `$SSH_AUTH_SOCK` exists and is a socket
before mounting. Prints diagnostic if missing.

### Named volumes (persistent across container recreates)

| Volume | Container path | Purpose |
|--------|---------------|---------|
| `dev-cache-uv` | `/home/dev/.cache/uv` | uv package cache |
| `dev-cache-go` | `/home/dev/.local/go` | Go module + build cache |
| `dev-cache-mise` | `/home/dev/.local/share/mise` | mise installs |
| `dev-cache-mason` | `/home/dev/.local/share/nvim/mason` | Mason tools (full only) |
| `dev-cache-bun` | `/home/dev/.cache/bun` | bun global cache |
| `dev-data-opencode` | `/home/dev/.local/share/opencode` | OpenCode sessions, history |

### tmpfs (ephemeral, RAM-only)

| Container path | Purpose |
|---------------|---------|
| `/tmp` | Scratch files (OpenCode's preferred scratch dir) |
| `/home/dev/.cache/tmp` | Build intermediates |

### Read-only root filesystem

The container runs with `--read-only`. The image filesystem is
immutable at runtime. Writes only go to mounted volumes and tmpfs.

---

## Security hardening

```bash
podman run \
  --read-only \
  --cap-drop=ALL \
  --cap-add=CHOWN,DAC_OVERRIDE,FOWNER \
  --security-opt=no-new-privileges \
  --network=slirp4netns \
  --userns=keep-id \
  ...
```

- `--cap-drop=ALL` + minimal add-back (`CHOWN`, `DAC_OVERRIDE`,
  `FOWNER` only — `SETUID`/`SETGID` not needed at runtime)
- `--security-opt=no-new-privileges` prevents privilege escalation
- `--userns=keep-id` maps container user to host UID. On macOS
  Podman Machine, consider explicit mapping:
  `--userns=keep-id:uid=1000,gid=1000`
- `slirp4netns` — rootless networking, outbound HTTPS only
- No `--privileged`, ever
- Optional `--port` flag for dev servers: `dev shell --port 8080`
- SSH agent requires `ssh-add -c` on host (confirmation per use)

---

## `dev` script

Lives at `container/dev.sh`, symlinked to `~/.local/bin/dev` by
the install script.

### Commands

```bash
dev build                    # build both stages
dev build --base             # build base stage only
dev shell                    # start/attach container for $PWD repo
dev shell --base             # use base image (agent-only, no TUI)
dev shell --ref ~/repos/lib  # add read-only reference repo (repeatable)
dev shell --port 8080        # expose a port
dev stop                     # stop container for $PWD repo
dev rebuild                  # rebuild image + recreate container, keep volumes
dev rebuild --clean          # rebuild + wipe named volumes
dev status                   # show running dev containers
dev prune                    # remove stopped containers + dangling images
```

`dev` with no arguments prints usage.

### Container naming

Each container is named `dev-<repo-directory-name>`. Multiple
containers can run simultaneously for different repos.

### Attach behaviour

`dev shell` is idempotent:
- Container doesn't exist: create, start, exec into bash
- Container stopped: start, exec into bash
- Container running: exec new bash session

### Stale image detection

On `dev shell`, the script compares the container's image ID against
`dotfiles-full:latest`. If they differ, it **blocks** with:

```
Image has been rebuilt since this container was created.
Run 'dev rebuild' to update, or 'dev shell --skip-check' to continue.
```

### Environment variables

Passed via `container/dev.env` (gitignored). Podman's `--env-file`
format: lines without `=` pass through the host's current value,
lines with `=` set explicit values.

`container/dev.env.example` (committed):

```bash
# container/dev.env.example — copy to dev.env and customise
# Lines without = pass through the host's current value
# Lines with = set an explicit value inside the container
GITHUB_TOKEN
NOTIFY_THRESHOLD
TERM
GIT_AUTHOR_NAME
GIT_AUTHOR_EMAIL
```

The script auto-sets `GIT_AUTHOR_NAME` and `GIT_AUTHOR_EMAIL` from
the host's `git config` if not already in `dev.env`.

If `dev.env` does not exist, the script prints a message and offers
to copy from `dev.env.example`.

---

## Container-specific Containerfile notes

### Locale

```dockerfile
RUN apk add glibc-locales
ENV LANG=C.UTF-8
```

### Preference: apk first, static binaries second

For tools not in the Wolfi apk repo, download pre-built Linux
binaries from GitHub releases. Pin versions with checksums in the
Containerfile.

### Architecture

Build for host architecture only (`linux/arm64` on Apple Silicon,
`linux/amd64` on Intel/WSL). Cross-platform builds deferred.

---

## `.dockerignore`

```
.git
docs/
*.md
container/dev.env
```

---

## Brewfile addition

```ruby
# Container runtime
brew "podman"
```

---

## Repo structure additions

```
container/
├── Containerfile            # multi-stage build (base + full)
├── dev.sh                   # lifecycle management script
├── dev.env.example          # env var template (committed)
├── test-tool-installs.sh    # tool verification script
└── .dockerignore
```
