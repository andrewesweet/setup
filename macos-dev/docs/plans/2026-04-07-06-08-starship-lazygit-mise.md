# Plans 6–8: Starship, Lazygit, Mise — single-file configs

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create configuration files for starship (prompt), lazygit (git TUI), and mise (version manager), add symlink calls to both install scripts, and create a combined smoke test wired into CI. These three tools are independent single-file configs batched into one plan for efficiency.

**Architecture:** Three config files in `starship/`, `lazygit/`, `mise/`, modifications to both install scripts (adding 3 `link()` calls each), one combined smoke test in `scripts/`, and a CI workflow update.

**Tech Stack:** TOML (starship, mise), YAML (lazygit)

**Design references:**
- `docs/design/terminal.md` — § Starship Configuration
- `docs/design/git.md` — § lazygit configuration, § Theme consistency
- `docs/design/languages.md` — § mise — version management

**Design amendments:** None. This plan implements the specs verbatim.

**Out of scope for this plan:**
- tmux (completed in Plan 5)
- opencode (Plan 9)
- nvim (Plan 10)
- prek .pre-commit-config.yaml (Plan 11)

**Prerequisites:**
- Plans 1–5 (Foundation, CI, Bash, Git, Kitty, tmux) are merged to `tool-verification-script`
- Both install scripts have `link()` helper and existing link() calls from Plans 2–5

**Branch strategy:** New worktree on branch `plan6-8-configs` off `tool-verification-script`. Push to remote, merge when CI is green.

---

## File Structure

Files created or modified by this plan (paths relative to `macos-dev/`):

| File | Action | Responsibility |
|------|--------|---------------|
| `starship/starship.toml` | Create | Starship prompt configuration |
| `lazygit/config.yml` | Create | Lazygit TUI configuration |
| `mise/config.toml` | Create | Mise version manager global config |
| `install-macos.sh` | Modify | Add 3 `link()` calls |
| `install-wsl.sh` | Modify | Add 3 `link()` calls |
| `scripts/test-plan6-8.sh` | Create | Combined smoke tests for all three configs |
| `.github/workflows/verify.yml` | Modify | Add test-plan6-8.sh to lint and macos-verify jobs |

---

## Task 1: Create `starship/starship.toml`

**Files:**
- Create: `macos-dev/starship/starship.toml`

- [ ] **Step 1: Create the starship directory**

```bash
mkdir -p macos-dev/starship
```

- [ ] **Step 2: Write starship.toml**

Write exactly this content to `macos-dev/starship/starship.toml`:

```toml
# starship.toml — prompt configuration
# See docs/design/terminal.md for the specification.

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

[directory]
truncation_length = 4
truncate_to_repo  = true
style             = "bold blue"

[git_branch]
symbol = " "
style  = "bold purple"

[git_status]
conflicted = "⚡"
ahead      = "↑${count}"
behind     = "↓${count}"
diverged   = "⇕"
modified   = "*"
staged     = "+"
untracked  = "?"
stashed    = "$"

[character]
vicmd_symbol   = "[N](bold green) "
success_symbol = "[I](bold yellow) "
error_symbol   = "[I](bold red) "

[cmd_duration]
min_time = 2000
format   = " [$duration](yellow)"

[nodejs]
format = "[ $version](green) "
detect_files = ["package.json", ".nvmrc"]

[python]
format = "[ $version](yellow) "

[golang]
format = "[ $version](cyan) "

[kubernetes]
disabled = false
format = "[⎈ $context](blue) "

[terraform]
format = "[ $version](purple) "
```

- [ ] **Step 3: Verify**

Run: `grep -c '^\[' macos-dev/starship/starship.toml`
Expected: `10` (section headers: directory, git_branch, git_status, character, cmd_duration, nodejs, python, golang, kubernetes, terraform).

Run: `grep 'scan_timeout' macos-dev/starship/starship.toml`
Expected: Contains `30`.

Run: `grep 'vicmd_symbol' macos-dev/starship/starship.toml`
Expected: At least one match.

Run: `grep 'vimins_symbol' macos-dev/starship/starship.toml; echo "exit=$?"`
Expected: `exit=1` (vimins_symbol MUST NOT be present — not a valid Starship key).

