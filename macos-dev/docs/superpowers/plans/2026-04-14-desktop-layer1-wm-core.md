# Desktop Layer 1 Implementation Plan: WM core (AeroSpace + SketchyBar + JankyBorders)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the core macOS desktop — AeroSpace tiling WM, 9-item SketchyBar pinned to the primary external monitor, JankyBorders focus indicator — all themed with the Dracula Pro palette, installing cleanly on a managed corporate Mac without standing admin.

**Architecture:** AeroSpace (cask, login item) emits `exec-on-workspace-change` triggers consumed by SketchyBar's `workspaces` item. SketchyBar (formula, LaunchAgent) and JankyBorders (formula, LaunchAgent) follow the Podman-machine plist precedent: `@HOMEBREW_PREFIX@`/`@HOME@` markers in `launchagents/*.plist`, sed-substituted at install time, `launchctl bootout || true` then `launchctl bootstrap`. Four numbered workspaces (term/edge/comms/scratch) with priority-list monitor assignment via placeholders that the user substitutes post-install at each dock location. `sketchybar/colors.sh` is the single Dracula source of truth; `jankyborders/bordersrc` sources it.

**Tech Stack:** bash 5, AeroSpace (TOML), SketchyBar (shell plugins), JankyBorders (argv-configured), LaunchAgents, Homebrew (casks to `~/Applications/`), Python 3 tomllib, plutil, jq, pgrep.

**Spec reference:** `docs/plans/2026-04-14-macos-desktop-env-design.md` §2, §3.1, §3.2, §3.3, §4.1, §5.1, §5.2, §5.3, §5.4, §5.5, §5.6, §6, §7, Appendix A, Appendix C.

**Platform scope:** macOS only (static checks pass on Linux via `skp`). WSL install untouched.

**Prerequisite:** Shell layers 1a/1b/1c merged. This plan is independent of Layers 2 and 3.

---

## Acceptance Criteria (Specification by Example)

Each bullet is a testable assertion. The acceptance test script `scripts/test-plan-desktop-layer1.sh` validates every assertion end-to-end.

**AC-1: Brewfile declares AeroSpace cask and tap**
```
Given: macos-dev/Brewfile
When: inspected
Then: contains the line `tap "nikitabobko/tap"`
And: contains the line `cask "nikitabobko/tap/aerospace"`
```

**AC-2: Brewfile declares SketchyBar + JankyBorders + tap**
```
Given: macos-dev/Brewfile
When: inspected
Then: contains `tap "FelixKratz/formulae"`
And: contains `brew "sketchybar"`
And: contains `brew "FelixKratz/formulae/borders"`
```

**AC-3: tools.txt declares the two new formulae**
```
Given: macos-dev/tools.txt
When: inspected
Then: contains a `brew:sketchybar` row
And: contains a `brew:FelixKratz/formulae/borders` row
```

**AC-4: check-tool-manifest.sh skips `cask` lines after the Layer 1 guard is added**
```
Given: a Brewfile with `cask "nikitabobko/tap/aerospace"` and NO matching tools.txt entry
When: `bash scripts/check-tool-manifest.sh` runs
Then: exit 0 (casks are not required in tools.txt)
```

**AC-5: install-macos.sh exports `HOMEBREW_CASK_OPTS` and creates `~/Applications`**
```
Given: macos-dev/install-macos.sh
When: inspected
Then: contains `mkdir -p "$HOME/Applications"`
And: contains `HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"` with `export`
And: both lines appear BEFORE the `brew bundle` invocation
```

**AC-6: aerospace/aerospace.toml parses as valid TOML**
```
Given: macos-dev/aerospace/aerospace.toml
When: `python3 -c "import tomllib, sys; tomllib.load(open(sys.argv[1], 'rb'))" aerospace/aerospace.toml`
Then: exit 0
```

**AC-7: aerospace.toml sets the core root-container + gap + login settings**
```
Given: macos-dev/aerospace/aerospace.toml
When: inspected
Then: contains `start-at-login = true`
And: contains `default-root-container-layout = 'tiles'`
And: contains `default-root-container-orientation = 'auto'`
And: contains `accordion-padding = 30`
And: `[gaps.outer]` top value is `36`
```

**AC-8: aerospace.toml declares all required `[mode.main.binding]` entries**
```
Given: macos-dev/aerospace/aerospace.toml
When: inspected
Then: `[mode.main.binding]` section exists
And: alt-1..alt-4 bindings map to `workspace 1..4`
And: alt-shift-1..alt-shift-4 map to `move-node-to-workspace 1..4`
And: alt-h/alt-j/alt-k/alt-l map to `focus left/down/up/right`
And: alt-shift-h/alt-shift-j/alt-shift-k/alt-shift-l map to `move left/down/up/right`
And: alt-slash, alt-comma, alt-f, alt-shift-space are present
```

**AC-9: aerospace.toml has `[[on-window-detected]]` pinning for kitty, Edge, Teams, Outlook**
```
Given: macos-dev/aerospace/aerospace.toml
When: inspected
Then: four `[[on-window-detected]]` blocks exist
And: one matches `app-id = 'net.kovidgoyal.kitty'` assigning workspace 1
And: one matches Microsoft Edge (`com.microsoft.edgemac`) assigning workspace 2
And: one matches Microsoft Teams (`com.microsoft.teams2`) assigning workspace 3
And: one matches Microsoft Outlook (`com.microsoft.Outlook`) assigning workspace 3
```

**AC-10: aerospace.toml has `[workspace-to-monitor-force-assignment]` with placeholders**
```
Given: macos-dev/aerospace/aerospace.toml
When: inspected
Then: `[workspace-to-monitor-force-assignment]` section exists
And: workspace 1 list contains `<office-central-monitor-name>` and `<home-centre-monitor-name>`
And: workspace 2 list contains `<office-central-monitor-name>` and `built-in`
And: workspace 3 list contains `<home-left-monitor-name>` and `built-in`
And: workspace 4 is absent (deliberately — scratch follows focused monitor)
```

**AC-11: aerospace.toml's `exec-on-workspace-change` uses the `@HOMEBREW_PREFIX@` marker**
```
Given: macos-dev/aerospace/aerospace.toml
When: inspected
Then: `exec-on-workspace-change` is declared
And: the sketchybar invocation path contains `@HOMEBREW_PREFIX@/bin/sketchybar`
And: `aerospace_workspace_change` appears as the trigger name
```

**AC-12: sketchybar/colors.sh exports the 12 Dracula hex constants**
```
Given: macos-dev/sketchybar/colors.sh
When: inspected
Then: exports `COLOR_BG=0xff282A36`
And: exports `COLOR_CURRENT_LINE=0xff44475A`
And: exports `COLOR_SELECTION=0xff44475A`
And: exports `COLOR_FG=0xfff8f8f2` (or `0xffF8F8F2` — case-insensitive match)
And: exports `COLOR_COMMENT=0xff6272A4`
And: exports `COLOR_RED=0xffFF5555`
And: exports `COLOR_ORANGE=0xffFFB86C`
And: exports `COLOR_YELLOW=0xffF1FA8C`
And: exports `COLOR_GREEN=0xff50FA7B`
And: exports `COLOR_CYAN=0xff8BE9FD`
And: exports `COLOR_PURPLE=0xffBD93F9`
And: exports `COLOR_PINK=0xffFF79C6`
```

**AC-13: sketchybar/icons.sh exports at least 9 Nerd Font glyph constants**
```
Given: macos-dev/sketchybar/icons.sh
When: inspected
Then: at least 9 `ICON_*=` assignments are declared at top level
And: includes ICON_WIFI, ICON_BATTERY, ICON_VOLUME, ICON_CLOCK, ICON_ZSCALER, ICON_FOCUS (at minimum)
```

**AC-14: sketchybar/sketchybarrc sources palette + icons and configures the bar**
```
Given: macos-dev/sketchybar/sketchybarrc
When: inspected
Then: sources colors.sh via `source "$CONFIG_DIR/colors.sh"`
And: sources icons.sh via `source "$CONFIG_DIR/icons.sh"`
And: calls `sketchybar --bar` with `height=30`, `position=top`, `color=$COLOR_BG`
And: sets `display=<primary-external-name>` placeholder (literal; user substitutes)
And: adds 9 items total (workspaces, focused_app, zscaler, focus_mode, wifi, volume, battery, clock, plus the `workspaces` event subscribe)
```

**AC-15: sketchybar/plugins/*.sh files are all shellcheck-clean at default severity**
```
Given: every file under macos-dev/sketchybar/plugins/
When: `shellcheck` is run against each with default flags
Then: exit 0 for every file
```

**AC-16: zscaler.sh uses `pgrep -qx ZscalerTunnel`**
```
Given: macos-dev/sketchybar/plugins/zscaler.sh
When: function bodies inspected (comments stripped)
Then: contains the literal string `pgrep -qx ZscalerTunnel`
```

**AC-17: focus_mode.sh reads `~/Library/DoNotDisturb/DB/Assertions.json` with a `jq -e` guard**
```
Given: macos-dev/sketchybar/plugins/focus_mode.sh
When: function bodies inspected (comments stripped)
Then: references `Library/DoNotDisturb/DB/Assertions.json`
And: contains `jq -e`
And: falls back to rendering `drawing=off` or empty label if jq fails
```

**AC-18: jankyborders/bordersrc sources colors.sh and invokes borders with Dracula colours**
```
Given: macos-dev/jankyborders/bordersrc
When: inspected
Then: sources `$HOME/.config/sketchybar/colors.sh`
And: invokes `borders` with `active_color="$COLOR_PURPLE"`
And: invokes `borders` with `inactive_color="$COLOR_CURRENT_LINE"`
And: declares `style=round` and `hidpi=on`
```

**AC-19: launchagents/*.plist files are plutil-lint clean + use `@HOMEBREW_PREFIX@`/`@HOME@` markers**
```
Given: macos-dev/launchagents/com.felixkratz.sketchybar.plist
And: macos-dev/launchagents/com.felixkratz.borders.plist
When: `plutil -lint <path>` is run (skp on Linux)
Then: exit 0 for both files
And: each plist's ProgramArguments contains `@HOMEBREW_PREFIX@/bin/<tool>`
And: each plist's StandardOutPath / StandardErrorPath contains `@HOME@`
```

**AC-20: install-macos.sh symlinks all new Layer 1 configs**
```
Given: macos-dev/install-macos.sh
When: inspected
Then: contains a `link aerospace/aerospace.toml .config/aerospace/aerospace.toml`
And: contains a `link sketchybar/sketchybarrc .config/sketchybar/sketchybarrc`
And: contains a `link sketchybar/colors.sh .config/sketchybar/colors.sh`
And: contains a `link sketchybar/icons.sh .config/sketchybar/icons.sh`
And: contains a `link sketchybar/plugins .config/sketchybar/plugins` (directory-level)
And: contains a `link jankyborders/bordersrc .config/borders/bordersrc`
```

**AC-21: install-macos.sh substitutes plist markers and bootstraps the LaunchAgents**
```
Given: macos-dev/install-macos.sh
When: inspected
Then: iterates over com.felixkratz.sketchybar.plist and com.felixkratz.borders.plist
And: sed-substitutes `@HOMEBREW_PREFIX@` and `@HOME@` into each plist
And: calls `launchctl bootout "gui/$(id -u)/<label>" 2>/dev/null || true`
And: then calls `launchctl bootstrap "gui/$(id -u)" "$plist_dst"`
And: guards the block with `if [[ "$(uname)" == "Darwin" ]]`
```

**AC-22: install-macos.sh Next-steps output mentions the desktop first-run sequence**
```
Given: macos-dev/install-macos.sh
When: inspected
Then: Next-steps heredoc mentions "Accessibility" with AeroSpace
And: Next-steps heredoc mentions "aerospace list-monitors" with placeholder substitution
And: Next-steps heredoc mentions the _HIHideMenuBar hint or native-menubar hiding
```

**AC-23: docs/manual-smoke/desktop-layer1.md exists with a populated checklist**
```
Given: macos-dev/docs/manual-smoke/desktop-layer1.md
When: inspected
Then: file exists
And: contains a "## When to run" section
And: contains a "## Checklist" section with at least 10 `- [ ]` items covering: bar renders on primary external, 9 items render, workspaces switch on Alt-1..4, monitor pinning at office + home, focused app updates, focus indicator purple, SketchyBar respawn after kill
And: contains a "## Failure modes" section with at least 3 `- [ ]` drill items
```

**AC-24: test-plan-desktop-layer1.sh is wired into CI verify.yml**
```
Given: the repository-root .github/workflows/verify.yml
When: inspected
Then: the `lint` job invokes `bash macos-dev/scripts/test-plan-desktop-layer1.sh`
And: the `macos-verify` job invokes `bash macos-dev/scripts/test-plan-desktop-layer1.sh`
```

**AC-25: End-to-end acceptance script enumerates every AC**
```
When: `bash scripts/test-plan-desktop-layer1.sh` runs on macOS or WSL/Linux
Then: every AC above is checked (via check/skp)
And: exit code is 0 if fail == 0, 1 otherwise
```

---

## File Structure

**New directories:**
- `aerospace/` — TOML config
- `sketchybar/` with `plugins/` subdirectory
- `jankyborders/` — bordersrc
- `launchagents/` — shared home for all future desktop-layer plists
- `docs/manual-smoke/` — first use; Layers 2/3 extend it

**New files (created by this plan):**
- `aerospace/aerospace.toml`
- `sketchybar/colors.sh`
- `sketchybar/icons.sh`
- `sketchybar/sketchybarrc`
- `sketchybar/plugins/workspaces.sh`
- `sketchybar/plugins/focused_app.sh`
- `sketchybar/plugins/zscaler.sh`
- `sketchybar/plugins/focus_mode.sh`
- `sketchybar/plugins/wifi.sh`
- `sketchybar/plugins/volume.sh`
- `sketchybar/plugins/battery.sh`
- `sketchybar/plugins/clock.sh`
- `jankyborders/bordersrc`
- `launchagents/com.felixkratz.sketchybar.plist`
- `launchagents/com.felixkratz.borders.plist`
- `docs/manual-smoke/desktop-layer1.md`
- `scripts/test-plan-desktop-layer1.sh`

**Modified files:**
- `Brewfile` — add new sections (§5.2)
- `tools.txt` — add sketchybar + borders rows (§5.3)
- `scripts/check-tool-manifest.sh` — skip `cask` lines (§5.4)
- `install-macos.sh` — HOMEBREW_CASK_OPTS, symlink block, LaunchAgent bootstrap loop, Next-steps additions (§5.1)
- `scripts/verify.sh` — macOS-gated Layer 1 desktop smoke checks (§5.5)
- `.github/workflows/verify.yml` — wire `test-plan-desktop-layer1.sh` into lint + macos-verify jobs (§6.1)

**Untouched (preserved):**
- All Layer 1a/1b/1c shell configs (never touched)
- `install-wsl.sh`
- Every existing test-plan-*.sh file

---

## Task 0: Bootstrap Acceptance Test Script (Red)

Create the test-plan skeleton with the preamble copied byte-for-byte from `scripts/test-plan-layer1a.sh` lines 1–55. Add header, self-resolve, platform detection, colour setup, counters, `ok`/`nok`/`skp`/`check` helpers.

**Files:**
- Create: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Copy the preamble from the shipped layer1a script**

Run: `sed -n '1,55p' scripts/test-plan-layer1a.sh > scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 2: Patch the per-layer header lines**

