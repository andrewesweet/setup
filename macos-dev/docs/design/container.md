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

**Platform Note on Networking:** On macOS, Podman Machine uses gvproxy/vfkit networking, not slirp4netns. The `dev.sh` script MUST detect platform and omit the `--network=slirp4netns` flag on macOS to avoid compatibility issues.

SSH agent REQUIRES ssh-add -c on host.

Optional --port for dev servers.

## Podman Machine lifecycle (macOS only)

On macOS, Podman runs rootless containers inside a Linux VM ("Podman Machine") backed by vfkit or QEMU. The VM MUST be running before any `podman` command can execute. On WSL2 and native Linux, Podman runs without a VM — this section does not apply.

### Machine detection and auto-start

The `dev` script MUST check Podman Machine state before running any container command on macOS:

1. If no machine exists: print a message and offer to run `dev init-machine` (non-interactive runs SHOULD exit with a clear error).
2. If a machine exists but is stopped: auto-start it via `podman machine start`.
3. If a machine is running: proceed.

The script MUST implement this as a `_ensure_machine()` helper called at the start of every command that needs container access (`shell`, `build`, `stop`, `rebuild`, `status`, `clean-sessions`).

### `dev init-machine` command

Creates a new Podman Machine with sensible defaults:

```bash
podman machine init \
  --cpus 4 \
  --memory 8192 \
  --disk-size 100 \
  --now
```

- `--now` starts it immediately after creation
- CPU/memory/disk defaults are starting points; users MAY override via flags to `dev init-machine --cpus 8 --memory 16384`
- The script SHOULD print the resource limits and ask for confirmation before creating

After `init-machine` completes, the script SHOULD also install the LaunchAgent plist (see below) unless the user opts out with `--no-autostart`.

### LaunchAgent for auto-start at login (macOS)

To ensure the machine is always running without manual intervention, `install-macos.sh` MUST install a LaunchAgent plist at `~/Library/LaunchAgents/io.podman.machine.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>io.podman.machine</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/podman</string>
    <string>machine</string>
    <string>start</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>StandardOutPath</key>
  <string>/tmp/podman-machine.out.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/podman-machine.err.log</string>
  <key>ThrottleInterval</key>
  <integer>30</integer>
</dict>
</plist>
```

Key behaviours:
- `RunAtLoad`: starts the machine when the user logs in
- `KeepAlive.SuccessfulExit = false`: relaunch `podman machine start` if it exits non-zero (crash, failed start). A successful `start` exits 0 once the machine is up; launchd will not loop in that case.
- `ThrottleInterval`: minimum 30 seconds between restart attempts, preventing tight crash loops
- Logs to `/tmp/` for diagnostics (SHOULD be rotated manually if needed)
- Path is hardcoded to `/opt/homebrew/bin/podman` — the install script MUST verify this path exists and substitute if Homebrew is at a different prefix

The plist template lives at `container/io.podman.machine.plist` with `@HOMEBREW_PREFIX@` as a substitution marker. `install-macos.sh` substitutes the actual prefix at install time.

### Loading the LaunchAgent

`install-macos.sh` MUST run:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.podman.machine.plist
launchctl kickstart -k gui/$(id -u)/io.podman.machine
```

`bootstrap` loads the plist. `kickstart -k` forcibly starts the service immediately (useful on first install before the next login).

### Uninstall

`install-macos.sh --restore` (or equivalent uninstall flow) MUST remove the LaunchAgent:

```bash
launchctl bootout gui/$(id -u)/io.podman.machine 2>/dev/null || true
rm -f ~/Library/LaunchAgents/io.podman.machine.plist
```

### WSL2 and native Linux

These platforms do not need lifecycle management — Podman is a daemonless local binary. The `_ensure_machine()` helper is a no-op on non-macOS platforms.

---

## dev script

Lives at container/dev.sh → ~/.local/bin/dev

Commands:
- `build [--base]` — build container image
- `shell [--base] [--ref <path>] [--port <port>] [--skip-check]` — start/attach to dev container (runs `_ensure_machine` first on macOS)
- `stop` — stop container for current repo
- `rebuild [--clean]` — rebuild image and recreate container
- `status` — show running dev containers
- `prune` — remove stopped containers + dangling images
- `clean-sessions` — remove OpenCode session data from dev-data-opencode volume
- `init-machine [--cpus N] [--memory MB] [--disk-size GB] [--no-autostart]` — macOS only: create a new Podman Machine and install the LaunchAgent
- `uninstall` — restore backups and remove LaunchAgent

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

## Repo structure additions

```
container/
├── Containerfile               # multi-stage build
├── dev.sh                      # lifecycle script
├── dev.env.example             # env var template
├── io.podman.machine.plist     # LaunchAgent template (macOS)
├── test-tool-installs.sh       # tool verification
└── .dockerignore
```
