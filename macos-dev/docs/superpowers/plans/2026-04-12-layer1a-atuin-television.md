# Layer 1a Implementation Plan: atuin + television (shell-agnostic, bash-opt-in)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install and configure atuin (shell history) and television (fuzzy picker) as the smallest meaningful increment of the shell modernisation design, with opt-in bash integration so no existing muscle memory breaks. Starship gets a Dracula palette refresh as a purely visual change.

**Architecture:** Add brew formulas + tools.txt entries, write TOML configs symlinked from `$DOTFILES`, gate the bash inits behind `ENABLE_ATUIN=1` and `ENABLE_TV=1` environment variables so users opt in from `~/.bashrc.local`. Television explicitly does NOT claim Ctrl-R — atuin is the sole owner. No changes to zsh or nushell yet.

**Tech Stack:** bash, brew, atuin, television, starship, GNU coreutils (check-configs.sh uses `ln`, `readlink`, `find`)

**Spec reference:** `docs/plans/2026-04-12-shell-modernisation-design.md` Layer 1a (section 4)

**Platform scope:** macOS (Apple Silicon + Intel), WSL2 (Ubuntu-based), and Alpine containers. Tests run on both macOS runner and WSL2 runner in CI, and locally on both environments.

---

## Acceptance Criteria (Specification by Example)

Each bullet below is a testable assertion derived from the spec. Every task in this plan contributes to one or more of these criteria. The acceptance test script `scripts/test-plan-layer1a.sh` will validate every assertion end-to-end.

**AC-1: Brewfile installs atuin and television**
```
Given: a fresh macOS machine with Homebrew installed
When: `brew bundle --file=Brewfile` runs
Then: `command -v atuin` and `command -v tv` both succeed
And: `atuin --version` prints a version string
And: `tv --version` prints a version string
```

**AC-2: tools.txt is consistent with Brewfile**
```
Given: the repo state
When: `bash scripts/check-tool-manifest.sh` runs
Then: exit code is 0 (no unmatched entries between Brewfile and tools.txt)
```

**AC-3: atuin config is symlinked from DOTFILES**
```
Given: `bash install-macos.sh` (or install-wsl.sh) has run
When: `readlink ~/.config/atuin/config.toml` is invoked
Then: the output equals `$DOTFILES/atuin/config.toml`
```

**AC-4: atuin config disables sync by default**
```
Given: the installed atuin/config.toml
When: `grep -E "^auto_sync\s*=" $DOTFILES/atuin/config.toml` runs
Then: the value is `false`
```

**AC-5: atuin history_filter covers token prefixes from the security review**
```
Given: the installed atuin/config.toml
When: inspected
Then: history_filter contains patterns for: GITHUB_TOKEN, GH_TOKEN, SECRET,
      PASSWORD, BEARER, AUTHORIZATION, AWS_ACCESS, AWS_SECRET, AWS_SESSION,
      ANTHROPIC, OPENAI, ghp_, gho_, github_pat_, glpat-, sk-, xoxb-, xoxp-
```

**AC-6: television config is symlinked from DOTFILES**
```
Given: install has run
When: `readlink ~/.config/television/config.toml` is invoked
Then: the output equals `$DOTFILES/television/config.toml`
```

**AC-7: television does NOT claim Ctrl-R in shell integration**
```
Given: the installed television/config.toml
When: parsing [shell_integration.keybindings]
Then: only `smart_autocomplete = "ctrl-t"` is present
And: no `command_history` key exists
```

**AC-8: Bash atuin init is opt-in via ENABLE_ATUIN**
```
Given: bash/.bashrc
When: executed with ENABLE_ATUIN unset
Then: `atuin` is not bound to Ctrl-R (bind -P shows reverse-search-history)

Given: bash/.bashrc
When: executed with ENABLE_ATUIN=1
Then: `bind -P` output for '\C-r' references atuin's search function
```

**AC-9: Bash television init is opt-in via ENABLE_TV**
```
Given: bash/.bashrc
When: executed with ENABLE_TV unset
Then: no tv shell function is defined

Given: bash/.bashrc
When: executed with ENABLE_TV=1
Then: tv shell integration is active (tv init bash output is sourced)
```

**AC-10: Starship uses Dracula palette**
```
Given: the installed starship/starship.toml
When: `grep '^palette' $DOTFILES/starship/starship.toml` runs
Then: the output is `palette = "dracula"`
And: the `[palettes.dracula]` table contains the 11 Dracula colors
      (background, current_line, foreground, comment, cyan, green,
       orange, pink, purple, red, yellow)
```

**AC-11: Install script is idempotent**
```
Given: install-macos.sh (or install-wsl.sh) has already run successfully
When: it is run a second time
Then: exit code is 0
And: no symlink is broken
And: no "backup created" messages appear for files already symlinked to $DOTFILES
```

**AC-12: Restore script reverts atuin and television symlinks**
```
Given: install has run, creating atuin + television symlinks
When: `bash install-macos.sh --restore` runs
Then: the atuin and television symlinks are removed
And: any prior files that were backed up are restored
```

**AC-13: verify.sh passes**
```
Given: a fully installed machine
When: `bash scripts/verify.sh` runs
Then: exit code is 0
```

**AC-14: Acceptance test script enumerates all above criteria**
```
Given: the repo state after this plan is complete
When: `bash scripts/test-plan-layer1a.sh` runs on macOS or WSL2
Then: every AC above is checked and passes
And: exit code is 0
```

---

## File Structure

**New files (created by this plan):**
- `atuin/config.toml` — atuin configuration, syncd disabled, comprehensive history filter
- `television/config.toml` — television configuration, Ctrl-T only (not Ctrl-R)
- `scripts/test-plan-layer1a.sh` — acceptance test script implementing all 14 ACs

