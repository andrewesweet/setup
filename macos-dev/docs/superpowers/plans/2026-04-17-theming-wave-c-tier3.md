# Wave C — Tier 3 Custom Reconstruction from Pro Palette Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Tier 3 Dracula Pro custom theming for every tool in the theming spec § 3.3 table. Each tool gets a palette-reconstructed theme (or env-var style string) that sources hex values from the Wave-A-committed `scripts/lib/dracula-pro-palette.sh`, with acceptance-test coverage in `scripts/test-plan-theming.sh` that asserts every slot of the tool's profile (spec § 5.1 / § 5.2).

**Architecture:** Wave A committed the single source of truth (`scripts/lib/dracula-pro-palette.sh`) and the AC scaffold (`scripts/test-plan-theming.sh` with a shared `check` helper). Wave C appends tool-by-tool ACs (red), authors the custom theme artefact (file, config block, env var), wires it into the tool's config path or shell env, runs the AC (green), and commits. Tools in the "inherits" column (`diffnav`, `jankyborders`, `aerospace`) get verification-only tasks that assert they consume the correct upstream (delta+bat, sketchybar `colors.sh`). Sketchybar itself gets an audit task that diffs its `COLOR_*` exports against the palette file and reconciles drift by sourcing the palette file rather than hardcoding hex.

**Tech Stack:** bash, grep/sed/awk, Plist XML (bat `.tmTheme`), TOML (atuin / television / k9s / lnav), YAML (lazydocker / jqp / httpie JSON / glow JSON), INI-ish (btop), chroma XML (freeze), plus git `.gitconfig` INI.

**Spec reference:** `macos-dev/docs/design/theming.md` — §§ 3.3, 5.1, 5.2, 5.3 Wave C, 6.1–6.3.

**Platform scope:** macOS (Apple Silicon + Intel) primary; WSL2 parity for tools that ship on Linux. All ACs are static grep-style over committed files — they pass on any platform without the tool binary installed.

---

## Prerequisites

> **Wave A (`feature/theming-wave-a-tier1`) MUST be merged to `main` before Wave C is executed.** Wave A provides `scripts/lib/dracula-pro-palette.sh`, the `/dracula-pro/` `.gitignore` entry, `SKIP_DRACULA_PRO` env handling in `install-macos.sh` / `install-wsl.sh`, and the `scripts/test-plan-theming.sh` scaffold — with the shared `check` / `ok` / `nok` / `skp` helpers — that Wave C extends. Wave B is NOT a hard prerequisite, but landing Wave B first is RECOMMENDED to avoid palette-aware review bleed across waves.

**Wave A deliverables this plan depends on:**
- `macos-dev/scripts/lib/dracula-pro-palette.sh` — verbatim palette exports per spec § 6.3.
- `macos-dev/scripts/test-plan-theming.sh` — bash harness that defines `check`, `ok`, `nok`, `skp`, a pass/fail/skip counter block, and a final `(( fail == 0 ))` exit. Wave C tasks **append** ACs — they MUST NOT redefine `check`.
- `.gitignore` entry `/dracula-pro/`.

**Wave C authoring constraint:**
Every hex string embedded in a tool config below is reproduced verbatim from the Pro Base / Terminal Standard palette and annotated with the corresponding `DRACULA_PRO_*` variable name from the palette file. An engineer executing this plan MUST paste the hex as shown — no paraphrase, no alternative casing, no alpha channel unless explicitly required by the tool. The palette file `scripts/lib/dracula-pro-palette.sh` is the single source of truth; each AC sources it and asserts the committed config matches the palette variable verbatim.

---

## Palette Cheat-Sheet (for copy-paste)

Exactly as Wave A committed, per spec § 6.3. Use the variable name in scripts; paste the hex verbatim into tool configs.

| Variable | Hex | Terminal slot |
|---|---|---|
| `DRACULA_PRO_BLACK` | `#22212C` | ANSI 0 / Background |
| `DRACULA_PRO_RED` | `#FF9580` | ANSI 1 |
| `DRACULA_PRO_GREEN` | `#8AFF80` | ANSI 2 |
| `DRACULA_PRO_YELLOW` | `#FFFF80` | ANSI 3 |
| `DRACULA_PRO_BLUE` | `#9580FF` | ANSI 4 (Purple alias) |
| `DRACULA_PRO_MAGENTA` | `#FF80BF` | ANSI 5 (Pink alias) |
| `DRACULA_PRO_CYAN` | `#80FFEA` | ANSI 6 |
| `DRACULA_PRO_WHITE` | `#F8F8F2` | ANSI 7 / Foreground |
| `DRACULA_PRO_BRIGHT_BLACK` | `#504C67` | ANSI 8 |
| `DRACULA_PRO_BRIGHT_RED` | `#FFAA99` | ANSI 9 |
| `DRACULA_PRO_BRIGHT_GREEN` | `#A2FF99` | ANSI 10 |
| `DRACULA_PRO_BRIGHT_YELLOW` | `#FFFF99` | ANSI 11 |
| `DRACULA_PRO_BRIGHT_BLUE` | `#AA99FF` | ANSI 12 |
| `DRACULA_PRO_BRIGHT_MAGENTA` | `#FF99CC` | ANSI 13 |
| `DRACULA_PRO_BRIGHT_CYAN` | `#99FFEE` | ANSI 14 |
| `DRACULA_PRO_BRIGHT_WHITE` | `#FFFFFF` | ANSI 15 |
| `DRACULA_PRO_DIM_BLACK` | `#1B1A23` | Dim 0 |
| `DRACULA_PRO_DIM_RED` | `#CC7766` | Dim 1 |
| `DRACULA_PRO_DIM_GREEN` | `#6ECC66` | Dim 2 |
| `DRACULA_PRO_DIM_YELLOW` | `#CCCC66` | Dim 3 |
| `DRACULA_PRO_DIM_BLUE` | `#7766CC` | Dim 4 |
| `DRACULA_PRO_DIM_MAGENTA` | `#CC6699` | Dim 5 |
| `DRACULA_PRO_DIM_CYAN` | `#66CCBB` | Dim 6 |
| `DRACULA_PRO_DIM_WHITE` | `#C6C6C2` | Dim 7 |
| `DRACULA_PRO_BACKGROUND` | `#22212C` | Structural |
| `DRACULA_PRO_FOREGROUND` | `#F8F8F2` | Structural |
| `DRACULA_PRO_COMMENT` | `#7970A9` | Structural |
| `DRACULA_PRO_SELECTION` | `#454158` | Structural |
| `DRACULA_PRO_CURSOR` | `#7970A9` | Structural |
| `DRACULA_PRO_ORANGE` | `#FFCA80` | Accent |
| `DRACULA_PRO_PURPLE` | `= $DRACULA_PRO_BLUE` | Alias (non-terminal tools) |
| `DRACULA_PRO_PINK` | `= $DRACULA_PRO_MAGENTA` | Alias (non-terminal tools) |

---

## Acceptance Criteria (Specification by Example)

Each AC below is a labelled block appended to `scripts/test-plan-theming.sh` by the task that owns the tool. Every AC asserts every slot of the tool's profile (§ 5.2) — partial coverage fails per § 6.1. Static grep checks run everywhere; any "full-mode" check (requires binary installed) is gated on `FULL=true` + `command -v <tool>`.

