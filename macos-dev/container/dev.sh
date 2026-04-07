#!/usr/bin/env bash
# dev.sh — container lifecycle script
# See docs/design/container.md for the specification.
set -euo pipefail

# ── Constants ───────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_BASE="dotfiles-base"
IMAGE_FULL="dotfiles-full"

# Container naming: dev-<repo-dir-name>
_container_name() {
  local repo_dir
  repo_dir="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")"
  echo "dev-${repo_dir}"
}

# ── Colours ─────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[0;33m'
  C_RED='\033[0;31m'
  C_RESET='\033[0m'
else
  C_GREEN='' C_YELLOW='' C_RED='' C_RESET=''
fi

log()  { printf "${C_GREEN}==>${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}WARN:${C_RESET} %s\n" "$*" >&2; }
err()  { printf "${C_RED}ERROR:${C_RESET} %s\n" "$*" >&2; }

# ── Platform detection ──────────────────────────────────────────────────────
_is_macos() { [[ "$(uname)" == "Darwin" ]]; }
_is_wsl()   { [[ -n "${WSL_DISTRO_NAME:-}" ]]; }

# ── Podman Machine helpers (macOS only) ─────────────────────────────────────
_ensure_machine() {
  [[ "$(uname)" == "Darwin" ]] || return 0

  local state
  state="$(podman machine inspect dotfiles --format '{{.State}}' 2>/dev/null || echo missing)"

  case "$state" in
    running)
      return 0
      ;;
    starting)
      log "Podman Machine 'dotfiles' is starting, waiting..."
      local i=0
      while (( i < 60 )); do
        sleep 1
        state="$(podman machine inspect dotfiles --format '{{.State}}' 2>/dev/null || echo missing)"
        if [[ "$state" == "running" ]]; then
          return 0
        fi
        ((i++))
      done
      err "Podman Machine 'dotfiles' did not start within 60 seconds."
      exit 1
      ;;
    stopped|configured)
      log "Starting Podman Machine 'dotfiles'..."
      podman machine start dotfiles
      ;;
    missing)
      err "Podman Machine 'dotfiles' not found. Run 'dev init-machine' to create it."
      exit 1
      ;;
  esac
}

# ── dev.env loading ─────────────────────────────────────────────────────────
_load_env() {
  local env_file="$DOTFILES/container/dev.env"
  local env_example="$DOTFILES/container/dev.env.example"

  if [[ ! -f "$env_file" ]]; then
    if [[ -f "$env_example" ]]; then
      warn "dev.env not found. Copy from example?"
      warn "  cp $env_example $env_file"
      warn "Continuing without dev.env."
    fi
    return 0
  fi

  # shellcheck disable=SC1090
  source "$env_file"
}

# ── Auto-set git identity from host ────────────────────────────────────────
_git_env_args() {
  local args=()
  local name email
  name="$(git config user.name 2>/dev/null || true)"
  email="$(git config user.email 2>/dev/null || true)"
  if [[ -n "$name" ]]; then
    args+=(-e "GIT_AUTHOR_NAME=$name" -e "GIT_COMMITTER_NAME=$name")
  fi
  if [[ -n "$email" ]]; then
    args+=(-e "GIT_AUTHOR_EMAIL=$email" -e "GIT_COMMITTER_EMAIL=$email")
  fi
  echo "${args[@]}"
}

# ── Security flags ──────────────────────────────────────────────────────────
_security_flags() {
  local flags=(
    --read-only
    --cap-drop=ALL
    --cap-add=CHOWN,DAC_OVERRIDE,FOWNER
    --security-opt=no-new-privileges
    --userns=keep-id
  )

  # On macOS Podman Machine, use deterministic UID mapping
  if _is_macos; then
    flags=(
      --read-only
      --cap-drop=ALL
      --cap-add=CHOWN,DAC_OVERRIDE,FOWNER
      --security-opt=no-new-privileges
      --userns=keep-id:uid=1000,gid=1000
    )
  fi

  echo "${flags[@]}"
}

