# JIT Admin Request — Developer Desktop Environment (macOS)

**Audience:** endpoint compute admins and security approvers reviewing a Just-In-Time (JIT) local-admin escalation for this machine.

**Ask:** one JIT admin window (~15 minutes) to complete first-run setup of a developer desktop environment installed from a version-controlled dotfiles repository. After the window closes, the machine operates permanently with standard user privileges; none of the changes below require admin for day-to-day use.

**Source of truth:** all configuration is in the committed repo at <https://github.com/andrewesweet/setup> under `macos-dev/`. Every setting described here maps to a specific file in the repo and is reviewable before approval. The relevant entry points are `macos-dev/install-macos.sh`, `macos-dev/Brewfile`, and the three desktop-layer manual-smoke checklists in `macos-dev/docs/manual-smoke/`.

---

## Summary table

| # | Operation | Scope | Why admin is needed | Persistence | Revocability |
|---|-----------|-------|---------------------|-------------|--------------|
| 1 | Grant Accessibility to 4 signed apps | Per-user TCC | Unlock Privacy pane padlock | Per-app toggle in System Settings | Untick per app, instant |
| 2 | Disable Spotlight's Cmd-Space binding | Per-user | Unlock Keyboard Shortcuts pane on some MDM profiles | `~/Library/Preferences` plist | Re-enable in System Settings, instant |
| 3 | `defaults write -g _HIHideMenuBar -bool true` | Per-user | Unlock if MDM profile locks global preferences | `~/Library/Preferences/.GlobalPreferences.plist` | `defaults delete -g _HIHideMenuBar`, instant |
| 4 | Append 3 lines to `/etc/hosts` (optional) | System-wide file, 3 lines | `sudo` required to write `/etc/hosts` | `/etc/hosts` file | `sudo sed -i '' '/raycast\.com/d' /etc/hosts`, instant |

No kernel extensions, no system extensions, no launch daemons, no MDM-profile modifications, no firmware changes, no changes to `/Applications`, no changes to `/Library`, no changes to `/System` (SIP-protected anyway).

---

## Scope guarantees (what this request does *not* cover)

- **No writes to `/Applications`.** The installer routes all Homebrew casks to `~/Applications/` via `HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"` (set before `brew bundle` runs; see `install-macos.sh`). The MDM-managed `/Applications` directory is untouched.
- **No new launch daemons.** Only LaunchAgents under `~/Library/LaunchAgents/` (per-user, user-launched, no admin). Three agents total — SketchyBar, JankyBorders, and skhd — bootstrapped via `launchctl bootstrap gui/$(id -u)`, which is a user-domain operation.
- **No kernel or system extensions.** The repo ships a dormant Karabiner-Elements JSON file under `macos-dev/karabiner/complex_modifications/` that is NOT symlinked into place by default. Activation would require a separate MDM System Extensions allow-list change (pqrs.org team ID `G43BCU2T37`) and is out of scope for this JIT request.
- **No credential storage.** Nothing in this flow reads, writes, or persists secrets, SSH keys, or OAuth tokens.
- **No automated `sudo`.** Every `sudo` operation is explicitly manual; the installer prints the command for the user to copy-paste under JIT admin.

---

## Item 1: Accessibility permission for four apps

### What changes

One line added to the per-user TCC (Transparency, Consent, and Control) database for each of four apps, toggled via *System Settings → Privacy & Security → Accessibility*:

| App | Installed at | Why it needs Accessibility |
|-----|--------------|----------------------------|
| AeroSpace | `~/Applications/AeroSpace.app` | Read window geometry and issue window-move commands (tiling WM) |
| Hammerspoon | `~/Applications/Hammerspoon.app` | Register a global event-tap for Caps Lock to Escape/Hyper remapping |
| skhd | `$(brew --prefix)/bin/skhd` | Register a global hotkey listener for Hyper+letter bindings |
| Raycast | `~/Applications/Raycast.app` | Window actions + Clipboard History capture + Cmd-Space hotkey takeover |