- [ ] **Step 4: Commit**

```bash
git add macos-dev/starship/starship.toml
git commit -m "feat(starship): add starship.toml prompt configuration"
```

---

## Task 2: Create `lazygit/config.yml`

**Files:**
- Create: `macos-dev/lazygit/config.yml`

- [ ] **Step 1: Create the lazygit directory**

```bash
mkdir -p macos-dev/lazygit
```

- [ ] **Step 2: Write config.yml**

Write exactly this content to `macos-dev/lazygit/config.yml`:

```yaml
# config.yml — lazygit configuration
# See docs/design/git.md for the specification.

gui:
  theme:
    activeBorderColor:
      - '#89b4fa'
      - bold
    selectedLineBgColor:
      - '#313244'
  sidePanelWidth: 0.25
  expandFocusedSidePanel: true
  showFileTree: true
  nerdFontsVersion: "3"

git:
  paging:
    colorArg: always
    pager: delta --paging=never --syntax-theme='Monokai Extended'
  commit:
    signOff: false
  fetching:
    interval: 60

keybinding:
  universal:
    quit:            q
    return:          "<esc>"
    scrollUpMain:    k
    scrollDownMain:  j
    prevItem:        k
    nextItem:        j
    scrollLeft:      h
    scrollRight:     l
    nextTab:         "]"
    prevTab:         "["
    openRecentRepos: "<c-r>"
```

- [ ] **Step 3: Verify**

Run: `grep 'Monokai Extended' macos-dev/lazygit/config.yml`
Expected: At least one match (explicit syntax theme for delta).

Run: `grep 'nerdFontsVersion' macos-dev/lazygit/config.yml`
Expected: Contains `"3"`.

Run: `grep 'sidePanelWidth' macos-dev/lazygit/config.yml`
Expected: Contains `0.25`.

Run: `grep 'signOff' macos-dev/lazygit/config.yml`
Expected: Contains `false`.

Run: `grep 'interval' macos-dev/lazygit/config.yml`
Expected: Contains `60`.

Run: `grep -c 'scrollUpMain\|scrollDownMain\|prevItem\|nextItem\|scrollLeft\|scrollRight' macos-dev/lazygit/config.yml`
Expected: `6` (vi navigation keybindings).

- [ ] **Step 4: Commit**

```bash
git add macos-dev/lazygit/config.yml
git commit -m "feat(lazygit): add config.yml with delta paging and vim keybindings"
```

---

## Task 3: Create `mise/config.toml`

**Files:**
- Create: `macos-dev/mise/config.toml`

- [ ] **Step 1: Create the mise directory**

```bash
mkdir -p macos-dev/mise
```

- [ ] **Step 2: Write config.toml**

Write exactly this content to `macos-dev/mise/config.toml`:

```toml
# config.toml — mise global configuration
# See docs/design/languages.md for the specification.
#
# This is the global config installed to ~/.config/mise/config.toml.
# Per-project .mise.toml files override these versions.

[tools]
python = "3.13"
go     = "1.24"

[settings]
auto_install = false  # Interactive machines: false. CI: override to true.
```

- [ ] **Step 3: Verify**

Run: `grep 'python.*3.13' macos-dev/mise/config.toml`
Expected: At least one match.

Run: `grep 'go.*1.24' macos-dev/mise/config.toml`
Expected: At least one match.

Run: `grep 'auto_install.*false' macos-dev/mise/config.toml`
Expected: At least one match.

- [ ] **Step 4: Commit**

```bash
git add macos-dev/mise/config.toml
git commit -m "feat(mise): add global config.toml with python and go versions"
```

---

## Task 4: Add `link()` calls to install scripts

**Files:**
- Modify: `macos-dev/install-macos.sh`
- Modify: `macos-dev/install-wsl.sh`

- [ ] **Step 1: Modify install-macos.sh**

Find the last tmux link() call:
```
link tmux/.tmux.conf  .tmux.conf
```

Add after it:
```bash

# starship, lazygit, mise (Plans 6–8)
link starship/starship.toml  .config/starship.toml
link lazygit/config.yml      .config/lazygit/config.yml
link mise/config.toml        .config/mise/config.toml
```

