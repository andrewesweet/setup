# Desktop Layer 2 Implementation Plan: Keyboard foundation (Hammerspoon + skhd)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Caps Lock → Escape-on-tap / Hyper-on-hold via Hammerspoon, and 11 Hyper+letter app-launch bindings via skhd. Ship Karabiner-Elements' equivalent JSON dormant (committed but unsymlinked) so the Appendix-B upgrade path is code-verifiable.

**Architecture:** Hammerspoon (cask, login item) runs a ~60-line `init.lua` that registers an `hs.eventtap` on keycode 57 (Caps Lock) with a 200 ms tap-vs-hold threshold; tap emits Escape, hold sets a flag so the next keyDown is emitted with `{cmd=true, alt=true, ctrl=true, shift=true}`. skhd (formula, LaunchAgent) consumes the four-modifier chord and maps 11 Hyper+letter combinations to `open -a/-na` commands plus one `aerospace reload-config`. Karabiner config sits under `karabiner/complex_modifications/desktop-layer2.json`; install-macos.sh symlinks it only when `DESKTOP_LAYER2_USE_KARABINER=true`.

**Tech Stack:** bash 5, Hammerspoon (Lua), skhd (koekeishiya/formulae), Karabiner-Elements (dormant JSON), LaunchAgents, luac, jq, plutil.

**Spec reference:** `docs/plans/2026-04-14-macos-desktop-env-design.md` §3.4, §3.5, §3.7, §4.2, §5.1, §5.2, §5.3, Appendix A.1.3, Appendix B.

**Platform scope:** macOS only (static checks pass on Linux via `skp`). WSL install untouched.