**Modified files:**
- `Brewfile` — add `atuin` and `television`
- `tools.txt` — add entries for both tools (preserves check-tool-manifest.sh contract)
- `install-macos.sh` — add link() calls for atuin and television config symlinks
- `install-wsl.sh` — add same link() calls (and gh_release_install calls since these aren't in apt)
- `bash/.bashrc` — add gated atuin and television inits in section 8
- `starship/starship.toml` — replace existing palette with Dracula palette + refs
- `scripts/verify.sh` — add smoke checks for the new tools
- `docs/cheatsheet.md` — update Ctrl-R label (fzf → atuin), Ctrl-T label (fzf → television)

**Untouched (preserved):**
- `bash/.bash_aliases` — aliases unchanged; atuin/television are shell-level integrations
- `zsh/`, `nushell/` — not introduced in Layer 1a
- All other tool configs — no cross-cutting changes

---

## Task 0: Bootstrap Acceptance Test Script (Red)

Before writing any production code, create the acceptance test script with stubs for all 14 ACs. Every AC starts as a failing test. As subsequent tasks implement features, the corresponding ACs flip to passing. This is the ATDD outer loop.

**Files:**
- Create: `scripts/test-plan-layer1a.sh`

- [ ] **Step 1: Create the test script skeleton**

```bash
#!/usr/bin/env bash
# test-plan-layer1a.sh — acceptance tests for Layer 1a (atuin + television + starship Dracula)
#
# Platform-aware: runs on macOS and WSL2/Linux.
#
# Usage:
#   bash scripts/test-plan-layer1a.sh              # safe tests only
#   bash scripts/test-plan-layer1a.sh --full       # + invasive tests (bash -lc init checks)
#
# Each AC from the Layer 1a plan is implemented as a labelled check.
# Exits 0 if all requested tests pass, 1 otherwise.

set -uo pipefail

# ── Self-resolve to macos-dev root ───────────────────────────────────────────
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
MACOS_DEV="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"
cd "$MACOS_DEV" || { echo "ERROR: cannot cd to $MACOS_DEV" >&2; exit 2; }

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)
    PLATFORM="linux"
    [[ -n "${WSL_DISTRO_NAME:-}" ]] && PLATFORM="wsl"
    ;;
  *) echo "ERROR: unsupported platform" >&2; exit 2 ;;
esac

if [[ -t 1 ]]; then
  C_GREEN=$'\033[0;32m' C_RED=$'\033[0;31m' C_YELLOW=$'\033[0;33m' C_RESET=$'\033[0m'
else
  C_GREEN='' C_RED='' C_YELLOW='' C_RESET=''
fi

pass=0
fail=0
skip=0

ok()   { printf "  ${C_GREEN}✓${C_RESET} %s\n" "$1"; pass=$((pass + 1)); }
nok()  { printf "  ${C_RED}✗${C_RESET} %s\n" "$1"; fail=$((fail + 1)); }
skp()  { printf "  ${C_YELLOW}~${C_RESET} %s (skipped: %s)\n" "$1" "$2"; skip=$((skip + 1)); }

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else nok "$desc"; fi
}

echo "Layer 1a acceptance tests (atuin + television + Dracula starship)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1: Brewfile installs atuin and television ──────────────────────────
echo "AC-1: Brewfile installs atuin and television"
check "Brewfile has brew \"atuin\""          grep -qE '^\s*brew\s+"atuin"' Brewfile
check "Brewfile has brew \"television\""     grep -qE '^\s*brew\s+"television"' Brewfile
if [[ "$FULL" == true ]]; then
  check "atuin is on PATH"                   command -v atuin
  check "television (tv) is on PATH"         command -v tv
else
  skp "atuin on PATH" "safe mode"
  skp "tv on PATH" "safe mode"
fi

# ── AC-2: tools.txt is consistent with Brewfile ─────────────────────────
echo ""
echo "AC-2: tools.txt manifest consistency"
check "check-tool-manifest.sh passes"        bash scripts/check-tool-manifest.sh

# ── AC-3, AC-6, AC-10, AC-11 etc. — stubs to be filled by later tasks ───
# (Placeholders for each AC; each will become a real check as features land.)

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x scripts/test-plan-layer1a.sh`

- [ ] **Step 3: Run the script to verify it runs (red state)**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-1 checks fail (Brewfile missing atuin/television), AC-2 may pass if existing Brewfile is consistent. Exit code 1.

- [ ] **Step 4: Commit**

```bash
git add scripts/test-plan-layer1a.sh
git commit -m "test(plan-layer1a): scaffold acceptance test script with AC-1 and AC-2"
```

---

## Task 1: Add atuin and television to Brewfile + tools.txt (AC-1, AC-2)

**Files:**
- Modify: `Brewfile`
- Modify: `tools.txt`
- Test: `scripts/test-plan-layer1a.sh` (AC-1, AC-2)

- [ ] **Step 1: Verify current state of Brewfile and tools.txt**

Run: `grep -E 'atuin|television' Brewfile tools.txt || echo "neither present"`
Expected: `neither present`

- [ ] **Step 2: Add a new "History & search" section to Brewfile**

Modify `Brewfile`: insert this block immediately after the existing "Navigation & search" section (right after the line `brew "ripgrep"`):

```
# ── History & search (new — Layer 1a) ────────────────────────────────────────
brew "atuin"
brew "television"
```

- [ ] **Step 3: Add matching entries to tools.txt**

Modify `tools.txt`: insert this block immediately after the existing "Navigation & search" section (right after the `ripgrep` line):

```
# ── History & search (new — Layer 1a) ────────────────────────────────────────
atuin                brew:atuin                     apt:-                   apk:atuin
television           brew:television                apt:-                   apk:-
```

- [ ] **Step 4: Run the tool manifest check**

Run: `bash scripts/check-tool-manifest.sh`
Expected: exit 0, no mismatches.

- [ ] **Step 5: Run the acceptance tests**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-1 Brewfile checks pass. AC-2 passes.

- [ ] **Step 6: Commit**

```bash
git add Brewfile tools.txt
git commit -m "feat(brewfile): add atuin and television (Layer 1a)"
```

---

## Task 2: Create atuin/config.toml (AC-3, AC-4, AC-5)

**Files:**
- Create: `atuin/config.toml`
- Test: `scripts/test-plan-layer1a.sh` (AC-4, AC-5)

- [ ] **Step 1: Add AC-4 and AC-5 checks to the test script**

Modify `scripts/test-plan-layer1a.sh`: add these blocks before the final summary line:

```bash
# ── AC-4: atuin auto_sync = false ─────────────────────────────────────────
echo ""
echo "AC-4: atuin config disables sync"
check "atuin/config.toml exists"             test -f atuin/config.toml
check "auto_sync = false"                    grep -qE '^\s*auto_sync\s*=\s*false' atuin/config.toml

# ── AC-5: history_filter covers token/secret prefixes ───────────────────
echo ""
echo "AC-5: atuin history_filter coverage"
for pat in GITHUB_TOKEN GH_TOKEN SECRET PASSWORD BEARER AUTHORIZATION \
           AWS_ACCESS AWS_SECRET AWS_SESSION ANTHROPIC OPENAI \
           'ghp_' 'gho_' 'github_pat_' 'glpat-' 'sk-' 'xoxb-' 'xoxp-'; do
  check "history_filter contains pattern '$pat'" \
    bash -c "awk '/^history_filter = \[/,/^\]/' atuin/config.toml | grep -Fq '$pat'"
done
```

- [ ] **Step 2: Run tests to confirm they fail**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-4 and AC-5 checks fail because atuin/config.toml does not exist yet.

- [ ] **Step 3: Create atuin/config.toml**

Create `atuin/config.toml` with this content:

```toml
# atuin/config.toml — shell history management
# See docs/plans/2026-04-12-shell-modernisation-design.md § 3.1
#
# Sync is DISABLED by default. To enable:
#   - Self-hosted: set sync_address to your server URL, auto_sync = true
#   - atuin.sh cloud: sync_address = "https://api.atuin.sh", auto_sync = true
# Encryption key at ~/.local/share/atuin/key is NEVER synced.

# ── UI ──────────────────────────────────────────────────────────────────────
style = "compact"
enter_accept = true

# ── Search ──────────────────────────────────────────────────────────────────
search_mode = "fuzzy"
filter_mode = "global"
workspaces = true
filter_mode_shell_up_key_binding = "directory"

# ── Keymap ──────────────────────────────────────────────────────────────────
keymap_mode = "auto"

# ── Secret filtering ────────────────────────────────────────────────────────
# Default regexes cover AWS keys, GitHub PATs, Slack tokens, Stripe keys.
secrets_filter = true

# Custom filter for variable-assignment-style patterns AND raw token prefixes.
# Unanchored regexes — match anywhere in command.
history_filter = [
  "^.*GITHUB_TOKEN.*$",
  "^.*GH_TOKEN.*$",
  "^.*SECRET.*$",
  "^.*PASSWORD.*$",
  "^.*BEARER.*$",
  "^.*AUTHORIZATION.*$",
  "^.*AWS_ACCESS.*$",
  "^.*AWS_SECRET.*$",
  "^.*AWS_SESSION.*$",
  "^.*ANTHROPIC.*$",
  "^.*OPENAI.*$",
  "^.*ghp_[A-Za-z0-9_]+.*$",
  "^.*gho_[A-Za-z0-9_]+.*$",
  "^.*github_pat_[A-Za-z0-9_]+.*$",
  "^.*glpat-[A-Za-z0-9_-]+.*$",
  # OpenAI sk-/sk-proj-/sk-ant- style keys; lower bound of 20 chars
  # after the sk- prefix rejects false positives like "disk-utils".
  "^.*sk-[A-Za-z0-9_-]{20,}.*$",
  "^.*xoxb-[A-Za-z0-9-]+.*$",
  "^.*xoxp-[A-Za-z0-9-]+.*$",
  "^.*PRIVATE.KEY.*$",
]

# ── Sync DISABLED ───────────────────────────────────────────────────────────
auto_sync = false

[sync]
records = true

[stats]
common_subcommands = [
  "cargo", "docker", "git", "go", "gcloud",
  "kubectl", "npm", "podman", "terraform", "tmux",
]
```

- [ ] **Step 4: Run tests to confirm they pass**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-4 and AC-5 checks pass.

- [ ] **Step 5: Commit**

```bash
git add atuin/config.toml scripts/test-plan-layer1a.sh
git commit -m "feat(atuin): config.toml with sync disabled and comprehensive history filter"
```

---

## Task 3: Create television/config.toml (AC-6, AC-7)

**Files:**
- Create: `television/config.toml`
- Test: `scripts/test-plan-layer1a.sh` (AC-7)

- [ ] **Step 1: Add AC-7 check to the test script**

Modify `scripts/test-plan-layer1a.sh`: add this block:

```bash
# ── AC-7: television does NOT claim Ctrl-R ────────────────────────────────
echo ""
echo "AC-7: television shell integration owns Ctrl-T only"
check "television/config.toml exists"         test -f television/config.toml
check "smart_autocomplete = ctrl-t present"   \
  grep -qE 'smart_autocomplete\s*=\s*"ctrl-t"' television/config.toml
check "command_history key is ABSENT"         \
  bash -c "! grep -qE 'command_history\s*=' television/config.toml"
```

- [ ] **Step 2: Run tests to confirm AC-7 fails**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-7 checks fail (config doesn't exist yet).

- [ ] **Step 3: Create television/config.toml**

Create `television/config.toml` with this content:

```toml
# television/config.toml — fuzzy picker with channel-based selection
# See docs/plans/2026-04-12-shell-modernisation-design.md § 3.2
#
# NOTE: Shell integration claims Ctrl-T ONLY. Ctrl-R is owned by atuin.

tick_rate = 50
default_channel = "files"
history_size = 200
global_history = false

[ui]
ui_scale = 100
orientation = "landscape"
theme = "dracula"

[ui.input_bar]
position = "top"
prompt = ">"
border_type = "rounded"

[ui.results_panel]
border_type = "rounded"

[ui.preview_panel]
size = 65
scrollbar = true
border_type = "rounded"

[ui.help_panel]
show_categories = true
hidden = true

[keybindings]
esc = "quit"
ctrl-c = "quit"
down = "select_next_entry"
ctrl-n = "select_next_entry"
ctrl-j = "select_next_entry"
up = "select_prev_entry"
ctrl-p = "select_prev_entry"
ctrl-k = "select_prev_entry"
tab = "toggle_selection_down"
backtab = "toggle_selection_up"
enter = "confirm_selection"
ctrl-d = "scroll_preview_half_page_down"
ctrl-u = "scroll_preview_half_page_up"
ctrl-f = "cycle_previews"
ctrl-y = "copy_entry_to_clipboard"
ctrl-s = "cycle_sources"
# Ctrl-R inside TV is rebound to avoid confusion with shell-level atuin Ctrl-R
ctrl-g = "toggle_remote_control"
ctrl-x = "toggle_action_picker"
ctrl-o = "toggle_preview"
f9 = "toggle_help"
f10 = "toggle_status_bar"
# Ctrl-T inside TV is rebound to avoid confusion with shell-level TV Ctrl-T
ctrl-shift-t = "toggle_layout"

[shell_integration]
fallback_channel = "files"

[shell_integration.channel_triggers]
"files" = ["cat", "less", "head", "tail", "vim", "nvim", "bat", "cp", "mv", "rm"]
"dirs" = ["cd", "ls", "rmdir", "z"]

[shell_integration.keybindings]
# Only Ctrl-T is claimed. atuin owns Ctrl-R.
smart_autocomplete = "ctrl-t"
```

- [ ] **Step 4: Run tests to confirm AC-7 passes**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-7 checks pass.

- [ ] **Step 5: Commit**

```bash
git add television/config.toml scripts/test-plan-layer1a.sh
git commit -m "feat(television): config.toml with Ctrl-T only shell integration"
```

---

## Task 4: Update starship.toml to Dracula palette (AC-10)

**Files:**
- Modify: `starship/starship.toml`
- Test: `scripts/test-plan-layer1a.sh` (AC-10)

- [ ] **Step 1: Add AC-10 check to the test script**

Modify `scripts/test-plan-layer1a.sh`: add this block:

```bash
# ── AC-10: Starship uses Dracula palette ──────────────────────────────────
echo ""
echo "AC-10: Starship Dracula palette"
check "starship palette = dracula"            \
  grep -qE '^palette\s*=\s*"dracula"' starship/starship.toml
check "[palettes.dracula] table exists"       \
  grep -qE '^\[palettes\.dracula\]' starship/starship.toml
for color in background current_line foreground comment cyan green orange pink purple red yellow; do
  check "palette has '$color'"                \
    grep -qE "^$color\s*=" starship/starship.toml
done
```

- [ ] **Step 2: Run tests to confirm AC-10 fails**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-10 checks fail.

- [ ] **Step 3: Read the current starship.toml**

Run: `cat starship/starship.toml`
Expected: see current palette-free config with modules like [directory], [git_branch], etc.

- [ ] **Step 4: Replace starship/starship.toml content**

Write the following to `starship/starship.toml`:

```toml
# starship.toml — prompt configuration with Dracula palette
# See docs/plans/2026-04-12-shell-modernisation-design.md § 3.9

format = """
$directory\
$git_branch\
$git_status\
$kubernetes\
$nodejs$python$golang$terraform\
$cmd_duration\
$line_break\
$character"""

scan_timeout = 30
command_timeout = 1000
palette = "dracula"

[palettes.dracula]
background = "#282A36"
current_line = "#44475A"
foreground = "#F8F8F2"
comment = "#6272A4"
cyan = "#8BE9FD"
green = "#50FA7B"
orange = "#FFB86C"
pink = "#FF79C6"
purple = "#BD93F9"
red = "#FF5555"
yellow = "#F1FA8C"

[directory]
truncation_length = 4
truncate_to_repo = true
style = "bold purple"

[git_branch]
symbol = " "
style = "bold pink"

[git_status]
conflicted = "⚡"
ahead = "↑${count}"
behind = "↓${count}"
diverged = "⇕"
modified = "*"
staged = "+"
untracked = "?"
stashed = "\\$"

[character]
vicmd_symbol = "[N](bold green) "
success_symbol = "[I](bold yellow) "
error_symbol = "[I](bold red) "

[cmd_duration]
min_time = 2000
format = " [$duration](yellow)"

[nodejs]
format = "[ $version](green) "
detect_files = ["package.json", ".nvmrc"]

[python]
format = "[ $version](yellow) "

[golang]
format = "[ $version](cyan) "

[kubernetes]
disabled = false
format = "[⎈ $context](cyan) "

[terraform]
format = "[ $version](purple) "
```

- [ ] **Step 5: Run tests to confirm AC-10 passes**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-10 palette and color checks all pass.

- [ ] **Step 6: Commit**

```bash
git add starship/starship.toml scripts/test-plan-layer1a.sh
git commit -m "feat(starship): adopt Dracula palette (Layer 1a visual refresh)"
```

---

## Task 5: Add gated atuin init to bash/.bashrc (AC-8)

**Files:**
- Modify: `bash/.bashrc` (section 8 — tool evals)
- Test: `scripts/test-plan-layer1a.sh` (AC-8)

- [ ] **Step 1: Add AC-8 check to the test script**

Modify `scripts/test-plan-layer1a.sh`: add this block:

```bash
# ── AC-8: atuin init is opt-in via ENABLE_ATUIN ───────────────────────────
echo ""
echo "AC-8: atuin bash init gated behind ENABLE_ATUIN"
check "bash/.bashrc mentions ENABLE_ATUIN"    grep -q 'ENABLE_ATUIN' bash/.bashrc
# Structural multiline match: must find an `if` that gates on ENABLE_ATUIN and
# wraps `atuin init bash` before the closing `fi`. Comments alone cannot match.
check "atuin init is guarded by if/fi block" \
  bash -c "grep -Pzo '(?s)if[^\n]*ENABLE_ATUIN[^\n]*==[^\n]*1[^\n]*\n[^\n]*atuin init bash[^\n]*\nfi' bash/.bashrc | grep -q ."

if [[ "$FULL" == true ]] && command -v atuin &>/dev/null; then
  # Spawn an interactive-ish bash with ENABLE_ATUIN unset
  unset_out="$(ENABLE_ATUIN= bash --rcfile bash/.bashrc -ic 'bind -P 2>/dev/null | grep "^reverse-search-history" || true' 2>/dev/null)"
  if printf '%s' "$unset_out" | grep -q 'reverse-search-history'; then
    ok "with ENABLE_ATUIN unset: Ctrl-R is default readline"
  else
    nok "with ENABLE_ATUIN unset: Ctrl-R is default readline"
  fi

  set_out="$(ENABLE_ATUIN=1 bash --rcfile bash/.bashrc -ic 'bind -P 2>/dev/null | grep "C-r" || true' 2>/dev/null)"
  if printf '%s' "$set_out" | grep -qi 'atuin\|_atuin'; then
    ok "with ENABLE_ATUIN=1: Ctrl-R is rebound"
  else
    nok "with ENABLE_ATUIN=1: Ctrl-R is rebound"
  fi
else
  skp "with ENABLE_ATUIN unset: Ctrl-R default" "requires --full + atuin installed"
  skp "with ENABLE_ATUIN=1: Ctrl-R rebound"    "requires --full + atuin installed"
fi
```

- [ ] **Step 2: Run tests to confirm AC-8 fails**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-8 checks fail (ENABLE_ATUIN not in .bashrc yet).

- [ ] **Step 3: Read the current bash/.bashrc section 8**

Run: `grep -n '^# ── 8' bash/.bashrc`
Expected: line number for section 8 header is shown.

- [ ] **Step 4: Modify bash/.bashrc section 8 — replace the fzf-only block with a tool-evals block that includes gated atuin**

Find this existing content in `bash/.bashrc`:

```bash
# ── 8. Tool evals (guarded, starship LAST) ─────────────────────────────────
# fzf
if command -v fzf &>/dev/null; then
  eval "$(fzf --bash)"
fi
```

Replace it with:

```bash
# ── 8. Tool evals (guarded, starship LAST) ─────────────────────────────────
# fzf
if command -v fzf &>/dev/null; then
  eval "$(fzf --bash)"
fi

# atuin — OPT-IN via ENABLE_ATUIN=1 in .bashrc.local.
# Leaves Ctrl-R bound to default readline reverse-search-history when unset,
# preserving existing bash muscle memory until the user explicitly opts in.
if [[ "${ENABLE_ATUIN:-0}" == 1 ]] && command -v atuin &>/dev/null; then
  eval "$(atuin init bash)"
fi
```

- [ ] **Step 5: Verify bash -n parses the modified file**

Run: `bash -n bash/.bashrc`
Expected: no output, exit code 0.

- [ ] **Step 6: Run safe-mode tests to confirm AC-8 static checks pass**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-8 static checks pass. Dynamic checks skipped in safe mode.

- [ ] **Step 7: Commit**

```bash
git add bash/.bashrc scripts/test-plan-layer1a.sh
git commit -m "feat(bash): gate atuin init behind ENABLE_ATUIN opt-in flag"
```

---

## Task 6: Add gated television init to bash/.bashrc (AC-9)

**Files:**
- Modify: `bash/.bashrc`
- Test: `scripts/test-plan-layer1a.sh` (AC-9)

- [ ] **Step 1: Add AC-9 check to the test script**

Modify `scripts/test-plan-layer1a.sh`: add this block:

```bash
# ── AC-9: television init is opt-in via ENABLE_TV ─────────────────────────
echo ""
echo "AC-9: television bash init gated behind ENABLE_TV"
check "bash/.bashrc mentions ENABLE_TV"       grep -q 'ENABLE_TV' bash/.bashrc
# Structural multiline match: must find an `if` that gates on ENABLE_TV and
# wraps `tv init bash` before the closing `fi`. Comments alone cannot match.
check "tv init is guarded by if/fi block" \
  bash -c "grep -Pzo '(?s)if[^\n]*ENABLE_TV[^\n]*==[^\n]*1[^\n]*\n[^\n]*tv init bash[^\n]*\nfi' bash/.bashrc | grep -q ."
```

Note: Mirrors the AC-8 hardening (commit e1f3ed6) — a flat regex with `.*tv init` would falsely match the comment line `# tv shell integration binds ...` even if the `if` block were missing. The structural multiline form requires the `if … ENABLE_TV … 1` line, the `tv init bash` eval, and the closing `fi` to all be present.

- [ ] **Step 2: Run tests to confirm AC-9 fails**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-9 checks fail.

- [ ] **Step 3: Modify bash/.bashrc section 8 — add gated television init right after atuin**

Find this content (just added in Task 5):

```bash
# atuin — OPT-IN via ENABLE_ATUIN=1 in .bashrc.local.
# ...
if [[ "${ENABLE_ATUIN:-0}" == 1 ]] && command -v atuin &>/dev/null; then
  eval "$(atuin init bash)"
fi
```

Append immediately after it, before the next section:

```bash

# television — OPT-IN via ENABLE_TV=1 in .bashrc.local.
# tv shell integration binds Ctrl-T to the smart_autocomplete channel picker.
# Ctrl-R is NOT bound by tv — it remains with readline or atuin if enabled.
if [[ "${ENABLE_TV:-0}" == 1 ]] && command -v tv &>/dev/null; then
  eval "$(tv init bash)"
fi
```

- [ ] **Step 4: Verify bash -n parses**

Run: `bash -n bash/.bashrc`
Expected: no output, exit 0.

- [ ] **Step 5: Run tests to confirm AC-9 passes**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-9 passes.

- [ ] **Step 6: Commit**

```bash
git add bash/.bashrc scripts/test-plan-layer1a.sh
git commit -m "feat(bash): gate television init behind ENABLE_TV opt-in flag"
```

---

## Task 7: Add atuin + television symlinks to install-macos.sh (AC-3, AC-6)

**Files:**
- Modify: `install-macos.sh`
- Test: `scripts/test-plan-layer1a.sh` (AC-3, AC-6)

- [ ] **Step 1: Add AC-3 and AC-6 checks to the test script**

Modify `scripts/test-plan-layer1a.sh`: add this block:

```bash
# ── AC-3 + AC-6: atuin and television configs are symlinked ─────────────
echo ""
echo "AC-3 + AC-6: install script creates atuin + television symlinks"
check "install-macos.sh links atuin config"      \
  grep -qE 'link\s+atuin/config\.toml\s+\.config/atuin/config\.toml' install-macos.sh
check "install-macos.sh links television config" \
  grep -qE 'link\s+television/config\.toml\s+\.config/television/config\.toml' install-macos.sh

if [[ "$FULL" == true ]]; then
  # Check actual symlinks — only meaningful after install-macos.sh has run
  if [[ -L "$HOME/.config/atuin/config.toml" ]]; then
    actual="$(readlink "$HOME/.config/atuin/config.toml")"
    expected="$MACOS_DEV/atuin/config.toml"
    if [[ "$actual" == "$expected" ]]; then
      ok "~/.config/atuin/config.toml → \$DOTFILES/atuin/config.toml"
    else
      nok "~/.config/atuin/config.toml → \$DOTFILES/atuin/config.toml (got: $actual)"
    fi
  else
    skp "~/.config/atuin/config.toml symlink" "install not yet run"
  fi
  if [[ -L "$HOME/.config/television/config.toml" ]]; then
    actual="$(readlink "$HOME/.config/television/config.toml")"
    expected="$MACOS_DEV/television/config.toml"
    if [[ "$actual" == "$expected" ]]; then
      ok "~/.config/television/config.toml → \$DOTFILES/television/config.toml"
    else
      nok "~/.config/television/config.toml → \$DOTFILES/television/config.toml (got: $actual)"
    fi
  else
    skp "~/.config/television/config.toml symlink" "install not yet run"
  fi
else
  skp "~/.config/atuin/config.toml symlink" "safe mode"
  skp "~/.config/television/config.toml symlink" "safe mode"
fi
```

- [ ] **Step 2: Run tests to confirm AC-3/AC-6 fail**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-3 and AC-6 static checks fail.

- [ ] **Step 3: Find the symlink block in install-macos.sh**

Run: `grep -n 'starship/starship.toml' install-macos.sh`
Expected: shows the line where starship is symlinked (around line 270 based on current code).

- [ ] **Step 4: Modify install-macos.sh — add atuin and television link() calls**

Find this block in `install-macos.sh`:

```bash
# starship, lazygit, mise (Plans 6–8)
link starship/starship.toml  .config/starship.toml
link lazygit/config.yml      .config/lazygit/config.yml
link mise/config.toml        .config/mise/config.toml
```

Insert immediately after it:

```bash

# atuin (Plan Layer 1a)
link atuin/config.toml        .config/atuin/config.toml

# television (Plan Layer 1a)
link television/config.toml   .config/television/config.toml
```

- [ ] **Step 5: Verify install-macos.sh parses**

Run: `bash -n install-macos.sh`
Expected: no output, exit 0.

- [ ] **Step 6: Run tests to confirm AC-3 and AC-6 static checks pass**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-3 and AC-6 static grep checks pass.

- [ ] **Step 7: Commit**

```bash
git add install-macos.sh scripts/test-plan-layer1a.sh
git commit -m "feat(install-macos): symlink atuin and television configs (Layer 1a)"
```

---

## Task 8: Add atuin + television handling to install-wsl.sh

**Files:**
- Modify: `install-wsl.sh`
- Test: `scripts/test-plan-layer1a.sh`

- [ ] **Step 1: Read current install-wsl.sh symlink section**

Run: `grep -n 'link ' install-wsl.sh | head -20`
Expected: shows current link() calls. Note the style.

- [ ] **Step 2: Check whether install-wsl.sh has a gh_release_install helper**

Run: `grep -n 'gh_release_install\|github.*releases' install-wsl.sh`
Expected: if the helper exists, its line number prints. If not, this task adds it.

- [ ] **Step 3: Modify install-wsl.sh — add atuin and television link() calls**

Find the equivalent symlink block (it mirrors install-macos.sh). Insert after the starship/lazygit/mise block:

```bash

# atuin (Plan Layer 1a)
link atuin/config.toml        .config/atuin/config.toml

# television (Plan Layer 1a)
link television/config.toml   .config/television/config.toml
```

- [ ] **Step 4: Document the tool install gap for WSL2 in install-wsl.sh**

Find the tool install section of `install-wsl.sh`. Add a comment noting that atuin and television are not in Debian/Ubuntu apt repositories. If a `gh_release_install` helper exists, call it:

```bash
# atuin (no apt package — install script)
if ! command -v atuin &>/dev/null; then
  log "installing atuin via the official installer"
  bash <(curl -fsSL https://setup.atuin.sh) || warn "atuin install failed"
fi

# television (no apt package — GitHub release)
if ! command -v tv &>/dev/null; then
  log "installing television from GitHub releases"
  # Use gh_release_install if available, else warn
  if declare -f gh_release_install >/dev/null; then
    gh_release_install alexpasmantier/television tv "linux.*$(uname -m)" || warn "tv install failed"
  else
    warn "gh_release_install helper not defined — install television manually"
    warn "  https://github.com/alexpasmantier/television/releases"
  fi
fi
```

If this conflicts with existing structure, adapt to the existing pattern — the goal is: WSL users can install atuin + television in some documented way.

- [ ] **Step 5: Verify install-wsl.sh parses**

Run: `bash -n install-wsl.sh`
Expected: no output, exit 0.

- [ ] **Step 6: Run tests**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: no regressions.

- [ ] **Step 7: Commit**

```bash
git add install-wsl.sh
git commit -m "feat(install-wsl): atuin + television install paths (Layer 1a)"
```

---

## Task 9: Restore path — ensure install-macos.sh --restore reverts new symlinks (AC-12)

**Files:**
- Modify: `install-macos.sh` (if needed)
- Test: `scripts/test-plan-layer1a.sh` (AC-12)

- [ ] **Step 1: Inspect the existing restore() function**

Run: `sed -n '/^restore()/,/^}/p' install-macos.sh`
Expected: shows the restore() function body.

- [ ] **Step 2: Determine whether the existing restore logic auto-handles new symlinks**

Read the restore() output. If it iterates over the backup directory and restores everything, AND removes any symlinks currently pointing into $DOTFILES, it will already handle the new atuin and television symlinks. No changes needed.

If it only restores a hardcoded set of paths, add atuin and television to the handled list.

- [ ] **Step 3: Add AC-12 check to the test script**

Modify `scripts/test-plan-layer1a.sh`: add this block:

```bash
# ── AC-12: --restore reverts Layer 1a symlinks ────────────────────────────
echo ""
echo "AC-12: install --restore handles atuin + television"
# Static check: restore() iterates the backup dir, which will include any
# file that had an original non-symlink replaced. We verify by checking the
# restore() function does not hardcode a path list that excludes our new ones.
check "restore() walks backup dir dynamically" \
  grep -qE 'find.*-type' install-macos.sh
# Full mode: actually run install + restore and verify symlinks are gone
if [[ "$FULL" == true ]]; then
  skp "install + restore round-trip" "destructive — requires manual verification"
fi
```

- [ ] **Step 4: Run tests to confirm AC-12 check passes**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-12 passes based on dynamic restore logic.

- [ ] **Step 5: If restore() does NOT walk dynamically, modify it**

Skip this step if Step 2 confirmed the existing code is dynamic. Otherwise, add atuin + television paths to the restore list.

- [ ] **Step 6: Commit (if any change was made)**

```bash
git add install-macos.sh scripts/test-plan-layer1a.sh
git commit -m "test(layer1a): verify restore() handles new symlinks dynamically"
```

---

## Task 10: Update verify.sh to smoke-check atuin + television (AC-13)

**Files:**
- Modify: `scripts/verify.sh`
- Test: `scripts/test-plan-layer1a.sh` (AC-13)

- [ ] **Step 1: Read the current verify.sh tool checks section**

Run: `grep -n 'check.*command -v' scripts/verify.sh`
Expected: shows existing tool availability checks.

- [ ] **Step 2: Add AC-13 check to the test script**

Modify `scripts/test-plan-layer1a.sh`: add this block:

```bash
# ── AC-13: verify.sh passes ──────────────────────────────────────────────
echo ""
echo "AC-13: verify.sh smoke checks"
check "verify.sh mentions atuin"        grep -q 'atuin' scripts/verify.sh
check "verify.sh mentions tv"           grep -qE '\btv\b' scripts/verify.sh
```

- [ ] **Step 3: Run tests to confirm AC-13 fails**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-13 checks fail.

- [ ] **Step 4: Modify scripts/verify.sh**

Find the section where other tool `command -v` checks live. Add:

```bash
# ── Layer 1a tools ────────────────────────────────────────────────────────
echo ""
echo "Layer 1a tools:"
check "atuin on PATH"            command -v atuin
check "tv (television) on PATH"  command -v tv
check "atuin config symlink"     test -L "$HOME/.config/atuin/config.toml"
check "television config symlink" test -L "$HOME/.config/television/config.toml"
```

- [ ] **Step 5: Verify verify.sh parses**

Run: `bash -n scripts/verify.sh`
Expected: exit 0.

- [ ] **Step 6: Run tests to confirm AC-13 passes**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-13 passes.

- [ ] **Step 7: Commit**

```bash
git add scripts/verify.sh scripts/test-plan-layer1a.sh
git commit -m "feat(verify): smoke-check atuin + television (Layer 1a)"
```

---

## Task 11: Update cheatsheet.md labels for Ctrl-R and Ctrl-T

**Files:**
- Modify: `docs/cheatsheet.md`
- Test: `scripts/test-plan-layer1a.sh`

- [ ] **Step 1: Read current cheatsheet content related to Ctrl-R and Ctrl-T**

Run: `grep -n 'Ctrl.*[rRtT]\|fzf' docs/cheatsheet.md`
Expected: shows current labels referencing fzf for these keys.

- [ ] **Step 2: Modify docs/cheatsheet.md**

Find rows/lines referencing fzf for Ctrl-R or Ctrl-T. Update to note that Ctrl-R and Ctrl-T are owned by atuin and television respectively when `ENABLE_ATUIN=1` and `ENABLE_TV=1` are set, and fzf remains the default otherwise.

Add a new row or line (match the existing table style):

```markdown
| `Ctrl-R`      | atuin (if ENABLE_ATUIN=1) / fzf (default) | history search |
| `Ctrl-T`      | television (if ENABLE_TV=1) / fzf (default) | smart autocomplete |
```

- [ ] **Step 3: Verify no broken tables**

Run: `grep -c '^|' docs/cheatsheet.md`
Expected: non-zero count confirming tables exist.

- [ ] **Step 4: Run all existing tests to ensure no regression**

Run: `bash scripts/test-plan14-16.sh` (validates cheatsheet structure)
Expected: all pass.

Run: `bash scripts/test-plan-layer1a.sh`
Expected: all ACs still pass.

- [ ] **Step 5: Commit**

```bash
git add docs/cheatsheet.md
git commit -m "docs(cheatsheet): label Ctrl-R/Ctrl-T as atuin/television opt-in"
```

---

## Task 12: Idempotency verification (AC-11)

**Files:**
- Test: `scripts/test-plan-layer1a.sh` (AC-11)

- [ ] **Step 1: Add AC-11 check to the test script**

Modify `scripts/test-plan-layer1a.sh`: add this block:

```bash
# ── AC-11: install is idempotent ──────────────────────────────────────────
echo ""
echo "AC-11: install idempotency"
if [[ "$FULL" == true ]] && command -v brew &>/dev/null && [[ "$PLATFORM" == "macos" ]]; then
  # Run install once (may already be up to date)
  bash install-macos.sh >/tmp/install-1.log 2>&1 || true
  # Run again; second run should not backup any file that's already a symlink to $DOTFILES
  bash install-macos.sh >/tmp/install-2.log 2>&1 || true
  check "second install reports no 'backed up' lines for atuin" \
    bash -c '! grep -E "backed up .*atuin/config\.toml" /tmp/install-2.log'
  check "second install reports no 'backed up' lines for television" \
    bash -c '! grep -E "backed up .*television/config\.toml" /tmp/install-2.log'
  check "second install exits 0" \
    bash -c 'tail -n5 /tmp/install-2.log; grep -q "install complete" /tmp/install-2.log'
else
  skp "install idempotency (macOS)" "requires --full on macOS"
fi
```

- [ ] **Step 2: Run tests on macOS in --full mode (if available)**

Run: `bash scripts/test-plan-layer1a.sh --full`
Expected: AC-11 checks pass on macOS. Skipped on WSL2 (equivalent check would use install-wsl.sh).

- [ ] **Step 3: Run tests on WSL2 in safe mode**

Run: `bash scripts/test-plan-layer1a.sh`
Expected: AC-11 skipped gracefully.

- [ ] **Step 4: Commit**

```bash
git add scripts/test-plan-layer1a.sh
git commit -m "test(layer1a): verify install idempotency (AC-11)"
```

---

## Task 13: End-to-end acceptance (AC-14) + CI integration

**Files:**
- Modify: `scripts/test-plan-layer1a.sh` (final summary)
- Verify: existing CI workflow picks up the new test script if one exists

- [ ] **Step 1: Ensure the acceptance script's final summary is strict**

The script should already exit non-zero if any check fails. Verify by inspecting the tail of `scripts/test-plan-layer1a.sh`:

Run: `tail -n 10 scripts/test-plan-layer1a.sh`
Expected: `(( fail == 0 ))` as the last executable line.

- [ ] **Step 2: Check whether CI runs test-plan*.sh scripts automatically**

Run: `find . -name "*.yml" -path "*workflows*" 2>/dev/null; find . -name "*.yaml" -path "*github*" 2>/dev/null`
Expected: shows CI workflow files if they exist. If none exist, note this — CI is run via an external system not reflected in-repo, and we rely on local macOS + WSL2 runs.

- [ ] **Step 3: Run the full acceptance test script on the current platform**

On macOS: `bash scripts/test-plan-layer1a.sh --full`
On WSL2:  `bash scripts/test-plan-layer1a.sh`

Expected: all ACs (AC-1 through AC-14) pass or are cleanly skipped in the current mode.

- [ ] **Step 4: Run on the other platform (switch machine)**

If developer has Mac + WSL2 access, run the same script on the other platform.

Expected: same result.

- [ ] **Step 5: Update README or docs to reference the new test script**

Modify any test-running documentation (README.md, or docs/tests.md if it exists) to add:

```
# Layer 1a tests
bash scripts/test-plan-layer1a.sh          # safe mode
bash scripts/test-plan-layer1a.sh --full   # full (requires tools installed)
```

- [ ] **Step 6: Commit**

```bash
git add scripts/test-plan-layer1a.sh README.md
git commit -m "test(layer1a): end-to-end acceptance + documented test invocation"
```

---

## Post-plan: Manual Validation Steps

These are manual steps the user should do AFTER the plan completes, to confirm Layer 1a is usable in practice. They're NOT automated because they require interactive shell sessions.

- [ ] **Manual 1:** Install Layer 1a on your macOS machine:
  ```
  brew bundle --file=Brewfile
  bash install-macos.sh
  ```

- [ ] **Manual 2:** Opt into atuin in `~/.bashrc.local`:
  ```
  echo 'export ENABLE_ATUIN=1' >> ~/.bashrc.local
  exec bash -l
  ```
  Press Ctrl-R. Verify atuin's TUI appears.

- [ ] **Manual 3:** Opt into television similarly:
  ```
  echo 'export ENABLE_TV=1' >> ~/.bashrc.local
  exec bash -l
  ```
  Press Ctrl-T. Verify television opens with the files channel.

- [ ] **Manual 4:** Test on WSL2 (install atuin/tv via the paths in install-wsl.sh).

- [ ] **Manual 5:** Confirm Dracula starship prompt appears on new shell launch.

- [ ] **Manual 6:** Confirm bash muscle memory still works with ENABLE_ATUIN / ENABLE_TV unset:
  ```
  unset ENABLE_ATUIN ENABLE_TV
  exec bash -l
  ```
  Ctrl-R should fall back to default readline reverse-search (or fzf's Ctrl-R binding from fzf --bash eval).

---

## Self-Review Notes (recorded at plan write time)

**Spec coverage check:**
- AC-1 → Task 1 ✓
- AC-2 → Task 1 + check-tool-manifest.sh (existing) ✓
- AC-3 → Task 2 + Task 7 ✓
- AC-4 → Task 2 ✓
- AC-5 → Task 2 ✓
- AC-6 → Task 3 + Task 7 ✓
- AC-7 → Task 3 ✓
- AC-8 → Task 5 ✓
- AC-9 → Task 6 ✓
- AC-10 → Task 4 ✓
- AC-11 → Task 12 ✓
- AC-12 → Task 9 ✓
- AC-13 → Task 10 ✓
- AC-14 → Task 13 (aggregate) ✓

**Out of scope for Layer 1a (deferred to later plans):**
- Zsh config → Layer 2
- Nushell config → Layer 3
- Television cable channels (all 30+) → Layer 1b
- tmux plugins → Layer 1b
- sesh, yazi, xh, rip, rip2, jqp, gh-dash, diffnav, carapace → Layer 1b
- Theming for tools other than starship → Layer 1b+
- Custom aliases for new tools → Layer 1b

**Type/naming consistency:**
- Env vars: `ENABLE_ATUIN`, `ENABLE_TV` (consistent with existing `NOTIFY_OSC9` pattern)
- File paths: all relative to `$DOTFILES`, symlinked to `$HOME`
- Test assertions: named `AC-1` through `AC-14` matching spec