### Why admin is needed

On standard macOS, the Privacy pane padlock is unlocked with the logged-in user's password. On managed corporate Macs, MDM profiles commonly require an administrator account to unlock the padlock before any per-app toggle can be flipped.

### Why this is safe

- **Apps are open-source and signed by their developers.** Each app is published on GitHub with reproducible releases:
  - AeroSpace — <https://github.com/nikitabobko/AeroSpace>
  - Hammerspoon — <https://github.com/Hammerspoon/hammerspoon>
  - skhd — <https://github.com/koekeishiya/skhd>
  - Raycast — commercial, but widely deployed in enterprises; macOS-signed with notarization.
- **Accessibility is not equivalent to admin.** It grants the ability to observe and synthesize input events *for the current user's session only*. It does not grant kernel-level access, disk read/write beyond user scope, or network capability.
- **Per-app scope.** Revoking Accessibility for any single app disables that app instantly without affecting the others.
- **Auditable.** The grant is visible at any time in *System Settings → Privacy & Security → Accessibility*. MDM inventory agents can detect and report on these entries.

### Why not user-level

macOS explicitly requires admin authentication to unlock the Accessibility pane on managed profiles. This is an Apple design decision, not a choice of this repo.

### How to verify post-grant

```bash
# From Terminal after the JIT window closes
tccutil reset Accessibility      # ONLY if a reset is needed — this clears ALL grants
# Safer: just visually confirm the four checkboxes under System Settings
```

---

## Item 2: Disable Spotlight's Cmd-Space binding

### What changes

Uncheck *System Settings → Keyboard → Keyboard Shortcuts → Spotlight → "Show Spotlight search"*. This persists in `~/Library/Preferences/com.apple.symbolichotkeys.plist`.

### Why admin is needed

On some corporate MDM profiles, the Keyboard Shortcuts pane requires admin to unlock. On a standard profile this is a user-level preference and does not need elevation.

### Why this is safe

- The change is entirely within user preferences. It does not disable Spotlight itself — Spotlight still runs, still indexes files, and is still reachable via Finder's search bar, the menu-bar magnifying-glass icon, and `mdfind` from the CLI.
- The binding is transferred to Raycast (see Item 1), which provides equivalent or superior functionality for the developer's workflow.
- Reversible in one click.

### Why not user-level

Same as Item 1 — Apple's design: managed profiles can lock this pane behind admin auth.

---

## Item 3: `defaults write -g _HIHideMenuBar -bool true`

### What changes

Sets a single key in the user's `.GlobalPreferences.plist`, instructing `SystemUIServer` to hide the macOS menu bar. After `killall SystemUIServer`, the menu bar auto-hides; hovering the top of the screen reveals it temporarily, as with fullscreen apps.

### Why it's needed

The SketchyBar custom status bar shipped by this repo renders at the top of the primary external monitor; without hiding the native menu bar, both bars overlap visually. This is purely cosmetic — menus remain reachable by cursor hover.

### Why admin is needed

On profiles that lock `.GlobalPreferences.plist` via MDM, the write returns `Permission denied` without admin. On standard profiles this is a user-level plist and needs no elevation.

### Why this is safe

- Single key, single boolean, user-scope plist.
- Equivalent to toggling the native "Automatically hide and show the menu bar" switch in *System Settings → Control Center* on standard macOS.
- Fully reversible: `defaults delete -g _HIHideMenuBar && killall SystemUIServer`.

---

## Item 4: `/etc/hosts` blackhole for Raycast sync endpoints (optional)

### What changes

Three lines appended to `/etc/hosts`:

```text
0.0.0.0  backend.raycast.com
0.0.0.0  api.raycast.com
0.0.0.0  sync.raycast.com
```

### Why it's needed

This is defense-in-depth for a corporate compliance requirement: preventing Raycast's cloud-sync feature from transmitting extension configuration, hotkey definitions, or snippets to Raycast Inc.'s servers. The primary control is documented in `raycast/extensions.md` as "do not sign in"; this `/etc/hosts` edit is a belt-and-braces follow-up in case a user inadvertently signs in or a future Raycast update changes the sync trigger.