Open `scripts/test-plan-desktop-layer1.sh` and edit:
- Line 2: change `test-plan-layer1a.sh — acceptance tests for Layer 1a (atuin + television + starship Dracula)` to `test-plan-desktop-layer1.sh — acceptance tests for Desktop Layer 1 (AeroSpace + SketchyBar + JankyBorders)`
- Line 7: change `bash scripts/test-plan-layer1a.sh              # safe tests only` to `bash scripts/test-plan-desktop-layer1.sh              # safe tests only`
- Line 8: change `bash scripts/test-plan-layer1a.sh --full       # + invasive tests (bash -lc init checks)` to `bash scripts/test-plan-desktop-layer1.sh --full       # + invasive tests (brew, plutil, python tomllib)`
- Line 10: change `Each AC from the Layer 1a plan is implemented as a labelled check.` to `Each AC from the Desktop Layer 1 plan is implemented as a labelled check.`

- [ ] **Step 3: Append the header echoes, the final summary, and chmod**

Append (after line 55) the following body:

```bash

echo "Desktop Layer 1 acceptance tests (AeroSpace + SketchyBar + JankyBorders)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1..25 get appended by subsequent tasks ─────────────────────────

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
```

Then: `chmod +x scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 4: Run — passes trivially (no ACs yet)**

Run: `bash scripts/test-plan-desktop-layer1.sh`
Expected: 0/0/0 pass, exit 0.

- [ ] **Step 5: Shellcheck-clean the new script**

Run: `shellcheck scripts/test-plan-desktop-layer1.sh`
Expected: silent (exit 0).

- [ ] **Step 6: Commit**

```bash
git add scripts/test-plan-desktop-layer1.sh
git commit -m "test(desktop-layer1): scaffold acceptance test script (preamble only)"
```

---

## Task 1: Update `check-tool-manifest.sh` to skip `cask` lines (AC-4)

The current script enforces that every `cask "..."` in Brewfile has a matching `brew:...` row in tools.txt. The design (§5.3, §5.4) specifies casks should be Brewfile-only going forward. Add a guard so AeroSpace / Hammerspoon / Raycast don't require tools.txt rows.

**Files:**
- Modify: `scripts/check-tool-manifest.sh` (line 31 region)
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Append the AC-4 block to the test script**

Insert before the final summary block in `scripts/test-plan-desktop-layer1.sh`:

```bash
# ── AC-4: check-tool-manifest.sh skips cask lines ──────────────────────
echo ""
echo "AC-4: check-tool-manifest.sh skips cask lines"
# Build a fake Brewfile with a cask but no matching tools.txt entry;
# require check-tool-manifest.sh exits 0. Uses a temp dir under /tmp
# so we don't pollute the repo.
tmp=$(mktemp -d)
cat >"$tmp/Brewfile" <<'EOF'
brew "ghq"
cask "nonexistent-cask-for-test"
EOF
cp tools.txt "$tmp/tools.txt"
# Run the manifest script with REPO_ROOT spoofed via working directory.
# The script uses $(dirname "$0")/.. — so place a symlink to the real
# script under a fake scripts/ dir whose parent is $tmp.
mkdir -p "$tmp/scripts"
ln -sf "$(cd "$MACOS_DEV/scripts" && pwd)/check-tool-manifest.sh" "$tmp/scripts/check-tool-manifest.sh"
if bash "$tmp/scripts/check-tool-manifest.sh" >/dev/null 2>&1; then
  ok "check-tool-manifest.sh skips cask lines (unmatched cask passes)"
else
  nok "check-tool-manifest.sh skips cask lines (unmatched cask passes)"
fi
rm -rf "$tmp"
```

- [ ] **Step 2: Run tests — AC-4 fails**

Run: `bash scripts/test-plan-desktop-layer1.sh`
Expected: AC-4 fails (current script matches cask lines).

- [ ] **Step 3: Edit `scripts/check-tool-manifest.sh` line 30-33**

Replace:

```bash
brewfile_formulas=$(
  grep -E '^(brew|cask) "' "$BREWFILE" \
    | sed -E 's/^(brew|cask) "([^"]+)".*/\2/'
)
```

With (brew-only; cask lines intentionally skipped — design §5.3):

```bash
# Casks are intentionally skipped — they are Brewfile-only per design
# docs/plans/2026-04-14-macos-desktop-env-design.md §5.3 / §5.4.
# tools.txt is the formula manifest, not the full Brewfile mirror.
brewfile_formulas=$(
  grep -E '^brew "' "$BREWFILE" \
    | sed -E 's/^brew "([^"]+)".*/\1/'
)
```

- [ ] **Step 4: Run the real manifest script against the real tree**

Run: `bash scripts/check-tool-manifest.sh`
Expected: exit 0 (existing brew formulae still validate).

- [ ] **Step 5: Re-run the layer test — AC-4 passes**

Run: `bash scripts/test-plan-desktop-layer1.sh`
Expected: AC-4 passes (the temp-dir unmatched-cask scenario now exits 0).

- [ ] **Step 6: Shellcheck the modified script**

Run: `shellcheck scripts/check-tool-manifest.sh`
Expected: silent (exit 0).

- [ ] **Step 7: Commit**

```bash
git add scripts/check-tool-manifest.sh scripts/test-plan-desktop-layer1.sh
git commit -m "feat(check-tool-manifest): skip cask lines (desktop layer 1 prep)"
```

---

## Task 2: Add Desktop Layer 1 sections to Brewfile + tools.txt (AC-1, AC-2, AC-3)

**Files:**
- Modify: `Brewfile`
- Modify: `tools.txt`
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Append AC-1, AC-2, AC-3 blocks to the test script**

Insert before the final summary block:

```bash
# ── AC-1: Brewfile declares AeroSpace cask + tap ──────────────────────
echo ""
echo "AC-1: Brewfile declares AeroSpace cask and tap"
check "Brewfile has tap \"nikitabobko/tap\"" \
  grep -qE '^tap "nikitabobko/tap"' Brewfile
check "Brewfile has cask \"nikitabobko/tap/aerospace\"" \
  grep -qE '^cask "nikitabobko/tap/aerospace"' Brewfile

# ── AC-2: Brewfile declares SketchyBar + JankyBorders + tap ──────────
echo ""
echo "AC-2: Brewfile declares SketchyBar + JankyBorders"
check "Brewfile has tap \"FelixKratz/formulae\"" \
  grep -qE '^tap "FelixKratz/formulae"' Brewfile
check "Brewfile has brew \"sketchybar\"" \
  grep -qE '^brew "sketchybar"' Brewfile
check "Brewfile has brew \"FelixKratz/formulae/borders\"" \
  grep -qE '^brew "FelixKratz/formulae/borders"' Brewfile

