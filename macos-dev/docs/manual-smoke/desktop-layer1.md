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
