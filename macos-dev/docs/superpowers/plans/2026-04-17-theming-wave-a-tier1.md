# Theming Wave A — Tier 1 Adoption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopt Dracula Pro ready-made themes (Tier 1) across kitty, nvim, vscode, windows-terminal, raycast, and ghostty, plus ship the shared Wave A infrastructure (palette file, `SKIP_DRACULA_PRO=1` handling, loud-fail on absent `~/dracula-pro/`, `.gitignore` entry, and an ATDD acceptance script).

**Architecture:** All Pro theme *files* stay at `~/dracula-pro/themes/…` and are referenced by path (kitty `include`, nvim lazy.nvim `dir`, ghostty `theme = …`). Install-time copy is used only where the tool has no include-directive equivalent (windows-terminal scheme JSON → WT `settings.json`; vscode `.vsix` → `code --install-extension`). The palette file `scripts/lib/dracula-pro-palette.sh` is the single committed source of truth for Pro hex values (facts, not expressive works) and is sourced by the kitty include file we *generate* at install time from those facts (required because no kitty-native Pro theme ships in `~/dracula-pro/themes/`). The install scripts fail loud when `~/dracula-pro/` is absent unless `SKIP_DRACULA_PRO=1` is set, in which case Tier 1 steps are skipped with a warning and the install continues.

**Tech Stack:** bash, kitty (include directive), ghostty (theme path), lazy.nvim (local `dir` plugin), VSCode CLI (`code --install-extension`), `jq` (Windows Terminal scheme splice), Raycast (manual first-run import).

**Spec reference:** `macos-dev/docs/design/theming.md` § 3.1, § 4, § 5.3 Wave A, § 6.3, § 6.4.

**Platform scope:** macOS (Tier 1 primary — kitty, nvim, vscode, raycast, ghostty), WSL2 Ubuntu (Tier 1 limited — nvim, vscode-server, windows-terminal scheme copy). Tests run on both via `scripts/test-plan-theming.sh`.

**Spec ambiguities resolved by choice in this plan** (flagged for ratification):

1. **Kitty theme file source.** Spec § 8 open item 1. `~/dracula-pro/themes/` does *not* contain a kitty-native `.conf` — only ghostty format (`palette = N=#…`) which kitty does not parse. Kitty ships `include ~/.config/kitty/dracula-pro.generated.conf`, a file produced at install time from `scripts/lib/dracula-pro-palette.sh` (the authorised palette-facts file). The generated file lives under `~/.config/kitty/` (runtime, not repo). The repo's `kitty/dracula-pro.conf` reconstruction is deleted per § 4.4.
2. **Ghostty.** Included in this wave (spec § 5.3 Wave A table marks it "optional this wave"). Trivial — a new `ghostty/config` that sets `theme = ~/dracula-pro/themes/ghostty/pro` and a symlink.
3. **Windows Terminal scheme install.** Spec § 4.2 says `install-wsl.sh` "copies scheme JSON … into Windows Terminal `settings.json`". Concrete implementation: detect the WT settings path under `/mnt/c/Users/<winuser>/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json`, use `jq` to splice the Pro scheme into `schemes[]` idempotently (matched by `.name == "Dracula Pro"`), and fall back to a loud instructional warn if the path is not resolvable or `jq` is absent. Non-destructive: the user's other schemes, profiles, and keybindings are preserved.
4. **Raycast.** No CLI install exists (documented in `~/dracula-pro/themes/raycast/install.md`). A Next-Steps entry is added to `install-macos.sh` pointing at the `addToRaycast` deep-link for the `Pro` variant; a `raycast/dracula-pro.md` doc file is added recording the variant choice for reproducibility.
5. **test-plan-theming.sh.** Covers the Wave A AC set only. Waves B/C extend this same file; the `check` helper and palette-source idiom are shared now so later waves only append AC blocks.

---

## Acceptance Criteria (Specification by Example)

Every AC below is implemented as a labelled check in `scripts/test-plan-theming.sh`. Tasks reference the AC-IDs they satisfy.

**AC-palette: Palette file ships and matches `~/dracula-pro/design/palette.md` § Base / Terminal Standard**
```
Given: the repo state after Task 1
When: sourcing scripts/lib/dracula-pro-palette.sh in a fresh shell
Then: DRACULA_PRO_BACKGROUND == "#22212C"
  AND: DRACULA_PRO_FOREGROUND == "#F8F8F2"
  AND: DRACULA_PRO_COMMENT    == "#7970A9"
  AND: DRACULA_PRO_SELECTION  == "#454158"
  AND: DRACULA_PRO_CURSOR     == "#7970A9"
  AND: DRACULA_PRO_ORANGE     == "#FFCA80"
  AND: all 8 ANSI 0–7, all 8 Bright, all 8 Dim slots match spec § 6.3
  AND: DRACULA_PRO_PURPLE equals DRACULA_PRO_BLUE
  AND: DRACULA_PRO_PINK   equals DRACULA_PRO_MAGENTA
```

**AC-gitignore: `/dracula-pro/` is ignored at repo root**
```
Given: repo state after Task 2
When: grep for '/dracula-pro/' in macos-dev/.gitignore
Then: exit code is 0 (entry present)
```

**AC-skip-env: install-macos.sh and install-wsl.sh honour SKIP_DRACULA_PRO=1**
```
Given: ~/dracula-pro/ absent AND SKIP_DRACULA_PRO unset
When: install-*.sh Tier 1 preflight runs
Then: script exits non-zero with "error: ~/dracula-pro/ not found"

Given: ~/dracula-pro/ absent AND SKIP_DRACULA_PRO=1
When: install-*.sh Tier 1 preflight runs
Then: script prints "WARN: SKIP_DRACULA_PRO=1 — Tier 1 theming skipped" and continues
```

**AC-kitty: kitty config includes Dracula Pro generated from palette**
```
Given: repo state + install-macos.sh ran
When: inspecting kitty/kitty.conf
Then: `grep -E '^include\s+~?/.*dracula-pro.*\.conf' kitty/kitty.conf` passes
  AND: kitty/dracula-pro.conf (reconstruction) no longer exists
  AND: install-macos.sh generates $HOME/.config/kitty/dracula-pro.generated.conf
       containing the 16 `color0..color15` lines sourced from the palette file
  AND: the generated file's `background` line is `background            #22212C`
```

**AC-nvim: nvim adopts the Dracula Pro vim plugin via lazy.nvim**
```
Given: repo state after Task 5
When: inspecting nvim/lua/plugins/colorscheme.lua
Then: file contains a lazy.nvim spec with `dir = vim.fn.expand("~/dracula-pro/themes/vim")`
  AND: colorscheme is set to "dracula_pro"
  AND: LazyVim `colorscheme` opt is overridden to "dracula_pro"
```

**AC-vscode: vscode extensions.json swaps catppuccin for Dracula Pro and install-macos.sh installs the .vsix**
```
Given: repo state after Task 6
When: inspecting vscode/extensions.json
Then: "catppuccin.catppuccin-vsc" is absent
  AND: "dracula-theme-pro.theme-dracula-pro" is present
  AND: vscode/settings.json has `"workbench.colorTheme": "Dracula Pro"`
  AND: install-macos.sh contains `code --install-extension "$HOME/dracula-pro/themes/visual-studio-code/dracula-pro.vsix"`
```

**AC-wt: install-wsl.sh splices Dracula Pro scheme into Windows Terminal settings.json**
```
Given: WT settings.json resolvable under /mnt/c/Users/<winuser>/.../LocalState/
When: install-wsl.sh Tier 1 step runs
Then: jq '.schemes[] | select(.name=="Dracula Pro")' settings.json prints one object
  AND: the splice is idempotent — running install-wsl.sh twice does not create duplicates

Given: WT settings.json not resolvable (no /mnt/c mount, or no Packages dir)
When: install-wsl.sh Tier 1 step runs
Then: script prints "WARN: Windows Terminal settings.json not found — copy manually from ~/dracula-pro/themes/windows-terminal/dracula-pro.json"
  AND: exit code is 0 (non-fatal warn, not error)
```

**AC-raycast: raycast theme import is documented in install-macos.sh Next Steps**
```
Given: repo state after Task 8
When: inspecting the Next Steps heredoc of install-macos.sh
Then: the heredoc contains a Raycast step referencing the addToRaycast deep-link for Dracula PRO - Pro
  AND: raycast/dracula-pro.md exists and records the chosen variant (Pro)
```

**AC-ghostty: ghostty config references the Pro theme by path**
```
Given: repo state after Task 9
When: inspecting ghostty/config
Then: `grep -E '^theme\s*=\s*~?/.*dracula-pro/themes/ghostty/pro' ghostty/config` passes
  AND: install-macos.sh symlinks ghostty/config → ~/.config/ghostty/config
```

**AC-aggregate: scripts/test-plan-theming.sh exits 0 and covers every AC above**
```
Given: all tasks complete on a machine with ~/dracula-pro/ present
When: bash scripts/test-plan-theming.sh runs
Then: exit code is 0
  AND: every AC-* above is labelled and checked