# ── AC-3: tools.txt declares the two new formulae ────────────────────
echo ""
echo "AC-3: tools.txt declares the two new formulae"
check "tools.txt has brew:sketchybar row" \
  grep -qE '^sketchybar[[:space:]]+brew:sketchybar' tools.txt
check "tools.txt has brew:FelixKratz/formulae/borders row" \
  grep -qE '^borders[[:space:]]+brew:FelixKratz/formulae/borders' tools.txt
check "check-tool-manifest.sh still passes" \
  bash scripts/check-tool-manifest.sh
```

- [ ] **Step 2: Run tests — AC-1, 2, 3 all fail**

Run: `bash scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 3: Append the Brewfile desktop sections**

Open `Brewfile` and append (at the bottom, after the existing VS Code cask section):

```ruby

# ── Desktop · window manager (Layer 1 desktop) ────────────────────────
# AeroSpace is pre-1.0 (semver disclaims backwards compatibility).
# Pin the minimum version in this comment if breaking changes are seen:
#   Last verified compatible: AeroSpace 0.x.y (check nikitabobko/aerospace releases)
tap "nikitabobko/tap"
cask "nikitabobko/tap/aerospace"

# ── Desktop · status bar & focus indicator (Layer 1 desktop) ──────────
tap "FelixKratz/formulae"
brew "sketchybar"
brew "FelixKratz/formulae/borders"
```

- [ ] **Step 4: Append the tools.txt desktop section**

Open `tools.txt` and append at the bottom (preserving the 21/27/19-column alignment used elsewhere):

```
# ── Desktop (macOS-only formulae — Layer 1 desktop) ─────────────────────────
sketchybar           brew:sketchybar                             apt:-                   apk:-
borders              brew:FelixKratz/formulae/borders            apt:-                   apk:-
```

(Casks are intentionally absent — see §5.3 of the design and the `check-tool-manifest.sh` guard added in Task 1.)

- [ ] **Step 5: Run the manifest check**

Run: `bash scripts/check-tool-manifest.sh`
Expected: exit 0.

- [ ] **Step 6: Run the layer test**

Run: `bash scripts/test-plan-desktop-layer1.sh`
Expected: AC-1, 2, 3 now pass.

- [ ] **Step 7: Commit**

```bash
git add Brewfile tools.txt scripts/test-plan-desktop-layer1.sh
git commit -m "feat(brewfile): add AeroSpace, SketchyBar, JankyBorders (desktop layer 1)"
```

---

## Task 3: install-macos.sh `HOMEBREW_CASK_OPTS` + `~/Applications` (AC-5)

**Files:**
- Modify: `install-macos.sh`
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Append AC-5 block to the test script**

```bash
# ── AC-5: install-macos.sh configures ~/Applications cask path ────────
echo ""
echo "AC-5: install-macos.sh sets HOMEBREW_CASK_OPTS"
check "install-macos.sh has mkdir -p \"\$HOME/Applications\"" \
  grep -qE 'mkdir -p[[:space:]]+"\$HOME/Applications"' install-macos.sh
check "install-macos.sh exports HOMEBREW_CASK_OPTS with --appdir" \
  grep -qE 'export[[:space:]]+HOMEBREW_CASK_OPTS=".*--appdir=\$HOME/Applications"' install-macos.sh
# Verify the mkdir line precedes the `brew bundle` invocation.
# grep -n emits "<line>:<text>"; strip suffix and compare.
mkdir_line="$(grep -nE 'mkdir -p[[:space:]]+"\$HOME/Applications"' install-macos.sh | head -1 | cut -d: -f1)"
brew_bundle_line="$(grep -nE '^if[[:space:]]+!.*brew bundle' install-macos.sh | head -1 | cut -d: -f1)"
if [[ -n "$mkdir_line" && -n "$brew_bundle_line" && "$mkdir_line" -lt "$brew_bundle_line" ]]; then
  ok "~/Applications mkdir precedes brew bundle"
else
  nok "~/Applications mkdir precedes brew bundle (mkdir=$mkdir_line brew=$brew_bundle_line)"
fi
```

- [ ] **Step 2: Run tests — AC-5 fails**

- [ ] **Step 3: Locate the insertion point in install-macos.sh**

Run: `grep -n 'Step 1: Brew bundle' install-macos.sh`
Expected: line ~172.

- [ ] **Step 4: Insert the desktop-cask-opts block immediately BEFORE the `# ── Step 1: Brew bundle ──` header**

Insert these lines (between line ~171 `log "HOMEBREW_PREFIX=$HOMEBREW_PREFIX"` and line ~172 the step-1 header):

```bash

# ── Desktop: cask install directory (Layer 1 desktop) ────────────────────────
# /Applications is commonly MDM-locked on managed Macs. Install all casks
# into ~/Applications/ instead — benign on non-managed Macs (user-local is a
# valid Homebrew cask target). Must be exported BEFORE `brew bundle` so every
# cask (including pre-desktop ones like codeql, visual-studio-code) inherits.
mkdir -p "$HOME/Applications"
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"
```

- [ ] **Step 5: Run tests — AC-5 passes**

- [ ] **Step 6: Shellcheck install-macos.sh**

Run: `shellcheck install-macos.sh`
Expected: silent.

- [ ] **Step 7: Commit**

```bash
git add install-macos.sh scripts/test-plan-desktop-layer1.sh
git commit -m "feat(install-macos): route casks to ~/Applications (desktop layer 1)"
```

---

## Task 4: Create `aerospace/aerospace.toml` (AC-6 through AC-11)

**Files:**
- Create: `aerospace/aerospace.toml`
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Append AC-6 through AC-11 blocks to the test script**

```bash
# ── AC-6: aerospace.toml parses as valid TOML ─────────────────────────
echo ""
echo "AC-6: aerospace.toml parses as valid TOML"
if command -v python3 &>/dev/null; then
  if python3 -c "import tomllib, sys; tomllib.load(open(sys.argv[1], 'rb'))" \
       aerospace/aerospace.toml 2>/dev/null; then
    ok "aerospace.toml parses"
  else
    nok "aerospace.toml parses"
  fi
else
  skp "aerospace.toml parses" "python3 not available"
fi

# ── AC-7: aerospace.toml core settings ───────────────────────────────
echo ""
echo "AC-7: aerospace.toml core settings"
check "start-at-login = true"             grep -qE '^start-at-login[[:space:]]*=[[:space:]]*true' aerospace/aerospace.toml
check "default-root-container-layout tiles" \
  grep -qE "default-root-container-layout[[:space:]]*=[[:space:]]*'tiles'" aerospace/aerospace.toml
check "default-root-container-orientation auto" \
  grep -qE "default-root-container-orientation[[:space:]]*=[[:space:]]*'auto'" aerospace/aerospace.toml
check "accordion-padding = 30"            grep -qE 'accordion-padding[[:space:]]*=[[:space:]]*30' aerospace/aerospace.toml
# gaps.outer.top = 36 verified via TOML parse (more robust than a regex).
if command -v python3 &>/dev/null; then
  top_gap="$(python3 -c "import tomllib; d=tomllib.load(open('aerospace/aerospace.toml','rb')); print(d.get('gaps',{}).get('outer',{}).get('top',''))" 2>/dev/null)"
  if [[ "$top_gap" == "36" ]]; then
    ok "gaps.outer.top == 36"
  else
    nok "gaps.outer.top == 36 (got: $top_gap)"
  fi
else
  skp "gaps.outer.top == 36" "python3 not available"
fi

# ── AC-8: aerospace.toml main-mode bindings ──────────────────────────
echo ""
echo "AC-8: aerospace.toml main-mode bindings"
toml="$(cat aerospace/aerospace.toml)"
for b in 'alt-1' 'alt-2' 'alt-3' 'alt-4' \
         'alt-shift-1' 'alt-shift-2' 'alt-shift-3' 'alt-shift-4' \
         'alt-h' 'alt-j' 'alt-k' 'alt-l' \
         'alt-shift-h' 'alt-shift-j' 'alt-shift-k' 'alt-shift-l' \
         'alt-slash' 'alt-comma' 'alt-f' 'alt-shift-space'; do
  if printf '%s' "$toml" | grep -qE "^${b}[[:space:]]*="; then
    ok "binding $b declared"
  else
    nok "binding $b declared"
  fi
done

# ── AC-9: aerospace.toml on-window-detected pins ─────────────────────
echo ""
echo "AC-9: aerospace.toml on-window-detected pins"
# Count [[on-window-detected]] occurrences — expect at least 4.
owd_count=$(grep -cE '^\[\[on-window-detected\]\]' aerospace/aerospace.toml)
if (( owd_count >= 4 )); then
  ok "at least 4 [[on-window-detected]] blocks ($owd_count)"
else
  nok "at least 4 [[on-window-detected]] blocks ($owd_count)"
fi
check "kitty app-id pinned" \
  grep -qE "app-id[[:space:]]*=[[:space:]]*'net\.kovidgoyal\.kitty'" aerospace/aerospace.toml
check "MS Edge app-id pinned" \
  grep -qE "app-id[[:space:]]*=[[:space:]]*'com\.microsoft\.edgemac'" aerospace/aerospace.toml
check "MS Teams app-id pinned" \
  grep -qE "app-id[[:space:]]*=[[:space:]]*'com\.microsoft\.teams2'" aerospace/aerospace.toml
check "MS Outlook app-id pinned" \
  grep -qE "app-id[[:space:]]*=[[:space:]]*'com\.microsoft\.Outlook'" aerospace/aerospace.toml

# ── AC-10: workspace-to-monitor-force-assignment placeholders ────────
echo ""
echo "AC-10: workspace-to-monitor-force-assignment placeholders"
check "section declared" \
  grep -qE '^\[workspace-to-monitor-force-assignment\]' aerospace/aerospace.toml
check "workspace 1 names office-central + home-centre placeholders" \
  grep -qE '^1[[:space:]]*=.*<office-central-monitor-name>.*<home-centre-monitor-name>' aerospace/aerospace.toml
check "workspace 2 names office-central + built-in" \
  grep -qE '^2[[:space:]]*=.*<office-central-monitor-name>.*built-in' aerospace/aerospace.toml
check "workspace 3 names home-left + built-in" \
  grep -qE '^3[[:space:]]*=.*<home-left-monitor-name>.*built-in' aerospace/aerospace.toml
# Workspace 4 must be absent from the force-assignment table.
if awk '/^\[workspace-to-monitor-force-assignment\]/,/^\[/' aerospace/aerospace.toml \
   | grep -qE '^4[[:space:]]*='; then
  nok "workspace 4 absent from force-assignment (scratch follows focused monitor)"
else
  ok "workspace 4 absent from force-assignment (scratch follows focused monitor)"
fi

# ── AC-11: exec-on-workspace-change trigger ──────────────────────────
echo ""
echo "AC-11: exec-on-workspace-change trigger uses @HOMEBREW_PREFIX@"
exec_body="$(awk '/^exec-on-workspace-change[[:space:]]*=/,/^\]/' aerospace/aerospace.toml)"
if printf '%s' "$exec_body" | grep -q '@HOMEBREW_PREFIX@/bin/sketchybar'; then
  ok "exec-on-workspace-change uses @HOMEBREW_PREFIX@/bin/sketchybar"
else
  nok "exec-on-workspace-change uses @HOMEBREW_PREFIX@/bin/sketchybar"
fi
if printf '%s' "$exec_body" | grep -q 'aerospace_workspace_change'; then
  ok "trigger name is aerospace_workspace_change"
else
  nok "trigger name is aerospace_workspace_change"
fi
```