**Prerequisite:** Desktop Layer 1 merged (this plan rebases on `feature/desktop-layer2-keyboard` after Layer 1's `main`). Hammerspoon and skhd both require the `~/Applications/` cask appdir env var set by Layer 1 Task 3; this plan does not re-add it.

---

## Acceptance Criteria (Specification by Example)

Each bullet is a testable assertion. The acceptance test script `scripts/test-plan-desktop-layer2.sh` validates every assertion end-to-end.

**AC-1: Brewfile declares Hammerspoon cask, skhd tap and formula**
```
Given: macos-dev/Brewfile
When: inspected
Then: contains `cask "hammerspoon"`
And: contains `tap "koekeishiya/formulae"`
And: contains `brew "koekeishiya/formulae/skhd"`
```

**AC-2: tools.txt declares the skhd formula (casks intentionally absent)**
```
Given: macos-dev/tools.txt
When: inspected
Then: contains a `brew:koekeishiya/formulae/skhd` row
And: contains NO `brew:hammerspoon` row (Hammerspoon is a cask — skipped per §5.3)
```

**AC-3: hammerspoon/init.lua parses via `luac -p`**
```
Given: macos-dev/hammerspoon/init.lua
When: `luac -p hammerspoon/init.lua`
Then: exit 0 (falls back to `skp` on machines without a Lua toolchain)
```

**AC-4: init.lua registers an eventtap on keycode 57 (Caps Lock)**
```
Given: macos-dev/hammerspoon/init.lua (comments stripped)
When: inspected
Then: contains `hs.eventtap.new`
And: contains `keyCode()` reference to `57` (the literal keycode for Caps Lock)
And: handles both keyDown and keyUp via `hs.eventtap.event.types.keyDown` and `.keyUp`
```

**AC-5: init.lua defines a 200 ms tap-vs-hold threshold constant**
```
Given: macos-dev/hammerspoon/init.lua
When: inspected
Then: declares a constant named `THRESHOLD_MS` equal to `200`
```

**AC-6: init.lua emits the four-modifier Hyper chord on hold**
```
Given: macos-dev/hammerspoon/init.lua (comments stripped)
When: inspected
Then: contains all four modifier keys in a single eventtap flags table:
      `cmd=true`, `alt=true`, `ctrl=true`, `shift=true`
```

**AC-7: init.lua wraps the eventtap registration in `pcall()` for crash safety**
```
Given: macos-dev/hammerspoon/init.lua (comments stripped)
When: inspected
Then: contains a `pcall(` invocation guarding the eventtap setup
```

**AC-8: skhd/.skhdrc parses via `skhd --parse` (macOS only, else skp)**
```
Given: macos-dev/skhd/.skhdrc
When: on macOS with skhd installed: `skhd --parse skhd/.skhdrc`
Then: exit 0
And: on Linux: skp "skhd not installed"
```

**AC-9: skhd/.skhdrc declares all 11 Hyper bindings**
```
Given: macos-dev/skhd/.skhdrc
When: inspected
Then: the 11 bindings (`e`, `o`, `t`, `k`, `n`, `w`, `x`, `p`, `f`, `space`, `r`)
      all appear as `cmd + alt + ctrl + shift - <key> : ...`
```

**AC-10: skhd/.skhdrc's `aerospace reload-config` binding uses `@HOMEBREW_PREFIX@`**
```
Given: macos-dev/skhd/.skhdrc
When: inspected
Then: the `r` binding calls `@HOMEBREW_PREFIX@/bin/aerospace reload-config`
```

**AC-11: karabiner/complex_modifications/desktop-layer2.json is valid JSON**
```
Given: macos-dev/karabiner/complex_modifications/desktop-layer2.json
When: `jq empty karabiner/complex_modifications/desktop-layer2.json`
Then: exit 0
```

**AC-12: Karabiner JSON declares Caps→Escape/Hyper semantics**
```
Given: macos-dev/karabiner/complex_modifications/desktop-layer2.json
When: parsed via jq
Then: .title is non-empty
And: .rules is a non-empty array
And: at least one rule references `"key_code": "caps_lock"` via jq -e
```

**AC-13: launchagents/com.koekeishiya.skhd.plist is plutil-lint clean + uses markers**
```
Given: macos-dev/launchagents/com.koekeishiya.skhd.plist
When: `plutil -lint` (skp on non-macOS)
Then: exit 0
And: file contains `@HOMEBREW_PREFIX@/bin/skhd`
And: file contains `@HOME@` in StandardOutPath / StandardErrorPath
```

**AC-14: install-macos.sh links Hammerspoon + skhd by default; does NOT link Karabiner by default**
```
Given: macos-dev/install-macos.sh
When: inspected
Then: contains `link hammerspoon/init.lua .hammerspoon/init.lua`
And: contains `link skhd/.skhdrc .config/skhd/skhdrc`
And: the Karabiner symlink is GUARDED by `${DESKTOP_LAYER2_USE_KARABINER:-false}`
And: the Karabiner symlink target is `.config/karabiner/assets/complex_modifications/desktop-layer2.json`
```

**AC-15: install-macos.sh bootstraps the skhd LaunchAgent via @HOMEBREW_PREFIX@/@HOME@ substitution**
```
Given: macos-dev/install-macos.sh
When: the "Desktop LaunchAgents" block inspected
Then: the iteration includes `com.koekeishiya.skhd.plist`
And: the block still calls `launchctl bootout` then `launchctl bootstrap`
```

**AC-16: scripts/desktop-layer2-switch-to-karabiner.sh exists, is shellcheck-clean, and flips the symlink**
```
Given: macos-dev/scripts/desktop-layer2-switch-to-karabiner.sh
When: inspected
Then: file exists and is executable (`-x`)
And: `shellcheck` passes
And: body contains `killall Hammerspoon` (stop Hammerspoon)
And: body contains `rm -f "$HOME/.hammerspoon/init.lua"` (unlink)
And: body contains `link karabiner/complex_modifications/desktop-layer2.json` or equivalent
And: body contains `DESKTOP_LAYER2_USE_KARABINER=true` OR explicitly invokes install-macos.sh with it
```

**AC-17: install-macos.sh Next-steps mentions the Hammerspoon/skhd Accessibility grants**
```
Given: macos-dev/install-macos.sh
When: inspected
Then: Next-steps mentions "Hammerspoon" in the Accessibility grant list
And: Next-steps mentions "skhd" in the Accessibility grant list
And: Next-steps mentions "Launch Hammerspoon at login" (the Hammerspoon prefs toggle)
```

**AC-18: docs/manual-smoke/desktop-layer2.md exists with a populated checklist**
```
Given: macos-dev/docs/manual-smoke/desktop-layer2.md
When: inspected
Then: file exists
And: contains a "## When to run" section
And: contains a "## Checklist" section with at least 12 `- [ ]` items covering:
     Caps-tap emits Escape, Caps-hold + letter emits Hyper-<letter>,
     each of 11 Hyper bindings fires, aerospace reload works, skhd restart on kill
And: contains a "## Failure modes" section with at least 3 `- [ ]` drills
```

**AC-19: test-plan-desktop-layer2.sh is wired into CI verify.yml**
```
Given: the repository-root .github/workflows/verify.yml
When: inspected
Then: the `lint` job invokes `bash macos-dev/scripts/test-plan-desktop-layer2.sh`
And: the `macos-verify` job invokes the same
```

**AC-20: End-to-end acceptance script enumerates every AC**
```
When: `bash scripts/test-plan-desktop-layer2.sh` runs on macOS or Linux
Then: every AC above is checked (via check/skp)
And: exit code is 0 if fail == 0, 1 otherwise
```

---

## File Structure

**New directories:**
- `hammerspoon/`
- `skhd/`
- `karabiner/complex_modifications/`

**New files (created by this plan):**
- `hammerspoon/init.lua`
- `skhd/.skhdrc`
- `karabiner/complex_modifications/desktop-layer2.json`
- `launchagents/com.koekeishiya.skhd.plist`
- `scripts/desktop-layer2-switch-to-karabiner.sh`
- `docs/manual-smoke/desktop-layer2.md`
- `scripts/test-plan-desktop-layer2.sh`

**Modified files:**
- `Brewfile` — new "Desktop · keyboard" section
- `tools.txt` — add skhd row
- `install-macos.sh` — new Layer 2 symlink block, extended LaunchAgent loop, Next-steps additions
- `.github/workflows/verify.yml` — wire `test-plan-desktop-layer2.sh` into lint + macos-verify

**Untouched (preserved):**
- All Layer 1 files (this plan extends, never modifies, `install-macos.sh`'s Desktop LaunchAgent loop)
- `install-wsl.sh`

---

## Task 0: Bootstrap Acceptance Test Script (Red)

**Files:**
- Create: `scripts/test-plan-desktop-layer2.sh`

- [ ] **Step 1: Copy the preamble from the shipped layer1a script**

Run: `sed -n '1,55p' scripts/test-plan-layer1a.sh > scripts/test-plan-desktop-layer2.sh`

- [ ] **Step 2: Patch the per-layer header lines**

Open `scripts/test-plan-desktop-layer2.sh` and edit:
- Line 2: `test-plan-desktop-layer2.sh — acceptance tests for Desktop Layer 2 (Hammerspoon + skhd + dormant Karabiner)`
- Line 7: `bash scripts/test-plan-desktop-layer2.sh              # safe tests only`
- Line 8: `bash scripts/test-plan-desktop-layer2.sh --full       # + invasive tests (skhd --parse, plutil)`
- Line 10: `Each AC from the Desktop Layer 2 plan is implemented as a labelled check.`

- [ ] **Step 3: Append the header + summary + chmod**

Append:

```bash

echo "Desktop Layer 2 acceptance tests (Hammerspoon + skhd + dormant Karabiner)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1..20 get appended by subsequent tasks ─────────────────────────

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
```

Then: `chmod +x scripts/test-plan-desktop-layer2.sh`

- [ ] **Step 4: Run — trivially green**

Run: `bash scripts/test-plan-desktop-layer2.sh`
Expected: 0/0/0, exit 0.

- [ ] **Step 5: Shellcheck**

Run: `shellcheck scripts/test-plan-desktop-layer2.sh`
Expected: silent.

- [ ] **Step 6: Commit**

```bash
git add scripts/test-plan-desktop-layer2.sh
git commit -m "test(desktop-layer2): scaffold acceptance test script (preamble only)"
```

---

## Task 1: Add Desktop Layer 2 sections to Brewfile + tools.txt (AC-1, AC-2)

**Files:**
- Modify: `Brewfile`, `tools.txt`
- Modify: `scripts/test-plan-desktop-layer2.sh`

- [ ] **Step 1: Append AC-1, AC-2 blocks to the test script**

```bash
# ── AC-1: Brewfile declares Hammerspoon + skhd ──────────────────────
echo ""
echo "AC-1: Brewfile declares keyboard-layer tooling"
check "Brewfile has cask \"hammerspoon\"" \
  grep -qE '^cask "hammerspoon"' Brewfile
check "Brewfile has tap \"koekeishiya/formulae\"" \
  grep -qE '^tap "koekeishiya/formulae"' Brewfile
check "Brewfile has brew \"koekeishiya/formulae/skhd\"" \
  grep -qE '^brew "koekeishiya/formulae/skhd"' Brewfile

# ── AC-2: tools.txt declares skhd; casks intentionally absent ────────
echo ""
echo "AC-2: tools.txt declares skhd formula (no cask rows)"
check "tools.txt has brew:koekeishiya/formulae/skhd" \
  grep -qE '^skhd[[:space:]]+brew:koekeishiya/formulae/skhd' tools.txt
if grep -qE '^[a-z].*brew:hammerspoon' tools.txt; then
  nok "tools.txt does NOT list hammerspoon (cask)"
else
  ok "tools.txt does NOT list hammerspoon (cask)"
fi
check "check-tool-manifest.sh still passes" \
  bash scripts/check-tool-manifest.sh
```

- [ ] **Step 2: Run tests — AC-1, 2 fail**

- [ ] **Step 3: Append the Brewfile section**

Append at the bottom of `Brewfile`:

```ruby

# ── Desktop · keyboard (Layer 2 desktop) ──────────────────────────────
cask "hammerspoon"
tap "koekeishiya/formulae"
brew "koekeishiya/formulae/skhd"
# Karabiner-Elements cask is deferred — see design Appendix B.
# karabiner/complex_modifications/desktop-layer2.json ships dormant
# and is only symlinked when DESKTOP_LAYER2_USE_KARABINER=true.
```

- [ ] **Step 4: Append the tools.txt row**

Append under the Layer 1 desktop section (add a new subsection header for Layer 2):

```
# ── Desktop keyboard (Layer 2 desktop) ───────────────────────────────
skhd                 brew:koekeishiya/formulae/skhd              apt:-                   apk:-
```

- [ ] **Step 5: Run manifest + layer tests**

```bash
bash scripts/check-tool-manifest.sh    # exit 0
bash scripts/test-plan-desktop-layer2.sh   # AC-1, 2 pass
```

- [ ] **Step 6: Commit**

```bash
git add Brewfile tools.txt scripts/test-plan-desktop-layer2.sh
git commit -m "feat(brewfile): add Hammerspoon + skhd (desktop layer 2)"
```

---

## Task 2: Create `hammerspoon/init.lua` (AC-3 through AC-7)

**Files:**
- Create: `hammerspoon/init.lua`
- Modify: `scripts/test-plan-desktop-layer2.sh`

- [ ] **Step 1: Append AC-3 through AC-7 blocks**

```bash
# ── AC-3: init.lua parses via luac -p ────────────────────────────────
echo ""
echo "AC-3: hammerspoon/init.lua parses via luac -p"
if command -v luac &>/dev/null; then
  if luac -p hammerspoon/init.lua >/dev/null 2>&1; then
    ok "luac -p hammerspoon/init.lua"
  else
    nok "luac -p hammerspoon/init.lua"
  fi
else
  skp "luac -p hammerspoon/init.lua" "luac not available"
fi

# ── AC-4: init.lua registers eventtap on keycode 57 (Caps Lock) ──────
echo ""
echo "AC-4: init.lua handles Caps Lock keycode 57"
lua_body="$(sed 's/--.*//' hammerspoon/init.lua)"
if printf '%s' "$lua_body" | grep -q 'hs\.eventtap\.new'; then
  ok "init.lua calls hs.eventtap.new"
else
  nok "init.lua calls hs.eventtap.new"
fi
if printf '%s' "$lua_body" | grep -qE 'keyCode\(\)[^=]*==[^0-9]*57|57\b'; then
  ok "init.lua references keycode 57"
else
  nok "init.lua references keycode 57"
fi
for typ in 'keyDown' 'keyUp'; do
  if printf '%s' "$lua_body" | grep -q "types\\.$typ"; then
    ok "init.lua subscribes to hs.eventtap.event.types.$typ"
  else
    nok "init.lua subscribes to hs.eventtap.event.types.$typ"
  fi
done

# ── AC-5: init.lua defines THRESHOLD_MS = 200 ────────────────────────
echo ""
echo "AC-5: init.lua defines THRESHOLD_MS = 200"
if printf '%s' "$lua_body" | grep -qE 'THRESHOLD_MS[[:space:]]*=[[:space:]]*200'; then
  ok "THRESHOLD_MS = 200"
else
  nok "THRESHOLD_MS = 200"
fi

# ── AC-6: init.lua emits the four-modifier Hyper chord ───────────────
echo ""
echo "AC-6: init.lua emits Cmd+Alt+Ctrl+Shift on hold"
# Search for all four modifiers present in a single region (lua table).
for mod in 'cmd[[:space:]]*=[[:space:]]*true' \
           'alt[[:space:]]*=[[:space:]]*true' \
           'ctrl[[:space:]]*=[[:space:]]*true' \
           'shift[[:space:]]*=[[:space:]]*true'; do
  if printf '%s' "$lua_body" | grep -qE "$mod"; then
    ok "init.lua sets $mod"
  else
    nok "init.lua sets $mod"
  fi
done

# ── AC-7: init.lua wraps eventtap setup in pcall() ───────────────────
echo ""
echo "AC-7: init.lua wraps setup in pcall()"
if printf '%s' "$lua_body" | grep -q 'pcall('; then
  ok "init.lua contains pcall("
else
  nok "init.lua contains pcall("
fi
```

- [ ] **Step 2: Run tests — AC-3..7 fail**

- [ ] **Step 3: Create `hammerspoon/init.lua`**

```lua
-- hammerspoon/init.lua — Desktop Layer 2 keyboard foundation.
--
-- Sole responsibility: Caps Lock tap → Escape; Caps Lock hold → Hyper
-- (Cmd+Alt+Ctrl+Shift applied to the next keypress). Nothing else.
--
-- Spec: docs/plans/2026-04-14-macos-desktop-env-design.md §3.4.
-- Requires: Accessibility permission for Hammerspoon.app.
-- Requires: "Launch Hammerspoon at login" toggled in Hammerspoon prefs.

local THRESHOLD_MS = 200  -- tap-vs-hold distinction (~humanly imperceptible on hold)
local CAPS_LOCK_KEYCODE = 57

-- State tracked across the keyDown/keyUp callback invocations.
local state = {
  caps_down_at = nil,     -- hs.timer.secondsSinceEpoch() when Caps pressed
  next_is_hyper = false,  -- set on Caps release when hold threshold exceeded
  sent_hyper_for_current_hold = false,
}

-- Modifier table applied to the next keypress when we synthesise a Hyper
-- chord. ALL FOUR modifiers are required so skhd sees an unambiguous
-- "Hyper" without competing with Cmd-only or Alt-only bindings.
local HYPER_MODS = { cmd = true, alt = true, ctrl = true, shift = true }

local function millis_since(t)
  return (hs.timer.secondsSinceEpoch() - t) * 1000
end

local function on_caps_event(event)
  local t = event:getType()
  local keycode = event:getKeyCode()

  if keycode ~= CAPS_LOCK_KEYCODE then
    -- Foreign key press WHILE Caps is held: inject Hyper modifiers.
    if state.caps_down_at and t == hs.eventtap.event.types.keyDown then
      if millis_since(state.caps_down_at) >= THRESHOLD_MS then
        state.sent_hyper_for_current_hold = true
        event:setFlags(HYPER_MODS)
      end
    end
    return false  -- let the (possibly-modified) event through
  end

  if t == hs.eventtap.event.types.keyDown then
    if not state.caps_down_at then
      state.caps_down_at = hs.timer.secondsSinceEpoch()
      state.sent_hyper_for_current_hold = false
    end
    return true   -- swallow the raw Caps Lock down event
  end

  if t == hs.eventtap.event.types.keyUp then
    local held_ms = state.caps_down_at and millis_since(state.caps_down_at) or 0
    if held_ms < THRESHOLD_MS and not state.sent_hyper_for_current_hold then
      -- Tap → Escape.
      hs.eventtap.keyStroke({}, "escape", 0)
    end
    state.caps_down_at = nil
    state.sent_hyper_for_current_hold = false
    return true   -- swallow the raw Caps Lock up event
  end

  return false
end

-- Wrap registration in pcall so a runtime error surfaces in the console
-- rather than crashing the Hammerspoon daemon. Menu-bar icon stays
-- responsive for "Reload Config" regardless.
local ok, err = pcall(function()
  caps_tap = hs.eventtap.new(
    { hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp },
    on_caps_event
  )
  caps_tap:start()
end)

if not ok then
  hs.alert.show("Hammerspoon init error: " .. tostring(err))
  print("init.lua pcall failed: " .. tostring(err))
end
```

- [ ] **Step 4: Verify luac parse (macOS / Linux with Lua)**

Run: `command -v luac && luac -p hammerspoon/init.lua && echo OK || echo SKIP`
Expected: "OK" on a machine with Lua; "SKIP" elsewhere.

- [ ] **Step 5: Run tests — AC-3..7 pass**

- [ ] **Step 6: Commit**

```bash
git add hammerspoon/init.lua scripts/test-plan-desktop-layer2.sh
git commit -m "feat(hammerspoon): add Caps→Escape/Hyper init.lua (desktop layer 2)"
```

---

## Task 3: Create `skhd/.skhdrc` (AC-8, AC-9, AC-10)

**Files:**
- Create: `skhd/.skhdrc`
- Modify: `scripts/test-plan-desktop-layer2.sh`

- [ ] **Step 1: Append AC-8, AC-9, AC-10 blocks**

```bash
# ── AC-8: skhd/.skhdrc parses via skhd --parse (else skp) ────────────
echo ""
echo "AC-8: skhd/.skhdrc parses via skhd --parse"
if [[ "$PLATFORM" == "macos" ]] && command -v skhd &>/dev/null; then
  if skhd --parse skhd/.skhdrc >/dev/null 2>&1; then
    ok "skhd --parse skhd/.skhdrc"
  else
    nok "skhd --parse skhd/.skhdrc"
  fi
else
  skp "skhd --parse skhd/.skhdrc" "skhd not installed"
fi

# ── AC-9: skhd/.skhdrc declares all 11 Hyper bindings ────────────────
echo ""
echo "AC-9: skhd/.skhdrc declares 11 Hyper bindings"
skhd_body="$(sed 's/#.*//' skhd/.skhdrc)"
for key in 'e' 'o' 't' 'k' 'n' 'w' 'x' 'p' 'f' 'space' 'r'; do
  if printf '%s' "$skhd_body" \
       | grep -qE "cmd[[:space:]]*\\+[[:space:]]*alt[[:space:]]*\\+[[:space:]]*ctrl[[:space:]]*\\+[[:space:]]*shift[[:space:]]*-[[:space:]]*${key}[[:space:]]*:"; then
    ok "Hyper+$key binding declared"
  else
    nok "Hyper+$key binding declared"
  fi
done

# ── AC-10: Hyper+r binding uses @HOMEBREW_PREFIX@/bin/aerospace ──────
echo ""
echo "AC-10: Hyper+r calls @HOMEBREW_PREFIX@/bin/aerospace reload-config"
if printf '%s' "$skhd_body" \
     | grep -qE "cmd[[:space:]]*\\+[[:space:]]*alt[[:space:]]*\\+[[:space:]]*ctrl[[:space:]]*\\+[[:space:]]*shift[[:space:]]*-[[:space:]]*r[[:space:]]*:.*@HOMEBREW_PREFIX@/bin/aerospace[[:space:]]+reload-config"; then
  ok "Hyper+r uses @HOMEBREW_PREFIX@/bin/aerospace reload-config"
else
  nok "Hyper+r uses @HOMEBREW_PREFIX@/bin/aerospace reload-config"
fi
```

- [ ] **Step 2: Run tests — AC-8, 9, 10 fail**

- [ ] **Step 3: Create `skhd/.skhdrc`**

```skhd
# skhd/.skhdrc — Desktop Layer 2 Hyper bindings.
#
# Spec: docs/plans/2026-04-14-macos-desktop-env-design.md §3.5.
# Hyper = Cmd + Alt + Ctrl + Shift (sourced from Caps Lock via
# hammerspoon/init.lua). Binding scheme: Hyper + first-letter-of-app.
# Collision rule: Excel exception → `x` (Microsoft's iconography uses
# the X glyph); Edge wins `e`. See design §3.5 collision convention.
#
# The @HOMEBREW_PREFIX@ marker is substituted at install time by
# install-macos.sh (same pattern as aerospace.toml).

# ── App launch / focus — first-letter rule, Office on siblings ───────
cmd + alt + ctrl + shift - e     : open -a "Microsoft Edge"
cmd + alt + ctrl + shift - o     : open -a "Microsoft Outlook"
cmd + alt + ctrl + shift - t     : open -a "Microsoft Teams"
cmd + alt + ctrl + shift - k     : open -a kitty
cmd + alt + ctrl + shift - n     : open -na kitty --args nvim
cmd + alt + ctrl + shift - w     : open -a "Microsoft Word"
cmd + alt + ctrl + shift - x     : open -a "Microsoft Excel"
cmd + alt + ctrl + shift - p     : open -a "Microsoft PowerPoint"
cmd + alt + ctrl + shift - f     : open -a Finder

# ── Utility ──────────────────────────────────────────────────────────
# Hyper+Space: fallback launcher (Raycast ships in Layer 3; falls back
# to Spotlight semantics gracefully if Layer 3 not yet installed).
cmd + alt + ctrl + shift - space : open -a Raycast
# Hyper+R: reload AeroSpace config (for after monitor-name edits).
cmd + alt + ctrl + shift - r     : @HOMEBREW_PREFIX@/bin/aerospace reload-config
```

- [ ] **Step 4: Run tests — AC-8 (skp on Linux), AC-9, AC-10 pass**

- [ ] **Step 5: Commit**

```bash
git add skhd/.skhdrc scripts/test-plan-desktop-layer2.sh
git commit -m "feat(skhd): add 11 Hyper bindings via skhdrc (desktop layer 2)"
```

---

## Task 4: Create `karabiner/complex_modifications/desktop-layer2.json` (AC-11, AC-12)

**Files:**
- Create: `karabiner/complex_modifications/desktop-layer2.json`
- Modify: `scripts/test-plan-desktop-layer2.sh`

- [ ] **Step 1: Append AC-11, AC-12 blocks**

```bash
# ── AC-11: Karabiner JSON is valid JSON ──────────────────────────────
echo ""
echo "AC-11: karabiner/.../desktop-layer2.json parses via jq empty"
if command -v jq &>/dev/null; then
  if jq empty karabiner/complex_modifications/desktop-layer2.json >/dev/null 2>&1; then
    ok "jq empty desktop-layer2.json"
  else
    nok "jq empty desktop-layer2.json"
  fi
else
  skp "jq empty desktop-layer2.json" "jq not available"
fi

# ── AC-12: Karabiner JSON declares caps_lock → escape/Hyper ──────────
echo ""
echo "AC-12: Karabiner JSON declares Caps → Escape / Hyper semantics"
if command -v jq &>/dev/null; then
  check "title is non-empty" \
    bash -c 'jq -e ".title | length > 0" karabiner/complex_modifications/desktop-layer2.json'
  check ".rules is a non-empty array" \
    bash -c 'jq -e ".rules | type == \"array\" and length > 0" karabiner/complex_modifications/desktop-layer2.json'
  check "at least one rule references caps_lock" \
    bash -c 'jq -e "[.. | .key_code? // empty] | any(. == \"caps_lock\")" karabiner/complex_modifications/desktop-layer2.json'
else
  skp "Karabiner JSON structural checks" "jq not available"
fi
```

- [ ] **Step 2: Run tests — AC-11, 12 fail**

- [ ] **Step 3: Create `karabiner/complex_modifications/desktop-layer2.json`**

```json
{
  "title": "Desktop Layer 2 — Caps Lock → Escape on tap / Hyper on hold",
  "description": "Dormant Karabiner-Elements complex modification. Not active by default — see Appendix B of docs/plans/2026-04-14-macos-desktop-env-design.md. Semantically identical to hammerspoon/init.lua; switch via scripts/desktop-layer2-switch-to-karabiner.sh once MDM allows pqrs.org team ID G43BCU2T37.",
  "rules": [
    {
      "description": "Caps Lock → Escape on tap, Hyper (Cmd+Alt+Ctrl+Shift) on hold",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "caps_lock",
            "modifiers": { "optional": ["any"] }
          },
          "to": [
            {
              "key_code": "left_shift",
              "modifiers": ["left_command", "left_control", "left_option"]
            }
          ],
          "to_if_alone": [
            { "key_code": "escape" }
          ]
        }
      ]
    }
  ]
}
```

- [ ] **Step 4: Validate JSON**

Run: `jq empty karabiner/complex_modifications/desktop-layer2.json && echo OK`
Expected: "OK".

- [ ] **Step 5: Run tests — AC-11, 12 pass**

- [ ] **Step 6: Commit**

```bash
git add karabiner/complex_modifications/desktop-layer2.json scripts/test-plan-desktop-layer2.sh
git commit -m "feat(karabiner): add dormant Caps→Escape/Hyper JSON (desktop layer 2, Appendix B)"
```

---

## Task 5: Create `launchagents/com.koekeishiya.skhd.plist` (AC-13)

**Files:**
- Create: `launchagents/com.koekeishiya.skhd.plist`
- Modify: `scripts/test-plan-desktop-layer2.sh`

- [ ] **Step 1: Append AC-13 block**

```bash
# ── AC-13: skhd LaunchAgent plist plutil-lint clean + markers ────────
echo ""
echo "AC-13: launchagents/com.koekeishiya.skhd.plist validity"
plist=launchagents/com.koekeishiya.skhd.plist
if [[ -f "$plist" ]]; then
  ok "$plist exists"
else
  nok "$plist exists"
fi
if [[ "$(uname)" == "Darwin" ]] && command -v plutil &>/dev/null; then
  if plutil -lint "$plist" >/dev/null 2>&1; then
    ok "$plist passes plutil -lint"
  else
    nok "$plist passes plutil -lint"
  fi
else
  skp "$plist passes plutil -lint" "plutil not available"
fi
check "$plist uses @HOMEBREW_PREFIX@/bin/skhd" \
  grep -q '@HOMEBREW_PREFIX@/bin/skhd' "$plist"
check "$plist uses @HOME@ marker" \
  grep -q '@HOME@' "$plist"
```

- [ ] **Step 2: Run tests — AC-13 fails**

- [ ] **Step 3: Create `launchagents/com.koekeishiya.skhd.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.koekeishiya.skhd</string>
  <key>ProgramArguments</key>
  <array>
    <string>@HOMEBREW_PREFIX@/bin/skhd</string>
    <string>-c</string>
    <string>@HOME@/.config/skhd/skhdrc</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>@HOME@/Library/Logs/com.koekeishiya.skhd.out.log</string>
  <key>StandardErrorPath</key>
  <string>@HOME@/Library/Logs/com.koekeishiya.skhd.err.log</string>
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

NOTE: the `-c` + skhdrc-path pair in ProgramArguments is skhd's
documented form for running against a non-default rc path. This matches
the install-macos.sh symlink target `.config/skhd/skhdrc` (no dotfile).

- [ ] **Step 4: Validate plutil-lint on macOS**

Run (macOS): `plutil -lint launchagents/com.koekeishiya.skhd.plist`
Expected: "OK".

- [ ] **Step 5: Run tests — AC-13 passes**

- [ ] **Step 6: Commit**

```bash
git add launchagents/com.koekeishiya.skhd.plist scripts/test-plan-desktop-layer2.sh
git commit -m "feat(launchagents): add skhd plist with @HOMEBREW_PREFIX@ + @HOME@ markers (desktop layer 2)"
```

---

## Task 6: install-macos.sh symlinks + LaunchAgent extension + Next-steps (AC-14, AC-15, AC-17)

**Files:**
- Modify: `install-macos.sh`
- Modify: `scripts/test-plan-desktop-layer2.sh`

- [ ] **Step 1: Append AC-14, AC-15, AC-17 blocks**

```bash
# ── AC-14: install-macos.sh links Layer 2 configs ────────────────────
echo ""
echo "AC-14: install-macos.sh links Layer 2 configs"
check "link hammerspoon/init.lua" \
  grep -qE 'link[[:space:]]+hammerspoon/init\.lua[[:space:]]+\.hammerspoon/init\.lua' install-macos.sh
check "link skhd/.skhdrc" \
  grep -qE 'link[[:space:]]+skhd/\.skhdrc[[:space:]]+\.config/skhd/skhdrc' install-macos.sh
check "Karabiner link guarded by DESKTOP_LAYER2_USE_KARABINER" \
  grep -qE 'DESKTOP_LAYER2_USE_KARABINER.*true|"\$\{DESKTOP_LAYER2_USE_KARABINER:-false\}"' install-macos.sh
check "Karabiner link target is assets/complex_modifications/desktop-layer2.json" \
  grep -qE 'link[[:space:]]+karabiner/complex_modifications/desktop-layer2\.json[[:space:]]+\.config/karabiner/assets/complex_modifications/desktop-layer2\.json' install-macos.sh

# ── AC-15: install-macos.sh bootstraps skhd LaunchAgent ──────────────
echo ""
echo "AC-15: install-macos.sh bootstraps skhd LaunchAgent"
la_block="$(awk '/Desktop LaunchAgents \(macOS only\)/,/Desktop LaunchAgents loaded/' install-macos.sh)"
if printf '%s' "$la_block" | grep -q 'com.koekeishiya.skhd.plist'; then
  ok "Desktop LaunchAgent block iterates com.koekeishiya.skhd.plist"
else
  nok "Desktop LaunchAgent block iterates com.koekeishiya.skhd.plist"
fi

# ── AC-17: install-macos.sh Next-steps covers Hammerspoon + skhd ─────
echo ""
echo "AC-17: install-macos.sh Next-steps covers Hammerspoon + skhd grants"
next="$(awk '/Next steps:/,/EOF/' install-macos.sh)"
for needle in 'Hammerspoon' 'skhd' 'Launch Hammerspoon at login'; do
  if printf '%s' "$next" | grep -q -F "$needle"; then
    ok "Next-steps mentions: $needle"
  else
    nok "Next-steps mentions: $needle"
  fi
done
```

- [ ] **Step 2: Run tests — AC-14, 15, 17 all fail**

- [ ] **Step 3: Extend the desktop LaunchAgent loop**

Locate the existing Layer 1 LaunchAgent block (added in Layer 1 Task 12):

```bash
  for plist in com.felixkratz.sketchybar.plist \
               com.felixkratz.borders.plist; do
```

Append the new plist to the loop array:

```bash
  for plist in com.felixkratz.sketchybar.plist \
               com.felixkratz.borders.plist \
               com.koekeishiya.skhd.plist; do
```

- [ ] **Step 4: Add the Layer 2 symlink block**

Locate the Layer 1 symlink block (from Layer 1 Task 12, just after `link jankyborders/bordersrc  .config/borders/bordersrc`). Append immediately after (still in Step 3 "symlink configs" region):

```bash

# ── Desktop Layer 2 configs (Hammerspoon + skhd) ────────────────────
link hammerspoon/init.lua  .hammerspoon/init.lua
link skhd/.skhdrc          .config/skhd/skhdrc

# Karabiner JSON — dormant by default. Only symlinked when the user
# has opted into the Appendix-B upgrade path by exporting
# DESKTOP_LAYER2_USE_KARABINER=true.
if [[ "${DESKTOP_LAYER2_USE_KARABINER:-false}" == "true" ]]; then
  link karabiner/complex_modifications/desktop-layer2.json \
       .config/karabiner/assets/complex_modifications/desktop-layer2.json
  log "Karabiner complex modification linked (DESKTOP_LAYER2_USE_KARABINER=true)"
fi
```

- [ ] **Step 5: Extend the Next-steps heredoc**

The Layer 1 plan already added step 7 with sub-items (a)–(e):
- (a) Launch AeroSpace
- (b) Accessibility grants (already lists AeroSpace, skhd, Hammerspoon, Raycast)
- (c) Hide native menu bar via `_HIHideMenuBar`
- (d) Monitor-name capture via `aerospace list-monitors`
- (e) `Walk docs/manual-smoke/desktop-layer1.md`

Layer 2 inserts two new sub-items AFTER (d) (before the Walk line), renaming the Walk line from (e) to (g):

- Locate the current `e) Walk docs/manual-smoke/desktop-layer1.md at your cadence.` (verify with `grep -n "Walk docs/manual-smoke" install-macos.sh`).
- Replace that line with the (e)/(f)/(g) block below:

```
     e) In Hammerspoon prefs (menu-bar icon → Preferences), toggle
          "Launch Hammerspoon at login" → enabled
        Then Reload Config (menu-bar icon → Reload Config).
        Caps-Lock-tap should emit Escape; Caps-Lock-hold + key should
        emit Hyper+key.
     f) (Karabiner upgrade path — Appendix B) If IT adds pqrs.org team
        ID G43BCU2T37 to the MDM System Extensions allow-list, run:
          DESKTOP_LAYER2_USE_KARABINER=true bash install-macos.sh
        or, for an already-installed machine:
          bash scripts/desktop-layer2-switch-to-karabiner.sh
     g) Walk docs/manual-smoke/desktop-layer{1,2}.md at your cadence.