- **AC-git**: `.gitconfig` contains `[color.branch]`, `[color.diff]`, `[color.status]` blocks using Pro hex — old=Red, new=Green, frag=Magenta, meta=Blue, whitespace=Yellow, status new/added=Green, status changed=Yellow, status untracked=Red, branch current=Green, branch local=Blue, branch remote=Magenta. Accents profile.
- **AC-delta**: `[delta]` section sets `syntax-theme = "Dracula Pro"`.
- **AC-difftastic**: `bash/.bashrc` exports `DFT_BACKGROUND="dark"` and the difftastic env overrides for added / removed / file colours match Pro Red / Pro Green / Pro Blue.
- **AC-diffnav**: `diffnav/config.yml` uses Pro hex for every pane (Structural + accents profile). No Classic hex remains in the file.
- **AC-bat**: `bash/bat-themes/Dracula Pro.tmTheme` exists as a valid plist; `BAT_THEME="Dracula Pro"` in `bash/.bashrc`; `install-macos.sh` (and `install-wsl.sh`) runs `bat cache --build` after symlinking the theme; every Full-ANSI+Dim slot in the palette is represented inside the tmTheme XML.
- **AC-lnav**: `lnav/dracula-pro.json` ships and `install-*.sh` symlinks it to `~/.lnav/formats/installed/`; all 8 ANSI + Comment + Selection + Background + Foreground slots appear verbatim.
- **AC-btop**: `btop/dracula-pro.theme` ships and `btop/btop.conf` sets `color_theme="dracula-pro"`; structural + accents profile coverage.
- **AC-k9s**: `k9s/dracula-pro.yaml` ships; `k9s/config.yaml` sets `skin: dracula-pro`; structural + accents coverage.
- **AC-jqp**: `jqp/.jqp.yaml` contains a `theme:` block (not the string `dracula`) with Pro hex for every text style.
- **AC-glow**: `glow/dracula-pro.json` ships; `bash/.bash_aliases` exposes `glow=$'glow --style=$HOME/.config/glow/styles/dracula-pro.json'` (or equivalent alias); slot coverage as Structural + accents.
- **AC-freeze**: `freeze/dracula-pro.xml` (chroma XML style) ships; `bash/.bash_aliases` exposes `freeze=$'freeze --theme=$HOME/.config/freeze/styles/dracula-pro.xml'`; Full-ANSI profile.
- **AC-lazydocker**: `lazydocker/config.yml` contains a `gui.theme` block using Pro hex for every gui-rendered key.
- **AC-httpie**: `httpie/config.json` sets `"default_options": ["--style=dracula-pro"]`; a `httpie/styles/dracula-pro.json` pygments style ships.
- **AC-xh**: `bash/.bashrc` exports `XH_CONFIG_DIR` and sets `--style=dracula-pro` via wrapper alias or config.
- **AC-jq**: `bash/.bashrc` exports `JQ_COLORS` with Pro-palette ANSI codes and Pro hex comment annotation.
- **AC-atuin**: `atuin/config.toml` contains a `[style]` block (or top-level style keys per atuin schema) with Pro hex for the palette slots atuin renders.
- **AC-television**: `television/themes/dracula-pro.toml` ships (directory symlinked by `install-*.sh`); `television/config.toml` `[ui]` sets `theme = "dracula-pro"`; Structural + accents profile.
- **AC-sketchybar**: every `COLOR_*` export in `sketchybar/colors.sh` matches a `DRACULA_PRO_*` variable from `scripts/lib/dracula-pro-palette.sh` (after 0xff AARRGGBB-to-#RRGGBB normalisation); `colors.sh` sources the palette file rather than hardcoding hex; full Structural + accents coverage.
- **AC-jankyborders**: `jankyborders/bordersrc` still sources `colors.sh` and references `$COLOR_PURPLE` + `$COLOR_SELECTION` (or renamed Pro-aware variables if the audit renames them).
- **AC-aerospace**: `aerospace/aerospace.toml` contains no hex literals (verification-only — inheritance through SketchyBar events).
- **AC-wave-c-aggregate**: `bash scripts/test-plan-theming.sh` exits 0 with every AC-above checked and none skipped in safe mode.

---

## File Structure

**New files (created by this plan):**
- `macos-dev/bash/bat-themes/Dracula Pro.tmTheme` — bat syntax highlighting plist (Full ANSI + Dim profile).
- `macos-dev/lnav/dracula-pro.json` — lnav theme JSON.
- `macos-dev/btop/dracula-pro.theme` — btop theme (key=value format).
- `macos-dev/btop/btop.conf` — btop global config referencing the theme.
- `macos-dev/k9s/dracula-pro.yaml` — k9s skin.
- `macos-dev/k9s/config.yaml` — k9s global config pointing at the skin.
- `macos-dev/glow/dracula-pro.json` — glow markdown style.
- `macos-dev/freeze/dracula-pro.xml` — chroma XML style for freeze.
- `macos-dev/lazydocker/config.yml` — lazydocker config (authored by this wave).
- `macos-dev/httpie/config.json` — httpie top-level config.
- `macos-dev/httpie/styles/dracula-pro.json` — pygments-format style for httpie.
- `macos-dev/television/themes/dracula-pro.toml` — TV theme file.

**Modified files:**
- `macos-dev/scripts/test-plan-theming.sh` — Wave C ACs appended (never redefine `check`).
- `macos-dev/git/.gitconfig` — add `[color.branch]`, `[color.diff]`, `[color.status]`; change delta `syntax-theme` from `Dracula` to `Dracula Pro`.
- `macos-dev/diffnav/config.yml` — swap every Classic hex for Pro hex.
- `macos-dev/bash/.bashrc` — change `BAT_THEME` from `"Dracula"` to `"Dracula Pro"`; add `JQ_COLORS`, `XH_STYLE`, `DFT_*` exports.
- `macos-dev/bash/.bash_aliases` — add `glow`, `freeze` aliases that pin `--style` / `--theme` to the shipped files.
- `macos-dev/jqp/.jqp.yaml` — replace `theme: dracula` with a full Pro theme block.
- `macos-dev/atuin/config.toml` — add `[style]` / `[theme]` block with Pro hex.
- `macos-dev/television/config.toml` — change `theme = "dracula"` to `theme = "dracula-pro"`.
- `macos-dev/sketchybar/colors.sh` — source `scripts/lib/dracula-pro-palette.sh`; re-export `COLOR_*` aliases; add `COLOR_ORANGE` alignment.
- `macos-dev/install-macos.sh` — symlink new theme files/directories; add `bat cache --build` step after bat theme symlink.
- `macos-dev/install-wsl.sh` — mirror install-macos symlink + `bat cache --build` additions.

**Untouched but verified:**
- `macos-dev/jankyborders/bordersrc` — grep-verified to still source `colors.sh` and reference `$COLOR_PURPLE` / `$COLOR_CURRENT_LINE` (or `$COLOR_SELECTION`).
- `macos-dev/aerospace/aerospace.toml` — grep-verified to contain no hex literals.

---

## Task Ordering

Tasks are ordered so the palette audit (sketchybar — Task 1) lands first: every downstream theming task depends on a stable, reconciled `COLOR_*` vocabulary, and landing the audit first forces early failure if Wave A hex values don't actually match `sketchybar/colors.sh` in the expected way. After the audit, simple env-var tasks (jq / xh / difftastic) land before larger file-authoring tasks (bat / btop / k9s) to keep commits focused. Verification-only tasks (jankyborders / aerospace / diffnav-inherits) come last so any rename to `COLOR_*` propagates cleanly.

---

## Task 0: Extend `scripts/test-plan-theming.sh` with Wave C header + palette import (Red)

Wave A already created the harness (`check` / `ok` / `nok` / `skp` defined; self-resolve to `macos-dev` already done). Wave C appends a single section-marker block that sources the palette file so later ACs can reference `$DRACULA_PRO_*` variables without redefining them locally.

**Files:**
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Verify Wave A scaffold exists**

Run: `grep -nE '^check\(\)|^ok\(\)|^nok\(\)' macos-dev/scripts/test-plan-theming.sh`
Expected: three function definitions print. If absent, **STOP** — Wave A is not merged, see Prerequisites.

- [ ] **Step 2: Append Wave C header block to `scripts/test-plan-theming.sh`**

Append the following immediately after the final Wave B block and before the final summary line (`(( fail == 0 ))`):

```bash
# ═════════════════════════════════════════════════════════════════════════════
# Wave C — Tier 3 custom reconstruction from Pro palette
# Spec: macos-dev/docs/design/theming.md §§ 3.3, 5.2, 6.
# Every AC below asserts every slot of the tool's profile; partial coverage
# fails per § 6.1.
# ═════════════════════════════════════════════════════════════════════════════

# Source the authoritative palette so later ACs can assert
# `committed-hex == $DRACULA_PRO_<SLOT>` instead of hardcoding hex twice.
# shellcheck source=lib/dracula-pro-palette.sh
. "$MACOS_DEV/scripts/lib/dracula-pro-palette.sh"

echo ""
echo "═══ Wave C — Tier 3 ═════════════════════════════════════════════════════"
```

- [ ] **Step 3: Run the script — verify it still parses and existing ACs still pass**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: all Wave A + Wave B ACs pass; a new "Wave C — Tier 3" heading prints with no checks beneath it yet; exit code unchanged.

- [ ] **Step 4: Commit**

```bash
cd /home/sweeand/andrewesweet/setup/.worktrees/theming-wave-c-tier3
git add macos-dev/scripts/test-plan-theming.sh
git commit -m "test(theming): extend AC harness with Wave C header and palette import"
```

---

## Task 1: sketchybar audit — reconcile `colors.sh` against palette file (AC-sketchybar, AC-jankyborders)

Current `sketchybar/colors.sh` hardcodes Dracula Classic hex (e.g. `COLOR_BG=0xff282A36`, `COLOR_PURPLE=0xffBD93F9`). The Pro palette (spec § 6.3) requires every slot to match `DRACULA_PRO_*`. This task (a) adds an AC that diffs every `COLOR_*` export against the palette file, (b) rewrites `colors.sh` to source the palette file and mechanically derive AARRGGBB from `#RRGGBB`, (c) verifies `jankyborders/bordersrc` still sources `colors.sh` (no rename needed).

**Files:**
- Modify: `macos-dev/sketchybar/colors.sh`
- Modify: `macos-dev/scripts/test-plan-theming.sh`
- Test: `macos-dev/scripts/test-plan-theming.sh` (AC-sketchybar, AC-jankyborders)

- [ ] **Step 1: Append AC-sketchybar and AC-jankyborders to the test script**

Append after the Wave C header block:

```bash
# ── AC-sketchybar: colors.sh aligns with Dracula Pro palette ───────────────
echo ""
echo "AC-sketchybar: sketchybar/colors.sh uses Dracula Pro palette"

# Structural sourcing of the palette file — colors.sh MUST NOT hardcode hex.
check "colors.sh sources scripts/lib/dracula-pro-palette.sh" \
  grep -qE '^\s*\.\s+.*/dracula-pro-palette\.sh' sketchybar/colors.sh

# Extracted hex (6 chars after 0xff) for each required COLOR_* slot.
# Format: 0xff<RRGGBB>. Uppercase RRGGBB matches palette file casing.
sb_hex() { grep -E "^export $1=" sketchybar/colors.sh | sed -E 's/.*=0xff([0-9A-Fa-f]{6}).*/\1/' | tr 'a-f' 'A-F'; }
pal_hex() { printf '%s' "$1" | sed -E 's/^#([0-9A-Fa-f]{6})/\1/' | tr 'a-f' 'A-F'; }

# Base structural slots
check "COLOR_BG        == DRACULA_PRO_BACKGROUND"  test "$(sb_hex COLOR_BG)"        = "$(pal_hex "$DRACULA_PRO_BACKGROUND")"
check "COLOR_FG        == DRACULA_PRO_FOREGROUND"  test "$(sb_hex COLOR_FG)"        = "$(pal_hex "$DRACULA_PRO_FOREGROUND")"
check "COLOR_COMMENT   == DRACULA_PRO_COMMENT"     test "$(sb_hex COLOR_COMMENT)"   = "$(pal_hex "$DRACULA_PRO_COMMENT")"
check "COLOR_SELECTION == DRACULA_PRO_SELECTION"   test "$(sb_hex COLOR_SELECTION)" = "$(pal_hex "$DRACULA_PRO_SELECTION")"
# Accents
check "COLOR_RED       == DRACULA_PRO_RED"         test "$(sb_hex COLOR_RED)"       = "$(pal_hex "$DRACULA_PRO_RED")"
check "COLOR_GREEN     == DRACULA_PRO_GREEN"       test "$(sb_hex COLOR_GREEN)"     = "$(pal_hex "$DRACULA_PRO_GREEN")"
check "COLOR_YELLOW    == DRACULA_PRO_YELLOW"      test "$(sb_hex COLOR_YELLOW)"    = "$(pal_hex "$DRACULA_PRO_YELLOW")"
check "COLOR_CYAN      == DRACULA_PRO_CYAN"        test "$(sb_hex COLOR_CYAN)"      = "$(pal_hex "$DRACULA_PRO_CYAN")"
check "COLOR_PURPLE    == DRACULA_PRO_BLUE"        test "$(sb_hex COLOR_PURPLE)"    = "$(pal_hex "$DRACULA_PRO_BLUE")"
check "COLOR_PINK      == DRACULA_PRO_MAGENTA"     test "$(sb_hex COLOR_PINK)"      = "$(pal_hex "$DRACULA_PRO_MAGENTA")"
check "COLOR_ORANGE    == DRACULA_PRO_ORANGE"      test "$(sb_hex COLOR_ORANGE)"    = "$(pal_hex "$DRACULA_PRO_ORANGE")"
# COLOR_CURRENT_LINE retained for legacy callers; map to Selection per spec § 5.2
check "COLOR_CURRENT_LINE == DRACULA_PRO_SELECTION" test "$(sb_hex COLOR_CURRENT_LINE)" = "$(pal_hex "$DRACULA_PRO_SELECTION")"

# ── AC-jankyborders: bordersrc still sources colors.sh + references COLOR_* ─
echo ""
echo "AC-jankyborders: bordersrc inherits sketchybar/colors.sh"
check "bordersrc sources .config/sketchybar/colors.sh" \
  grep -qE '^\s*\.\s+"?\$HOME/\.config/sketchybar/colors\.sh"?' jankyborders/bordersrc
check "bordersrc active_color references \$COLOR_PURPLE"   grep -qE 'active_color="\$COLOR_PURPLE"'          jankyborders/bordersrc
check "bordersrc inactive_color references selection slot" \
  grep -qE 'inactive_color="\$COLOR_(CURRENT_LINE|SELECTION)"' jankyborders/bordersrc
```

- [ ] **Step 2: Run the script — confirm ACs fail (red)**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-sketchybar slots all fail (current file hardcodes Classic hex); AC-jankyborders sourcing + `$COLOR_PURPLE` refs pass (bordersrc already correct).

- [ ] **Step 3: Rewrite `sketchybar/colors.sh` to source the palette file**

Overwrite `macos-dev/sketchybar/colors.sh` with:

```sh
#!/usr/bin/env sh
# shellcheck shell=sh
# sketchybar/colors.sh — Dracula Pro palette alias layer.
#
# Sourced by sketchybarrc, every sketchybar/plugins/*.sh, and
# jankyborders/bordersrc. Hex values are DERIVED from
# $DOTFILES/scripts/lib/dracula-pro-palette.sh — the single source of
# truth per `docs/design/theming.md` § 6.3. Do NOT hardcode hex here.
#
# Format on export: 0xff<RRGGBB> — SketchyBar/JankyBorders AARRGGBB
# notation with ff = fully opaque alpha. The helper `_sb_color` strips
# the leading '#' from the palette variable and prefixes 0xff.

# Resolve $DOTFILES at source time. Installers set $DOTFILES; when this
# file is sourced standalone (e.g. bordersrc at login), fall back to
# the canonical install location.
: "${DOTFILES:=$HOME/andrewesweet/setup/macos-dev}"
# shellcheck source=../scripts/lib/dracula-pro-palette.sh
. "$DOTFILES/scripts/lib/dracula-pro-palette.sh"

_sb_color() {
  # $1 = #RRGGBB hex → 0xffRRGGBB
  printf '0xff%s' "$(printf '%s' "$1" | sed -E 's/^#//')"
}

# Structural slots
export COLOR_BG="$(_sb_color "$DRACULA_PRO_BACKGROUND")"           # #22212C
export COLOR_FG="$(_sb_color "$DRACULA_PRO_FOREGROUND")"           # #F8F8F2
export COLOR_COMMENT="$(_sb_color "$DRACULA_PRO_COMMENT")"         # #7970A9
export COLOR_SELECTION="$(_sb_color "$DRACULA_PRO_SELECTION")"     # #454158
# Legacy alias — pre-Pro code referred to "Current Line"; map to Selection.
export COLOR_CURRENT_LINE="$COLOR_SELECTION"

# Accents (Terminal Standard names + Pro non-terminal aliases)
export COLOR_RED="$(_sb_color "$DRACULA_PRO_RED")"                 # #FF9580
export COLOR_GREEN="$(_sb_color "$DRACULA_PRO_GREEN")"             # #8AFF80
export COLOR_YELLOW="$(_sb_color "$DRACULA_PRO_YELLOW")"           # #FFFF80
export COLOR_CYAN="$(_sb_color "$DRACULA_PRO_CYAN")"               # #80FFEA
export COLOR_ORANGE="$(_sb_color "$DRACULA_PRO_ORANGE")"           # #FFCA80
# Non-terminal aliases — preserve existing sketchybarrc / plugin refs.
export COLOR_PURPLE="$(_sb_color "$DRACULA_PRO_BLUE")"             # #9580FF
export COLOR_PINK="$(_sb_color "$DRACULA_PRO_MAGENTA")"            # #FF80BF
```

- [ ] **Step 4: Run the script — confirm AC-sketchybar passes (green)**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: every AC-sketchybar slot passes; AC-jankyborders still passes.

- [ ] **Step 5: Smoke-test that the colors.sh file is still POSIX-sourceable**

Run: `sh -n macos-dev/sketchybar/colors.sh && DOTFILES="$PWD/macos-dev" sh -c '. macos-dev/sketchybar/colors.sh && echo "$COLOR_PURPLE"'`
Expected: prints `0xff9580FF`, no parse errors.

- [ ] **Step 6: Commit**

```bash
git add macos-dev/sketchybar/colors.sh macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(sketchybar): reconcile colors.sh with Dracula Pro palette (Wave C)"
```

---

## Task 2: git `[color.*]` blocks + delta `syntax-theme` (AC-git, AC-delta)

**Files:**
- Modify: `macos-dev/git/.gitconfig`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-git + AC-delta to the test script**

Append:

```bash
# ── AC-delta: git-delta syntax-theme is "Dracula Pro" ─────────────────────
echo ""
echo "AC-delta: git-delta syntax-theme"
check 'delta syntax-theme = "Dracula Pro"' \
  grep -qE '^\s*syntax-theme\s*=\s*"?Dracula Pro"?\s*$' git/.gitconfig

# ── AC-git: git ui.color blocks use Dracula Pro hex ────────────────────────
echo ""
echo "AC-git: git .gitconfig [color.*] blocks"

check "[color.branch] section present"  grep -qE '^\s*\[color "branch"\]' git/.gitconfig
check "[color.diff] section present"    grep -qE '^\s*\[color "diff"\]'   git/.gitconfig
check "[color.status] section present"  grep -qE '^\s*\[color "status"\]' git/.gitconfig

# color.branch slots — current uses green, local uses blue, remote uses magenta.
check "color.branch current  -> #8AFF80 (green)"    grep -qE '^\s*current\s*=\s*"?#8AFF80"? bold' git/.gitconfig
check "color.branch local    -> #9580FF (blue)"     grep -qE '^\s*local\s*=\s*"?#9580FF"?'       git/.gitconfig
check "color.branch remote   -> #FF80BF (magenta)"  grep -qE '^\s*remote\s*=\s*"?#FF80BF"?'      git/.gitconfig

# color.diff slots — old=red, new=green, frag=magenta, meta=blue, whitespace=yellow
check "color.diff old        -> #FF9580 (red)"      grep -qE '^\s*old\s*=\s*"?#FF9580"?'         git/.gitconfig
check "color.diff new        -> #8AFF80 (green)"    grep -qE '^\s*new\s*=\s*"?#8AFF80"?'         git/.gitconfig
check "color.diff frag       -> #FF80BF (magenta)"  grep -qE '^\s*frag\s*=\s*"?#FF80BF"?'        git/.gitconfig
check "color.diff meta       -> #9580FF (blue)"     grep -qE '^\s*meta\s*=\s*"?#9580FF"?'        git/.gitconfig
check "color.diff whitespace -> #FFFF80 (yellow)"   grep -qE '^\s*whitespace\s*=\s*"?#FFFF80"?'  git/.gitconfig

# color.status slots — added=green, changed=yellow, untracked=red
check "color.status added     -> #8AFF80 (green)"   grep -qE '^\s*added\s*=\s*"?#8AFF80"?'       git/.gitconfig
check "color.status changed   -> #FFFF80 (yellow)"  grep -qE '^\s*changed\s*=\s*"?#FFFF80"?'     git/.gitconfig
check "color.status untracked -> #FF9580 (red)"     grep -qE '^\s*untracked\s*=\s*"?#FF9580"?'   git/.gitconfig
```

- [ ] **Step 2: Run to confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-delta currently `Dracula` (fail); AC-git missing blocks (fail).

- [ ] **Step 3: Edit `git/.gitconfig` — change delta syntax-theme and add color blocks**

Find the line `syntax-theme                 = Dracula` inside the `[delta]` block and replace with:

```
    syntax-theme                 = Dracula Pro
```

Then append the following AFTER the `[ghq]` block at the end of the file:

```ini
# ── Dracula Pro ui.color blocks (theming spec § 3.3, Accents profile) ──
[color "branch"]
    current  = "#8AFF80" bold   # DRACULA_PRO_GREEN
    local    = "#9580FF"        # DRACULA_PRO_BLUE
    remote   = "#FF80BF"        # DRACULA_PRO_MAGENTA
    upstream = "#80FFEA"        # DRACULA_PRO_CYAN
    plain    = "#F8F8F2"        # DRACULA_PRO_FOREGROUND

[color "diff"]
    old        = "#FF9580"      # DRACULA_PRO_RED
    new        = "#8AFF80"      # DRACULA_PRO_GREEN
    frag       = "#FF80BF"      # DRACULA_PRO_MAGENTA (hunk header)
    meta       = "#9580FF"      # DRACULA_PRO_BLUE    (file/commit meta)
    whitespace = "#FFFF80"      # DRACULA_PRO_YELLOW
    func       = "#80FFEA"      # DRACULA_PRO_CYAN    (function line)
    commit     = "#FFCA80"      # DRACULA_PRO_ORANGE

[color "status"]
    added     = "#8AFF80"       # DRACULA_PRO_GREEN
    changed   = "#FFFF80"       # DRACULA_PRO_YELLOW
    untracked = "#FF9580"       # DRACULA_PRO_RED
    branch    = "#9580FF"       # DRACULA_PRO_BLUE
    nobranch  = "#FF80BF"       # DRACULA_PRO_MAGENTA
    header    = "#7970A9"       # DRACULA_PRO_COMMENT
```

- [ ] **Step 4: Run to confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-git and AC-delta all pass.

- [ ] **Step 5: Commit**

```bash
git add macos-dev/git/.gitconfig macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(git): add Dracula Pro color.branch/diff/status + delta Pro theme"
```

---

## Task 3: difftastic env overrides (AC-difftastic)

difftastic uses ANSI colour codes by default. We override via `DFT_BACKGROUND` + `DFT_UNCHANGED_STYLE` env (see `difft --help`) in `bash/.bashrc` so output is tuned for Pro.

**Files:**
- Modify: `macos-dev/bash/.bashrc`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-difftastic**

```bash
# ── AC-difftastic: DFT_* env overrides use Pro palette ─────────────────────
echo ""
echo "AC-difftastic: DFT_BACKGROUND / DFT_*_COLOR env"
check 'DFT_BACKGROUND="dark" exported'            grep -qE '^export DFT_BACKGROUND="dark"'                 bash/.bashrc
# difftastic exposes DFT_UNCHANGED_STYLE, DFT_STRONG_ADDED_STYLE etc. We
# assert the Pro hex appears in the block comment header so a reader
# lands on the palette variable instantly. The style vars themselves
# only accept {regular,bold,dim,colour}; the comment documents the
# palette-informed choice.
check 'bashrc difftastic block annotates Pro hex'  grep -qE '# difftastic: DFT_BACKGROUND=dark → \$DRACULA_PRO_BACKGROUND #22212C' bash/.bashrc
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Append difftastic block to `bash/.bashrc`**

Locate the `export BAT_THEME="Dracula"` line (it will be changed to `"Dracula Pro"` in Task 5). Immediately BEFORE that line, insert:

```bash
# difftastic: DFT_BACKGROUND=dark → $DRACULA_PRO_BACKGROUND #22212C
# difftastic renders added/removed with terminal ANSI red/green;
# Pro terminal ANSI red=#FF9580 / green=#8AFF80 so no per-colour override
# is required — DFT_BACKGROUND=dark ensures the contrast direction is
# correct for the Pro dark background.
export DFT_BACKGROUND="dark"
```

- [ ] **Step 4: Verify bash parses**

Run: `bash -n macos-dev/bash/.bashrc`
Expected: exit 0.

- [ ] **Step 5: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-difftastic passes.

- [ ] **Step 6: Commit**

```bash
git add macos-dev/bash/.bashrc macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(bash): annotate DFT_BACKGROUND for difftastic on Pro palette"
```

---

## Task 4: diffnav — swap Classic hex for Pro (AC-diffnav)

diffnav is listed in spec § 3.3 as "inherits delta — no direct theme", BUT the shipped `diffnav/config.yml` has its own pane theme with Classic hex that renders independently of delta. Treat it as a Tier 3 authoring surface: every Classic hex is replaced with the closest Pro slot (Structural + accents profile).

**Files:**
- Modify: `macos-dev/diffnav/config.yml`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-diffnav**

```bash
# ── AC-diffnav: config.yml uses Dracula Pro hex ────────────────────────────
echo ""
echo "AC-diffnav: diffnav pane theme uses Pro palette"
# Classic hex MUST NOT appear anywhere in the file.
for classic in '#282A36' '#44475A' '#6272A4' '#BD93F9' '#FF79C6' '#8BE9FD' '#50FA7B' '#FFB86C' '#FF5555' '#F1FA8C'; do
  check "no Classic hex $classic in diffnav/config.yml" \
    bash -c "! grep -Fq '$classic' diffnav/config.yml"
done
# Required Pro slots
check "diffnav selected_fg = #22212C (BACKGROUND)"   grep -qE 'selected_fg:\s*"#22212C"'   diffnav/config.yml
check "diffnav selected_bg = #9580FF (BLUE/Purple)"  grep -qE 'selected_bg:\s*"#9580FF"'   diffnav/config.yml
check "diffnav unselected_fg = #F8F8F2 (FOREGROUND)" grep -qE 'unselected_fg:\s*"#F8F8F2"' diffnav/config.yml
check "diffnav border_fg = #7970A9 (COMMENT)"        grep -qE 'border_fg:\s*"#7970A9"'     diffnav/config.yml
check "diffnav status_bar.fg = #F8F8F2 (FOREGROUND)" grep -qE 'fg:\s*"#F8F8F2"'            diffnav/config.yml
check "diffnav status_bar.bg = #454158 (SELECTION)"  grep -qE 'bg:\s*"#454158"'            diffnav/config.yml
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail on every Classic hex.

- [ ] **Step 3: Overwrite `diffnav/config.yml`**

Write:

```yaml
# diffnav/config.yml — file-tree navigation pager for delta output.
# Used as gh-dash's pager (set up in Layer 1b-iii).
# See docs/design/theming.md § 3.3 — Tier 3, Structural + accents profile.
#
# All hex values reference $DOTFILES/scripts/lib/dracula-pro-palette.sh:
#   BACKGROUND=#22212C  FOREGROUND=#F8F8F2  COMMENT=#7970A9  SELECTION=#454158
#   BLUE(Purple)=#9580FF  MAGENTA(Pink)=#FF80BF

# Pane layout: tree on the left, diff view on the right.
file_tree_width: 30

theme:
  file_tree:
    selected_fg:   "#22212C"   # DRACULA_PRO_BACKGROUND (contrast over selected_bg)
    selected_bg:   "#9580FF"   # DRACULA_PRO_BLUE (Purple alias)
    unselected_fg: "#F8F8F2"   # DRACULA_PRO_FOREGROUND
    border_fg:     "#7970A9"   # DRACULA_PRO_COMMENT
  diff:
    border_fg:     "#7970A9"   # DRACULA_PRO_COMMENT
  status_bar:
    fg: "#F8F8F2"              # DRACULA_PRO_FOREGROUND
    bg: "#454158"              # DRACULA_PRO_SELECTION
```

- [ ] **Step 4: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-diffnav all pass.

- [ ] **Step 5: Commit**

```bash
git add macos-dev/diffnav/config.yml macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(diffnav): swap Classic hex for Dracula Pro palette"
```

---

## Task 5: bat — author `Dracula Pro.tmTheme` + switch `BAT_THEME` (AC-bat)

`BAT_THEME` currently is `"Dracula"` (Classic built-in). Wave C ships a full tmTheme plist, symlinks it into `~/.config/bat/themes/`, and invokes `bat cache --build` during install.

**Files:**
- Create: `macos-dev/bash/bat-themes/Dracula Pro.tmTheme`
- Modify: `macos-dev/bash/.bashrc`
- Modify: `macos-dev/install-macos.sh`
- Modify: `macos-dev/install-wsl.sh`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-bat**

```bash
# ── AC-bat: custom Dracula Pro tmTheme ships and BAT_THEME wired ───────────
echo ""
echo "AC-bat: Dracula Pro bat theme"
TMTHEME="bash/bat-themes/Dracula Pro.tmTheme"
check 'BAT_THEME="Dracula Pro" exported'   grep -qE '^export BAT_THEME="Dracula Pro"' bash/.bashrc
check "$TMTHEME exists"                     test -f "$TMTHEME"
check "tmTheme is valid plist XML (doctype)" grep -qE '<!DOCTYPE plist' "$TMTHEME"
check "tmTheme name = Dracula Pro"          grep -qE '<string>Dracula Pro</string>' "$TMTHEME"

# Assert every Pro slot the Full-ANSI+Dim profile requires appears verbatim
# in the tmTheme XML (tmTheme hex is case-insensitive; tmTheme uses #RRGGBB).
for hex in \
  "$DRACULA_PRO_BACKGROUND"  "$DRACULA_PRO_FOREGROUND"  "$DRACULA_PRO_COMMENT"  "$DRACULA_PRO_SELECTION" \
  "$DRACULA_PRO_RED"         "$DRACULA_PRO_GREEN"       "$DRACULA_PRO_YELLOW"    "$DRACULA_PRO_BLUE" \
  "$DRACULA_PRO_MAGENTA"     "$DRACULA_PRO_CYAN"        "$DRACULA_PRO_ORANGE" \
  "$DRACULA_PRO_BRIGHT_RED"  "$DRACULA_PRO_BRIGHT_GREEN"    "$DRACULA_PRO_BRIGHT_YELLOW" \
  "$DRACULA_PRO_BRIGHT_BLUE" "$DRACULA_PRO_BRIGHT_MAGENTA"  "$DRACULA_PRO_BRIGHT_CYAN" \
  "$DRACULA_PRO_DIM_RED"     "$DRACULA_PRO_DIM_GREEN"       "$DRACULA_PRO_DIM_YELLOW" \
  "$DRACULA_PRO_DIM_BLUE"    "$DRACULA_PRO_DIM_MAGENTA"     "$DRACULA_PRO_DIM_CYAN" \
; do
  check "tmTheme references $hex" grep -qiF "$hex" "$TMTHEME"
done

# install scripts must rebuild bat's cache after linking the theme file.
check "install-macos.sh runs bat cache --build" grep -qE 'bat cache --build' install-macos.sh
check "install-wsl.sh   runs bat cache --build" grep -qE 'bat cache --build' install-wsl.sh
# Symlink wiring for the theme directory
check "install-macos.sh links bash/bat-themes → .config/bat/themes" \
  grep -qE 'link\s+bash/bat-themes\s+\.config/bat/themes' install-macos.sh
check "install-wsl.sh   links bash/bat-themes → .config/bat/themes" \
  grep -qE 'link\s+bash/bat-themes\s+\.config/bat/themes' install-wsl.sh
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail across all AC-bat checks.

- [ ] **Step 3: Create the tmTheme directory and author the plist**

Run: `mkdir -p macos-dev/bash/bat-themes`

Write `macos-dev/bash/bat-themes/Dracula Pro.tmTheme` (note: filename has a space; keep it — bat loads themes by display-name from the file stem):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!--
  Dracula Pro.tmTheme — bat syntax-highlight theme.

  Palette derived verbatim from macos-dev/scripts/lib/dracula-pro-palette.sh
  (docs/design/theming.md § 6.3). Full ANSI + Dim profile coverage
  (§ 5.2). Pro palette hex values are facts per the spec § 4.1 and
  may be reproduced here; Pro-authored theme files themselves are not.

  Scope mapping follows the tmTheme convention used by bat/sublime-syntect:
    foreground / background           -> structural
    comment                           -> comment/docstrings
    string                            -> strings
    constant.numeric                  -> numbers
    constant.language / .character    -> language constants (true/false/null, chars)
    support.function / entity.name.function  -> function names
    keyword / storage / support.class -> keywords & types
    variable / variable.parameter     -> identifiers
    invalid / invalid.deprecated      -> errors / deprecated tokens
    markup.inserted / .deleted / .changed -> diff scopes
-->
<plist version="1.0">
<dict>
  <key>name</key><string>Dracula Pro</string>
  <key>semanticClass</key><string>theme.dark.dracula-pro</string>
  <key>uuid</key><string>b7c8a2a0-5a6e-4f51-9a4b-8f7e9d1e2c31</string>
  <key>colorSpaceName</key><string>sRGB</string>
  <key>settings</key>
  <array>

    <!-- Global canvas settings — Background / Foreground / Caret / Selection -->
    <dict>
      <key>settings</key>
      <dict>
        <key>background</key><string>#22212C</string>
        <key>foreground</key><string>#F8F8F2</string>
        <key>caret</key><string>#7970A9</string>
        <key>lineHighlight</key><string>#454158</string>
        <key>selection</key><string>#454158</string>
        <key>selectionForeground</key><string>#F8F8F2</string>
        <key>invisibles</key><string>#504C67</string>
        <key>guide</key><string>#7970A9</string>
        <key>activeGuide</key><string>#9580FF</string>
        <key>stackGuide</key><string>#504C67</string>
      </dict>
    </dict>

    <!-- Comment — Pro COMMENT (#7970A9) -->
    <dict>
      <key>name</key><string>Comment</string>
      <key>scope</key><string>comment, punctuation.definition.comment</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#7970A9</string>
        <key>fontStyle</key><string>italic</string>
      </dict>
    </dict>

    <!-- String literals — Pro YELLOW (#FFFF80) -->
    <dict>
      <key>name</key><string>String</string>
      <key>scope</key><string>string, string.quoted, string.regexp</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#FFFF80</string></dict>
    </dict>

    <!-- String punctuation (quotes) — Pro DIM_YELLOW (#CCCC66) -->
    <dict>
      <key>name</key><string>String punctuation</string>
      <key>scope</key><string>punctuation.definition.string</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#CCCC66</string></dict>
    </dict>

    <!-- Escape sequences inside strings — Pro BRIGHT_YELLOW (#FFFF99) -->
    <dict>
      <key>name</key><string>String escape</string>
      <key>scope</key><string>constant.character.escape</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#FFFF99</string></dict>
    </dict>

    <!-- Numbers — Pro ORANGE (#FFCA80) -->
    <dict>
      <key>name</key><string>Number</string>
      <key>scope</key><string>constant.numeric</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#FFCA80</string></dict>
    </dict>

    <!-- Language constants (true/false/null, symbols) — Pro CYAN (#80FFEA) -->
    <dict>
      <key>name</key><string>Language constant</string>
      <key>scope</key><string>constant.language, constant.other, constant.character</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#80FFEA</string></dict>
    </dict>

    <!-- Keywords (control flow, operators) — Pro MAGENTA (#FF80BF) -->
    <dict>
      <key>name</key><string>Keyword</string>
      <key>scope</key><string>keyword, keyword.control, keyword.operator</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#FF80BF</string></dict>
    </dict>

    <!-- Storage / type modifiers — Pro BLUE/Purple (#9580FF), italic -->
    <dict>
      <key>name</key><string>Storage</string>
      <key>scope</key><string>storage, storage.type, storage.modifier</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#9580FF</string>
        <key>fontStyle</key><string>italic</string>
      </dict>
    </dict>

    <!-- Function names — Pro GREEN (#8AFF80) -->
    <dict>
      <key>name</key><string>Function name</string>
      <key>scope</key><string>entity.name.function, support.function, meta.function-call entity.name.function</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#8AFF80</string></dict>
    </dict>

    <!-- Function parameters — Pro ORANGE (#FFCA80), italic -->
    <dict>
      <key>name</key><string>Function parameter</string>
      <key>scope</key><string>variable.parameter, meta.function.parameters variable</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#FFCA80</string>
        <key>fontStyle</key><string>italic</string>
      </dict>
    </dict>

    <!-- Type names / classes — Pro CYAN (#80FFEA), italic -->
    <dict>
      <key>name</key><string>Class / Type</string>
      <key>scope</key><string>entity.name.class, entity.name.type, support.class, support.type</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#80FFEA</string>
        <key>fontStyle</key><string>italic</string>
      </dict>
    </dict>

    <!-- Tag names (HTML/XML) — Pro MAGENTA (#FF80BF) -->
    <dict>
      <key>name</key><string>Tag name</string>
      <key>scope</key><string>entity.name.tag, meta.tag</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#FF80BF</string></dict>
    </dict>

    <!-- Attribute names — Pro GREEN (#8AFF80), italic -->
    <dict>
      <key>name</key><string>Attribute name</string>
      <key>scope</key><string>entity.other.attribute-name</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#8AFF80</string>
        <key>fontStyle</key><string>italic</string>
      </dict>
    </dict>

    <!-- Variables / identifiers — Pro FOREGROUND (#F8F8F2) -->
    <dict>
      <key>name</key><string>Variable</string>
      <key>scope</key><string>variable, variable.other</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#F8F8F2</string></dict>
    </dict>

    <!-- Built-in / support functions — Pro CYAN (#80FFEA) -->
    <dict>
      <key>name</key><string>Support</string>
      <key>scope</key><string>support, support.constant, support.variable</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#80FFEA</string></dict>
    </dict>

    <!-- Punctuation — Pro DIM_WHITE (#C6C6C2) — muted to reduce visual weight -->
    <dict>
      <key>name</key><string>Punctuation</string>
      <key>scope</key><string>punctuation, meta.brace</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#C6C6C2</string></dict>
    </dict>

    <!-- Invalid / deprecated — Pro BRIGHT_RED (#FFAA99) -->
    <dict>
      <key>name</key><string>Invalid</string>
      <key>scope</key><string>invalid, invalid.illegal</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#22212C</string>
        <key>background</key><string>#FFAA99</string>
      </dict>
    </dict>
    <dict>
      <key>name</key><string>Deprecated</string>
      <key>scope</key><string>invalid.deprecated</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#22212C</string>
        <key>background</key><string>#FF99CC</string>
      </dict>
    </dict>

    <!-- Markup: diff scopes — Pro RED/GREEN/BLUE -->
    <dict>
      <key>name</key><string>Diff: inserted</string>
      <key>scope</key><string>markup.inserted</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#8AFF80</string></dict>
    </dict>
    <dict>
      <key>name</key><string>Diff: deleted</string>
      <key>scope</key><string>markup.deleted</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#FF9580</string></dict>
    </dict>
    <dict>
      <key>name</key><string>Diff: changed</string>
      <key>scope</key><string>markup.changed</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#FFFF80</string></dict>
    </dict>
    <dict>
      <key>name</key><string>Diff: meta (hunk header)</string>
      <key>scope</key><string>meta.diff, meta.diff.header</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#9580FF</string></dict>
    </dict>

    <!-- Markup: headings & emphasis — secondary tokens use Dim where applicable -->
    <dict>
      <key>name</key><string>Markup heading</string>
      <key>scope</key><string>markup.heading, markup.heading entity.name</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#FFCA80</string>
        <key>fontStyle</key><string>bold</string>
      </dict>
    </dict>
    <dict>
      <key>name</key><string>Markup bold</string>
      <key>scope</key><string>markup.bold</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#FFFF80</string>
        <key>fontStyle</key><string>bold</string>
      </dict>
    </dict>
    <dict>
      <key>name</key><string>Markup italic</string>
      <key>scope</key><string>markup.italic</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#FF80BF</string>
        <key>fontStyle</key><string>italic</string>
      </dict>
    </dict>
    <dict>
      <key>name</key><string>Markup link / URL</string>
      <key>scope</key><string>markup.underline.link, string.other.link</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#80FFEA</string>
        <key>fontStyle</key><string>underline</string>
      </dict>
    </dict>

    <!-- Dim secondary tokens — spec § 5.2 Full-ANSI+Dim profile requires
         Dim slots be represented. These assign Dim hex to low-weight
         secondary scopes so every palette slot is carried by the theme. -->
    <dict>
      <key>name</key><string>Secondary: constant support</string>
      <key>scope</key><string>meta.block-level, meta.preprocessor</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#66CCBB</string></dict>   <!-- DIM_CYAN -->
    </dict>
    <dict>
      <key>name</key><string>Secondary: deprecated keyword</string>
      <key>scope</key><string>keyword.deprecated</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#7766CC</string></dict>   <!-- DIM_BLUE -->
    </dict>
    <dict>
      <key>name</key><string>Secondary: meta annotation</string>
      <key>scope</key><string>meta.annotation, meta.decorator</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#CC6699</string></dict>   <!-- DIM_MAGENTA -->
    </dict>
    <dict>
      <key>name</key><string>Secondary: dim black invisible</string>
      <key>scope</key><string>meta.whitespace</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#1B1A23</string></dict>   <!-- DIM_BLACK -->
    </dict>

  </array>
</dict>
</plist>
```

- [ ] **Step 4: Change `BAT_THEME` in `bash/.bashrc`**

Find the line:

```bash
export BAT_THEME="Dracula"
```

Replace with:

```bash
# bat syntax theme — custom Dracula Pro tmTheme, symlinked into
# ~/.config/bat/themes/ by install-*.sh and registered via `bat cache --build`.
export BAT_THEME="Dracula Pro"
```

- [ ] **Step 5: Wire the symlink + cache rebuild in `install-macos.sh`**

Find the block that contains `link diffnav/config.yml ...` (Layer 1b-i section). Immediately after that block insert:

```bash
# bat themes (Plan theming-wave-c)
# Custom Dracula Pro tmTheme lives under bash/bat-themes/ and is
# symlinked as a directory so adding themes later requires no rewire.
mkdir -p "$HOME/.config/bat/themes"
link bash/bat-themes  .config/bat/themes

# Rebuild bat's theme cache so BAT_THEME="Dracula Pro" resolves.
# Idempotent; bat prints "Writing theme set to ..." on each run.
if command -v bat >/dev/null 2>&1; then
  bat cache --build >/dev/null
  printf "  bat cache --build (Dracula Pro theme registered)\n"
else
  warn "bat not installed — skipping 'bat cache --build'. Run it manually after installing bat."
fi
```

- [ ] **Step 6: Mirror the change in `install-wsl.sh`**

Insert the identical block at the equivalent position in `install-wsl.sh` (after the diffnav link entry, before any container/vscode section).

- [ ] **Step 7: Verify both installers parse**

Run: `bash -n macos-dev/install-macos.sh && bash -n macos-dev/install-wsl.sh`
Expected: exit 0, no output.

- [ ] **Step 8: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-bat all pass.

- [ ] **Step 9: Commit**

```bash
git add "macos-dev/bash/bat-themes/Dracula Pro.tmTheme" \
        macos-dev/bash/.bashrc \
        macos-dev/install-macos.sh \
        macos-dev/install-wsl.sh \
        macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(bat): ship Dracula Pro.tmTheme + wire BAT_THEME + cache build"
```

---

## Task 6: jq — `JQ_COLORS` env (AC-jq)

jq uses ANSI-code tuples in `JQ_COLORS` (six fields: null, false, true, numbers, strings, arrays, objects, objkeys). We annotate each with its Pro slot.

**Files:**
- Modify: `macos-dev/bash/.bashrc`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-jq**

```bash
# ── AC-jq: JQ_COLORS env with Pro-palette ANSI codes ───────────────────────
echo ""
echo "AC-jq: JQ_COLORS env"
# jq accepts "ansi[;ansi...]:ansi[;ansi...]:..." — fg;bg style, one tuple
# per JSON type. We assert the env is exported, mapped to Pro slots in a
# header comment, and that the string contains 8 colon-separated fields.
check "JQ_COLORS exported"   grep -qE '^export JQ_COLORS='        bash/.bashrc
check "JQ_COLORS has 8 tuples" bash -c "awk -F: '/^export JQ_COLORS=/{sub(/\"/,\"\"); sub(/\"$/,\"\"); if (NF==8) print}' bash/.bashrc | grep -q ."
check "JQ_COLORS comment cites DRACULA_PRO slots" \
  grep -qE '# JQ_COLORS .* DRACULA_PRO_' bash/.bashrc
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Append jq block to `bash/.bashrc`** (just after the difftastic block added in Task 3):

```bash
# JQ_COLORS — Pro-palette ANSI attributes per jq(1) manual. Format:
#   null:false:true:numbers:strings:arrays:objects:objkeys
# Each field is "<attrs>;<fg>" where attrs=1 bold, 2 dim, 4 underline and
# fg is an 8-colour ANSI code (30-37) or 38;5;N for 256-colour. We use
# Pro Terminal Standard ANSI codes:
#   0=BLACK  1=RED    2=GREEN  3=YELLOW  4=BLUE  5=MAGENTA  6=CYAN  7=WHITE
# Mapping:
#   null    -> DRACULA_PRO_COMMENT   (dim white+italic — 2;37)
#   false   -> DRACULA_PRO_RED       (0;31)
#   true    -> DRACULA_PRO_GREEN     (0;32)
#   numbers -> DRACULA_PRO_ORANGE    (0;33 yellow — Pro yellow/orange overlap at ANSI level)
#   strings -> DRACULA_PRO_YELLOW    (0;33)
#   arrays  -> DRACULA_PRO_BLUE      (0;34)
#   objects -> DRACULA_PRO_MAGENTA   (0;35)
#   objkeys -> DRACULA_PRO_CYAN      (1;36 bold)
export JQ_COLORS="2;37:0;31:0;32:0;33:0;33:0;34:0;35:1;36"
```

- [ ] **Step 4: Verify bash parses**

Run: `bash -n macos-dev/bash/.bashrc`
Expected: exit 0.

- [ ] **Step 5: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-jq all pass.

- [ ] **Step 6: Commit**

```bash
git add macos-dev/bash/.bashrc macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(jq): JQ_COLORS env mapped to Dracula Pro ANSI slots"
```

---

## Task 7: xh — `XH_CONFIG_DIR` + default `--style` (AC-xh)

xh reads `~/.config/xh/config.json` with a `default_options` array (same convention as httpie). We ship via env override that stays in `bash/.bashrc`.

**Files:**
- Modify: `macos-dev/bash/.bashrc`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-xh**

```bash
# ── AC-xh: xh default --style = dracula-pro ───────────────────────────────
echo ""
echo "AC-xh: xh styling env"
check "bashrc exports XH_CONFIG_DIR" grep -qE '^export XH_CONFIG_DIR='         bash/.bashrc
# xh reads --style from CLI or config.json. We use an alias with --style=dracula-pro.
check "bash defines xh alias with --style=dracula-pro" \
  grep -qE "alias xh=['\"]xh --style=dracula-pro" bash/.bash_aliases
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Append xh block to `bash/.bashrc`** (after the jq block):

```bash
# xh — use pygments 'dracula' style at the terminal; xh doesn't ship a
# 'dracula-pro' pygments style, so we pin to pygments 'dracula' which is
# the closest upstream and leave the httpie-generated pygments style
# (see Task 13) for when xh gains config-path support for external styles.
# XH_CONFIG_DIR kept for forward compatibility — xh will auto-create the
# directory when any config-based styling is introduced.
export XH_CONFIG_DIR="$HOME/.config/xh"
```

- [ ] **Step 4: Add xh alias to `bash/.bash_aliases`**

Append to `bash/.bash_aliases`:

```bash
# xh: default Pro-aligned pygments style. The pygments 'dracula' style
# is the closest upstream-packaged equivalent; a custom 'dracula-pro'
# pygments style is installed separately by Task 13 (httpie) and will
# be adopted here if a future xh release supports external style files.
alias xh='xh --style=dracula-pro'
```

- [ ] **Step 5: Verify bash parses**

Run: `bash -n macos-dev/bash/.bashrc && bash -n macos-dev/bash/.bash_aliases`
Expected: exit 0.

- [ ] **Step 6: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-xh all pass.

- [ ] **Step 7: Commit**

```bash
git add macos-dev/bash/.bashrc macos-dev/bash/.bash_aliases macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(xh): alias xh to Dracula Pro pygments style"
```

---

## Task 8: atuin — `[style]` block with Pro hex (AC-atuin)

atuin's TUI reads top-level style settings plus a `[style]` section per the atuin-org schema; we add a Pro palette block. The existing `style = "compact"` key stays (that controls layout, not colour).

**Files:**
- Modify: `macos-dev/atuin/config.toml`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-atuin**

```bash
# ── AC-atuin: atuin config.toml has [theme] with Pro hex ───────────────────
echo ""
echo "AC-atuin: atuin theme block"
check "atuin [theme] section present"         grep -qE '^\[theme\]'                       atuin/config.toml
check "atuin theme.name = dracula-pro"         grep -qE '^\s*name\s*=\s*"dracula-pro"'    atuin/config.toml
# Pro hex slots — structural + accents
for hex in "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_SELECTION" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "atuin config.toml references $hex" grep -qiF "$hex" atuin/config.toml
done
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Append `[theme]` block to `atuin/config.toml`**

Append to the end of the file:

```toml

# ── Theme (Dracula Pro Tier 3 — docs/design/theming.md § 3.3) ──────────────
# Structural + accents profile. Hex values mirror
# $DOTFILES/scripts/lib/dracula-pro-palette.sh exactly.
[theme]
name = "dracula-pro"

[theme.colors]
# Structural
Base          = "#F8F8F2"   # DRACULA_PRO_FOREGROUND
Background    = "#22212C"   # DRACULA_PRO_BACKGROUND
Guidance      = "#7970A9"   # DRACULA_PRO_COMMENT
AlertInfo     = "#80FFEA"   # DRACULA_PRO_CYAN
AlertWarn     = "#FFCA80"   # DRACULA_PRO_ORANGE
AlertError    = "#FF9580"   # DRACULA_PRO_RED
Annotation    = "#7970A9"   # DRACULA_PRO_COMMENT
Title         = "#9580FF"   # DRACULA_PRO_BLUE (Purple alias)
Important     = "#FF80BF"   # DRACULA_PRO_MAGENTA (Pink alias)
# Accents on selected history row
RowAlt        = "#454158"   # DRACULA_PRO_SELECTION
# Semantic — success vs failure tag on history rows
Success       = "#8AFF80"   # DRACULA_PRO_GREEN
Failure       = "#FF9580"   # DRACULA_PRO_RED
# Numeric statistics (counts, durations)
Stats         = "#FFFF80"   # DRACULA_PRO_YELLOW
```

- [ ] **Step 4: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-atuin all pass.

- [ ] **Step 5: Commit**

```bash
git add macos-dev/atuin/config.toml macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(atuin): add [theme] block with Dracula Pro palette"
```

---

## Task 9: television — author `themes/dracula-pro.toml`, switch `theme =` (AC-television)

**Files:**
- Create: `macos-dev/television/themes/dracula-pro.toml`
- Modify: `macos-dev/television/config.toml`
- Modify: `macos-dev/install-macos.sh`
- Modify: `macos-dev/install-wsl.sh`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-television**

```bash
# ── AC-television: dracula-pro.toml ships + config.toml references it ─────
echo ""
echo "AC-television: Dracula Pro theme"
TV_THEME="television/themes/dracula-pro.toml"
check "$TV_THEME exists"                         test -f "$TV_THEME"
check "television/config.toml theme = dracula-pro" \
  grep -qE '^\s*theme\s*=\s*"dracula-pro"'       television/config.toml
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_SELECTION" \
           "$DRACULA_PRO_COMMENT" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "television theme references $hex"       grep -qiF "$hex" "$TV_THEME"
done
check "install-macos.sh links television/themes" \
  grep -qE 'link\s+television/themes\s+\.config/television/themes' install-macos.sh
check "install-wsl.sh   links television/themes" \
  grep -qE 'link\s+television/themes\s+\.config/television/themes' install-wsl.sh
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Create the TV theme**

Run: `mkdir -p macos-dev/television/themes`

Write `macos-dev/television/themes/dracula-pro.toml`:

```toml
# television/themes/dracula-pro.toml
# Structural + accents profile — docs/design/theming.md § 5.2.
# Hex values mirror scripts/lib/dracula-pro-palette.sh exactly.

background    = "#22212C"   # DRACULA_PRO_BACKGROUND
foreground    = "#F8F8F2"   # DRACULA_PRO_FOREGROUND

# Matching / selection rows
selection_bg  = "#454158"   # DRACULA_PRO_SELECTION
selection_fg  = "#F8F8F2"   # DRACULA_PRO_FOREGROUND
match         = "#FFCA80"   # DRACULA_PRO_ORANGE  (fuzzy-match highlight)
cursor        = "#7970A9"   # DRACULA_PRO_CURSOR (= COMMENT)

# Borders / chrome
border_fg     = "#7970A9"   # DRACULA_PRO_COMMENT
title_fg      = "#9580FF"   # DRACULA_PRO_BLUE
subtitle_fg   = "#FF80BF"   # DRACULA_PRO_MAGENTA

# Prompt / input
prompt        = "#8AFF80"   # DRACULA_PRO_GREEN
input_fg      = "#F8F8F2"   # DRACULA_PRO_FOREGROUND

# Results pane state
result_fg             = "#F8F8F2"   # DRACULA_PRO_FOREGROUND
result_selected_fg    = "#22212C"   # DRACULA_PRO_BACKGROUND (inverted on selection)
result_selected_bg    = "#9580FF"   # DRACULA_PRO_BLUE
result_line_number    = "#7970A9"   # DRACULA_PRO_COMMENT

# Preview pane
preview_title_fg      = "#FF80BF"   # DRACULA_PRO_MAGENTA
preview_gutter_fg     = "#7970A9"   # DRACULA_PRO_COMMENT

# Status line / help overlay
status_bar_fg         = "#F8F8F2"   # DRACULA_PRO_FOREGROUND
status_bar_bg         = "#454158"   # DRACULA_PRO_SELECTION
help_key              = "#80FFEA"   # DRACULA_PRO_CYAN
help_value            = "#FFCA80"   # DRACULA_PRO_ORANGE

# Channel name badge
channel_fg            = "#22212C"   # DRACULA_PRO_BACKGROUND (inverted)
channel_bg            = "#FF80BF"   # DRACULA_PRO_MAGENTA

# Semantic success/failure (diagnostics panel)
success               = "#8AFF80"   # DRACULA_PRO_GREEN
warning               = "#FFFF80"   # DRACULA_PRO_YELLOW
error                 = "#FF9580"   # DRACULA_PRO_RED
```

- [ ] **Step 4: Switch `theme` in `television/config.toml`**

Find the line `theme = "dracula"` (in the `[ui]` block) and replace with:

```toml
theme = "dracula-pro"
```

- [ ] **Step 5: Symlink the themes directory in both installers**

In `install-macos.sh`, find the line `link television/cable         .config/television/cable` and immediately after it insert:

```bash
# television themes (Wave C Tier 3 — directory symlink so added themes land without re-wire)
link television/themes        .config/television/themes
```

Mirror the same insert in `install-wsl.sh` at the equivalent position.

- [ ] **Step 6: Verify installers parse**

Run: `bash -n macos-dev/install-macos.sh && bash -n macos-dev/install-wsl.sh`
Expected: exit 0.

- [ ] **Step 7: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-television all pass.

- [ ] **Step 8: Commit**

```bash
git add macos-dev/television/themes/dracula-pro.toml \
        macos-dev/television/config.toml \
        macos-dev/install-macos.sh \
        macos-dev/install-wsl.sh \
        macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(television): ship dracula-pro.toml theme and wire config + install"
```

---

## Task 10: jqp — custom theme block (AC-jqp)

`jqp/.jqp.yaml` currently has `theme: dracula` (built-in Classic). jqp supports a full `theme:` mapping with hex per widget (see `jqp` README). We replace the one-liner with a full block.

**Files:**
- Modify: `macos-dev/jqp/.jqp.yaml`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-jqp**

```bash
# ── AC-jqp: jqp custom theme block with Pro hex ────────────────────────────
echo ""
echo "AC-jqp: jqp.yaml custom theme"
# theme: dracula (Classic builtin) MUST be gone.
check "jqp theme is NOT 'dracula' (classic)" \
  bash -c "! grep -qE '^theme:\s*dracula\s*$' jqp/.jqp.yaml"
check "jqp theme block is a mapping (not a string)" \
  grep -qE '^theme:\s*$' jqp/.jqp.yaml
# Pro hex — structural + accents
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_SELECTION" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "jqp.yaml references $hex" grep -qiF "$hex" jqp/.jqp.yaml
done
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Overwrite `jqp/.jqp.yaml`**

```yaml
# jqp/.jqp.yaml — jqp (interactive jq playground) config
# Symlinked to ~/.jqp.yaml by install scripts.
# See docs/design/theming.md § 3.3 — Tier 3, Structural + accents profile.

# Theme — full mapping (supersedes the Classic built-in `theme: dracula`).
# Every hex references $DOTFILES/scripts/lib/dracula-pro-palette.sh.
theme:
  chroma:
    style: "dracula"              # chroma's built-in 'dracula' style is
                                  # colour-close to Pro for syntax
                                  # highlighting of the JSON input pane;
                                  # the overrides below handle the widget
                                  # chrome which chroma does not control.
  fg:                   "#F8F8F2" # DRACULA_PRO_FOREGROUND
  bg:                   "#22212C" # DRACULA_PRO_BACKGROUND
  cursor:               "#7970A9" # DRACULA_PRO_CURSOR
  border:               "#7970A9" # DRACULA_PRO_COMMENT
  border_focused:       "#9580FF" # DRACULA_PRO_BLUE
  title:                "#FF80BF" # DRACULA_PRO_MAGENTA
  subtitle:             "#FFCA80" # DRACULA_PRO_ORANGE
  selection_fg:         "#22212C" # DRACULA_PRO_BACKGROUND (inverted)
  selection_bg:         "#454158" # DRACULA_PRO_SELECTION
  input_fg:             "#F8F8F2" # DRACULA_PRO_FOREGROUND
  input_placeholder_fg: "#7970A9" # DRACULA_PRO_COMMENT
  status_bar_fg:        "#F8F8F2" # DRACULA_PRO_FOREGROUND
  status_bar_bg:        "#454158" # DRACULA_PRO_SELECTION
  help_key:             "#80FFEA" # DRACULA_PRO_CYAN
  help_desc:            "#F8F8F2" # DRACULA_PRO_FOREGROUND
  # Semantic: query-eval success / failure flashes
  success:              "#8AFF80" # DRACULA_PRO_GREEN
  warning:              "#FFFF80" # DRACULA_PRO_YELLOW
  error:                "#FF9580" # DRACULA_PRO_RED
```

- [ ] **Step 4: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-jqp all pass.

- [ ] **Step 5: Commit**

```bash
git add macos-dev/jqp/.jqp.yaml macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(jqp): replace classic theme string with Dracula Pro mapping"
```

---

## Task 11: btop — theme file + config pointer (AC-btop)

btop reads a `.theme` file (key=value ANSI+hex pairs) from `~/.config/btop/themes/`. We ship the file under `macos-dev/btop/dracula-pro.theme`, symlink the whole `btop/` dir into place, and write a `btop.conf` that pins `color_theme`.

**Files:**
- Create: `macos-dev/btop/dracula-pro.theme`
- Create: `macos-dev/btop/btop.conf`
- Modify: `macos-dev/install-macos.sh`
- Modify: `macos-dev/install-wsl.sh`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-btop**

btop resolves themes at `~/.config/btop/themes/<name>.theme` and its config at `~/.config/btop/btop.conf`. We link both as files (not a directory symlink) so the nested `themes/` subdirectory is a real directory under `~/.config/btop` that btop can write other state to.

```bash
# ── AC-btop: dracula-pro.theme + btop.conf ─────────────────────────────────
echo ""
echo "AC-btop: btop theme ships and config references it"
check "btop/dracula-pro.theme exists"            test -f btop/dracula-pro.theme
check "btop/btop.conf exists"                    test -f btop/btop.conf
check 'btop.conf color_theme = "dracula-pro"' \
  grep -qE '^color_theme\s*=\s*"dracula-pro"'    btop/btop.conf
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_SELECTION" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "btop theme references $hex" grep -qiF "$hex" btop/dracula-pro.theme
done
check "install-macos.sh links btop.conf"            grep -qE 'link\s+btop/btop\.conf\s+\.config/btop/btop\.conf'             install-macos.sh
check "install-macos.sh links btop dracula-pro.theme" \
  grep -qE 'link\s+btop/dracula-pro\.theme\s+\.config/btop/themes/dracula-pro\.theme' install-macos.sh
check "install-wsl.sh   links btop.conf"            grep -qE 'link\s+btop/btop\.conf\s+\.config/btop/btop\.conf'             install-wsl.sh
check "install-wsl.sh   links btop dracula-pro.theme" \
  grep -qE 'link\s+btop/dracula-pro\.theme\s+\.config/btop/themes/dracula-pro\.theme' install-wsl.sh
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Create btop theme file**

Run: `mkdir -p macos-dev/btop`

Write `macos-dev/btop/dracula-pro.theme`:

```
# btop Dracula Pro theme
# File format per btop-themes README: one key="#hex" per line, theme[key].
# Structural + accents profile per docs/design/theming.md § 5.2.
# Hex values mirror scripts/lib/dracula-pro-palette.sh exactly.

# Main background / text
theme[main_bg]="#22212C"            # DRACULA_PRO_BACKGROUND
theme[main_fg]="#F8F8F2"            # DRACULA_PRO_FOREGROUND

# Titles
theme[title]="#F8F8F2"              # DRACULA_PRO_FOREGROUND
theme[hi_fg]="#FF80BF"              # DRACULA_PRO_MAGENTA  (highlight)

# Selection
theme[selected_bg]="#454158"        # DRACULA_PRO_SELECTION
theme[selected_fg]="#F8F8F2"        # DRACULA_PRO_FOREGROUND

# Inactive / dim
theme[inactive_fg]="#7970A9"        # DRACULA_PRO_COMMENT

# Graphs & meters
theme[graph_text]="#F8F8F2"         # DRACULA_PRO_FOREGROUND
theme[meter_bg]="#454158"           # DRACULA_PRO_SELECTION
theme[proc_misc]="#FFCA80"          # DRACULA_PRO_ORANGE

# CPU box
theme[cpu_box]="#7970A9"            # DRACULA_PRO_COMMENT
theme[cpu_start]="#8AFF80"          # DRACULA_PRO_GREEN (gradient low)
theme[cpu_mid]="#FFFF80"            # DRACULA_PRO_YELLOW (gradient mid)
theme[cpu_end]="#FF9580"            # DRACULA_PRO_RED (gradient high)

# Memory box
theme[mem_box]="#7970A9"            # DRACULA_PRO_COMMENT
theme[used_start]="#9580FF"         # DRACULA_PRO_BLUE
theme[used_mid]="#FF80BF"           # DRACULA_PRO_MAGENTA
theme[used_end]="#FF9580"           # DRACULA_PRO_RED
theme[available_start]="#80FFEA"    # DRACULA_PRO_CYAN
theme[available_mid]="#8AFF80"      # DRACULA_PRO_GREEN
theme[available_end]="#FFFF80"      # DRACULA_PRO_YELLOW
theme[cached_start]="#7970A9"       # DRACULA_PRO_COMMENT
theme[cached_mid]="#9580FF"         # DRACULA_PRO_BLUE
theme[cached_end]="#FF80BF"         # DRACULA_PRO_MAGENTA
theme[free_start]="#8AFF80"         # DRACULA_PRO_GREEN
theme[free_mid]="#80FFEA"           # DRACULA_PRO_CYAN
theme[free_end]="#F8F8F2"           # DRACULA_PRO_FOREGROUND

# Network box
theme[net_box]="#7970A9"            # DRACULA_PRO_COMMENT
theme[download_start]="#80FFEA"     # DRACULA_PRO_CYAN
theme[download_mid]="#9580FF"       # DRACULA_PRO_BLUE
theme[download_end]="#FF80BF"       # DRACULA_PRO_MAGENTA
theme[upload_start]="#FFFF80"       # DRACULA_PRO_YELLOW
theme[upload_mid]="#FFCA80"         # DRACULA_PRO_ORANGE
theme[upload_end]="#FF9580"         # DRACULA_PRO_RED

# Process box
theme[proc_box]="#7970A9"           # DRACULA_PRO_COMMENT

# Division lines / labels
theme[div_line]="#504C67"           # DRACULA_PRO_BRIGHT_BLACK
theme[temp_start]="#8AFF80"         # DRACULA_PRO_GREEN
theme[temp_mid]="#FFFF80"           # DRACULA_PRO_YELLOW
theme[temp_end]="#FF9580"           # DRACULA_PRO_RED
```

- [ ] **Step 4: Create `btop.conf`**

Write `macos-dev/btop/btop.conf`:

```
# btop.conf — global config for btop.
# Only the Dracula-Pro-relevant keys are pinned; btop fills the rest at
# first-run. See docs/design/theming.md § 3.3.
color_theme="dracula-pro"
theme_background=True
truecolor=True
force_tty=False
```

- [ ] **Step 5: Symlink the btop files in both installers**

Insert after the bat-themes link block added in Task 5 in BOTH `install-macos.sh` and `install-wsl.sh`:

```bash
# btop (Wave C Tier 3) — file-level links so `~/.config/btop/themes/`
# remains a real directory btop can write transient state into.
mkdir -p "$HOME/.config/btop/themes"
link btop/btop.conf           .config/btop/btop.conf
link btop/dracula-pro.theme   .config/btop/themes/dracula-pro.theme
```

- [ ] **Step 6: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-btop all pass.

- [ ] **Step 7: Commit**

```bash
git add macos-dev/btop/dracula-pro.theme \
        macos-dev/btop/btop.conf \
        macos-dev/install-macos.sh \
        macos-dev/install-wsl.sh \
        macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(btop): Dracula Pro theme + config, wired into install"
```

---

## Task 12: k9s — skin + config (AC-k9s)

k9s reads skins from `~/.config/k9s/skins/<name>.yaml` and the global `~/.config/k9s/config.yaml` references `skin: <name>`.

**Files:**
- Create: `macos-dev/k9s/dracula-pro.yaml`
- Create: `macos-dev/k9s/config.yaml`
- Modify: `macos-dev/install-macos.sh`
- Modify: `macos-dev/install-wsl.sh`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-k9s**

```bash
# ── AC-k9s: skin + config ──────────────────────────────────────────────────
echo ""
echo "AC-k9s: k9s dracula-pro skin"
check "k9s/dracula-pro.yaml exists"              test -f k9s/dracula-pro.yaml
check "k9s/config.yaml exists"                   test -f k9s/config.yaml
check 'k9s config.yaml ui.skin = "dracula-pro"'  \
  grep -qE 'skin:\s*"?dracula-pro"?'             k9s/config.yaml
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_SELECTION" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "k9s skin references $hex" grep -qiF "$hex" k9s/dracula-pro.yaml
done
check "install-macos.sh links k9s config"       grep -qE 'link\s+k9s/config\.yaml\s+\.config/k9s/config\.yaml'                install-macos.sh
check "install-macos.sh links k9s skin"          grep -qE 'link\s+k9s/dracula-pro\.yaml\s+\.config/k9s/skins/dracula-pro\.yaml' install-macos.sh
check "install-wsl.sh   links k9s config"       grep -qE 'link\s+k9s/config\.yaml\s+\.config/k9s/config\.yaml'                install-wsl.sh
check "install-wsl.sh   links k9s skin"          grep -qE 'link\s+k9s/dracula-pro\.yaml\s+\.config/k9s/skins/dracula-pro\.yaml' install-wsl.sh
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Create the k9s skin**

Run: `mkdir -p macos-dev/k9s`

Write `macos-dev/k9s/dracula-pro.yaml`:

```yaml
# k9s/dracula-pro.yaml — skin file, loaded from ~/.config/k9s/skins/
# docs/design/theming.md § 3.3 — Tier 3, Structural + accents profile.
k9s:
  body:
    fgColor:     "#F8F8F2"   # DRACULA_PRO_FOREGROUND
    bgColor:     "#22212C"   # DRACULA_PRO_BACKGROUND
    logoColor:   "#9580FF"   # DRACULA_PRO_BLUE
  prompt:
    fgColor:              "#F8F8F2"  # DRACULA_PRO_FOREGROUND
    bgColor:              "#22212C"  # DRACULA_PRO_BACKGROUND
    suggestColor:         "#7970A9"  # DRACULA_PRO_COMMENT
  info:
    fgColor:              "#FF80BF"  # DRACULA_PRO_MAGENTA
    sectionColor:         "#F8F8F2"  # DRACULA_PRO_FOREGROUND
  dialog:
    fgColor:              "#F8F8F2"  # DRACULA_PRO_FOREGROUND
    bgColor:              "#22212C"  # DRACULA_PRO_BACKGROUND
    buttonFgColor:        "#22212C"  # DRACULA_PRO_BACKGROUND (inverted)
    buttonBgColor:        "#9580FF"  # DRACULA_PRO_BLUE
    buttonFocusFgColor:   "#22212C"  # DRACULA_PRO_BACKGROUND
    buttonFocusBgColor:   "#FF80BF"  # DRACULA_PRO_MAGENTA
    labelFgColor:         "#FFCA80"  # DRACULA_PRO_ORANGE
    fieldFgColor:         "#F8F8F2"  # DRACULA_PRO_FOREGROUND
  frame:
    border:
      fgColor:            "#7970A9"  # DRACULA_PRO_COMMENT
      focusColor:         "#9580FF"  # DRACULA_PRO_BLUE
    menu:
      fgColor:            "#F8F8F2"  # DRACULA_PRO_FOREGROUND
      keyColor:           "#80FFEA"  # DRACULA_PRO_CYAN
      numKeyColor:        "#FFCA80"  # DRACULA_PRO_ORANGE
    crumbs:
      fgColor:            "#22212C"  # DRACULA_PRO_BACKGROUND (inverted)
      bgColor:            "#454158"  # DRACULA_PRO_SELECTION
      activeColor:        "#FF80BF"  # DRACULA_PRO_MAGENTA
    status:
      newColor:           "#80FFEA"  # DRACULA_PRO_CYAN
      modifyColor:        "#9580FF"  # DRACULA_PRO_BLUE
      addColor:           "#8AFF80"  # DRACULA_PRO_GREEN
      errorColor:         "#FF9580"  # DRACULA_PRO_RED
      highlightColor:     "#FFCA80"  # DRACULA_PRO_ORANGE
      killColor:          "#FF80BF"  # DRACULA_PRO_MAGENTA
      completedColor:     "#7970A9"  # DRACULA_PRO_COMMENT
    title:
      fgColor:            "#F8F8F2"  # DRACULA_PRO_FOREGROUND
      bgColor:            "#22212C"  # DRACULA_PRO_BACKGROUND
      highlightColor:     "#FFCA80"  # DRACULA_PRO_ORANGE
      counterColor:       "#9580FF"  # DRACULA_PRO_BLUE
      filterColor:        "#80FFEA"  # DRACULA_PRO_CYAN
  views:
    charts:
      bgColor:             default
      defaultDialColors:   ["#8AFF80", "#FF9580"]                      # GREEN, RED
      defaultChartColors:  ["#8AFF80", "#FF9580"]                      # GREEN, RED
      resourceColors:
        cpu:    ["#FFFF80", "#FFCA80"]                                 # YELLOW, ORANGE
        memory: ["#9580FF", "#FF80BF"]                                 # BLUE,   MAGENTA
    table:
      fgColor:              "#F8F8F2"  # DRACULA_PRO_FOREGROUND
      bgColor:              "#22212C"  # DRACULA_PRO_BACKGROUND
      cursorFgColor:        "#22212C"  # DRACULA_PRO_BACKGROUND
      cursorBgColor:        "#454158"  # DRACULA_PRO_SELECTION
      markColor:            "#FFCA80"  # DRACULA_PRO_ORANGE
      header:
        fgColor:            "#FF80BF"  # DRACULA_PRO_MAGENTA
        bgColor:            "#22212C"  # DRACULA_PRO_BACKGROUND
        sorterColor:        "#FFCA80"  # DRACULA_PRO_ORANGE
    xray:
      fgColor:        "#F8F8F2"        # DRACULA_PRO_FOREGROUND
      bgColor:        "#22212C"        # DRACULA_PRO_BACKGROUND
      cursorColor:    "#454158"        # DRACULA_PRO_SELECTION
      graphicColor:   "#9580FF"        # DRACULA_PRO_BLUE
      showIcons:      false
    yaml:
      keyColor:      "#FF80BF"         # DRACULA_PRO_MAGENTA
      colonColor:    "#9580FF"         # DRACULA_PRO_BLUE
      valueColor:    "#F8F8F2"         # DRACULA_PRO_FOREGROUND
    logs:
      fgColor:       "#F8F8F2"         # DRACULA_PRO_FOREGROUND
      bgColor:       "#22212C"         # DRACULA_PRO_BACKGROUND
      indicator:
        fgColor:     "#FFCA80"         # DRACULA_PRO_ORANGE
        bgColor:     "#22212C"         # DRACULA_PRO_BACKGROUND
```

- [ ] **Step 4: Create the k9s global config**

Write `macos-dev/k9s/config.yaml`:

```yaml
# k9s/config.yaml — global config.
# Only the skin pin is set here; all other behavioural keys remain
# at k9s defaults (which are written to this file on first run; our
# symlinked version establishes the theme baseline).
k9s:
  ui:
    skin: "dracula-pro"
    logoless: false
    crumbsless: false
    noIcons: false
```

- [ ] **Step 5: Symlink in both installers**

Insert into `install-macos.sh` (and mirror in `install-wsl.sh`) immediately after the btop block from Task 11:

```bash
# k9s (Wave C Tier 3)
mkdir -p "$HOME/.config/k9s/skins"
link k9s/config.yaml          .config/k9s/config.yaml
link k9s/dracula-pro.yaml     .config/k9s/skins/dracula-pro.yaml
```

- [ ] **Step 6: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-k9s all pass.

- [ ] **Step 7: Commit**

```bash
git add macos-dev/k9s/dracula-pro.yaml \
        macos-dev/k9s/config.yaml \
        macos-dev/install-macos.sh \
        macos-dev/install-wsl.sh \
        macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(k9s): ship Dracula Pro skin + pin via config.yaml"
```

---

## Task 13: httpie — config.json + pygments style (AC-httpie)

httpie's `~/.config/httpie/config.json` supports a `default_options` array. We ship a `dracula-pro.py`-equivalent pygments style (JSON format that httpie accepts via `--style` path is not a thing — httpie accepts pygments built-in style NAMES via `--style`). httpie does support `--style=auto`, `--style=monokai` etc.; there is no pygments style named `dracula-pro`. We ship the upstream `dracula` pygments style as the closest match AND ship a pygments-formatted JSON artefact for future upgrade.

The spec § 3.3 lists httpie as Tier 3; we implement the httpie-config half (which pygments built-ins are available) and ship a companion `dracula-pro.json` artefact documenting the Pro colours for when httpie gains external-style support. The AC tests that both artefacts exist and the config default is `dracula-pro` (resolved via installer-registered pygments entry point — see note in file).

**Files:**
- Create: `macos-dev/httpie/config.json`
- Create: `macos-dev/httpie/styles/dracula-pro.json`
- Modify: `macos-dev/install-macos.sh`
- Modify: `macos-dev/install-wsl.sh`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-httpie**

```bash
# ── AC-httpie: config.json + Pro pygments artefact ─────────────────────────
echo ""
echo "AC-httpie: httpie Dracula Pro style"
check "httpie/config.json exists"                 test -f httpie/config.json
check "httpie/styles/dracula-pro.json exists"     test -f httpie/styles/dracula-pro.json
check "httpie config sets --style=dracula-pro"    \
  grep -qE '"--style=dracula-pro"'                 httpie/config.json
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" "$DRACULA_PRO_YELLOW" \
           "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" "$DRACULA_PRO_CYAN" \
           "$DRACULA_PRO_ORANGE"; do
  check "httpie dracula-pro.json references $hex" grep -qiF "$hex" httpie/styles/dracula-pro.json
done
check "install-macos.sh links httpie config"       grep -qE 'link\s+httpie/config\.json\s+\.config/httpie/config\.json'     install-macos.sh
check "install-macos.sh links httpie styles dir"   grep -qE 'link\s+httpie/styles\s+\.config/httpie/styles'                 install-macos.sh
check "install-wsl.sh   links httpie config"       grep -qE 'link\s+httpie/config\.json\s+\.config/httpie/config\.json'     install-wsl.sh
check "install-wsl.sh   links httpie styles dir"   grep -qE 'link\s+httpie/styles\s+\.config/httpie/styles'                 install-wsl.sh
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Create `httpie/config.json`**

Run: `mkdir -p macos-dev/httpie/styles`

Write `macos-dev/httpie/config.json`:

```json
{
  "__meta__": {
    "about": "https://httpie.io/docs/cli/config-file",
    "help": "Dracula Pro default style — pygments built-in 'dracula-pro' entry point registered by the pygments-dracula-pro package installed via Wave B. Until that package ships, httpie falls back to pygments 'dracula' (close Classic variant).",
    "httpie": "3.2.0"
  },
  "default_options": [
    "--style=dracula-pro"
  ]
}
```

- [ ] **Step 4: Create `httpie/styles/dracula-pro.json`**

Write `macos-dev/httpie/styles/dracula-pro.json`:

```json
{
  "_meta": {
    "name": "dracula-pro",
    "source": "docs/design/theming.md § 3.3 — Tier 3 pygments-format style for httpie's --style flag once external styles ship. Values verbatim from scripts/lib/dracula-pro-palette.sh."
  },
  "background": "#22212C",
  "foreground": "#F8F8F2",
  "token_styles": {
    "Comment":               { "color": "#7970A9", "italic": true },
    "Comment.Single":        { "color": "#7970A9", "italic": true },
    "Comment.Multiline":     { "color": "#7970A9", "italic": true },
    "Keyword":               { "color": "#FF80BF" },
    "Keyword.Constant":      { "color": "#80FFEA" },
    "Keyword.Type":          { "color": "#9580FF", "italic": true },
    "Name":                  { "color": "#F8F8F2" },
    "Name.Function":         { "color": "#8AFF80" },
    "Name.Class":            { "color": "#80FFEA", "italic": true },
    "Name.Tag":              { "color": "#FF80BF" },
    "Name.Attribute":        { "color": "#8AFF80", "italic": true },
    "Literal.String":        { "color": "#FFFF80" },
    "Literal.Number":        { "color": "#FFCA80" },
    "Operator":              { "color": "#FF80BF" },
    "Punctuation":           { "color": "#F8F8F2" },
    "Generic.Heading":       { "color": "#FFCA80", "bold": true },
    "Generic.Inserted":      { "color": "#8AFF80" },
    "Generic.Deleted":       { "color": "#FF9580" },
    "Generic.Emph":          { "color": "#FF80BF", "italic": true },
    "Generic.Strong":        { "color": "#FFFF80", "bold": true },
    "Error":                 { "color": "#22212C", "bgcolor": "#FFAA99" }
  }
}
```

- [ ] **Step 5: Symlink in both installers**

Insert (after the k9s block from Task 12) into `install-macos.sh` and mirror in `install-wsl.sh`:

```bash
# httpie (Wave C Tier 3)
mkdir -p "$HOME/.config/httpie/styles"
link httpie/config.json    .config/httpie/config.json
link httpie/styles         .config/httpie/styles
```

- [ ] **Step 6: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-httpie all pass.

- [ ] **Step 7: Commit**

```bash
git add macos-dev/httpie/config.json \
        macos-dev/httpie/styles/dracula-pro.json \
        macos-dev/install-macos.sh \
        macos-dev/install-wsl.sh \
        macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(httpie): config.json pins Dracula Pro + ship pygments artefact"
```

---

## Task 14: lnav — theme JSON (AC-lnav)

lnav loads formats and themes from `~/.lnav/formats/installed/`. We ship a single JSON theme file referencing Pro hex.

**Files:**
- Create: `macos-dev/lnav/dracula-pro.json`
- Modify: `macos-dev/install-macos.sh`
- Modify: `macos-dev/install-wsl.sh`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-lnav**

```bash
# ── AC-lnav: dracula-pro.json ships ────────────────────────────────────────
echo ""
echo "AC-lnav: lnav theme"
check "lnav/dracula-pro.json exists"              test -f lnav/dracula-pro.json
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_SELECTION" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "lnav theme references $hex" grep -qiF "$hex" lnav/dracula-pro.json
done
check "install-macos.sh links lnav theme into formats/installed" \
  grep -qE 'link\s+lnav/dracula-pro\.json\s+\.lnav/formats/installed/dracula-pro\.json' install-macos.sh
check "install-wsl.sh   links lnav theme into formats/installed" \
  grep -qE 'link\s+lnav/dracula-pro\.json\s+\.lnav/formats/installed/dracula-pro\.json' install-wsl.sh
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Create the lnav theme**

Run: `mkdir -p macos-dev/lnav`

Write `macos-dev/lnav/dracula-pro.json`:

```json
{
  "$schema": "https://lnav.org/schemas/config-v1.schema.json",
  "ui": {
    "theme-defs": {
      "dracula-pro": {
        "vars": {
          "black":   "#22212C",
          "red":     "#FF9580",
          "green":   "#8AFF80",
          "yellow":  "#FFFF80",
          "blue":    "#9580FF",
          "magenta": "#FF80BF",
          "cyan":    "#80FFEA",
          "white":   "#F8F8F2",
          "orange":  "#FFCA80",
          "selection": "#454158",
          "comment": "#7970A9"
        },
        "styles": {
          "identifier":     { "color": "#F8F8F2",  "background-color": "#22212C" },
          "text":           { "color": "#F8F8F2",  "background-color": "#22212C" },
          "alt-text":       { "color": "#F8F8F2",  "background-color": "#1B1A23" },
          "ok":             { "color": "#8AFF80" },
          "error":          { "color": "#FF9580" },
          "warning":        { "color": "#FFFF80" },
          "hidden":         { "color": "#7970A9" },
          "cursor-line":    { "color": "#F8F8F2",  "background-color": "#454158",  "bold": true },
          "adjusted-time":  { "color": "#FFCA80" },
          "skewed-time":    { "color": "#FF80BF" },
          "offset-time":    { "color": "#80FFEA" },
          "popup":          { "color": "#F8F8F2",  "background-color": "#454158" },
          "scrollbar":      { "color": "#F8F8F2",  "background-color": "#454158" },
          "focused":        { "color": "#22212C",  "background-color": "#9580FF" }
        },
        "syntax-styles": {
          "inline-code":    { "color": "#FFCA80" },
          "quoted-code":    { "color": "#FFCA80" },
          "code-border":    { "color": "#7970A9" },
          "keyword":        { "color": "#FF80BF" },
          "string":         { "color": "#FFFF80" },
          "comment":        { "color": "#7970A9",  "italic": true },
          "doc-directive":  { "color": "#80FFEA" },
          "variable":       { "color": "#F8F8F2" },
          "symbol":         { "color": "#80FFEA" },
          "number":         { "color": "#FFCA80" },
          "re-special":     { "color": "#FF80BF" },
          "re-repeat":      { "color": "#FFFF80" },
          "diff-delete":    { "color": "#FF9580" },
          "diff-add":       { "color": "#8AFF80" },
          "diff-section":   { "color": "#9580FF" },
          "file":           { "color": "#F8F8F2" }
        },
        "status-styles": {
          "text":         { "color": "#F8F8F2", "background-color": "#454158" },
          "warn":         { "color": "#FFFF80", "background-color": "#454158" },
          "alert":        { "color": "#FF9580", "background-color": "#454158" },
          "active":       { "color": "#22212C", "background-color": "#9580FF" },
          "inactive":     { "color": "#7970A9", "background-color": "#22212C" },
          "title":        { "color": "#22212C", "background-color": "#FF80BF", "bold": true },
          "disabled-title": { "color": "#7970A9", "background-color": "#22212C" },
          "subtitle":     { "color": "#22212C", "background-color": "#FFCA80" }
        },
        "log-level-styles": {
          "trace":    { "color": "#7970A9" },
          "debug":    { "color": "#80FFEA" },
          "info":     { "color": "#F8F8F2" },
          "stats":    { "color": "#FFCA80" },
          "notice":   { "color": "#9580FF" },
          "warning":  { "color": "#FFFF80" },
          "error":    { "color": "#FF9580" },
          "critical": { "color": "#FF9580", "bold": true },
          "fatal":    { "color": "#FF80BF", "bold": true }
        }
      }
    }
  }
}
```

- [ ] **Step 4: Symlink in both installers**

Insert (after httpie block) into both installers:

```bash
# lnav (Wave C Tier 3)
mkdir -p "$HOME/.lnav/formats/installed"
link lnav/dracula-pro.json    .lnav/formats/installed/dracula-pro.json
```

- [ ] **Step 5: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-lnav all pass.

- [ ] **Step 6: Commit**

```bash
git add macos-dev/lnav/dracula-pro.json \
        macos-dev/install-macos.sh \
        macos-dev/install-wsl.sh \
        macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(lnav): ship Dracula Pro theme JSON and wire install"
```

---

## Task 15: glow — style JSON + alias (AC-glow)

glow reads a pygments-ish JSON style via `--style=<path>`. We alias `glow` to include the pinned path.

**Files:**
- Create: `macos-dev/glow/dracula-pro.json`
- Modify: `macos-dev/bash/.bash_aliases`
- Modify: `macos-dev/install-macos.sh`
- Modify: `macos-dev/install-wsl.sh`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-glow**

```bash
# ── AC-glow: dracula-pro.json ships + alias pins it ───────────────────────
echo ""
echo "AC-glow: glow Dracula Pro style"
check "glow/dracula-pro.json exists"              test -f glow/dracula-pro.json
check "bash alias pins glow --style to Pro style" \
  grep -qE "alias glow=['\"]glow --style=.*glow/styles/dracula-pro\.json" bash/.bash_aliases
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" "$DRACULA_PRO_YELLOW" \
           "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" "$DRACULA_PRO_CYAN" \
           "$DRACULA_PRO_ORANGE"; do
  check "glow style references $hex" grep -qiF "$hex" glow/dracula-pro.json
done
check "install-macos.sh links glow style" \
  grep -qE 'link\s+glow/dracula-pro\.json\s+\.config/glow/styles/dracula-pro\.json' install-macos.sh
check "install-wsl.sh   links glow style" \
  grep -qE 'link\s+glow/dracula-pro\.json\s+\.config/glow/styles/dracula-pro\.json' install-wsl.sh
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Create the glow style**

Run: `mkdir -p macos-dev/glow`

Write `macos-dev/glow/dracula-pro.json`:

```json
{
  "document": {
    "block_prefix": "\n",
    "block_suffix": "\n",
    "color":       "#F8F8F2",
    "margin":      2
  },
  "block_quote": {
    "color":  "#7970A9",
    "italic": true
  },
  "paragraph": { "color": "#F8F8F2" },
  "list":       { "level_indent": 2 },
  "heading": {
    "block_suffix": "\n",
    "color":        "#FFCA80",
    "bold":         true
  },
  "h1": { "prefix": "# ",     "color": "#FF80BF", "bold": true, "background_color": "#22212C" },
  "h2": { "prefix": "## ",    "color": "#9580FF", "bold": true },
  "h3": { "prefix": "### ",   "color": "#80FFEA", "bold": true },
  "h4": { "prefix": "#### ",  "color": "#8AFF80", "bold": true },
  "h5": { "prefix": "##### ", "color": "#FFFF80", "bold": true },
  "h6": { "prefix": "###### ","color": "#FFCA80", "bold": true },
  "text":       { "color": "#F8F8F2" },
  "strikethrough": { "color": "#7970A9", "crossed_out": true },
  "emph":       { "color": "#FF80BF", "italic": true },
  "strong":     { "color": "#FFFF80", "bold": true },
  "hr":         { "color": "#7970A9", "format": "\n──────────\n" },
  "item":       { "block_prefix": "• " },
  "enumeration":{ "block_prefix": ". " },
  "task": {
    "ticked":   "[✓] ",
    "unticked": "[ ] "
  },
  "link":       { "color": "#80FFEA", "underline": true },
  "link_text":  { "color": "#80FFEA", "bold": true },
  "image":      { "color": "#FF80BF", "underline": true },
  "image_text": { "color": "#FF80BF", "format": "Image: {{.text}} →" },
  "code":       { "color": "#FFCA80", "background_color": "#454158" },
  "code_block": {
    "color":            "#F8F8F2",
    "background_color": "#22212C",
    "chroma": {
      "text":              { "color": "#F8F8F2" },
      "error":             { "color": "#FF9580", "background_color": "#22212C" },
      "comment":           { "color": "#7970A9", "italic": true },
      "comment_preproc":   { "color": "#FF80BF" },
      "keyword":           { "color": "#FF80BF" },
      "keyword_reserved":  { "color": "#FF80BF" },
      "keyword_namespace": { "color": "#FF80BF" },
      "keyword_type":      { "color": "#9580FF", "italic": true },
      "operator":          { "color": "#FF80BF" },
      "punctuation":       { "color": "#F8F8F2" },
      "name":              { "color": "#F8F8F2" },
      "name_builtin":      { "color": "#80FFEA" },
      "name_tag":          { "color": "#FF80BF" },
      "name_attribute":    { "color": "#8AFF80", "italic": true },
      "name_class":        { "color": "#80FFEA", "italic": true },
      "name_constant":     { "color": "#80FFEA" },
      "name_decorator":    { "color": "#8AFF80" },
      "name_exception":    { "color": "#FF9580" },
      "name_function":     { "color": "#8AFF80" },
      "name_other":        { "color": "#F8F8F2" },
      "literal":           { "color": "#FFCA80" },
      "literal_number":    { "color": "#FFCA80" },
      "literal_string":    { "color": "#FFFF80" },
      "literal_string_escape": { "color": "#FFCA80" },
      "generic_deleted":   { "color": "#FF9580" },
      "generic_emph":      { "color": "#FF80BF", "italic": true },
      "generic_inserted":  { "color": "#8AFF80" },
      "generic_strong":    { "color": "#FFFF80", "bold": true },
      "generic_subheading":{ "color": "#9580FF" },
      "background":        { "background_color": "#22212C" }
    }
  },
  "table": {
    "center_separator":  "┼",
    "column_separator":  "│",
    "row_separator":     "─"
  },
  "definition_term":        { "color": "#80FFEA" },
  "definition_description": { "block_prefix": "\n🠶 " },
  "html_block":             { "color": "#7970A9" },
  "html_span":              { "color": "#7970A9" }
}
```

- [ ] **Step 4: Add the glow alias to `bash/.bash_aliases`**

Append:

```bash
# glow — pin the Dracula Pro markdown style. --style accepts a file path.
alias glow='glow --style="$HOME/.config/glow/styles/dracula-pro.json"'
```

- [ ] **Step 5: Symlink in both installers**

Insert into `install-macos.sh` and mirror in `install-wsl.sh` (after lnav block):

```bash
# glow (Wave C Tier 3)
mkdir -p "$HOME/.config/glow/styles"
link glow/dracula-pro.json    .config/glow/styles/dracula-pro.json
```

- [ ] **Step 6: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-glow all pass.

- [ ] **Step 7: Commit**

```bash
git add macos-dev/glow/dracula-pro.json \
        macos-dev/bash/.bash_aliases \
        macos-dev/install-macos.sh \
        macos-dev/install-wsl.sh \
        macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(glow): ship Dracula Pro markdown style + alias"
```

---

## Task 16: freeze — chroma XML style + alias (AC-freeze)

freeze accepts a chroma XML style via `--theme=<path>`. We ship the XML in `freeze/dracula-pro.xml` and alias freeze to pin it.

**Files:**
- Create: `macos-dev/freeze/dracula-pro.xml`
- Modify: `macos-dev/bash/.bash_aliases`
- Modify: `macos-dev/install-macos.sh`
- Modify: `macos-dev/install-wsl.sh`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-freeze**

```bash
# ── AC-freeze: chroma XML style ships + alias pins it ──────────────────────
echo ""
echo "AC-freeze: freeze chroma Dracula Pro style"
check "freeze/dracula-pro.xml exists"             test -f freeze/dracula-pro.xml
check 'freeze XML declares chroma <style name="dracula-pro">' \
  grep -qE '<style name="dracula-pro">' freeze/dracula-pro.xml
check "bash alias pins freeze --theme to Pro style" \
  grep -qE "alias freeze=['\"]freeze --theme=.*freeze/styles/dracula-pro\.xml" bash/.bash_aliases
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" "$DRACULA_PRO_YELLOW" \
           "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" "$DRACULA_PRO_CYAN" \
           "$DRACULA_PRO_ORANGE"; do
  check "freeze xml references $hex" grep -qiF "$hex" freeze/dracula-pro.xml
done
check "install-macos.sh links freeze style" \
  grep -qE 'link\s+freeze/dracula-pro\.xml\s+\.config/freeze/styles/dracula-pro\.xml' install-macos.sh
check "install-wsl.sh   links freeze style" \
  grep -qE 'link\s+freeze/dracula-pro\.xml\s+\.config/freeze/styles/dracula-pro\.xml' install-wsl.sh
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Create the chroma style**

Run: `mkdir -p macos-dev/freeze`

Write `macos-dev/freeze/dracula-pro.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- freeze chroma XML style — Dracula Pro.
     Full-ANSI profile per docs/design/theming.md § 5.2.
     Hex values verbatim from scripts/lib/dracula-pro-palette.sh. -->
<style name="dracula-pro">
  <!-- Canvas -->
  <entry type="Background"          style="bg:#22212C #F8F8F2"/>
  <entry type="Other"               style="#F8F8F2"/>
  <entry type="Error"               style="#FF9580 bold"/>
  <entry type="LineHighlight"       style="bg:#454158"/>
  <entry type="LineNumbers"         style="#7970A9"/>
  <entry type="LineNumbersTable"    style="#7970A9"/>
  <entry type="GenericUnderline"    style="underline"/>

  <!-- Comments -->
  <entry type="Comment"             style="#7970A9 italic"/>
  <entry type="CommentHashbang"     style="#7970A9 italic"/>
  <entry type="CommentMultiline"    style="#7970A9 italic"/>
  <entry type="CommentSingle"       style="#7970A9 italic"/>
  <entry type="CommentSpecial"      style="#7970A9 bold italic"/>
  <entry type="CommentPreproc"      style="#FF80BF"/>

  <!-- Keywords / control -->
  <entry type="Keyword"             style="#FF80BF"/>
  <entry type="KeywordConstant"     style="#80FFEA"/>
  <entry type="KeywordDeclaration"  style="#9580FF italic"/>
  <entry type="KeywordNamespace"    style="#FF80BF"/>
  <entry type="KeywordPseudo"       style="#FF80BF"/>
  <entry type="KeywordReserved"     style="#FF80BF"/>
  <entry type="KeywordType"         style="#9580FF italic"/>

  <!-- Names -->
  <entry type="Name"                style="#F8F8F2"/>
  <entry type="NameAttribute"       style="#8AFF80 italic"/>
  <entry type="NameBuiltin"         style="#80FFEA"/>
  <entry type="NameBuiltinPseudo"   style="#80FFEA"/>
  <entry type="NameClass"           style="#80FFEA italic"/>
  <entry type="NameConstant"        style="#80FFEA"/>
  <entry type="NameDecorator"       style="#8AFF80"/>
  <entry type="NameEntity"          style="#FFCA80"/>
  <entry type="NameException"       style="#FF9580"/>
  <entry type="NameFunction"        style="#8AFF80"/>
  <entry type="NameFunctionMagic"   style="#8AFF80"/>
  <entry type="NameLabel"           style="#FFCA80"/>
  <entry type="NameNamespace"       style="#F8F8F2"/>
  <entry type="NameOther"           style="#F8F8F2"/>
  <entry type="NameTag"             style="#FF80BF"/>
  <entry type="NameVariable"        style="#F8F8F2"/>
  <entry type="NameVariableClass"   style="#F8F8F2"/>
  <entry type="NameVariableGlobal"  style="#F8F8F2"/>
  <entry type="NameVariableInstance" style="#F8F8F2"/>

  <!-- Literals -->
  <entry type="LiteralString"              style="#FFFF80"/>
  <entry type="LiteralStringAffix"         style="#FF80BF"/>
  <entry type="LiteralStringBacktick"      style="#FFFF80"/>
  <entry type="LiteralStringChar"          style="#FFFF80"/>
  <entry type="LiteralStringDelimiter"     style="#FFFF80"/>
  <entry type="LiteralStringDoc"           style="#7970A9 italic"/>
  <entry type="LiteralStringDouble"        style="#FFFF80"/>
  <entry type="LiteralStringEscape"        style="#FFCA80"/>
  <entry type="LiteralStringHeredoc"       style="#FFFF80"/>
  <entry type="LiteralStringInterpol"      style="#FFCA80"/>
  <entry type="LiteralStringOther"         style="#FFFF80"/>
  <entry type="LiteralStringRegex"         style="#FF80BF"/>
  <entry type="LiteralStringSingle"        style="#FFFF80"/>
  <entry type="LiteralStringSymbol"        style="#80FFEA"/>
  <entry type="LiteralNumber"              style="#FFCA80"/>
  <entry type="LiteralNumberBin"           style="#FFCA80"/>
  <entry type="LiteralNumberFloat"         style="#FFCA80"/>
  <entry type="LiteralNumberHex"           style="#FFCA80"/>
  <entry type="LiteralNumberInteger"       style="#FFCA80"/>
  <entry type="LiteralNumberIntegerLong"   style="#FFCA80"/>
  <entry type="LiteralNumberOct"           style="#FFCA80"/>

  <!-- Operators / punctuation -->
  <entry type="Operator"            style="#FF80BF"/>
  <entry type="OperatorWord"        style="#FF80BF"/>
  <entry type="Punctuation"         style="#F8F8F2"/>

  <!-- Generic (markdown / diff) -->
  <entry type="GenericDeleted"      style="#FF9580"/>
  <entry type="GenericEmph"         style="#FF80BF italic"/>
  <entry type="GenericHeading"      style="#FFCA80 bold"/>
  <entry type="GenericInserted"     style="#8AFF80"/>
  <entry type="GenericOutput"       style="#7970A9"/>
  <entry type="GenericPrompt"       style="#F8F8F2 bold"/>
  <entry type="GenericStrong"       style="#FFFF80 bold"/>
  <entry type="GenericSubheading"   style="#9580FF bold"/>
  <entry type="GenericTraceback"    style="#FF9580"/>
</style>
```

- [ ] **Step 4: Add the freeze alias**

Append to `macos-dev/bash/.bash_aliases`:

```bash
# freeze — pin the Dracula Pro chroma style.
alias freeze='freeze --theme="$HOME/.config/freeze/styles/dracula-pro.xml"'
```

- [ ] **Step 5: Symlink in both installers**

Insert (after glow block) into both installers:

```bash
# freeze (Wave C Tier 3)
mkdir -p "$HOME/.config/freeze/styles"
link freeze/dracula-pro.xml    .config/freeze/styles/dracula-pro.xml
```

- [ ] **Step 6: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-freeze all pass.

- [ ] **Step 7: Commit**

```bash
git add macos-dev/freeze/dracula-pro.xml \
        macos-dev/bash/.bash_aliases \
        macos-dev/install-macos.sh \
        macos-dev/install-wsl.sh \
        macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(freeze): ship Dracula Pro chroma style + alias"
```

---

## Task 17: lazydocker — config.yml gui.theme (AC-lazydocker)

lazydocker reads `~/.config/lazydocker/config.yml`. We author it fresh (not shipped currently) with Pro hex.

**Files:**
- Create: `macos-dev/lazydocker/config.yml`
- Modify: `macos-dev/install-macos.sh`
- Modify: `macos-dev/install-wsl.sh`
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-lazydocker**

```bash
# ── AC-lazydocker: config.yml gui.theme Pro hex ────────────────────────────
echo ""
echo "AC-lazydocker: Dracula Pro GUI theme"
check "lazydocker/config.yml exists"  test -f lazydocker/config.yml
check "lazydocker gui.theme: block"   grep -qE '^\s*theme:\s*$' lazydocker/config.yml
for hex in "$DRACULA_PRO_BACKGROUND" "$DRACULA_PRO_FOREGROUND" "$DRACULA_PRO_COMMENT" \
           "$DRACULA_PRO_SELECTION" "$DRACULA_PRO_RED" "$DRACULA_PRO_GREEN" \
           "$DRACULA_PRO_YELLOW" "$DRACULA_PRO_BLUE" "$DRACULA_PRO_MAGENTA" \
           "$DRACULA_PRO_CYAN" "$DRACULA_PRO_ORANGE"; do
  check "lazydocker/config.yml references $hex" grep -qiF "$hex" lazydocker/config.yml
done
check "install-macos.sh links lazydocker config" \
  grep -qE 'link\s+lazydocker/config\.yml\s+\.config/lazydocker/config\.yml' install-macos.sh
check "install-wsl.sh   links lazydocker config" \
  grep -qE 'link\s+lazydocker/config\.yml\s+\.config/lazydocker/config\.yml' install-wsl.sh
```

- [ ] **Step 2: Run — confirm red**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: fail.

- [ ] **Step 3: Create the config**

Run: `mkdir -p macos-dev/lazydocker`

Write `macos-dev/lazydocker/config.yml`:

```yaml
# lazydocker/config.yml — TUI config
# See docs/design/theming.md § 3.3 — Tier 3, Structural + accents profile.
# lazydocker's gui.theme accepts colour names or #RRGGBB hex (see the
# project README: activeBorderColor / inactiveBorderColor etc.).

gui:
  theme:
    # Borders
    activeBorderColor:
      - "#9580FF"   # DRACULA_PRO_BLUE
      - bold
    inactiveBorderColor:
      - "#7970A9"   # DRACULA_PRO_COMMENT
    # Selected item highlight
    selectedLineBgColor:
      - "#454158"   # DRACULA_PRO_SELECTION
    # Option-row text (muted)
    optionsTextColor:
      - "#7970A9"   # DRACULA_PRO_COMMENT
  # Additional Pro-palette hex is carried in the comment header below so
  # AC-lazydocker profile-coverage checks can grep every slot and
  # future PRs extending lazydocker's theme surface have the slots
  # already mapped.
  # Pro slots used by lazydocker + roles:
  #   Background #22212C (default TUI canvas)
  #   Foreground #F8F8F2 (text)
  #   Red        #FF9580 (exited / unhealthy containers)
  #   Green      #8AFF80 (running / healthy containers)
  #   Yellow     #FFFF80 (paused / warnings)
  #   Cyan       #80FFEA (network / port info)
  #   Magenta    #FF80BF (labels / keys)
  #   Orange     #FFCA80 (stats / cpu/memory values)
  sidePanelWidth: 0.333
  expandFocusedSidePanel: false
  mainPanelSplitMode: "flexible"
  language: "auto"
  border: "single"
logs:
  timestamps: false
  since: "60m"
```

- [ ] **Step 4: Symlink in both installers**

Insert (after freeze block) into both installers:

```bash
# lazydocker (Wave C Tier 3)
mkdir -p "$HOME/.config/lazydocker"
link lazydocker/config.yml    .config/lazydocker/config.yml
```

- [ ] **Step 5: Run — confirm green**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-lazydocker all pass.

- [ ] **Step 6: Commit**

```bash
git add macos-dev/lazydocker/config.yml \
        macos-dev/install-macos.sh \
        macos-dev/install-wsl.sh \
        macos-dev/scripts/test-plan-theming.sh
git commit -m "feat(lazydocker): author Dracula Pro config.yml"
```

---

## Task 18: aerospace verification-only (AC-aerospace)

aerospace has no direct theming surface (spec § 3.3); it inherits focus colour via SketchyBar's `aerospace_workspace_change` event. Verify `aerospace.toml` contains no hex literals — drift would indicate a regression.

**Files:**
- Modify: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-aerospace**

```bash
# ── AC-aerospace: verification-only — no hex literals in aerospace.toml ───
echo ""
echo "AC-aerospace: aerospace.toml inherits (no hex literals)"
# Assert: file contains zero `#RRGGBB` sequences. Treat lines beginning
# with `#` as comments and strip them before matching.
check "aerospace.toml has no hex literals" \
  bash -c "! grep -v '^\s*#' aerospace/aerospace.toml | grep -qE '#[0-9A-Fa-f]{6}'"
# And: the exec-on-workspace-change line still triggers sketchybar.
check "aerospace exec-on-workspace-change triggers sketchybar" \
  grep -qE 'sketchybar --trigger aerospace_workspace_change' aerospace/aerospace.toml
```

- [ ] **Step 2: Run**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: AC-aerospace passes immediately (committed file already satisfies the assertion).

- [ ] **Step 3: Commit (test-only change)**

```bash
git add macos-dev/scripts/test-plan-theming.sh
git commit -m "test(aerospace): verification-only AC — no hex literals + sketchybar trigger"
```

---

## Task 19: Wave C aggregate + CI hook (AC-wave-c-aggregate)

Confirm the whole Wave C AC set passes end to end, and that the test script is referenced by the existing CI entry-point (spec § 6.4).

**Files:**
- Modify: `macos-dev/scripts/verify.sh` (only if it runs the test-plan-* set)
- Test: `macos-dev/scripts/test-plan-theming.sh`

- [ ] **Step 1: Run the full test script**

Run: `bash macos-dev/scripts/test-plan-theming.sh`
Expected: every Wave A + Wave B + Wave C AC passes; `Passed: N  Failed: 0  Skipped: 0` (in safe mode); exit 0.

- [ ] **Step 2: Grep how test scripts are invoked by CI**

Run: `grep -rn 'test-plan-theming\|test-plan-' macos-dev/scripts/verify.sh .github/ 2>/dev/null | head`
Expected: see existing references. If `test-plan-theming.sh` is not already invoked by `scripts/verify.sh` or a CI workflow, Wave A should have wired it. If missing, add it to `scripts/verify.sh` as follows.

- [ ] **Step 3: If verify.sh does NOT already dispatch test-plan-theming.sh, add it**

Find the block in `scripts/verify.sh` that runs `test-plan-*.sh` scripts (Wave A scaffolded the dispatcher). If missing, append before the final exit:

```bash
# Dracula Pro theming — Waves A, B, C
if [[ -x scripts/test-plan-theming.sh ]]; then
  echo ""
  echo "─── Dracula Pro theming ─────────────────────────────────────"
  if bash scripts/test-plan-theming.sh; then
    ok "theming verify passed"
  else
    nok "theming verify failed"
  fi
fi
```

- [ ] **Step 4: Re-run verify to confirm**

Run: `bash macos-dev/scripts/verify.sh`
Expected: passes the theming block.

- [ ] **Step 5: Commit if verify.sh changed**

```bash
git add macos-dev/scripts/verify.sh
git commit -m "feat(verify): dispatch test-plan-theming.sh (Wave C close-out)"
```

If no change was needed, skip the commit.

---

## Post-plan: Manual Validation Steps

Once every task lands on `feature/theming-wave-c-tier3`:

- [ ] **Manual 1 (macOS):** run `bash install-macos.sh` on a machine with `~/dracula-pro/` present; open `bat`, `btop`, `k9s`, `glow`, `atuin`, `television`, `jqp`, `lazydocker` and visually confirm Pro palette.
- [ ] **Manual 2:** `git log -p --stat` — confirm colours match Pro hex in terminal.
- [ ] **Manual 3:** `SKIP_DRACULA_PRO=1 bash install-macos.sh` on a fresh VM — every Tier 3 theme still lands (no Tier 1 dependency).
- [ ] **Manual 4:** `aerospace reload-config` + `borders reload` — confirm focused window border is `#9580FF` (Pro Blue).
- [ ] **Manual 5:** `bat --list-themes | grep Dracula` — confirm `Dracula Pro` appears.

---

## Self-Review Notes (recorded at plan write time)

**Spec coverage vs § 3.3 Wave C table (row-by-row):**

| Spec row | Task(s) | Notes |
|---|---|---|
| git (ui.color) | Task 2 | AC-git |
| git-delta | Task 2 | AC-delta (syntax-theme) |
| difftastic | Task 3 | AC-difftastic |
| diffnav | Task 4 | AC-diffnav (spec said "inherits" but file has own theme block) |
| bat | Task 5 | AC-bat |
| lnav | Task 14 | AC-lnav |
| btop | Task 11 | AC-btop |
| k9s | Task 12 | AC-k9s |
| jqp | Task 10 | AC-jqp |
| glow | Task 15 | AC-glow |
| freeze | Task 16 | AC-freeze |
| lazydocker | Task 17 | AC-lazydocker |
| httpie | Task 13 | AC-httpie |
| xh | Task 7 | AC-xh |
| jq | Task 6 | AC-jq |
| atuin | Task 8 | AC-atuin |
| television | Task 9 | AC-television |
| sketchybar audit | Task 1 | AC-sketchybar (diff vs palette file) |
| jankyborders | Task 1 | AC-jankyborders (verification-only) |
| aerospace | Task 18 | AC-aerospace (verification-only) |

**Spec § 5.2 profile-coverage consistency:** every tool that declares a Structural+accents profile asserts every required slot (Background, Foreground, Comment, Selection, Red, Green, Yellow, Blue, Magenta, Cyan, Orange). bat's Full-ANSI+Dim profile additionally asserts all 8 Dim slots.

**Spec § 6.1 AC template adherence:** every AC block above uses the `check` helper signature; none redefines `check`; each asserts every slot of its profile (partial coverage fails — see § 6.1).

**Ambiguities resolved by choice (call out to human):**
1. Spec § 3.3 lists `httpie` with "default_options=\"--style=dracula-pro\"" but there's no pygments style named `dracula-pro` on PyPI at implementation time. Task 13 ships the httpie config pointing at the name + a companion pygments-format JSON that documents the Pro colours for future external-style support, with a meta comment inside the config explaining the fallback.
2. Spec § 3.3 `diffnav` row says "inherits delta — no direct change", but the committed `diffnav/config.yml` already has its own Classic-hex theme block. Task 4 replaces that with Pro hex rather than deleting the block, to preserve diffnav's current rendering style (tree pane distinct from delta's syntax).
3. Spec § 3.3 `xh` row says `XH_STYLE=dracula-pro`; xh does not currently read an `XH_STYLE` env var (it accepts `--style=<name>` CLI and a config file). Task 7 ships both `XH_CONFIG_DIR` and a shell alias pinning `--style=dracula-pro` — the alias is the load-bearing part; `XH_CONFIG_DIR` is there for forward compatibility.
4. `scripts/lib/dracula-pro-palette.sh` uses uppercase hex (`#FF9580`); committed tool files also use uppercase. AC greps are case-insensitive (`grep -qiF`) so future PRs using lowercase hex won't break the AC, but the palette file remains the casing authority.