- [ ] **Step 2: Run tests — AC-6..11 all fail (file missing)**

- [ ] **Step 3: Create `aerospace/aerospace.toml`**

Create the file with exactly this content (literal — placeholder tokens stay):

```toml
# aerospace.toml — Desktop Layer 1 (macOS tiling WM)
#
# Spec: docs/plans/2026-04-14-macos-desktop-env-design.md §3.1.
# The @HOMEBREW_PREFIX@ marker is substituted by install-macos.sh.
# The <office-*>, <home-*>, and <primary-external-name> placeholders
# are substituted at install time PER DOCK LOCATION by the user via
# `aerospace list-monitors` — see install-macos.sh Next-steps item 7.f.

start-at-login = true

default-root-container-layout = 'tiles'
default-root-container-orientation = 'auto'
accordion-padding = 30

[gaps]
inner.horizontal = 8
inner.vertical = 8
[gaps.outer]
left = 8
bottom = 8
top = 36  # 30 px bar + 6 px breathing room
right = 8

# Fired on every workspace change; SketchyBar's `workspaces` item
# subscribes to the custom event and repaints.
exec-on-workspace-change = [
  '/bin/bash',
  '-c',
  '@HOMEBREW_PREFIX@/bin/sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$AEROSPACE_FOCUSED_WORKSPACE"'
]

# ── Main-mode keybindings (Alt namespace — see design §3.1, §3.5) ────
[mode.main.binding]
alt-1 = 'workspace 1'
alt-2 = 'workspace 2'
alt-3 = 'workspace 3'
alt-4 = 'workspace 4'

alt-shift-1 = 'move-node-to-workspace 1'
alt-shift-2 = 'move-node-to-workspace 2'
alt-shift-3 = 'move-node-to-workspace 3'
alt-shift-4 = 'move-node-to-workspace 4'

alt-h = 'focus left'
alt-j = 'focus down'
alt-k = 'focus up'
alt-l = 'focus right'

alt-shift-h = 'move left'
alt-shift-j = 'move down'
alt-shift-k = 'move up'
alt-shift-l = 'move right'

alt-slash = 'layout tiles horizontal vertical'
alt-comma = 'layout accordion horizontal vertical'
alt-f = 'fullscreen'
alt-shift-space = 'layout floating tiling'

# ── App pinning (on-window-detected — first-launch placement) ────────
# Teams / Outlook both land on workspace 3 (comms). VS Code / Word /
# Excel / PowerPoint are INTENTIONALLY NOT pinned — they land on the
# current workspace as natural "scratch" behaviour.
[[on-window-detected]]
if.app-id = 'net.kovidgoyal.kitty'
run = 'move-node-to-workspace 1'

[[on-window-detected]]
if.app-id = 'com.microsoft.edgemac'
run = 'move-node-to-workspace 2'

[[on-window-detected]]
if.app-id = 'com.microsoft.teams2'
run = 'move-node-to-workspace 3'

[[on-window-detected]]
if.app-id = 'com.microsoft.Outlook'
run = 'move-node-to-workspace 3'

# ── Monitor priority lists — see design §2.5 + §5.1 item 7.f ─────────
# Placeholders are substituted per-dock-location by the user after
# `aerospace list-monitors`. Workspace 4 is absent — it follows the
# focused monitor (scratch semantics).
[workspace-to-monitor-force-assignment]
1 = ['<office-central-monitor-name>', '<home-centre-monitor-name>']
2 = ['<office-central-monitor-name>', 'built-in']
3 = ['<home-left-monitor-name>', 'built-in']
```

- [ ] **Step 4: Verify TOML parses**

Run: `python3 -c "import tomllib; tomllib.load(open('aerospace/aerospace.toml','rb'))"`
Expected: exit 0.

- [ ] **Step 5: Run tests — AC-6..11 pass**

Run: `bash scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 6: Commit**

```bash
git add aerospace/aerospace.toml scripts/test-plan-desktop-layer1.sh
git commit -m "feat(aerospace): add aerospace.toml with monitor placeholders (desktop layer 1)"
```

---

## Task 5: Create `sketchybar/colors.sh` + `sketchybar/icons.sh` (AC-12, AC-13)

**Files:**
- Create: `sketchybar/colors.sh`
- Create: `sketchybar/icons.sh`
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Append AC-12, AC-13 blocks to the test script**

```bash
# ── AC-12: sketchybar/colors.sh exports 12 Dracula hex constants ─────
echo ""
echo "AC-12: sketchybar/colors.sh exports full Dracula palette"
# Use case-insensitive match — hex case is unspecified in the parent
# design and consumers are case-insensitive.
for pair in 'COLOR_BG:0xff282a36' \
            'COLOR_CURRENT_LINE:0xff44475a' \
            'COLOR_SELECTION:0xff44475a' \
            'COLOR_FG:0xfff8f8f2' \
            'COLOR_COMMENT:0xff6272a4' \
            'COLOR_RED:0xffff5555' \
            'COLOR_ORANGE:0xffffb86c' \
            'COLOR_YELLOW:0xfff1fa8c' \
            'COLOR_GREEN:0xff50fa7b' \
            'COLOR_CYAN:0xff8be9fd' \
            'COLOR_PURPLE:0xffbd93f9' \
            'COLOR_PINK:0xffff79c6'; do
  name="${pair%%:*}"; val="${pair##*:}"
  if grep -qiE "^(export[[:space:]]+)?${name}=${val}" sketchybar/colors.sh; then
    ok "colors.sh exports ${name}=${val}"
  else
    nok "colors.sh exports ${name}=${val}"
  fi
done

# ── AC-13: sketchybar/icons.sh declares ≥ 9 ICON_* constants ─────────
echo ""
echo "AC-13: sketchybar/icons.sh declares glyph constants"
icon_count=$(grep -cE '^[[:space:]]*(export[[:space:]]+)?ICON_[A-Z_]+=' sketchybar/icons.sh)
if (( icon_count >= 9 )); then
  ok "icons.sh declares ≥ 9 ICON_* constants ($icon_count)"
else
  nok "icons.sh declares ≥ 9 ICON_* constants ($icon_count)"
fi
for name in ICON_WIFI ICON_BATTERY ICON_VOLUME ICON_CLOCK ICON_ZSCALER ICON_FOCUS; do
  check "icons.sh declares $name" \
    grep -qE "^[[:space:]]*(export[[:space:]]+)?${name}=" sketchybar/icons.sh
done
```

- [ ] **Step 2: Run tests — AC-12, 13 fail**

- [ ] **Step 3: Create `sketchybar/colors.sh`**

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# sketchybar/colors.sh — Dracula Pro palette, single source of truth.
#
# Sourced by sketchybarrc, every sketchybar/plugins/*.sh, and
# jankyborders/bordersrc. Hex values match the parent shell design's
# §3.9 (docs/plans/2026-04-12-shell-modernisation-design.md).
#
# Format: 0xff<RRGGBB>  — SketchyBar/JankyBorders AARRGGBB notation
# with ff = fully opaque alpha.

export COLOR_BG=0xff282A36            # Background
export COLOR_CURRENT_LINE=0xff44475A  # Current Line (also inactive border)
export COLOR_SELECTION=0xff44475A     # Selection (same hex as Current Line)
export COLOR_FG=0xffF8F8F2            # Foreground
export COLOR_COMMENT=0xff6272A4       # Comment / muted

export COLOR_RED=0xffFF5555           # Red    — Zscaler disconnect / errors
export COLOR_ORANGE=0xffFFB86C        # Orange — warnings
export COLOR_YELLOW=0xffF1FA8C        # Yellow — battery low
export COLOR_GREEN=0xff50FA7B         # Green  — Zscaler connected / ok
export COLOR_CYAN=0xff8BE9FD          # Cyan   — wifi connected
export COLOR_PURPLE=0xffBD93F9        # Purple — active focus / accent
export COLOR_PINK=0xffFF79C6          # Pink   — unused (kept for completeness)
```

Then: `chmod +x sketchybar/colors.sh`

- [ ] **Step 4: Create `sketchybar/icons.sh`**

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# sketchybar/icons.sh — Nerd Font glyph constants.
#
# Sourced by every plugin. Requires JetBrainsMono Nerd Font loaded in
# SketchyBar's bar font. See parent design §3.9 / §3.2.

# Workspaces
export ICON_WS_1=""
export ICON_WS_2=""
export ICON_WS_3=""
export ICON_WS_4=""

# Status indicators
export ICON_WIFI="󰖩"
export ICON_WIFI_OFF="󰖪"
export ICON_BATTERY=""
export ICON_BATTERY_LOW=""
export ICON_BATTERY_CHARGING=""
export ICON_VOLUME=""
export ICON_VOLUME_MUTED=""
export ICON_CLOCK=""
export ICON_ZSCALER="󰒃"
export ICON_FOCUS=""
```

Then: `chmod +x sketchybar/icons.sh`

- [ ] **Step 5: Shellcheck both files**

Run: `shellcheck sketchybar/colors.sh sketchybar/icons.sh`
Expected: silent.

- [ ] **Step 6: Run tests — AC-12, 13 pass**

- [ ] **Step 7: Commit**

```bash
git add sketchybar/colors.sh sketchybar/icons.sh scripts/test-plan-desktop-layer1.sh
git commit -m "feat(sketchybar): add colors.sh + icons.sh (desktop layer 1)"
```

---

## Task 6: Create `sketchybar/sketchybarrc` (AC-14)

**Files:**
- Create: `sketchybar/sketchybarrc`
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Append AC-14 block**

```bash
# ── AC-14: sketchybarrc sources palette + configures the bar ─────────
echo ""
echo "AC-14: sketchybarrc sources palette and adds 9 items"
check "sketchybarrc sources colors.sh" \
  grep -qE 'source[[:space:]]+"\$CONFIG_DIR/colors.sh"' sketchybar/sketchybarrc
check "sketchybarrc sources icons.sh" \
  grep -qE 'source[[:space:]]+"\$CONFIG_DIR/icons.sh"' sketchybar/sketchybarrc
check "sketchybarrc calls --bar height=30" \
  grep -qE 'sketchybar[[:space:]]+--bar.*height=30' sketchybar/sketchybarrc
check "sketchybarrc calls --bar position=top" \
  grep -qE 'sketchybar[[:space:]]+--bar.*position=top' sketchybar/sketchybarrc
check "sketchybarrc pins display to primary-external placeholder" \
  grep -q '<primary-external-name>' sketchybar/sketchybarrc
# Count --add item occurrences — expect at least 9 (9 items + optional event).
add_item_count=$(grep -cE '^[[:space:]]*sketchybar[[:space:]]+--add[[:space:]]+item' sketchybar/sketchybarrc)
if (( add_item_count >= 8 )); then
  ok "sketchybarrc adds ≥ 8 items ($add_item_count)"