- [ ] **Step 2: Syntax check install-macos.sh**

Run: `bash -n macos-dev/install-macos.sh`
Expected: No output, exit code 0.

- [ ] **Step 3: Verify the link calls are present**

Run: `grep -c 'link starship/\|link lazygit/\|link mise/' macos-dev/install-macos.sh`
Expected: `3`

- [ ] **Step 4: Modify install-wsl.sh**

Same addition as Step 1 but in `install-wsl.sh`. Find the last tmux link() call and add after it:

```bash

# starship, lazygit, mise (Plans 6–8)
link starship/starship.toml  .config/starship.toml
link lazygit/config.yml      .config/lazygit/config.yml
link mise/config.toml        .config/mise/config.toml
```

- [ ] **Step 5: Syntax check install-wsl.sh**

Run: `bash -n macos-dev/install-wsl.sh`
Expected: No output, exit code 0.

- [ ] **Step 6: Verify the link calls are present**

Run: `grep -c 'link starship/\|link lazygit/\|link mise/' macos-dev/install-wsl.sh`
Expected: `3`

- [ ] **Step 7: Commit**

```bash
git add macos-dev/install-macos.sh macos-dev/install-wsl.sh
git commit -m "feat(install): add link() calls for starship, lazygit, mise (Plans 6–8)"
```

---

## Task 5: Create `scripts/test-plan6-8.sh`

**Files:**
- Create: `macos-dev/scripts/test-plan6-8.sh`

- [ ] **Step 1: Write the test script**

Write exactly this content to `macos-dev/scripts/test-plan6-8.sh`:

