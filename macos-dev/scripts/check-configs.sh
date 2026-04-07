#!/usr/bin/env bash
# check-configs.sh — config file parse validation
#
# Validates:
#   1. bash -n on all bash config files
#   2. JSON validity of opencode.jsonc and tui.jsonc (strip comments, python3 json.load)
#   3. JSON validity of vscode/settings.json and vscode/extensions.json
#   4. TOML validity of starship.toml and mise/config.toml
#   5. YAML validity of lazygit/config.yml and prek/.pre-commit-config.yaml
#
# Usage: bash scripts/check-configs.sh
# Exit: 0 if all pass, 1 if any fail

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass=0
fail=0

ok() {
  printf "  \033[0;32m✓\033[0m %s\n" "$1"
  pass=$((pass + 1))
}

nok() {
  printf "  \033[0;31m✗\033[0m %s\n" "$1"
  fail=$((fail + 1))
}

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "$desc"
  else
    nok "$desc"
  fi
}

echo "check-configs.sh — config file validation"
echo ""

# ── 1. Bash syntax (bash -n) ───────────────────────────────────────────────
echo "Bash syntax:"
for f in bash/.bash_profile bash/.bashrc bash/.bash_aliases; do
  check "bash -n $f" bash -n "$REPO_ROOT/$f"
done

# ── 2. JSONC validity (strip // comments, validate with python3) ──────────
echo ""
echo "JSONC files:"
for f in opencode/opencode.jsonc opencode/tui.jsonc; do
  check "jsonc valid: $f" python3 -c "
import json, re, sys
with open('$REPO_ROOT/$f') as fh:
    text = fh.read()
# Strip // comments that are not inside strings
lines = text.split('\n')
cleaned = []
for line in lines:
    result = ''
    in_str = False
    i = 0
    while i < len(line):
        c = line[i]
        if c == '\"' and (i == 0 or line[i-1] != '\\\\'):
            in_str = not in_str
            result += c
        elif not in_str and c == '/' and i+1 < len(line) and line[i+1] == '/':
            break
        else:
            result += c
        i += 1
    cleaned.append(result)
text = '\n'.join(cleaned)
# Strip trailing commas before } or ]
text = re.sub(r',\s*([}\]])', r'\1', text)
json.loads(text)
"
done

# ── 3. JSON validity ───────────────────────────────────────────────────────
echo ""
echo "JSON files:"
for f in vscode/settings.json vscode/extensions.json; do
  check "json valid: $f" python3 -c "
import json, sys
with open('$REPO_ROOT/$f') as fh:
    json.load(fh)
"
done

# ── 4. TOML validity ───────────────────────────────────────────────────────
echo ""
echo "TOML files:"
# Python 3.11+ has tomllib in stdlib; fall back to a basic syntax check
for f in starship/starship.toml mise/config.toml; do
  check "toml valid: $f" python3 -c "
import sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib
with open('$REPO_ROOT/$f', 'rb') as fh:
    tomllib.load(fh)
"
done

# ── 5. YAML validity ───────────────────────────────────────────────────────
echo ""
echo "YAML files:"
for f in lazygit/config.yml prek/.pre-commit-config.yaml; do
  check "yaml valid: $f" python3 -c "
import yaml, sys
with open('$REPO_ROOT/$f') as fh:
    yaml.safe_load(fh)
"
done

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