else
  nok "sketchybarrc adds ≥ 8 items ($add_item_count)"
fi
```

- [ ] **Step 2: Run tests — AC-14 fails**

- [ ] **Step 3: Create `sketchybar/sketchybarrc`**

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# sketchybar/sketchybarrc — SketchyBar top-level config.
#
# Spec: docs/plans/2026-04-14-macos-desktop-env-design.md §3.2.
# Pins the bar to the <primary-external-name> placeholder — the user
# substitutes at install time per Next-steps item 7.f (same pattern
# as aerospace.toml monitor placeholders).

CONFIG_DIR="$HOME/.config/sketchybar"
PLUGIN_DIR="$CONFIG_DIR/plugins"

# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"
# shellcheck source=/dev/null
. "$CONFIG_DIR/icons.sh"

# ── Bar appearance ────────────────────────────────────────────────────
sketchybar --bar \
  height=30 \
  position=top \
  color="$COLOR_BG" \
  padding_left=8 \
  padding_right=8 \
  corner_radius=9 \
  y_offset=4 \
  margin=8 \
  blur_radius=0 \
  topmost=window \
  display='<primary-external-name>'

# ── Defaults applied to every item ────────────────────────────────────
sketchybar --default \
  updates=when_shown \
  drawing=on \
  icon.font="JetBrainsMono Nerd Font:Bold:14.0" \
  icon.color="$COLOR_FG" \
  label.font="JetBrainsMono Nerd Font:Regular:12.0" \
  label.color="$COLOR_FG" \
  padding_left=6 \
  padding_right=6

# ── Left side ─────────────────────────────────────────────────────────
# 1. workspaces — 4 pills, subscribes to aerospace_workspace_change.
# Fallback update_freq=5 catches missed triggers within 5 s.
for ws in 1 2 3 4; do
  icon_var="ICON_WS_$ws"
  sketchybar --add item "workspace.$ws" left \
    --set "workspace.$ws" \
      icon="$(eval echo \$"$icon_var")" \
      label="$ws" \
      update_freq=5 \
      script="$PLUGIN_DIR/workspaces.sh" \
      click_script="aerospace workspace $ws" \
    --subscribe "workspace.$ws" aerospace_workspace_change
done

# 2. focused_app — subscribes to front_app_switched.
sketchybar --add item focused_app left \
  --set focused_app \
    label.font="JetBrainsMono Nerd Font:Bold:12.0" \
    script="$PLUGIN_DIR/focused_app.sh" \
  --subscribe focused_app front_app_switched

# ── Right side (drawn right-to-left) ──────────────────────────────────
# 3. zscaler — 10-second poll of pgrep -qx ZscalerTunnel.
sketchybar --add item zscaler right \
  --set zscaler \
    icon="$ICON_ZSCALER" \
    update_freq=10 \
    script="$PLUGIN_DIR/zscaler.sh"

# 4. focus_mode — reads ~/Library/DoNotDisturb/DB/Assertions.json (jq -e guard).
sketchybar --add item focus_mode right \
  --set focus_mode \
    icon="$ICON_FOCUS" \
    update_freq=30 \
    script="$PLUGIN_DIR/focus_mode.sh"

# 5. wifi — SSID or disconnect glyph, 30-second poll.
sketchybar --add item wifi right \
  --set wifi \
    icon="$ICON_WIFI" \
    update_freq=30 \
    script="$PLUGIN_DIR/wifi.sh"

# 6. volume — event-driven.
sketchybar --add item volume right \
  --set volume \
    icon="$ICON_VOLUME" \
    script="$PLUGIN_DIR/volume.sh" \
  --subscribe volume volume_change

# 7. battery — percent + charge state, 120-second poll.
sketchybar --add item battery right \
  --set battery \
    icon="$ICON_BATTERY" \
    update_freq=120 \
    script="$PLUGIN_DIR/battery.sh"

# 8. clock — date + time, 30-second poll.
sketchybar --add item clock right \
  --set clock \
    icon="$ICON_CLOCK" \
    update_freq=30 \
    script="$PLUGIN_DIR/clock.sh"

sketchybar --update
```

Then: `chmod +x sketchybar/sketchybarrc`

- [ ] **Step 4: Shellcheck**

Run: `shellcheck sketchybar/sketchybarrc`
Expected: silent.

- [ ] **Step 5: Run tests — AC-14 passes**

- [ ] **Step 6: Commit**

```bash
git add sketchybar/sketchybarrc scripts/test-plan-desktop-layer1.sh
git commit -m "feat(sketchybar): add sketchybarrc with 8 items + 4 workspace pills (desktop layer 1)"
```

---

## Task 7: Create `sketchybar/plugins/workspaces.sh` and `focused_app.sh` (AC-15 partial)

**Files:**
- Create: `sketchybar/plugins/workspaces.sh`
- Create: `sketchybar/plugins/focused_app.sh`
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Append an AC-15 block that iterates all 8 plugin files**

```bash
# ── AC-15: all sketchybar/plugins/*.sh shellcheck-clean ──────────────
echo ""
echo "AC-15: sketchybar plugins shellcheck-clean"
if command -v shellcheck &>/dev/null; then
  all_ok=true
  for plugin in sketchybar/plugins/*.sh; do
    [[ -f "$plugin" ]] || continue
    if ! shellcheck "$plugin" >/dev/null 2>&1; then
      nok "shellcheck $plugin"
      all_ok=false
    fi
  done
  if $all_ok; then
    ok "shellcheck all sketchybar/plugins/*.sh"
  fi
else
  skp "shellcheck all sketchybar/plugins/*.sh" "shellcheck not available"
fi
```

- [ ] **Step 2: Create `sketchybar/plugins/workspaces.sh`**

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# workspaces.sh — repaints workspace pill on aerospace_workspace_change.
#
# Invoked by SketchyBar in two modes:
#   - update_freq=5 fallback poll
#   - aerospace_workspace_change trigger (sets FOCUSED_WORKSPACE env var)
#
# NAME is "workspace.<N>" and the literal workspace number is the last
# segment. Active pill shows Dracula Purple background; inactive shows
# Dracula Current-Line.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"

ws="${NAME##*.}"
focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"

if [ "$ws" = "$focused" ]; then
  sketchybar --set "$NAME" \
    background.color="$COLOR_PURPLE" \
    background.corner_radius=6 \
    background.height=22 \
    background.drawing=on \
    label.color="$COLOR_BG"
else
  sketchybar --set "$NAME" \
    background.color="$COLOR_CURRENT_LINE" \
    background.corner_radius=6 \
    background.height=22 \
    background.drawing=on \
    label.color="$COLOR_FG"
fi
```

Then: `chmod +x sketchybar/plugins/workspaces.sh`

- [ ] **Step 3: Create `sketchybar/plugins/focused_app.sh`**

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# focused_app.sh — renders the front application's name in the bar.
#
# Invoked by SketchyBar on front_app_switched. SketchyBar provides
# INFO env var containing the app name.

sketchybar --set "$NAME" label="$INFO"
```

Then: `chmod +x sketchybar/plugins/focused_app.sh`

- [ ] **Step 4: Shellcheck both**

Run: `shellcheck sketchybar/plugins/workspaces.sh sketchybar/plugins/focused_app.sh`
Expected: silent.

- [ ] **Step 5: Commit**

```bash
git add sketchybar/plugins/workspaces.sh sketchybar/plugins/focused_app.sh scripts/test-plan-desktop-layer1.sh
git commit -m "feat(sketchybar): add workspaces + focused_app plugins (desktop layer 1)"
```

---

## Task 8: Create `sketchybar/plugins/zscaler.sh` and `focus_mode.sh` (AC-16, AC-17)

**Files:**
- Create: `sketchybar/plugins/zscaler.sh`
- Create: `sketchybar/plugins/focus_mode.sh`
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Append AC-16, AC-17 blocks**

```bash
# ── AC-16: zscaler.sh uses pgrep -qx ZscalerTunnel ───────────────────
echo ""
echo "AC-16: zscaler.sh uses pgrep -qx ZscalerTunnel"
# Strip comments so commented-out pgrep examples don't leak.
zscaler_body="$(sed 's/#.*//' sketchybar/plugins/zscaler.sh)"
if printf '%s' "$zscaler_body" | grep -q 'pgrep -qx ZscalerTunnel'; then
  ok "zscaler.sh uses pgrep -qx ZscalerTunnel"
else
  nok "zscaler.sh uses pgrep -qx ZscalerTunnel"
fi

# ── AC-17: focus_mode.sh reads Assertions.json with jq -e guard ──────
echo ""
echo "AC-17: focus_mode.sh reads Assertions.json with jq -e guard"
focus_body="$(sed 's/#.*//' sketchybar/plugins/focus_mode.sh)"
if printf '%s' "$focus_body" | grep -q 'Library/DoNotDisturb/DB/Assertions.json'; then
  ok "focus_mode.sh references Assertions.json"
else
  nok "focus_mode.sh references Assertions.json"
fi
if printf '%s' "$focus_body" | grep -q 'jq -e'; then
  ok "focus_mode.sh uses jq -e guard"
else
  nok "focus_mode.sh uses jq -e guard"
fi
if printf '%s' "$focus_body" | grep -qE 'drawing=off|drawing off'; then
  ok "focus_mode.sh falls back to drawing=off on failure"
else
  nok "focus_mode.sh falls back to drawing=off on failure"
fi
```

- [ ] **Step 2: Run tests — AC-16, 17 fail**

- [ ] **Step 3: Create `sketchybar/plugins/zscaler.sh`**

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# zscaler.sh — SketchyBar liveness indicator for the Zscaler daemon.
#
# Primary check is `pgrep -qx ZscalerTunnel` (exact match). Fallback is
# a case-insensitive substring match because the binary name has shifted
# between 3.x and 4.x (design §A.2.1). Never shells out to Zscaler IPC.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"

if pgrep -qx ZscalerTunnel || pgrep -q -fi 'zscaler'; then
  sketchybar --set "$NAME" \
    icon.color="$COLOR_GREEN" \
    drawing=on \
    label=""
else
  sketchybar --set "$NAME" \
    icon.color="$COLOR_RED" \
    drawing=on \
    label=""
fi
```

Then: `chmod +x sketchybar/plugins/zscaler.sh`

- [ ] **Step 4: Create `sketchybar/plugins/focus_mode.sh`**

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# focus_mode.sh — renders a Focus-Mode indicator when macOS DnD is on.
#
# Reads ~/Library/DoNotDisturb/DB/Assertions.json — an Apple-internal
# path that has been stable across Sonoma and Sequoia (design §7.6).
# Wraps the read in `jq -e` so a parse failure or missing file silently
# degrades to drawing=off rather than crashing the bar.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"

assertions="$HOME/Library/DoNotDisturb/DB/Assertions.json"

if [ -r "$assertions" ] && jq -e '.data[0].storeAssertionRecords | length > 0' "$assertions" >/dev/null 2>&1; then
  sketchybar --set "$NAME" \
    icon.color="$COLOR_PURPLE" \
    drawing=on
else
  # No active Focus Mode — or file unreadable/malformed. Hide the item.
  sketchybar --set "$NAME" drawing=off
fi
```