```

(The `{1,2}` glob form in (g) is shell-expandable: the user literally runs `ls docs/manual-smoke/desktop-layer{1,2}.md` to list both checklists. Layer 3 will extend this further.)

- [ ] **Step 6: Shellcheck install-macos.sh**

Run: `shellcheck install-macos.sh`
Expected: silent.

- [ ] **Step 7: Run tests — AC-14, 15, 17 pass**

- [ ] **Step 8: Commit**

```bash
git add install-macos.sh scripts/test-plan-desktop-layer2.sh
git commit -m "feat(install-macos): link Hammerspoon + skhd, bootstrap skhd agent (desktop layer 2)"
```

---

## Task 7: Create `scripts/desktop-layer2-switch-to-karabiner.sh` (AC-16)

**Files:**
- Create: `scripts/desktop-layer2-switch-to-karabiner.sh`
- Modify: `scripts/test-plan-desktop-layer2.sh`

- [ ] **Step 1: Append AC-16 block**

```bash
# ── AC-16: desktop-layer2-switch-to-karabiner.sh is shellcheck-clean ─
echo ""
echo "AC-16: desktop-layer2-switch-to-karabiner.sh structure"
script=scripts/desktop-layer2-switch-to-karabiner.sh
check "script exists and is executable" test -x "$script"
if command -v shellcheck &>/dev/null; then
  if shellcheck "$script" >/dev/null 2>&1; then
    ok "shellcheck $script"
  else
    nok "shellcheck $script"
  fi
