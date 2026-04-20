# shellcheck shell=bash
# extract-pair.sh — tool-specific fg/bg hex extractors.
#
# Per `docs/design/theming-qa.md` § 5.4, each function below prints the
# tool's resolved primary (or muted) "fg bg" hex pair on stdout as two
# whitespace-separated tokens ("#RRGGBB #RRGGBB"). If the tool's config
# file is absent from the repo the function returns non-zero so the
# caller in `test-plan-theming.sh` can record `skp` instead of failure.
#
# Assumed cwd: the macos-dev root (as set by test-plan-theming.sh).
#
# Stdlib only: bash + jq (already in the Brewfile) + standard grep/awk.

# ── opencode ────────────────────────────────────────────────────────────────
# Resolve `.theme.<slot>` through `.defs`. If the theme value is already a
# hex (starts with '#') use it directly; otherwise look it up in `.defs`.
_opencode_resolve() {
  local theme_file="$1" slot="$2"
  local raw
  raw=$(jq -r --arg slot "$slot" '.theme[$slot] // empty' "$theme_file") || return 1
  [[ -z "$raw" ]] && return 1
  if [[ "$raw" == \#* ]]; then
    printf '%s\n' "$raw"
    return 0
  fi
  jq -r --arg name "$raw" '.defs[$name] // empty' "$theme_file"
}

extract_opencode_primary() {
  local f="opencode/themes/dracula-pro.json"
  [[ -f "$f" ]] || return 1
  local fg bg
  fg=$(_opencode_resolve "$f" text)       || return 1
  bg=$(_opencode_resolve "$f" background) || return 1
  [[ -n "$fg" && -n "$bg" ]] || return 1
  printf '%s %s\n' "$fg" "$bg"
}

extract_opencode_muted() {
  local f="opencode/themes/dracula-pro.json"
  [[ -f "$f" ]] || return 1
  local fg bg
  fg=$(_opencode_resolve "$f" textMuted)  || return 1
  bg=$(_opencode_resolve "$f" background) || return 1
  [[ -n "$fg" && -n "$bg" ]] || return 1
  printf '%s %s\n' "$fg" "$bg"
}

# ── ghostty ─────────────────────────────────────────────────────────────────
# Ghostty config uses `foreground = #...` / `background = #...` lines.
# Repo currently delegates via `theme = ~/dracula-pro/themes/ghostty/pro`,
# so literal fg/bg lines will usually be absent → return non-zero → skip.
extract_ghostty() {
  local f="ghostty/config"
  [[ -f "$f" ]] || return 1
  local fg bg
  fg=$(awk -F'=' '/^[[:space:]]*foreground[[:space:]]*=/ {gsub(/[[:space:]#]/, "", $2); print "#" toupper($2); exit}' "$f")
  bg=$(awk -F'=' '/^[[:space:]]*background[[:space:]]*=/ {gsub(/[[:space:]#]/, "", $2); print "#" toupper($2); exit}' "$f")
  [[ -n "$fg" && -n "$bg" ]] || return 1
  printf '%s %s\n' "$fg" "$bg"
}

# ── kitty ───────────────────────────────────────────────────────────────────
# Kitty config uses bare `foreground #RRGGBB` / `background #RRGGBB` lines.
# Repo currently `include`s a generated Pro conf so literal fg/bg lines are
# absent → return non-zero → skip.
extract_kitty() {
  local f="kitty/kitty.conf"
  [[ -f "$f" ]] || return 1
  local fg bg
  fg=$(awk '/^[[:space:]]*foreground[[:space:]]+#/ {print toupper($2); exit}' "$f")
  bg=$(awk '/^[[:space:]]*background[[:space:]]+#/ {print toupper($2); exit}' "$f")
  [[ -n "$fg" && -n "$bg" ]] || return 1
  printf '%s %s\n' "$fg" "$bg"
}

# ── btop ────────────────────────────────────────────────────────────────────
# Lines look like:  theme[main_fg]="#F8F8F2"
extract_btop() {
  local f="btop/dracula-pro.theme"
  [[ -f "$f" ]] || return 1
  local fg bg
  fg=$(awk -F'"' '/theme\[main_fg\][[:space:]]*=/ {print toupper($2); exit}' "$f")
  bg=$(awk -F'"' '/theme\[main_bg\][[:space:]]*=/ {print toupper($2); exit}' "$f")
  [[ -n "$fg" && -n "$bg" ]] || return 1
  printf '%s %s\n' "$fg" "$bg"
}

# ── k9s ─────────────────────────────────────────────────────────────────────
# Use the body.fgColor / body.bgColor pair. Parse via awk to find the first
# fgColor/bgColor values under the `body:` block.
extract_k9s() {
  local f="k9s/dracula-pro.yaml"
  [[ -f "$f" ]] || return 1
  local fg bg
  # shellcheck disable=SC2016
  fg=$(awk '
    /^[[:space:]]*body:/ { in_body = 1; next }
    /^[[:space:]]{0,4}[a-zA-Z]+:[[:space:]]*$/ && in_body && !/body:/ { in_body = 0 }
    in_body && /fgColor:/ {
      match($0, /#[0-9A-Fa-f]{6}/); if (RSTART) print toupper(substr($0, RSTART, RLENGTH)); exit
    }
  ' "$f")
  # shellcheck disable=SC2016
  bg=$(awk '
    /^[[:space:]]*body:/ { in_body = 1; next }
    /^[[:space:]]{0,4}[a-zA-Z]+:[[:space:]]*$/ && in_body && !/body:/ { in_body = 0 }
    in_body && /bgColor:/ {
      match($0, /#[0-9A-Fa-f]{6}/); if (RSTART) print toupper(substr($0, RSTART, RLENGTH)); exit
    }
  ' "$f")
  [[ -n "$fg" && -n "$bg" ]] || return 1
  printf '%s %s\n' "$fg" "$bg"
}

# ── bat (tmTheme plist) ─────────────────────────────────────────────────────
# The global canvas `<dict>` contains `<key>foreground</key><string>#...</string>`
# and `<key>background</key><string>#...</string>`. Extract from the first
# <dict> block that contains both.
extract_bat() {
  # Glob for any Dracula Pro tmTheme file — filename may contain a space.
  local f
  for candidate in bat/themes/*.tmTheme; do
    [[ -f "$candidate" ]] || continue
    f="$candidate"
    break
  done
  [[ -n "${f:-}" && -f "$f" ]] || return 1
  local fg bg
  # Collapse the plist onto one line, then extract the first
  # <key>foreground</key><string>#...</string> and similarly for background.
  local flat
  flat=$(tr -d '\n' <"$f")
  fg=$(printf '%s' "$flat" | grep -oE '<key>foreground</key>[[:space:]]*<string>#[0-9A-Fa-f]{6}</string>' | head -n1 \
    | grep -oE '#[0-9A-Fa-f]{6}' | head -n1 | tr '[:lower:]' '[:upper:]')
  bg=$(printf '%s' "$flat" | grep -oE '<key>background</key>[[:space:]]*<string>#[0-9A-Fa-f]{6}</string>' | head -n1 \
    | grep -oE '#[0-9A-Fa-f]{6}' | head -n1 | tr '[:lower:]' '[:upper:]')
  [[ -n "$fg" && -n "$bg" ]] || return 1
  printf '%s %s\n' "$fg" "$bg"
}