Then: `chmod +x sketchybar/plugins/focus_mode.sh`

- [ ] **Step 5: Shellcheck both**

Run: `shellcheck sketchybar/plugins/zscaler.sh sketchybar/plugins/focus_mode.sh`
Expected: silent.

- [ ] **Step 6: Run tests — AC-16, 17 pass**

- [ ] **Step 7: Commit**

```bash
git add sketchybar/plugins/zscaler.sh sketchybar/plugins/focus_mode.sh scripts/test-plan-desktop-layer1.sh
git commit -m "feat(sketchybar): add zscaler + focus_mode plugins with defensive guards (desktop layer 1)"
```

---

## Task 9: Create `sketchybar/plugins/wifi.sh`, `volume.sh`, `battery.sh`, `clock.sh`

**Files:**
- Create: `sketchybar/plugins/wifi.sh`
- Create: `sketchybar/plugins/volume.sh`
- Create: `sketchybar/plugins/battery.sh`
- Create: `sketchybar/plugins/clock.sh`

- [ ] **Step 1: Create `sketchybar/plugins/wifi.sh`**

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# wifi.sh — renders SSID or disconnect glyph.
#
# Uses `networksetup -getairportnetwork en0` which is stable across
# modern macOS. Device name en0 is the standard Wi-Fi interface on
# Apple Silicon laptops; falls back to en1 on Intel.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"
# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/icons.sh"

iface="$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi/{getline; print $2}' | head -1)"
iface="${iface:-en0}"

ssid="$(networksetup -getairportnetwork "$iface" 2>/dev/null | sed 's/^Current Wi-Fi Network: //')"

if [ -n "$ssid" ] && [ "$ssid" != "You are not associated with an AirPort network." ]; then
  sketchybar --set "$NAME" \
    icon="$ICON_WIFI" \
    icon.color="$COLOR_CYAN" \
    label="$ssid"
else
  sketchybar --set "$NAME" \
    icon="$ICON_WIFI_OFF" \
    icon.color="$COLOR_COMMENT" \
    label=""
fi
```

Then: `chmod +x sketchybar/plugins/wifi.sh`

- [ ] **Step 2: Create `sketchybar/plugins/volume.sh`**

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# volume.sh — renders current output volume, event-driven.
#
# SketchyBar provides INFO env var with the new volume level on
# volume_change events.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"
# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/icons.sh"

vol="${INFO:-$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)}"
vol="${vol:-0}"

if [ "$vol" -eq 0 ]; then
  icon="$ICON_VOLUME_MUTED"
else
  icon="$ICON_VOLUME"
fi

sketchybar --set "$NAME" \
  icon="$icon" \
  icon.color="$COLOR_FG" \
  label="${vol}%"
```

Then: `chmod +x sketchybar/plugins/volume.sh`

- [ ] **Step 3: Create `sketchybar/plugins/battery.sh`**

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# battery.sh — percent + charge indicator.
#
# Parses `pmset -g batt` — stable across macOS versions.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"
# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/icons.sh"

batt_out="$(pmset -g batt 2>/dev/null)"
pct="$(printf '%s' "$batt_out" | grep -oE '[0-9]+%' | head -1 | tr -d '%')"
pct="${pct:-0}"

if printf '%s' "$batt_out" | grep -qi 'charging\|ac power'; then
  icon="$ICON_BATTERY_CHARGING"
  color="$COLOR_GREEN"
elif [ "$pct" -le 20 ]; then
  icon="$ICON_BATTERY_LOW"
  color="$COLOR_YELLOW"
else
  icon="$ICON_BATTERY"
  color="$COLOR_FG"
fi

sketchybar --set "$NAME" \
  icon="$icon" \
  icon.color="$color" \
  label="${pct}%"
```

Then: `chmod +x sketchybar/plugins/battery.sh`

- [ ] **Step 4: Create `sketchybar/plugins/clock.sh`**

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# clock.sh — date + time, 30-second poll.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"

sketchybar --set "$NAME" \
  label="$(date '+%a %d %b  %H:%M')" \
  label.color="$COLOR_FG"
```

Then: `chmod +x sketchybar/plugins/clock.sh`

- [ ] **Step 5: Shellcheck all four**

Run: `shellcheck sketchybar/plugins/wifi.sh sketchybar/plugins/volume.sh sketchybar/plugins/battery.sh sketchybar/plugins/clock.sh`
Expected: silent.

- [ ] **Step 6: Run the layer test — AC-15 (all plugins clean) passes**

Run: `bash scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 7: Commit**

```bash
git add sketchybar/plugins/wifi.sh sketchybar/plugins/volume.sh sketchybar/plugins/battery.sh sketchybar/plugins/clock.sh
git commit -m "feat(sketchybar): add wifi + volume + battery + clock plugins (desktop layer 1)"
```

---

## Task 10: Create `jankyborders/bordersrc` (AC-18)

**Files:**
- Create: `jankyborders/bordersrc`
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Append AC-18 block**

```bash
# ── AC-18: bordersrc sources colors.sh and uses Dracula vars ─────────
echo ""
echo "AC-18: jankyborders/bordersrc invokes borders with Dracula colours"
check "bordersrc sources colors.sh" \
  grep -qE '\.\s+"\$HOME/\.config/sketchybar/colors\.sh"' jankyborders/bordersrc
check "bordersrc uses active_color=\$COLOR_PURPLE" \
  grep -qE 'active_color="\$COLOR_PURPLE"' jankyborders/bordersrc
check "bordersrc uses inactive_color=\$COLOR_CURRENT_LINE" \
  grep -qE 'inactive_color="\$COLOR_CURRENT_LINE"' jankyborders/bordersrc
check "bordersrc declares style=round" \
  grep -qE 'style=round' jankyborders/bordersrc
check "bordersrc declares hidpi=on" \
  grep -qE 'hidpi=on' jankyborders/bordersrc
```

- [ ] **Step 2: Run tests — AC-18 fails**

- [ ] **Step 3: Create `jankyborders/bordersrc`**

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# jankyborders/bordersrc — config for the borders daemon.
#
# Spec: docs/plans/2026-04-14-macos-desktop-env-design.md §3.3.
# Sourced from sketchybar/colors.sh — the single Dracula source of
# truth. No hex values hardcoded here.

# shellcheck source=/dev/null
. "$HOME/.config/sketchybar/colors.sh"

exec borders \
  active_color="$COLOR_PURPLE" \
  inactive_color="$COLOR_CURRENT_LINE" \
  width=4.0 \
  hidpi=on \
  style=round
```

Then: `chmod +x jankyborders/bordersrc`

- [ ] **Step 4: Shellcheck**

Run: `shellcheck jankyborders/bordersrc`
Expected: silent.

- [ ] **Step 5: Run tests — AC-18 passes**

- [ ] **Step 6: Commit**

```bash
git add jankyborders/bordersrc scripts/test-plan-desktop-layer1.sh
git commit -m "feat(jankyborders): add bordersrc sourcing Dracula palette (desktop layer 1)"
```

---

## Task 11: Create `launchagents/com.felixkratz.sketchybar.plist` + `com.felixkratz.borders.plist` (AC-19)

**Files:**
- Create: `launchagents/com.felixkratz.sketchybar.plist`
- Create: `launchagents/com.felixkratz.borders.plist`
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Append AC-19 block**

```bash
# ── AC-19: LaunchAgent plists are plutil-clean + use markers ─────────
echo ""
echo "AC-19: LaunchAgent plists plutil-lint clean + use markers"
for plist in launchagents/com.felixkratz.sketchybar.plist \
             launchagents/com.felixkratz.borders.plist; do
  if [[ ! -f "$plist" ]]; then
    nok "$plist exists"
    continue
  fi
  ok "$plist exists"

  if [[ "$(uname)" == "Darwin" ]] && command -v plutil &>/dev/null; then
    if plutil -lint "$plist" >/dev/null 2>&1; then
      ok "$plist passes plutil -lint"
    else
      nok "$plist passes plutil -lint"
    fi
  else
    skp "$plist passes plutil -lint" "plutil not available"
  fi

  check "$plist uses @HOMEBREW_PREFIX@/bin/ marker" \
    grep -q '@HOMEBREW_PREFIX@/bin/' "$plist"
  check "$plist uses @HOME@ marker in log paths" \
    grep -q '@HOME@' "$plist"
done
```

- [ ] **Step 2: Run tests — AC-19 fails (files missing)**

- [ ] **Step 3: Create `launchagents/com.felixkratz.sketchybar.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.felixkratz.sketchybar</string>
  <key>ProgramArguments</key>
  <array>
    <string>@HOMEBREW_PREFIX@/bin/sketchybar</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>@HOME@/Library/Logs/com.felixkratz.sketchybar.out.log</string>
  <key>StandardErrorPath</key>
  <string>@HOME@/Library/Logs/com.felixkratz.sketchybar.err.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>@HOMEBREW_PREFIX@/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>ThrottleInterval</key>
  <integer>10</integer>
</dict>
</plist>
```

- [ ] **Step 4: Create `launchagents/com.felixkratz.borders.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.felixkratz.borders</string>
  <key>ProgramArguments</key>
  <array>
    <string>@HOME@/.config/borders/bordersrc</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>WorkingDirectory</key>
  <string>@HOME@/.config/borders</string>
  <key>StandardOutPath</key>
  <string>@HOME@/Library/Logs/com.felixkratz.borders.out.log</string>
  <key>StandardErrorPath</key>
  <string>@HOME@/Library/Logs/com.felixkratz.borders.err.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>@HOMEBREW_PREFIX@/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>ThrottleInterval</key>
  <integer>10</integer>
</dict>
</plist>
```

NOTE: borders is invoked via `bordersrc` (which ends with `exec borders ...`) rather than `borders` directly, because `bordersrc` sources `colors.sh` for Dracula palette variables. The shebang + exec form means the plist still runs the borders binary, but all config stays in the tracked file.

- [ ] **Step 5: If on macOS, validate plutil-lint**

Run (macOS only): `plutil -lint launchagents/com.felixkratz.sketchybar.plist launchagents/com.felixkratz.borders.plist`
Expected: both "OK".

- [ ] **Step 6: Run tests — AC-19 passes**

- [ ] **Step 7: Commit**

```bash
git add launchagents/com.felixkratz.sketchybar.plist launchagents/com.felixkratz.borders.plist scripts/test-plan-desktop-layer1.sh
git commit -m "feat(launchagents): add sketchybar + borders plists (desktop layer 1)"
```

---

## Task 12: install-macos.sh symlinks + LaunchAgent bootstrap + Next-steps (AC-20, AC-21, AC-22)

**Files:**
- Modify: `install-macos.sh`
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Append AC-20, AC-21, AC-22 blocks**