else
  skp "shellcheck $script" "shellcheck not available"
fi
body="$(sed 's/#.*//' "$script")"
if printf '%s' "$body" | grep -q 'killall Hammerspoon'; then
  ok "script stops Hammerspoon"
else
  nok "script stops Hammerspoon"
fi
if printf '%s' "$body" | grep -qE 'rm -f[[:space:]]+"\$HOME/\.hammerspoon/init\.lua"'; then
  ok "script removes Hammerspoon symlink"
else
  nok "script removes Hammerspoon symlink"
fi
if printf '%s' "$body" | grep -q 'DESKTOP_LAYER2_USE_KARABINER=true'; then
  ok "script invokes install-macos.sh with DESKTOP_LAYER2_USE_KARABINER=true"
else
  nok "script invokes install-macos.sh with DESKTOP_LAYER2_USE_KARABINER=true"
fi
```

- [ ] **Step 2: Run tests — AC-16 fails**

- [ ] **Step 3: Create `scripts/desktop-layer2-switch-to-karabiner.sh`**

```bash
#!/usr/bin/env bash
# desktop-layer2-switch-to-karabiner.sh — switch Layer 2 from Hammerspoon
# to Karabiner-Elements (Appendix B upgrade path).
#
# Preconditions:
#   1. IT has added pqrs.org team ID G43BCU2T37 to the MDM System
#      Extensions allow-list. Verify with:
#          systemextensionsctl list
#   2. Karabiner-Elements cask is available to brew (if not, run
#      `brew install --cask karabiner-elements` first).
#
# What this script does:
#   1. Stops Hammerspoon.
#   2. Removes the ~/.hammerspoon/init.lua symlink.
#   3. Re-runs install-macos.sh with DESKTOP_LAYER2_USE_KARABINER=true
#      so the Karabiner JSON gets symlinked.
#   4. Prints a reminder to enable the rule in Karabiner prefs + grant
#      Accessibility to Karabiner-Elements.app.
#
# Usage: bash scripts/desktop-layer2-switch-to-karabiner.sh

