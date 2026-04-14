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