# ── Network flags ───────────────────────────────────────────────────────────
_network_flags() {
  local flags=()

  # slirp4netns on Linux/WSL only; macOS uses gvproxy via Podman Machine
  if ! _is_macos; then
    flags+=(--network=slirp4netns)
  fi

  # WSL2: pass DNS from host
  if _is_wsl && [[ -f /etc/resolv.conf ]]; then
    local dns
    dns="$(grep -m1 '^nameserver' /etc/resolv.conf | awk '{print $2}')"
    if [[ -n "$dns" ]]; then
      flags+=(--dns "$dns")
    fi
  fi

  echo "${flags[@]}"
}

# ── Volume and mount flags ──────────────────────────────────────────────────
_volume_flags() {
  local flags=()

  # Named volumes
  flags+=(-v dev-cache-uv:/home/dev/.cache/uv)
  flags+=(-v dev-cache-go:/home/dev/go)
  flags+=(-v dev-cache-mise:/home/dev/.local/share/mise)
  flags+=(-v dev-cache-mason:/home/dev/.local/share/mason)
  flags+=(-v dev-cache-bun:/home/dev/.bun)
  flags+=(-v dev-data-opencode:/home/dev/.local/share/opencode)

  # tmpfs mounts
  flags+=(--tmpfs /tmp)
  flags+=(--tmpfs /home/dev/.cache/tmp)

  echo "${flags[@]}"
}

# ── Credential and config mounts ────────────────────────────────────────────
_credential_mounts() {
  local flags=()

  # OpenCode auth — at /home/dev/.opencode-auth/ to avoid volume shadow
  local opencode_auth="$HOME/.local/share/opencode/auth.json"
  if [[ -f "$opencode_auth" ]]; then
    flags+=(-v "$opencode_auth:/home/dev/.opencode-auth/auth.json:ro")
  fi

  # GitHub CLI
  if [[ -d "$HOME/.config/gh" ]]; then
    flags+=(-v "$HOME/.config/gh:/home/dev/.config/gh:ro")
  fi

  # GCP ADC
  if [[ -d "$HOME/.config/gcloud" ]]; then
    flags+=(-v "$HOME/.config/gcloud:/home/dev/.config/gcloud:ro")
  fi

  # CodeQL packs
  if [[ -d "$HOME/.codeql" ]]; then
    flags+=(-v "$HOME/.codeql:/home/dev/.codeql:ro")
  fi

  # SSH agent — validate socket exists, warn and skip if absent
  if [[ -n "${SSH_AUTH_SOCK:-}" ]] && [[ -S "$SSH_AUTH_SOCK" ]]; then
    flags+=(-v "$SSH_AUTH_SOCK:/run/ssh-agent.sock:ro" -e "SSH_AUTH_SOCK=/run/ssh-agent.sock")
  else
    warn "SSH_AUTH_SOCK not set or socket not found — SSH agent will not be available in container."
    warn "Run 'ssh-add -c' on the host to enable SSH agent forwarding."
  fi

  echo "${flags[@]}"
}

# ── Commands ────────────────────────────────────────────────────────────────

cmd_build() {
  local target="full"
  local image="$IMAGE_FULL"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base)
        target="base"
        image="$IMAGE_BASE"
        shift
        ;;
      *)
        err "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  _ensure_machine

  log "Building $image (target=$target)..."
  podman build \
    --target "$target" \
    -t "$image" \
    -f "$DOTFILES/container/Containerfile" \
    "$DOTFILES"
}

