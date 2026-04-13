# Layer 1c Implementation Plan: ghq + ghorg (repo organisation)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopt a GOPATH-style `~/code/<host>/<org>/<repo>` checkout layout, enforced by ghq, with `ghorg` for bulk org cloning and shell helpers that make the layout frictionless. Ship an AGENTS.md convention so OpenCode and GitHub Copilot Coding Agent honour the layout too.

**Architecture:** Install ghq + ghorg via brew. Add `ghq.root = ~/code` to the tracked `git/.gitconfig`. Add three always-on shell functions (`repo`, `gclone`, `ghorg-gh`) plus an Alt-R readline binding for `repo`. Hard-abort install-wsl.sh if `$HOME` is under `/mnt/c/` (perf cliff). Ship a tracked AGENTS.md snippet plus an idempotent installer that appends it to `~/AGENTS.md` on user invocation.

**Tech Stack:** bash, brew, ghq, ghorg, fzf (already shipped), GNU coreutils.

**Spec reference:** `docs/plans/2026-04-12-shell-modernisation-design.md` § 3.11 and § 4 (Layer 1c).

**Platform scope:** macOS (Apple Silicon + Intel), WSL2 (Ubuntu-based). Tests run on both.

**Prerequisite:** Layer 1a merged. This plan is independent of Layer 1b (can land in either order); if Layer 1b lands first, its `git-repos.toml` cable channel becomes functional once Layer 1c completes.

---

## Acceptance Criteria (Specification by Example)

Each bullet is a testable assertion. The acceptance test script `scripts/test-plan-layer1c.sh` validates every assertion end-to-end.

**AC-1: Brewfile installs ghq and ghorg**
```
Given: a fresh macOS machine with Homebrew installed
When: `brew bundle --file=Brewfile` runs
Then: `command -v ghq` and `command -v ghorg` both succeed
```

**AC-2: tools.txt is consistent with Brewfile**
```
When: `bash scripts/check-tool-manifest.sh` runs
Then: exit 0
```

**AC-3: git/.gitconfig sets ghq.root**
```
Given: the tracked git/.gitconfig
When: `git config --file git/.gitconfig ghq.root` is queried
Then: output is `~/code` (literal tilde, not expanded — git config preserves this)
```

**AC-4: `ghq root` resolves to $HOME/code (full-mode only)**
```
Given: ghq installed and git/.gitconfig symlinked
When: `ghq root` runs
Then: output is `$HOME/code` (tilde expanded)
```

**AC-5: `repo` function is defined and invokes ghq + fzf**
```
Given: bash/.bash_aliases sourced
When: `declare -F repo` runs
Then: exit 0 (function defined)
And: the body contains `ghq list --full-path | fzf`
```

