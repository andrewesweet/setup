# Layer 1b-i Implementation Plan: Shell-agnostic tools + aliases

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add eight shell-agnostic CLI tools (`sesh`, `yazi`, `xh`, `rip`, `rip2`, `jqp`, `diffnav`, `carapace`) with configs, shell integration, and aliases, without touching tmux plugins, cable channels, or gh extensions (those land in 1b-ii and 1b-iii).

**Architecture:** Tools install via Brewfile (macOS) or a new `gh_release_install` helper + `apt` (WSL/Linux). Configs are tracked flat in the repo (`sesh/sesh.toml.tmpl`, `yazi/*.toml`, `jqp/.jqp.yaml`, `diffnav/config.yml`) and symlinked into XDG paths. Sesh uses install-time `sed` template substitution because its schema rejects env-var expansion. Aliases + the `y()` cd-on-quit wrapper go into `bash/.bash_aliases`. Carapace provides cross-shell completion bridging via `CARAPACE_BRIDGES`.

**Tech Stack:** bash, brew, apt, gh-release tarballs, fzf (already shipped), carapace.

**Spec reference:** `docs/plans/2026-04-12-shell-modernisation-design.md` §§ 2.5, 3.3, 3.4, 3.8, 4 (Layer 1b), 5, 6, 8.1, Appendix (Dracula palette §§ 3.9).

**Platform scope:** macOS (Apple Silicon + Intel), WSL2 (Ubuntu-based), native Linux. Tests run on macOS and WSL2 in CI.

**Prerequisites:** Layers 1a and 1c merged. 1b-ii and 1b-iii are siblings — this plan does NOT introduce TPM/plugins, cable channels, gh extensions, or gh-dash (tracked in their own plans). The alias namespace reserved by 1b-ii/1b-iii (`ghd`, `ghce`, `ghcs`, `ghp`, `ghmd`, `ghg`, `ghaw`) is NOT claimed here.

---

## Acceptance Criteria (Specification by Example)

Each bullet is a testable assertion. `scripts/test-plan-layer1b-i.sh` validates every one.

**AC-1: Brewfile declares all Layer 1b-i tools**
```
Given: the tracked Brewfile
When: grepped for each tool
Then: entries exist for sesh, yazi, xh, rip2, jqp, diffnav, carapace
And: a cesarferreira/tap tap line exists with brew "cesarferreira/tap/rip"
And: a dlvhdr/formulae tap line exists with brew "dlvhdr/formulae/diffnav"
```

**AC-2: tools.txt matches Brewfile**
```
When: bash scripts/check-tool-manifest.sh runs
Then: exit 0
```

**AC-3: sesh template file exists with substitution markers**
```
Given: sesh/sesh.toml.tmpl
When: inspected
Then: file exists
And: contains the literal marker "@DOTFILES@"
And: does NOT contain any $ENV_VAR-style expansions in [[session]] path fields
```

**AC-4: install scripts substitute the sesh template to ~/.config/sesh/sesh.toml**
```
Given: install-macos.sh / install-wsl.sh
When: grepped
Then: both contain a `sed "s|@DOTFILES@|$DOTFILES|g"` invocation
And: both write to $HOME/.config/sesh/sesh.toml
And: (full mode) generated file contains no "@DOTFILES@" markers post-install
```

**AC-5: yazi configs exist and are symlinked**
```
Given: yazi/yazi.toml, yazi/keymap.toml, yazi/theme.toml
When: inspected
Then: all three files exist in the repo
And: install-macos.sh and install-wsl.sh contain link() calls for each to .config/yazi/
```

**AC-6: `y()` cd-on-quit wrapper is defined in bash/.bash_aliases**
```
Given: bash/.bash_aliases sourced
When: `declare -F y` runs
Then: exit 0
And: the body contains `yazi` and `--cwd-file`
And: the body contains `builtin cd --` or `cd --`
```

**AC-7: jqp config sets theme = dracula**
```
Given: jqp/.jqp.yaml
When: inspected
Then: file exists
And: contains `theme: dracula`
And: install scripts link it to $HOME/.jqp.yaml
```

**AC-8: diffnav config exists and uses Dracula palette**
```
Given: diffnav/config.yml
When: inspected
Then: file exists
And: install scripts link it to $HOME/.config/diffnav/config.yml
```

**AC-9: bash/.bashrc sources carapace bridges in an opt-out-safe guard**
```
Given: bash/.bashrc
When: grepped
Then: `CARAPACE_BRIDGES` is exported (with 'zsh,fish,bash,inshellisense' as the value)
And: a `command -v carapace` guard wraps the completion source
And: the source line is inside section 9 (Completions)
```

**AC-10: new aliases exist in bash/.bash_aliases with exact definitions**
```
Given: bash/.bash_aliases
When: grepped
Then: alias http='xh'
And: alias rrip='rip2 -u'
And: alias rm-safe='rip2'
And: alias jqi='jqp'
And: alias dn='diffnav'
And: alias sx='sesh connect'
And: alias sxl='sesh list'
```

**AC-11: `cheat` function has subcommands for every new tool**
```
Given: bash/.bash_aliases cheat() body (restricted to the case arms)
When: grepped
Then: case arms exist for atuin, tv|television, sesh, yazi, xh, rip, rip2, jqp, diffnav
And: the help output lists each new subcommand
```

**AC-12: cheatsheet.md has a Tool reference row for each new tool**
```
Given: docs/cheatsheet.md
When: inspected
Then: rows for sesh/sx, yazi/y, xh/http, rip (process killer), rip2/rrip, jqp/jqi, diffnav/dn are present
And: the `cheat` discovery table lists each new tool
```

**AC-13: install-wsl.sh provides a `gh_release_install` helper**
```
Given: install-wsl.sh
When: grepped
Then: `gh_release_install()` function is defined
And: the body handles x86_64 and aarch64 arches
And: the body writes binaries to $HOME/.local/bin
And: the body is idempotent (skips when the target already exists with version ≥ requested)
```

**AC-14: install-wsl.sh invokes gh_release_install for tools missing from apt**
```
Given: install-wsl.sh step 2
When: grepped
Then: invocations exist for: sesh, yazi, jqp, diffnav, carapace
And: rip (cesarferreira) and rip2 (MilesCranmer) each call gh_release_install with distinct owners/repos
And: xh install path is apt (it exists in Ubuntu apt) — no gh_release_install call needed for xh
```

**AC-15: install-macos.sh symlinks all new configs**
```
Given: install-macos.sh step 3
When: grepped
Then: link() calls exist for yazi/*.toml (three), jqp/.jqp.yaml, diffnav/config.yml
And: the sesh template substitution block runs before the symlink block
```

**AC-16: verify.sh smoke-checks all new tools**
```
Given: scripts/verify.sh
When: inspected
Then: `command -v sesh|yazi|xh|rip|rip2|jqp|diffnav|carapace` checks exist
And: symlink checks exist for yazi/*.toml, jqp/.jqp.yaml, diffnav/config.yml, ~/.config/sesh/sesh.toml (file, not symlink)
```

**AC-17: test-plan2.sh still passes (.bashrc structure unchanged — 14 sections)**
```
Given: .bashrc with the new CARAPACE_BRIDGES export placed inside section 11
When: bash scripts/test-plan2.sh runs
Then: exit 0
And: ".bashrc has 14 numbered sections" check passes
```

**AC-18: End-to-end acceptance script enumerates every AC**
```
When: bash scripts/test-plan-layer1b-i.sh runs on macOS or WSL2
Then: every AC above is checked
And: exit 0 if all pass, 1 otherwise
```

---

## File Structure

**New files:**
- `sesh/sesh.toml.tmpl` — template with `@DOTFILES@`/`@HOME@` markers
- `yazi/yazi.toml` — core yazi config
- `yazi/keymap.toml` — vi-mode keymap (yazi defaults are mostly already vi-native)
- `yazi/theme.toml` — Dracula theme ported from `github.com/dracula/yazi`
- `jqp/.jqp.yaml` — `theme: dracula`
- `diffnav/config.yml` — Dracula palette
- `scripts/test-plan-layer1b-i.sh` — ATDD script with every AC

**Modified:**
- `Brewfile` — new "Shell-agnostic tools (Layer 1b-i)" section + two new tap declarations
- `tools.txt` — matching rows
- `bash/.bashrc` — CARAPACE_BRIDGES export in §11, carapace completion guard in §9
- `bash/.bash_aliases` — new aliases + `y()` function + extended `cheat()` case arms + extended help text
- `install-macos.sh` — sesh template substitution block, symlinks for yazi/jqp/diffnav
- `install-wsl.sh` — `gh_release_install()` helper, release installs for sesh/yazi/rip/rip2/jqp/diffnav/carapace, xh via apt, sesh template substitution, symlinks
- `scripts/verify.sh` — Layer 1b-i smoke checks section
- `docs/cheatsheet.md` — new Tool reference rows + discovery table rows