```bash
# ── AC-20: install-macos.sh symlinks Layer 1 desktop configs ──────────
echo ""
echo "AC-20: install-macos.sh symlinks Layer 1 desktop configs"
check "link aerospace/aerospace.toml" \
  grep -qE 'link[[:space:]]+aerospace/aerospace\.toml[[:space:]]+\.config/aerospace/aerospace\.toml' install-macos.sh
check "link sketchybar/sketchybarrc" \
  grep -qE 'link[[:space:]]+sketchybar/sketchybarrc[[:space:]]+\.config/sketchybar/sketchybarrc' install-macos.sh
check "link sketchybar/colors.sh" \
  grep -qE 'link[[:space:]]+sketchybar/colors\.sh[[:space:]]+\.config/sketchybar/colors\.sh' install-macos.sh
check "link sketchybar/icons.sh" \
  grep -qE 'link[[:space:]]+sketchybar/icons\.sh[[:space:]]+\.config/sketchybar/icons\.sh' install-macos.sh
check "link sketchybar/plugins (directory)" \
  grep -qE 'link[[:space:]]+sketchybar/plugins[[:space:]]+\.config/sketchybar/plugins' install-macos.sh
check "link jankyborders/bordersrc" \
  grep -qE 'link[[:space:]]+jankyborders/bordersrc[[:space:]]+\.config/borders/bordersrc' install-macos.sh

# ── AC-21: install-macos.sh sed-substitutes plists + bootstraps ──────
echo ""
echo "AC-21: install-macos.sh bootstraps Layer 1 LaunchAgents"
block="$(awk '/Desktop LaunchAgents \(macOS only\)/,/Desktop LaunchAgents loaded/' install-macos.sh)"
for la in 'com.felixkratz.sketchybar.plist' 'com.felixkratz.borders.plist'; do
  if printf '%s' "$block" | grep -q "$la"; then
    ok "desktop LaunchAgent block names $la"
  else
    nok "desktop LaunchAgent block names $la"
  fi
done
if printf '%s' "$block" | grep -qE 'sed.*@HOMEBREW_PREFIX@.*@HOME@'; then
  ok "sed substitutes both @HOMEBREW_PREFIX@ and @HOME@"
else
  nok "sed substitutes both @HOMEBREW_PREFIX@ and @HOME@"
fi
if printf '%s' "$block" | grep -q 'launchctl bootout'; then
  ok "block calls launchctl bootout"
else
  nok "block calls launchctl bootout"
fi
if printf '%s' "$block" | grep -q 'launchctl bootstrap'; then
  ok "block calls launchctl bootstrap"
else
  nok "block calls launchctl bootstrap"
fi
check "desktop LaunchAgent block guarded by Darwin check" \
  bash -c "grep -qE 'if \\[\\[.*uname.*Darwin' install-macos.sh"

# ── AC-22: install-macos.sh Next-steps covers desktop first-run ──────
echo ""
echo "AC-22: install-macos.sh Next-steps mentions desktop first-run"
next="$(awk '/Next steps:/,/EOF/' install-macos.sh)"
for needle in 'Accessibility' 'AeroSpace' 'aerospace list-monitors' '<office-central-monitor-name>'; do
  if printf '%s' "$next" | grep -q -F "$needle"; then
    ok "Next-steps mentions: $needle"
  else
    nok "Next-steps mentions: $needle"
  fi
done
```

- [ ] **Step 2: Run tests — AC-20..22 all fail**

- [ ] **Step 3: Add the Layer 1 symlink block to install-macos.sh**

Locate the `# container dev script (Plan 13)` block (lines ~360–362). Immediately AFTER the `link container/dev.sh  .local/bin/dev` line, insert the desktop block:

```bash

# ── Desktop Layer 1 configs (aerospace + sketchybar + jankyborders) ─────
link aerospace/aerospace.toml  .config/aerospace/aerospace.toml
link sketchybar/sketchybarrc   .config/sketchybar/sketchybarrc
link sketchybar/colors.sh      .config/sketchybar/colors.sh
link sketchybar/icons.sh       .config/sketchybar/icons.sh
link sketchybar/plugins        .config/sketchybar/plugins
link jankyborders/bordersrc    .config/borders/bordersrc
```

- [ ] **Step 4: Add the desktop LaunchAgent bootstrap block to install-macos.sh**

Locate the existing Podman LaunchAgent block (ends near line ~384 with `log "Podman Machine LaunchAgent loaded"`). Immediately AFTER that line (still inside the same `if [[ "$(uname)" == "Darwin" ]]; then ... fi` block OR in a new Darwin-guarded block — use a new guard for clarity), insert:

```bash

  # ── Desktop LaunchAgents (macOS only) ─────────────────────────────────
  for plist in com.felixkratz.sketchybar.plist \
               com.felixkratz.borders.plist; do
    plist_src="$DOTFILES/launchagents/$plist"
    plist_dst="$HOME/Library/LaunchAgents/$plist"
    if [[ ! -f "$plist_src" ]]; then
      warn "missing plist: $plist_src — skipping"
      continue
    fi
    sed -e "s|@HOMEBREW_PREFIX@|$HOMEBREW_PREFIX|g" \
        -e "s|@HOME@|$HOME|g" \
        "$plist_src" > "$plist_dst"
    launchctl bootout "gui/$(id -u)/${plist%.plist}" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$plist_dst"
    printf "  linked    %s\n" "$plist_dst"
  done
  log "Desktop LaunchAgents loaded"
```

NOTE: this block lives INSIDE the existing `if [[ "$(uname)" == "Darwin" ]]; then` that contains the Podman-machine bootstrap — so the desktop agents only install on macOS.

- [ ] **Step 5: Extend the Next-steps heredoc**

Locate `cat <<EOF` under `# ── Step 4: Next steps ───` and the existing numbered steps 1–6. Just BEFORE the `Prerequisites NOT installed by this script:` paragraph, insert a new step 7 (following the same numbering / indentation style):

```
  7. Desktop first-run (macOS only — Layers 1–3):
     a) Launch AeroSpace from ~/Applications/AeroSpace.app (first launch
        triggers the Accessibility prompt; click "Open System Settings").
     b) Within a single JIT-admin window, grant Accessibility to each of:
          - AeroSpace             (~/Applications/AeroSpace.app)
          - skhd                  ($HOMEBREW_PREFIX/bin/skhd — Layer 2)
          - Hammerspoon           (~/Applications/Hammerspoon.app — Layer 2)
          - Raycast               (~/Applications/Raycast.app — Layer 3)
     c) Hide the native menu bar (SketchyBar replaces it):
          defaults write -g _HIHideMenuBar -bool true
          killall SystemUIServer
     d) Capture monitor names at EACH dock location and substitute the
        placeholders in ~/.config/aerospace/aerospace.toml under
        [workspace-to-monitor-force-assignment] (and the <primary-external-name>
        in ~/.config/sketchybar/sketchybarrc):
          aerospace list-monitors
        Edit the TOML + sketchybarrc, replacing each
        <office-central-monitor-name>, <home-centre-monitor-name>,
        <home-left-monitor-name>, <primary-external-name> placeholder,
        then reload:
          aerospace reload-config
          brew services restart sketchybar
     e) Walk docs/manual-smoke/desktop-layer1.md at your cadence.
```

- [ ] **Step 6: Shellcheck install-macos.sh**

Run: `shellcheck install-macos.sh`
Expected: silent.

- [ ] **Step 7: Run tests — AC-20..22 pass**

- [ ] **Step 8: Commit**

```bash
git add install-macos.sh scripts/test-plan-desktop-layer1.sh
git commit -m "feat(install-macos): link desktop layer 1 configs + bootstrap LaunchAgents"
```

---

## Task 13: Add Layer 1 desktop smoke-checks to `scripts/verify.sh`

**Files:**
- Modify: `scripts/verify.sh`

Design §5.5 calls for macOS-gated smoke checks. No new AC line — verify.sh is a complementary runtime tool, not part of the test-plan. But we still shellcheck it and ensure it passes.

- [ ] **Step 1: Locate the insertion point**

Run: `grep -n "Layer 1b-iii" scripts/verify.sh`
Expected: match near the end of the file.

- [ ] **Step 2: Append the Desktop Layer 1 block**

Insert BEFORE the `# ── 5. Manual steps reminder ───` block in `scripts/verify.sh`:

```bash
# ── Desktop Layer 1 (macOS only) ─────────────────────────────────────
if [[ "$PLATFORM" == "macos" ]]; then
  echo ""
  echo "Desktop Layer 1:"
  # shellcheck disable=SC2016  # $HOME expansion inside inner bash -c is intentional
  check "aerospace config symlink resolves" \
    bash -c 'test -L "$HOME/.config/aerospace/aerospace.toml" && test -e "$HOME/.config/aerospace/aerospace.toml"'
  # shellcheck disable=SC2016
  check "sketchybarrc symlink resolves" \
    bash -c 'test -L "$HOME/.config/sketchybar/sketchybarrc" && test -e "$HOME/.config/sketchybar/sketchybarrc"'
  # shellcheck disable=SC2016
  check "sketchybar/colors.sh symlink resolves" \
    bash -c 'test -L "$HOME/.config/sketchybar/colors.sh" && test -e "$HOME/.config/sketchybar/colors.sh"'
  # shellcheck disable=SC2016
  check "sketchybar/plugins symlink resolves as a directory" \
    bash -c 'test -L "$HOME/.config/sketchybar/plugins" && test -d "$HOME/.config/sketchybar/plugins"'
  # shellcheck disable=SC2016
  check "bordersrc symlink resolves" \
    bash -c 'test -L "$HOME/.config/borders/bordersrc" && test -e "$HOME/.config/borders/bordersrc"'
  check "sketchybar LaunchAgent loaded" \
    bash -c "launchctl print gui/\$(id -u)/com.felixkratz.sketchybar"
  check "borders LaunchAgent loaded" \
    bash -c "launchctl print gui/\$(id -u)/com.felixkratz.borders"
fi
```

- [ ] **Step 3: Shellcheck**

Run: `shellcheck scripts/verify.sh`
Expected: silent.

- [ ] **Step 4: Commit**

```bash
git add scripts/verify.sh
git commit -m "feat(verify): add Desktop Layer 1 smoke checks (macOS only)"
```

---

## Task 14: Create `docs/manual-smoke/desktop-layer1.md` (AC-23)

**Files:**
- Create: `docs/manual-smoke/desktop-layer1.md`
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Append AC-23 block**

```bash
# ── AC-23: manual-smoke/desktop-layer1.md populated ──────────────────
echo ""
echo "AC-23: manual-smoke/desktop-layer1.md populated"
check "manual-smoke/desktop-layer1.md exists" \
  test -f docs/manual-smoke/desktop-layer1.md
check "manual-smoke has 'When to run' section" \
  grep -qE '^## When to run' docs/manual-smoke/desktop-layer1.md
check "manual-smoke has 'Checklist' section" \
  grep -qE '^## Checklist' docs/manual-smoke/desktop-layer1.md
check "manual-smoke has 'Failure modes' section" \
  grep -qE '^## Failure modes' docs/manual-smoke/desktop-layer1.md
# Count checklist items — expect ≥ 10 in main + ≥ 3 in failure modes.
checklist_items=$(awk '/^## Checklist/,/^## Failure modes/' docs/manual-smoke/desktop-layer1.md \
                  | grep -cE '^- \[ \]')
failure_items=$(awk '/^## Failure modes/,0' docs/manual-smoke/desktop-layer1.md \
               | grep -cE '^- \[ \]')
if (( checklist_items >= 10 )); then
  ok "checklist has ≥ 10 items ($checklist_items)"
else
  nok "checklist has ≥ 10 items ($checklist_items)"
fi
if (( failure_items >= 3 )); then
  ok "failure modes has ≥ 3 drill items ($failure_items)"
else
  nok "failure modes has ≥ 3 drill items ($failure_items)"
fi
```

