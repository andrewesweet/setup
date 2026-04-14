# macOS Desktop Environment Design

**Date**: 2026-04-14
**Status**: Approved — design complete, ready for implementation planning
**Successor to**: Appendix C of `2026-04-12-shell-modernisation-design.md`

---

## 1. Goals & non-goals

### 1.1 Goals

1. Deliver a macOS-only, keyboard-centric desktop that complements the shipped
   shell stack (tmux, nvim, starship, atuin, television, ghq) by replacing the
   three remaining mouse-mediated surfaces: window management, status/menu bar,
   and application launcher.
2. Ship reproducibly via the existing dotfile mechanism — `Brewfile` +
   `install-macos.sh` + symlinked configs — with zero regression to any shipped
   Layer 1 config and zero touch to `install-wsl.sh`.
3. Keep the cognitive surface small: four numbered workspaces with semantic
   labels, a single status bar on one monitor, disjoint keybinding namespaces
   (AeroSpace on Alt, skhd on Hyper, shell stack untouched).
4. Operate on a **managed corporate Mac** end-to-end: no standing admin
   required, Accessibility grants batched into a single JIT-admin window, no
   third-party kernel/driver extensions in the default path.
5. Honour the Dracula Pro palette across SketchyBar and JankyBorders as the
   only cross-dependency with the shell layer, strictly data-only (hex values
   from §3.9 of the parent design).

### 1.2 Non-goals

1. No WSL/Linux equivalent. `install-wsl.sh` remains untouched; `tools.txt`
   acquires no new formula rows for desktop-only apps.
2. No regression of, or dependency change to, any Layer 1a/1b/1c shipped
   config. Dracula palette values are *referenced*, not mutated.
3. No dext-requiring tool in the default installation (Karabiner-Elements is
   deferred to an opt-in Appendix).
4. No replacement of macOS Focus Modes, Control Center, Dock-as-launcher, or
   Mission Control — the design composes with them, not against them.
5. No automation of Accessibility grants, `/etc/hosts` writes, or any other
   sudo-gated operation. These are documented as manual JIT-admin steps in
   `install-macos.sh` "Next steps" output.
6. No media/music/meeting-calendar widgets in v1's SketchyBar — deferred to a
   follow-on cycle that would require Microsoft Graph auth infrastructure.

### 1.3 Principles carried forward from parent design

- **Bash is never broken.** No desktop tool may require a shell-stack change as
  a hard dependency.
- **Atuin owns Ctrl-R, Television owns Ctrl-T, ghq owns Alt-R.** No desktop
  binding collides.
- **Every config is a committed dotfile.** No tool is "configured in its GUI
  and trusted to sync" — settings that can be expressed as files are expressed
  as files.
- **CI green gates every merge.** The four-job CI (lint, macos-verify,
  macos-install, wsl-install) remains authoritative.

---

## 2. Architecture

### 2.1 Three-layer composition

```
┌──────────────────────────── Layer 3 · Launcher ────────────────────────────┐
│   Raycast   (replaces Spotlight on Cmd-Space)                              │
└────────────────────────────────────────────────────────────────────────────┘
                                  ▲    standalone; no IPC with Layer 1 or 2
                                  │
┌──────────────────────────── Layer 2 · Keyboard ────────────────────────────┐
│   Caps Lock remap   ──────►  skhd   (Hyper+<letter> → shell commands)      │
│   (Hammerspoon default;                                                    │
│    Karabiner in Appendix B)                                                │
└────────────────────────────────────────────────────────────────────────────┘
                                  │    skhd may issue `aerospace ...` CLI
                                  ▼
┌──────────────────────────── Layer 1 · WM core ─────────────────────────────┐
│   AeroSpace  ───► exec-on-workspace-change ───► SketchyBar                 │
│   AeroSpace  ───► focus events            ───► JankyBorders                │
│                                                                            │
│   AeroSpace (cask, login item)        — TOML config, built-in keybindings  │
│   SketchyBar (formula, LaunchAgent)   — 9 items, shell-script plugins      │
│   JankyBorders (formula, LaunchAgent) — argv-configured, Dracula Purple    │
└────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Dependency DAG

```
AeroSpace ─┬─► SketchyBar
           └─► JankyBorders

Hammerspoon (or Karabiner) ─► skhd ─► (optionally) AeroSpace CLI

Raycast (no dependencies; can install first, last, or concurrently)
```

Each layer is strictly additive: Layer 1 ships a usable (if keyboard-spartan)
tiling desktop using AeroSpace's native `Alt+*` bindings. Layer 2 layers Hyper
on top. Layer 3 replaces Spotlight. Any layer can be bypassed without breaking
others — e.g. Layer 2 disabled leaves `Alt+*` window operations fully
functional.

### 2.3 Runtime topology

`/Applications` is assumed MDM-locked; all casks install to `~/Applications/`
via `HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"`. Homebrew prefix is
`$HOME/homebrew`.

| Component | Process form | Starts how | Lives where |
|---|---|---|---|
| AeroSpace | cask, login item | Self-registers on first launch | `~/Applications/AeroSpace.app` |
| SketchyBar | formula, LaunchAgent | `launchctl bootstrap` at install time | `~/homebrew/bin/sketchybar` |
| JankyBorders | formula, LaunchAgent | `launchctl bootstrap` | `~/homebrew/bin/borders` |
| skhd | formula, LaunchAgent | `launchctl bootstrap` (via `skhd --install-service` template) | `~/homebrew/bin/skhd` |
| Hammerspoon | cask, login item | Hammerspoon prefs → "Launch on login" | `~/Applications/Hammerspoon.app` |
| Raycast | cask, login item | Raycast prefs → "Start at login" | `~/Applications/Raycast.app` |

All LaunchAgent plists follow the **podman-machine precedent** committed in
the parent design (`container/io.podman.machine.plist` +
sed-substituted wrapper + `launchctl bootstrap/bootout`). No new
plist-management pattern is introduced.

### 2.4 Inter-tool communication

- **AeroSpace → SketchyBar**: one-way event. `aerospace.toml` sets
  `exec-on-workspace-change = ['/bin/bash', '-c', '<sketchybar>  --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE']`.
  SketchyBar's `workspaces` item subscribes to the custom event and repaints.
- **AeroSpace → JankyBorders**: no direct IPC. JankyBorders consumes macOS
  SkyLight focus events natively; AeroSpace's tile-swap triggers those events
  organically.
- **skhd → AeroSpace**: optional, CLI-based. Bindings like
  `shift + alt - return : aerospace exec-and-forget open -na kitty` call
  AeroSpace's command surface without shared state.
- **Everything else**: no IPC. Raycast, Hammerspoon, and the shell layer all
  live in disjoint address spaces.

### 2.5 Dock-topology handling

Single `aerospace.toml` with a `[workspace-to-monitor-force-assignment]` table
whose values are ordered priority lists mixing office and home monitor names.
AeroSpace iterates each list in order; the first attached monitor matched
wins. No runtime dock-detection daemon; AeroSpace re-resolves the assignment
on display connect/disconnect natively.

Display names are captured at install time via `aerospace list-monitors` run
once at each location and substituted into the TOML via a documented
Next-steps step (§5.1).

### 2.6 File-system layout

```
macos-dev/
├── aerospace/
│   └── aerospace.toml                  # → ~/.config/aerospace/
├── sketchybar/
│   ├── sketchybarrc                    # → ~/.config/sketchybar/
│   ├── colors.sh                       # Dracula palette source of truth
│   ├── icons.sh                        # Nerd Font glyph constants
│   └── plugins/
│       ├── workspaces.sh
│       ├── focused_app.sh
│       ├── zscaler.sh
│       ├── focus_mode.sh
│       ├── wifi.sh
│       ├── volume.sh
│       ├── battery.sh
│       └── clock.sh
├── jankyborders/
│   └── bordersrc                       # → ~/.config/borders/
├── hammerspoon/
│   └── init.lua                        # → ~/.hammerspoon/
├── skhd/
│   └── .skhdrc                         # → ~/.config/skhd/
├── karabiner/                          # deferred Appendix B; ships but dormant
│   └── complex_modifications/
│       └── desktop-layer2.json
├── raycast/
│   └── extensions.md                   # human checklist; no symlink
├── launchagents/
│   ├── com.felixkratz.sketchybar.plist
│   ├── com.felixkratz.borders.plist
│   └── com.koekeishiya.skhd.plist
└── docs/
    └── manual-smoke/
        ├── desktop-layer1.md
        ├── desktop-layer2.md
        └── desktop-layer3.md
```

