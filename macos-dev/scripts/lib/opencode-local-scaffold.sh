# shellcheck shell=bash
# scripts/lib/opencode-local-scaffold.sh
#
# Scaffold for the OpenCode personal overrides file
# ~/.config/opencode-local/opencode.jsonc (OPENCODE_CONFIG, see bash/.bashrc).
# Single source of truth shared by install-wsl.sh and install-macos.sh.
#
# Scaffold-if-absent: an existing personal overrides file is never overwritten.

# Create the opencode-local directory and write the overrides file only when
# absent. The scaffold carries $schema plus the OpenTelemetry flag so installs
# export spans to the loopback collector named by $OTEL_EXPORTER_OTLP_ENDPOINT.
scaffold_opencode_local() {
  mkdir -p "$HOME/.config/opencode-local"
  if [[ ! -f "$HOME/.config/opencode-local/opencode.jsonc" ]]; then
    cat > "$HOME/.config/opencode-local/opencode.jsonc" <<'JSONC'
{
  // OpenTelemetry spans are exported to the collector named by
  // $OTEL_EXPORTER_OTLP_ENDPOINT.
  "$schema": "https://opencode.ai/config.json",
  "experimental": { "openTelemetry": true }
}
JSONC
    printf "  created  %s\n" "$HOME/.config/opencode-local/opencode.jsonc"
  fi
}
