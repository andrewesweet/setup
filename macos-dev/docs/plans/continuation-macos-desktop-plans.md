I'm continuing a macOS desktop environment modernisation project for my
dotfiles repo. All context is in the repo at
`/home/sweeand/andrewesweet/setup/macos-dev/`.
Do not consult external sources beyond the ones linked below — the
design is settled and your job is to convert it into three
implementation plans, then execute them.

### This is the PLAN-WRITING + EXECUTION phase

Brainstorm and design are complete. The approved design doc is at
`docs/plans/2026-04-14-macos-desktop-env-design.md` (commit `779dea5`
on main, 1378 lines). Your job is NOT to re-design — your job is to:

1. Produce three implementation plans (one per desktop layer), ATDD-first.
2. Execute them sequentially, one merge cycle at a time.

### Required reading (in this order)

1. **`docs/plans/2026-04-14-macos-desktop-env-design.md`** — the
   approved desktop-environment design. Status: Approved. Read it in
   full. Every decision is captured; no implicit knowledge needed.
   Particular attention to:
   - §4 (Layer breakdown) — per-layer AC sketches (20/16/7 ACs)
   - §5 (Install changes) — concrete `install-macos.sh` diff targets
   - §6 (Testing strategy) — B+C (static + runtime + manual-smoke)
   - §7 (Security & corporate-Mac) — sudo-free default path
   - Appendix A (adversarial review) — failure modes to test for
   - Appendix B (Karabiner Path α) — dormant but committed

2. **`docs/plans/2026-04-12-shell-modernisation-design.md`** — the
   parent design. Layers 1a/1b-i/1b-ii/1b-iii/1c are all shipped and
   CI-green. You are NOT touching those. Read §3.9 (Dracula Pro
   palette) to confirm the hex values the desktop design will consume
   via `sketchybar/colors.sh`.

3. **`docs/plans/continuation-1b-ii-iii.md`** — reproduces the 12
   codified conventions from shipped-layer execution. Skim sections
   1–12. Every convention applies to desktop layers too. The most
   bite-y ones:
   - ATDD preamble copied byte-for-byte from
     `scripts/test-plan-layer1a.sh` lines 12–55.
   - Function-body-scoped greps need
     `awk '/^fn\(\) \{/,/^\}/' file.sh | sed 's/#.*//' | grep -q PATTERN`
     (the `sed 's/#.*//'` is mandatory — comments leak through without it).
   - Structural multiline greps use `grep -Pzo`, **NOT `-PzoE`**
     (P and E mutually exclusive in GNU grep).
   - SIGPIPE-safe assertions: NEVER `awk | sed | grep -q` in a script
     with `set -o pipefail`. Materialise to a variable first:
     `VAR="$(awk|sed)"; grep -q PATTERN <<< "$VAR"`. Hotfix `4b289a2`
     documents the incident.
   - Dynamic checks use `printf '%s' "$out" | grep`, NOT
     `bash -c "echo '$out' | grep"`.
   - Shellcheck is a CI gate with default severity (warnings AND info
     fail). Per-statement `# shellcheck disable=SCxxxx  # reason`
     (block-level only covers the next single statement).
   - Worktrees at `.worktrees/<branch>/` at git ROOT
     (`/home/sweeand/andrewesweet/setup/`). Root `.gitignore` has
     `.worktrees/`. Use `superpowers:using-git-worktrees`.

4. **Shipped layer plans** (reference for pattern + AC conventions):
   - `docs/superpowers/plans/2026-04-12-layer1a-atuin-television.md`
   - `docs/superpowers/plans/2026-04-13-layer1b-i-tools-aliases.md`
   - `docs/superpowers/plans/2026-04-13-layer1b-ii-tmux-theming.md`
   - `docs/superpowers/plans/2026-04-13-layer1b-iii-cable-gh.md`
   - `docs/superpowers/plans/2026-04-13-layer1c-ghq-ghorg.md`
   Read the most recent (`1b-iii`, `1c`) to lock in the plan format.

### Workflow

Workflow is:

1. **Write three implementation plans** using
   `superpowers:writing-plans`, one per layer:
   - `docs/superpowers/plans/2026-04-XX-desktop-layer1-wm-core.md`
   - `docs/superpowers/plans/2026-04-XX-desktop-layer2-keyboard.md`
   - `docs/superpowers/plans/2026-04-XX-desktop-layer3-launcher.md`
   Each plan converts the design's AC sketches (§4.1–§4.3) into
   concrete ATDD tasks. Expected AC counts: 16–20 (Layer 1),
   12–16 (Layer 2), 6–8 (Layer 3). Commit all three plans in one
   commit with a message like
   `plan(desktop): write implementation plans for layers 1–3`.

2. **Execute Layer 1** using `superpowers:subagent-driven-development`
   (or `superpowers:executing-plans` if you prefer the checkpointed
   variant). Create the worktree via `superpowers:using-git-worktrees`
   at `.worktrees/desktop-layer1-wm-core/`. Implement, verify inline
   for mechanical tasks, dispatch a review subagent for judgement-heavy
   tasks (Task 1's aerospace.toml structure, any plugin that touches
   `~/Library/` paths, the LaunchAgent bootstrap loop). Test with
   `bash scripts/test-plan-desktop-layer1.sh`, shellcheck-clean the
   whole repo, merge to main, wait for CI green (~7 min).

3. **Rebase Layer 2 on new main**, resolve small predictable conflicts
   in `Brewfile` and `install-macos.sh` (both plans extend these).
   Execute Layer 2. Merge. Wait for CI green.

4. **Rebase Layer 3 on new main.** Execute. Merge. CI green.

Sequential, not parallel — the file overlap in `Brewfile`,
`install-macos.sh`, and potentially `scripts/verify.sh` guarantees
conflicts if run concurrently. Precedent: this is how 1b-ii and
1b-iii were sequenced (see `continuation-1b-ii-iii.md` STEP 2 for
the analogous analysis).

### Locked design decisions (do NOT re-open)

These are settled in the design doc. If the implementer pushes back,
cite the design section.

- **Layer scope**: 3 layers (WM core / keyboard / launcher). Design §2.1.
- **Workspaces**: 4 numbered, labelled term/edge/comms/scratch.
  Pinning rules for kitty / MS Edge / MS Teams / MS Outlook.
  Design §3.1.
- **Keybindings**: Alt for AeroSpace, Hyper for skhd (via Caps→Hyper
  remap). 11 Hyper bindings: e/o/t/k/n/w/x/p/f/space/r. Collision
  convention in §3.5. First-letter rule; Excel→x is the documented
  exception.
- **SketchyBar items**: exactly 9 — workspaces, focused_app, zscaler,
  focus_mode, wifi, volume, battery, clock (right-to-left on the
  right side, workspaces+focused_app on the left). Design §3.2.
- **Bar layout**: top, replacing native menu bar; full bar on the
  **primary external only** (no bar on laptop/secondary); opaque
  Dracula Background; notch-style corner radius; JetBrainsMono Nerd
  Font; default 30 px height.
- **Monitor assignment**: priority-list via
  `[workspace-to-monitor-force-assignment]` with placeholders captured
  at install time via `aerospace list-monitors` at each dock location.
  Design §3.1 and §5.1 item 7.f.
- **Keyboard foundation**: Hammerspoon default (Path β). Karabiner
  config committed dormant under `karabiner/` for Appendix B upgrade.
  Design §3.4 and Appendix B.
- **Launcher**: Raycast. `raycast/extensions.md` is the only
  committed asset — two-section format (summary + post-install
  checklist with recommended-extensions subsection). Design §3.6.
- **Raycast cloud sync**: **forcibly disabled** via three layers —
  checklist mandate, optional `/etc/hosts` blackhole (during JIT
  admin), opportunistic plist probe. Design §7.6.
- **Corporate Mac assumptions**: `/Applications` MDM-locked → always
  install casks to `~/Applications/`. Homebrew prefix is
  `~/homebrew/`. `HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"`
  set before `brew bundle`. Design §5.1 and §7.3.