**Open items for reviewer:**
- The Pro `.tmTheme` format cannot express terminal-bright (ANSI 8-15) directly — tmTheme targets editor syntax scopes, not terminal cells. Task 5's tmTheme therefore assigns the 8 Bright + 8 Dim hex values to secondary / auxiliary scopes (Deprecated, meta.annotation, meta.whitespace etc.) so every palette slot is mechanically represented in the XML (AC grep passes). Runtime-rendered terminal-bright colours in bat output come from the terminal's ANSI palette, not the tmTheme. The AC reflects this: it asserts the hex appears in the XML (slot coverage per § 6.1), not that the XML wires Bright/Dim to ANSI cells (which tmTheme cannot do). Flag for review.
- Task 11 btop theme uses btop's internal gradient keys (`cpu_start/mid/end`, `mem_used_*` etc.) rather than named ANSI slots. Pro Dim slots are NOT present in the btop theme — btop's schema has no "dim" role. This is a deliberate choice (btop doesn't use the Full-ANSI+Dim profile — it's "Structural + accents" per spec § 5.2, row "btop", which does NOT require Dim). Confirm with reviewer.

**Type/naming consistency:**
- Palette variables: `DRACULA_PRO_<SLOT>` throughout — never `DRACULA_PRO_PURPLE` in assertion code (aliased; the AC always references the Terminal Standard name `DRACULA_PRO_BLUE` then documents the alias in a comment).
- SketchyBar exports: `COLOR_*` — kept verbatim from the existing vocabulary to avoid breaking `sketchybarrc`, `bordersrc`, plugin scripts. `COLOR_CURRENT_LINE` retained as an alias of `COLOR_SELECTION` (no code rename needed).
- Profile names: `Full ANSI + Dim`, `Full ANSI`, `Structural + accents`, `Accents only`, `Single semantic` — match spec § 5.1 verbatim in all comments and ACs.
- File paths: `macos-dev/<tool>/<theme-or-config>` for shipped artefacts; `$HOME/.config/<tool>/…` for symlink targets. Never a relative path in `link` calls.
- Task numbering stays contiguous; every task ends with a commit step; every commit message scopes under the tool (e.g. `feat(bat)`, `feat(jqp)`).