Given: ~/dracula-pro/ absent
When: bash scripts/test-plan-theming.sh runs
Then: AC-palette, AC-gitignore, AC-skip-env, AC-kitty (static), AC-nvim, AC-vscode (static), AC-raycast, AC-ghostty static checks still pass
  AND: AC-kitty (generated-file), AC-wt, AC-skip-env (runtime) are reported as SKIPPED with reason "~/dracula-pro absent"
  AND: exit code is 0
```

---

## File Structure

**New files (created by this plan):**
- `scripts/lib/dracula-pro-palette.sh` — single source of truth for Pro hex values; sourced by install scripts, the test script, and future Wave B/C config generators. Verbatim from spec § 6.3.
- `scripts/test-plan-theming.sh` — Wave A ATDD acceptance script; defines shared `check` helper at the top; has a labelled block per AC. Waves B/C will append to this file.
- `nvim/lua/plugins/colorscheme.lua` — LazyVim override plugin spec: local `dir` = `~/dracula-pro/themes/vim`, lazy = false, priority high, sets `colorscheme = "dracula_pro"` and overrides the LazyVim default.
- `ghostty/config` — ghostty config referencing the Pro theme by path.
- `raycast/dracula-pro.md` — documents the chosen Raycast variant (Pro) and the deep-link import instruction; referenced from install-macos.sh Next Steps.

**Modified files:**
- `.gitignore` (repo root: `macos-dev/.gitignore`) — add `/dracula-pro/`.
- `kitty/kitty.conf` — change `include dracula-pro.conf` → `include ~/.config/kitty/dracula-pro.generated.conf`.
- `vscode/extensions.json` — swap `catppuccin.catppuccin-vsc` for `dracula-theme.theme-dracula-pro`.
- `vscode/settings.json` — add `"workbench.colorTheme": "Dracula Pro"`.
- `install-macos.sh` — add: (a) `SKIP_DRACULA_PRO` preflight with loud-fail, (b) kitty generated-conf writer sourcing the palette file, (c) `code --install-extension` for the Pro `.vsix`, (d) ghostty symlink, (e) Raycast Next-Steps entry. Remove the `link kitty/dracula-pro.conf ...` line.
- `install-wsl.sh` — add: (a) `SKIP_DRACULA_PRO` preflight with loud-fail, (b) kitty generated-conf writer (same as macOS), (c) Windows Terminal scheme splice via `jq`. Remove the `link kitty/dracula-pro.conf ...` line.

**Deleted files:**
- `kitty/dracula-pro.conf` — replaced by the generated runtime file sourced from the palette.

**Untouched (out of scope for Wave A):**
- `bash/.bashrc`, `bash/.bash_aliases` — no theming logic added in Wave A.
- `starship/starship.toml`, `tmux/.tmux.conf`, `lazygit/config.yml`, etc. — Wave B (Tier 2) / Wave C (Tier 3).
- `sketchybar/colors.sh` — Wave C audit.
- Any other tool config — no cross-cutting changes in this wave.

---

## Task 1: Create the authoritative palette file (AC-palette)

**Files:**
- Create: `scripts/lib/dracula-pro-palette.sh`

- [ ] **Step 1: Create the palette directory**

Run: `mkdir -p scripts/lib`
Expected: directory exists (no output if already present).

- [ ] **Step 2: Write scripts/lib/dracula-pro-palette.sh (verbatim from spec § 6.3, verified against ~/dracula-pro/design/palette.md Base / Terminal Standard)**

Create `scripts/lib/dracula-pro-palette.sh` with exactly this content:

```bash
# scripts/lib/dracula-pro-palette.sh
#
# Dracula PRO Base / Terminal Standard — single source of truth.
# Values copied verbatim from ~/dracula-pro/design/palette.md,
# section "Color Palette - Terminal Standard / Dracula PRO - Base".
# Facts (hex triples) — not the licensed theme files.

# ANSI 0-7
export DRACULA_PRO_BLACK="#22212C"         # ANSI 0 (= Background)
export DRACULA_PRO_RED="#FF9580"           # ANSI 1
export DRACULA_PRO_GREEN="#8AFF80"         # ANSI 2
export DRACULA_PRO_YELLOW="#FFFF80"        # ANSI 3
export DRACULA_PRO_BLUE="#9580FF"          # ANSI 4  (Base alias: Purple)
export DRACULA_PRO_MAGENTA="#FF80BF"       # ANSI 5  (Base alias: Pink)
export DRACULA_PRO_CYAN="#80FFEA"          # ANSI 6
export DRACULA_PRO_WHITE="#F8F8F2"         # ANSI 7 (= Foreground)

# ANSI 8-15 (Bright)
export DRACULA_PRO_BRIGHT_BLACK="#504C67"  # ANSI 8
export DRACULA_PRO_BRIGHT_RED="#FFAA99"
export DRACULA_PRO_BRIGHT_GREEN="#A2FF99"
export DRACULA_PRO_BRIGHT_YELLOW="#FFFF99"
export DRACULA_PRO_BRIGHT_BLUE="#AA99FF"
export DRACULA_PRO_BRIGHT_MAGENTA="#FF99CC"
export DRACULA_PRO_BRIGHT_CYAN="#99FFEE"
export DRACULA_PRO_BRIGHT_WHITE="#FFFFFF"

# Dim (muted / inactive states)
export DRACULA_PRO_DIM_BLACK="#1B1A23"
export DRACULA_PRO_DIM_RED="#CC7766"
export DRACULA_PRO_DIM_GREEN="#6ECC66"
export DRACULA_PRO_DIM_YELLOW="#CCCC66"
export DRACULA_PRO_DIM_BLUE="#7766CC"
export DRACULA_PRO_DIM_MAGENTA="#CC6699"
export DRACULA_PRO_DIM_CYAN="#66CCBB"
export DRACULA_PRO_DIM_WHITE="#C6C6C2"

# Structural
export DRACULA_PRO_BACKGROUND="#22212C"
export DRACULA_PRO_FOREGROUND="#F8F8F2"
export DRACULA_PRO_COMMENT="#7970A9"
export DRACULA_PRO_SELECTION="#454158"
export DRACULA_PRO_CURSOR="#7970A9"

# Extra semantic accent (Base palette)
export DRACULA_PRO_ORANGE="#FFCA80"

# Non-terminal aliases (used where a tool's theme vocabulary is non-terminal)
export DRACULA_PRO_PURPLE="$DRACULA_PRO_BLUE"     # #9580FF
export DRACULA_PRO_PINK="$DRACULA_PRO_MAGENTA"    # #FF80BF
```

- [ ] **Step 3: Confirm the file sources cleanly**

Run: `bash -c 'set -eu; source scripts/lib/dracula-pro-palette.sh; echo "$DRACULA_PRO_BACKGROUND|$DRACULA_PRO_FOREGROUND|$DRACULA_PRO_ORANGE"'`
Expected: `#22212C|#F8F8F2|#FFCA80`

- [ ] **Step 4: Commit**

```bash
git add scripts/lib/dracula-pro-palette.sh
git commit -m "feat(theming): add Dracula Pro palette (single source of truth)"
```

---

## Task 2: Add `/dracula-pro/` to `.gitignore` (AC-gitignore)

**Files:**
- Modify: `.gitignore` (the `macos-dev/.gitignore` file)

- [ ] **Step 1: Confirm the entry is absent**

Run: `grep -E '^/dracula-pro/?$' .gitignore || echo "absent"`
Expected: `absent`

- [ ] **Step 2: Append a Dracula Pro guard section to `.gitignore`**

Append this block to the end of `.gitignore`:

```
# ── Dracula Pro (licensed — never committed) ─────────────────────────────────
# Safety rail against accidentally committing symlinks, caches, or copies of
# Pro theme content. Pro theme files live at ~/dracula-pro/ per
# docs/design/theming.md § 4.1. Palette hex values (facts) are reproduced in
# scripts/lib/dracula-pro-palette.sh per § 4.1 / § 6.3.
/dracula-pro/
```

- [ ] **Step 3: Confirm the entry is present**

Run: `grep -Fxq '/dracula-pro/' .gitignore && echo "present"`
Expected: `present`

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore(gitignore): ignore /dracula-pro/ (licensed — never committed)"
```

---

## Task 3: Bootstrap the ATDD test script with shared helpers + AC-palette + AC-gitignore (red → green for Tasks 1 and 2)

**Files:**
- Create: `scripts/test-plan-theming.sh`

- [ ] **Step 1: Write the script skeleton with the shared `check` helper**

Create `scripts/test-plan-theming.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# test-plan-theming.sh — acceptance tests for Dracula Pro theming rollout.
#
# Wave A covers the prerequisites and Tier 1 tools (kitty, nvim, vscode,
# windows-terminal, raycast, ghostty). Waves B and C will append to this
# script in later plans.
#
# Usage:
#   bash scripts/test-plan-theming.sh              # safe tests only
#   bash scripts/test-plan-theming.sh --full       # + runtime tests (needs installed tools)
#
# Exits 0 iff every requested check passes. Skipped checks do not count
# as failures.

set -uo pipefail

# ── Self-resolve to macos-dev root ───────────────────────────────────────────
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
MACOS_DEV="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"
cd "$MACOS_DEV" || { echo "ERROR: cannot cd to $MACOS_DEV" >&2; exit 2; }

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)
    PLATFORM="linux"
    [[ -n "${WSL_DISTRO_NAME:-}" ]] && PLATFORM="wsl"
    ;;
  *) echo "ERROR: unsupported platform" >&2; exit 2 ;;