- **Testing**: B+C — static assertions + CI runtime validators
  (`skhd --parse`, `luac -p`, `plutil -lint`, `jq empty`,
  `aerospace --check-config` with TOML-parse fallback) + per-layer
  `docs/manual-smoke/desktop-layer<N>.md` ticked at user discretion.
  Design §6.
- **Brewfile organisation**: single `Brewfile` with new per-layer
  `# ── Desktop · ... ──` sections. `tools.txt` gets formulae-only
  rows. Design §5.2 and §5.3.
- **LaunchAgent pattern**: reuse the Podman precedent exactly —
  `launchagents/<name>.plist` with `@HOMEBREW_PREFIX@` and `@HOME@`
  sed markers, substituted at install time, `launchctl bootout ||
  true` then `launchctl bootstrap`. Design §2.3 and §5.1.
- **Accessibility grant sequence**: batched into a single JIT-admin
  window for AeroSpace, skhd, Hammerspoon, Raycast. Design §7.2.
- **File layout**: per design §2.6. Top-level dirs: `aerospace/`,
  `sketchybar/` (with `plugins/`), `jankyborders/`, `hammerspoon/`,
  `skhd/`, `karabiner/complex_modifications/`, `raycast/`,
  `launchagents/`, `docs/manual-smoke/`.
- **Dracula palette**: single source of truth at `sketchybar/colors.sh`.
  `jankyborders/bordersrc` sources it. Layer 1 test-plan asserts hex
  values match parent design §3.9. Design Appendix C.

### Deferred (do NOT implement in v1)

Captured in design §8.1. Don't reopen unless the user explicitly asks.

- Outlook/Teams unread + next-meeting SketchyBar items (Appendix D).
- Karabiner upgrade path (Appendix B — script committed, switching
  not executed).
- Git-branch, k8s-context, aws-profile SketchyBar items.
- Raycast script commands.
- Scripted `install-macos.sh --uninstall-desktop`.
- Every other tool from the research top-10 shortlist (Itsycal, Maccy,
  AltTab, Stats, BetterDisplay, LinearMouse).

### Platform realities (quick refresher — full detail in design §7)

- **Accessibility permissions** — AeroSpace, skhd, Hammerspoon,
  Raycast all require it. Manual, one-time per machine, batched into a
  single JIT-admin window. Documented in
  `install-macos.sh` Next-steps. Never automated.
- **Driver extensions** — NOT in default path. Karabiner
  (Appendix B) is the only tool that would need one.
  `systemextensionsctl list` observed: only Microsoft, Zscaler, Google
  (security-category). pqrs.org team ID `G43BCU2T37` is NOT on the
  list; IT-ticket template is in Appendix B.
- **LaunchAgents** — SketchyBar, JankyBorders, skhd. Pattern from
  `container/io.podman.machine.plist` (see `install-macos.sh` ~line
  345 in current main). Reuse; do not reinvent.
- **Homebrew cask vs brew**:
  - Cask: AeroSpace, Hammerspoon, Raycast, (Karabiner deferred).
  - Formula: SketchyBar, JankyBorders, skhd.
  - All casks land in `~/Applications/` via `HOMEBREW_CASK_OPTS`.
- **Gatekeeper**: AeroSpace is ad-hoc signed; Homebrew auto-removes
  the quarantine xattr (`--no-quarantine` default since 2022).
  Hammerspoon and Raycast are properly signed + notarised.
  **No `sudo xattr -rd com.apple.quarantine` step required** for any
  default-path tool.

### Conventions for this cycle (delta from shipped layers)

Everything in `continuation-1b-ii-iii.md` still applies. New items
specific to desktop layers:

1. **`skip()` helper** in test-plans. Skipped checks count separately
   from pass/fail; `(( fail == 0 ))` still gates. For ACs that require
   tools only available on macOS (`skhd --parse`, `plutil -lint`,
   `aerospace --check-config`), degrade to `skip` on Linux with a
   reason string. Pattern in design §6.3.
2. **Runtime validators** are the new testing surface. Probe
   availability with `command -v <tool>` before invoking. Fall back to
   static parsers when the runtime validator isn't available
   (e.g. TOML `tomllib` parse if `aerospace --check-config` is
   missing).
