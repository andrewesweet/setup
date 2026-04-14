# Desktop Layer 3 Implementation Plan: Launcher (Raycast)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace macOS Spotlight with Raycast on Cmd-Space, with cloud sync forcibly disabled by three defense-in-depth mechanisms (checklist mandate + `/etc/hosts` blackhole + opportunistic plist probe).

**Architecture:** Raycast ships as a cask (login item); no symlinks, no settings export (binary prefs + OAuth tokens not source-controllable). `raycast/extensions.md` is the sole committed asset — a two-section document (Summary + Post-install checklist with Recommended Extensions subsection) that any fresh-machine setup walks through to replicate the intended state. `install-macos.sh`'s Next-steps appends optional `/etc/hosts` blackhole commands for Raycast sync endpoints.

**Tech Stack:** bash 5, Raycast (cask), `/etc/hosts` (user-discretion hardening).

**Spec reference:** `docs/plans/2026-04-14-macos-desktop-env-design.md` §3.6, §4.3, §5.1, §5.2, §7.6, Appendix A.2.3.

**Platform scope:** macOS only. WSL install untouched.

**Prerequisite:** Desktop Layers 1 and 2 merged (this plan rebases on the new `main` after Layer 2). This layer is orthogonal to Layers 1/2 — Raycast has no IPC with AeroSpace, SketchyBar, Hammerspoon, or skhd. Layer 2's `Hyper+Space` binding is the documented fallback invocation path if Cmd-Space takeover fails.

---

## Acceptance Criteria (Specification by Example)

Each bullet is a testable assertion. The acceptance test script `scripts/test-plan-desktop-layer3.sh` validates every assertion end-to-end.

**AC-1: Brewfile declares Raycast cask**
```
Given: macos-dev/Brewfile
When: inspected
Then: contains the line `cask "raycast"`
```