**Untouched:**
- `bash/.bash_profile`, `bash/.inputrc`
- `starship/starship.toml` (1b-ii updates this for BAT_THEME/FZF, not 1b-i)
- All tmux, television, gh configs

---

## Task 0: Bootstrap acceptance test script (Red)

**Files:**
- Create: `scripts/test-plan-layer1b-i.sh`

- [ ] **Step 1: Create the skeleton.** Copy the preamble verbatim from `scripts/test-plan-layer1a.sh` lines 1–55 (shebang, header, `set -uo pipefail`, self-resolve, `FULL` flag, platform detection, TTY-aware colours, `pass`/`fail`/`skip` counters, `ok`/`nok`/`skp`/`check` helpers). Update the header comment to read "test-plan-layer1b-i.sh — acceptance tests for Layer 1b-i (sesh + yazi + xh + rip + rip2 + jqp + diffnav + carapace)".

- [ ] **Step 2: Append the initial banner and AC-1/AC-2 stubs**

```bash
echo "Layer 1b-i acceptance tests (sesh/yazi/xh/rip/rip2/jqp/diffnav/carapace)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1: Brewfile declares all Layer 1b-i tools ─────────────────────────
echo "AC-1: Brewfile declares Layer 1b-i tools"
for t in sesh yazi xh rip2 jqp carapace; do
  check "Brewfile has brew \"$t\"" grep -qE "^\s*brew\s+\"$t\"" Brewfile
done
check "Brewfile has brew \"cesarferreira/tap/rip\"" \
  grep -qE '^\s*brew\s+"cesarferreira/tap/rip"' Brewfile
check "Brewfile has brew \"dlvhdr/formulae/diffnav\"" \
  grep -qE '^\s*brew\s+"dlvhdr/formulae/diffnav"' Brewfile
check "Brewfile taps cesarferreira/tap" \
  grep -qE '^\s*tap\s+"cesarferreira/tap"' Brewfile
check "Brewfile taps dlvhdr/formulae" \
  grep -qE '^\s*tap\s+"dlvhdr/formulae"' Brewfile

# ── AC-2: tools.txt manifest consistency ──────────────────────────────────
echo ""
echo "AC-2: tools.txt manifest consistency"
check "check-tool-manifest.sh passes" bash scripts/check-tool-manifest.sh

# Later tasks append AC-3 through AC-18 as they land.

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
```

- [ ] **Step 3:** `chmod +x scripts/test-plan-layer1b-i.sh`.

- [ ] **Step 4:** Run `bash scripts/test-plan-layer1b-i.sh`. Expected: AC-1 checks fail (tools not yet in Brewfile), AC-2 may pass if existing manifest is consistent. Overall exit 1.

- [ ] **Step 5: Commit**

```
git add scripts/test-plan-layer1b-i.sh
git commit -m "test(plan-layer1b-i): scaffold acceptance test script with AC-1 and AC-2"
```

---

## Task 1: Add Layer 1b-i tools to Brewfile + tools.txt (AC-1, AC-2)

**Files:**
- Modify: `Brewfile`, `tools.txt`

- [ ] **Step 1: Verify none of the tools are already declared**

Run `grep -E '^\s*brew\s+"(sesh|yazi|xh|rip2|jqp|diffnav|carapace)"|cesarferreira/tap/rip|dlvhdr/formulae/diffnav' Brewfile`. Expected: no output.

- [ ] **Step 2: Add two tap declarations** near the existing `tap "oven-sh/bun"` / `tap "charmbracelet/tap"` lines. Keep grouping consistent with existing tap section placement.

Insert:

```
# ── Layer 1b-i taps ──────────────────────────────────────────────────────────
tap "cesarferreira/tap"
tap "dlvhdr/formulae"
```

- [ ] **Step 3: Add a "Shell-agnostic tools (Layer 1b-i)" section** near the bottom of Brewfile (before the VS Code cask entry, after OpenCode runtime):

```
# ── Shell-agnostic tools (Layer 1b-i) ───────────────────────────────────────
# sesh: tmux session manager (CLI picker — complements tmux-sessionx plugin)
brew "sesh"
# yazi: terminal file manager (vi-mode native)
brew "yazi"
# xh: modern httpie replacement (httpie stays for team compat — see `http` alias)
brew "xh"
# rip (cesarferreira): fuzzy process killer — NOT a safe-rm
brew "cesarferreira/tap/rip"
# rip2 (MilesCranmer): safe rm with undo (graveyard ~/.local/share/graveyard)
brew "rip2"
# jqp: interactive jq playground (vi-navigation, Dracula theme)
brew "jqp"
# diffnav: file-tree nav UI on top of delta (used as gh-dash pager in 1b-iii)
brew "dlvhdr/formulae/diffnav"
# carapace: cross-shell completion bridge
brew "carapace"
```

- [ ] **Step 4: Add matching rows to tools.txt** (preserve the 21/31/23 column alignment used by existing rows):

```
# ── Shell-agnostic tools (Layer 1b-i) ───────────────────────────────────────
sesh                 brew:sesh                      apt:-                   apk:-
yazi                 brew:yazi                      apt:-                   apk:-
xh                   brew:xh                        apt:xh                  apk:xh
rip                  brew:cesarferreira/tap/rip     apt:-                   apk:-
rip2                 brew:rip2                      apt:-                   apk:-
jqp                  brew:jqp                       apt:-                   apk:-
diffnav              brew:dlvhdr/formulae/diffnav   apt:-                   apk:-
carapace             brew:carapace                  apt:-                   apk:-
```

- [ ] **Step 5: Validate** — `bash scripts/check-tool-manifest.sh` → exit 0.

- [ ] **Step 6:** `bash scripts/test-plan-layer1b-i.sh` → AC-1 and AC-2 pass. Exit 1 still (other ACs not yet added).

- [ ] **Step 7: Commit**

```
git add Brewfile tools.txt
git commit -m "feat(brewfile): add Layer 1b-i tools (sesh/yazi/xh/rip/rip2/jqp/diffnav/carapace)"
```

---

## Task 2: Create sesh template and install-time substitution (AC-3, AC-4)

**Files:**
- Create: `sesh/sesh.toml.tmpl`
- Modify: `install-macos.sh`, `install-wsl.sh`
- Modify: `scripts/test-plan-layer1b-i.sh`

- [ ] **Step 1: Append AC-3, AC-4 checks to the test script** (before the summary):

```bash
# ── AC-3: sesh template with substitution markers ─────────────────────────
echo ""
echo "AC-3: sesh/sesh.toml.tmpl"
check "sesh/sesh.toml.tmpl exists" test -f sesh/sesh.toml.tmpl
check "sesh template contains @DOTFILES@" \
  grep -q '@DOTFILES@' sesh/sesh.toml.tmpl
# No $ENV expansion inside [[session]] path fields — sesh requires absolute paths.
check "sesh template has no \$VAR expansion in paths" \
  bash -c '! grep -nE "^[[:space:]]*path[[:space:]]*=[[:space:]]*\"\\\$" sesh/sesh.toml.tmpl'

# ── AC-4: install scripts substitute template ─────────────────────────────
echo ""
echo "AC-4: install scripts generate ~/.config/sesh/sesh.toml"
check "install-macos.sh substitutes @DOTFILES@" \
  grep -q 's|@DOTFILES@|' install-macos.sh
check "install-wsl.sh substitutes @DOTFILES@" \
  grep -q 's|@DOTFILES@|' install-wsl.sh
check "install-macos.sh writes to ~/.config/sesh/sesh.toml" \
  grep -qE 'sesh/sesh\.toml[^.]' install-macos.sh
check "install-wsl.sh writes to ~/.config/sesh/sesh.toml" \
  grep -qE 'sesh/sesh\.toml[^.]' install-wsl.sh
if [[ "$FULL" == true ]] && [[ -f "$HOME/.config/sesh/sesh.toml" ]]; then
  if ! grep -q '@DOTFILES@' "$HOME/.config/sesh/sesh.toml"; then
    ok "generated sesh.toml contains no @DOTFILES@ markers"
  else
    nok "generated sesh.toml still contains @DOTFILES@ markers"
  fi
else
  skp "generated sesh.toml marker check" "requires --full + prior install"
fi
```

- [ ] **Step 2: Run — AC-3 and AC-4 fail.**