cmd_shell() {
  local target="full"
  local image="$IMAGE_FULL"
  local skip_check=false
  local ref_paths=()
  local port_flags=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base)
        target="base"
        image="$IMAGE_BASE"
        shift
        ;;
      --ref)
        ref_paths+=("$2")
        shift 2
        ;;
      --port)
        port_flags+=(-p "$2:$2")
        shift 2
        ;;
      --skip-check)
        skip_check=true
        shift
        ;;
      *)
        err "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  _ensure_machine
  _load_env

  local container_name
  container_name="$(_container_name)"

  # Resolve workspace to git root
  local workspace
  workspace="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
  if [[ "$PWD" != "$workspace" ]]; then
    warn "Current directory differs from git root ($workspace). Mounting git root."
  fi

  # Check if container already exists
  if podman container exists "$container_name" 2>/dev/null; then
    local state
    state="$(podman inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null || echo unknown)"
    case "$state" in
      running)
        log "Attaching to running container '$container_name'..."
        exec podman exec -it "$container_name" bash -l
        ;;
      exited|stopped)
        log "Starting stopped container '$container_name'..."
        podman start "$container_name"
        exec podman exec -it "$container_name" bash -l
        ;;
    esac
  fi

  # Check for stale image
  if ! $skip_check && ! podman image exists "$image" 2>/dev/null; then
    err "Image '$image' not found. Run 'dev build' first."
    exit 1
  fi

  # Build run arguments
  # shellcheck disable=SC2207
  local security_flags=($(_security_flags))
  # shellcheck disable=SC2207
  local network_flags=($(_network_flags))
  # shellcheck disable=SC2207
  local volume_flags=($(_volume_flags))
  # shellcheck disable=SC2207
  local cred_mounts=($(_credential_mounts))
  # shellcheck disable=SC2207
  local git_env=($(_git_env_args))

  local ref_mounts=()
  for ref in "${ref_paths[@]+"${ref_paths[@]}"}"; do
    local ref_name
    ref_name="$(basename "$ref")"
    ref_mounts+=(-v "$ref:/home/dev/refs/$ref_name:ro")
  done

  log "Creating container '$container_name' from $image..."
  podman run -dit \
    --name "$container_name" \
    "${security_flags[@]}" \
    "${network_flags[@]}" \
    "${volume_flags[@]}" \
    "${cred_mounts[@]+"${cred_mounts[@]}"}" \
    "${git_env[@]+"${git_env[@]}"}" \
    "${ref_mounts[@]+"${ref_mounts[@]}"}" \
    "${port_flags[@]+"${port_flags[@]}"}" \
    -v "$workspace:/home/dev/workspace" \
    -w /home/dev/workspace \
    "$image" \
    bash -l

  exec podman exec -it "$container_name" bash -l
}

cmd_stop() {
  _ensure_machine

  local container_name
  container_name="$(_container_name)"

  if podman container exists "$container_name" 2>/dev/null; then
    log "Stopping container '$container_name'..."
    podman stop "$container_name"
  else
    warn "Container '$container_name' not found."
  fi
}

cmd_rebuild() {
  local clean=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --clean)
        clean=true
        shift
        ;;
      *)
        err "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  _ensure_machine

  local container_name
  container_name="$(_container_name)"

  # Stop and remove existing container
  if podman container exists "$container_name" 2>/dev/null; then
    log "Removing container '$container_name'..."
    podman rm -f "$container_name"
  fi

  if $clean; then
    log "Removing images for clean rebuild..."
    podman rmi -f "$IMAGE_FULL" "$IMAGE_BASE" 2>/dev/null || true
  fi

  cmd_build "$@"
}

cmd_status() {
  _ensure_machine

  log "Running dev containers:"
  podman ps --filter "name=^dev-" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

  if _is_macos; then
    echo ""
    log "Podman Machine status:"
    podman machine inspect dotfiles --format '{{.Name}}: {{.State}}' 2>/dev/null || echo "  dotfiles: not found"
  fi
}

cmd_prune() {
  _ensure_machine

  log "Removing stopped dev containers..."
  podman container prune -f --filter "name=^dev-"

  log "Removing dangling images..."
  podman image prune -f
}