**AC-2: raycast/extensions.md exists with the two-section header structure**
```
Given: macos-dev/raycast/extensions.md
When: inspected
Then: file exists
And: top-level `# Raycast — Layer 3 launcher` header present
And: `## Summary` section header present
And: `## Post-install checklist` section header present
And: `## Recommended extensions` section header present (subsection-level `###` is also acceptable but the design specifies `##` — match that)
```

**AC-3: Post-install checklist contains the 8 documented steps**
```
Given: macos-dev/raycast/extensions.md
When: Post-install checklist inspected
Then: contains checklist items mentioning ALL of:
  - "Launch Raycast" (first-run)
  - "Accessibility" grant
  - "Start at login"
  - "Cmd" + "Space" hotkey binding
  - "Spotlight" (disable macOS Spotlight's Cmd-Space)
  - "Pop to root"
  - "Auto-switch input source" disabled
  - explicit "Do NOT sign in" / "Account" guidance
```

**AC-4: Recommended extensions section includes the 7 curated items**
```
Given: macos-dev/raycast/extensions.md
When: Recommended extensions section inspected
Then: contains checklist items for ALL of:
  - Brew
  - GitHub
  - Kill Process
  - System
  - Clipboard History
  - Color Picker
  - Visual Studio Code
```

**AC-5: install-macos.sh Next-steps references raycast/extensions.md by path**
```
Given: macos-dev/install-macos.sh
When: the Next-steps heredoc inspected
Then: the path `raycast/extensions.md` appears literally
```

**AC-6: install-macos.sh Next-steps includes the /etc/hosts blackhole commands**
```
Given: macos-dev/install-macos.sh
When: the Next-steps heredoc inspected
Then: contains `backend.raycast.com`
And: contains `api.raycast.com`
And: contains `sync.raycast.com`
And: contains `0.0.0.0` (blackhole target)
And: these appear inside an "optional hardening" / "corporate Mac only" sub-item
```

**AC-7: docs/manual-smoke/desktop-layer3.md exists with a populated checklist**
```
Given: macos-dev/docs/manual-smoke/desktop-layer3.md
When: inspected
Then: file exists
And: contains `## When to run`
And: contains `## Checklist` with at least 6 `- [ ]` items covering:
     Cmd-Space launches Raycast, Spotlight inactive, at least one
     recommended extension installed + functional, sign-in blank
And: contains `## Failure modes` with at least 2 `- [ ]` drills
```

**AC-8: test-plan-desktop-layer3.sh is wired into CI verify.yml**
```
Given: the repository-root .github/workflows/verify.yml
When: inspected
Then: the `lint` job invokes `bash macos-dev/scripts/test-plan-desktop-layer3.sh`
And: the `macos-verify` job invokes the same
```

**AC-9: End-to-end acceptance script enumerates every AC**
```
When: `bash scripts/test-plan-desktop-layer3.sh` runs on macOS or Linux
Then: every AC above is checked (via check/skp)
And: exit code is 0 if fail == 0, 1 otherwise
```

---

## File Structure

**New directories:**
- `raycast/`

**New files (created by this plan):**
- `raycast/extensions.md`
- `docs/manual-smoke/desktop-layer3.md`
- `scripts/test-plan-desktop-layer3.sh`

**Modified files:**
- `Brewfile` — one cask line in a new "Desktop · launcher" section
- `install-macos.sh` — Next-steps additions only (no new symlinks, no new LaunchAgent)
- `.github/workflows/verify.yml` — wire `test-plan-desktop-layer3.sh` into lint + macos-verify

**Untouched (preserved):**
- All Layer 1 and Layer 2 files
- `tools.txt` — Raycast is a cask, no formula row (per §5.3 + the Layer 1 guard in check-tool-manifest.sh)
- `install-wsl.sh`
- `scripts/verify.sh` — Raycast is an app-in-~/Applications, the launcher has no symlink/LaunchAgent to verify; smoke is user-discretion only

---

## Task 0: Bootstrap Acceptance Test Script (Red)

**Files:**
- Create: `scripts/test-plan-desktop-layer3.sh`

- [ ] **Step 1: Copy the preamble from the shipped layer1a script**

Run: `sed -n '1,55p' scripts/test-plan-layer1a.sh > scripts/test-plan-desktop-layer3.sh`

- [ ] **Step 2: Patch the per-layer header lines**

Open `scripts/test-plan-desktop-layer3.sh` and edit:
- Line 2: `test-plan-desktop-layer3.sh — acceptance tests for Desktop Layer 3 (Raycast launcher)`
- Line 7: `bash scripts/test-plan-desktop-layer3.sh              # safe tests only`
- Line 8: `bash scripts/test-plan-desktop-layer3.sh --full       # + invasive tests`
- Line 10: `Each AC from the Desktop Layer 3 plan is implemented as a labelled check.`

- [ ] **Step 3: Append the header + summary + chmod**

Append:

```bash

echo "Desktop Layer 3 acceptance tests (Raycast launcher)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1..9 get appended by subsequent tasks ──────────────────────────

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
```

Then: `chmod +x scripts/test-plan-desktop-layer3.sh`

- [ ] **Step 4: Run — trivially green**

Run: `bash scripts/test-plan-desktop-layer3.sh`
Expected: 0/0/0, exit 0.

- [ ] **Step 5: Shellcheck**

Run: `shellcheck scripts/test-plan-desktop-layer3.sh`
Expected: silent.

- [ ] **Step 6: Commit**

```bash
git add scripts/test-plan-desktop-layer3.sh
git commit -m "test(desktop-layer3): scaffold acceptance test script (preamble only)"
```

---

## Task 1: Add Raycast cask to Brewfile (AC-1)

**Files:**
- Modify: `Brewfile`
- Modify: `scripts/test-plan-desktop-layer3.sh`

- [ ] **Step 1: Append AC-1 block to the test script**

```bash
# ── AC-1: Brewfile declares Raycast cask ─────────────────────────────
echo ""
echo "AC-1: Brewfile declares Raycast cask"
check "Brewfile has cask \"raycast\"" \
  grep -qE '^cask "raycast"' Brewfile
check "check-tool-manifest.sh still passes" \
  bash scripts/check-tool-manifest.sh
```

- [ ] **Step 2: Run tests — AC-1 fails**

- [ ] **Step 3: Append to Brewfile**

Append at the bottom (after the Layer 2 keyboard section):

```ruby

# ── Desktop · launcher (Layer 3 desktop) ──────────────────────────────
# Raycast replaces Spotlight on Cmd-Space. Cloud sync is forbidden on
# corporate devices — see raycast/extensions.md + install-macos.sh
# Next-steps for the /etc/hosts blackhole.
cask "raycast"
```

- [ ] **Step 4: Run tests — AC-1 passes**

- [ ] **Step 5: Commit**

```bash
git add Brewfile scripts/test-plan-desktop-layer3.sh
git commit -m "feat(brewfile): add Raycast cask (desktop layer 3)"
```

---

## Task 2: Create `raycast/extensions.md` (AC-2, AC-3, AC-4)

**Files:**
- Create: `raycast/extensions.md`
- Modify: `scripts/test-plan-desktop-layer3.sh`

- [ ] **Step 1: Append AC-2, AC-3, AC-4 blocks to the test script**

```bash
# ── AC-2: raycast/extensions.md two-section structure ────────────────
echo ""
echo "AC-2: raycast/extensions.md two-section structure"
check "file exists" test -f raycast/extensions.md
check "top-level '# Raycast' header" \
  grep -qE '^# Raycast' raycast/extensions.md
check "## Summary header" \
  grep -qE '^## Summary' raycast/extensions.md
check "## Post-install checklist header" \
  grep -qE '^## Post-install checklist' raycast/extensions.md
check "## Recommended extensions header" \
  grep -qE '^## Recommended extensions' raycast/extensions.md

# ── AC-3: Post-install checklist 8 documented steps ──────────────────
echo ""
echo "AC-3: Post-install checklist covers 8 documented steps"
checklist="$(awk '/^## Post-install checklist/,/^## Recommended extensions/' raycast/extensions.md)"
for needle in 'Launch Raycast' \
              'Accessibility' \
              'Start at login' \
              'Cmd.*Space' \
              'Spotlight' \
              'Pop to root' \
              'Auto-switch input source' \
              'sign.in\|Account'; do
  if printf '%s' "$checklist" | grep -qE "$needle"; then
    ok "checklist mentions: $needle"
  else
    nok "checklist mentions: $needle"
  fi
done

# ── AC-4: Recommended extensions — 7 curated items ──────────────────
echo ""
echo "AC-4: Recommended extensions lists 7 curated items"
recommended="$(awk '/^## Recommended extensions/,0' raycast/extensions.md)"
for ext in 'Brew' 'GitHub' 'Kill Process' 'System' 'Clipboard History' 'Color Picker' 'Visual Studio Code'; do
  if printf '%s' "$recommended" | grep -qF "$ext"; then
    ok "Recommended extensions lists: $ext"
  else
    nok "Recommended extensions lists: $ext"
  fi
done
```

- [ ] **Step 2: Run tests — AC-2, 3, 4 fail (file missing)**

- [ ] **Step 3: Create `raycast/extensions.md`**

```markdown
# Raycast — Layer 3 launcher

## Summary

Raycast replaces macOS Spotlight on Cmd-Space. Installed by Layer 3 of
the macOS desktop environment plan cycle. No repo-committed settings
(binary preferences + OAuth tokens are not source-controllable); this
file documents first-run setup and the curated extension list so any
fresh machine replicates the intended state.

Cloud sync is forbidden on corporate devices. Enforcement is three
layers deep (see design §7.6):

1. The post-install checklist below explicitly forbids signing in.
2. `install-macos.sh` Next-steps provides an optional `/etc/hosts`
   blackhole that nulls `backend.raycast.com`, `api.raycast.com`, and
   `sync.raycast.com` during the JIT-admin window.
3. If Raycast's user-writable preferences expose a sync toggle
   independent of sign-in, set it via `defaults write` post-first-run
   (probed at Layer 3 build time; skipped if no such key exists).

## Post-install checklist

Run once per fresh machine. Tick each box as you confirm it.

- [ ] Launch Raycast from `~/Applications/Raycast.app` (first launch
      triggers the Accessibility permission prompt).
- [ ] When prompted, grant Accessibility permission to Raycast
      (JIT admin). System Settings → Privacy & Security → Accessibility.
- [ ] Raycast preferences → General → "Start at login" → enabled.
- [ ] Raycast preferences → General → "Launch Raycast" hotkey →
      `Cmd + Space`.
- [ ] Accept macOS's prompt to disable Spotlight's Cmd-Space binding
      (or: System Settings → Keyboard → Keyboard Shortcuts →
      Spotlight → uncheck "Show Spotlight search").
- [ ] Raycast preferences → General → "Pop to root" → enabled.
- [ ] Raycast preferences → Advanced → "Auto-switch input source" →
      **disabled** (prevents input-method fights with kitty).
- [ ] **Do NOT sign in to a Raycast account.** Leave the "Account" pane
      blank. Signing in enables cloud sync of extensions, hotkeys, and
      snippets to Raycast's servers. On a corporate device this is
      typically prohibited without IT approval. See `install-macos.sh`
      Next-steps step 7 for the optional `/etc/hosts` blackhole that
      backs this up.

## Recommended extensions

Install each from the Raycast Store (Cmd-K → "Store").

- [ ] **Brew** — brew formula/cask install + upgrade surface from
      Cmd-Space. Complements the Brewfile-driven workflow.
- [ ] **GitHub** — PRs, issues, repos without leaving Cmd-Space.
      Complements the gh CLI / gh-dash shipped in Layer 1b-iii.
- [ ] **Kill Process** — pgrep + kill from the launcher.
      Complements the `kill $(pgrep <name>)` pattern from Layer 1b-i
      (rip was dropped; Raycast's Kill Process fills the GUI gap).
- [ ] **System** — screen lock, restart, sleep, empty trash.
- [ ] **Clipboard History** — `Cmd + Shift + V` brings up a searchable
      clipboard (Raycast-local, no cloud sync).
- [ ] **Color Picker** — Dracula palette eyedropper. Useful when
      tuning SketchyBar / JankyBorders colours against real macOS
      windows.
- [ ] **Visual Studio Code** — open recent projects by fuzzy match.
      Complements `repo` / `gclone` / Alt-R from Layer 1c.

## Notes

- Raycast's extensions themselves are NOT committed to this repo. Any
  extension that stores data (e.g. Clipboard History) keeps it locally.
- If Cmd-Space takeover fails silently after first launch, the documented
  fallback is Layer 2's `Hyper + Space` binding (skhd → `open -a Raycast`).
- To uninstall cleanly: quit Raycast, `rm -rf ~/Applications/Raycast.app`,
  `defaults delete com.raycast.macos`, `rm -rf ~/Library/Application\ Support/com.raycast.macos`.
```

- [ ] **Step 4: Run tests — AC-2, 3, 4 pass**

- [ ] **Step 5: Markdownlint (best-effort)**

Run: `markdownlint-cli2 raycast/extensions.md`
Expected: silent (or fix benign advisories).

- [ ] **Step 6: Commit**

```bash
git add raycast/extensions.md scripts/test-plan-desktop-layer3.sh
git commit -m "docs(raycast): add extensions.md with post-install checklist (desktop layer 3)"
```

---

## Task 3: install-macos.sh Next-steps additions (AC-5, AC-6)

**Files:**
- Modify: `install-macos.sh`
- Modify: `scripts/test-plan-desktop-layer3.sh`

- [ ] **Step 1: Append AC-5, AC-6 blocks**

```bash
# ── AC-5: Next-steps references raycast/extensions.md ────────────────
echo ""
echo "AC-5: install-macos.sh Next-steps references raycast/extensions.md"
next="$(awk '/Next steps:/,/EOF/' install-macos.sh)"
if printf '%s' "$next" | grep -qF 'raycast/extensions.md'; then
  ok "Next-steps mentions raycast/extensions.md"
else
  nok "Next-steps mentions raycast/extensions.md"
fi

# ── AC-6: Next-steps /etc/hosts blackhole commands ──────────────────
echo ""
echo "AC-6: Next-steps includes /etc/hosts blackhole for Raycast sync"
for domain in 'backend.raycast.com' 'api.raycast.com' 'sync.raycast.com'; do
  if printf '%s' "$next" | grep -qF "$domain"; then
    ok "Next-steps mentions $domain"
  else
    nok "Next-steps mentions $domain"
  fi
done
if printf '%s' "$next" | grep -qE '0\.0\.0\.0'; then
  ok "Next-steps uses 0.0.0.0 blackhole target"
else
  nok "Next-steps uses 0.0.0.0 blackhole target"
fi
```

- [ ] **Step 2: Run tests — AC-5, 6 fail**

- [ ] **Step 3: Extend the Next-steps heredoc with Raycast sub-items**

After Layer 2's edits, step 7 looks like this:
- (a) Launch AeroSpace
- (b) Accessibility grants (list already includes Raycast — added by Layer 1)
- (c) Hide native menu bar
- (d) Monitor-name capture
- (e) Hammerspoon login toggle
- (f) Karabiner upgrade path
- (g) `Walk docs/manual-smoke/desktop-layer{1,2}.md at your cadence.`

Layer 3 inserts TWO new sub-items BEFORE (g) and renumbers (g) to reference all three layers. Verify current state: `grep -n "Walk docs/manual-smoke" install-macos.sh`.

Replace the existing (g) line:

```
     g) Walk docs/manual-smoke/desktop-layer{1,2}.md at your cadence.
```

With three new lines (g)/(h)/(i):

```
     g) Launch Raycast from ~/Applications/Raycast.app. First launch
        prompts for Accessibility — grant in the same JIT-admin window
        as AeroSpace/skhd/Hammerspoon. Prefs: Start at login on,
        Cmd+Space hotkey, Pop to root on, Auto-switch input source off.
        Do NOT sign in. See raycast/extensions.md for the 8-step
        post-install checklist and the 7-extension curated list.
     h) (Corporate Mac — optional) Within the same JIT admin window,
        null Raycast sync endpoints via /etc/hosts (defense in depth
        on top of the no-sign-in rule):
          sudo tee -a /etc/hosts >/dev/null <<EOF
          0.0.0.0  backend.raycast.com
          0.0.0.0  api.raycast.com
          0.0.0.0  sync.raycast.com
          EOF
     i) Walk docs/manual-smoke/desktop-layer{1,2,3}.md at your cadence.
```

(The `{1,2,3}` glob form in (i) is shell-expandable: the user runs `ls docs/manual-smoke/desktop-layer{1,2,3}.md` to list all three checklists.)

- [ ] **Step 4: Shellcheck install-macos.sh**

Run: `shellcheck install-macos.sh`
Expected: silent.

- [ ] **Step 5: Run tests — AC-5, 6 pass**

- [ ] **Step 6: Commit**

```bash
git add install-macos.sh scripts/test-plan-desktop-layer3.sh
git commit -m "feat(install-macos): add Raycast Next-steps + /etc/hosts blackhole (desktop layer 3)"
```

---

## Task 4: Create `docs/manual-smoke/desktop-layer3.md` (AC-7)

**Files:**
- Create: `docs/manual-smoke/desktop-layer3.md`
- Modify: `scripts/test-plan-desktop-layer3.sh`

- [ ] **Step 1: Append AC-7 block**

```bash
# ── AC-7: manual-smoke/desktop-layer3.md populated ──────────────────
echo ""
echo "AC-7: manual-smoke/desktop-layer3.md populated"
check "file exists" test -f docs/manual-smoke/desktop-layer3.md
check "has 'When to run' section" \
  grep -qE '^## When to run' docs/manual-smoke/desktop-layer3.md
check "has 'Checklist' section" \
  grep -qE '^## Checklist' docs/manual-smoke/desktop-layer3.md
check "has 'Failure modes' section" \
  grep -qE '^## Failure modes' docs/manual-smoke/desktop-layer3.md
checklist_items=$(awk '/^## Checklist/,/^## Failure modes/' docs/manual-smoke/desktop-layer3.md \
                  | grep -cE '^- \[ \]')
failure_items=$(awk '/^## Failure modes/,0' docs/manual-smoke/desktop-layer3.md \
               | grep -cE '^- \[ \]')
if (( checklist_items >= 6 )); then
  ok "checklist has ≥ 6 items ($checklist_items)"
else
  nok "checklist has ≥ 6 items ($checklist_items)"
fi
if (( failure_items >= 2 )); then
  ok "failure modes has ≥ 2 drill items ($failure_items)"
else
  nok "failure modes has ≥ 2 drill items ($failure_items)"
fi
```

- [ ] **Step 2: Run tests — AC-7 fails**

- [ ] **Step 3: Create `docs/manual-smoke/desktop-layer3.md`**

```markdown
# Manual smoke — Desktop Layer 3 (Raycast)

Track runtime behaviour that CI cannot observe. Tick each box as you
confirm it.

## When to run

- First install on a new machine.
- After every `install-macos.sh` re-run that modifies Layer 3 Next-steps.
- After every Raycast version bump (brew bundle output lists the delta).

## Checklist

- [ ] Raycast is installed at `~/Applications/Raycast.app` (not
      `/Applications/Raycast.app` — corporate `/Applications` is
      MDM-locked and `HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"`
      was exported by Layer 1).
