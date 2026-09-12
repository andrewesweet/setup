# shellcheck shell=bash
# scripts/lib/opencode-local-scaffold.sh
#
# Scaffold for the OpenCode personal overrides file
# ~/.config/opencode-local/opencode.jsonc (OPENCODE_CONFIG, see bash/.bashrc).
# Single source of truth shared by install-wsl.sh and install-macos.sh.
#
# Scaffold-if-absent: a personal overrides file with real content is never
# overwritten. The empty `{}` placeholder written by earlier installers holds
# no personal settings and is replaced by the current scaffold.

# Create the opencode-local directory and write the overrides file when it is
# absent or still the empty `{}` placeholder. The scaffold carries $schema plus
# the OpenTelemetry flag so installs export spans to the loopback collector
# named by $OTEL_EXPORTER_OTLP_ENDPOINT.
scaffold_opencode_local() {
  local file="$HOME/.config/opencode-local/opencode.jsonc"
  mkdir -p "${file%/*}"
  if [[ ! -f "$file" ]] || [[ "$(tr -d '[:space:]' < "$file")" == "{}" ]]; then
    cat > "$file" <<'JSONC'
{
  // OpenTelemetry spans are exported to the collector named by
  // $OTEL_EXPORTER_OTLP_ENDPOINT.
  "$schema": "https://opencode.ai/config.json",
  "experimental": { "openTelemetry": true }
}
JSONC
    printf "  created  %s\n" "$file"
  fi
}
