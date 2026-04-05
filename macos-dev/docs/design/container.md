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

### Machine name

The dotfiles setup MUST use a named Podman Machine called `dotfiles`. All commands target this name explicitly. Users MAY have other Podman Machines for other purposes — the `dotfiles` machine is dedicated to this setup and does not interfere.

### Machine detection and auto-start

The `dev` script MUST check the `dotfiles` machine state before running any container command on macOS. The `_ensure_machine()` helper:

```
if uname is not Darwin: return 0

case $(podman machine inspect dotfiles --format '{{.State}}' 2>/dev/null || echo missing) in
  running)           return 0 ;;
  starting)          wait up to 60s polling inspect; return 0 when running ;;
  stopped|configured) podman machine start dotfiles ;;
  missing)           print "Run 'dev init-machine' to create." ; exit 1 ;;
esac
```

Called at the start of every command that needs container access: `shell`, `build`, `stop`, `rebuild`, `status`, `clean-sessions`.

### `dev init-machine` command

Creates the `dotfiles` Podman Machine with sensible defaults:

```bash
podman machine init dotfiles \
  --cpus 4 \
  --memory 8192 \
  --disk-size 60 \
  --now
```

- `--now` starts it immediately after creation
- Disk size default is 60GB. Podman Machine disks can be grown via `podman machine set --disk-size N dotfiles` but NOT shrunk without destroying the machine. The script SHOULD warn about this one-way operation.
- Users MAY override defaults: `dev init-machine --cpus 8 --memory 16384 --disk-size 100`
- The script MUST print the resource limits and ask for confirmation before creating
- `podman machine set` command and syntax SHOULD be documented in the output for later resource adjustments

This command is idempotent with respect to the LaunchAgent — if the agent is already installed, it is not reinstalled.

### LaunchAgent wrapper script

The LaunchAgent MUST NOT call `podman machine start` directly. It calls a wrapper script that handles edge cases safely:

```bash
#!/bin/bash
# container/podman-machine-start.sh
# Wrapper for LaunchAgent — safe on first run, idempotent, no-loop on failure modes
set -e

# Platform guard (plist is only installed on macOS, but defence in depth)
[[ "$(uname)" == "Darwin" ]] || exit 0

# If podman isn't on PATH, exit cleanly rather than letting launchd loop
PODMAN="@HOMEBREW_PREFIX@/bin/podman"
[[ -x "$PODMAN" ]] || exit 0

# If the dotfiles machine doesn't exist, exit cleanly (user hasn't run init-machine yet)
"$PODMAN" machine list -q 2>/dev/null | grep -qx 'dotfiles' || exit 0

# Check current state; only start if stopped/configured
state=$("$PODMAN" machine inspect dotfiles --format '{{.State}}' 2>/dev/null || echo missing)
case "$state" in
  running|starting) exit 0 ;;
  stopped|configured) exec "$PODMAN" machine start dotfiles ;;
  *) exit 0 ;;
esac
```

`@HOMEBREW_PREFIX@` is substituted by `install-macos.sh` at install time. This script lives at `container/podman-machine-start.sh` and is symlinked by `install-macos.sh` to `~/.local/bin/podman-machine-start`.

### LaunchAgent plist

Located at `container/io.podman.machine.plist`. The `@HOME@` and `@SCRIPT_PATH@` markers are substituted at install time:

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
    <string>@SCRIPT_PATH@</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>StandardOutPath</key>
  <string>@HOME@/Library/Logs/io.podman.machine.out.log</string>
  <key>StandardErrorPath</key>
  <string>@HOME@/Library/Logs/io.podman.machine.err.log</string>
  <key>ThrottleInterval</key>
  <integer>30</integer>
</dict>
</plist>
```

Key behaviours:
- `RunAtLoad`: runs the wrapper script when the user logs in
- The wrapper exits 0 when no work is needed (no machine, already running, already starting) — launchd will not relaunch
- `KeepAlive.SuccessfulExit = false`: relaunch the wrapper only if it exits non-zero (the `podman machine start` underneath failed)
- `ThrottleInterval`: minimum 30 seconds between relaunches — prevents tight crash loops
- Logs to `~/Library/Logs/` (user-scoped, not world-readable)

Note that manual `podman machine stop` exits 0 and the machine stays stopped until next login. This is intentional: manual stop means "I want it stopped." Users SHOULD use `dev machine-start` or `dev shell` to restart when needed.

### Loading the LaunchAgent

`install-macos.sh` MUST run:

```bash
# Idempotent: bootout first if already loaded, then bootstrap
launchctl bootout gui/$(id -u)/io.podman.machine 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.podman.machine.plist
```

`bootstrap` loads the plist and `RunAtLoad=true` invokes the wrapper immediately. No `kickstart` is needed.

On first install, if no `dotfiles` machine exists yet, the wrapper exits 0 harmlessly. Once the user runs `dev init-machine`, future logins will find the machine and start it automatically.

### Uninstall

`install-macos.sh --restore` is the single uninstall entry point. It MUST:

```bash
launchctl bootout gui/$(id -u)/io.podman.machine 2>/dev/null || true
rm -f ~/Library/LaunchAgents/io.podman.machine.plist
rm -f ~/.local/bin/podman-machine-start
# Leave the dotfiles machine itself — user may want to preserve VM state
# To remove the machine too: podman machine rm dotfiles
```

Leftover log files at `~/Library/Logs/io.podman.machine.{out,err}.log` are retained for post-uninstall diagnostics. Users MAY remove them manually.

### WSL2 and native Linux

These platforms do not need lifecycle management — Podman is a daemonless local binary. The `_ensure_machine()` helper MUST return 0 immediately on non-Darwin platforms (`[[ "$(uname)" == "Darwin" ]] || return 0`).

---

## dev script

Lives at container/dev.sh → ~/.local/bin/dev

Commands:
- `build [--base]` — build container image
- `shell [--base] [--ref <path>] [--port <port>] [--skip-check]` — start/attach to dev container (runs `_ensure_machine` first on macOS)
- `stop` — stop container for current repo
- `rebuild [--clean]` — rebuild image and recreate container
- `status` — show running dev containers and (on macOS) Podman Machine status
- `prune` — remove stopped containers + dangling images
- `clean-sessions` — remove OpenCode session data from dev-data-opencode volume
- `init-machine [--cpus N] [--memory MB] [--disk-size GB]` — macOS only: create the `dotfiles` Podman Machine (defaults: 4 CPU, 8192 MB, 60 GB)
- `machine-start` — macOS only: start the `dotfiles` Podman Machine (alias for `podman machine start dotfiles`)
- `machine-stop` — macOS only: stop the `dotfiles` Podman Machine (alias for `podman machine stop dotfiles`)
- `machine-status` — macOS only: show the `dotfiles` Podman Machine state

Uninstall is handled by `install-macos.sh --restore`, not by `dev`. The dev script MAY alias `dev uninstall` to `install-macos.sh --restore` for discoverability, but ownership of the uninstall flow lives in the install script.

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
├── Containerfile                # multi-stage build
├── dev.sh                       # lifecycle script
├── dev.env.example              # env var template
├── io.podman.machine.plist      # LaunchAgent template (macOS)
├── podman-machine-start.sh      # LaunchAgent wrapper (macOS)
├── test-tool-installs.sh        # tool verification
└── .dockerignore
```