- [ ] `Cmd + Space` opens Raycast (not Spotlight).
- [ ] Spotlight's Cmd-Space binding is disabled (System Settings →
      Keyboard → Keyboard Shortcuts → Spotlight → "Show Spotlight
      search" unchecked).
- [ ] Raycast has Accessibility permission (prerequisite for window
      actions and for Clipboard History to capture).
- [ ] Raycast is set to Launch at Login.
- [ ] "Pop to root" is enabled — pressing `Cmd + Space` while Raycast
      is open drops back to the root query.
- [ ] "Auto-switch input source" is disabled (no input-method fights
      with kitty).
- [ ] **Sign-in is blank.** Raycast preferences → Account shows no
      logged-in user.
- [ ] At least one recommended extension installed and functional:
      `Cmd + Space` → type "brew" (if Brew extension is installed) or
      "code" (Visual Studio Code extension) and confirm results surface.
- [ ] (Corporate hardening applied) `grep -E 'raycast\.com' /etc/hosts`
      shows the three blackhole entries. (Skip if running on a personal
      machine.)
- [ ] `Hyper + Space` (from Layer 2) also opens Raycast — this is the
      documented fallback if Cmd-Space takeover ever fails.

## Failure modes

### Cmd-Space takeover loses to Spotlight
- [ ] After reboot, `Cmd + Space` opens Spotlight instead of Raycast.
      Fix: Raycast preferences → Re-assign the hotkey; accept the
      macOS prompt to take over Spotlight. If the prompt doesn't
      surface, manually untick Spotlight in System Settings → Keyboard
      → Keyboard Shortcuts → Spotlight.