- [ ] **Step 3: Create `sesh/sesh.toml.tmpl`** with absolute-path markers. Design § 3.3 + § 3.10.3.

```toml
# sesh/sesh.toml.tmpl — template for ~/.config/sesh/sesh.toml
#
# sesh requires ABSOLUTE paths in [[session]] path fields — no env-var
# expansion is performed by sesh itself. Install scripts run `sed` at
# install time:
#   sed -e "s|@DOTFILES@|$DOTFILES|g" -e "s|@HOME@|$HOME|g" sesh.toml.tmpl > sesh.toml
# (Same pattern as the podman LaunchAgent plist.)

[default_session]
startup_command = ""

# ── Dotfiles session: edit the dotfiles repo itself ──────────────────────
[[session]]
name = "dotfiles"
path = "@DOTFILES@"
startup_command = "nvim"
windows = ["editor", "git", "files"]

# ── Home session: quick-access landing pad ───────────────────────────────
[[session]]
name = "home"
path = "@HOME@"
startup_command = ""

# ── Window definitions (reused by [[session]].windows arrays) ────────────
[[window]]
name = "editor"
startup_script = "nvim"

[[window]]
name = "git"
startup_script = "lazygit"

[[window]]
name = "files"
startup_script = "yazi"
```

- [ ] **Step 4: Add the install-time substitution block to install-macos.sh.** Locate the existing "Step 3: Symlink config files" section and insert BEFORE the first `link` call:

```bash
# ── sesh (generated from template — absolute paths required by schema) ──
mkdir -p "$HOME/.config/sesh"
sed -e "s|@DOTFILES@|$DOTFILES|g" -e "s|@HOME@|$HOME|g" \
  "$DOTFILES/sesh/sesh.toml.tmpl" > "$HOME/.config/sesh/sesh.toml"
printf "  generated %s\n" "$HOME/.config/sesh/sesh.toml"
```

- [ ] **Step 5: Add the same block to install-wsl.sh** at the analogous location (inside Step 4 "Symlink configs", before the first `link` call).

- [ ] **Step 6: Sanity test the generation locally (dry run)**

```
DOTFILES="$(pwd)" sed -e "s|@DOTFILES@|$DOTFILES|g" -e "s|@HOME@|$HOME|g" \
  sesh/sesh.toml.tmpl | head -10
```

Expected: `path = "/absolute/path/to/macos-dev"` (no `@DOTFILES@` markers).

- [ ] **Step 7: Run the test script**

`bash scripts/test-plan-layer1b-i.sh` → AC-3 passes, AC-4 static checks pass. Full-mode generated-file check is skipped.

- [ ] **Step 8: Commit**

```
git add sesh/sesh.toml.tmpl install-macos.sh install-wsl.sh scripts/test-plan-layer1b-i.sh
git commit -m "feat(sesh): add sesh.toml template + install-time substitution (Layer 1b-i)"
```

---

## Task 3: Create yazi configs and `y()` cd-on-quit wrapper (AC-5, AC-6)

**Files:**
- Create: `yazi/yazi.toml`, `yazi/keymap.toml`, `yazi/theme.toml`
- Modify: `bash/.bash_aliases`
- Modify: `install-macos.sh`, `install-wsl.sh`
- Modify: `scripts/test-plan-layer1b-i.sh`

- [ ] **Step 1: Add AC-5, AC-6 checks**

```bash
# ── AC-5: yazi configs exist and are symlinked ────────────────────────────
echo ""
echo "AC-5: yazi configs present and wired"
for f in yazi/yazi.toml yazi/keymap.toml yazi/theme.toml; do
  check "$f exists" test -f "$f"
done
check "install-macos.sh links yazi.toml" \
  grep -qE 'link\s+yazi/yazi\.toml' install-macos.sh
check "install-macos.sh links keymap.toml" \
  grep -qE 'link\s+yazi/keymap\.toml' install-macos.sh
check "install-macos.sh links theme.toml" \
  grep -qE 'link\s+yazi/theme\.toml' install-macos.sh
check "install-wsl.sh links yazi.toml" \
  grep -qE 'link\s+yazi/yazi\.toml' install-wsl.sh
check "install-wsl.sh links keymap.toml" \
  grep -qE 'link\s+yazi/keymap\.toml' install-wsl.sh
check "install-wsl.sh links theme.toml" \
  grep -qE 'link\s+yazi/theme\.toml' install-wsl.sh

# ── AC-6: y() cd-on-quit wrapper ─────────────────────────────────────────
echo ""
echo "AC-6: y() cd-on-quit wrapper"
check "bash/.bash_aliases defines y()" \
  bash -c "awk '/^y\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q 'yazi'"
check "y() body uses --cwd-file" \
  bash -c "awk '/^y\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -q -- '--cwd-file'"
check "y() body cds into the yazi-selected directory" \
  bash -c "awk '/^y\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//' | grep -qE 'builtin cd|^[[:space:]]*cd '"
```

- [ ] **Step 2: Run — AC-5 and AC-6 fail.**

- [ ] **Step 3: Create `yazi/yazi.toml`** (design § 3.4):

```toml
# yazi/yazi.toml — core yazi config
# See docs/plans/2026-04-12-shell-modernisation-design.md § 3.4

[manager]
layout = [1, 4, 3]
sort_by = "natural"
sort_sensitive = false
sort_reverse = false
sort_dir_first = true
show_hidden = false
show_symlink = true

[preview]
tab_size = 2
max_width = 600
max_height = 900

[opener]
edit = [
  { run = '${EDITOR:-nvim} "$@"', block = true, for = "unix" },
]
```

- [ ] **Step 4: Create `yazi/keymap.toml`** (yazi defaults are already vi-native; we only add `z` for zoxide-in-yazi which is picked up by a future plugin):

```toml
# yazi/keymap.toml — yazi keybindings
# Defaults are already vi-centric (h/j/k/l, gg/G, /, :). Extensions below.
# See docs/plans/2026-04-12-shell-modernisation-design.md § 3.10.3

[[manager.prepend_keymap]]
on = "!"
run = 'shell "$SHELL" --block --confirm'
desc = "Open shell in CWD"
```