```bash
#!/usr/bin/env bash
# test-plan6-8.sh — smoke tests for Plans 6–8 (starship, lazygit, mise)
#
# Validates:
#   - All three config files exist
#   - Starship prompt format, modules, and settings
#   - Lazygit theme, paging, keybindings
#   - Mise tool versions and settings
#   - Install scripts have correct link() mappings
#   - Plans 2–5 link() calls are preserved (regression)
#
# Usage: bash scripts/test-plan6-8.sh
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

echo "Plans 6–8: starship, lazygit, mise smoke tests"
echo ""

# ── File existence ─────────────────────────────────────────────────────────
echo "File existence:"
check "starship.toml exists"  test -f "$REPO_ROOT/starship/starship.toml"
check "lazygit config.yml exists"  test -f "$REPO_ROOT/lazygit/config.yml"
check "mise config.toml exists"  test -f "$REPO_ROOT/mise/config.toml"

# ══════════════════════════════════════════════════════════════════════════
# STARSHIP
# ══════════════════════════════════════════════════════════════════════════

echo ""
echo "Starship — prompt format:"
check "format string present"         grep -q '^\$directory' "$REPO_ROOT/starship/starship.toml"
check "scan_timeout = 30"             grep -q 'scan_timeout.*30' "$REPO_ROOT/starship/starship.toml"

echo ""
echo "Starship — directory module:"
check "truncation_length = 4"         grep -q 'truncation_length.*4' "$REPO_ROOT/starship/starship.toml"
check "truncate_to_repo = true"       grep -q 'truncate_to_repo.*true' "$REPO_ROOT/starship/starship.toml"
check "directory style bold blue"     grep -q 'style.*bold blue' "$REPO_ROOT/starship/starship.toml"

echo ""
echo "Starship — git modules:"
check "git_branch symbol"             grep -qF 'symbol = " "' "$REPO_ROOT/starship/starship.toml"
check "git_branch style bold purple"  grep -q 'style.*bold purple' "$REPO_ROOT/starship/starship.toml"
check "git_status conflicted"         grep -qF 'conflicted = "⚡"' "$REPO_ROOT/starship/starship.toml"
check "git_status ahead"              grep -qF 'ahead      = "↑${count}"' "$REPO_ROOT/starship/starship.toml"
check "git_status behind"             grep -qF 'behind     = "↓${count}"' "$REPO_ROOT/starship/starship.toml"
check "git_status diverged"           grep -qF 'diverged   = "⇕"' "$REPO_ROOT/starship/starship.toml"
check "git_status modified"           grep -qF 'modified = "*"' "$REPO_ROOT/starship/starship.toml"
check "git_status staged"             grep -qF 'staged = "+"' "$REPO_ROOT/starship/starship.toml"
check "git_status untracked"          grep -qF 'untracked = "?"' "$REPO_ROOT/starship/starship.toml"
check "git_status stashed"            grep -qF 'stashed = "$"' "$REPO_ROOT/starship/starship.toml"

echo ""
echo "Starship — character module:"
check "vicmd_symbol N green"          grep -q 'vicmd_symbol.*N.*bold green' "$REPO_ROOT/starship/starship.toml"
check "success_symbol I yellow"       grep -q 'success_symbol.*I.*bold yellow' "$REPO_ROOT/starship/starship.toml"
check "error_symbol I red"            grep -q 'error_symbol.*I.*bold red' "$REPO_ROOT/starship/starship.toml"

# MUST NOT include vimins_symbol (not a valid Starship key)
if grep -q 'vimins_symbol' "$REPO_ROOT/starship/starship.toml"; then
  nok "vimins_symbol absent (invalid key)"
else
  ok "vimins_symbol absent (invalid key)"
fi

echo ""
echo "Starship — cmd_duration:"
check "min_time = 2000"               grep -q 'min_time.*2000' "$REPO_ROOT/starship/starship.toml"
check "duration format yellow"        grep -q 'format.*duration.*yellow' "$REPO_ROOT/starship/starship.toml"

echo ""
echo "Starship — language modules:"
check "nodejs format"                 grep -q '\[nodejs\]' "$REPO_ROOT/starship/starship.toml"
check "nodejs detect_files"           grep -q 'detect_files.*package.json' "$REPO_ROOT/starship/starship.toml"
check "python format"                 grep -q '\[python\]' "$REPO_ROOT/starship/starship.toml"
check "golang format"                 grep -q '\[golang\]' "$REPO_ROOT/starship/starship.toml"
check "kubernetes disabled false"     grep -q 'disabled.*false' "$REPO_ROOT/starship/starship.toml"
check "kubernetes format"             grep -q '\[kubernetes\]' "$REPO_ROOT/starship/starship.toml"
check "terraform format"              grep -q '\[terraform\]' "$REPO_ROOT/starship/starship.toml"

# Section count
check "10 TOML sections"             test "$(grep -c '^\[' "$REPO_ROOT/starship/starship.toml")" -eq 10

# ══════════════════════════════════════════════════════════════════════════
# LAZYGIT
# ══════════════════════════════════════════════════════════════════════════

echo ""
echo "Lazygit — theme:"
check "activeBorderColor #89b4fa"     grep -qF "'#89b4fa'" "$REPO_ROOT/lazygit/config.yml"
check "selectedLineBgColor #313244"   grep -qF "'#313244'" "$REPO_ROOT/lazygit/config.yml"

echo ""
echo "Lazygit — GUI settings:"
check "sidePanelWidth 0.25"           grep -q 'sidePanelWidth.*0.25' "$REPO_ROOT/lazygit/config.yml"
check "expandFocusedSidePanel true"   grep -q 'expandFocusedSidePanel.*true' "$REPO_ROOT/lazygit/config.yml"
check "showFileTree true"             grep -q 'showFileTree.*true' "$REPO_ROOT/lazygit/config.yml"
check "nerdFontsVersion 3"            grep -qF 'nerdFontsVersion: "3"' "$REPO_ROOT/lazygit/config.yml"

echo ""
echo "Lazygit — git paging:"
check "pager delta with Monokai"      grep -q "pager.*delta.*Monokai Extended" "$REPO_ROOT/lazygit/config.yml"
check "colorArg always"               grep -q 'colorArg.*always' "$REPO_ROOT/lazygit/config.yml"

echo ""
echo "Lazygit — git settings:"
check "signOff false"                 grep -q 'signOff.*false' "$REPO_ROOT/lazygit/config.yml"
check "fetching interval 60"          grep -q 'interval.*60' "$REPO_ROOT/lazygit/config.yml"

echo ""
echo "Lazygit — keybindings:"
check "quit = q"                      grep -q 'quit:.*q' "$REPO_ROOT/lazygit/config.yml"
check "return = esc"                  grep -q 'return:.*esc' "$REPO_ROOT/lazygit/config.yml"
check "scrollUpMain = k"              grep -q 'scrollUpMain:.*k' "$REPO_ROOT/lazygit/config.yml"
check "scrollDownMain = j"            grep -q 'scrollDownMain:.*j' "$REPO_ROOT/lazygit/config.yml"
check "prevItem = k"                  grep -q 'prevItem:.*k' "$REPO_ROOT/lazygit/config.yml"
check "nextItem = j"                  grep -q 'nextItem:.*j' "$REPO_ROOT/lazygit/config.yml"
check "scrollLeft = h"                grep -q 'scrollLeft:.*h' "$REPO_ROOT/lazygit/config.yml"
check "scrollRight = l"               grep -q 'scrollRight:.*l' "$REPO_ROOT/lazygit/config.yml"
check "nextTab = ]"                   grep -qF 'nextTab' "$REPO_ROOT/lazygit/config.yml"
check "prevTab = ["                   grep -qF 'prevTab' "$REPO_ROOT/lazygit/config.yml"
check "openRecentRepos = c-r"         grep -q 'openRecentRepos.*c-r' "$REPO_ROOT/lazygit/config.yml"

# ══════════════════════════════════════════════════════════════════════════
# MISE
# ══════════════════════════════════════════════════════════════════════════

echo ""
echo "Mise — tool versions:"
check "python = 3.13"                 grep -q 'python.*3.13' "$REPO_ROOT/mise/config.toml"
check "go = 1.24"                     grep -q 'go.*1.24' "$REPO_ROOT/mise/config.toml"

echo ""
echo "Mise — settings:"
check "auto_install = false"          grep -q 'auto_install.*false' "$REPO_ROOT/mise/config.toml"

# ══════════════════════════════════════════════════════════════════════════
# INSTALL SCRIPTS
# ══════════════════════════════════════════════════════════════════════════

echo ""
echo "Install scripts:"
check "macos: starship mapping"       grep -q 'link starship/starship.toml.*\.config/starship.toml' "$REPO_ROOT/install-macos.sh"
check "macos: lazygit mapping"        grep -q 'link lazygit/config.yml.*\.config/lazygit/config.yml' "$REPO_ROOT/install-macos.sh"
check "macos: mise mapping"           grep -q 'link mise/config.toml.*\.config/mise/config.toml' "$REPO_ROOT/install-macos.sh"
check "wsl: starship mapping"         grep -q 'link starship/starship.toml.*\.config/starship.toml' "$REPO_ROOT/install-wsl.sh"
check "wsl: lazygit mapping"          grep -q 'link lazygit/config.yml.*\.config/lazygit/config.yml' "$REPO_ROOT/install-wsl.sh"
check "wsl: mise mapping"             grep -q 'link mise/config.toml.*\.config/mise/config.toml' "$REPO_ROOT/install-wsl.sh"

# Regression: Plans 2–5 link() calls preserved
check "macos: bash links preserved"   test "$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: git links preserved"    test "$(grep -c 'link git/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "macos: kitty links preserved"  test "$(grep -c 'link kitty/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: tmux links preserved"   test "$(grep -c 'link tmux/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "wsl: bash links preserved"     test "$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: git links preserved"      test "$(grep -c 'link git/' "$REPO_ROOT/install-wsl.sh")" -eq 2
check "wsl: kitty links preserved"    test "$(grep -c 'link kitty/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: tmux links preserved"     test "$(grep -c 'link tmux/' "$REPO_ROOT/install-wsl.sh")" -eq 1

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Current count: 70 tests. Floor should be within ~10% of actual.
if (( total < 63 )); then
  echo "WARNING: only $total tests ran (expected >= 63). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x macos-dev/scripts/test-plan6-8.sh
```

