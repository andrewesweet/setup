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