- [ ] **Step 5: Create `yazi/theme.toml`** (Dracula — copied from `github.com/dracula/yazi`). The full theme is below; keep values literal. Do not edit the hex codes (they're Dracula palette: #282A36/#F8F8F2/#BD93F9/#FF79C6/#8BE9FD/#50FA7B/#FFB86C/#FF5555/#F1FA8C/#6272A4/#44475A):

```toml
# yazi/theme.toml — Dracula theme
# Source: github.com/dracula/yazi (community-maintained)

[manager]
cwd = { fg = "#8BE9FD" }
hovered         = { fg = "#282A36", bg = "#BD93F9" }
preview_hovered = { underline = true }
find_keyword    = { fg = "#FFB86C", italic = true }
find_position   = { fg = "#FF79C6", bg = "reset", italic = true }
marker_selected = { fg = "#50FA7B", bg = "#50FA7B" }
marker_copied   = { fg = "#F1FA8C", bg = "#F1FA8C" }
marker_cut      = { fg = "#FF5555", bg = "#FF5555" }
tab_active      = { fg = "#282A36", bg = "#BD93F9" }
tab_inactive    = { fg = "#F8F8F2", bg = "#44475A" }
tab_width       = 1
border_symbol   = "│"
border_style    = { fg = "#6272A4" }
syntect_theme   = ""

[status]
separator_open  = ""
separator_close = ""
separator_style = { fg = "#44475A", bg = "#44475A" }
mode_normal = { fg = "#282A36", bg = "#BD93F9", bold = true }
mode_select = { fg = "#282A36", bg = "#50FA7B", bold = true }
mode_unset  = { fg = "#282A36", bg = "#FFB86C", bold = true }
progress_label   = { fg = "#F8F8F2", bold = true }
progress_normal  = { fg = "#BD93F9", bg = "#44475A" }
progress_error   = { fg = "#FF5555", bg = "#44475A" }
permissions_t = { fg = "#8BE9FD" }
permissions_r = { fg = "#F1FA8C" }
permissions_w = { fg = "#FF5555" }
permissions_x = { fg = "#50FA7B" }
permissions_s = { fg = "#6272A4" }

[input]
border   = { fg = "#BD93F9" }
title    = {}
value    = {}
selected = { reversed = true }

[select]
border   = { fg = "#BD93F9" }
active   = { fg = "#FF79C6" }
inactive = {}

[tasks]
border  = { fg = "#BD93F9" }
title   = {}
hovered = { underline = true }

[which]
mask            = { bg = "#282A36" }
cand            = { fg = "#8BE9FD" }
rest            = { fg = "#6272A4" }
desc            = { fg = "#FF79C6" }
separator       = "  "
separator_style = { fg = "#44475A" }

[help]
on      = { fg = "#FF79C6" }
exec    = { fg = "#8BE9FD" }
desc    = { fg = "#6272A4" }
hovered = { bg = "#44475A", bold = true }
footer  = { fg = "#282A36", bg = "#F8F8F2" }

[filetype]
rules = [
  { mime = "image/*",                fg = "#FFB86C" },
  { mime = "video/*",                fg = "#F1FA8C" },
  { mime = "audio/*",                fg = "#F1FA8C" },
  { mime = "application/zip",        fg = "#FF79C6" },
  { mime = "application/gzip",       fg = "#FF79C6" },
  { mime = "application/x-tar",      fg = "#FF79C6" },
  { mime = "application/x-bzip",     fg = "#FF79C6" },
  { mime = "application/x-bzip2",    fg = "#FF79C6" },
  { mime = "application/x-7z-compressed", fg = "#FF79C6" },
  { mime = "application/x-rar",      fg = "#FF79C6" },
  { name = "*",                      fg = "#F8F8F2" },
  { name = "*/",                     fg = "#BD93F9" },
]
```

- [ ] **Step 6: Add the `y()` wrapper to `bash/.bash_aliases`.** Append in a new section at the end of the file (after the existing `ghorg-gh()` from Layer 1c):

```bash

# ── Yazi — cd-on-quit wrapper (Layer 1b-i) ──────────────────────────────────
# Launches yazi and, on exit, cd's the parent shell to whatever directory
# yazi was last in. `yazi` alone can't do this because a child process
# can't change the parent's cwd — it writes the final cwd to a temp file
# and the wrapper reads it back.
y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  cwd="$(cat -- "$tmp" 2>/dev/null)"
  if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
```

NOTE: The `awk '/^y\(\) \{/,/^\}/'` test pattern requires `y()` on a single line with `{` at line-end and the closing `}` at column 0 on its own line. Follow this exactly.

- [ ] **Step 7: Add symlinks to install-macos.sh** (Step 3, near the existing atuin/television symlinks):

```bash
# yazi (Plan Layer 1b-i)
link yazi/yazi.toml    .config/yazi/yazi.toml
link yazi/keymap.toml  .config/yazi/keymap.toml
link yazi/theme.toml   .config/yazi/theme.toml
```

- [ ] **Step 8: Add the same symlinks to install-wsl.sh.**

- [ ] **Step 9: Syntax check**

```
bash -n bash/.bash_aliases
bash -n install-macos.sh
bash -n install-wsl.sh
```

All exit 0.

- [ ] **Step 10:** `bash scripts/test-plan-layer1b-i.sh` → AC-5 and AC-6 pass.

- [ ] **Step 11: Commit**

```
git add yazi/ bash/.bash_aliases install-macos.sh install-wsl.sh scripts/test-plan-layer1b-i.sh
git commit -m "feat(yazi): add yazi config (Dracula) + y() cd-on-quit wrapper (Layer 1b-i)"
```

---

## Task 4: Create jqp config (AC-7)

**Files:**
- Create: `jqp/.jqp.yaml`
- Modify: `install-macos.sh`, `install-wsl.sh`
- Modify: `scripts/test-plan-layer1b-i.sh`

- [ ] **Step 1: Add AC-7 check**

```bash
# ── AC-7: jqp config (Dracula) ───────────────────────────────────────────
echo ""
echo "AC-7: jqp/.jqp.yaml"
check "jqp/.jqp.yaml exists" test -f jqp/.jqp.yaml
check "jqp config has theme: dracula" \
  grep -qE '^theme:\s*dracula\s*$' jqp/.jqp.yaml
check "install-macos.sh links jqp/.jqp.yaml" \
  grep -qE 'link\s+jqp/\.jqp\.yaml' install-macos.sh
check "install-wsl.sh links jqp/.jqp.yaml" \
  grep -qE 'link\s+jqp/\.jqp\.yaml' install-wsl.sh
```

- [ ] **Step 2: Run — AC-7 fails.**

- [ ] **Step 3: Create `jqp/.jqp.yaml`** (design § 4 "jqp config" decision):

```yaml
# jqp/.jqp.yaml — jqp (interactive jq playground) config
# Symlinked to ~/.jqp.yaml by install scripts.
# See docs/plans/2026-04-12-shell-modernisation-design.md § 3.9

theme: dracula
```

- [ ] **Step 4: Add symlink to install-macos.sh and install-wsl.sh.** Near the yazi block:

```bash
# jqp (Plan Layer 1b-i)
link jqp/.jqp.yaml  .jqp.yaml
```

- [ ] **Step 5:** `bash scripts/test-plan-layer1b-i.sh` → AC-7 passes.

- [ ] **Step 6: Commit**

```
git add jqp/ install-macos.sh install-wsl.sh scripts/test-plan-layer1b-i.sh
git commit -m "feat(jqp): add jqp config with dracula theme (Layer 1b-i)"
```

---

## Task 5: Create diffnav config (AC-8)

**Files:**
- Create: `diffnav/config.yml`
- Modify: `install-macos.sh`, `install-wsl.sh`
- Modify: `scripts/test-plan-layer1b-i.sh`

- [ ] **Step 1: Add AC-8 check**

```bash
# ── AC-8: diffnav config (Dracula palette) ───────────────────────────────
echo ""
echo "AC-8: diffnav/config.yml"
check "diffnav/config.yml exists" test -f diffnav/config.yml
check "install-macos.sh links diffnav/config.yml" \
  grep -qE 'link\s+diffnav/config\.yml' install-macos.sh
check "install-wsl.sh links diffnav/config.yml" \
  grep -qE 'link\s+diffnav/config\.yml' install-wsl.sh
```

- [ ] **Step 2: Run — AC-8 fails.**

- [ ] **Step 3: Create `diffnav/config.yml`** (design § 3.9 "diffnav" + § 3.10.3 "diffnav wraps delta"):

```yaml
# diffnav/config.yml — file-tree navigation pager for delta output.
# Used as gh-dash's pager (set up in Layer 1b-iii).
# See docs/plans/2026-04-12-shell-modernisation-design.md § 3.9

# diffnav reads this file at $XDG_CONFIG_HOME/diffnav/config.yml.
# Palette values are Dracula (see design § 3.9):
#   background=#282A36  foreground=#F8F8F2  comment=#6272A4
#   purple=#BD93F9  pink=#FF79C6  cyan=#8BE9FD  green=#50FA7B
#   orange=#FFB86C  red=#FF5555  yellow=#F1FA8C

# Pane layout: tree on the left, diff view on the right.
file_tree_width: 30

# Dracula styling for the panes.
theme:
  file_tree:
    selected_fg: "#282A36"
    selected_bg: "#BD93F9"
    unselected_fg: "#F8F8F2"
    border_fg: "#6272A4"
  diff:
    border_fg: "#6272A4"
  status_bar:
    fg: "#F8F8F2"
    bg: "#44475A"
```

- [ ] **Step 4: Add symlinks to install scripts** (near the jqp block):

```bash
# diffnav (Plan Layer 1b-i)
link diffnav/config.yml  .config/diffnav/config.yml
```

- [ ] **Step 5:** `bash scripts/test-plan-layer1b-i.sh` → AC-8 passes.

- [ ] **Step 6: Commit**

```
git add diffnav/ install-macos.sh install-wsl.sh scripts/test-plan-layer1b-i.sh
git commit -m "feat(diffnav): add diffnav dracula config (Layer 1b-i)"
```

---

## Task 6: Add carapace CARAPACE_BRIDGES + completion source to .bashrc (AC-9)

**Files:**
- Modify: `bash/.bashrc`
- Modify: `scripts/test-plan-layer1b-i.sh`

- [ ] **Step 1: Add AC-9 check**

```bash
# ── AC-9: carapace bridges wired into bash init ──────────────────────────
echo ""
echo "AC-9: carapace completion wiring"
check "CARAPACE_BRIDGES exported in .bashrc" \
  grep -qE '^export\s+CARAPACE_BRIDGES=' bash/.bashrc
check "CARAPACE_BRIDGES includes zsh,fish,bash,inshellisense" \
  bash -c "grep -E '^export CARAPACE_BRIDGES=' bash/.bashrc | grep -q 'zsh' && grep -E '^export CARAPACE_BRIDGES=' bash/.bashrc | grep -q 'bash' && grep -E '^export CARAPACE_BRIDGES=' bash/.bashrc | grep -q 'fish'"
# carapace completion source wrapped in a `command -v` guard.
check "carapace completion source is guarded" \
  grep -PzoE '(?s)command -v carapace[^\n]*\n[^\n]*carapace[[:space:]]+_carapace[[:space:]]+bash' bash/.bashrc >/dev/null 2>&1
```

NOTE: the multiline `grep -Pzo` pattern matches the structural if/source block — bare greps false-positive on comments. If the structural regex proves fragile, fall back to the equivalent `awk` range pattern scoped to section 9.

- [ ] **Step 2: Run — AC-9 fails.**

- [ ] **Step 3: Add CARAPACE_BRIDGES to section 3 of `bash/.bashrc`.**

The export must precede section 9 (Completions) so `carapace _carapace bash` sees it at init. Section 11 is too late. Place it at the end of section 3 — just after the DOTFILES export block and BEFORE the section 4 banner:

```bash

# carapace — cross-shell completion bridges. MUST be exported before
# section 9 (Completions) so `carapace _carapace bash` sees it at init.
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
```

Note the AC-9 check above requires the export to be anywhere in `.bashrc`; placing it in §3 satisfies both the grep (placement-agnostic) and the semantic requirement (ordering).

- [ ] **Step 4: Add the completion source to section 9 of `bash/.bashrc`** (after `cog generate-completions bash`):

```bash
# carapace (completion backstop for tools without native bash support).
# Requires CARAPACE_BRIDGES to be set earlier in this file (section 3).
if command -v carapace &>/dev/null; then
  source <(carapace _carapace bash)
fi
```

- [ ] **Step 5: Syntax check**

`bash -n bash/.bashrc` → exit 0.

- [ ] **Step 6: Sanity-check structure**

```
grep -c '^# ── [0-9]' bash/.bashrc
```

Expected: 14 (unchanged). The new blocks go INSIDE existing sections, not as a new section.

- [ ] **Step 7:** `bash scripts/test-plan-layer1b-i.sh` → AC-9 passes.

- [ ] **Step 8: Commit**

```
git add bash/.bashrc scripts/test-plan-layer1b-i.sh
git commit -m "feat(bash): wire carapace completion bridges (Layer 1b-i)"
```

---

## Task 7: Add new aliases + y() to bash/.bash_aliases (AC-10)

Note: `y()` already landed in Task 3. This task adds the seven text aliases.

**Files:**
- Modify: `bash/.bash_aliases`
- Modify: `scripts/test-plan-layer1b-i.sh`

- [ ] **Step 1: Add AC-10 checks**

```bash
# ── AC-10: new aliases with exact definitions ─────────────────────────────
echo ""
echo "AC-10: Layer 1b-i aliases defined"
check "alias http='xh'"            grep -qE "^alias http='xh'"            bash/.bash_aliases
check "alias rrip='rip2 -u'"       grep -qE "^alias rrip='rip2 -u'"       bash/.bash_aliases
check "alias rm-safe='rip2'"       grep -qE "^alias rm-safe='rip2'"       bash/.bash_aliases
check "alias jqi='jqp'"            grep -qE "^alias jqi='jqp'"            bash/.bash_aliases
check "alias dn='diffnav'"         grep -qE "^alias dn='diffnav'"         bash/.bash_aliases
check "alias sx='sesh connect'"    grep -qE "^alias sx='sesh connect'"    bash/.bash_aliases
check "alias sxl='sesh list'"      grep -qE "^alias sxl='sesh list'"      bash/.bash_aliases
```

- [ ] **Step 2: Run — AC-10 fails.**

- [ ] **Step 3: Add the aliases to `bash/.bash_aliases`.** Insert a new section near the end, BEFORE the "── Repo organisation (Layer 1c: ghq + ghorg) ────" section. Placement keeps layered sections in chronological order:

```bash

# ── Layer 1b-i aliases ──────────────────────────────────────────────────────
# xh — modern httpie replacement. httpie stays installed for team compat.
alias http='xh'

# rip (cesarferreira/rip) is a fuzzy process killer — no alias needed;
# invoke as `rip` directly. Do not confuse with rip2 (safe rm).

# rip2 (MilesCranmer/rip2) — safe rm with undo. Graveyard at
# ~/.local/share/graveyard (per §7.3 of design). Two aliases:
#   rrip     — undo last deletion
#   rm-safe  — explicit safe-rm (makes the intent unambiguous in scripts)
alias rrip='rip2 -u'
alias rm-safe='rip2'

# jqp — interactive jq playground
alias jqi='jqp'

# diffnav — file-tree navigation pager for delta output
alias dn='diffnav'

# sesh — tmux session manager. `sx` prefix to avoid collision with Linux `ss`.
alias sx='sesh connect'
alias sxl='sesh list'
```

- [ ] **Step 4: Syntax check**

`bash -n bash/.bash_aliases` → exit 0.

- [ ] **Step 5:** `bash scripts/test-plan-layer1b-i.sh` → AC-10 passes.

- [ ] **Step 6: Commit**

```
git add bash/.bash_aliases scripts/test-plan-layer1b-i.sh
git commit -m "feat(aliases): add Layer 1b-i aliases (http/rrip/rm-safe/jqi/dn/sx/sxl)"
```

---

## Task 8: Extend `cheat()` with per-tool subcommands (AC-11)

**Files:**
- Modify: `bash/.bash_aliases`
- Modify: `scripts/test-plan-layer1b-i.sh`

- [ ] **Step 1: Add AC-11 checks**

```bash
# ── AC-11: cheat() has subcommands for every new tool ────────────────────
echo ""
echo "AC-11: cheat() subcommand coverage"
# Scope to the cheat() function body so comments elsewhere don't false-positive.
cheat_body() { awk '/^cheat\(\) \{/,/^\}/' bash/.bash_aliases | sed 's/#.*//'; }
for tool in atuin "tv|television" sesh yazi xh rip rip2 jqp diffnav; do
  if cheat_body | grep -qE "^[[:space:]]*${tool}\)"; then
    ok "cheat: case arm for '$tool' present"
  else
    nok "cheat: case arm for '$tool' present"
  fi
done
check "cheat help lists new subcommands" \
  bash -c "cheat_body() { awk '/^cheat\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//'; }; cheat_body | grep -q 'sesh, yazi, xh, rip'"
```

NOTE: the `cheat_body` helper inlined at the check site ensures scoped matching — bare greps on `.bash_aliases` would false-positive on alias comments mentioning tool names.

- [ ] **Step 2: Run — AC-11 fails.**

- [ ] **Step 3: Open `bash/.bash_aliases` and extend the `cheat()` `case` block.**

Find the existing `case "${1:-}" in` block inside `cheat()`. Add the following arms IMMEDIATELY AFTER the `starship)` arm and BEFORE the `opencode|oc)` arm:

```bash
    atuin)
      cat <<'EOF'
atuin — shell history with search + filtering
  Ctrl-R           interactive search (shell-global)
  atuin search -i  same picker from the CLI
  atuin stats      usage stats
  atuin import auto   pull existing history on first login (if desired)
Config: ~/.config/atuin/config.toml
EOF
      ;;
    tv|television)
      cat <<'EOF'
television — channel-based fuzzy picker
  Ctrl-T           smart autocomplete (shell integration, context-aware)
  tv <channel>     open channel by name (e.g. tv files, tv git-branch)
  tv --list        list available channels
Cable channels live at ~/.config/television/cable/ (Layer 1b-iii).
EOF
      ;;
    sesh)
      cat <<'EOF'
sesh — tmux session manager (CLI picker + tmux plugin)
  sx               connect (alias for `sesh connect`)
  sxl              list sessions (alias for `sesh list`)
  sesh last        re-attach to the most recent session
Config: ~/.config/sesh/sesh.toml (generated from sesh/sesh.toml.tmpl).
EOF
      ;;
    yazi)
      cat <<'EOF'
yazi — terminal file manager (vi-mode native)
  y                open yazi and cd to the selected dir on quit
  <CR> / o         open file / enter dir
  h/j/k/l          navigate (default)
  /                fuzzy search (fd + rg under the hood)
  q                quit without cd
Config: ~/.config/yazi/{yazi,keymap,theme}.toml
EOF
      ;;
    xh)
      cat <<'EOF'
xh — modern httpie replacement (Rust, single binary)
  http GET httpbin.org/get   shorthand alias for xh
  xh POST httpbin.org/post name=alice
  xh --json GET ...          force JSON
Syntax: method-as-first-arg, key=value JSON body, key==value query, key:value header.
Differences from httpie: no Python; smaller binary; --offline flag available.
EOF
      ;;
    rip)
      cat <<'EOF'
rip (cesarferreira/rip) — fuzzy process killer
  rip              list processes, select with fzf, send SIGTERM
  rip -9           send SIGKILL instead
NOT a safe-rm. For that, use rip2 (see `cheat rip2`).
EOF
      ;;
    rip2)
      cat <<'EOF'
rip2 (MilesCranmer/rip2) — safe rm with undo
  rip2 file ...    move files to the graveyard (not deleted)
  rrip             undo last rip2 deletion (alias for `rip2 -u`)
  rm-safe file     explicit safe-rm alias (avoid confusion with rip, the killer)
Graveyard: ~/.local/share/graveyard
EOF
      ;;
    jqp)
      cat <<'EOF'
jqp — interactive jq playground
  jqi <file>       open jqp on a JSON file (alias for jqp)
  cat foo.json | jqp
Tab switches panels; Ctrl-C exits.
Config: ~/.jqp.yaml (theme: dracula).
EOF
      ;;
    diffnav)
      cat <<'EOF'
diffnav — file-tree nav UI over delta output
  dn <unified.diff>    navigate a diff
  git diff | dn        pipe diff directly
h/l moves between files; j/k moves between hunks.
Used as gh-dash's pager (see 1b-iii).
EOF
      ;;
```

- [ ] **Step 4: Extend the `help` arm and `*)` fallback.**

Update the `help` arm text (search for `-h|--help|help)` in `cheat()`). The `Per-tool subcommands:` block should list the new arms. Replace:

```
Per-tool subcommands:
  bash, btop, delta, fzf, git, k9s, lazydocker, lazygit, lnav,
  nvim, opencode, starship, tmux
```

with:

```
Per-tool subcommands:
  atuin, bash, btop, delta, diffnav, fzf, git, jqp, k9s, lazydocker,
  lazygit, lnav, nvim, opencode, rip, rip2, sesh, starship, tmux,
  tv/television, xh, yazi
```

- [ ] **Step 5: Syntax check**

`bash -n bash/.bash_aliases` → exit 0.

- [ ] **Step 6:** `bash scripts/test-plan-layer1b-i.sh` → AC-11 passes.

- [ ] **Step 7: Commit**

```
git add bash/.bash_aliases scripts/test-plan-layer1b-i.sh
git commit -m "feat(cheat): add per-tool subcommands for Layer 1b-i tools"
```

---

## Task 9: Update docs/cheatsheet.md (AC-12)

**Files:**
- Modify: `docs/cheatsheet.md`
- Modify: `scripts/test-plan-layer1b-i.sh`

- [ ] **Step 1: Add AC-12 checks**

```bash
# ── AC-12: cheatsheet.md tool reference rows ─────────────────────────────
echo ""
echo "AC-12: cheatsheet.md Tool reference coverage"
check "cheatsheet lists sesh/sx"       grep -qE '\bsesh\b.*\bsx\b' docs/cheatsheet.md
check "cheatsheet lists yazi/y"        grep -qE 'yazi.*\`y\`|\byazi\b.*cd-on-quit' docs/cheatsheet.md
check "cheatsheet lists xh/http"       grep -qE '\bxh\b.*\bhttp\b' docs/cheatsheet.md
check "cheatsheet lists rip (killer)"  grep -qiE 'rip.*process.*killer|rip.*fuzzy.*killer' docs/cheatsheet.md
check "cheatsheet lists rip2/rrip"     grep -qE '\brip2\b.*\brrip\b|rrip.*rip2' docs/cheatsheet.md
check "cheatsheet lists jqp/jqi"       grep -qE '\bjqp\b.*\bjqi\b|jqi.*jqp' docs/cheatsheet.md
check "cheatsheet lists diffnav/dn"    grep -qE '\bdiffnav\b.*\bdn\b' docs/cheatsheet.md
```

- [ ] **Step 2: Run — AC-12 fails for the new tools.**

- [ ] **Step 3: Add a "Layer 1b-i tools" subsection to the Tool reference section.**

Find `## Tool reference` and insert a new `### Layer 1b-i tools` subsection AFTER `### Searching` and BEFORE `### Git`:

```markdown
### Layer 1b-i tools

| Task | Tool | Command | Alias |
|------|------|---------|-------|
| tmux session manager (CLI) | sesh | `sesh connect <name>` | `sx` |
| List sesh sessions | sesh | `sesh list` | `sxl` |
| File manager (cd-on-quit) | yazi | `yazi` | `y` (function) |
| HTTP client | xh | `xh GET httpbin.org/get` | `http` |
| Fuzzy process killer | rip | `rip` | — |
| Safe rm (undo-able) | rip2 | `rip2 file` | `rm-safe` |
| Undo last rip2 delete | rip2 | `rip2 -u` | `rrip` |
| Interactive jq playground | jqp | `cat file.json \| jqp` | `jqi` |
| Navigate diffs (delta UI) | diffnav | `git diff \| diffnav` | `dn` |
| Cross-shell completions | carapace | auto (via bash init) | — |
```

- [ ] **Step 4: Extend the "Discover full bindings inside each tool" table.** Append rows for `sesh`, `yazi`, `jqp`, `diffnav`, `xh`, `rip`, `rip2`:

```markdown
| sesh | `cheat sesh` |
| yazi | Inside yazi: `?` for help overlay |
| jqp | Inside jqp: `Ctrl+H` for help |
| diffnav | Inside diffnav: `?` for help |
| xh | `xh --help`; `cheat xh` for quickstart |
| rip / rip2 | `cheat rip` / `cheat rip2` |
```

- [ ] **Step 5:** `bash scripts/test-plan-layer1b-i.sh` → AC-12 passes.

- [ ] **Step 6: Commit**

```
git add docs/cheatsheet.md scripts/test-plan-layer1b-i.sh
git commit -m "docs(cheatsheet): add Layer 1b-i tool reference + discovery rows"
```

---

## Task 10: Add `gh_release_install()` helper + WSL release installs (AC-13, AC-14)

**Files:**
- Modify: `install-wsl.sh`
- Modify: `scripts/test-plan-layer1b-i.sh`

- [ ] **Step 1: Add AC-13 and AC-14 checks**

```bash
# ── AC-13: gh_release_install() helper ───────────────────────────────────
echo ""
echo "AC-13: install-wsl.sh gh_release_install helper"
check "gh_release_install is defined" \
  bash -c "awk '/^gh_release_install\\(\\) \\{/,/^\\}/' install-wsl.sh | grep -q '.'"
check "helper handles x86_64"    \
  bash -c "awk '/^gh_release_install\\(\\) \\{/,/^\\}/' install-wsl.sh | grep -q 'x86_64'"
check "helper handles aarch64"   \
  bash -c "awk '/^gh_release_install\\(\\) \\{/,/^\\}/' install-wsl.sh | grep -q 'aarch64'"
check "helper writes to ~/.local/bin" \
  bash -c "awk '/^gh_release_install\\(\\) \\{/,/^\\}/' install-wsl.sh | grep -q '.local/bin'"
check "helper is idempotent (checks for existing binary)" \
  bash -c "awk '/^gh_release_install\\(\\) \\{/,/^\\}/' install-wsl.sh | grep -qE 'command -v|-x '"

# ── AC-14: install-wsl.sh installs each tool ──────────────────────────────
echo ""
echo "AC-14: install-wsl.sh installs Layer 1b-i tools"
check "install-wsl.sh installs sesh" \
  grep -qE 'gh_release_install\s+"?joshmedeski/sesh"?' install-wsl.sh
check "install-wsl.sh installs yazi" \
  grep -qE 'gh_release_install\s+"?sxyazi/yazi"?' install-wsl.sh
check "install-wsl.sh installs rip (cesarferreira)" \
  grep -qE 'gh_release_install\s+"?cesarferreira/rip"?' install-wsl.sh
check "install-wsl.sh installs rip2 (MilesCranmer)" \
  grep -qE 'gh_release_install\s+"?MilesCranmer/rip2"?' install-wsl.sh
check "install-wsl.sh installs jqp (noahgorstein)" \
  grep -qE 'gh_release_install\s+"?noahgorstein/jqp"?' install-wsl.sh
check "install-wsl.sh installs diffnav (dlvhdr)" \
  grep -qE 'gh_release_install\s+"?dlvhdr/diffnav"?' install-wsl.sh
check "install-wsl.sh installs carapace" \
  grep -qE 'gh_release_install\s+"?rsteube/carapace-bin"?' install-wsl.sh
# xh is in apt.
check "install-wsl.sh apt-installs xh" \
  grep -qE 'apt\s+install.*\bxh\b' install-wsl.sh
```

- [ ] **Step 2: Run — AC-13 and AC-14 fail.**

- [ ] **Step 3: Add the `gh_release_install()` helper** immediately after the existing `link()` helper in `install-wsl.sh`:

```bash
# ── gh_release_install ───────────────────────────────────────────────────
# Download a GitHub release binary and install it into ~/.local/bin.
#
# Usage: gh_release_install <owner/repo> <binary-name> [<asset-pattern>]
#   owner/repo:     e.g. "joshmedeski/sesh"
#   binary-name:    the executable to place in ~/.local/bin (e.g. "sesh")
#   asset-pattern:  optional extra regex to narrow the asset match
#                   (defaults to the arch pattern below)
#
# Idempotent: skips if ~/.local/bin/<binary-name> is already executable.
# This is a coarse idempotency check — for version pinning, delete the
# binary and re-run the installer.
#
# Requires: curl, tar, (optional) jq. Falls back to grep/sed parsing if
# jq is unavailable (which it is during early bootstrap on fresh WSL).
gh_release_install() {
  local repo="$1" binary="$2" extra_pattern="${3:-}"
  local arch os tmp asset url
  mkdir -p "$HOME/.local/bin"

  # Idempotency: already installed.
  if [[ -x "$HOME/.local/bin/$binary" ]] || command -v "$binary" &>/dev/null; then
    printf "  already installed: %s\n" "$binary"
    return 0
  fi

  # Arch detection.
  case "$(uname -m)" in
    x86_64)  arch='x86_64|amd64|x64' ;;
    aarch64|arm64) arch='aarch64|arm64' ;;
    *)       warn "gh_release_install: unsupported arch $(uname -m) for $binary"; return 1 ;;
  esac

  # OS detection.
  case "$(uname -s)" in
    Linux)   os='linux|unknown-linux-(gnu|musl)' ;;
    Darwin)  os='darwin|apple-darwin' ;;
    *)       warn "gh_release_install: unsupported OS $(uname -s)"; return 1 ;;
  esac

  log "fetching latest release metadata: $repo"
  local api="https://api.github.com/repos/$repo/releases/latest"
  local releases_json
  if ! releases_json="$(curl -fsSL "$api" 2>/dev/null)"; then
    warn "gh_release_install: cannot reach GitHub API for $repo"
    return 1
  fi

  # Select a .tar.gz asset matching both arch and os, plus any extra_pattern.
  # Prefer gnu over musl when both exist (glibc on Ubuntu).
  local pattern="($arch).*($os)"
  [[ -n "$extra_pattern" ]] && pattern="$pattern.*$extra_pattern"

  url="$(printf '%s' "$releases_json" \
    | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | sed -E 's/.*"([^"]+)"$/\1/' \
    | grep -E "$pattern" \
    | grep -E '\.tar\.gz$|\.tgz$' \
    | grep -vE 'musl' \
    | head -1)"

  # Fallback: musl-only releases (e.g. some Rust static binaries).
  if [[ -z "$url" ]]; then
    url="$(printf '%s' "$releases_json" \
      | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' \
      | sed -E 's/.*"([^"]+)"$/\1/' \
      | grep -E "$pattern" \
      | grep -E '\.tar\.gz$|\.tgz$' \
      | head -1)"
  fi

  if [[ -z "$url" ]]; then
    warn "gh_release_install: no matching asset found for $repo (arch=$arch os=$os)"
    return 1
  fi

  log "downloading $url"
  tmp="$(mktemp -d)"
  if ! curl -fsSL -o "$tmp/asset.tar.gz" "$url"; then
    warn "gh_release_install: download failed for $url"
    rm -rf "$tmp"
    return 1
  fi

  # Extract and locate the binary. Handles flat archives and subdir archives.
  tar -xzf "$tmp/asset.tar.gz" -C "$tmp"
  asset="$(find "$tmp" -type f -name "$binary" -perm -u+x | head -1)"
  if [[ -z "$asset" ]]; then
    asset="$(find "$tmp" -type f -name "$binary" | head -1)"
  fi
  if [[ -z "$asset" ]]; then
    warn "gh_release_install: binary '$binary' not found in archive for $repo"
    rm -rf "$tmp"
    return 1
  fi

  install -m 0755 "$asset" "$HOME/.local/bin/$binary"
  printf "  installed %s → ~/.local/bin/%s\n" "$binary" "$binary"
  rm -rf "$tmp"
}
```

- [ ] **Step 4: Update `install-wsl.sh` apt list to include `xh`.** Find `sudo apt install -y \` and append `xh` on a new continuation line (alphabetical group, near `jq`). Note: xh has been in Ubuntu apt since 24.04; older WSL users will see the apt install fail and must upgrade or install from release (documented in the plan's "Manual Validation" section).

- [ ] **Step 5: Replace Step 2 stub in install-wsl.sh** with concrete Layer 1b-i invocations. Find the `# ── Step 2: GitHub release / install script installs` block and REPLACE the two warn lines with:

```bash
# ── Step 2: GitHub release installs (Layer 1a + 1b-i) ────────────────────
log "installing release binaries (Layer 1a)"
gh_release_install "atuinsh/atuin"                atuin
gh_release_install "alexpasmantier/television"    tv

log "installing release binaries (Layer 1b-i)"
gh_release_install "joshmedeski/sesh"             sesh
gh_release_install "sxyazi/yazi"                  yazi
gh_release_install "cesarferreira/rip"            rip
gh_release_install "MilesCranmer/rip2"            rip2
gh_release_install "noahgorstein/jqp"             jqp
gh_release_install "dlvhdr/diffnav"               diffnav
gh_release_install "rsteube/carapace-bin"         carapace
```

- [ ] **Step 6: Syntax check**

`bash -n install-wsl.sh` → exit 0.

- [ ] **Step 7:** `bash scripts/test-plan-layer1b-i.sh` → AC-13 and AC-14 pass (static).

- [ ] **Step 8: Commit**

```
git add install-wsl.sh scripts/test-plan-layer1b-i.sh
git commit -m "feat(install-wsl): add gh_release_install helper + Layer 1b-i tool installs"
```

---

## Task 11: Add install-macos.sh symlinks block (AC-15)

**Files:**
- Modify: `install-macos.sh`
- Modify: `scripts/test-plan-layer1b-i.sh`

Note: Tasks 3–5 already added individual `link` calls. This task is a consistency audit — verify every new config is symlinked and the sesh substitution runs first.

- [ ] **Step 1: Add AC-15 checks**

```bash
# ── AC-15: install-macos.sh wires all new configs ────────────────────────
echo ""
echo "AC-15: install-macos.sh Layer 1b-i wiring"
check "install-macos.sh links yazi/yazi.toml"    grep -qE 'link\s+yazi/yazi\.toml' install-macos.sh
check "install-macos.sh links yazi/keymap.toml"  grep -qE 'link\s+yazi/keymap\.toml' install-macos.sh
check "install-macos.sh links yazi/theme.toml"   grep -qE 'link\s+yazi/theme\.toml' install-macos.sh
check "install-macos.sh links jqp/.jqp.yaml"     grep -qE 'link\s+jqp/\.jqp\.yaml' install-macos.sh
check "install-macos.sh links diffnav/config"    grep -qE 'link\s+diffnav/config\.yml' install-macos.sh
# sesh sed block runs BEFORE the first link call (see design § 2.5).
check "install-macos.sh sesh substitution precedes first link()" \
  bash -c 'sed_line=$(grep -n "sed .*@DOTFILES@" install-macos.sh | head -1 | cut -d: -f1);
           link_line=$(grep -n "^link " install-macos.sh | head -1 | cut -d: -f1);
           [[ -n "$sed_line" && -n "$link_line" && $sed_line -lt $link_line ]]'
```

- [ ] **Step 2: Run.** If Tasks 2, 3, 4, 5 were completed cleanly, AC-15 should already pass. Fix any missing link calls or ordering.

- [ ] **Step 3: Ensure sesh block precedes symlinks.** Verify by `grep -n 'sed.*@DOTFILES@\|^link ' install-macos.sh | head -5`; expected: sed line number < first link line number.

- [ ] **Step 4: Syntax check + test**

```
bash -n install-macos.sh
bash scripts/test-plan-layer1b-i.sh
```

AC-15 passes.

- [ ] **Step 5: Commit (skip if no diff)**

If changes were needed:
```
git add install-macos.sh scripts/test-plan-layer1b-i.sh
git commit -m "chore(install-macos): consolidate Layer 1b-i symlink wiring (Layer 1b-i)"
```

---

## Task 12: Update verify.sh (AC-16)

**Files:**
- Modify: `scripts/verify.sh`
- Modify: `scripts/test-plan-layer1b-i.sh`

- [ ] **Step 1: Add AC-16 checks**

```bash
# ── AC-16: verify.sh Layer 1b-i smoke checks ─────────────────────────────
echo ""
echo "AC-16: verify.sh smoke coverage"
for t in sesh yazi xh rip rip2 jqp diffnav carapace; do
  check "verify.sh checks '$t'" grep -qE "command -v $t\b" scripts/verify.sh
done
check "verify.sh checks yazi/yazi.toml symlink"  grep -qE '\.config/yazi/yazi\.toml' scripts/verify.sh
check "verify.sh checks jqp/.jqp.yaml symlink"   grep -qE '\.jqp\.yaml' scripts/verify.sh
check "verify.sh checks diffnav config symlink"  grep -qE 'diffnav/config\.yml' scripts/verify.sh
check "verify.sh checks sesh.toml is a regular file" \
  bash -c "grep -qE 'sesh/sesh\\.toml' scripts/verify.sh"
```

- [ ] **Step 2: Run — AC-16 fails.**

- [ ] **Step 3: Add a "Layer 1b-i tools" block to `scripts/verify.sh`** after the existing "Layer 1c tools" block:

```bash
# ── Layer 1b-i tools ──────────────────────────────────────────────────────
echo ""
echo "Layer 1b-i tools:"
for t in sesh yazi xh rip rip2 jqp diffnav carapace; do
  check "$t on PATH" command -v "$t"
done

# yazi configs
# shellcheck disable=SC2016  # $HOME expanded inside inner bash -c intentionally
check "yazi config symlink resolves" \
  bash -c 'test -L "$HOME/.config/yazi/yazi.toml" && test -e "$HOME/.config/yazi/yazi.toml"'
# shellcheck disable=SC2016
check "yazi keymap symlink resolves" \
  bash -c 'test -L "$HOME/.config/yazi/keymap.toml" && test -e "$HOME/.config/yazi/keymap.toml"'
# shellcheck disable=SC2016
check "yazi theme symlink resolves" \
  bash -c 'test -L "$HOME/.config/yazi/theme.toml" && test -e "$HOME/.config/yazi/theme.toml"'

# jqp config (~/.jqp.yaml)
# shellcheck disable=SC2016
check "jqp config symlink resolves" \
  bash -c 'test -L "$HOME/.jqp.yaml" && test -e "$HOME/.jqp.yaml"'

# diffnav config
# shellcheck disable=SC2016
check "diffnav config symlink resolves" \
  bash -c 'test -L "$HOME/.config/diffnav/config.yml" && test -e "$HOME/.config/diffnav/config.yml"'

# sesh.toml is a regular file (generated from template), NOT a symlink
# shellcheck disable=SC2016
check "sesh.toml is a generated regular file" \
  bash -c 'test -f "$HOME/.config/sesh/sesh.toml" && test ! -L "$HOME/.config/sesh/sesh.toml"'
```

- [ ] **Step 4:** `bash scripts/test-plan-layer1b-i.sh` → AC-16 passes.

- [ ] **Step 5: Run verify.sh itself** (static mode is fine, skipping tool-on-PATH in safe mode is acceptable):

`bash scripts/verify.sh || true`

Expected (on the dev host where installs haven't run): some PATH checks fail — that's expected until `install-*.sh` runs. The shellcheck and symlink logic is what we care about here.

- [ ] **Step 6: Commit**

```
git add scripts/verify.sh scripts/test-plan-layer1b-i.sh
git commit -m "feat(verify): add Layer 1b-i tool and symlink checks"
```

---

## Task 13: Preserve structural invariants (AC-17) + final e2e (AC-18)

**Files:**
- Modify: `scripts/test-plan-layer1b-i.sh`

- [ ] **Step 1: Add AC-17 guardrail**

```bash
# ── AC-17: .bashrc still has 14 numbered sections ────────────────────────
echo ""
echo "AC-17: .bashrc structural invariants preserved"
section_count=$(grep -c '^# ── [0-9]' bash/.bashrc)
if [[ "$section_count" -eq 14 ]]; then
  ok ".bashrc has 14 numbered sections"
else
  nok ".bashrc has $section_count sections (expected 14)"
fi
# Composite: the full test-plan2.sh must still pass.
check "test-plan2.sh still passes" bash scripts/test-plan2.sh
```

- [ ] **Step 2: Verify AC-17 passes**

`bash scripts/test-plan-layer1b-i.sh | grep -E 'AC-17|14 numbered'`

Expected: pass. If it fails, the culprit is a new `# ── N …` header introduced inadvertently — remove it.

- [ ] **Step 3: Run the full acceptance script**

`bash scripts/test-plan-layer1b-i.sh` → exit 0, all ACs pass.

- [ ] **Step 4: Run `--full` mode** (invasive checks, requires tools installed)

`bash scripts/test-plan-layer1b-i.sh --full` → ACs that require `$HOME/.config/sesh/sesh.toml` to exist pass if install scripts have been run locally. Accept `skp` results on CI where the install hasn't been run.

- [ ] **Step 5: Shellcheck sweep**

```
find . -type f -name '*.sh' -not -path './.worktrees/*' -print0 | xargs -0 shellcheck
```

Expected: silent (no warnings).

- [ ] **Step 6: Run all existing test-plan scripts in safe mode**

```
for f in scripts/test-plan*.sh; do bash "$f" >/dev/null 2>&1 || echo "FAIL: $f"; done
```

Expected: no FAIL output (test-plan1..14-16 all green; Layer 1a, Layer 1c, Layer 1b-i green).

- [ ] **Step 7: Commit**

```
git add scripts/test-plan-layer1b-i.sh
git commit -m "test(plan-layer1b-i): wire AC-17 invariant + e2e e2e gate (AC-18)"
```

- [ ] **Step 8: Merge readiness check**

Ensure every AC section in `scripts/test-plan-layer1b-i.sh` is non-empty (no skipped AC numbers):

```
grep -E '^# ── AC-[0-9]+' scripts/test-plan-layer1b-i.sh | sort -V
```

Expected: AC-1 through AC-18 listed, no gaps.

---

## Post-plan: Manual Validation Steps

After CI passes, verify end-to-end on macOS and WSL2:

**macOS:**
1. `bash install-macos.sh` — symlinks all new configs; generates `~/.config/sesh/sesh.toml` with absolute `@DOTFILES@`/`@HOME@` substituted; brews all new tools.
2. New shell: `sx<Tab>` → sesh list, connect to "dotfiles" → tmux session opens nvim in the dotfiles repo.
3. `y` → yazi opens; navigate, `q` quits with cd into the selected dir.
4. `http GET https://httpbin.org/get` → JSON response.
5. `rm-safe /tmp/testfile` → moves to `~/.local/share/graveyard`; `rrip` restores.
6. `rip` → fuzzy process picker.
7. `echo '{"a":1}' | jqp` → interactive jq.
8. `git diff | dn` → file-tree diff navigation.
9. `cheat yazi` / `cheat rip2` → help text renders.

**WSL2:**
Same, but `install-wsl.sh --check-preconditions` first, then full install.

---

## Self-Review Notes (recorded at plan write time)

- **Spec coverage:** design §§ 3.3, 3.4, 3.8 (aliases list), 3.10.3 (sesh `[[window]]` integration), 4 (Layer 1b bullet 1), 5 (install scripts), 8.1 (cheat subcommands), 8.2 (cheatsheet rows) all mapped to tasks. The `Layer 1b` scope items deferred to siblings: cable channels → 1b-iii; TPM/plugins → 1b-ii; gh-dash → 1b-iii. This file does NOT introduce those.
- **Type consistency:** `y()` is defined in Task 3 and referenced in Tasks 8/9/12 — signature matches. All aliases use exact quoted strings in both the plan body and AC-10 greps.
- **Placeholders:** zero TODOs, zero "similar to earlier task" references — each code block is explicit.
- **Invariants preserved:** `.bashrc` remains 14 sections (carapace export goes into §3; source into §9 — both inside existing sections). `starship.toml` untouched. test-plan2 and test-plan6-8 assertions unchanged.
- **Shellcheck:** all new bash is guarded with `command -v` / `[[ -x ... ]]`. Inline `# shellcheck disable=SCxxxx # reason` comments accompany every intentional `$VAR` inside single-quoted `bash -c` (SC2016) and every `test -L / test -e` double-invocation pattern.
- **Forward compat:** `gh_release_install` is designed to be reused by Layer 1b-ii (for TPM dependencies on WSL if needed) and 1b-iii (for gh — already installed, but the helper is general).