- [ ] **Step 3: Syntax check**

Run: `bash -n macos-dev/scripts/test-plan6-8.sh`
Expected: No output, exit code 0.

- [ ] **Step 4: Run the test script**

Run: `bash macos-dev/scripts/test-plan6-8.sh`
Expected: All tests pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add macos-dev/scripts/test-plan6-8.sh
git commit -m "test(configs): add Plans 6–8 smoke tests for starship, lazygit, mise"
```

---

## Task 6: Wire test-plan6-8.sh into CI

**Files:**
- Modify: `.github/workflows/verify.yml`

- [ ] **Step 1: Add to lint job**

In the `lint` job, find:
```yaml
      - name: Plan 5 tmux config smoke tests
        run: bash macos-dev/scripts/test-plan5.sh
```

Add after it:
```yaml

      - name: Plans 6-8 starship/lazygit/mise config smoke tests
        run: bash macos-dev/scripts/test-plan6-8.sh
```

- [ ] **Step 2: Add to macos-verify job**

In the `macos-verify` job, find the existing `Plan 5 tmux config smoke tests` step and add after it:
```yaml

      - name: Plans 6-8 starship/lazygit/mise config smoke tests
        run: bash macos-dev/scripts/test-plan6-8.sh
```

- [ ] **Step 3: Verify**

Run: `grep -c 'test-plan6-8.sh' .github/workflows/verify.yml`
Expected: `2` (one in lint, one in macos-verify).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/verify.yml
git commit -m "ci: add Plans 6–8 smoke tests to lint and macos-verify jobs"
```