LaunchAgent plists live under `launchagents/` rather than inside per-tool
directories — keeps the `install-macos.sh` sed-substitute-and-bootstrap loop
grep-able in one spot, mirrors how `container/io.podman.machine.plist` is
structured.

---

## 3. Tool-by-tool configuration

### 3.1 AeroSpace — tiling WM (Layer 1)

- **Install**: `cask "nikitabobko/tap/aerospace"` (tap declared in `Brewfile`).
- **Config**: `aerospace/aerospace.toml` → `~/.config/aerospace/aerospace.toml`.
- **Core settings**:
  - `start-at-login = true`.
  - `default-root-container-layout = 'tiles'`.
  - `default-root-container-orientation = 'auto'`.
  - `accordion-padding = 30`.
  - `gaps = { inner = { horizontal = 8, vertical = 8 }, outer = { left = 8, bottom = 8, top = 36, right = 8 } }`
    (top gap reserves space for the 30 px SketchyBar plus 6 px breathing room).
- **Keybindings** (`[mode.main.binding]`):
  - `alt-1..alt-4` → `workspace 1..4`.
  - `alt-shift-1..alt-shift-4` → `move-node-to-workspace 1..4`.
  - `alt-h/j/k/l` → `focus left/down/up/right`.
  - `alt-shift-h/j/k/l` → `move left/down/up/right`.
  - `alt-slash` → `layout tiles horizontal vertical`.
  - `alt-comma` → `layout accordion horizontal vertical`.
  - `alt-f` → `fullscreen`.
  - `alt-shift-space` → `layout floating tiling`.
- **Workspace event dispatch**:
  ```toml
  exec-on-workspace-change = [
    '/bin/bash', '-c',
    "$HOME/homebrew/bin/sketchybar --trigger aerospace_workspace_change \
     FOCUSED_WORKSPACE=\"$AEROSPACE_FOCUSED_WORKSPACE\""
  ]
  ```
- **App-to-workspace pinning** (`[[on-window-detected]]`):
  - kitty → workspace 1.
  - MS Edge → workspace 2.
  - MS Teams (new) → workspace 3.
  - MS Outlook → workspace 3.
  - (VS Code, Word, Excel, PowerPoint: intentionally NOT pinned. They land on
    the current workspace — natural "scratch" behaviour.)
- **Monitor force-assignment**:
  ```toml
  [workspace-to-monitor-force-assignment]
  # ws 1 · term   — office: large central external; home: centre external
  1 = ['<office-central-monitor-name>', '<home-centre-monitor-name>']

  # ws 2 · edge   — office: central external (behind term); home: laptop
  2 = ['<office-central-monitor-name>', 'built-in']

  # ws 3 · comms  — office: laptop; home: left external
  3 = ['<home-left-monitor-name>', 'built-in']

  # ws 4 · scratch — no assignment; follows focused monitor
  ```
  Placeholders substituted at install time; see §5.1.
- **Theming**: none. TOML has no colour settings.
- **Gotchas**: pre-1.0 breaking changes expected; pin minimum version in
  `Brewfile` comment at implementation time. `aerospace reload-config` exposed
  via `Hyper + r` (see §3.5).

### 3.2 SketchyBar — status bar (Layer 1)

- **Install**: `brew "sketchybar"` via `tap "FelixKratz/formulae"`.
- **Config root**: `sketchybar/sketchybarrc` →
  `~/.config/sketchybar/sketchybarrc`.
- **Companion files**:
  - `sketchybar/colors.sh` — Dracula Pro palette as shell exports
    (`COLOR_BG=0xff282A36`, `COLOR_PURPLE=0xffBD93F9`, etc.). Sourced by
    `sketchybarrc` and every plugin. **Single source of truth** for every
    Dracula colour used across Layer 1.
  - `sketchybar/icons.sh` — Nerd Font glyph constants (`ICON_WIFI="󰖩"`,
    `ICON_BATTERY_FULL=""`, etc.). Sourced the same way.
- **Bar settings**:
  ```
  height=30 color=$COLOR_BG position=top padding_left=8 padding_right=8
  corner_radius=9 y_offset=4 margin=8 blur_radius=0
  font="JetBrainsMono Nerd Font:Regular:12.0"
  topmost=window display=<primary-external-name>
  ```
  `display=<name>` pins the bar to the primary external monitor — same
  placeholder-substitution pattern as AeroSpace.
- **Nine items** (left-to-right, right justified where appropriate):
  1. `workspaces` — 4 pills, subscribes to `aerospace_workspace_change`.
  2. `focused_app` — subscribes to `front_app_switched`.
  3. `zscaler` — `pgrep -qx ZscalerTunnel`, 10-second polling.
  4. `focus_mode` — reads `~/Library/DoNotDisturb/DB/Assertions.json`.
  5. `wifi` — SSID or disconnect glyph, 30-second polling.
  6. `volume` — subscribes to `volume_change`.
  7. `battery` — percent + charge state, 120-second polling.
  8. `clock` — date + time, 30-second polling.
- **Native-menubar hiding**: `defaults write -g _HIHideMenuBar -bool true`
  added to `install-macos.sh`'s macOS-defaults block, gated by
  `[[ -n "$DESKTOP_LAYER_INSTALLED" ]]` so Layer-1-shell-only users aren't
  affected.
- **Gotchas**:
  - GPL-3.0 license. Noted in Appendix C.
  - `--trigger` events are fire-and-forget; delivery is best-effort. The
    `workspaces` item has `update_freq=5` as a fallback repaint so a missed
    AeroSpace trigger self-corrects within 5 seconds.

### 3.3 JankyBorders — focus indicator (Layer 1)

- **Install**: `brew "FelixKratz/formulae/borders"`.
- **Config**: `jankyborders/bordersrc` → `~/.config/borders/bordersrc`.
- **Contents**:
  ```sh
  #!/usr/bin/env sh
  # shellcheck shell=sh
  . "$HOME/.config/sketchybar/colors.sh"    # shared palette
  exec borders \
    active_color="$COLOR_PURPLE" \
    inactive_color="$COLOR_CURRENT_LINE" \
    width=4.0 \
    hidpi=on \
    style=round
  ```
  Dracula Purple `#BD93F9` for active focus, Current-Line Grey `#44475A` for
  inactive. Rounded corners complement SketchyBar's `corner_radius=9`.
- **LaunchAgent**: `launchagents/com.felixkratz.borders.plist` runs
  `@HOMEBREW_PREFIX@/bin/borders` with
  `WorkingDirectory = $HOME/.config/borders` so the daemon reads `bordersrc`.
- **Gotchas**: Sonoma 14.0+ only. Occasionally mis-renders on displays entering
  sleep; `launchctl kickstart -k gui/$(id -u)/com.felixkratz.borders` resets.

### 3.4 Hammerspoon — Caps→Hyper source (Layer 2 default)

- **Install**: `cask "hammerspoon"` → `~/Applications/Hammerspoon.app`.
- **Config**: `hammerspoon/init.lua` → `~/.hammerspoon/init.lua`.
- **Purpose**: one job — Caps Lock tap → Escape, hold → Hyper
  (Cmd+Ctrl+Opt+Shift applied to next keypress). Nothing else in v1.
- **Implementation**:
  - Uses `hs.eventtap.new({hs.eventtap.event.types.keyDown, .keyUp})` with
    keycode 57 (Caps Lock).
  - `THRESHOLD_MS = 200` constant for tap-vs-hold distinction.
  - On tap: emit Escape via `hs.eventtap.keyStroke({}, "escape", 0)`.
  - On hold: set a flag so the next keyDown is emitted with the four-modifier
    chord; reset on keyUp.
  - Main event loop wrapped in `pcall()` so a Lua runtime error surfaces in
    Hammerspoon's console without crashing the daemon.
- **Login Item**: Hammerspoon's own "Launch Hammerspoon at login" preference,
  toggled once post-install (documented in smoke-test).
