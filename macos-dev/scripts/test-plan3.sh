#!/usr/bin/env bash
# test-plan3.sh — smoke tests for Plan 3 (git configuration)
#
# Validates:
#   - Both git config files exist
#   - .gitconfig has required sections and settings
#   - .gitconfig does NOT have [user] or editor (identity in .gitconfig.local)
#   - .gitignore_global has required patterns
#   - Install scripts have correct link() mappings for git files
#   - .gitconfig.local is in repo .gitignore
#
# Usage: bash scripts/test-plan3.sh
# Exit: 0 if all tests pass, 1 if any fail

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

echo "Plan 3: git configuration smoke tests"
echo ""

# ── File existence ─────────────────────────────────────────────────────────
echo "File existence:"
check ".gitconfig exists"          test -f "$REPO_ROOT/git/.gitconfig"
check ".gitignore_global exists"   test -f "$REPO_ROOT/git/.gitignore_global"

# ── .gitconfig structure ───────────────────────────────────────────────────
echo ""
echo ".gitconfig structure:"

# Include for local identity
check "include path to .gitconfig.local"  grep -q 'path.*gitconfig.local' "$REPO_ROOT/git/.gitconfig"

# MUST NOT have [user] section (identity in .gitconfig.local)
if grep -q '^\[user\]' "$REPO_ROOT/git/.gitconfig"; then
  nok "[user] section absent (should be in .gitconfig.local)"
else
  ok "[user] section absent (in .gitconfig.local)"
fi

# MUST NOT have editor key assignment (falls back to $EDITOR)
if grep -qiE '^\s*editor\s*=' "$REPO_ROOT/git/.gitconfig"; then
  nok "no editor setting (falls back to \$EDITOR)"
else
  ok "no editor setting (falls back to \$EDITOR)"
fi

# Core settings
check "core.pager = delta"            grep -q 'pager.*=.*delta' "$REPO_ROOT/git/.gitconfig"
check "core.excludesFile camelCase"   grep -q 'excludesFile' "$REPO_ROOT/git/.gitconfig"
check "core.autocrlf = input"         grep -q 'autocrlf.*=.*input' "$REPO_ROOT/git/.gitconfig"

# Delta configuration
check "delta.navigate = true"         grep -q 'navigate.*=.*true' "$REPO_ROOT/git/.gitconfig"
check "delta.side-by-side = true"     grep -q 'side-by-side.*=.*true' "$REPO_ROOT/git/.gitconfig"
check "delta.line-numbers = true"     grep -q 'line-numbers.*=.*true' "$REPO_ROOT/git/.gitconfig"
check "delta.syntax-theme = Dracula (1b-ii)"  grep -q 'syntax-theme.*=.*Dracula' "$REPO_ROOT/git/.gitconfig"
check "delta decorations feature"     grep -q 'features.*=.*decorations' "$REPO_ROOT/git/.gitconfig"
check "interactive.diffFilter delta"  grep -q 'diffFilter.*=.*delta' "$REPO_ROOT/git/.gitconfig"

# Diff tools
check "diff.tool = difftastic"       grep -qE '^\s*tool\s*=.*difftastic' "$REPO_ROOT/git/.gitconfig"
check "difftool difft cmd"           grep -q 'cmd.*=.*difft' "$REPO_ROOT/git/.gitconfig"

# Merge
check "merge.conflictstyle = diff3"  grep -q 'conflictstyle.*=.*diff3' "$REPO_ROOT/git/.gitconfig"
check "merge.tool = nvimdiff"        grep -qE '^\s*tool\s*=.*nvimdiff' "$REPO_ROOT/git/.gitconfig"
check "mergetool vscode stanza"      grep -qF '[mergetool "vscode"]' "$REPO_ROOT/git/.gitconfig"
check "mergetool vscode cmd"         grep -q 'code --wait --merge' "$REPO_ROOT/git/.gitconfig"
# shellcheck disable=SC2016
check "mergetool vars quoted"        grep -qF '"$REMOTE" "$LOCAL" "$BASE" "$MERGED"' "$REPO_ROOT/git/.gitconfig"
check "mergetool.keepBackup = false" grep -q 'keepBackup.*=.*false' "$REPO_ROOT/git/.gitconfig"