3. **`docs/manual-smoke/desktop-layer<N>.md`** per layer. Populated
   from the design doc (§5.7 is the template). Tick marks in the
   checklist are the user's; implementer leaves them unticked.
4. **Placeholder display names** in `aerospace.toml` and
   `sketchybarrc` — `<office-central-monitor-name>`,
   `<home-centre-monitor-name>`, `<home-left-monitor-name>`,
   `<primary-external-name>`. Committed verbatim with the
   placeholders in place; `install-macos.sh` does NOT substitute
   them. User substitutes at install time per Next-steps item 7.f.
   Test-plan must ALLOW the placeholders to remain present (don't
   assert concrete monitor strings).

### What NOT to do

- Do NOT touch `install-wsl.sh`, WSL config, or any Layer-1 shipped
  shell config (tmux/kitty/lazygit/delta/starship/atuin/ghq/etc.)
  unless you catch a regression during CI.
- Do NOT add Karabiner to the default install path. Its JSON config
  ships dormant in `karabiner/complex_modifications/`; the switching
  script lives at `scripts/desktop-layer2-switch-to-karabiner.sh`.
- Do NOT add script commands to Raycast (deferred). Do NOT commit
  Raycast's binary preferences directory.
- Do NOT add tools not listed in design §3. Itsycal, Maccy, AltTab,
  Stats, LinearMouse, MonitorControl, BetterDisplay etc. are all
  deferred to a future v2 cycle (§8.1 item 8).
- Do NOT auto-substitute monitor names in `aerospace.toml` during
  install. The placeholders stay; the user edits post-install.
- Do NOT modify the parent shell-modernisation design doc. If you find
  a Dracula palette discrepancy, fix `sketchybar/colors.sh` to match
  §3.9 — the parent is the source of truth.
- Do NOT skip the manual-smoke checklists. They're committed files
  even if CI doesn't execute them.
- Do NOT pick up `.claude/`, `docs/plans/2026-04-07-04-kitty.md`,
  `docs/plans/continuation-*.md`, or `continuation-plan5.md` — they
  are pre-existing untracked files on main. Use
  `git add <specific-files>` instead of `git add -A`
  (convention #12 in `continuation-1b-ii-iii.md`).

### First actions

1. Read the approved design doc at
   `docs/plans/2026-04-14-macos-desktop-env-design.md` in full.
   Then skim the three required-reading docs (parent design,
   continuation-1b-ii-iii, latest shipped layer plan).
2. Summarise your understanding in 3–5 sentences, confirming you see
   the three layers, the Hammerspoon-default keyboard choice, the
   corporate-Mac constraints, and the B+C testing strategy.
3. Ask whether to proceed with `superpowers:writing-plans` to produce
   all three implementation plans in one sitting, or to write them
   one-at-a-time with user review between each. Default is
   all-three-at-once — the design is prescriptive enough that
   writing-plans has clear ACs to work from for all three.
4. After plans are written and committed, ask whether to begin
   executing Layer 1 immediately or to pause for user review of the
   plans first.

Do NOT begin plan-writing before confirming the summary with the
user. Do NOT begin execution before the three plans are committed
and CI-green on main (only the plan commit runs; CI for plan docs is
essentially instant).

### Session recap (for continuity)

The macOS desktop design shipped in a single brainstorm+design
session. Scope ambition B (core + keyboard foundation) with
three-layer decomposition. Nine SketchyBar items locked
(no Outlook/Teams awareness in v1). Hammerspoon beat Karabiner as
default because user's MDM only allow-lists security-category dexts
(Microsoft/Zscaler/Google observed); pqrs.org team ID would need an
IT ticket. Raycast cloud sync forcibly disabled via checklist +
`/etc/hosts` blackhole + opportunistic plist probe. Monitor
assignment uses priority lists with placeholders captured per-dock
at install time; no auto-detection. Brewfile stays unified (per-layer
sections); casks land in `~/Applications/` via
`HOMEBREW_CASK_OPTS` because `/Applications` is MDM-locked.
Everything committed to main in commit `779dea5`.