### Sign-in sneaks in
- [ ] Raycast preferences → Account shows a logged-in user.
      Fix: log out; verify `grep raycast.com /etc/hosts` shows the
      blackhole entries are still present; restart Raycast.

### Accessibility revocation
- [ ] System Settings → Privacy → Accessibility → Raycast unticked.
      Clipboard History stops capturing; window actions fail.
      Fix: re-tick Accessibility; restart Raycast.
```

- [ ] **Step 4: Run tests — AC-7 passes**

- [ ] **Step 5: Commit**

```bash
git add docs/manual-smoke/desktop-layer3.md scripts/test-plan-desktop-layer3.sh
git commit -m "docs(manual-smoke): add Desktop Layer 3 checklist"
```

---

## Task 5: Wire `test-plan-desktop-layer3.sh` into CI (AC-8)

**Files:**
- Modify: `../.github/workflows/verify.yml` (repository root)
- Modify: `scripts/test-plan-desktop-layer3.sh`

- [ ] **Step 1: Append AC-8 block**

```bash
# ── AC-8: test-plan-desktop-layer3.sh wired into CI ──────────────────
echo ""
echo "AC-8: test-plan-desktop-layer3.sh wired into verify.yml"
REPO_ROOT="$(cd "$MACOS_DEV/.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/verify.yml"
if [[ -f "$WORKFLOW" ]]; then
  hits=$(grep -c 'test-plan-desktop-layer3.sh' "$WORKFLOW" || true)
  if (( hits >= 2 )); then
    ok "verify.yml invokes test-plan-desktop-layer3.sh ($hits times)"
  else
    nok "verify.yml invokes test-plan-desktop-layer3.sh ($hits times; need ≥ 2)"
  fi