esac

if [[ -t 1 ]]; then
  C_GREEN=$'\033[0;32m' C_RED=$'\033[0;31m' C_YELLOW=$'\033[0;33m' C_RESET=$'\033[0m'
else
  C_GREEN='' C_RED='' C_YELLOW='' C_RESET=''
fi

pass=0
fail=0
skip=0

ok()   { printf "  ${C_GREEN}\u2713${C_RESET} %s\n" "$1"; pass=$((pass + 1)); }
nok()  { printf "  ${C_RED}\u2717${C_RESET} %s\n" "$1"; fail=$((fail + 1)); }
skp()  { printf "  ${C_YELLOW}~${C_RESET} %s (skipped: %s)\n" "$1" "$2"; skip=$((skip + 1)); }

# Shared check() — runs a command; passes if exit 0, fails otherwise.
# Later waves extend this script; this helper stays unchanged.
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else nok "$desc"; fi
}

# Source the palette file so later ACs can assert `$DRACULA_PRO_FOO == "<hex>"`.
# shellcheck source=scripts/lib/dracula-pro-palette.sh
if [[ -f scripts/lib/dracula-pro-palette.sh ]]; then
  # shellcheck disable=SC1091
  source scripts/lib/dracula-pro-palette.sh
fi

DRACULA_PRO_HOME="${DRACULA_PRO_HOME:-$HOME/dracula-pro}"

echo "Wave A acceptance tests"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo "Dracula Pro home: $DRACULA_PRO_HOME $([ -d "$DRACULA_PRO_HOME" ] && echo "(present)" || echo "(ABSENT)")"
echo ""

# ── AC-palette: palette file ships and matches spec § 6.3 ──────────────────
echo "AC-palette: scripts/lib/dracula-pro-palette.sh matches spec"
check "palette file exists"                        test -f scripts/lib/dracula-pro-palette.sh
check "DRACULA_PRO_BLACK      == #22212C"          test "${DRACULA_PRO_BLACK:-}"      = "#22212C"
check "DRACULA_PRO_RED        == #FF9580"          test "${DRACULA_PRO_RED:-}"        = "#FF9580"
check "DRACULA_PRO_GREEN      == #8AFF80"          test "${DRACULA_PRO_GREEN:-}"      = "#8AFF80"
check "DRACULA_PRO_YELLOW     == #FFFF80"          test "${DRACULA_PRO_YELLOW:-}"     = "#FFFF80"
check "DRACULA_PRO_BLUE       == #9580FF"          test "${DRACULA_PRO_BLUE:-}"       = "#9580FF"
check "DRACULA_PRO_MAGENTA    == #FF80BF"          test "${DRACULA_PRO_MAGENTA:-}"    = "#FF80BF"
check "DRACULA_PRO_CYAN       == #80FFEA"          test "${DRACULA_PRO_CYAN:-}"       = "#80FFEA"
check "DRACULA_PRO_WHITE      == #F8F8F2"          test "${DRACULA_PRO_WHITE:-}"      = "#F8F8F2"
check "DRACULA_PRO_BRIGHT_BLACK   == #504C67"      test "${DRACULA_PRO_BRIGHT_BLACK:-}"   = "#504C67"
check "DRACULA_PRO_BRIGHT_RED     == #FFAA99"      test "${DRACULA_PRO_BRIGHT_RED:-}"     = "#FFAA99"
check "DRACULA_PRO_BRIGHT_GREEN   == #A2FF99"      test "${DRACULA_PRO_BRIGHT_GREEN:-}"   = "#A2FF99"
check "DRACULA_PRO_BRIGHT_YELLOW  == #FFFF99"      test "${DRACULA_PRO_BRIGHT_YELLOW:-}"  = "#FFFF99"
check "DRACULA_PRO_BRIGHT_BLUE    == #AA99FF"      test "${DRACULA_PRO_BRIGHT_BLUE:-}"    = "#AA99FF"
check "DRACULA_PRO_BRIGHT_MAGENTA == #FF99CC"      test "${DRACULA_PRO_BRIGHT_MAGENTA:-}" = "#FF99CC"
check "DRACULA_PRO_BRIGHT_CYAN    == #99FFEE"      test "${DRACULA_PRO_BRIGHT_CYAN:-}"    = "#99FFEE"
check "DRACULA_PRO_BRIGHT_WHITE   == #FFFFFF"      test "${DRACULA_PRO_BRIGHT_WHITE:-}"   = "#FFFFFF"
check "DRACULA_PRO_DIM_BLACK     == #1B1A23"       test "${DRACULA_PRO_DIM_BLACK:-}"     = "#1B1A23"
check "DRACULA_PRO_DIM_RED       == #CC7766"       test "${DRACULA_PRO_DIM_RED:-}"       = "#CC7766"
check "DRACULA_PRO_DIM_GREEN     == #6ECC66"       test "${DRACULA_PRO_DIM_GREEN:-}"     = "#6ECC66"
check "DRACULA_PRO_DIM_YELLOW    == #CCCC66"       test "${DRACULA_PRO_DIM_YELLOW:-}"    = "#CCCC66"
check "DRACULA_PRO_DIM_BLUE      == #7766CC"       test "${DRACULA_PRO_DIM_BLUE:-}"      = "#7766CC"
check "DRACULA_PRO_DIM_MAGENTA   == #CC6699"       test "${DRACULA_PRO_DIM_MAGENTA:-}"   = "#CC6699"
check "DRACULA_PRO_DIM_CYAN      == #66CCBB"       test "${DRACULA_PRO_DIM_CYAN:-}"      = "#66CCBB"
check "DRACULA_PRO_DIM_WHITE     == #C6C6C2"       test "${DRACULA_PRO_DIM_WHITE:-}"     = "#C6C6C2"
check "DRACULA_PRO_BACKGROUND == #22212C"          test "${DRACULA_PRO_BACKGROUND:-}" = "#22212C"
check "DRACULA_PRO_FOREGROUND == #F8F8F2"          test "${DRACULA_PRO_FOREGROUND:-}" = "#F8F8F2"
check "DRACULA_PRO_COMMENT    == #7970A9"          test "${DRACULA_PRO_COMMENT:-}"    = "#7970A9"
check "DRACULA_PRO_SELECTION  == #454158"          test "${DRACULA_PRO_SELECTION:-}"  = "#454158"
check "DRACULA_PRO_CURSOR     == #7970A9"          test "${DRACULA_PRO_CURSOR:-}"     = "#7970A9"
check "DRACULA_PRO_ORANGE     == #FFCA80"          test "${DRACULA_PRO_ORANGE:-}"     = "#FFCA80"
check "DRACULA_PRO_PURPLE == DRACULA_PRO_BLUE"     test "${DRACULA_PRO_PURPLE:-}"  = "${DRACULA_PRO_BLUE:-x}"
check "DRACULA_PRO_PINK   == DRACULA_PRO_MAGENTA"  test "${DRACULA_PRO_PINK:-}"    = "${DRACULA_PRO_MAGENTA:-x}"

# ── AC-gitignore: /dracula-pro/ is ignored at repo root ────────────────────
echo ""
echo "AC-gitignore: /dracula-pro/ is listed in .gitignore"
check ".gitignore contains '/dracula-pro/'"  grep -Fxq "/dracula-pro/" .gitignore

echo ""
echo "---------------------------------------------------------------"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x scripts/test-plan-theming.sh`
Expected: no output.

- [ ] **Step 3: Run the script — AC-palette and AC-gitignore should pass**

Run: `bash scripts/test-plan-theming.sh`
Expected: all AC-palette and AC-gitignore checks pass. `Failed: 0`. Exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/test-plan-theming.sh
git commit -m "test(theming): scaffold Wave A acceptance script (AC-palette, AC-gitignore)"
```

---

## Task 4: Add SKIP_DRACULA_PRO preflight to install-macos.sh and install-wsl.sh (AC-skip-env)

The preflight sources the palette file (proving repo integrity) and then gates Tier 1 on `~/dracula-pro/` presence. Behaviour:

- `~/dracula-pro/` present → set `DRACULA_PRO_OK=1`, continue.
- `~/dracula-pro/` absent AND `SKIP_DRACULA_PRO=1` → warn, set `DRACULA_PRO_OK=0`, continue (Tier 1 steps later gate on `DRACULA_PRO_OK`).
- `~/dracula-pro/` absent AND `SKIP_DRACULA_PRO` unset → error and exit 1.

**Files:**
- Modify: `install-macos.sh`
- Modify: `install-wsl.sh`
- Modify: `scripts/test-plan-theming.sh` (append AC-skip-env block)

- [ ] **Step 1: Append AC-skip-env checks to the test script**

Open `scripts/test-plan-theming.sh`. Find the block that ends with:

```bash
check ".gitignore contains '/dracula-pro/'"  grep -Fxq "/dracula-pro/" .gitignore
```

Append immediately after it (before the summary line `echo ""`, `echo "---..."`, `printf`, `(( fail == 0 ))`):