set -uo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
DOTFILES="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"

echo "==> stopping Hammerspoon"
killall Hammerspoon 2>/dev/null || true

echo "==> removing Hammerspoon init symlink"
rm -f "$HOME/.hammerspoon/init.lua"

echo "==> re-running install-macos.sh with DESKTOP_LAYER2_USE_KARABINER=true"
DESKTOP_LAYER2_USE_KARABINER=true bash "$DOTFILES/install-macos.sh"

cat <<'EOF'

─────────────────────────────────────────────────────────────
Manual steps to complete the switch:

  1. Open Karabiner-Elements.app (install via Homebrew if missing:
     brew install --cask karabiner-elements).
  2. Grant Accessibility permission when prompted (JIT admin window).
  3. Prefs → Complex Modifications → Add rule → select
     "Desktop Layer 2 — Caps Lock → Escape on tap / Hyper on hold".
  4. Prefs → Simple Modifications → delete any stale Caps Lock rule
     from Hammerspoon's prior session (belt-and-braces).
  5. Test: Caps-tap should emit Escape; Caps-hold + letter should
     emit Hyper+letter (same behaviour as Hammerspoon default).
  6. (Optional) Disable "Launch Hammerspoon at login" in Hammerspoon
     prefs to avoid duplicate keyboard handlers.