else
  skp "verify.yml wiring" "workflow not found"
fi
```

- [ ] **Step 2: Run tests — AC-8 fails**

- [ ] **Step 3: Edit the CI workflow**

Open `/home/sweeand/andrewesweet/setup/.github/workflows/verify.yml`. Locate the `Desktop Layer 2 smoke tests` step added by Layer 2 in both the `lint` and `macos-verify` jobs. AFTER each occurrence, insert:

```yaml
      - name: Desktop Layer 3 smoke tests
        run: bash macos-dev/scripts/test-plan-desktop-layer3.sh
```

- [ ] **Step 4: Validate YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('/home/sweeand/andrewesweet/setup/.github/workflows/verify.yml'))"`
Expected: exit 0.

- [ ] **Step 5: Run tests — AC-8 passes**

- [ ] **Step 6: Commit (cross-directory)**

```bash
git -C "$(cd .. && pwd)" add .github/workflows/verify.yml
git add scripts/test-plan-desktop-layer3.sh
git commit -m "ci(verify): wire test-plan-desktop-layer3.sh into lint + macos-verify"
```

---

## Task 6: Final AC-9 wrapper + full-repo gates

**Files:** (none modified — validation only)

- [ ] **Step 1: AC-9 structural check**

AC-9 is the `(( fail == 0 ))` gate — no additional block needed. Run:

```bash
bash scripts/test-plan-desktop-layer3.sh
```

Expected: all 9 ACs pass, exit 0.

- [ ] **Step 2: Repo-wide shellcheck pass**

```bash
find . -type f -name '*.sh' -not -path './.worktrees/*' -print0 \
  | xargs -0 shellcheck
```

Expected: silent.

- [ ] **Step 3: All other test-plans still pass**

```bash
for f in scripts/test-plan*.sh; do
  bash "$f" >/dev/null 2>&1 || echo "FAIL: $f"
done
```

Expected: no "FAIL:" lines (including `test-plan-desktop-layer1.sh` and `test-plan-desktop-layer2.sh`).

- [ ] **Step 4: YAML lint**

```bash
python3 -c "import yaml; yaml.safe_load(open('/home/sweeand/andrewesweet/setup/.github/workflows/verify.yml'))"
```

Expected: exit 0.

---

## Execution notes

- Rebase on the latest `main` (post-Layer 2) before starting. Predictable conflicts: `Brewfile` (new section stacks), `install-macos.sh` (Layer 2's Next-steps numbering is extended again), `.github/workflows/verify.yml`. Resolve by keeping both layers' entries in order.
- This is the smallest layer — ~7 tasks, mostly mechanical. Dispatch review subagents only for Task 3 (the Next-steps numbering across layers is easy to mis-order).
- `tools.txt` is NOT modified — Raycast is a cask and the Layer 1 guard in `check-tool-manifest.sh` makes the tools.txt mirror unnecessary. If the guard were ever reverted, Raycast would need a row `raycast brew:raycast apt:- apk:-`.
- `scripts/verify.sh` is NOT modified — Raycast has no symlink or LaunchAgent to spot-check. The manual smoke checklist (Task 4) is the only runtime surface.
- `/etc/hosts` editing remains user-discretion. The install script does NOT sudo-automate it; the design (§7) explicitly keeps all sudo-gated operations manual.
- Convention #12 (pre-existing untracked files on main): `git add <specific-files>` per task; never `git add -A`.