```bash

# ── AC-skip-env: install scripts honour SKIP_DRACULA_PRO ──────────────────
echo ""
echo "AC-skip-env: install scripts handle SKIP_DRACULA_PRO + loud-fail"
check "install-macos.sh sources the palette file"             \
  grep -qE 'source .*scripts/lib/dracula-pro-palette\.sh' install-macos.sh
check "install-macos.sh checks for ~/dracula-pro/ presence"   \
  grep -qE 'test -d .*\$HOME/dracula-pro|\[\[ -d "\$HOME/dracula-pro" \]\]' install-macos.sh
check "install-macos.sh references SKIP_DRACULA_PRO"          \
  grep -q 'SKIP_DRACULA_PRO' install-macos.sh
check "install-macos.sh has loud-fail error message"          \
  grep -qE 'error: ~/dracula-pro/ not found' install-macos.sh
check "install-wsl.sh sources the palette file"               \
  grep -qE 'source .*scripts/lib/dracula-pro-palette\.sh' install-wsl.sh
check "install-wsl.sh checks for ~/dracula-pro/ presence"     \
  grep -qE 'test -d .*\$HOME/dracula-pro|\[\[ -d "\$HOME/dracula-pro" \]\]' install-wsl.sh
check "install-wsl.sh references SKIP_DRACULA_PRO"            \
  grep -q 'SKIP_DRACULA_PRO' install-wsl.sh
check "install-wsl.sh has loud-fail error message"            \
  grep -qE 'error: ~/dracula-pro/ not found' install-wsl.sh

# Runtime: run the preflight in isolation with HOME redirected and confirm exit codes.
if [[ "$FULL" == true ]]; then
  tmphome="$(mktemp -d)"
  # Absent + unset → must fail non-zero with the error message
  out_absent_unset="$(HOME="$tmphome" SKIP_DRACULA_PRO= bash -c '
    set +e
    source scripts/lib/dracula-pro-palette.sh
    if [[ ! -d "$HOME/dracula-pro" ]] && [[ -z "${SKIP_DRACULA_PRO:-}" ]]; then
      echo "error: ~/dracula-pro/ not found. Install Dracula Pro from draculatheme.com/pro before running this script." >&2
      exit 1
    fi
  ' 2>&1)"
  if printf '%s' "$out_absent_unset" | grep -q 'error: ~/dracula-pro/ not found'; then
    ok "preflight: absent + SKIP unset → error"
  else
    nok "preflight: absent + SKIP unset → error (got: $out_absent_unset)"
  fi

  # Absent + SKIP=1 → must warn and exit 0
  out_absent_skip="$(HOME="$tmphome" SKIP_DRACULA_PRO=1 bash -c '
    set -e
    source scripts/lib/dracula-pro-palette.sh
    if [[ ! -d "$HOME/dracula-pro" ]]; then
      if [[ "${SKIP_DRACULA_PRO:-0}" == 1 ]]; then
        echo "WARN: SKIP_DRACULA_PRO=1 — Tier 1 theming skipped" >&2
      else
        echo "error: ~/dracula-pro/ not found" >&2
        exit 1
      fi
    fi
  ' 2>&1)"
  if printf '%s' "$out_absent_skip" | grep -q 'SKIP_DRACULA_PRO=1 — Tier 1 theming skipped'; then
    ok "preflight: absent + SKIP=1 → warn + continue"
  else
    nok "preflight: absent + SKIP=1 → warn + continue (got: $out_absent_skip)"
  fi
  rm -rf "$tmphome"
else
  skp "preflight runtime (absent + unset)" "safe mode"
  skp "preflight runtime (absent + SKIP=1)" "safe mode"
fi
```