Walk docs/manual-smoke/desktop-layer2.md under "Karabiner upgrade path".
─────────────────────────────────────────────────────────────
EOF
```

Then: `chmod +x scripts/desktop-layer2-switch-to-karabiner.sh`

- [ ] **Step 4: Shellcheck**

Run: `shellcheck scripts/desktop-layer2-switch-to-karabiner.sh`
Expected: silent.

- [ ] **Step 5: Run tests — AC-16 passes**

- [ ] **Step 6: Commit**

```bash
git add scripts/desktop-layer2-switch-to-karabiner.sh scripts/test-plan-desktop-layer2.sh
git commit -m "feat(desktop-layer2): add switch-to-karabiner helper script (Appendix B)"
```

---

## Task 8: Add Layer 2 desktop smoke-checks to `scripts/verify.sh`

**Files:**
- Modify: `scripts/verify.sh`

No new AC — verify.sh is a complementary runtime tool.

- [ ] **Step 1: Locate the Desktop Layer 1 block**

Run: `grep -n "Desktop Layer 1:" scripts/verify.sh`
Expected: a match inside the macOS-only block.

- [ ] **Step 2: Append the Desktop Layer 2 block immediately after Layer 1**

Inside the same `if [[ "$PLATFORM" == "macos" ]]; then` block, append:

```bash
  echo ""
  echo "Desktop Layer 2:"
  # shellcheck disable=SC2016
  check "hammerspoon init symlink resolves" \
    bash -c 'test -L "$HOME/.hammerspoon/init.lua" && test -e "$HOME/.hammerspoon/init.lua"'
  # shellcheck disable=SC2016
  check "skhdrc symlink resolves" \
    bash -c 'test -L "$HOME/.config/skhd/skhdrc" && test -e "$HOME/.config/skhd/skhdrc"'
  check "skhd LaunchAgent loaded" \
    bash -c "launchctl print gui/\$(id -u)/com.koekeishiya.skhd"