# Workflow settings
check "pull.rebase = true"          grep -q 'rebase.*=.*true' "$REPO_ROOT/git/.gitconfig"
check "rebase.autoStash = true"     grep -q 'autoStash.*=.*true' "$REPO_ROOT/git/.gitconfig"
check "rebase.autoSquash = true"    grep -q 'autoSquash.*=.*true' "$REPO_ROOT/git/.gitconfig"
check "push.default = current"      grep -q 'default.*=.*current' "$REPO_ROOT/git/.gitconfig"
check "push.autoSetupRemote = true" grep -q 'autoSetupRemote.*=.*true' "$REPO_ROOT/git/.gitconfig"
check "fetch.prune = true"          grep -q 'prune.*=.*true' "$REPO_ROOT/git/.gitconfig"
check "branch.sort"                 grep -q 'sort.*=.*-committerdate' "$REPO_ROOT/git/.gitconfig"
check "log.date = relative"         grep -q 'date.*=.*relative' "$REPO_ROOT/git/.gitconfig"
check "stash.showPatch = true"      grep -q 'showPatch.*=.*true' "$REPO_ROOT/git/.gitconfig"

# Aliases
check "alias: undo"                 grep -q 'undo.*=.*reset HEAD~1' "$REPO_ROOT/git/.gitconfig"
check "alias: wip"                  grep -q 'wip.*=.*!git add -A' "$REPO_ROOT/git/.gitconfig"
check "alias: unwip"                grep -q 'unwip.*=.*WIP' "$REPO_ROOT/git/.gitconfig"
check "alias: unwip feedback"       grep -qF 'No WIP commit found' "$REPO_ROOT/git/.gitconfig"
check "alias: aliases"              grep -q 'aliases.*=.*config --get-regexp' "$REPO_ROOT/git/.gitconfig"

# ── .gitignore_global ──────────────────────────────────────────────────────
echo ""
echo ".gitignore_global patterns:"

# macOS — use -qF for literal matching of gitignore glob patterns
check "ignores .DS_Store"           grep -qF '.DS_Store' "$REPO_ROOT/git/.gitignore_global"
check "ignores .AppleDouble"        grep -qF '.AppleDouble' "$REPO_ROOT/git/.gitignore_global"
check "ignores .LSOverride"         grep -qF '.LSOverride' "$REPO_ROOT/git/.gitignore_global"
check "ignores ._*"                 grep -qF '._*' "$REPO_ROOT/git/.gitignore_global"

# Editors
check "ignores .vscode/"           grep -qF '.vscode/' "$REPO_ROOT/git/.gitignore_global"
check "ignores .idea/"             grep -qF '.idea/' "$REPO_ROOT/git/.gitignore_global"
check "ignores *.swp"              grep -qF '*.swp' "$REPO_ROOT/git/.gitignore_global"
check "ignores *.swo"              grep -qF '*.swo' "$REPO_ROOT/git/.gitignore_global"
check "ignores *~"                 grep -qF '*~' "$REPO_ROOT/git/.gitignore_global"
check "ignores .aider*"            grep -qF '.aider*' "$REPO_ROOT/git/.gitignore_global"

# OS/tools
check "ignores Thumbs.db"          grep -qF 'Thumbs.db' "$REPO_ROOT/git/.gitignore_global"
check "ignores .direnv/"           grep -qF '.direnv/' "$REPO_ROOT/git/.gitignore_global"

