# shellcheck shell=bash
# scripts/lib/opencode-local-scaffold.sh
#
# Scaffold for the OpenCode personal overrides file
# ~/.config/opencode-local/opencode.jsonc (OPENCODE_CONFIG, see bash/.bashrc).
# Single source of truth shared by install-wsl.sh and install-macos.sh.
#
# Scaffold-if-absent: a personal overrides file with real content is never
# overwritten. The empty `{}` placeholder written by earlier installers holds
# no personal settings and is replaced by the current scaffold. OpenCode
# rewrites a loaded `{}` to `{ "$schema": "https://opencode.ai/config.json", }`
# on first launch; that form is the same placeholder and is replaced too.

# User-facing scaffold rules: README.md, Local overrides.
scaffold_opencode_local() {
  local file="$HOME/.config/opencode-local/opencode.jsonc"
  mkdir -p "${file%/*}"
  # Upgrade the placeholder in both forms it takes on previously-installed
  # hosts: the bare `{}` written by earlier installers, and the same file as
  # OpenCode rewrites it on first launch (schema key added, nothing else).
  # Any other content is personal and is never touched.
  if [[ -f "$file" ]]; then
    # shellcheck disable=SC2016  # literal key, expansion not wanted
    local schema_key='"$schema":"https://opencode.ai/config.json",'
    local stripped
    stripped="$(tr -d '[:space:]' <"$file")"
    stripped="${stripped//"$schema_key"/}"
    [[ "$stripped" == "{}" ]] || return 0
  fi
  cat >"$file" <<'JSONC'
{
  // OpenTelemetry spans are exported to the collector named by
  // $OTEL_EXPORTER_OTLP_ENDPOINT.
  "$schema": "https://opencode.ai/config.json",
  "experimental": { "openTelemetry": true }
}
JSONC
  printf "  created  %s\n" "$file"
}