```

- [ ] **Step 3: Shellcheck**

Run: `shellcheck scripts/verify.sh`
Expected: silent.

- [ ] **Step 4: Commit**

```bash
git add scripts/verify.sh
git commit -m "feat(verify): add Desktop Layer 2 smoke checks (macOS only)"
```

---

## Task 9: Create `docs/manual-smoke/desktop-layer2.md` (AC-18)

**Files:**
- Create: `docs/manual-smoke/desktop-layer2.md`
- Modify: `scripts/test-plan-desktop-layer2.sh`

- [ ] **Step 1: Append AC-18 block**

```bash
# ── AC-18: manual-smoke/desktop-layer2.md populated ──────────────────
echo ""
echo "AC-18: manual-smoke/desktop-layer2.md populated"
check "file exists" test -f docs/manual-smoke/desktop-layer2.md
check "has 'When to run' section" \
  grep -qE '^## When to run' docs/manual-smoke/desktop-layer2.md
check "has 'Checklist' section" \
  grep -qE '^## Checklist' docs/manual-smoke/desktop-layer2.md
check "has 'Failure modes' section" \
  grep -qE '^## Failure modes' docs/manual-smoke/desktop-layer2.md
checklist_items=$(awk '/^## Checklist/,/^## Failure modes/' docs/manual-smoke/desktop-layer2.md \
                  | grep -cE '^- \[ \]')
failure_items=$(awk '/^## Failure modes/,0' docs/manual-smoke/desktop-layer2.md \
               | grep -cE '^- \[ \]')
if (( checklist_items >= 12 )); then
  ok "checklist has ≥ 12 items ($checklist_items)"
else
  nok "checklist has ≥ 12 items ($checklist_items)"
fi
if (( failure_items >= 3 )); then
  ok "failure modes has ≥ 3 drill items ($failure_items)"
else
  nok "failure modes has ≥ 3 drill items ($failure_items)"
fi
```

- [ ] **Step 2: Run tests — AC-18 fails**

- [ ] **Step 3: Create `docs/manual-smoke/desktop-layer2.md`**

```markdown
# Manual smoke — Desktop Layer 2 (Hammerspoon + skhd)

Track runtime behaviour that CI cannot observe. Tick each box as you
confirm it.

## When to run

- First install on a new machine.
- After every `install-macos.sh` re-run that modifies Layer 2 files.
- After every version bump of Hammerspoon or skhd.
- After any System Settings → Privacy change (in case TCC drops a grant).

## Checklist

### Caps Lock behaviour
- [ ] Caps-tap (press and release within ~200 ms) emits Escape
      (verify in kitty: `vim` → `i` → type → Caps → exits insert).
- [ ] Caps-hold for ≥ 300 ms and release without another key: no action.
- [ ] Caps-hold + any letter: emits Hyper+letter (observable in skhd
      logs: `log stream --predicate 'process == "skhd"'`).

### 11 Hyper bindings fire
- [ ] Hyper+E → Microsoft Edge focused or launched.
- [ ] Hyper+O → Microsoft Outlook focused or launched.
- [ ] Hyper+T → Microsoft Teams focused or launched.
- [ ] Hyper+K → kitty focused or launched.
- [ ] Hyper+N → fresh `nvim` in a new kitty window.
- [ ] Hyper+W → Microsoft Word focused or launched.
- [ ] Hyper+X → Microsoft Excel focused or launched (collision exception).
- [ ] Hyper+P → Microsoft PowerPoint focused or launched.
- [ ] Hyper+F → Finder focused or launched.
- [ ] Hyper+Space → Raycast opens (Layer 3) or fallback behaviour noted.
- [ ] Hyper+R → `aerospace reload-config` runs; bar item changes surface
      within ~2 s if the TOML was edited.