# Secrets — core
check "ignores .env"               grep -qxF '.env' "$REPO_ROOT/git/.gitignore_global"
check "ignores .env.*"             grep -qF '.env.*' "$REPO_ROOT/git/.gitignore_global"
check "ignores *.env"              grep -qF '*.env' "$REPO_ROOT/git/.gitignore_global"
check "ignores *.pem"              grep -qF '*.pem' "$REPO_ROOT/git/.gitignore_global"
check "ignores *.key"              grep -qF '*.key' "$REPO_ROOT/git/.gitignore_global"
check "ignores *.p12"              grep -qF '*.p12' "$REPO_ROOT/git/.gitignore_global"
check "ignores *.pfx"              grep -qF '*.pfx' "$REPO_ROOT/git/.gitignore_global"
check "ignores *.p8"               grep -qF '*.p8' "$REPO_ROOT/git/.gitignore_global"
check "ignores *.jks"              grep -qF '*.jks' "$REPO_ROOT/git/.gitignore_global"
check "ignores *.keystore"         grep -qF '*.keystore' "$REPO_ROOT/git/.gitignore_global"
check "ignores auth.json"          grep -qF 'auth.json' "$REPO_ROOT/git/.gitignore_global"
check "ignores credentials.json"   grep -qF 'credentials.json' "$REPO_ROOT/git/.gitignore_global"
check "ignores application_default_credentials.json" grep -qF 'application_default_credentials.json' "$REPO_ROOT/git/.gitignore_global"

# Secrets — SSH keys
check "ignores *_rsa"              grep -qF '*_rsa' "$REPO_ROOT/git/.gitignore_global"
check "ignores *_ecdsa"            grep -qF '*_ecdsa' "$REPO_ROOT/git/.gitignore_global"
check "ignores *_ed25519"          grep -qF '*_ed25519' "$REPO_ROOT/git/.gitignore_global"

# Secrets — npm/terraform
check "ignores .npmrc"             grep -qF '.npmrc' "$REPO_ROOT/git/.gitignore_global"
check "ignores terraform.tfstate*" grep -qF 'terraform.tfstate' "$REPO_ROOT/git/.gitignore_global"
check "ignores .terraform/"        grep -qF '.terraform/' "$REPO_ROOT/git/.gitignore_global"
check "ignores *.tfvars"           grep -qF '*.tfvars' "$REPO_ROOT/git/.gitignore_global"

# Local overrides
check "ignores .bashrc.local"      grep -qF '.bashrc.local' "$REPO_ROOT/git/.gitignore_global"
check "ignores .gitconfig.local"   grep -qF '.gitconfig.local' "$REPO_ROOT/git/.gitignore_global"
check "ignores dev.env"            grep -qF 'dev.env' "$REPO_ROOT/git/.gitignore_global"

# ── Repo .gitignore ───────────────────────────────────────────────────────
echo ""
echo "Repo .gitignore:"
check ".gitconfig.local in repo .gitignore" grep -q '\.gitconfig\.local' "$REPO_ROOT/.gitignore"

# ── Install script link() calls ───────────────────────────────────────────
echo ""
echo "Install scripts:"

check "macos: .gitconfig mapping"        grep -q 'link git/.gitconfig.*\.gitconfig' "$REPO_ROOT/install-macos.sh"
check "macos: .gitignore_global mapping" grep -q 'link git/.gitignore_global.*\.gitignore_global' "$REPO_ROOT/install-macos.sh"
check "wsl: .gitconfig mapping"          grep -q 'link git/.gitconfig.*\.gitconfig' "$REPO_ROOT/install-wsl.sh"
check "wsl: .gitignore_global mapping"   grep -q 'link git/.gitignore_global.*\.gitignore_global' "$REPO_ROOT/install-wsl.sh"

# Verify bash link() calls from Plan 2 still present (regression)
check "macos: bash links preserved"      test "$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "wsl: bash links preserved"        test "$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh")" -eq 4

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Current count: ~70 tests. Floor should be within ~10% of actual.
if (( total < 63 )); then
  echo "WARNING: only $total tests ran (expected >= 63). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