---

## Task 7: Final verification

- [ ] **Step 1: Run Plans 6–8 tests**

Run: `bash macos-dev/scripts/test-plan6-8.sh`
Expected: All tests pass, 0 failures.

- [ ] **Step 2: Run Plan 5 tests (regression)**

Run: `bash macos-dev/scripts/test-plan5.sh`
Expected: All tests pass.

- [ ] **Step 3: Run Plan 4 tests (regression)**

Run: `bash macos-dev/scripts/test-plan4.sh`
Expected: All tests pass.

- [ ] **Step 4: Run Plan 3 tests (regression)**

Run: `bash macos-dev/scripts/test-plan3.sh`
Expected: All tests pass.

- [ ] **Step 5: Run Plan 2 tests (regression)**

Run: `bash macos-dev/scripts/test-plan2.sh`
Expected: All tests pass.

- [ ] **Step 6: Run Plan 1 manifest check (regression)**

Run: `bash macos-dev/scripts/check-tool-manifest.sh`
Expected: Clean run, exit 0.

- [ ] **Step 7: Confirm all expected files exist**

```bash
ls -la macos-dev/starship/starship.toml
ls -la macos-dev/lazygit/config.yml
ls -la macos-dev/mise/config.toml
ls -la macos-dev/scripts/test-plan6-8.sh
```

Expected: All four files present.

- [ ] **Step 8: Confirm no unexpected changes**

```bash
git status
```

Expected: `nothing to commit, working tree clean`

- [ ] **Step 9: Push the branch**

```bash
git push -u origin plan6-8-configs
```

---

## Success criteria

Plans 6–8 are complete when:

1. `starship.toml` has all modules from terminal.md: format string, scan_timeout, directory, git_branch, git_status (8 indicators), character (3 symbols, NO vimins_symbol), cmd_duration, nodejs (with detect_files), python, golang, kubernetes (disabled=false), terraform
2. `lazygit/config.yml` has Catppuccin theme colors (#89b4fa, #313244), delta pager with explicit Monokai Extended, nerdFontsVersion 3, vim keybindings (hjkl + tabs + recent repos), signOff false, fetching interval 60
3. `mise/config.toml` has python 3.13, go 1.24, auto_install false
4. Both install scripts have 3 `link()` calls (starship, lazygit, mise) with correct `.config/` target paths
5. Plans 2–5 link() calls are preserved (4 bash + 2 git + 1 kitty + 1 tmux each)
6. `scripts/test-plan6-8.sh` passes with 0 failures
7. `test-plan6-8.sh` is wired into CI (both lint and macos-verify jobs)
8. Plans 1–5 regression checks pass
9. All commits are made with the specified messages
10. The branch is pushed to `origin`

Plans 6–8 do NOT attempt to:
- Configure opencode (Plan 9)
- Configure nvim (Plan 10)
- Set up prek hooks (Plan 11)
- Configure VS Code (Plan 12)

Plan 9 will add the opencode configuration.