### Integration
- [ ] Hammerspoon's menu-bar icon is visible and green (not flashing red).
- [ ] "Reload Config" in the Hammerspoon menu-bar icon does not crash.
- [ ] skhd's LaunchAgent is loaded: `launchctl print
      gui/$(id -u)/com.koekeishiya.skhd` prints non-zero output.

### Karabiner upgrade path (only if switched)
- [ ] After `scripts/desktop-layer2-switch-to-karabiner.sh`,
      `~/.config/karabiner/assets/complex_modifications/desktop-layer2.json`
      is a symlink to the repo file.
- [ ] Karabiner-Elements.app shows the rule as Enabled under Complex
      Modifications.
- [ ] Hammerspoon is NOT running (or its rule is disabled) — no double-
      handling of Caps Lock.

## Failure modes

### Hammerspoon console error
- [ ] Inject a syntax error into `~/.hammerspoon/init.lua` (e.g.
      remove a `)`) and Reload Config. Hammerspoon surfaces the error
      via `hs.alert.show` and/or the console; Caps Lock reverts to
      native behaviour. The daemon does NOT crash (pcall guard).

### skhd respawn
- [ ] `killall skhd`. Within ~10 s (ThrottleInterval), the LaunchAgent
      restarts skhd. Hyper bindings resume firing.

### Accessibility revocation
- [ ] System Settings → Privacy & Security → Accessibility. Untick
      Hammerspoon. Caps Lock reverts to native behaviour. Re-tick.
      Hammerspoon must be reloaded (menu-bar icon → Reload Config).
- [ ] Repeat with skhd: untick → re-tick → LaunchAgent reload.

### CPU-load Hyper miss
- [ ] Under sustained CPU load (e.g. `yes >/dev/null &` a few times),
      rapid-fire Hyper chords may drop (~1% frequency). Documented
      behaviour (design Appendix A.1.3); Karabiner (Appendix B) is the
      upgrade path if this becomes painful.
```

- [ ] **Step 4: Run tests — AC-18 passes**

- [ ] **Step 5: Commit**

```bash
git add docs/manual-smoke/desktop-layer2.md scripts/test-plan-desktop-layer2.sh
git commit -m "docs(manual-smoke): add Desktop Layer 2 checklist"
```

---

## Task 10: Wire `test-plan-desktop-layer2.sh` into CI (AC-19)

**Files:**
- Modify: `../.github/workflows/verify.yml` (repository root)
- Modify: `scripts/test-plan-desktop-layer2.sh`

- [ ] **Step 1: Append AC-19 block**

```bash
# ── AC-19: test-plan-desktop-layer2.sh wired into CI ─────────────────
echo ""
echo "AC-19: test-plan-desktop-layer2.sh wired into verify.yml"
REPO_ROOT="$(cd "$MACOS_DEV/.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/verify.yml"
if [[ -f "$WORKFLOW" ]]; then
  hits=$(grep -c 'test-plan-desktop-layer2.sh' "$WORKFLOW" || true)
  if (( hits >= 2 )); then
    ok "verify.yml invokes test-plan-desktop-layer2.sh ($hits times)"
  else
    nok "verify.yml invokes test-plan-desktop-layer2.sh ($hits times; need ≥ 2)"
  fi
else
  skp "verify.yml wiring" "workflow not found"
fi
```

- [ ] **Step 2: Run tests — AC-19 fails**

- [ ] **Step 3: Edit the CI workflow**

Open `/home/sweeand/andrewesweet/setup/.github/workflows/verify.yml`. Locate the `Desktop Layer 1 smoke tests` step added by Layer 1 in both the `lint` and `macos-verify` jobs. AFTER each occurrence, insert:

```yaml
      - name: Desktop Layer 2 smoke tests
        run: bash macos-dev/scripts/test-plan-desktop-layer2.sh
```

- [ ] **Step 4: Validate YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('/home/sweeand/andrewesweet/setup/.github/workflows/verify.yml'))"`
Expected: exit 0.

- [ ] **Step 5: Run tests — AC-19 passes**

- [ ] **Step 6: Commit (cross-directory)**

```bash
git -C "$(cd .. && pwd)" add .github/workflows/verify.yml
git add scripts/test-plan-desktop-layer2.sh
git commit -m "ci(verify): wire test-plan-desktop-layer2.sh into lint + macos-verify"
```

---

## Task 11: Final AC-20 wrapper + full-repo gates

**Files:** (none modified — this task is validation only)

- [ ] **Step 1: AC-20 structural check**

AC-20 is the final `(( fail == 0 ))` gate — no additional block needed. Run:

```bash
bash scripts/test-plan-desktop-layer2.sh
```

Expected: all 20 ACs pass (skp on Linux for `skhd --parse` and `plutil -lint`), exit 0.

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

Expected: no "FAIL:" lines (including `test-plan-desktop-layer1.sh` from Layer 1).

- [ ] **Step 4: YAML lint**

```bash
python3 -c "import yaml; yaml.safe_load(open('/home/sweeand/andrewesweet/setup/.github/workflows/verify.yml'))"
```

Expected: exit 0.

- [ ] **Step 5: Sanity-check luac parse on Lua-equipped hosts**

```bash
if command -v luac &>/dev/null; then
  luac -p hammerspoon/init.lua && echo OK
fi
```

Expected: "OK" on hosts with Lua installed (skipped silently otherwise).

---

## Execution notes

- Rebase this worktree on the latest `main` before starting. Predictable conflicts: `Brewfile` (new sections stack), `install-macos.sh` (Layer 1's LaunchAgent loop + Layer 1's symlink block both get extended), `tools.txt`, `.github/workflows/verify.yml` (Layer 1's CI steps now have a sibling). Resolve by keeping both layers' entries in order.
- Judgement-heavy tasks: Task 2 (`init.lua` eventtap + pcall guard), Task 4 (Karabiner JSON schema — Karabiner's complex-modifications format has implicit semantics around `to` vs `to_if_alone`), Task 6 (extending the LaunchAgent loop without breaking Layer 1's iteration). Dispatch a review subagent for these.
- Tasks 1, 3, 5, 7, 8, 9, 10 are mechanical — verify inline.
- The Karabiner JSON has NO runtime test on macOS in this plan (driver-extension loading requires MDM change + reboot). Its validity is enforced purely structurally via `jq empty` + targeted jq queries on schema fields. When the Karabiner upgrade path activates later, add a runtime item to `docs/manual-smoke/desktop-layer2.md` under the existing "Karabiner upgrade path" subsection.
- Convention #12 (pre-existing untracked files on main): use `git add <specific-files>` per task; never `git add -A`.