### Why admin is needed

`/etc/hosts` is a system file writable only by `root`.

### Why this is safe

- **Conservative blackhole target (`0.0.0.0`).** Resolves loopback-style failures immediately; no DNS leakage to upstream resolvers; no impact on any other name resolution.
- **Scoped to three domains.** Does not affect other Raycast functionality (local extensions, local clipboard history, command palette).
- **Reversible with a one-liner:** `sudo sed -i '' '/raycast\.com/d' /etc/hosts`
- **Optional.** If the security team prefers to rely solely on the "do not sign in" policy, this item can be skipped entirely.
- **Auditable.** `grep raycast.com /etc/hosts` returns the three lines or nothing.

### Commands the user will run under JIT

Exactly what appears in `install-macos.sh` Next-steps step 7(h):

```bash
sudo tee -a /etc/hosts >/dev/null <<EOF_HOSTS
0.0.0.0  backend.raycast.com
0.0.0.0  api.raycast.com
0.0.0.0  sync.raycast.com
EOF_HOSTS
```

No scripts with embedded `sudo`. No sudoers modification. No persistent admin credential.

---

## Threat model summary (for security approvers)

| Threat | Mitigation |
|--------|-----------|
| Persistence beyond JIT window | None of items 1–4 create persistent admin state. The JIT-admin actions themselves are one-off writes. |
| Privilege escalation | No setuid binaries, no sudoers edits, no launchd daemons (only agents under the user's own domain). |
| Data exfiltration | No credentials handled. Four apps get Accessibility scope, which is keyboard-visible but does not include network egress unless the app itself uses it — and Raycast's egress is explicitly blackholed per Item 4. |
| Supply chain | All tooling is installed via Homebrew from signed, reproducible sources. The Brewfile and its installed formulae/casks are version-pinned by Homebrew's own lockfile and tap contents; any change to the Brewfile goes through the repo's PR review pipeline (CI runs `brew bundle` end-to-end on every push). |
| Revocability | Every change is reversible in seconds by the user, with no admin required for the reversal. |
| Auditability | Every setting has a known location and a known command to read it. The repo commit log documents every change with attribution. |

## Post-JIT verification (the approver can confirm the window is truly closed)

```bash
# Run as the logged-in user after the JIT admin window closes:

# 1. No stale admin group membership
id -Gn | tr ' ' '\n' | grep -qx admin && echo "FAIL: still admin" || echo "OK: standard user"

# 2. No sudoers lingering grants
sudo -n true 2>&1 | grep -q 'password is required' && echo "OK: sudo reprompts" || echo "INSPECT"

# 3. Accessibility entries match exactly what was approved
# (visual inspection of System Settings → Privacy → Accessibility)

# 4. /etc/hosts shows only the three approved lines (if Item 4 applied)
grep raycast.com /etc/hosts
```

## Rollback (if the approver later decides to revoke)

All four items are reversible without admin:

```bash
# Item 1 — untick each app in System Settings → Privacy → Accessibility (user-level)
# Item 2 — re-tick Spotlight's Cmd-Space in System Settings → Keyboard (user-level)
# Item 3 — defaults delete -g _HIHideMenuBar && killall SystemUIServer
# Item 4 — sudo sed -i '' '/raycast\.com/d' /etc/hosts    (needs admin for this one)
```

After rollback, the four installed apps remain but stop providing their WM/keyboard/launcher functionality. Uninstallation of the apps themselves is a separate `brew uninstall --cask <name>` operation and needs no admin (they live in `~/Applications/`).

---

## Contact

Source repo: <https://github.com/andrewesweet/setup>  
Manual-smoke checklists (what the user walks after the JIT window): `macos-dev/docs/manual-smoke/desktop-layer{1,2,3}.md`  
Design document: `macos-dev/docs/plans/2026-04-14-macos-desktop-env-design.md`