cmd_clean_sessions() {
  _ensure_machine

  printf "${C_YELLOW}WARNING:${C_RESET} This will remove OpenCode session data from the dev-data-opencode volume.\n"
  printf "${C_YELLOW}WARNING:${C_RESET} Session history may contain sensitive data (user-pasted secrets, credentials).\n"
  printf "${C_YELLOW}WARNING:${C_RESET} This operation is irreversible.\n"
  echo ""
  read -rp "Continue? [y/N] " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    log "Aborted."
    return 0
  fi

  log "Removing OpenCode session data..."
  podman volume rm dev-data-opencode 2>/dev/null || true
  log "Volume dev-data-opencode removed. It will be recreated on next 'dev shell'."
}

cmd_init_machine() {
  if ! _is_macos; then
    log "Podman Machine is only needed on macOS. On Linux/WSL, podman runs natively."
    return 0
  fi

  local cpus=4
  local memory=8192
  local disk_size=60

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cpus)    cpus="$2"; shift 2 ;;
      --memory)  memory="$2"; shift 2 ;;
      --disk-size) disk_size="$2"; shift 2 ;;
      *) err "Unknown option: $1"; exit 1 ;;
    esac
  done

  # Check if machine already exists
  if podman machine inspect dotfiles &>/dev/null; then
    log "Podman Machine 'dotfiles' already exists."
    podman machine inspect dotfiles --format '  State: {{.State}}'
    return 0
  fi

  log "Creating Podman Machine 'dotfiles':"
  log "  CPUs:      $cpus"
  log "  Memory:    ${memory} MB"
  log "  Disk size: ${disk_size} GB"
  echo ""
  warn "Disk size can be grown later but NOT shrunk without destroying the machine."
  warn "  To grow: podman machine set --disk-size N dotfiles"
  warn "  To change CPUs/memory: podman machine set --cpus N --memory M dotfiles"
  echo ""
  read -rp "Create machine with these settings? [y/N] " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    log "Aborted."
    return 0
  fi

  podman machine init dotfiles \
    --cpus "$cpus" \
    --memory "$memory" \
    --disk-size "$disk_size" \
    --now

  log "Podman Machine 'dotfiles' created and started."
}

cmd_machine_start() {
  if ! _is_macos; then
    log "Podman Machine is only needed on macOS."
    return 0
  fi
  podman machine start dotfiles
}

cmd_machine_stop() {
  if ! _is_macos; then
    log "Podman Machine is only needed on macOS."
    return 0
  fi
  podman machine stop dotfiles
}

cmd_machine_status() {
  if ! _is_macos; then
    log "Podman Machine is only needed on macOS."
    return 0
  fi
  podman machine inspect dotfiles --format 'dotfiles: {{.State}}' 2>/dev/null || echo "dotfiles: not found"
}

# ── Usage ───────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: dev <command> [options]

Commands:
  build [--base]                     Build container image
  shell [--base] [--ref <path>]      Start/attach to dev container
        [--port <port>] [--skip-check]
  stop                               Stop container for current repo
  rebuild [--clean]                  Rebuild image and recreate container
  status                             Show running containers + machine status
  prune                              Remove stopped containers + dangling images
  clean-sessions                     Remove OpenCode session data
  init-machine [--cpus N]            Create macOS Podman Machine
    [--memory MB] [--disk-size GB]
  machine-start                      Start macOS Podman Machine
  machine-stop                       Stop macOS Podman Machine
  machine-status                     Show Podman Machine state
EOF
}

# ── Main ────────────────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

command="$1"
shift

case "$command" in
  build)          cmd_build "$@" ;;
  shell)          cmd_shell "$@" ;;
  stop)           cmd_stop ;;
  rebuild)        cmd_rebuild "$@" ;;
  status)         cmd_status ;;
  prune)          cmd_prune ;;
  clean-sessions) cmd_clean_sessions ;;
  init-machine)   cmd_init_machine "$@" ;;
  machine-start)  cmd_machine_start ;;
  machine-stop)   cmd_machine_stop ;;
  machine-status) cmd_machine_status ;;
  -h|--help|help) usage ;;
  *)
    err "Unknown command: $command"
    usage
    exit 1
    ;;
esac