- [ ] **Step 2: Run tests to confirm AC-skip-env static checks fail**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-skip-env static checks fail (install scripts don't yet reference the palette file or `SKIP_DRACULA_PRO`).

- [ ] **Step 3: Add the preflight block to install-macos.sh**

Open `install-macos.sh`. Find the line `export DOTFILES` (follows the self-resolve block, around line 36). Immediately after `export DOTFILES`, insert this block:

```bash

# ── Dracula Pro preflight (Wave A) ───────────────────────────────────────────
# Tier 1 theming requires ~/dracula-pro/ present. On CI or machines without a
# Pro licence, set SKIP_DRACULA_PRO=1 to skip Tier 1 steps and continue.
# See macos-dev/docs/design/theming.md § 4.3.
# shellcheck source=scripts/lib/dracula-pro-palette.sh
source "$DOTFILES/scripts/lib/dracula-pro-palette.sh"
DRACULA_PRO_OK=0
if [[ -d "$HOME/dracula-pro" ]]; then
  DRACULA_PRO_OK=1
elif [[ "${SKIP_DRACULA_PRO:-0}" == 1 ]]; then
  printf "WARN: SKIP_DRACULA_PRO=1 — Tier 1 theming skipped\n" >&2
else
  printf "error: ~/dracula-pro/ not found. Install Dracula Pro from draculatheme.com/pro before running this script.\n" >&2
  printf "       (To skip Tier 1 on CI, rerun with SKIP_DRACULA_PRO=1 in the environment.)\n" >&2
  exit 1
fi
export DRACULA_PRO_OK
```

- [ ] **Step 4: Add the same preflight block to install-wsl.sh**

Open `install-wsl.sh`. Find the line `export DOTFILES` (same position, around line 30). Immediately after it, insert the identical block (re-typed verbatim so no cross-task reference is needed):

```bash

# ── Dracula Pro preflight (Wave A) ───────────────────────────────────────────
# Tier 1 theming requires ~/dracula-pro/ present. On CI or machines without a
# Pro licence, set SKIP_DRACULA_PRO=1 to skip Tier 1 steps and continue.
# See macos-dev/docs/design/theming.md § 4.3.
# shellcheck source=scripts/lib/dracula-pro-palette.sh
source "$DOTFILES/scripts/lib/dracula-pro-palette.sh"
DRACULA_PRO_OK=0
if [[ -d "$HOME/dracula-pro" ]]; then
  DRACULA_PRO_OK=1
elif [[ "${SKIP_DRACULA_PRO:-0}" == 1 ]]; then
  printf "WARN: SKIP_DRACULA_PRO=1 — Tier 1 theming skipped\n" >&2
else
  printf "error: ~/dracula-pro/ not found. Install Dracula Pro from draculatheme.com/pro before running this script.\n" >&2
  printf "       (To skip Tier 1 on CI, rerun with SKIP_DRACULA_PRO=1 in the environment.)\n" >&2
  exit 1
fi
export DRACULA_PRO_OK
```

- [ ] **Step 5: Verify both install scripts parse**

Run: `bash -n install-macos.sh && bash -n install-wsl.sh && echo ok`
Expected: `ok`

- [ ] **Step 6: Run tests to confirm AC-skip-env static checks now pass**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-skip-env static checks pass. Runtime checks skipped in safe mode. `Failed: 0`. Exit 0.

- [ ] **Step 7: Commit**

```bash
git add install-macos.sh install-wsl.sh scripts/test-plan-theming.sh
git commit -m "feat(install): SKIP_DRACULA_PRO preflight with loud-fail (Wave A)"
```

---

## Task 5: Switch nvim to Dracula Pro via lazy.nvim local `dir` plugin (AC-nvim)

lazy.nvim supports local-directory plugins via the `dir = <path>` field. We create `nvim/lua/plugins/colorscheme.lua` returning a plugin spec that loads `~/dracula-pro/themes/vim` and overrides LazyVim's default colorscheme opt.

**Files:**
- Create: `nvim/lua/plugins/colorscheme.lua`
- Modify: `scripts/test-plan-theming.sh` (append AC-nvim block)

- [ ] **Step 1: Append AC-nvim checks to the test script**

Open `scripts/test-plan-theming.sh`. Find the end of the AC-skip-env block (the last `skp "preflight runtime..."` line inside the `else` branch). Append immediately after `fi` that closes the `if [[ "$FULL" == true ]]` block:

```bash

# ── AC-nvim: nvim adopts the Dracula Pro vim plugin via lazy.nvim ─────────
echo ""
echo "AC-nvim: nvim loads Dracula Pro via lazy.nvim local dir plugin"
check "nvim/lua/plugins/colorscheme.lua exists"              \
  test -f nvim/lua/plugins/colorscheme.lua
check "colorscheme.lua uses local dir for dracula-pro/themes/vim" \
  grep -qE 'dir\s*=\s*vim\.fn\.expand\("~/dracula-pro/themes/vim"\)' nvim/lua/plugins/colorscheme.lua
check "colorscheme.lua sets colorscheme = dracula_pro"       \
  grep -qE 'colorscheme\s*=\s*"dracula_pro"' nvim/lua/plugins/colorscheme.lua
check "colorscheme.lua overrides LazyVim default colorscheme" \
  grep -qE 'LazyVim.*colorscheme|opts.*colorscheme' nvim/lua/plugins/colorscheme.lua
```

- [ ] **Step 2: Run tests to confirm AC-nvim fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-nvim checks fail because `nvim/lua/plugins/colorscheme.lua` does not exist yet.

- [ ] **Step 3: Create nvim/lua/plugins/colorscheme.lua**

Create `nvim/lua/plugins/colorscheme.lua` with exactly this content:

```lua
-- colorscheme.lua — Dracula Pro via lazy.nvim local `dir` plugin
-- See macos-dev/docs/design/theming.md § 3.1 Wave A.
--
-- Tier 1: Pro ready-made vim plugin from ~/dracula-pro/themes/vim.
-- Loaded with `lazy = false` + high priority so it is applied before any
-- LazyVim plugin resolves colours. We also override the LazyVim default
-- colorscheme opt so `:LazyVim` treats "dracula_pro" as the active theme.

return {
  -- 1. Ship the Pro vim plugin to lazy.nvim as a local-directory plugin.
  {
    dir = vim.fn.expand("~/dracula-pro/themes/vim"),
    name = "dracula-pro",
    lazy = false,
    priority = 1000,
    config = function()
      -- The plugin registers a `dracula_pro` colorscheme (see
      -- ~/dracula-pro/themes/vim/colors/dracula_pro.vim).
      vim.cmd.colorscheme("dracula_pro")
    end,
  },

  -- 2. Override the LazyVim default colorscheme opt so LazyVim's startup
  --    colorscheme switch resolves to dracula_pro.
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "dracula_pro",
    },
  },
}
```

- [ ] **Step 4: Run tests to confirm AC-nvim passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-nvim checks pass. `Failed: 0`. Exit 0.

- [ ] **Step 5: Commit**

```bash
git add nvim/lua/plugins/colorscheme.lua scripts/test-plan-theming.sh
git commit -m "feat(nvim): load Dracula Pro via lazy.nvim local dir plugin (Wave A)"
```

---

## Task 6: Switch VSCode to Dracula Pro .vsix and theme setting (AC-vscode)

**Files:**
- Modify: `vscode/extensions.json`
- Modify: `vscode/settings.json`
- Modify: `install-macos.sh` (add `code --install-extension` call)
- Modify: `scripts/test-plan-theming.sh` (append AC-vscode block)

- [ ] **Step 1: Append AC-vscode checks to the test script**

Open `scripts/test-plan-theming.sh`. Append after the AC-nvim block (before the summary):

```bash

# ── AC-vscode: Dracula Pro replaces Catppuccin in vscode ──────────────────
echo ""
echo "AC-vscode: vscode uses Dracula Pro (.vsix + colorTheme setting)"
check "extensions.json does NOT include catppuccin.catppuccin-vsc" \
  bash -c '! grep -q "catppuccin.catppuccin-vsc" vscode/extensions.json'
check "extensions.json includes dracula-theme-pro.theme-dracula-pro" \
  grep -q '"dracula-theme-pro.theme-dracula-pro"' vscode/extensions.json
check "settings.json sets workbench.colorTheme = Dracula Pro"   \
  grep -qE '"workbench\.colorTheme"\s*:\s*"Dracula Pro"' vscode/settings.json
check "install-macos.sh installs the Pro .vsix via code CLI"    \
  grep -qE 'code --install-extension\s+.*dracula-pro\.vsix' install-macos.sh
```

- [ ] **Step 2: Run tests to confirm AC-vscode fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-vscode checks fail.

- [ ] **Step 3: Read current vscode/extensions.json**

Run: `cat vscode/extensions.json`
Expected: see the existing JSON with `"catppuccin.catppuccin-vsc"` entry.

- [ ] **Step 4: Rewrite vscode/extensions.json — swap catppuccin for Dracula Pro**

Overwrite `vscode/extensions.json` with exactly:

```json
{
  "recommendations": [
    "charliermarsh.ruff",
    "ms-python.python",
    "ms-python.vscode-pylance",
    "golang.go",
    "hashicorp.terraform",
    "redhat.vscode-yaml",
    "github.vscode-github-actions",
    "DavidAnson.vscode-markdownlint",
    "yzhang.markdown-all-in-one",
    "timonwong.shellcheck",
    "mkhl.shfmt",
    "eamodio.gitlens",
    "mhutchie.git-graph",
    "github.vscode-codeql",
    "gitleaks.gitleaks",
    "ms-vscode-remote.remote-wsl",
    "ms-vscode-remote.remote-containers",
    "esbenp.prettier-vscode",
    "dracula-theme-pro.theme-dracula-pro",
    "EditorConfig.EditorConfig",
    "streetsidesoftware.code-spell-checker"
  ]
}
```

- [ ] **Step 5: Read current vscode/settings.json**

Run: `cat vscode/settings.json`
Expected: see the existing settings JSON. Note the top-level key order so the diff remains minimal.

- [ ] **Step 6: Add `"workbench.colorTheme": "Dracula Pro"` to vscode/settings.json**

Use the Edit tool to add (not replace) a `"workbench.colorTheme"` key. Insert it immediately after the opening `{` line, as the first key. If a `"workbench.colorTheme"` key already exists with a different value, replace its value with `"Dracula Pro"`.

Concrete command to sanity-check the file validates as JSON:

Run: `python3 -c 'import json; json.load(open("vscode/settings.json"))' && echo ok`
Expected: `ok`

- [ ] **Step 7: Add `code --install-extension` to install-macos.sh**

Open `install-macos.sh`. Find the block that starts with `# vscode (Plan 12) — macOS settings path` (around line 364). Immediately after the two `link vscode/...` lines, insert:

```bash

# vscode — Dracula Pro .vsix (Wave A Tier 1). Only attempt if ~/dracula-pro/
# is present (DRACULA_PRO_OK=1) and `code` CLI is available. `code
# --install-extension` is idempotent: running with the same .vsix is a
# no-op once installed.
if [[ "${DRACULA_PRO_OK:-0}" == 1 ]] && command -v code &>/dev/null; then
  VSIX_PATH="$HOME/dracula-pro/themes/visual-studio-code/dracula-pro.vsix"
  if [[ -f "$VSIX_PATH" ]]; then
    log "installing Dracula Pro vscode extension"
    code --install-extension "$VSIX_PATH" || warn "vscode extension install failed (non-fatal)"
  else
    warn "Dracula Pro .vsix not found at $VSIX_PATH — skipping vscode theme install"
  fi
elif [[ "${DRACULA_PRO_OK:-0}" != 1 ]]; then
  warn "DRACULA_PRO_OK=0 — skipping vscode Pro .vsix install"
else
  warn "code CLI not on PATH — install vscode or run 'Shell Command: Install code command in PATH' from the command palette"
fi
```

- [ ] **Step 8: Verify install-macos.sh parses**

Run: `bash -n install-macos.sh && echo ok`
Expected: `ok`

- [ ] **Step 9: Run tests to confirm AC-vscode passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-vscode checks pass. `Failed: 0`. Exit 0.

- [ ] **Step 10: Commit**

```bash
git add vscode/extensions.json vscode/settings.json install-macos.sh scripts/test-plan-theming.sh
git commit -m "feat(vscode): swap Catppuccin for Dracula Pro .vsix (Wave A Tier 1)"
```

---

## Task 7: Windows Terminal scheme splice in install-wsl.sh (AC-wt)

Windows Terminal stores settings at `/mnt/c/Users/<WINUSER>/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json` (the `*` is a hash segment). We resolve the path via glob, then use `jq` to splice the Pro scheme into `.schemes` idempotently by matching on `.name == "Dracula Pro"`.

**Files:**
- Modify: `install-wsl.sh` (add WT splice step)
- Modify: `scripts/test-plan-theming.sh` (append AC-wt block)

- [ ] **Step 1: Append AC-wt checks to the test script**

Open `scripts/test-plan-theming.sh`. Append after the AC-vscode block:

```bash

# ── AC-wt: install-wsl.sh splices Dracula Pro scheme into WT settings ─────
echo ""
echo "AC-wt: install-wsl.sh splices Dracula Pro scheme into Windows Terminal"
check "install-wsl.sh references the Pro WT scheme JSON"      \
  grep -qE 'dracula-pro/themes/windows-terminal/dracula-pro\.json' install-wsl.sh
check "install-wsl.sh splices via jq (schemes array)"         \
  grep -qE 'jq .*schemes' install-wsl.sh
check "install-wsl.sh warns on absent WT settings.json"       \
  grep -qE 'Windows Terminal settings\.json not found' install-wsl.sh
check "install-wsl.sh WT splice is guarded by DRACULA_PRO_OK" \
  grep -qE 'DRACULA_PRO_OK.*==.*1' install-wsl.sh

# Runtime idempotency check — only runs on WSL with a real WT settings.json
if [[ "$FULL" == true ]] && [[ "$PLATFORM" == "wsl" ]] && [[ "${DRACULA_PRO_OK:-0}" == 1 ]]; then
  wt_glob="/mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json"
  # shellcheck disable=SC2086
  wt_path="$(compgen -G $wt_glob 2>/dev/null | head -n1 || true)"
  if [[ -n "$wt_path" ]] && command -v jq &>/dev/null; then
    bash install-wsl.sh >/tmp/wt-install-1.log 2>&1 || true
    bash install-wsl.sh >/tmp/wt-install-2.log 2>&1 || true
    count="$(jq '[.schemes[] | select(.name=="Dracula Pro")] | length' "$wt_path" 2>/dev/null || echo 0)"
    if [[ "$count" == "1" ]]; then
      ok "WT splice is idempotent (exactly 1 Dracula Pro scheme)"
    else
      nok "WT splice is idempotent (expected 1, got $count)"
    fi
  else
    skp "WT splice idempotency" "no WT settings.json or no jq"
  fi
else
  skp "WT splice idempotency" "not WSL/full-mode or Pro absent"
fi
```

- [ ] **Step 2: Run tests to confirm AC-wt fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-wt static checks fail.

- [ ] **Step 3: Add the WT splice block to install-wsl.sh**

Open `install-wsl.sh`. Find the line `# ── Step 5: Next steps ───` (around line 432). Immediately before that line, insert:

```bash

# ── Wave A Tier 1: Windows Terminal scheme splice ────────────────────────
# Splices ~/dracula-pro/themes/windows-terminal/dracula-pro.json into
# Windows Terminal's schemes[] array. Idempotent via .name == "Dracula Pro".
# See macos-dev/docs/design/theming.md § 4.2.
if [[ "${DRACULA_PRO_OK:-0}" == 1 ]]; then
  wt_scheme_src="$HOME/dracula-pro/themes/windows-terminal/dracula-pro.json"
  wt_settings_glob="/mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json"
  # shellcheck disable=SC2086
  wt_settings="$(compgen -G $wt_settings_glob 2>/dev/null | head -n1 || true)"

  if [[ -z "$wt_settings" ]]; then
    warn "Windows Terminal settings.json not found — copy manually from $wt_scheme_src"
  elif ! command -v jq &>/dev/null; then
    warn "jq not on PATH — install jq (apt install -y jq) then rerun install-wsl.sh"
    warn "Windows Terminal settings.json not found (skipped splice: no jq)"
  elif [[ ! -f "$wt_scheme_src" ]]; then
    warn "Dracula Pro WT scheme not found at $wt_scheme_src — skipping WT splice"
  else
    log "splicing Dracula Pro scheme into $wt_settings"
    tmp="$(mktemp)"
    # Remove any existing "Dracula Pro" scheme, then append the fresh one.
    jq --slurpfile new "$wt_scheme_src" '
      .schemes = ((.schemes // []) | map(select(.name != "Dracula Pro"))) + $new
    ' "$wt_settings" > "$tmp"
    # Back up once per day; never overwrite an existing backup.
    bak="${wt_settings}.bak.$(date +%Y%m%d)"
    [[ -f "$bak" ]] || cp "$wt_settings" "$bak"
    cp "$tmp" "$wt_settings"
    rm -f "$tmp"
    printf "  spliced   %s\n" "$wt_settings"
  fi
else
  warn "DRACULA_PRO_OK=0 — skipping Windows Terminal scheme splice"
fi
```

- [ ] **Step 4: Verify install-wsl.sh parses**

Run: `bash -n install-wsl.sh && echo ok`
Expected: `ok`

- [ ] **Step 5: Run tests to confirm AC-wt static checks pass**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-wt static checks pass. Runtime splice idempotency skipped in safe mode / non-WSL. `Failed: 0`. Exit 0.

- [ ] **Step 6: Commit**

```bash
git add install-wsl.sh scripts/test-plan-theming.sh
git commit -m "feat(install-wsl): splice Dracula Pro scheme into Windows Terminal (Wave A)"
```

---

## Task 8: Raycast theme documentation + install-macos.sh Next Steps (AC-raycast)

**Files:**
- Create: `raycast/dracula-pro.md`
- Modify: `install-macos.sh` (Next Steps heredoc)
- Modify: `scripts/test-plan-theming.sh` (append AC-raycast block)

- [ ] **Step 1: Append AC-raycast checks to the test script**

Open `scripts/test-plan-theming.sh`. Append after the AC-wt block:

```bash

# ── AC-raycast: Raycast theme import is documented ────────────────────────
echo ""
echo "AC-raycast: install-macos.sh Next Steps documents Raycast import"
check "raycast/dracula-pro.md exists"                         \
  test -f raycast/dracula-pro.md
check "raycast/dracula-pro.md records chosen variant (Pro)"   \
  grep -qE 'Dracula PRO\s*-\s*Pro|variant.*Pro' raycast/dracula-pro.md
check "install-macos.sh Next Steps mentions Raycast + Dracula Pro" \
  bash -c "awk '/^Next steps:/,/^EOF$/' install-macos.sh | grep -qi 'Raycast.*Dracula Pro'"
check "install-macos.sh Next Steps contains addToRaycast deep-link" \
  grep -qE 'https://themes\.ray\.so' install-macos.sh
```

- [ ] **Step 2: Run tests to confirm AC-raycast fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-raycast checks fail.

- [ ] **Step 3: Create raycast/dracula-pro.md**

Create `raycast/dracula-pro.md` with exactly this content:

```markdown
# Raycast — Dracula Pro theme (Wave A Tier 1)

## Chosen variant

**Dracula PRO - Pro** (dark, canonical Base palette matching
`~/dracula-pro/design/palette.md` § "Color Palette - Terminal Standard /
Dracula PRO - Base"). Other Pro variants (Alucard, Blade, Buffy, Lincoln,
Morbius, Van Helsing) are out of scope for Wave A — see
`macos-dev/docs/design/theming.md` § 1.3.

## First-run import

Raycast has no CLI theme install. From a macOS browser, open the
`addToRaycast` deep-link below. Raycast will prompt to import the theme,
then activate it under Raycast Preferences → Appearance → Theme.

- Dracula PRO - Pro:
  https://themes.ray.so?version=1&name=Dracula%20PRO%20-%20Pro&author=Lucas%20de%20Fran%C3%A7a&authorUsername=luxonauta&colors=%2322212C,%2322212C,%23F8F8F2,%237970A9,%23454158,%23FFA680,%23FFCA80,%23FFFF80,%238AFF80,%2380FFEA,%239580FF,%23FF80BF&appearance=dark&addToRaycast

The source JSON reference (for manual import when Raycast adds JSON
import): `~/dracula-pro/themes/raycast/json-files/pro.json`.

## Verification

Raycast → Preferences → Appearance → Theme shows "Dracula PRO - Pro" as
the active theme.
```

- [ ] **Step 4: Add the Raycast step to install-macos.sh Next Steps heredoc**

Open `install-macos.sh`. Find the heredoc that starts with `cat <<EOF` (right after `log "install complete"`, around line 434). Within the numbered list, find the last numbered item and append a new item at the end (keep numbering consistent — inspect the file and pick the next integer):

```
  N. Raycast — Dracula Pro theme (Wave A Tier 1):
     Open this URL in a macOS browser to import the "Dracula PRO - Pro" theme
     into Raycast, then set it in Raycast Preferences -> Appearance -> Theme:
       https://themes.ray.so?version=1&name=Dracula%20PRO%20-%20Pro&author=Lucas%20de%20Fran%C3%A7a&authorUsername=luxonauta&colors=%2322212C,%2322212C,%23F8F8F2,%237970A9,%23454158,%23FFA680,%23FFCA80,%23FFFF80,%238AFF80,%2380FFEA,%239580FF,%23FF80BF&appearance=dark&addToRaycast
     See raycast/dracula-pro.md for variant details and rationale.
```

Replace `N` with the next integer after the last existing step. Use the Edit tool with the closing `EOF` line as an anchor so the new block is inserted directly above it.

- [ ] **Step 5: Verify install-macos.sh parses**

Run: `bash -n install-macos.sh && echo ok`
Expected: `ok`

- [ ] **Step 6: Run tests to confirm AC-raycast passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-raycast checks pass. `Failed: 0`. Exit 0.

- [ ] **Step 7: Commit**

```bash
git add raycast/dracula-pro.md install-macos.sh scripts/test-plan-theming.sh
git commit -m "feat(raycast): document Dracula Pro (variant: Pro) import step (Wave A)"
```

---

## Task 9: Ghostty config referencing the Pro theme (AC-ghostty)

**Files:**
- Create: `ghostty/config`
- Modify: `install-macos.sh` (add `link ghostty/config …`)
- Modify: `scripts/test-plan-theming.sh` (append AC-ghostty block)

- [ ] **Step 1: Append AC-ghostty checks to the test script**

Open `scripts/test-plan-theming.sh`. Append after the AC-raycast block:

```bash

# ── AC-ghostty: ghostty config references Pro theme by path ───────────────
echo ""
echo "AC-ghostty: ghostty uses ~/dracula-pro/themes/ghostty/pro"
check "ghostty/config exists"                                 \
  test -f ghostty/config
check "ghostty/config sets theme to Pro file"                 \
  grep -qE '^theme\s*=\s*~?/.*dracula-pro/themes/ghostty/pro' ghostty/config
check "install-macos.sh symlinks ghostty/config"              \
  grep -qE 'link\s+ghostty/config\s+\.config/ghostty/config' install-macos.sh
```

- [ ] **Step 2: Run tests to confirm AC-ghostty fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-ghostty checks fail.

- [ ] **Step 3: Create ghostty/config**

Create `ghostty/config` with exactly this content:

```
# ghostty/config — terminal emulator configuration
# See macos-dev/docs/design/theming.md § 3.1 Wave A.
#
# Tier 1 theming: Pro ready-made ghostty theme from ~/dracula-pro/themes/.
# Ghostty supports the `theme = <path>` directive natively — no include-file
# generation needed (cf. kitty in Task 10).

font-family = JetBrainsMono Nerd Font
font-size   = 13
theme       = ~/dracula-pro/themes/ghostty/pro
```

- [ ] **Step 4: Add ghostty symlink to install-macos.sh**

Open `install-macos.sh`. Find the kitty symlink lines (around line 309, `link kitty/kitty.conf …`). Immediately after the kitty block (before the tmux block `link tmux/.tmux.conf …`), insert:

```bash

# ghostty (Wave A Tier 1) — theme referenced directly via `theme = ~/dracula-pro/...`
link ghostty/config  .config/ghostty/config
```

- [ ] **Step 5: Verify install-macos.sh parses**

Run: `bash -n install-macos.sh && echo ok`
Expected: `ok`

- [ ] **Step 6: Run tests to confirm AC-ghostty passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-ghostty checks pass. `Failed: 0`. Exit 0.

- [ ] **Step 7: Commit**

```bash
git add ghostty/config install-macos.sh scripts/test-plan-theming.sh
git commit -m "feat(ghostty): add config referencing Dracula Pro theme (Wave A Tier 1)"
```

---

## Task 10: Switch kitty to generated include + delete reconstruction (AC-kitty)

Kitty needs a kitty-format `color0..color15`/`background`/`foreground` file. `~/dracula-pro/themes/` ships no such file (only the ghostty-format `pro`). We generate the kitty file at install time under `~/.config/kitty/dracula-pro.generated.conf` from `scripts/lib/dracula-pro-palette.sh` (palette facts are authorised to be reproduced; see spec § 4.1). `kitty/kitty.conf` switches from `include dracula-pro.conf` to `include ~/.config/kitty/dracula-pro.generated.conf`. The old `kitty/dracula-pro.conf` reconstruction is deleted per § 4.4.

**Files:**
- Modify: `kitty/kitty.conf` (change include path)
- Delete: `kitty/dracula-pro.conf`
- Modify: `install-macos.sh` (add generator, remove old symlink)
- Modify: `install-wsl.sh` (same)
- Modify: `scripts/test-plan-theming.sh` (append AC-kitty block)

- [ ] **Step 1: Append AC-kitty checks to the test script**

Open `scripts/test-plan-theming.sh`. Append after the AC-ghostty block:

```bash

# ── AC-kitty: kitty consumes Pro theme via generated include file ─────────
echo ""
echo "AC-kitty: kitty includes Dracula Pro (generated at install time)"
check "kitty/kitty.conf includes dracula-pro.generated.conf"  \
  grep -qE '^include\s+~?/.*dracula-pro\.generated\.conf' kitty/kitty.conf
check "kitty/dracula-pro.conf (reconstruction) is removed"    \
  bash -c '! test -f kitty/dracula-pro.conf'
check "install-macos.sh generates the kitty include file"     \
  grep -qE 'dracula-pro\.generated\.conf' install-macos.sh
check "install-wsl.sh generates the kitty include file"       \
  grep -qE 'dracula-pro\.generated\.conf' install-wsl.sh
check "install-macos.sh no longer symlinks kitty/dracula-pro.conf" \
  bash -c '! grep -qE "link\s+kitty/dracula-pro\.conf" install-macos.sh'
check "install-wsl.sh no longer symlinks kitty/dracula-pro.conf"   \
  bash -c '! grep -qE "link\s+kitty/dracula-pro\.conf" install-wsl.sh'

# Runtime check: after install, the generated file must exist and contain
# the canonical palette lines.
if [[ "$FULL" == true ]] && [[ "${DRACULA_PRO_OK:-0}" == 1 ]]; then
  gen="$HOME/.config/kitty/dracula-pro.generated.conf"
  if [[ -f "$gen" ]]; then
    check "generated kitty file: background #22212C" \
      grep -qE '^background\s+#22212C' "$gen"
    check "generated kitty file: foreground #F8F8F2" \
      grep -qE '^foreground\s+#F8F8F2' "$gen"
    check "generated kitty file has 16 color lines"  \
      bash -c "[[ \"\$(grep -cE '^color(1?[0-9])\\s+#' \"$gen\")\" == 16 ]]"
  else
    skp "generated kitty file" "install-macos.sh has not been run"
  fi
else
  skp "generated kitty file runtime checks" "safe mode or Pro absent"
fi
```

- [ ] **Step 2: Run tests to confirm AC-kitty fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-kitty static checks fail (the old `include dracula-pro.conf` line is still there; the reconstruction file still exists; install scripts still reference the old path).

- [ ] **Step 3: Update kitty/kitty.conf**

Open `kitty/kitty.conf`. Replace the line:

```
include dracula-pro.conf
```

with:

```
include ~/.config/kitty/dracula-pro.generated.conf
```

- [ ] **Step 4: Delete kitty/dracula-pro.conf**

Run: `git rm kitty/dracula-pro.conf`
Expected: file removed from index and working tree.

- [ ] **Step 5: Add the kitty generator to install-macos.sh and remove the old symlink**

Open `install-macos.sh`. Find the lines:

```
link kitty/kitty.conf        .config/kitty/kitty.conf
link kitty/dracula-pro.conf  .config/kitty/dracula-pro.conf
```

Replace the two lines with:

```bash
link kitty/kitty.conf        .config/kitty/kitty.conf

# kitty Dracula Pro theme (Wave A Tier 1) — ~/dracula-pro/themes/ ships no
# kitty-native file, so generate one from the palette file at install time.
# Palette hex values are facts (spec § 4.1 — reproduction authorised).
if [[ "${DRACULA_PRO_OK:-0}" == 1 ]]; then
  mkdir -p "$HOME/.config/kitty"
  gen="$HOME/.config/kitty/dracula-pro.generated.conf"
  cat > "$gen" <<KITTYEOF
# AUTO-GENERATED by install-macos.sh from scripts/lib/dracula-pro-palette.sh
# Do not edit by hand — edits are overwritten on next install.
# Source: macos-dev/docs/design/theming.md § 3.1, § 6.3.

background            $DRACULA_PRO_BACKGROUND
foreground            $DRACULA_PRO_FOREGROUND
selection_foreground  $DRACULA_PRO_FOREGROUND
selection_background  $DRACULA_PRO_SELECTION
cursor                $DRACULA_PRO_CURSOR
cursor_text_color     $DRACULA_PRO_BACKGROUND

url_color             $DRACULA_PRO_CYAN

active_tab_foreground   $DRACULA_PRO_BACKGROUND
active_tab_background   $DRACULA_PRO_PURPLE
inactive_tab_foreground $DRACULA_PRO_FOREGROUND
inactive_tab_background $DRACULA_PRO_SELECTION

color0  $DRACULA_PRO_BLACK
color1  $DRACULA_PRO_RED
color2  $DRACULA_PRO_GREEN
color3  $DRACULA_PRO_YELLOW
color4  $DRACULA_PRO_BLUE
color5  $DRACULA_PRO_MAGENTA
color6  $DRACULA_PRO_CYAN
color7  $DRACULA_PRO_WHITE
color8  $DRACULA_PRO_BRIGHT_BLACK
color9  $DRACULA_PRO_BRIGHT_RED
color10 $DRACULA_PRO_BRIGHT_GREEN
color11 $DRACULA_PRO_BRIGHT_YELLOW
color12 $DRACULA_PRO_BRIGHT_BLUE
color13 $DRACULA_PRO_BRIGHT_MAGENTA
color14 $DRACULA_PRO_BRIGHT_CYAN
color15 $DRACULA_PRO_BRIGHT_WHITE
KITTYEOF
  printf "  generated %s\n" "$gen"
else
  warn "DRACULA_PRO_OK=0 — skipping kitty Dracula Pro generated file"
fi
```

- [ ] **Step 6: Add the same generator to install-wsl.sh and remove the old symlink**

Open `install-wsl.sh`. Find the lines:

```
link kitty/kitty.conf        .config/kitty/kitty.conf
link kitty/dracula-pro.conf  .config/kitty/dracula-pro.conf
```

Replace with the same block as Step 5 (re-type verbatim — do not reference "see Task 10 Step 5"):

```bash
link kitty/kitty.conf        .config/kitty/kitty.conf

# kitty Dracula Pro theme (Wave A Tier 1) — ~/dracula-pro/themes/ ships no
# kitty-native file, so generate one from the palette file at install time.
# Palette hex values are facts (spec § 4.1 — reproduction authorised).
if [[ "${DRACULA_PRO_OK:-0}" == 1 ]]; then
  mkdir -p "$HOME/.config/kitty"
  gen="$HOME/.config/kitty/dracula-pro.generated.conf"
  cat > "$gen" <<KITTYEOF
# AUTO-GENERATED by install-wsl.sh from scripts/lib/dracula-pro-palette.sh
# Do not edit by hand — edits are overwritten on next install.
# Source: macos-dev/docs/design/theming.md § 3.1, § 6.3.

background            $DRACULA_PRO_BACKGROUND
foreground            $DRACULA_PRO_FOREGROUND
selection_foreground  $DRACULA_PRO_FOREGROUND
selection_background  $DRACULA_PRO_SELECTION
cursor                $DRACULA_PRO_CURSOR
cursor_text_color     $DRACULA_PRO_BACKGROUND

url_color             $DRACULA_PRO_CYAN

active_tab_foreground   $DRACULA_PRO_BACKGROUND
active_tab_background   $DRACULA_PRO_PURPLE
inactive_tab_foreground $DRACULA_PRO_FOREGROUND
inactive_tab_background $DRACULA_PRO_SELECTION

color0  $DRACULA_PRO_BLACK
color1  $DRACULA_PRO_RED
color2  $DRACULA_PRO_GREEN
color3  $DRACULA_PRO_YELLOW
color4  $DRACULA_PRO_BLUE
color5  $DRACULA_PRO_MAGENTA
color6  $DRACULA_PRO_CYAN
color7  $DRACULA_PRO_WHITE
color8  $DRACULA_PRO_BRIGHT_BLACK
color9  $DRACULA_PRO_BRIGHT_RED
color10 $DRACULA_PRO_BRIGHT_GREEN
color11 $DRACULA_PRO_BRIGHT_YELLOW
color12 $DRACULA_PRO_BRIGHT_BLUE
color13 $DRACULA_PRO_BRIGHT_MAGENTA
color14 $DRACULA_PRO_BRIGHT_CYAN
color15 $DRACULA_PRO_BRIGHT_WHITE
KITTYEOF
  printf "  generated %s\n" "$gen"
else
  warn "DRACULA_PRO_OK=0 — skipping kitty Dracula Pro generated file"
fi
```

- [ ] **Step 7: Verify both install scripts parse**

Run: `bash -n install-macos.sh && bash -n install-wsl.sh && echo ok`
Expected: `ok`

- [ ] **Step 8: Run tests to confirm AC-kitty static checks pass**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-kitty static checks pass. Runtime checks skipped in safe mode. `Failed: 0`. Exit 0.

- [ ] **Step 9: Commit (includes the file deletion)**

```bash
git add kitty/kitty.conf install-macos.sh install-wsl.sh scripts/test-plan-theming.sh
git commit -m "feat(kitty): generate Pro include from palette; delete reconstruction (Wave A)"
```

Note: `git rm kitty/dracula-pro.conf` from Step 4 is already staged; the commit above includes the deletion.

---

## Task 11: Wire AC-aggregate end-to-end + run the full suite

**Files:**
- Verify (no-op): `scripts/test-plan-theming.sh`

- [ ] **Step 1: Confirm the test script's final line is strict**

Run: `tail -n 5 scripts/test-plan-theming.sh`
Expected: the last executable line is `(( fail == 0 ))` so the script exits non-zero on any failure.

- [ ] **Step 2: Run the full suite in safe mode**

Run: `bash scripts/test-plan-theming.sh`
Expected output (abridged):
```
Wave A acceptance tests
Platform: <macos|linux|wsl>    Mode: safe
Dracula Pro home: /home/<user>/dracula-pro (present|ABSENT)

AC-palette: ...
  ✓ palette file exists
  ...
AC-gitignore: ...
  ✓ .gitignore contains '/dracula-pro/'
AC-skip-env: ...
  ✓ install-macos.sh sources the palette file
  ...
AC-nvim: ...
AC-vscode: ...
AC-wt: ...
AC-raycast: ...
AC-ghostty: ...
AC-kitty: ...

---------------------------------------------------------------
Passed: <N>  Failed: 0  Skipped: <M>
```
Exit code: 0.

- [ ] **Step 3: On macOS with `~/dracula-pro/` present, run the full-mode suite**

Run: `bash scripts/test-plan-theming.sh --full`
Expected: the runtime blocks (preflight runtime, generated kitty file, WT splice idempotency) run and pass where applicable; others skip with a clear reason. Exit code 0.

- [ ] **Step 4: Confirm `~/dracula-pro/` absent path — safe-mode still exits 0**

Run: `DRACULA_PRO_HOME=/tmp/does-not-exist bash scripts/test-plan-theming.sh`
Expected: the header prints `(ABSENT)`; no static check fails; runtime checks skipped with reason. Exit code 0.

- [ ] **Step 5: Confirm absent + unset preflight fails install-macos.sh**

Run: `HOME=/tmp/fresh-home SKIP_DRACULA_PRO= bash -n install-macos.sh && echo parse-ok`
Expected: `parse-ok` (syntactic parse only; we don't actually execute against `/tmp/fresh-home` — the preflight exit-1 path is covered by the full-mode runtime check in Task 4's AC-skip-env block).

- [ ] **Step 6: Commit (no-op if no changes; skip commit if nothing staged)**

Run: `git status --short`
If output is empty, skip this step — Task 11 is verify-only.
Otherwise:

```bash
git add scripts/test-plan-theming.sh
git commit -m "test(theming): finalise Wave A suite run (AC-aggregate)"
```

---

## Post-plan: Manual Validation Steps

These steps exercise Tier 1 theming end-to-end on a real machine. They are not automated because they need interactive GUI tools.

- [ ] **Manual 1:** On macOS, run `bash install-macos.sh` with `~/dracula-pro/` present. Confirm:
  - `~/.config/kitty/dracula-pro.generated.conf` exists with 16 `colorN` lines and `background #22212C`.
  - `code --list-extensions | grep -i dracula-pro` shows the extension installed.
  - kitty, opened fresh, uses the Pro palette (ANSI `red` test: `printf '\033[31mRED\033[0m\n'` shows in `#FF9580`).
- [ ] **Manual 2:** Open vscode → Preferences → Color Theme → confirm "Dracula Pro" is selected.
- [ ] **Manual 3:** Open Raycast preferences → Appearance → Theme; follow the Next Steps URL if the Pro theme is not listed; confirm it activates.
- [ ] **Manual 4:** Open nvim; confirm `:colorscheme` prints `dracula_pro` and syntax uses the Pro palette (no LazyVim tokyonight carry-over).
- [ ] **Manual 5:** Open ghostty (if installed) — window background is `#22212C`.
- [ ] **Manual 6:** On WSL2, run `bash install-wsl.sh`; open Windows Terminal → Settings → Color schemes; confirm "Dracula Pro" is present; set it as the default scheme for the Ubuntu profile.
- [ ] **Manual 7:** On a CI-like shell with `~/dracula-pro` absent, run `SKIP_DRACULA_PRO=1 bash install-macos.sh` — confirm it reports `WARN: SKIP_DRACULA_PRO=1 — Tier 1 theming skipped` and completes install-stage 1..N without error. Tier 1 artefacts (generated kitty file, vscode extension) must not be created.
- [ ] **Manual 8:** Same as above without `SKIP_DRACULA_PRO=1` — confirm the script exits 1 with `error: ~/dracula-pro/ not found`.

---

## Self-Review Notes (recorded at plan write time)

**Spec coverage check:**
- Spec § 3.1 Tier 1 tools — kitty (Task 10), nvim (Task 5), vscode (Task 6), windows-terminal (Task 7), raycast (Task 8), ghostty (Task 9). ✓
- Spec § 4.3 `SKIP_DRACULA_PRO=1` handling — Task 4. ✓
- Spec § 4.3 loud-fail on `~/dracula-pro` absent — Task 4. ✓
- Spec § 4.4 delete `kitty/dracula-pro.conf` — Task 10. ✓
- Spec § 4.5 `/dracula-pro/` in `.gitignore` — Task 2. ✓
- Spec § 5.3 Wave A table (kitty, nvim, vscode, windows-terminal, raycast, ghostty) — Tasks 5, 6, 7, 8, 9, 10. ✓
- Spec § 6.3 palette file verbatim — Task 1. ✓
- Spec § 6.4 `scripts/test-plan-theming.sh` ATDD script — Task 3 (scaffold); Tasks 4–10 extend it with one AC block each. ✓

**Out of scope for Wave A (deferred):**
- Wave B (Tier 2 palette substitution — starship, tmux, lazygit, gh-dash, yazi, fzf, ripgrep, eza, dircolors, opencode, man-pages, pygments).
- Wave C (Tier 3 custom reconstruction — bat, delta, difftastic, lnav, btop, k9s, jqp, glow, freeze, lazydocker, httpie, xh, jq, atuin, television, sketchybar, jankyborders, aerospace, git ui.color).
- Wave Z (supersession note, final cleanup, CI integration into the four-job matrix beyond `theming-verify` suggestion).
- Variants other than Base (Alucard/Blade/Buffy/Lincoln/Morbius/Van Helsing) — spec § 1.3 deferral.

**Placeholder scan:** no TODO/TBD/see-other-task content remains. Every code block is complete and runnable. Task 10 re-types the kitty generator in both install scripts rather than cross-referencing.

**Type/naming consistency:**
- Env vars: `SKIP_DRACULA_PRO`, `DRACULA_PRO_OK`, `DRACULA_PRO_HOME` — all defined once (Task 4), consumed in Tasks 6, 7, 9, 10. ✓
- Palette var names: `DRACULA_PRO_<SLOT>` — defined in Task 1, consumed in Tasks 3 (assertions) and 10 (kitty generator). Same names throughout. ✓
- Generated kitty file name: `dracula-pro.generated.conf` — consistent in `kitty/kitty.conf` include, install-macos.sh cat > …, install-wsl.sh cat > …, test assertions. ✓
- AC labels: `AC-palette`, `AC-gitignore`, `AC-skip-env`, `AC-nvim`, `AC-vscode`, `AC-wt`, `AC-raycast`, `AC-ghostty`, `AC-kitty`, `AC-aggregate` — each labelled once in the header list, once in the script. ✓