- **Gotchas**:
  - eventtap needs Accessibility.
  - Slight latency vs Karabiner (~5 ms typical; humanly imperceptible).
  - Rapid-fire Hyper chords can miss the hold threshold — mitigated by the
    200 ms tuning, documented as known behaviour in Appendix A.

### 3.5 skhd — Hyper key consumer (Layer 2)

- **Install**: `brew "koekeishiya/formulae/skhd"` via
  `tap "koekeishiya/formulae"`.
- **Config**: `skhd/.skhdrc` → `~/.config/skhd/skhdrc`.
- **Binding scheme**: Hyper (`cmd + alt + ctrl + shift`) + single letter.
  **First-letter-of-app** rule applied uniformly; collisions resolved via
  documented exceptions.

  ```skhd
  # App launch / focus — first-letter rule, Office suite on sibling keys
  cmd + alt + ctrl + shift - e : open -a "Microsoft Edge"
  cmd + alt + ctrl + shift - o : open -a "Microsoft Outlook"
  cmd + alt + ctrl + shift - t : open -a "Microsoft Teams"
  cmd + alt + ctrl + shift - k : open -a kitty                     # focus existing; launch if none
  cmd + alt + ctrl + shift - n : open -na kitty --args nvim        # always fresh nvim session
  cmd + alt + ctrl + shift - w : open -a "Microsoft Word"
  cmd + alt + ctrl + shift - x : open -a "Microsoft Excel"         # x exception: Edge owns e
  cmd + alt + ctrl + shift - p : open -a "Microsoft PowerPoint"
  cmd + alt + ctrl + shift - f : open -a Finder

  # Utility
  cmd + alt + ctrl + shift - space : open -a Raycast               # fallback if Cmd-Space blocked
  cmd + alt + ctrl + shift - r     : @HOMEBREW_PREFIX@/bin/aerospace reload-config
  ```

  **Collision convention** (design-doc rule for future additions): Hyper +
  first-letter-of-app. When a collision occurs (e.g. Edge claims `e` so Excel
  cannot), resolve in order of preference:
  1. Reassign the *new* binding to a brand-letter equivalent (Excel → `x`
     because Microsoft's iconography uses the X glyph).
  2. Otherwise use `Hyper + shift + <letter>` for the secondary app.
  3. Never reassign an existing binding without updating the manual-smoke
     checklist in the same commit.

- **LaunchAgent**: `launchagents/com.koekeishiya.skhd.plist` — same
  sed-substitute-and-bootstrap pattern as the Podman plist.
- **Gotchas**: skhd requires Accessibility. `skhd --parse <file>` gives
  pre-run validation and is used by the Layer 2 test-plan script.

### 3.6 Raycast — launcher (Layer 3)

- **Install**: `cask "raycast"` → `~/Applications/Raycast.app`.
- **Repo-committed files**: `raycast/extensions.md` — two-section document
  combining a summary description and a post-install checklist with a
  Recommended Extensions subsection. No symlinks, no settings export.
- **`raycast/extensions.md` structure**:
  ```markdown
  # Raycast — Layer 3 launcher

  ## Summary

  Raycast replaces macOS Spotlight on Cmd-Space. Installed by Layer 3
  of the macOS desktop environment plan cycle. No repo-committed
  settings (binary preferences + OAuth tokens not in source control);
  this file documents the first-run setup and curated extension list
  so any machine replicates the intended state.

  ## Post-install checklist

  Run once per fresh machine (tick each step):

  - [ ] Launch Raycast from `~/Applications/Raycast.app`
  - [ ] When prompted, grant Accessibility permission (JIT admin)
  - [ ] Prefs → General → "Start at login" → enabled
  - [ ] Prefs → General → "Launch Raycast" hotkey → `Cmd + Space`
  - [ ] Accept macOS prompt to disable Spotlight's Cmd-Space binding
  - [ ] Prefs → General → "Pop to root" → enabled
  - [ ] Prefs → Advanced → "Auto-switch input source" → disabled
        (prevents input-method fights with kitty)
  - [ ] **Do NOT sign in to a Raycast account.** Leave "Account" blank.
        Signing in enables cloud sync of extensions, hotkeys, and
        snippets to Raycast's servers. On a corporate device this is
        typically prohibited without IT approval. See §7.6 for the
        defense-in-depth blackhole that backs this up.

  ## Recommended extensions

  Install each from the Raycast Store (⌘K → "Store"):

  - [ ] **Brew** — brew formula/cask install + upgrade surface
  - [ ] **GitHub** — PRs, issues, repos without leaving Cmd-Space
  - [ ] **Kill Process** — pgrep + kill from the launcher
  - [ ] **System** — screen lock, restart, sleep, empty trash
  - [ ] **Clipboard History** — Cmd-Shift-V
  - [ ] **Color Picker** — Dracula palette eyedropper for SketchyBar
  - [ ] **Visual Studio Code** — open recent projects
  ```
- **Gotchas**: Cmd-Space takeover sometimes requires a second app-restart to
  settle. `Hyper + space` is the documented fallback.

### 3.7 Karabiner-Elements — deferred Appendix B (not in v1 default)

- Committed under `karabiner/complex_modifications/desktop-layer2.json` but
  **dormant** — not symlinked by `install-macos.sh` unless
  `DESKTOP_LAYER2_USE_KARABINER=true` is exported.
- JSON content: single complex modification, Caps Lock → Escape-on-tap /
  Hyper-on-hold, semantically identical to `hammerspoon/init.lua`.
- Switching procedure captured in
  `scripts/desktop-layer2-switch-to-karabiner.sh` (flips the symlink, adds
  Karabiner login item, removes Hammerspoon login item).
- Layer 2 test-plan asserts the JSON is structurally valid (`jq empty`) even
  while dormant, so the upgrade path remains code-verifiable.

---

## 4. Layer breakdown

### 4.1 Layer 1 · WM core — `feature/desktop-layer1-wm-core`

**Tools shipped**: AeroSpace, SketchyBar, JankyBorders.

**File-touch surface**:
- New directories: `aerospace/`, `sketchybar/` (with `plugins/`),
  `jankyborders/`, `launchagents/`, `docs/manual-smoke/`.
- Modified: `Brewfile` (three new sections + taps), `install-macos.sh`
  (cask-appdir env var, new link stanzas, new LaunchAgent bootstrap loop
  entries, Next-steps additions), `scripts/verify.sh` (macOS-gated presence
  checks), `tools.txt` (three macOS-only formulae rows).
- New: `scripts/test-plan-desktop-layer1.sh`,
  `docs/manual-smoke/desktop-layer1.md`.

**Acceptance-criteria sketch** (16–20 ACs expected):

| ID | AC |
|---|---|
| 1 | `Brewfile` declares `tap "nikitabobko/tap"` and `cask "nikitabobko/tap/aerospace"` |
| 2 | `Brewfile` declares `tap "FelixKratz/formulae"`, `brew "sketchybar"`, `brew "FelixKratz/formulae/borders"` |
| 3 | `install-macos.sh` sets `HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"` and `mkdir -p "$HOME/Applications"` before `brew bundle` |
| 4 | `aerospace/aerospace.toml` exists and parses as valid TOML |
| 5 | `aerospace.toml` contains `[mode.main.binding]` with `alt-1..alt-4`, `alt-shift-1..alt-shift-4`, `alt-h/j/k/l`, `alt-shift-h/j/k/l`, `alt-f`, `alt-slash`, `alt-comma`, `alt-shift-space` |
| 6 | `aerospace.toml` has `[[on-window-detected]]` blocks for kitty, MS Edge, MS Teams, MS Outlook |
| 7 | `aerospace.toml` has `[workspace-to-monitor-force-assignment]` with priority lists for ws 1, 2, 3 containing placeholder markers |
| 8 | `aerospace.toml`'s `exec-on-workspace-change` uses the `@HOMEBREW_PREFIX@` marker |
| 9 | `sketchybar/colors.sh` exports all Dracula hex values, minimum 12 colour constants |
| 10 | `sketchybar/icons.sh` exports at least 9 Nerd Font glyph constants |
| 11 | `sketchybar/sketchybarrc` sources `colors.sh` and `icons.sh` and calls `sketchybar --bar height=30 color=$COLOR_BG position=top ...` |
| 12 | `sketchybar/plugins/*.sh` are all shellcheck-clean under default severity |
| 13 | `sketchybar/plugins/zscaler.sh` uses `pgrep -qx ZscalerTunnel` as the primary liveness check |
| 14 | `sketchybar/plugins/focus_mode.sh` reads `~/Library/DoNotDisturb/DB/Assertions.json` with `jq -e` guard |
| 15 | `jankyborders/bordersrc` sources `$HOME/.config/sketchybar/colors.sh` and invokes `borders` with Dracula colour vars |
| 16 | `launchagents/com.felixkratz.sketchybar.plist` and `com.felixkratz.borders.plist` are `plutil -lint` clean and use the `@HOMEBREW_PREFIX@` marker |
| 17 | `install-macos.sh` links `aerospace.toml`, `sketchybarrc`, `colors.sh`, `icons.sh`, `plugins/*`, `bordersrc` to the correct `~/.config/*` paths |
| 18 | `install-macos.sh` substitutes `@HOMEBREW_PREFIX@` in the new plists and calls `launchctl bootstrap` following the Podman precedent |
| 19 | `install-macos.sh` "Next steps" output mentions the AeroSpace Accessibility grant, the JIT-admin batching sequence, and the `aerospace list-monitors` monitor-name capture step at each dock location |
| 20 | `docs/manual-smoke/desktop-layer1.md` exists with a populated checklist covering bar rendering, workspace switching, monitor pinning (office + home), 9 items, focus indicator, and failure-mode drills |

### 4.2 Layer 2 · Keyboard foundation — `feature/desktop-layer2-keyboard`

**Tools shipped**: Hammerspoon (default) + skhd. Karabiner config present but
dormant.

**File-touch surface**:
- New directories: `hammerspoon/`, `skhd/`, `karabiner/complex_modifications/`.
- Modified: `Brewfile` (Hammerspoon cask, skhd tap + formula),
  `install-macos.sh` (Hammerspoon path detection, skhd LaunchAgent via
  plist template, symlink `init.lua`, conditionally symlink Karabiner JSON),
  `tools.txt` (skhd formula row).
- New: `scripts/test-plan-desktop-layer2.sh`,
  `scripts/desktop-layer2-switch-to-karabiner.sh`,
  `docs/manual-smoke/desktop-layer2.md`.

**Acceptance-criteria sketch** (12–16 ACs expected):

| ID | AC |
|---|---|
| 1 | `Brewfile` declares `cask "hammerspoon"`, `tap "koekeishiya/formulae"`, `brew "koekeishiya/formulae/skhd"` |
| 2 | `hammerspoon/init.lua` parses cleanly via `luac -p` |
| 3 | `init.lua` contains an `hs.eventtap.new` registration handling keycode 57 (Caps Lock) |
| 4 | `init.lua` has a documented 200 ms tap-vs-hold threshold constant |
| 5 | `init.lua` emits keystrokes with the four-modifier flags `{cmd=true, alt=true, ctrl=true, shift=true}` on hold |
| 6 | `skhd/.skhdrc` parses cleanly via `skhd --parse skhd/.skhdrc` |
| 7 | `.skhdrc` contains the 11 Hyper bindings (e/o/t/k/n/w/x/p/f + space + r) |
| 8 | `.skhdrc`'s `aerospace reload-config` binding uses the `@HOMEBREW_PREFIX@` marker |
| 9 | `karabiner/complex_modifications/desktop-layer2.json` is valid JSON (`jq empty`) |
| 10 | `karabiner/.../desktop-layer2.json` has the same Caps Lock → Escape/Hyper semantics as `init.lua` (manual correspondence note in both files) |
| 11 | `launchagents/com.koekeishiya.skhd.plist` is `plutil -lint` clean |
| 12 | `install-macos.sh` links `init.lua` → `~/.hammerspoon/init.lua` and `.skhdrc` → `~/.config/skhd/skhdrc` by default; does NOT link Karabiner JSON |
| 13 | `install-macos.sh` links Karabiner JSON only when `DESKTOP_LAYER2_USE_KARABINER=true` is exported (guard documented in the script's comment block) |
| 14 | `scripts/desktop-layer2-switch-to-karabiner.sh` exists, is shellcheck-clean, and flips the symlink + Hammerspoon login item |
| 15 | `install-macos.sh` Next-steps mentions Hammerspoon "Launch at login" toggle + Accessibility grants for skhd and Hammerspoon |
| 16 | `docs/manual-smoke/desktop-layer2.md` exists with populated checklist covering Caps-tap emits Escape; Caps-hold + letter emits Hyper-letter; all 11 Hyper bindings launch/focus correctly |

### 4.3 Layer 3 · Launcher — `feature/desktop-layer3-launcher`

**Tools shipped**: Raycast.

**File-touch surface**:
- New directory: `raycast/`.
- Modified: `Brewfile` (one cask line), `install-macos.sh` (Next-steps
  additions, optional `/etc/hosts` blackhole documentation).
- New: `raycast/extensions.md`, `scripts/test-plan-desktop-layer3.sh`,
  `docs/manual-smoke/desktop-layer3.md`.

**Acceptance-criteria sketch** (6–8 ACs expected):

| ID | AC |
|---|---|
| 1 | `Brewfile` declares `cask "raycast"` |
| 2 | `raycast/extensions.md` exists with the two-section format: Summary description + Post-install checklist (with Recommended Extensions subsection) |
| 3 | `raycast/extensions.md` checklist includes the 8 documented steps (launch, Accessibility grant, Start at login, Cmd-Space binding, disable Spotlight, Pop to root, Auto-switch input source disabled, explicit sign-in forbidden) |
| 4 | `raycast/extensions.md` Recommended Extensions includes the 7 curated items (Brew, GitHub, Kill Process, System, Clipboard History, Color Picker, VS Code) |
| 5 | `install-macos.sh` Next-steps references `raycast/extensions.md` by path |
| 6 | `install-macos.sh` Next-steps includes the optional-but-recommended `/etc/hosts` blackhole commands for Raycast sync endpoints (`backend.raycast.com`, `api.raycast.com`, `sync.raycast.com`) |
| 7 | `docs/manual-smoke/desktop-layer3.md` exists with populated checklist covering Raycast launches on Cmd-Space, old Spotlight binding inactive, at least one recommended extension installed and functional |

### 4.4 Effort distribution

| Layer | AC count | Plan length (estimate) | Subagent dispatches |
|---|---|---|---|
| 1 | 16–20 | 500–700 lines | 4–6 implementer tasks + 2 reviews |
| 2 | 12–16 | 350–500 lines | 3–4 tasks + 1 review |
| 3 | 6–8 | 150–250 lines | 1–2 tasks (mostly mechanical) |

### 4.5 Per-layer independence

- Layer 1 can land and be useful without Layers 2 or 3. User keeps Spotlight
  and uses AeroSpace's native `Alt+*` bindings.
- Layer 2 can land without Layer 3 (skhd's `Hyper + space` covers launcher
  need until Raycast lands).
- Layer 3 can land before Layer 2 (Raycast is orthogonal). The ordering
  1 → 2 → 3 is chosen because Layer 1 delivers the headline transformation.

---

## 5. Install changes

### 5.1 `install-macos.sh` modifications

Adds seven concerns, in install-time order. Each guarded for idempotency.

**Near the top (global concern)**:

```bash
# Desktop casks install to ~/Applications/ because /Applications is MDM-locked.
# Benign on non-managed Macs too (user-local is a valid Homebrew target).
mkdir -p "$HOME/Applications"
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"
```

Placed just before the existing `brew bundle` invocation. Applies to all
casks — future layers inherit it without new code.

**After `brew bundle` succeeds (per layer)**:

- Layer 1 symlink block: six new `link` calls for `aerospace.toml`,
  `sketchybarrc`, `colors.sh`, `icons.sh`, `plugins` (directory),
  `bordersrc`. Uses the existing `link()` helper (symlink +
  backup-on-clobber + idempotent re-link).
- Layer 2 symlink block: `hammerspoon/init.lua` → `~/.hammerspoon/init.lua`;
  `skhd/.skhdrc` → `~/.config/skhd/skhdrc`. Conditional Karabiner link under
  `${DESKTOP_LAYER2_USE_KARABINER:-false}`.
- Layer 3 symlink block: none — Raycast's settings are GUI-managed; comment
  notes where `raycast/extensions.md` lives.

**LaunchAgent block (extends existing Podman-machine block)**:

```bash
# --- Desktop LaunchAgents (macOS only) ---
if [[ "$(uname)" == "Darwin" ]]; then
  for plist in com.felixkratz.sketchybar.plist \
               com.felixkratz.borders.plist \
               com.koekeishiya.skhd.plist; do
    plist_src="$DOTFILES/launchagents/$plist"
    plist_dst="$HOME/Library/LaunchAgents/$plist"
    sed "s|@HOMEBREW_PREFIX@|$HOMEBREW_PREFIX|g; s|@HOME@|$HOME|g" \
      "$plist_src" > "$plist_dst"
    launchctl bootout "gui/$(id -u)/${plist%.plist}" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$plist_dst"
    printf "  linked    %s\n" "$plist_dst"
  done
  log "Desktop LaunchAgents loaded"
fi
```

**Next-steps output** — appended to existing `Next steps:` heredoc:

```
  7. Desktop layer first-run (macOS only):
     a) Launch AeroSpace from ~/Applications/AeroSpace.app
     b) Request JIT admin. Within the elevation window, grant
        Accessibility to ALL of the following in a single pass:
          - AeroSpace             (~/Applications/AeroSpace.app)
          - skhd                  (~/homebrew/bin/skhd)
          - Hammerspoon           (~/Applications/Hammerspoon.app)
          - Raycast               (~/Applications/Raycast.app)
     c) In Hammerspoon prefs, toggle "Launch Hammerspoon at login"
     d) In Raycast prefs, set Cmd-Space + "Start at login"
     e) Follow the post-install checklist at raycast/extensions.md
     f) At each dock location (office + home), run:
          aerospace list-monitors
        Substitute the display names into the placeholders in
        ~/.config/aerospace/aerospace.toml under
        [workspace-to-monitor-force-assignment], then:
          aerospace reload-config
     g) Walk docs/manual-smoke/desktop-layer*.md at your cadence
     h) (Corporate Mac only, optional hardening) Within the same JIT
        admin window, append Raycast sync endpoints to /etc/hosts:
          sudo tee -a /etc/hosts >/dev/null <<EOF
          0.0.0.0  backend.raycast.com
          0.0.0.0  api.raycast.com
          0.0.0.0  sync.raycast.com
          EOF

  Corporate-Mac note (Karabiner upgrade path):
     If IT adds pqrs.org team ID G43BCU2T37 to the MDM System-Extensions
     allow-list, run:
       DESKTOP_LAYER2_USE_KARABINER=true ./install-macos.sh
     to switch from Hammerspoon to Karabiner-Elements.
```

### 5.2 `Brewfile` changes

New sections added in desktop-layer order:

```ruby
# ── Desktop · window manager (Layer 1 desktop) ────────────────────────
tap "nikitabobko/tap"
cask "nikitabobko/tap/aerospace"

# ── Desktop · status bar & focus indicator (Layer 1 desktop) ──────────
tap "FelixKratz/formulae"
brew "sketchybar"
brew "FelixKratz/formulae/borders"

# ── Desktop · keyboard (Layer 2 desktop) ──────────────────────────────
cask "hammerspoon"
tap "koekeishiya/formulae"
brew "koekeishiya/formulae/skhd"
# Karabiner-Elements cask is deferred — see karabiner/README.md

# ── Desktop · launcher (Layer 3 desktop) ──────────────────────────────
cask "raycast"
```

Taps precede their `cask`/`brew` consumers as `brew bundle` requires.

### 5.3 `tools.txt` changes

Only formulae get entries; casks are Brewfile-only. Three new rows under a
new section:

```
# ── Desktop (macOS-only formulae) ─────────────────────────────────────
sketchybar           brew:sketchybar                             apt:-  apk:-
borders              brew:FelixKratz/formulae/borders            apt:-  apk:-
skhd                 brew:koekeishiya/formulae/skhd              apt:-  apk:-
```

WSL install is unaffected.

### 5.4 `scripts/check-tool-manifest.sh`

Audited at implementation time. If the script doesn't already skip
`cask "..."` and `tap "..."` lines when validating formula-to-tools.txt
correspondence, a three-line guard is added in the first layer that
introduces a cask (Layer 1).

### 5.5 `scripts/verify.sh`

Three new smoke-level checks, gated on macOS:

```bash
if [[ "$(uname)" == "Darwin" ]]; then
  # Layer 1 desktop
  [[ -r "$HOME/.config/aerospace/aerospace.toml" ]] && ok "aerospace config"
  launchctl print "gui/$(id -u)/com.felixkratz.sketchybar" &>/dev/null \
    && ok "sketchybar LaunchAgent loaded"
  launchctl print "gui/$(id -u)/com.felixkratz.borders" &>/dev/null \
    && ok "borders LaunchAgent loaded"

  # Layer 2 desktop
  [[ -r "$HOME/.hammerspoon/init.lua" ]] && ok "hammerspoon init symlinked"
  launchctl print "gui/$(id -u)/com.koekeishiya.skhd" &>/dev/null \
    && ok "skhd LaunchAgent loaded"

  # Layer 3 desktop
  [[ -d "$HOME/Applications/Raycast.app" ]] && ok "raycast installed"
fi
```

### 5.6 `scripts/test-plan-desktop-layer{1,2,3}.sh`

One per layer. Preamble copied byte-for-byte from
`scripts/test-plan-layer1a.sh` lines 12–55 (convention 1). Each AC in §4
becomes one labelled check. Final line `(( fail == 0 ))`.

Conventions reaffirmed:
- Function-body-scoped greps use
  `awk '/^fn\(\) \{/,/^\}/' file.sh | sed 's/#.*//' | grep -q PATTERN`
  (convention 2).
- Structural multiline greps use `grep -Pzo` — NOT `-PzoE`
  (convention 3).
- Pipelines with `awk | sed | grep -q` materialise to a variable first to
  avoid SIGPIPE flakes under `set -o pipefail` (convention 4).
- Dynamic checks use `printf '%s' "$out" | grep`, NOT
  `bash -c "echo '$out' | grep"` (convention 5).
- Shellcheck disables are per-statement (convention 6).

### 5.7 `docs/manual-smoke/desktop-layer{1,2,3}.md`

Three new files. Structure:

```markdown
# Manual smoke — Desktop Layer <N>

## When to run
- First dock at office (laptop + central external)
- First dock at home (laptop + centre + left externals)
- After every install-macos.sh re-run that touches Layer <N> files
- After every formula/cask version bump for this layer's tools

## Checklist
- [ ] …

## Failure modes to drill
- [ ] …
```

See Appendix A for the Layer 1 checklist body.

### 5.8 Rollback & uninstall

Rollback documented as a runbook; not scripted for v1 (see §8.1, deferred
item 7):

```bash
# Unload LaunchAgents
for la in com.felixkratz.sketchybar com.felixkratz.borders com.koekeishiya.skhd; do
  launchctl bootout "gui/$(id -u)/$la" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/$la.plist"
done
# Remove apps
rm -rf "$HOME/Applications/"{AeroSpace,Hammerspoon,Raycast}.app
# Uninstall formulae
brew uninstall sketchybar borders skhd
# Restore pre-desktop symlinks
./install-macos.sh --restore
```

---

## 6. Testing strategy

### 6.1 What runs where

```
┌──────────────── CI (on every push to main) ────────────────┐
│                                                            │
│   lint (all platforms)                                     │
│     └── shellcheck: all *.sh including desktop plugins     │
│                                                            │
│   macos-verify (macOS runner)                              │
│     └── bash scripts/test-plan-desktop-layer1.sh           │
│     └── bash scripts/test-plan-desktop-layer2.sh           │
│     └── bash scripts/test-plan-desktop-layer3.sh           │
│     └── (all existing test-plan-layer*.sh keep running)    │
│                                                            │
│   macos-install (macOS runner)                             │
│     └── brew bundle check                                  │
│     └── install-macos.sh round-trip                        │
│                                                            │
│   wsl-install (Linux runner)                               │
│     └── install-wsl.sh (untouched; no desktop effect)      │
│                                                            │
└────────────────────────────────────────────────────────────┘

┌──────────── User-discretion (not CI-gated) ────────────┐
│                                                        │
│   docs/manual-smoke/desktop-layer{1,2,3}.md            │
│     Ticked at user's cadence.                          │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### 6.2 Static assertion patterns

Inherited verbatim from shipped Layer-1 test-plans:

```bash
# -- TOML validity --
label "AC-04 aerospace.toml parses as valid TOML"
python3 -c "import tomllib, sys; tomllib.load(open(sys.argv[1], 'rb'))" \
  "$DOTFILES/aerospace/aerospace.toml" && pass || fail

# -- JSON validity --
label "AC-09 karabiner complex_modifications JSON parses"
jq empty "$DOTFILES/karabiner/complex_modifications/desktop-layer2.json" \
  && pass || fail

# -- plist validity --
label "AC-16 sketchybar LaunchAgent plist passes plutil -lint"
plutil -lint "$DOTFILES/launchagents/com.felixkratz.sketchybar.plist" \
  &>/dev/null && pass || fail

# -- Content assertion (function-body-scoped, SIGPIPE-safe) --
label "AC-13 zscaler.sh uses pgrep -qx ZscalerTunnel"
content="$(awk '/^check\(\) \{/,/^\}/' \
  "$DOTFILES/sketchybar/plugins/zscaler.sh" | sed 's/#.*//')"
grep -q 'pgrep -qx ZscalerTunnel' <<< "$content" && pass || fail
```

### 6.3 Runtime validators

Gated on macOS, degrading to `skip` on Linux:

```bash
label "AC-06 skhd config parses via skhd --parse"
if [[ "$(uname)" == "Darwin" ]] && command -v skhd &>/dev/null; then
  skhd --parse "$DOTFILES/skhd/.skhdrc" &>/dev/null && pass || fail
else
  skip "skhd not installed"
fi

label "AC-02 hammerspoon init.lua parses via luac -p"
if command -v luac &>/dev/null; then
  luac -p "$DOTFILES/hammerspoon/init.lua" &>/dev/null && pass || fail
else
  skip "luac not installed"
fi

label "AC-04 aerospace config parses"
if [[ "$(uname)" == "Darwin" ]] && command -v aerospace &>/dev/null \
   && aerospace --help 2>&1 | grep -q -- '--check-config'; then
  aerospace --check-config "$DOTFILES/aerospace/aerospace.toml" \
    &>/dev/null && pass || fail
else
  # Fallback: TOML-level validity (weaker but non-zero).
  python3 -c "import tomllib, sys; tomllib.load(open(sys.argv[1], 'rb'))" \
    "$DOTFILES/aerospace/aerospace.toml" && pass || fail
fi
```

### 6.4 `skip()` helper semantics

The shipped test-plans have `pass` / `fail` helpers; a new `skip()` helper:

```bash
skip() {
    printf "  %b⊘ SKIP%b  %s — %s\n" "${DIM}" "${RESET}" "$label" "$1"
    ((skipped++))
}
```

Skipped checks count separately from pass/fail. Final gate is
`(( fail == 0 ))` — skipped checks don't block CI.

### 6.5 Invariant assertions (unchanged from shipped)

- `test-plan-layer2.sh` asserts `.bashrc` has exactly 14 sections. Desktop
  layers do NOT modify `.bashrc`; invariant unchanged.
- `test-plan-layer6-8.sh` asserts `starship.toml` has exactly 11 sections.
  Desktop layers do NOT modify starship; invariant unchanged.

### 6.6 Explicit exclusions

No CI job *runs* AeroSpace, SketchyBar, skhd, Hammerspoon, or Raycast.
No GUI app launching, no LaunchAgent bootstrap verification beyond
best-effort, no monitor assignment testing, no Karabiner dext loading.
Runtime behaviour is the user's smoke-test job.

### 6.7 Test-plan size estimate

| File | Size | Checks |
|---|---|---|
| `scripts/test-plan-desktop-layer1.sh` | ~550 lines | 16–20 |
| `scripts/test-plan-desktop-layer2.sh` | ~400 lines | 12–16 |
| `scripts/test-plan-desktop-layer3.sh` | ~180 lines | 6–8 |

---

## 7. Security & corporate-Mac considerations

### 7.1 Permission inventory

| Tool | Accessibility | Driver Ext. | Admin install | Admin runtime |
|---|---|---|---|---|
| AeroSpace | **required** | — | avoided via `~/Applications` | no |
| SketchyBar | — | — | no | no |
| JankyBorders | — | — | no | no |
| skhd | **required** | — | no | no |
| Hammerspoon | **required** | — | avoided via `~/Applications` | no |
| Raycast | **required** | — | avoided via `~/Applications` | no |
| Karabiner (deferred) | **required** | **required** + MDM allow-list | **yes** + reboot | no |

Four Accessibility grants total in the default (Hammerspoon) path.

### 7.2 JIT-admin grant sequence

Documented in `install-macos.sh` Next-steps:

```
Request JIT admin once; within the 20-minute elevation window:

  1. Open System Settings → Privacy & Security → Accessibility.
  2. Click + and add, in this order:
       a. ~/Applications/AeroSpace.app
       b. ~/homebrew/bin/skhd
       c. ~/Applications/Hammerspoon.app
       d. ~/Applications/Raycast.app
  3. Toggle each to on.
  4. (Optional hardening) Append Raycast sync endpoints to /etc/hosts.
  5. (If Raycast Cmd-Space takeover requires it) Re-visit System Settings.
  6. Close System Settings.
```

If elevation expires mid-sequence, remaining grants block until the next
JIT window. No automation available — Apple's TCC framework resists
programmatic grants by design.

### 7.3 MDM interaction surface

1. **System Extensions allow-list** — observed: Microsoft, Zscaler, Google
   (all security-category). Karabiner (team ID `G43BCU2T37`, HID-category)
   is not on the list; deferred behind Appendix B.
2. **`/Applications` writability** — assumed locked; design uses
   `HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"` unconditionally.
3. **TCC profile** — MDM may push a pre-authorised Accessibility profile.
   If so, §7.2's grant sequence becomes no-op. Positive-surprise
   scenario; no accommodation required.

### 7.4 LaunchAgent attack surface

Three new LaunchAgents (`com.felixkratz.sketchybar`, `com.felixkratz.borders`,
`com.koekeishiya.skhd`). Each runs as the user — no privilege elevation,
no root, no system domain.

- Plists in `~/Library/LaunchAgents/` with user-only write. Tampered plists
  are clobbered on next `install-macos.sh` run.
- Binaries referenced via `$HOMEBREW_PREFIX/bin/<tool>` — same threat surface
  as every other homebrew binary already in the repo. No new surface
  introduced.
- `ProgramArguments` is a static array — no shell interpolation; not
  argv-injection-vulnerable.

### 7.5 Gatekeeper / quarantine

- **Formulae** (SketchyBar, JankyBorders, skhd): built from source by
  Homebrew locally. No quarantine xattr. Run cleanly.
- **Casks** (AeroSpace, Hammerspoon, Raycast): downloaded. AeroSpace is
  ad-hoc signed; Homebrew auto-removes `com.apple.quarantine` via
  `--no-quarantine` (default since 2022). Hammerspoon and Raycast are
  properly signed and notarised.

No `sudo xattr -rd com.apple.quarantine` documentation needed for the
default (Path β) installation.

### 7.6 Privacy & data-flow notes

- **Raycast cloud sync — forcibly disabled.** Enforcement via three layers:
  1. **Checklist (mandatory)**: post-install checklist explicitly forbids
     signing in. Raycast does not sign in by default.
  2. **`/etc/hosts` blackhole (recommended for corporate)**: appends
     `backend.raycast.com`, `api.raycast.com`, `sync.raycast.com` to
     `/etc/hosts` as `0.0.0.0` entries during the JIT admin window.
     Prevents sign-in attempts from ever reaching Raycast's servers.
  3. **Plist-level disable (opportunistic)**: if a user-writable preference
     key exists that disables cloud-sync semantics independent of sign-in
     state, set it via `defaults write` in `install-macos.sh`. Probed at
     Layer 3 build time; skip if no such key is observable pre-sign-in.
- **Focus Mode detection** reads `~/Library/DoNotDisturb/DB/Assertions.json`
  (Apple-internal but stable across Sonoma and Sequoia). Read-only; `jq -e`
  guard returns "hidden" on parse error.
- **Zscaler process probe**: `pgrep -qx ZscalerTunnel` — liveness check
  only, no IPC with the daemon.
- **Hammerspoon eventtap**: intercepts keyboard events system-wide under
  Accessibility. Only the repo-committed `init.lua` is loaded.

### 7.7 Supply chain

Four new brew taps:
- `nikitabobko/tap` (AeroSpace).
- `FelixKratz/formulae` (SketchyBar, JankyBorders) — shared maintainer.
- `koekeishiya/formulae` (skhd).
- (No new tap for Raycast — cask lives in homebrew-core.)

All single-maintainer OSS taps. Version pinning is not applied; breaking
changes cascade on next `brew bundle`. Accepted risk; matches the parent
design's `dracula/*` tap posture.

### 7.8 Incident-response

- **SketchyBar crash loop**:
  `launchctl bootout gui/$(id -u)/com.felixkratz.sketchybar` → fix config →
  re-bootstrap.
- **AeroSpace grabs windows unexpectedly after config reload**:
  `aerospace emit-move-nodes-to-all-monitors` or toggle off via menu-bar →
  fix TOML → `aerospace reload-config`.
- **Hammerspoon Lua error locks Caps Lock**: menu-bar icon → "Reload
  Config"; if unresponsive, `killall Hammerspoon`. Caps reverts to native
  behaviour automatically.

Documented in the per-layer manual-smoke "Failure modes" subsection.

---

## 8. Deferred decisions + adversarial review

### 8.1 Deferred decisions

| # | Item | Rationale | Successor |
|---|---|---|---|
| 1 | Outlook unread / next-meeting / Teams unread bar items | Graph API requires Azure AD + IT approval; AppleScript scrape known-fragile. | Appendix D |
| 2 | Karabiner-Elements upgrade path | MDM team-ID allow-list negotiation out of cycle scope. | Appendix B |
| 3 | Git-branch SketchyBar item | Starship prompt already shows it. | Revisit if manual smoke reveals a need |
| 4 | K8s / AWS / GCP profile items beyond the current workflow | YAGNI. | Separate plan if workflow shifts |
| 5 | Raycast script commands | Shell stack already covers the use cases. | Revisit if a concrete need emerges |
| 6 | MS Teams meeting-window floating rule | Requires live observation of AX window class post-install. | Follow-up commit in Layer 1 execution |
| 7 | Scripted `install-macos.sh --uninstall-desktop` | Rollback is infrequent and case-by-case for a personal dotfile. | Revisit if multi-user install flows emerge |
| 8 | Itsycal, Maccy, AltTab, Stats, BetterDisplay, LinearMouse (top-10 research shortlist) | Out of scope per B-level ambition. | Future desktop-v2 cycle |
| 9 | Raycast cloud sync | See §7.6 — enforcement via three defense-in-depth layers; user decision inevitable. | — |
| 10 | Monitor-name auto-capture | Scriptable but premature for single-machine dotfile. | Revisit on multi-machine expansion |
| 11 | Light-mode palette | Parent design is dark-only. | Parent design concern |
| 12 | External monitor colour-profile calibration | Untunable without per-monitor calibration. | Out of scope |

### 8.2 Open questions for implementation

Not design blockers; implementer resolves deliberately:

- **AeroSpace `--check-config` flag existence** — probed at runtime by Layer 1
  test-plan with TOML-parse fallback.
- **MS Teams new-app bundle ID** — plan assumes `com.microsoft.teams2`;
  implementer verifies via
  `osascript -e 'id of app "Microsoft Teams"'` during smoke test.
- **Primary-external display-name placeholder** — captured manually per
  §5.1, item 7.f.
- **Zscaler process-name stability** — fallback grep
  `pgrep -q -f 'Zscaler' || pgrep -q -f 'zscaler'` in `zscaler.sh`.
- **Hammerspoon 200 ms tap-threshold** — `THRESHOLD_MS` constant; tunable.

### 8.3 Adversarial review — what could go wrong

See Appendix A for the full pessimist walkthrough.

Summary of highest-likelihood failure modes:

- AeroSpace ships a breaking TOML change mid-cycle (pre-1.0).
- Monitor names contain characters that break sed substitution.
- Hammerspoon's eventtap misses a Hyper chord under CPU load.
- Focus-mode `Assertions.json` format mutates in a macOS point release.
- MS Teams bundle ID changes again.
- MDM retroactively revokes Accessibility.

### 8.4 Test-for-failure scenarios

Captured in the per-layer manual-smoke checklists under "Failure modes":

- Layer 1: kill SketchyBar, verify respawn; unplug external mid-session,
  verify re-layout; kill `borders`, verify respawn.
- Layer 2: inject Lua syntax error, verify Hammerspoon console surfaces it
  without crash; kill skhd, verify LaunchAgent respawn.
- Layer 3: toggle Raycast Login Item off, verify `Hyper + space` fallback
  still opens Raycast.

---

## Appendix A — Adversarial review (expanded)

Pessimist walkthrough of failure modes, ordered by likelihood × severity.

### A.1 Likely, moderate severity

**A.1.1 AeroSpace breaking TOML change mid-cycle.** Pre-1.0 semver disclaims
backwards compatibility. Mitigation: `Brewfile` comment pins a minimum
version; implementer flags breaking changes in the layer-1 PR body; test-plan
catches schema drift via `--check-config` where available, via TOML parse
otherwise. Recovery: pin `version "0.x.y"` explicitly in `Brewfile`.

**A.1.2 Monitor names break sed substitution.** Display names like `LG HDR 4K`
are fine; names with double quotes or backticks would fail.
Mitigation: Next-steps documents "paste the name as-is between single
quotes"; `install-macos.sh` doesn't auto-substitute — user edits the TOML
directly.

**A.1.3 Hammerspoon eventtap misses Hyper chord under CPU load.** Known
behaviour; rapid-fire Hyper sequences on a loaded machine occasionally
drop. Mitigation: documented in Layer 2 smoke checklist; Path α (Karabiner)
is the fallback if the pain becomes significant.

**A.1.4 Focus-mode `Assertions.json` format changes.** Apple-internal path;
could mutate at any macOS point release. Mitigation: `focus_mode.sh` wraps
the read in `jq -e .` and degrades to "hidden" (no item rendered) on parse
error. Never crashes the bar. Expected maintenance.

**A.1.5 AeroSpace dock-transition race.** Unplugging an external while
workspace 1 is active on that external can trigger a re-layout flicker.
Mitigation: AeroSpace handles this natively. No design remediation; smoke
checklist item only.

### A.2 Less likely, moderate severity

**A.2.1 Zscaler binary rename.** `ZscalerTunnel` has been stable 3.x–4.x
but is not contract. Mitigation: `zscaler.sh` fallback on case-insensitive
substring match.

**A.2.2 MS Teams bundle-ID change.** `on-window-detected` silently stops
firing; Teams windows land wherever spawned. Mitigation: smoke-test
item; one-line TOML fix if observed.

**A.2.3 Raycast Cmd-Space takeover fails silently.** Occasionally loses to
Spotlight until manual re-toggle. Mitigation: `Hyper + space` skhd binding
is the documented fallback.

**A.2.4 JankyBorders flickers on display-sleep wake.** Known upstream issue.
Mitigation: `launchctl kickstart -k gui/$(id -u)/com.felixkratz.borders`.
Documented in Troubleshooting.

### A.3 Less likely, high severity

**A.3.1 MDM retroactively revokes Accessibility.** TCC profile push removes
granted permissions; all four tools silently fail. Mitigation: none at
design time — corporate policy supersedes. External risk.

**A.3.2 MDM disables Homebrew.** Endgame: nothing installs. External risk.

**A.3.3 Hammerspoon Lua error at boot prevents eventtap registration.** Caps
Lock stuck native; Hyper dead. Mitigation: `init.lua` wraps eventtap
registration in `pcall()`; Hammerspoon menu-bar icon stays responsive for
Reload-Config. Smoke-test item.

**A.3.4 Accessibility grant applies to stale bundle path.** If macOS indexed
a prior `/Applications/AeroSpace.app` before the `~/Applications/` install,
the grant may apply to the wrong path. Mitigation: Next-steps explicitly
specifies the `~/Applications/` path; smoke test verifies focus.

### A.4 Unlikely, high severity

**A.4.1 Supply-chain compromise of a tap.** All three new taps are
single-maintainer. SketchyBar and JankyBorders share a maintainer
(FelixKratz) — a compromise there would hit two of three formulae.
Mitigation: none specific; matches parent `dracula/*` tap posture.

**A.4.2 Dracula palette drift.** Parent design revises hex values;
`sketchybar/colors.sh` becomes stale silently. Mitigation: Layer 1
test-plan cross-references colour values against a baseline list; drift
fails CI.

**A.4.3 LaunchAgent bootstrap races during live install.** Daemon
crash-loops; logs grow unchecked. Mitigation: §7.8 incident response;
`launchctl bootout` kill switch.

### A.5 Explicitly not considered

- Physical theft of the machine.
- Kernel-level compromise (no default-path dext in this design).
- Accidental commit of secrets in `~/.config/sketchybar/` — no secrets
  are stored there by design; Outlook/Teams/Graph deferred to v2.

---

## Appendix B — Path α: Karabiner upgrade

### B.1 When this applies

The user has successfully requested that IT add pqrs.org team ID
`G43BCU2T37` to the MDM System Extensions allow-list, and verified via
`systemextensionsctl list` that the driver-extension category accepts
HID-category dexts.

### B.2 IT-ticket template

```
Subject: MDM System Extensions allow-list — add pqrs.org (G43BCU2T37)

Requesting addition of team ID G43BCU2T37 (pqrs.org) to MDM-allowed
System Extensions. Karabiner-Elements is a widely used open-source
keyboard remapper that enables productivity keybindings. Its driver
extension is a userland HID driver; it does not access network, storage,
or other endpoint-security-relevant surfaces.

Homepage:   https://karabiner-elements.pqrs.org/
Source:     https://github.com/pqrs-org/Karabiner-Elements
License:    MIT / Public Domain
Signer:     Developer ID Application: Fumiaki Ishii (G43BCU2T37)
```

### B.3 Switching procedure

Run after IT confirms the profile update:

```bash
DESKTOP_LAYER2_USE_KARABINER=true ./install-macos.sh
# or, if the other layers are already installed:
./scripts/desktop-layer2-switch-to-karabiner.sh
```

The script:
1. Stops Hammerspoon (`killall Hammerspoon`; removes login item).
2. Unlinks `~/.hammerspoon/init.lua`.
3. Installs Karabiner-Elements cask if not already present.
4. Links `karabiner/complex_modifications/desktop-layer2.json` to
   `~/.config/karabiner/assets/complex_modifications/`.
5. Opens Karabiner prefs for the user to enable the rule.
6. Prints a reminder to grant Accessibility (fresh app).

### B.4 Post-switch verification

- Caps-tap emits Escape.
- Caps-hold + letter emits Hyper-letter.
- `hs.eventtap` no longer consuming key events (kill -0 Hammerspoon fails).
- All 11 Hyper bindings from §3.5 fire correctly.

---

## Appendix C — Dracula Pro palette reference

The canonical palette lives in §3.9 of
`2026-04-12-shell-modernisation-design.md`. This appendix mirrors the
hex values consumed by desktop-layer tooling and documents the
cross-layer contract.

### C.1 Palette values consumed

```
Background:    #282A36   (COLOR_BG)        — SketchyBar bar.color
Current Line:  #44475A   (COLOR_CURRENT)   — JankyBorders inactive_color
Selection:     #44475A   (COLOR_SELECTION)
Foreground:    #F8F8F2   (COLOR_FG)        — SketchyBar label.color
Comment:       #6272A4   (COLOR_COMMENT)   — muted-state text
Red:           #FF5555   (COLOR_RED)       — Zscaler disconnect
Orange:        #FFB86C   (COLOR_ORANGE)
Yellow:        #F1FA8C   (COLOR_YELLOW)    — battery low
Green:         #50FA7B   (COLOR_GREEN)     — Zscaler connected
Cyan:          #8BE9FD   (COLOR_CYAN)      — wifi connected
Purple:        #BD93F9   (COLOR_PURPLE)    — JankyBorders active_color; Focus-mode active
Pink:          #FF79C6   (COLOR_PINK)
```

### C.2 Cross-layer contract

- `sketchybar/colors.sh` is the single source of truth.
- `jankyborders/bordersrc` sources `sketchybar/colors.sh` — no duplicate
  hex values on disk.
- Layer 1 test-plan asserts each hex value present in `colors.sh` matches
  the parent design's §3.9. Drift fails CI.

### C.3 Delta table

Reserved for future revisions of the parent design. Empty as of v1.

---

## Appendix D — Deferred: Outlook / Teams awareness

### D.1 Scope

SketchyBar items deferred from v1:
- Outlook unread email count.
- Outlook next meeting (title + relative time).
- Teams unread notifications count.

### D.2 Implementation paths compared

| Path | Pros | Cons |
|---|---|---|
| **Microsoft Graph API** | Clean, documented, future-proof. Supports fine-grained scopes. | Requires Azure AD app registration in the user's tenant. OAuth2 + refresh flow in shell scripts. Corporate tenant-admin approval typically required. |
| **AppleScript dock-badge scrape** | Zero infra; works today against legacy Outlook. | Fragile; broken by the "new" Outlook/Teams React rewrites. Requires both Accessibility and Automation permissions. |

### D.3 Estimated AC count for a v2 cycle

- Graph path: ~15–20 ACs across a new Layer 4 (auth infra, token storage,
  refresh daemon, three bar items). Significant work.
- AppleScript path: ~6–8 ACs (three plugins + Automation grant + smoke
  checklist). Low work; high re-break risk.

### D.4 Starter Graph scopes

If pursuing the Graph path: `Mail.Read`, `Calendars.Read`,
`ChannelMessage.Read.All`, `Chat.Read`. Confirm with IT that these are
acceptable scopes for dev-machine OAuth apps in the tenant.

---

## Appendix E — Corporate-Mac considerations (summary)

Consolidates §7.1–§7.3 for readers needing only the MDM/sudo summary.

### E.1 Sudo surface

- **Zero standing admin required** for Layers 1, 2, 3 install + runtime.
- **One JIT admin window** batches four Accessibility grants + optional
  `/etc/hosts` blackhole + optional Spotlight re-toggle.
- **Karabiner (Appendix B)** requires additional admin + MDM team-ID
  allow-list; out of default path.

### E.2 `/Applications` lockdown workaround

Global env var in `install-macos.sh`:

```bash
mkdir -p "$HOME/Applications"
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"
```

Applied before every `brew bundle`; benign on non-managed Macs.

### E.3 dext policy probe

```bash
systemextensionsctl list
```

Look for `driver_extension` subtype HID with a non-Apple team ID. If
present → Path α feasible. Observed on this user's Mac: only
security-category dexts (Microsoft, Zscaler, Google) → Path β default.

### E.4 Accessibility grant persistence

TCC stores grants keyed by bundle-ID **and** path. Moving an app between
`/Applications` and `~/Applications` invalidates the grant.

---

## Appendix F — Community dotfile references

Surveyed during the research phase; referenced for structural precedent
only (no forks, no code copying):

- **mehd-io/dotfiles** — https://github.com/mehd-io/dotfiles  
  AeroSpace + SketchyBar + tmux + Neovim + Starship + Atuin. Closest match
  to this user's stack. Reference for `Brewfile`, `install.sh`,
  LaunchAgent plists, and `aerospace.toml` layout.
- **zmre/aerospace-sketchybar-nix-lua-config** —
  https://github.com/zmre/aerospace-sketchybar-nix-lua-config  
  Nix-darwin flake; reference for LaunchAgent module patterns.
- **falleco/dotfiles** — https://github.com/falleco/dotfiles  
  AeroSpace + JankyBorders + SketchyBar with brew-bundle. Clean Brewfile
  + config-directory layout.

No committed code in this repo is derived from these. They are navigation
aids for implementers.

---

*End of design. Handover: implementation planning via
`superpowers:writing-plans`, one plan per layer, in
`docs/superpowers/plans/<date>-desktop-layer<N>-<name>.md`.*
