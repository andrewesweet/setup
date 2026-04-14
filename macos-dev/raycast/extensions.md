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
- [ ] **Do NOT sign in to a Raycast account** (sign-in|Account pane:
      leave blank). Signing in enables cloud sync of extensions, hotkeys,
      and snippets to Raycast's servers. On a corporate device this is
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