**AC-6: `gclone` function is defined with `ghq list -e -p` and a guard**
```
Given: bash/.bash_aliases sourced
When: `declare -F gclone` runs
Then: exit 0
And: the body contains `ghq get -u`
And: the body contains `ghq list -e -p`
And: the body contains a guard clause (`[[ -n` / `-d` / `return 1`)
```

**AC-7: `ghorg-gh` function is defined and pins --path**
```
Given: bash/.bash_aliases sourced
When: `declare -F ghorg-gh` runs
Then: exit 0
And: the body contains `ghorg clone` and `--path ~/code/github.com`
And: the body does NOT contain `--output-dir` (forbidden by design)
```

**AC-8: Alt-R is bound to `repo` in bash readline**
```
Given: bash/.bashrc sourced in an interactive shell
When: `bind -P` is inspected
Then: the line for `\e-r` (or `\C-[r`) shows `repo\n` as the macro
```

**AC-9: install-wsl.sh aborts if $HOME is under /mnt/c/**
```
Given: a simulated WSL environment with `HOME=/mnt/c/Users/test`
When: `bash install-wsl.sh --check-preconditions` runs
Then: exit code is non-zero
And: stderr contains a message mentioning /mnt/c and ext4

Given: `HOME=/home/test` (ext4-style path)
When: `bash install-wsl.sh --check-preconditions` runs
Then: exit code is 0 and no precondition error fires
```

**AC-10: agents/AGENTS.md.snippet exists with required content**
```
Given: the repo state
When: `test -f agents/AGENTS.md.snippet` runs
Then: exit 0
And: the file contains "## Local repo layout"
And: the file contains "ghq get <url>"
And: the file contains "never clone into /mnt/c"
```

**AC-11: scripts/install-ai-conventions.sh is idempotent**
```
Given: ~/AGENTS.md does not contain the snippet
When: `bash scripts/install-ai-conventions.sh` runs
Then: ~/AGENTS.md exists and contains the snippet once

When: `bash scripts/install-ai-conventions.sh` runs a second time
Then: ~/AGENTS.md still contains the snippet exactly once
And: no file corruption
```

**AC-12: verify.sh smoke-checks ghq and ghorg**
```
Given: verify.sh
When: grep for literal check strings
Then: "command -v ghq" appears
And: "command -v ghorg" appears
And: "ghq root" appears (validates config resolution, not just PATH)
```

**AC-13: cheatsheet.md documents repo / gclone / ghorg-gh**
```
Given: docs/cheatsheet.md
When: inspected
Then: it contains rows for `repo`, `gclone`, `ghorg-gh`
And: it mentions Alt-R as the repo-picker chord
```

**AC-14: README has a Repo layout section**
```
Given: README.md
When: inspected
Then: it contains a "Repo layout" H2 or H3 section
And: that section mentions `~/code/<host>/<org>/<repo>` and the `repo` function
```

**AC-15: End-to-end acceptance script enumerates every AC**
```
When: `bash scripts/test-plan-layer1c.sh` runs on macOS or WSL2
Then: every AC above is checked
And: exit code is 0 if all pass, 1 otherwise
```

---

## File Structure

**New files (created by this plan):**
- `agents/AGENTS.md.snippet` — canonical AGENTS.md addition, used by installer
- `scripts/install-ai-conventions.sh` — idempotent installer that appends snippet to `~/AGENTS.md`
- `scripts/test-plan-layer1c.sh` — acceptance tests for all 15 ACs

**Modified files:**
- `Brewfile` — add `ghq`, `ghorg`
- `tools.txt` — matching rows
- `git/.gitconfig` — add `[ghq]\n  root = ~/code`
- `bash/.bash_aliases` — add `repo`, `gclone`, `ghorg-gh` functions (with section banner)
- `bash/.bashrc` — add Alt-R binding (in section 6, vi-mode keybindings area, or a new § 10 if not already placed)
- `install-wsl.sh` — add `--check-preconditions` flag and hard-abort-on-/mnt/c/ logic; wire the check into the main body as a pre-flight step
- `install-macos.sh` — (no code change needed; git/.gitconfig is already symlinked)
- `scripts/verify.sh` — Layer 1c smoke checks
- `docs/cheatsheet.md` — new rows for `repo`, `gclone`, `ghorg-gh`, Alt-R chord
- `README.md` — "Repo layout" section

**Untouched (preserved):**
- `~/.gitconfig.local` — personal identity stays separate from `ghq.root` (structural)
- All other tool configs

---

## Task 0: Bootstrap Acceptance Test Script (Red)

Before writing production code, create the acceptance test script with scaffolding for the Layer 1c ACs. Follows the same pattern as Layer 1a's `scripts/test-plan-layer1a.sh`.

**Files:**
- Create: `scripts/test-plan-layer1c.sh`

- [ ] **Step 1: Create the script skeleton**

Model on the Layer 1a script (self-resolving path, `--full` mode, TTY-aware colours, `ok`/`nok`/`skp`/`check` helpers). Copy the preamble verbatim from `scripts/test-plan-layer1a.sh` lines 1–55 (header, self-resolve, platform detection, colour setup, counters, helpers), then add:

```bash
echo "Layer 1c acceptance tests (ghq + ghorg + shell helpers)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1: Brewfile installs ghq and ghorg ──────────────────────────────
echo "AC-1: Brewfile installs ghq and ghorg"
check "Brewfile has brew \"ghq\""        grep -qE '^\s*brew\s+"ghq"' Brewfile
check "Brewfile has brew \"ghorg\""      grep -qE '^\s*brew\s+"ghorg"' Brewfile
if [[ "$FULL" == true ]]; then
  check "ghq is on PATH"                 command -v ghq
  check "ghorg is on PATH"               command -v ghorg
else
  skp "ghq on PATH" "safe mode"
  skp "ghorg on PATH" "safe mode"
fi

# ── AC-2: tools.txt manifest consistency ──────────────────────────────
echo ""
echo "AC-2: tools.txt manifest consistency"
check "check-tool-manifest.sh passes"    bash scripts/check-tool-manifest.sh

# Later tasks fill in AC-3 through AC-14 as features land.

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
```

- [ ] **Step 2:** `chmod +x scripts/test-plan-layer1c.sh`

- [ ] **Step 3: Run to confirm red state**

`bash scripts/test-plan-layer1c.sh` — AC-1 Brewfile checks fail (ghq/ghorg not yet listed), AC-2 may pass (existing manifest consistent). Exit 1.

- [ ] **Step 4: Commit**

```
git add scripts/test-plan-layer1c.sh
git commit -m "test(plan-layer1c): scaffold acceptance test script with AC-1 and AC-2"
```

---

## Task 1: Add ghq and ghorg to Brewfile + tools.txt (AC-1, AC-2)

**Files:**
- Modify: `Brewfile`, `tools.txt`

- [ ] **Step 1:** Verify current state: `grep -E 'ghq|ghorg' Brewfile tools.txt || echo "neither present"` → `neither present`.

- [ ] **Step 2: Add a "Repo organisation" section to Brewfile**

Choose placement that groups it with other Git-related tools. Insert after the existing "Git" section (wherever that ends; if there isn't one, place near the top after general utilities):

```
# ── Repo organisation (Layer 1c) ─────────────────────────────────────────────
brew "ghq"
brew "ghorg"
```

- [ ] **Step 3: Add matching rows to tools.txt**

Preserve column alignment (21/27/19 columns based on existing rows):

```
# ── Repo organisation (Layer 1c) ─────────────────────────────────────────────
ghq                  brew:ghq                       apt:-                   apk:ghq
ghorg                brew:ghorg                     apt:-                   apk:-
```

- [ ] **Step 4:** `bash scripts/check-tool-manifest.sh` → exit 0.

- [ ] **Step 5:** `bash scripts/test-plan-layer1c.sh` → AC-1 Brewfile checks pass, AC-2 passes.

- [ ] **Step 6: Commit**

```
git add Brewfile tools.txt
git commit -m "feat(brewfile): add ghq and ghorg (Layer 1c)"
```

---

## Task 2: Add ghq.root to git/.gitconfig (AC-3)

**Files:**
- Modify: `git/.gitconfig`
- Modify: `scripts/test-plan-layer1c.sh`

- [ ] **Step 1: Add AC-3 check to the test script**

Insert immediately after the AC-2 block, before the final summary separator:

```bash
# ── AC-3: git/.gitconfig sets ghq.root ────────────────────────────────
echo ""
echo "AC-3: git/.gitconfig declares ghq.root"
check "git config ghq.root = ~/code" \
  bash -c 'root=$(git config --file git/.gitconfig ghq.root 2>/dev/null); [[ "$root" == "~/code" ]]'

# ── AC-4: ghq root resolves to $HOME/code (full only) ────────────────
echo ""
echo "AC-4: ghq root command resolves"
if [[ "$FULL" == true ]] && command -v ghq &>/dev/null; then
  actual="$(ghq root 2>/dev/null)"
  expected="$HOME/code"
  if [[ "$actual" == "$expected" ]]; then
    ok "ghq root = \$HOME/code"
  else
    nok "ghq root = \$HOME/code (got: $actual)"
  fi
else
  skp "ghq root = \$HOME/code" "requires --full + ghq installed + symlinks"
fi
```

- [ ] **Step 2: Run tests — AC-3 fails**

- [ ] **Step 3: Read current git/.gitconfig**

`cat git/.gitconfig` to see the current sections.

- [ ] **Step 4: Append the ghq section**

Add at the end of `git/.gitconfig` (or wherever other tool sections live — if there's no `[hub]` or similar, just append):

```ini

[ghq]
  root = ~/code
```

The literal `~/code` is correct — git expands `~` at read time.

- [ ] **Step 5:** `bash scripts/test-plan-layer1c.sh` → AC-3 passes.

- [ ] **Step 6: Commit**

```
git add git/.gitconfig scripts/test-plan-layer1c.sh
git commit -m "feat(git): add ghq.root = ~/code for Layer 1c repo organisation"
```

---

## Task 3: Add `repo`, `gclone`, `ghorg-gh` functions to bash/.bash_aliases (AC-5, AC-6, AC-7)

**Files:**
- Modify: `bash/.bash_aliases`
- Modify: `scripts/test-plan-layer1c.sh`

- [ ] **Step 1: Add AC-5, AC-6, AC-7 blocks to the test script**

Append after the AC-4 block:

```bash
# ── AC-5: `repo` function defined ─────────────────────────────────────
echo ""
echo "AC-5: repo function invokes ghq+fzf"
check "bash/.bash_aliases defines repo()" \
  bash -c "awk '/^repo\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'ghq list --full-path'"
check "repo body pipes through fzf" \
  bash -c "awk '/^repo\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'fzf'"

# ── AC-6: `gclone` function with -e -p and guard ─────────────────────
echo ""
echo "AC-6: gclone uses exact-path lookup with a guard"
check "gclone uses 'ghq get -u'" \
  bash -c "awk '/^gclone\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'ghq get -u'"
check "gclone uses 'ghq list -e -p'" \
  bash -c "awk '/^gclone\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'ghq list -e -p'"
check "gclone has a guard against empty/missing target" \
  bash -c "awk '/^gclone\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -qE 'return 1|nonexist|-d '"

# ── AC-7: `ghorg-gh` function ─────────────────────────────────────────
echo ""
echo "AC-7: ghorg-gh pins --path into the ghq tree"
check "ghorg-gh calls 'ghorg clone'" \
  bash -c "awk '/^ghorg-gh\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'ghorg clone'"
check "ghorg-gh passes '--path ~/code/github.com'" \
  bash -c "awk '/^ghorg-gh\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'path ~/code/github.com'"
check "ghorg-gh does NOT pass --output-dir" \
  bash -c "! awk '/^ghorg-gh\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'output-dir'"
```

NOTE: The `awk '/^func\(\) \{/,/^\}/'` pattern requires each function's opening brace to be on the same line as the name, and the closing `}` to be on its own line at column 0. Follow this convention when writing the functions.

- [ ] **Step 2: Run tests — AC-5/6/7 all fail.**

- [ ] **Step 3: Append the functions to bash/.bash_aliases**

Add at the end of `bash/.bash_aliases` (preserve existing content):

```bash

# ── Repo organisation (Layer 1c: ghq + ghorg) ────────────────────────────────
# Interactive repo picker — bound to Alt-R (see bash/.bashrc).
repo() {
  local dir
  dir=$(ghq list --full-path | fzf --preview 'ls -la {}') && cd "$dir" || return
}

# Clone-and-go: ghq get + cd to the canonical path.
# Uses `ghq list -e -p` (exact match, full path) to avoid the substring+head hazard.
gclone() {
  if ghq get -u "$1"; then
    local target
    target="$(ghq list -e -p "$1" 2>/dev/null | head -1)"
    if [[ -n "$target" && -d "$target" ]]; then
      cd "$target"
    else
      echo "ghq: cannot resolve path for '$1'" >&2
      return 1
    fi
  fi
}

# Bulk-clone a GitHub org into the ghq tree.
# Pins --path to ~/code/github.com; never pass --output-dir (renames org folder).
ghorg-gh() {
  local org="$1"; shift
  ghorg clone "$org" --path ~/code/github.com "$@"
}
```

- [ ] **Step 4:** `bash -n bash/.bash_aliases` → exit 0.

- [ ] **Step 5:** `bash scripts/test-plan-layer1c.sh` → AC-5, AC-6, AC-7 all pass.

- [ ] **Step 6: Commit**

```
git add bash/.bash_aliases scripts/test-plan-layer1c.sh
git commit -m "feat(bash-aliases): add repo, gclone, ghorg-gh functions (Layer 1c)"
```

---

## Task 4: Add Alt-R readline binding for `repo` (AC-8)

**Files:**
- Modify: `bash/.bashrc`
- Modify: `scripts/test-plan-layer1c.sh`

- [ ] **Step 1: Add AC-8 check to the test script**

```bash
# ── AC-8: Alt-R bound to repo in bash readline ────────────────────────
echo ""
echo "AC-8: Alt-R binding for repo"
check "bash/.bashrc binds \\e-r to repo" \
  bash -c "grep -qE '^bind\\s+\"\\\\er\":\"repo' bash/.bashrc"

if [[ "$FULL" == true ]]; then
  bind_out="$(bash --rcfile bash/.bashrc -ic 'bind -P 2>/dev/null | grep "\\\\er" || true' 2>/dev/null)"
  if printf '%s' "$bind_out" | grep -q 'repo'; then
    ok "interactive bash binds Alt-R to repo"
  else
    nok "interactive bash binds Alt-R to repo"
  fi
else
  skp "interactive bash binds Alt-R to repo" "requires --full"
fi
```

- [ ] **Step 2: Run — AC-8 fails.**

- [ ] **Step 3: Find the right insertion point in bash/.bashrc**

`grep -n '^# ── ' bash/.bashrc` to see the section headers. Add the binding in a "Keybindings" or "Aliases" section near the end of the file but BEFORE the `.bashrc.local` source line (so local overrides can rebind).

- [ ] **Step 4: Add the Alt-R binding**

Add this block (choose the section that makes sense based on current bashrc structure — likely near the existing readline customisations, or appended in a new § 13 "Layer 1c keybindings"):

```bash

# ── Layer 1c keybindings ───────────────────────────────────────────────────
# Alt-R: invoke `repo` (ghq+fzf interactive picker).
# Only bind in interactive shells to avoid noisy errors in non-interactive contexts.
if [[ $- == *i* ]]; then
  bind '"\er":"repo\n"'
fi
```

- [ ] **Step 5:** `bash -n bash/.bashrc` → exit 0.

- [ ] **Step 6:** `bash scripts/test-plan-layer1c.sh` → AC-8 static check passes.

- [ ] **Step 7: Commit**

```
git add bash/.bashrc scripts/test-plan-layer1c.sh
git commit -m "feat(bash): bind Alt-R to repo() for ghq+fzf repo picker (Layer 1c)"
```

---

## Task 5: Add WSL2 precondition to install-wsl.sh (AC-9)

**Files:**
- Modify: `install-wsl.sh`
- Modify: `scripts/test-plan-layer1c.sh`

- [ ] **Step 1: Add AC-9 check to the test script**

```bash
# ── AC-9: install-wsl.sh aborts if $HOME under /mnt/c ─────────────────
echo ""
echo "AC-9: WSL /mnt/c precondition"
# Static: the precondition function exists and references /mnt/c
check "install-wsl.sh contains /mnt/c precondition" \
  bash -c "awk '/^check_home_on_ext4\\(\\) \\{/,/^\\}/' install-wsl.sh | grep -q '/mnt/c'"
check "install-wsl.sh supports --check-preconditions" \
  grep -qE '\-\-check-preconditions' install-wsl.sh

# Full: spawn with simulated HOME
if [[ "$FULL" == true ]]; then
  # Case A: HOME under /mnt/c should abort
  if HOME=/mnt/c/Users/test bash install-wsl.sh --check-preconditions 2>/tmp/wsl-a.err; rc=$?; [[ $rc -ne 0 ]]; then
    if grep -q '/mnt/c' /tmp/wsl-a.err; then
      ok "HOME=/mnt/c/... causes abort with /mnt/c message"
    else
      nok "HOME=/mnt/c/... aborts but message lacks /mnt/c reference"
    fi
  else
    nok "HOME=/mnt/c/... should abort but exited $rc"
  fi
  # Case B: HOME on ext4 should succeed
  if HOME=/home/test bash install-wsl.sh --check-preconditions >/dev/null 2>&1; then
    ok "HOME=/home/... passes preconditions"
  else
    nok "HOME=/home/... should pass preconditions"
  fi
else
  skp "HOME=/mnt/c/... aborts" "requires --full"
  skp "HOME=/home/... passes" "requires --full"
fi
```

- [ ] **Step 2: Run — AC-9 fails (no precondition function yet).**

- [ ] **Step 3: Add the precondition function and flag handling to install-wsl.sh**

Insert a new function near the top of `install-wsl.sh` (after the existing helper definitions like `err`, `warn`, `log`, `link`):

```bash
# Precondition: $HOME must be on a native Linux filesystem (ext4), not on
# /mnt/c/ (9P bridge to Windows — ~10× slower, kills git perf on ghq tree).
check_home_on_ext4() {
  local home_real
  home_real="$(readlink -f "$HOME" 2>/dev/null || echo "$HOME")"
  case "$home_real" in
    /mnt/c/*|/mnt/*)
      err "HOME ($home_real) is on a 9P-mounted Windows path."
      err "ghq tree (~/code) would be crippling slow here."
      err "Move your Linux home to ext4 before running this installer."
      err "See: docs/plans/2026-04-12-shell-modernisation-design.md § 3.11.6"
      return 1
      ;;
  esac
  return 0
}
```

Then add early argument handling (near the top of the main body, before the install steps):

```bash
if [[ "${1:-}" == "--check-preconditions" ]]; then
  check_home_on_ext4 || exit 1
  log "preconditions OK"
  exit 0
fi

# Normal install path also runs the precondition
check_home_on_ext4 || exit 1
```

- [ ] **Step 4:** `bash -n install-wsl.sh` → exit 0.

- [ ] **Step 5: Sanity-test the simulation**

Locally run:
```
HOME=/mnt/c/Users/test bash install-wsl.sh --check-preconditions 2>&1 | head -5
```
Expected: non-zero exit, stderr mentions `/mnt/c` and ext4.

Then:
```
HOME=/home/test bash install-wsl.sh --check-preconditions
```
Expected: exit 0, "preconditions OK".

- [ ] **Step 6:** `bash scripts/test-plan-layer1c.sh` → AC-9 static checks pass.

- [ ] **Step 7: Commit**

```
git add install-wsl.sh scripts/test-plan-layer1c.sh
git commit -m "feat(install-wsl): hard-abort if HOME is on /mnt/c (Layer 1c)"
```

---

## Task 6: Create agents/AGENTS.md.snippet (AC-10)

**Files:**
- Create: `agents/AGENTS.md.snippet`
- Modify: `scripts/test-plan-layer1c.sh`

- [ ] **Step 1: Add AC-10 check**

```bash
# ── AC-10: AGENTS.md snippet exists with required content ─────────────
echo ""
echo "AC-10: agents/AGENTS.md.snippet"
check "snippet file exists"          test -f agents/AGENTS.md.snippet
check "snippet has Local repo layout heading" \
  grep -q '^## Local repo layout' agents/AGENTS.md.snippet
check "snippet mentions ghq get" \
  grep -q 'ghq get' agents/AGENTS.md.snippet
check "snippet forbids /mnt/c clones" \
  grep -q '/mnt/c' agents/AGENTS.md.snippet
```

- [ ] **Step 2: Create `agents/AGENTS.md.snippet`**

```markdown
## Local repo layout

Clone git repos via `ghq get <url>` — never plain `git clone`. The repo root
is `~/code` and the enforced layout is `<host>/<org>/<repo>`. For bulk-cloning
an org, use `ghorg clone <org> --path ~/code/<host>` so repos land inside the
ghq tree. On WSL2 never clone into `/mnt/c/...` (10× perf penalty on the 9P
bridge; keep everything on ext4).

To navigate to an existing checkout, prefer `cd "$(ghq list -e -p <ref>)"` or
the interactive `repo` function (Alt-R) over hand-typed `cd ~/code/...` paths.
```

- [ ] **Step 3:** `bash scripts/test-plan-layer1c.sh` → AC-10 passes.

- [ ] **Step 4: Commit**

```
git add agents/AGENTS.md.snippet scripts/test-plan-layer1c.sh
git commit -m "feat(agents): tracked AGENTS.md snippet for ghq layout convention"
```

---

## Task 7: Create scripts/install-ai-conventions.sh (AC-11)

**Files:**
- Create: `scripts/install-ai-conventions.sh`
- Modify: `scripts/test-plan-layer1c.sh`

- [ ] **Step 1: Add AC-11 check**

```bash
# ── AC-11: install-ai-conventions.sh is idempotent ───────────────────
echo ""
echo "AC-11: AI conventions installer is idempotent"
check "install-ai-conventions.sh exists"     test -x scripts/install-ai-conventions.sh
if [[ "$FULL" == true ]]; then
  tmp_home="$(mktemp -d)"
  trap "rm -rf '$tmp_home'" EXIT
  # First run
  if HOME="$tmp_home" bash scripts/install-ai-conventions.sh >/dev/null 2>&1; then
    snippet_count=$(grep -c '^## Local repo layout' "$tmp_home/AGENTS.md" 2>/dev/null || echo 0)
    if [[ "$snippet_count" -eq 1 ]]; then
      ok "first run installs snippet once"
    else
      nok "first run installs snippet exactly once (got $snippet_count)"
    fi
    # Second run — must remain idempotent
    HOME="$tmp_home" bash scripts/install-ai-conventions.sh >/dev/null 2>&1
    snippet_count=$(grep -c '^## Local repo layout' "$tmp_home/AGENTS.md" 2>/dev/null || echo 0)
    if [[ "$snippet_count" -eq 1 ]]; then
      ok "second run leaves snippet count at 1 (idempotent)"
    else
      nok "second run should keep snippet count at 1 (got $snippet_count)"
    fi
  else
    nok "first install-ai-conventions.sh run exited non-zero"
  fi
else
  skp "install-ai-conventions.sh idempotency" "requires --full"
fi
```

- [ ] **Step 2: Create the installer**

Create `scripts/install-ai-conventions.sh`:

```bash
#!/usr/bin/env bash
# install-ai-conventions.sh — append the Local repo layout section to ~/AGENTS.md
# Idempotent: running twice produces exactly one copy of the snippet.
#
# Both OpenCode and GitHub Copilot Coding Agent (VS Code) honour ~/AGENTS.md.

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
DOTFILES="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"

SNIPPET="$DOTFILES/agents/AGENTS.md.snippet"
TARGET="$HOME/AGENTS.md"

[[ -f "$SNIPPET" ]] || { echo "error: snippet not found at $SNIPPET" >&2; exit 1; }

mkdir -p "$(dirname "$TARGET")"
touch "$TARGET"

# Sentinel: the snippet's H2 heading. If already present, no-op.
if grep -qF '## Local repo layout' "$TARGET"; then
  echo "AGENTS.md already contains 'Local repo layout' — no change."
  exit 0
fi

# Separate with a blank line if file non-empty and doesn't already end in one.
if [[ -s "$TARGET" ]] && [[ "$(tail -c1 "$TARGET" | od -An -c | tr -d ' ')" != '\n' ]]; then
  printf '\n' >> "$TARGET"
fi
if [[ -s "$TARGET" ]]; then
  printf '\n' >> "$TARGET"
fi

cat "$SNIPPET" >> "$TARGET"
echo "Appended Local repo layout snippet to $TARGET"
```

- [ ] **Step 3:** `chmod +x scripts/install-ai-conventions.sh`

- [ ] **Step 4: Manual sanity**

```
tmp=$(mktemp -d); HOME="$tmp" bash scripts/install-ai-conventions.sh
grep -c '^## Local repo layout' "$tmp/AGENTS.md"    # → 1
HOME="$tmp" bash scripts/install-ai-conventions.sh  # → no-op message
grep -c '^## Local repo layout' "$tmp/AGENTS.md"    # → still 1
rm -rf "$tmp"
```

- [ ] **Step 5:** `bash scripts/test-plan-layer1c.sh` → AC-11 static check passes.

- [ ] **Step 6: Commit**

```
git add scripts/install-ai-conventions.sh scripts/test-plan-layer1c.sh
git commit -m "feat(scripts): idempotent installer for ~/AGENTS.md repo layout snippet"
```

---

## Task 8: Add ghq/ghorg smoke checks to verify.sh (AC-12)

**Files:**
- Modify: `scripts/verify.sh`
- Modify: `scripts/test-plan-layer1c.sh`

- [ ] **Step 1: Add AC-12 check**

```bash
# ── AC-12: verify.sh smoke-checks ghq + ghorg ────────────────────────
echo ""
echo "AC-12: verify.sh smoke checks"
check "verify.sh checks ghq on PATH"    grep -q 'command -v ghq' scripts/verify.sh
check "verify.sh checks ghorg on PATH"  grep -q 'command -v ghorg' scripts/verify.sh
check "verify.sh checks 'ghq root'"     grep -q 'ghq root' scripts/verify.sh
```

- [ ] **Step 2: Add the verify.sh block**

After the existing "Layer 1a tools" block in `scripts/verify.sh`, add:

```bash

# ── Layer 1c tools ────────────────────────────────────────────────────────
echo ""
echo "Layer 1c tools:"
check "ghq on PATH"              command -v ghq
check "ghorg on PATH"            command -v ghorg
if command -v ghq &>/dev/null; then
  ghq_root_actual="$(ghq root 2>/dev/null)"
  if [[ "$ghq_root_actual" == "$HOME/code" ]]; then
    ok "ghq root resolves to \$HOME/code"
  else
    nok "ghq root resolves to \$HOME/code (got: $ghq_root_actual)"
  fi
fi
```

- [ ] **Step 3:** `bash -n scripts/verify.sh` → exit 0.

- [ ] **Step 4:** `bash scripts/test-plan-layer1c.sh` → AC-12 passes.

- [ ] **Step 5: Commit**

```
git add scripts/verify.sh scripts/test-plan-layer1c.sh
git commit -m "feat(verify): smoke-check ghq + ghorg + ghq root (Layer 1c)"
```

---

## Task 9: Update docs/cheatsheet.md (AC-13)

**Files:**
- Modify: `docs/cheatsheet.md`
- Modify: `scripts/test-plan-layer1c.sh`

- [ ] **Step 1: Add AC-13 check**

```bash
# ── AC-13: cheatsheet.md documents Layer 1c ──────────────────────────
echo ""
echo "AC-13: cheatsheet.md repo helpers"
check "cheatsheet mentions repo function"     grep -q '\brepo\b' docs/cheatsheet.md
check "cheatsheet mentions gclone"            grep -q 'gclone' docs/cheatsheet.md
check "cheatsheet mentions ghorg-gh"          grep -q 'ghorg-gh' docs/cheatsheet.md
check "cheatsheet mentions Alt-R"             grep -q 'Alt.R' docs/cheatsheet.md
```

- [ ] **Step 2: Add rows**

Find the most appropriate table (likely a "Searching" or "Git" table) and add:

```markdown
| Pick a repo (ghq tree) | ghq+fzf | `repo` | Alt-R |
| Clone and cd into it | ghq | `gclone <url>` | — |
| Bulk-clone a GitHub org | ghorg | `ghorg-gh <org>` | — |
```

Or add them to a new "Repo organisation" subsection if the table layout doesn't fit. Keep style consistent with the existing tables (Layer 1a's atuin/television rows are the recent precedent).

- [ ] **Step 3:** `bash scripts/test-plan14-16.sh` → no regression. `bash scripts/test-plan-layer1c.sh` → AC-13 passes.

- [ ] **Step 4: Commit**

```
git add docs/cheatsheet.md scripts/test-plan-layer1c.sh
git commit -m "docs(cheatsheet): add repo / gclone / ghorg-gh rows (Layer 1c)"
```

---

## Task 10: Add Repo layout section to README (AC-14)

**Files:**
- Modify: `README.md`
- Modify: `scripts/test-plan-layer1c.sh`

- [ ] **Step 1: Add AC-14 check**

```bash
# ── AC-14: README documents repo layout ──────────────────────────────
echo ""
echo "AC-14: README Repo layout section"
check "README has 'Repo layout' heading" \
  grep -qE '^##+\s+Repo layout' README.md
check "README mentions ~/code/<host>/<org>/<repo>" \
  grep -q 'code/<host>/<org>/<repo>' README.md
check "README mentions 'repo' function" \
  grep -qE '\brepo\b.*function|fzf.*repo|Alt-R.*repo' README.md
```

- [ ] **Step 2: Add the section**

Find the existing README structure (check where "Testing" section landed from Layer 1a). Add a "Repo layout" section AFTER the Quick start and BEFORE Configuration (or adjacent to it):

```markdown
## Repo layout

All git checkouts live under a single root, organised by host/org/repo:

```
~/code/<host>/<org>/<repo>

Examples:
  ~/code/github.com/anthropics/claude-code
  ~/code/gitlab.com/some-org/service
  ~/code/gitlab.mycompany.com/team/repo
```

Enforced by [ghq](https://github.com/x-motemen/ghq) (`ghq.root = ~/code`). Helpers:

- **`repo`** — fzf picker over all ghq-managed checkouts. Bound to `Alt-R`.
- **`gclone <url>`** — `ghq get -u` + cd to the canonical path.
- **`ghorg-gh <org>`** — bulk-clone a whole GitHub org into `~/code/github.com/<org>/`.

For the coding agents' convention (OpenCode, GitHub Copilot), run once:
```
bash scripts/install-ai-conventions.sh
```

**WSL2**: `~/code` MUST be on ext4, never `/mnt/c/`. The installer hard-aborts if your `$HOME` is on `/mnt/c/`.
```

- [ ] **Step 3:** `bash scripts/test-plan-layer1c.sh` → AC-14 passes.

- [ ] **Step 4: Commit**

```
git add README.md scripts/test-plan-layer1c.sh
git commit -m "docs(readme): add Repo layout section (Layer 1c)"
```

---

## Task 11: End-to-end acceptance (AC-15) + docs polish

**Files:**
- Modify: `scripts/test-plan-layer1c.sh` (final summary sanity)
- Modify: `README.md` Testing section (add Layer 1c to invocation list)

- [ ] **Step 1: Verify the script's final summary is strict**

`tail -5 scripts/test-plan-layer1c.sh` → `(( fail == 0 ))` as last executable line.

- [ ] **Step 2: Run the full suite**

```
bash scripts/test-plan-layer1c.sh             # safe mode
bash scripts/test-plan-layer1a.sh             # regression
bash scripts/test-plan14-16.sh                # regression
bash scripts/check-tool-manifest.sh
```

All must pass.

Optional (if tools are installed locally):
```
bash scripts/test-plan-layer1c.sh --full
```

- [ ] **Step 3: Update README Testing section**

Find the Testing section added in Layer 1a and add a new line:

```
bash scripts/test-plan-layer1c.sh          # Layer 1c: ghq + ghorg + shell helpers
bash scripts/test-plan-layer1c.sh --full   # + invasive checks (requires tools installed + --full WSL simulation)
```

- [ ] **Step 4: Commit**

```
git add README.md
git commit -m "docs(readme): document test-plan-layer1c.sh invocation"
```

---

## Post-plan: Manual Validation Steps

After the plan completes:

- [ ] **Manual 1:** Install Layer 1c on your macOS box:
  ```
  brew bundle --file=Brewfile
  bash install-macos.sh
  ```
  Verify: `ghq root` → `$HOME/code`.

- [ ] **Manual 2:** Clone a test repo and navigate:
  ```
  ghq get github.com/anthropics/anthropic-cookbook
  # Opens a new shell (or source .bashrc)
  repo   # Alt-R
  # fzf shows anthropic-cookbook; selecting cd's into it
  ```

- [ ] **Manual 3:** Test `gclone`:
  ```
  gclone github.com/cli/cli
  # Should cd into ~/code/github.com/cli/cli
  ```

- [ ] **Manual 4:** Run the AGENTS.md installer:
  ```
  bash scripts/install-ai-conventions.sh
  cat ~/AGENTS.md    # should include the Local repo layout section
  bash scripts/install-ai-conventions.sh    # second run says "already contains"
  ```

- [ ] **Manual 5 (WSL2):** Simulate the /mnt/c abort:
  ```
  HOME=/mnt/c/Users/test bash install-wsl.sh --check-preconditions
  # Must exit non-zero with clear error
  ```

- [ ] **Manual 6:** Bulk-clone test (tiny org):
  ```
  ghorg-gh some-tiny-org
  ls ~/code/github.com/some-tiny-org/
  ghq list | grep some-tiny-org
  ```

---

## Self-Review Notes

**Spec coverage check:**
- AC-1 → Task 1 ✓
- AC-2 → Task 1 ✓
- AC-3 → Task 2 ✓
- AC-4 → Task 2 (full-mode) ✓
- AC-5 → Task 3 ✓
- AC-6 → Task 3 ✓
- AC-7 → Task 3 ✓
- AC-8 → Task 4 ✓
- AC-9 → Task 5 ✓
- AC-10 → Task 6 ✓
- AC-11 → Task 7 ✓
- AC-12 → Task 8 ✓
- AC-13 → Task 9 ✓
- AC-14 → Task 10 ✓
- AC-15 → Task 11 (aggregate) ✓

**Out of scope for Layer 1c:**
- Zsh versions of the functions → Layer 2 (port to `.zsh_aliases` with `bindkey -s '^[r' 'repo\n'` instead of `bind`)
- Nushell versions → Layer 3
- GitLab Self-hosted `ghorg-gl` variant → add later when user hits the need
- Migration of existing clones into `~/code/<host>/<org>/<repo>` → out of scope (user does this manually; ghq doesn't auto-migrate)
- Integration with television's `git-repos.toml` cable channel → happens in Layer 1b (forward reference: once 1b and 1c both land, the channel Just Works)

**Conventions adopted from Layer 1a:**
- ATDD outer loop via `scripts/test-plan-layer1c.sh`
- `if/then/ok/nok` for dynamic checks (no `bash -c` quote-interpolation)
- `awk '/^func\(\) \{/,/^\}/' | sed 's/#.*//'` for function-body-scoped greps (prevents comment false-positives)
- Structural multiline matches over loose greps
- Commits reference Co-Authored-By trailer
- --full mode gating for invasive checks

**Type/naming consistency:**
- Function names: `repo`, `gclone`, `ghorg-gh` (lowercase, hyphens OK for the bulk variant)
- Env vars: none new (ghq uses `GHQ_ROOT` optionally, but we prefer git-config)
- File paths: all relative to `$DOTFILES`, symlinked to `$HOME`
- Test assertions: `AC-1` through `AC-15` matching spec