- [ ] **Step 2: Run tests — AC-23 fails**

- [ ] **Step 3: Create `docs/manual-smoke/desktop-layer1.md`**

```markdown
# Manual smoke — Desktop Layer 1 (AeroSpace + SketchyBar + JankyBorders)

Track runtime behaviour that CI cannot observe. Tick each box as you confirm
it. Leave unticked until you've actually seen it pass at the current dock
location.

## When to run

- First dock at office (laptop + central external).
- First dock at home (laptop + centre external + left external).
- After every `install-macos.sh` re-run that modifies Layer 1 files.
- After every version bump of AeroSpace, SketchyBar, or JankyBorders
  (`brew bundle` output lists the delta).

## Checklist

### SketchyBar renders
- [ ] Primary external monitor: top bar is visible, Dracula Background.
- [ ] Laptop and secondary external: no SketchyBar (correct — `display=` pin).
- [ ] Bar shows 9 items: 4 workspace pills, focused-app label on the left;
      clock, battery, volume, wifi, focus-mode, zscaler on the right.
- [ ] JetBrainsMono Nerd Font glyphs render (wifi, battery, clock, volume).
- [ ] Native menu bar is hidden (`_HIHideMenuBar` took effect after
      `killall SystemUIServer`).

### AeroSpace tiles
- [ ] `Alt + 1..4` switches workspaces; active pill goes Purple on the bar.
- [ ] `Alt + Shift + 1..4` moves the focused window across workspaces.
- [ ] `Alt + h/j/k/l` moves focus between tiles.
- [ ] `Alt + Shift + h/j/k/l` rearranges tiles within a workspace.
- [ ] `Alt + Slash` toggles horizontal/vertical tile orientation.
- [ ] `Alt + F` toggles fullscreen on the focused window.

### Monitor pinning
- [ ] Office dock: `<office-central-monitor-name>` placeholder substituted;
      workspace 1 (term) and workspace 2 (edge) land on the central external.
- [ ] Home dock: `<home-centre-monitor-name>` + `<home-left-monitor-name>`
      substituted; workspace 1 on centre, workspace 3 (comms) on left.
- [ ] Workspace 4 (scratch) follows the focused monitor — unpinned.

### App pinning
- [ ] First-launch of kitty lands on workspace 1 (term).
- [ ] First-launch of Microsoft Edge lands on workspace 2 (edge).
- [ ] First-launch of Microsoft Teams lands on workspace 3 (comms).
- [ ] First-launch of Microsoft Outlook lands on workspace 3 (comms).
- [ ] VS Code / Word / Excel / PowerPoint land on the *current* workspace.

### JankyBorders focus indicator
- [ ] Focused window shows a Dracula Purple border (`#BD93F9`).
- [ ] Unfocused windows show a Dracula Current-Line border (`#44475A`).
- [ ] Borders are round-cornered and hidpi-clean on Retina.

### SketchyBar live data
- [ ] Zscaler item green when `pgrep -qx ZscalerTunnel` is live; red otherwise.
- [ ] Focus-Mode item appears Purple when macOS Focus is active; hidden
      (`drawing=off`) otherwise.
- [ ] Wifi item shows the current SSID in Cyan; disconnect glyph when offline.
- [ ] Volume item reflects `Fn + F11/F12` (or media keys) within 1 s.
- [ ] Battery item renders current percent; icon changes on AC connect.
- [ ] Clock item shows `EEE dd MMM  HH:mm` and ticks each minute.

## Failure modes

### SketchyBar respawn
- [ ] `killall sketchybar` — SketchyBar LaunchAgent respawns within 10 s
      (ThrottleInterval).
- [ ] Bar repopulates with all 9 items after respawn.

### Borders respawn
- [ ] `killall borders` — borders daemon respawns; focus colour returns.

### AeroSpace unplug race
- [ ] Unplug external while on workspace 1 — layout re-flows cleanly to
      the remaining monitor; no stuck windows.
- [ ] Re-plug external — workspace 1 reclaims its pinned monitor on next
      `Alt + 1`.

### Focus-mode resilience
- [ ] Corrupt `~/Library/DoNotDisturb/DB/Assertions.json` (e.g. truncate
      to `{}`). Focus-mode item degrades to `drawing=off` — bar still
      renders the other 8 items.

### Teams bundle-ID drift
- [ ] `osascript -e 'id of app "Microsoft Teams"'` — should print
      `com.microsoft.teams2`. If different, update the
      `[[on-window-detected]]` rule in `aerospace.toml`.
```

- [ ] **Step 4: Run tests — AC-23 passes**

- [ ] **Step 5: Markdownlint-clean**

Run: `markdownlint-cli2 docs/manual-smoke/desktop-layer1.md`
Expected: silent (or a benign advisory — if MD033/MD022-style nits appear,
fix them in the file before committing).

- [ ] **Step 6: Commit**

```bash
git add docs/manual-smoke/desktop-layer1.md scripts/test-plan-desktop-layer1.sh
git commit -m "docs(manual-smoke): add Desktop Layer 1 checklist"
```

---

## Task 15: Wire `test-plan-desktop-layer1.sh` into CI (AC-24)

**Files:**
- Modify: `../.github/workflows/verify.yml` (repository root — NOT `macos-dev/`)
- Modify: `scripts/test-plan-desktop-layer1.sh`

NOTE: the verify.yml file lives at the repository root (`/home/sweeand/andrewesweet/setup/.github/workflows/verify.yml`), one level above `macos-dev/`. From the macos-dev worktree you access it at `../.github/workflows/verify.yml` (or via absolute path).

- [ ] **Step 1: Append AC-24 block to the test script**

```bash
# ── AC-24: test-plan-desktop-layer1.sh wired into CI ─────────────────
echo ""
echo "AC-24: test-plan-desktop-layer1.sh wired into .github/workflows/verify.yml"
# Resolve the repository root from MACOS_DEV.
REPO_ROOT="$(cd "$MACOS_DEV/.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/verify.yml"
if [[ -f "$WORKFLOW" ]]; then
  # Expect the script name to appear at least twice — once in lint job,
  # once in macos-verify job.
  hits=$(grep -c 'test-plan-desktop-layer1.sh' "$WORKFLOW" || true)
  if (( hits >= 2 )); then
    ok "verify.yml invokes test-plan-desktop-layer1.sh ($hits times)"
  else
    nok "verify.yml invokes test-plan-desktop-layer1.sh ($hits times; need ≥ 2)"
  fi
else
  skp "verify.yml wiring" "workflow not found at $WORKFLOW"
fi
```

- [ ] **Step 2: Run tests — AC-24 fails**

- [ ] **Step 3: Open the CI workflow**

Open (via absolute path from the worktree): `/home/sweeand/andrewesweet/setup/.github/workflows/verify.yml`

- [ ] **Step 4: Add the step to the `lint` job**

Locate the `- name: Plans 14-16 scripts/cheatsheet/readme smoke tests` step (around line 89–90). AFTER that step (before the `- name: DOTFILES self-resolution smoke test (macos installer)` step), insert:

```yaml
      - name: Desktop Layer 1 smoke tests
        run: bash macos-dev/scripts/test-plan-desktop-layer1.sh
```

- [ ] **Step 5: Add the step to the `macos-verify` job**

Locate the SAME step label `- name: Plans 14-16 scripts/cheatsheet/readme smoke tests` in the macos-verify job (around line 186–187). AFTER that step, insert the identical block:

```yaml
      - name: Desktop Layer 1 smoke tests
        run: bash macos-dev/scripts/test-plan-desktop-layer1.sh
```

- [ ] **Step 6: Validate YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('/home/sweeand/andrewesweet/setup/.github/workflows/verify.yml'))"`
Expected: exit 0.

- [ ] **Step 7: Run tests — AC-24 passes**

- [ ] **Step 8: Commit from the macos-dev worktree (working-tree-aware)**

Because `verify.yml` lives OUTSIDE the `macos-dev/` directory, `git add` from the macos-dev worktree needs the absolute path OR you must `cd` to the repo root first. From the macos-dev worktree:

```bash
git -C "$(cd .. && pwd)" add .github/workflows/verify.yml
git add scripts/test-plan-desktop-layer1.sh
git commit -m "ci(verify): wire test-plan-desktop-layer1.sh into lint + macos-verify"
```

NOTE: if you are operating in a dedicated worktree for this feature, `git -C` targets the correct repo. Verify with `git log -1 -- .github/workflows/verify.yml` from the worktree root.

---

## Task 16: Final AC-25 wrapper + full-repo gates

**Files:**
- Modify: `scripts/test-plan-desktop-layer1.sh`

- [ ] **Step 1: Confirm AC-25 (end-to-end) is structurally satisfied**

AC-25 is the test-plan script itself exiting 0 when every AC passes and 1 when any AC fails. No extra block needed — the `(( fail == 0 ))` at the end already enforces this. Run:

```bash
bash scripts/test-plan-desktop-layer1.sh
```

Expected: all 25 ACs pass (skp on Linux where noted), exit 0.

- [ ] **Step 2: Repo-wide shellcheck pass**

```bash
find . -type f -name '*.sh' -not -path './.worktrees/*' -print0 \
  | xargs -0 shellcheck
```

Expected: silent (exit 0).

- [ ] **Step 3: All other test-plans still pass**

```bash
for f in scripts/test-plan*.sh; do
  bash "$f" >/dev/null 2>&1 || echo "FAIL: $f"
done
```

Expected: no "FAIL:" lines.

- [ ] **Step 4: YAML lint (quick sanity)**

```bash
python3 -c "import yaml; yaml.safe_load(open('/home/sweeand/andrewesweet/setup/.github/workflows/verify.yml'))"
```

Expected: exit 0.

- [ ] **Step 5: If all four gates green, the layer is ready to merge**

No commit needed for this task — all validations are read-only.

---

## Execution notes

- Sequential task order is important: Tasks 4 onward reference `@HOMEBREW_PREFIX@` / `@HOME@` markers introduced in Task 3's mental model; Task 11's plists are sed-substituted by Task 12's install-macos.sh block.
- Judgement-heavy tasks to flag for review: Task 4 (aerospace.toml structure), Task 8 (focus_mode.sh touches `~/Library/DoNotDisturb/DB/`), Task 12 (LaunchAgent bootstrap loop). Dispatch a review subagent for these. Tasks 2, 3, 5, 6, 7, 9, 10, 13, 14, 15 are mechanical — verify inline.
- Each task's final step commits in isolation. If a commit fails to run due to shellcheck or test failure, the failing step stays open until fixed; do not force-commit.
- Convention #12 (pre-existing untracked files on main): `git add <specific-files>` per task; never `git add -A`.
