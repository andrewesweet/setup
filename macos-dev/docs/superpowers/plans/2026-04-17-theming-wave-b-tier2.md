# Wave B — Tier 2 Pro-from-Classic Palette Substitution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substitute every Classic Dracula hex in the twelve Tier 2 tool configs (starship, tmux, lazygit, gh-dash, yazi, fzf, ripgrep, eza, dircolors, opencode, man-pages, pygments) with the Dracula PRO Base palette, asserting the substitution via per-tool acceptance checks that share the palette file committed in Wave A.

**Architecture:** Each tool's committed config (or shell-exported env var) gets its Classic hex values rewritten to the Pro Base equivalents. The single source of truth for hex values is `scripts/lib/dracula-pro-palette.sh` (committed by Wave A). The aggregate test `scripts/test-plan-theming.sh` (scaffolded by Wave A) is extended with Wave B ACs that grep the committed configs and compare against the palette constants. No tool-config file content is authored from the licensed Pro theme files — only hex values (facts, not expressive works — see design § 1.5 and § 4.1).

**Tech Stack:** bash, TOML/YAML/JSONC config files, tmux TPM plugin override variables, GNU coreutils (`dircolors`), FZF env strings, ripgrep `~/.config/ripgrep/config`, `EZA_COLORS` env var, less termcap env vars, uv-installed Python packages (pygments), standard POSIX shell for assertions.

**Spec reference:** `macos-dev/docs/design/theming.md` § 3.2 (Tier 2), § 5.1 (Structural + accents profile), § 5.3 (Wave B table), § 6 (AC template), § 8 (open items).

**Platform scope:** macOS (Apple Silicon + Intel) and WSL2 (Ubuntu-based). Tests run in both environments; pygments install step uses `uv tool install` on both.

---

## Prerequisites

Wave A (`feature/theming-wave-a-tier1`) MUST be merged to `main` before Wave B is executed. Wave A provides `scripts/lib/dracula-pro-palette.sh`, `.gitignore` entry, `SKIP_DRACULA_PRO` env handling, and the `scripts/test-plan-theming.sh` scaffold that Wave B extends.

Before starting Wave B:

- [ ] Verify `scripts/lib/dracula-pro-palette.sh` exists and is sourceable from the worktree root (`macos-dev/`).
- [ ] Verify `scripts/test-plan-theming.sh` exists, is executable, and already sources the palette file.
- [ ] Verify `.gitignore` at the repo root contains `/dracula-pro/`.
- [ ] If any of the above are missing, STOP — go back and land Wave A first.

---

## Dracula PRO Base palette — values asserted by Wave B

The palette values below are the verbatim hex strings that Wave A's
`scripts/lib/dracula-pro-palette.sh` exports. Wave B's ACs grep for these
literal strings in committed configs. Any drift means either the palette file
or the tool config is wrong; do NOT resolve drift by loosening the AC —
resolve it by fixing whichever file is out of sync with the palette file.

| Constant                          | Hex      | Notes                                |
|-----------------------------------|----------|--------------------------------------|
| `DRACULA_PRO_BLACK`               | `#22212C` | ANSI 0, also = Background            |
| `DRACULA_PRO_RED`                 | `#FF9580` | ANSI 1                               |
| `DRACULA_PRO_GREEN`               | `#8AFF80` | ANSI 2                               |
| `DRACULA_PRO_YELLOW`              | `#FFFF80` | ANSI 3                               |
| `DRACULA_PRO_BLUE` / `_PURPLE`    | `#9580FF` | ANSI 4 (alias Purple)                |
| `DRACULA_PRO_MAGENTA` / `_PINK`   | `#FF80BF` | ANSI 5 (alias Pink)                  |
| `DRACULA_PRO_CYAN`                | `#80FFEA` | ANSI 6                               |
| `DRACULA_PRO_WHITE`               | `#F8F8F2` | ANSI 7, also = Foreground            |
| `DRACULA_PRO_BRIGHT_BLACK`        | `#504C67` | ANSI 8                               |
| `DRACULA_PRO_BACKGROUND`          | `#22212C` |                                      |
| `DRACULA_PRO_FOREGROUND`          | `#F8F8F2` |                                      |
| `DRACULA_PRO_COMMENT`             | `#7970A9` |                                      |
| `DRACULA_PRO_SELECTION`           | `#454158` |                                      |
| `DRACULA_PRO_CURSOR`              | `#7970A9` |                                      |
| `DRACULA_PRO_ORANGE`              | `#FFCA80` |                                      |

Classic hex values that Wave B replaces (every tool replaces a subset):

| Classic slot     | Classic hex | Pro Base hex | Constant                          |
|------------------|-------------|--------------|-----------------------------------|
| background       | `#282A36`   | `#22212C`    | `DRACULA_PRO_BACKGROUND`          |
| current_line     | `#44475A`   | `#454158`    | `DRACULA_PRO_SELECTION`           |
| foreground       | `#F8F8F2`   | `#F8F8F2`    | `DRACULA_PRO_FOREGROUND` (same)   |
| comment          | `#6272A4`   | `#7970A9`    | `DRACULA_PRO_COMMENT`             |
| cyan             | `#8BE9FD`   | `#80FFEA`    | `DRACULA_PRO_CYAN`                |
| green            | `#50FA7B`   | `#8AFF80`    | `DRACULA_PRO_GREEN`               |
| orange           | `#FFB86C`   | `#FFCA80`    | `DRACULA_PRO_ORANGE`              |
| pink / magenta   | `#FF79C6`   | `#FF80BF`    | `DRACULA_PRO_MAGENTA` / `_PINK`   |
| purple / blue    | `#BD93F9`   | `#9580FF`    | `DRACULA_PRO_BLUE` / `_PURPLE`    |
| red              | `#FF5555`   | `#FF9580`    | `DRACULA_PRO_RED`                 |
| yellow           | `#F1FA8C`   | `#FFFF80`    | `DRACULA_PRO_YELLOW`              |

Note: `DRACULA_PRO_FOREGROUND` (`#F8F8F2`) is numerically identical to the Classic `foreground`. It is still asserted: identity is a property we want to verify.

---

## Acceptance Criteria (Specification by Example)

Every AC below is assertable against a committed file and is implemented as a set of `check` calls in `scripts/test-plan-theming.sh` (the scaffold was committed by Wave A; Wave B appends Wave B blocks). Do not redefine `check`; reuse Wave A's.

**AC-B-starship: starship palette is `dracula-pro` with Pro Base hex**
```
Then: grep -qE '^palette\s*=\s*"dracula-pro"' starship/starship.toml
  AND: ! grep -qE '^palette\s*=\s*"dracula"' starship/starship.toml     # Classic name removed
  AND: ! grep -qE '^\[palettes\.dracula\]' starship/starship.toml        # Classic palette table removed
  AND: grep -qE '^\[palettes\.dracula-pro\]' starship/starship.toml
  AND: grep -qE '^background\s*=\s*"#22212C"' starship/starship.toml
  AND: grep -qE '^current_line\s*=\s*"#454158"' starship/starship.toml
  AND: grep -qE '^foreground\s*=\s*"#F8F8F2"' starship/starship.toml
  AND: grep -qE '^comment\s*=\s*"#7970A9"' starship/starship.toml
  AND: grep -qE '^cyan\s*=\s*"#80FFEA"' starship/starship.toml
  AND: grep -qE '^green\s*=\s*"#8AFF80"' starship/starship.toml
  AND: grep -qE '^orange\s*=\s*"#FFCA80"' starship/starship.toml
  AND: grep -qE '^pink\s*=\s*"#FF80BF"' starship/starship.toml
  AND: grep -qE '^purple\s*=\s*"#9580FF"' starship/starship.toml
  AND: grep -qE '^red\s*=\s*"#FF9580"' starship/starship.toml
  AND: grep -qE '^yellow\s*=\s*"#FFFF80"' starship/starship.toml
```

**AC-B-tmux: tmux dracula plugin colours are overridden with Pro Base hex**
```
Then: grep -qE '^set -g @dracula-colors "' tmux/.tmux.conf
  AND: grep -q "white='#F8F8F2'"        tmux/.tmux.conf
  AND: grep -q "gray='#454158'"         tmux/.tmux.conf
  AND: grep -q "dark_gray='#22212C'"    tmux/.tmux.conf
  AND: grep -q "light_purple='#9580FF'" tmux/.tmux.conf
  AND: grep -q "dark_purple='#7970A9'"  tmux/.tmux.conf
  AND: grep -q "cyan='#80FFEA'"         tmux/.tmux.conf
  AND: grep -q "green='#8AFF80'"        tmux/.tmux.conf
  AND: grep -q "orange='#FFCA80'"       tmux/.tmux.conf
  AND: grep -q "red='#FF9580'"          tmux/.tmux.conf
  AND: grep -q "pink='#FF80BF'"         tmux/.tmux.conf
  AND: grep -q "yellow='#FFFF80'"       tmux/.tmux.conf
```

**AC-B-lazygit: lazygit theme uses Pro Base hex only (no Classic residue)**
```
Then: grep -q "'#9580FF'" lazygit/config.yml        # activeBorderColor + cherry-pick
  AND: grep -q "'#7970A9'" lazygit/config.yml        # inactiveBorderColor
  AND: grep -q "'#F8F8F2'" lazygit/config.yml        # optionsTextColor + defaultFgColor
  AND: grep -q "'#454158'" lazygit/config.yml        # selectedLineBgColor + selectedRangeBgColor + cherryPickedCommitBgColor
  AND: grep -q "'#FF9580'" lazygit/config.yml        # unstagedChangesColor
  AND: grep -q "'#FFFF80'" lazygit/config.yml        # searchingActiveBorderColor
  AND: ! grep -qE "#(BD93F9|6272A4|44475A|FF5555|F1FA8C)" lazygit/config.yml   # all Classic hex gone
  AND: grep -qE 'syntax-theme=.*Dracula Pro' lazygit/config.yml                # delta theme name updated (Tier 3 dep — verified on this layer)
```

**AC-B-gh-dash: gh-dash theme block uses Pro Base hex only**
```
Then: grep -q '"#F8F8F2"' gh-dash/config.yml        # text.primary
  AND: grep -q '"#7970A9"' gh-dash/config.yml        # text.secondary + border.secondary
  AND: grep -q '"#22212C"' gh-dash/config.yml        # text.inverted
  AND: grep -q '"#454158"' gh-dash/config.yml        # text.faint + border.faint + background.selected
  AND: grep -q '"#FFCA80"' gh-dash/config.yml        # warning
  AND: grep -q '"#8AFF80"' gh-dash/config.yml        # success
  AND: grep -q '"#FF9580"' gh-dash/config.yml        # error
  AND: grep -q '"#9580FF"' gh-dash/config.yml        # border.primary
  AND: ! grep -qE "#(BD93F9|FF5555|50FA7B|FFB86C|6272A4|44475A|282A36|FF79C6|F1FA8C|8BE9FD)" gh-dash/config.yml
```

**AC-B-yazi: yazi/theme.toml uses Pro Base hex only**
```
Then: grep -q '"#22212C"' yazi/theme.toml    # backgrounds (hovered/tab_active/mode fg etc.)
  AND: grep -q '"#F8F8F2"' yazi/theme.toml    # foregrounds
  AND: grep -q '"#7970A9"' yazi/theme.toml    # comments / borders / rest
  AND: grep -q '"#454158"' yazi/theme.toml    # tab_inactive bg / progress bg / separator
  AND: grep -q '"#9580FF"' yazi/theme.toml    # hovered.bg / tab_active.bg / input/select/tasks border
  AND: grep -q '"#80FFEA"' yazi/theme.toml    # cwd / permissions_t / cand
  AND: grep -q '"#8AFF80"' yazi/theme.toml    # marker_selected / mode_select / permissions_x
  AND: grep -q '"#FFFF80"' yazi/theme.toml    # marker_copied / permissions_r / video audio
  AND: grep -q '"#FFCA80"' yazi/theme.toml    # mode_unset / find_keyword / image
  AND: grep -q '"#FF80BF"' yazi/theme.toml    # find_position / active / desc / help on / archives
  AND: grep -q '"#FF9580"' yazi/theme.toml    # marker_cut / progress_error / permissions_w
  AND: ! grep -qE "#(BD93F9|6272A4|44475A|282A36|FF5555|50FA7B|FFB86C|FF79C6|F1FA8C|8BE9FD)" yazi/theme.toml
```

**AC-B-fzf: FZF_DEFAULT_OPTS uses Pro Base hex only**
```
Then: grep -q 'fg:#F8F8F2'          bash/.bashrc
  AND: grep -q 'bg:#22212C'          bash/.bashrc
  AND: grep -q 'hl:#9580FF'          bash/.bashrc
  AND: grep -q 'fg+:#F8F8F2'         bash/.bashrc
  AND: grep -q 'bg+:#454158'         bash/.bashrc
  AND: grep -q 'hl+:#9580FF'         bash/.bashrc
  AND: grep -q 'info:#FFCA80'        bash/.bashrc
  AND: grep -q 'prompt:#8AFF80'      bash/.bashrc
  AND: grep -q 'pointer:#FF80BF'     bash/.bashrc
  AND: grep -q 'marker:#FF80BF'      bash/.bashrc
  AND: grep -q 'spinner:#FFCA80'     bash/.bashrc
  AND: grep -q 'header:#7970A9'      bash/.bashrc
  AND: ! grep -qE '#(bd93f9|6272a4|44475a|282a36|ff5555|50fa7b|ffb86c|ff79c6|f1fa8c|8be9fd)' bash/.bashrc   # no lowercase Classic hex left over
```

**AC-B-ripgrep: ripgrep config uses Pro Base hex (via RGB triples)**
```
Then: test -f ripgrep/config
  AND: grep -q 'colors=path:fg:0x95,0x80,0xFF'    ripgrep/config     # Purple/Blue = #9580FF
  AND: grep -q 'colors=line:fg:0x8A,0xFF,0x80'    ripgrep/config     # Green      = #8AFF80
  AND: grep -q 'colors=column:fg:0x8A,0xFF,0x80'  ripgrep/config     # Green      = #8AFF80
  AND: grep -q 'colors=match:fg:0xFF,0x95,0x80'   ripgrep/config     # Red        = #FF9580
  AND: grep -q 'RIPGREP_CONFIG_PATH=.*ripgrep/config' bash/.bashrc
```

**AC-B-eza: EZA_COLORS is exported with Pro Base hex for overridable slots**
```
Then: grep -qE '^export EZA_COLORS=' bash/.bashrc
  AND: grep -q 'da=38;2;121;112;169' bash/.bashrc    # date  = Comment #7970A9
  AND: grep -q 'ur=38;2;149;128;255' bash/.bashrc    # user read bit = Purple #9580FF
  AND: grep -q 'uw=38;2;255;149;128' bash/.bashrc    # user write    = Red    #FF9580
  AND: grep -q 'ux=38;2;138;255;128' bash/.bashrc    # user exec     = Green  #8AFF80
  AND: grep -q 'ue=38;2;255;202;128' bash/.bashrc    # user other x  = Orange #FFCA80
```

**AC-B-dircolors: ~/.dir_colors ships Pro Base hex RGB triples**
```
Then: test -f dircolors/.dir_colors
  AND: grep -qE 'DIR .*38;2;149;128;255'   dircolors/.dir_colors    # dir    = Purple  #9580FF
  AND: grep -qE 'LINK .*38;2;128;255;234'  dircolors/.dir_colors    # link   = Cyan    #80FFEA
  AND: grep -qE 'FIFO .*38;2;255;255;128'  dircolors/.dir_colors    # fifo fg = Yellow #FFFF80
  AND: grep -qE 'ORPHAN .*38;2;255;149;128' dircolors/.dir_colors   # orphan = Red     #FF9580
  AND: grep -qE 'SETUID .*48;2;255;149;128' dircolors/.dir_colors   # setuid bg = Red  #FF9580
  AND: ! grep -qE '38;2;(189;147;249|98;114;164|139;233;253|255;121;198|255;85;85|255;184;108|241;250;140|80;250;123)' dircolors/.dir_colors
  AND: grep -q 'eval "\$(dircolors -b.*\.dir_colors)"' bash/.bashrc
```

**AC-B-opencode: opencode tui.jsonc has dracula-pro theme + in-repo theme file with Pro Base hex**
```
Then: grep -qE '"theme"\s*:\s*"dracula-pro"' opencode/tui.jsonc
  AND: test -f opencode/themes/dracula-pro.json
  AND: grep -q '"#22212C"' opencode/themes/dracula-pro.json   # bgPrimary
  AND: grep -q '"#454158"' opencode/themes/dracula-pro.json   # bgSecondary / bgSelection
  AND: grep -q '"#F8F8F2"' opencode/themes/dracula-pro.json   # foreground
  AND: grep -q '"#7970A9"' opencode/themes/dracula-pro.json   # comment
  AND: grep -q '"#FF9580"' opencode/themes/dracula-pro.json   # red
  AND: grep -q '"#FFCA80"' opencode/themes/dracula-pro.json   # orange
  AND: grep -q '"#FFFF80"' opencode/themes/dracula-pro.json   # yellow
  AND: grep -q '"#8AFF80"' opencode/themes/dracula-pro.json   # green
  AND: grep -q '"#80FFEA"' opencode/themes/dracula-pro.json   # cyan
  AND: grep -q '"#9580FF"' opencode/themes/dracula-pro.json   # purple
  AND: grep -q '"#FF80BF"' opencode/themes/dracula-pro.json   # pink
  AND: grep -qE 'link opencode/themes/dracula-pro\.json.*\.config/opencode/themes/dracula-pro\.json' install-macos.sh
```

**AC-B-man-pages: MANPAGER + LESS_TERMCAP env vars use Pro Base hex via 24-bit SGR**
```
Then: grep -qE 'LESS_TERMCAP_md=.*38;2;149;128;255' bash/.bashrc         # begin bold  = Purple #9580FF
  AND: grep -qE 'LESS_TERMCAP_us=.*38;2;128;255;234' bash/.bashrc         # underline   = Cyan   #80FFEA
  AND: grep -qE 'LESS_TERMCAP_so=.*38;2;34;33;44.*48;2;255;202;128' bash/.bashrc   # standout fg=bg=Black/Orange
  AND: grep -qE 'LESS_TERMCAP_mb=.*38;2;255;149;128' bash/.bashrc         # begin blink = Red    #FF9580
  AND: grep -qE 'GROFF_NO_SGR=1' bash/.bashrc
```

**AC-B-pygments: Pro pygments style resolvable + bat cache rebuild documented**
```
Given: WaveB-Task-N-validate-pygments has been run (see plan)
When: inspecting committed artefacts
Then: (installable path)   test -f pygments/dracula_pro.py
  OR:  (installable path)   grep -qE 'uv tool install pygments-dracula-pro' install-macos.sh
  AND: grep -qE 'DRACULA_PRO_PURPLE|#9580FF' pygments/dracula_pro.py    # when local file route taken
  AND: grep -qE 'pygmentize -L styles.*dracula-pro' scripts/test-plan-theming.sh   # runtime smoke check added
```

**AC-B-aggregate: Wave B extensions land in `scripts/test-plan-theming.sh`**
```
Then: grep -q '# ── Wave B: Tier 2 Pro-from-Classic ─' scripts/test-plan-theming.sh
  AND: bash scripts/test-plan-theming.sh  exits 0 on a fresh checkout of this branch
```

---

## File Structure

**New files (created by Wave B):**
- `ripgrep/config` — ripgrep config file with Pro-hex `--colors` directives (new dir).
- `dircolors/.dir_colors` — GNU dircolors database with Pro-hex 24-bit SGR escapes (new dir).
- `opencode/themes/dracula-pro.json` — opencode custom theme file (palette facts; not a Pro-theme-file reproduction — opencode's Dracula Classic file is community-authored, and the structure is ours, only the hex values change).
- `pygments/dracula_pro.py` — local pygments style module (only if the uv package does not exist at impl time — see Task 13).

**Modified files:**
- `starship/starship.toml` — palette renamed `[palettes.dracula]` → `[palettes.dracula-pro]`, 11 hex values substituted, `palette = "dracula-pro"` at top.
- `tmux/.tmux.conf` — add `set -g @dracula-colors "..."` block overriding all 11 plugin colour variables; verify existing `@dracula-plugins "git time"` segments resolve to Pro hex at runtime.
- `lazygit/config.yml` — 11 hex values substituted; `pager: delta --syntax-theme='Dracula'` → `'Dracula Pro'`.
- `gh-dash/config.yml` — theme block hex values substituted.
- `yazi/theme.toml` — every hex value substituted (the file has many Classic hex — all 10 slots).
- `bash/.bashrc` — `FZF_DEFAULT_OPTS` hex substituted (lower→UPPER + Pro values); new blocks for `RIPGREP_CONFIG_PATH`, `EZA_COLORS`, `dircolors -b` eval, `LESS_TERMCAP_*` + `GROFF_NO_SGR`.
- `opencode/tui.jsonc` — add `"theme": "dracula-pro"` key at top level of the object.
- `install-macos.sh` — add `link()` calls for `ripgrep/config`, `dircolors/.dir_colors`, `opencode/themes/dracula-pro.json`, and (conditionally) `pygments/dracula_pro.py`.
- `install-wsl.sh` — mirror the above `link()` additions.
- `scripts/test-plan-theming.sh` — append twelve Wave B AC blocks (starship, tmux, lazygit, gh-dash, yazi, fzf, ripgrep, eza, dircolors, opencode, man-pages, pygments).

**Untouched (preserved):**
- `scripts/lib/dracula-pro-palette.sh` — committed by Wave A; Wave B reads only.
- `yazi/yazi.toml`, `yazi/keymap.toml` — no palette content in these files (theme.toml is the only themed file).
- `lazygit/config.yml` non-theme keys (git.commit.signOff, keybindings, sidePanelWidth, etc.).
- `starship/starship.toml` module sections (`[directory]`, `[git_branch]`, etc.) — they reference palette colours by name (`purple`, `pink`, `yellow`, `green`, `cyan`, `red`) so substituting the palette values alone updates them.
- `opencode/opencode.jsonc` — no theming surface (permissions config only).
- Classic Dracula theme files in `~/code/dracula-theme/` — read-only source of Classic hex.

---

## Task 0: Bootstrap Wave B test blocks in `scripts/test-plan-theming.sh` (Red)

This task assumes Wave A created the script with:
- a shebang and platform-detect header,
- a sourcing line for `scripts/lib/dracula-pro-palette.sh`,
- a `check()` function that runs `"$@"` and prints ✓ or ✗ (identical signature to the AC-scaffold in `scripts/test-plan-layer1a.sh`),
- Wave A AC blocks for Tier 1 tools,
- a final `(( fail == 0 ))` as the last executable line.

Wave B extends the script with twelve AC blocks, added incrementally per tool. Step 1 reserves the region.

**Files:**
- Modify: `scripts/test-plan-theming.sh` (append Wave B section header)

- [ ] **Step 1: Verify Wave A scaffold is present**

Run:
```bash
test -f scripts/test-plan-theming.sh && \
test -x scripts/test-plan-theming.sh && \
test -f scripts/lib/dracula-pro-palette.sh && \
grep -q 'dracula-pro-palette.sh' scripts/test-plan-theming.sh && \
grep -qE '^check\s*\(\s*\)\s*\{' scripts/test-plan-theming.sh && \
echo OK
```
Expected: prints `OK`. If any test fails, STOP — Wave A is not merged.

- [ ] **Step 2: Append Wave B section header to the test script**

Find the line that reads `(( fail == 0 ))` at the end of `scripts/test-plan-theming.sh`. Immediately before it, insert:

```bash

# ─────────────────────────────────────────────────────────────────────────────
# ── Wave B: Tier 2 Pro-from-Classic ──────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
# Each tool below reproduces § 3.2 of macos-dev/docs/design/theming.md.
# Classic hex are substituted for Dracula PRO Base hex sourced from
# scripts/lib/dracula-pro-palette.sh. Every AC asserts every slot in the
# tool's coverage profile per § 5.1.
echo ""
echo "Wave B — Tier 2 Pro-from-Classic palette substitution"
```

- [ ] **Step 3: Run the test script to confirm the Wave B section prints a heading but no checks**

Run: `bash scripts/test-plan-theming.sh`
Expected: the heading `Wave B — Tier 2 Pro-from-Classic palette substitution` appears in output; existing Wave A checks still pass; exit 0 (no Wave B failures yet because no Wave B checks exist).

- [ ] **Step 4: Commit**

```bash
git add scripts/test-plan-theming.sh
git commit -m "test(theming-wave-b): scaffold Tier 2 acceptance section"
```

---

## Task 1: starship — rename palette + substitute hex (AC-B-starship)

Current state (inspected 2026-04-17 in this worktree): `starship/starship.toml` lines 16-29 declare `palette = "dracula"` and a `[palettes.dracula]` table with Classic hex. Module sections reference palette colours by name (`bold purple`, `bold pink`, `yellow`, `red`, `cyan`, `green`) so they automatically pick up the renamed palette.

**Files:**
- Modify: `starship/starship.toml`
- Modify: `scripts/test-plan-theming.sh`

- [ ] **Step 1: Capture current Classic hex (for rollback audit trail)**

Run:
```bash
grep -nE '^(background|current_line|foreground|comment|cyan|green|orange|pink|purple|red|yellow)\s*=' starship/starship.toml
```
Expected output (verbatim — this is the current state):
```
19:background = "#282A36"
20:current_line = "#44475A"
21:foreground = "#F8F8F2"
22:comment = "#6272A4"
23:cyan = "#8BE9FD"
24:green = "#50FA7B"
25:orange = "#FFB86C"
26:pink = "#FF79C6"
27:purple = "#BD93F9"
28:red = "#FF5555"
29:yellow = "#F1FA8C"
```

- [ ] **Step 2: Append AC-B-starship checks to the test script**

Find the `echo "Wave B — ..."` heading added in Task 0. Immediately after it, insert:

```bash

# ── AC-B-starship ────────────────────────────────────────────────────────────
echo ""
echo "AC-B-starship: starship palette is dracula-pro with Pro Base hex"
check "palette = dracula-pro"               grep -qE '^palette\s*=\s*"dracula-pro"' starship/starship.toml
check "Classic palette name removed"        bash -c '! grep -qE "^palette\s*=\s*\"dracula\"\s*$" starship/starship.toml'
check "Classic [palettes.dracula] removed"  bash -c '! grep -qE "^\[palettes\.dracula\]\s*$" starship/starship.toml'
check "[palettes.dracula-pro] table"        grep -qE '^\[palettes\.dracula-pro\]' starship/starship.toml
check "background = #22212C"                grep -qE '^background\s*=\s*"#22212C"' starship/starship.toml
check "current_line = #454158"              grep -qE '^current_line\s*=\s*"#454158"' starship/starship.toml
check "foreground = #F8F8F2"                grep -qE '^foreground\s*=\s*"#F8F8F2"' starship/starship.toml
check "comment = #7970A9"                   grep -qE '^comment\s*=\s*"#7970A9"' starship/starship.toml
check "cyan = #80FFEA"                      grep -qE '^cyan\s*=\s*"#80FFEA"' starship/starship.toml
check "green = #8AFF80"                     grep -qE '^green\s*=\s*"#8AFF80"' starship/starship.toml
check "orange = #FFCA80"                    grep -qE '^orange\s*=\s*"#FFCA80"' starship/starship.toml
check "pink = #FF80BF"                      grep -qE '^pink\s*=\s*"#FF80BF"' starship/starship.toml
check "purple = #9580FF"                    grep -qE '^purple\s*=\s*"#9580FF"' starship/starship.toml
check "red = #FF9580"                       grep -qE '^red\s*=\s*"#FF9580"' starship/starship.toml
check "yellow = #FFFF80"                    grep -qE '^yellow\s*=\s*"#FFFF80"' starship/starship.toml
```

- [ ] **Step 3: Run tests — confirm AC-B-starship fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-B-starship shows 14 failing checks (palette still named `dracula`, hex values still Classic).

- [ ] **Step 4: Rewrite `starship/starship.toml` lines 16-29**

Find the exact block (lines 16-29 in current file):
```toml
palette = "dracula"

[palettes.dracula]
background = "#282A36"
current_line = "#44475A"
foreground = "#F8F8F2"
comment = "#6272A4"
cyan = "#8BE9FD"
green = "#50FA7B"
orange = "#FFB86C"
pink = "#FF79C6"
purple = "#BD93F9"
red = "#FF5555"
yellow = "#F1FA8C"
```

Replace with:
```toml
palette = "dracula-pro"

[palettes.dracula-pro]
background = "#22212C"
current_line = "#454158"
foreground = "#F8F8F2"
comment = "#7970A9"
cyan = "#80FFEA"
green = "#8AFF80"
orange = "#FFCA80"
pink = "#FF80BF"
purple = "#9580FF"
red = "#FF9580"
yellow = "#FFFF80"
```

(Module references to palette names — `bold purple`, `bold pink`, `yellow`, `red`, `cyan`, `green` — remain unchanged; they resolve against whatever `palette` is active.)

- [ ] **Step 5: Confirm no other Classic hex lingers in the file**

Run:
```bash
grep -nE '#(282A36|44475A|6272A4|BD93F9|8BE9FD|50FA7B|FFB86C|FF79C6|FF5555|F1FA8C)' starship/starship.toml || echo "CLEAN"
```
Expected: `CLEAN`.

- [ ] **Step 6: Run tests — confirm AC-B-starship passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: AC-B-starship section passes all 14 checks.

- [ ] **Step 7: Commit**

```bash
git add starship/starship.toml scripts/test-plan-theming.sh
git commit -m "feat(starship): adopt dracula-pro palette (Pro Base hex)"
```

---

## Task 2: tmux — validate plugin overrideability + substitute colour block (AC-B-tmux)

### Sub-task 2a: Verify the `dracula/tmux` plugin can be fully overridden

The `dracula/tmux` plugin reads colours from the `@dracula-colors` tmux user option. The upstream plugin docs (`docs/color_theming/README.md`) declare the named slots: `white`, `gray`, `dark_gray`, `light_purple`, `dark_purple`, `cyan`, `green`, `orange`, `red`, `pink`, `yellow`. Per-widget assignments (e.g. `@dracula-battery-colors "pink dark_gray"`) look up these names. Provided we override all 11 slots, no hardcoded Classic hex can reach the status line.

**Files:**
- Read-only: `~/.tmux/plugins/tmux/scripts/*.sh` (post-install; populated by TPM after `prefix + I`)

- [ ] **Step 1: Document the check in a plan appendix line in `tmux/.tmux.conf`**

Modify `tmux/.tmux.conf`: find the existing Dracula block (lines 115-120):
```tmux
# Dracula tmux plugin (replaces the previous hand-rolled status line).
# Segments: git branch + clock. Military time avoids AM/PM ambiguity.
set -g @dracula-show-powerline true
set -g @dracula-plugins "git time"
set -g @dracula-show-left-icon session
set -g @dracula-military-time true
```

Insert a note comment immediately above it:
```tmux
# Dracula Pro palette override. The dracula/tmux plugin looks up 11 named
# colour slots (@dracula-colors) from a user option. Every active segment
# (git, time, etc. — listed via @dracula-plugins) resolves colours through
# these names, so overriding all 11 substitutes the palette end-to-end.
# If a future upstream version adds a hardcoded hex not routed through
# @dracula-colors, this override will not catch it — flag it as an Open
# Item and fall back to a custom status line (Tier 3). See theming.md § 8.
```

- [ ] **Step 2: Install TPM + plugin to verify the override actually intercepts every colour (manual smoke check)**

Run (inside a tmux session, after this plan's tmux step is applied):
```bash
tmux kill-server 2>/dev/null; tmux new-session -d -s probe
tmux source-file ~/.tmux.conf
tmux show-option -g | grep -E '@dracula-colors|@dracula-plugins'
# The colours-string output MUST contain the Pro hex values verbatim.
```
Expected: `@dracula-colors` expands to the Pro hex string installed in Sub-task 2b. If any segment on the status line visibly shows a Classic-like colour, open an item: the plan's tmux AC drops to Tier 3 and tmux's custom status line is authored in a follow-up plan.

### Sub-task 2b: Install the @dracula-colors override

**Files:**
- Modify: `tmux/.tmux.conf`
- Modify: `scripts/test-plan-theming.sh`

- [ ] **Step 3: Append AC-B-tmux checks to the test script**

After the AC-B-starship block (added in Task 1) and before the final summary/`fail == 0` line in `scripts/test-plan-theming.sh`, add:

```bash

# ── AC-B-tmux ────────────────────────────────────────────────────────────────
echo ""
echo "AC-B-tmux: tmux dracula plugin colours overridden with Pro Base hex"
check "tmux has @dracula-colors block"    grep -qE '^set -g @dracula-colors "' tmux/.tmux.conf
check "tmux white = Pro White"            grep -q "white='#F8F8F2'"        tmux/.tmux.conf
check "tmux gray = Pro Selection"         grep -q "gray='#454158'"         tmux/.tmux.conf
check "tmux dark_gray = Pro Background"   grep -q "dark_gray='#22212C'"    tmux/.tmux.conf
check "tmux light_purple = Pro Blue"      grep -q "light_purple='#9580FF'" tmux/.tmux.conf
check "tmux dark_purple = Pro Comment"    grep -q "dark_purple='#7970A9'"  tmux/.tmux.conf
check "tmux cyan = Pro Cyan"              grep -q "cyan='#80FFEA'"         tmux/.tmux.conf
check "tmux green = Pro Green"            grep -q "green='#8AFF80'"        tmux/.tmux.conf
check "tmux orange = Pro Orange"          grep -q "orange='#FFCA80'"       tmux/.tmux.conf
check "tmux red = Pro Red"                grep -q "red='#FF9580'"          tmux/.tmux.conf
check "tmux pink = Pro Magenta"           grep -q "pink='#FF80BF'"         tmux/.tmux.conf
check "tmux yellow = Pro Yellow"          grep -q "yellow='#FFFF80'"       tmux/.tmux.conf
```

- [ ] **Step 4: Run tests — confirm AC-B-tmux fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: 12 failing checks under `AC-B-tmux`.

- [ ] **Step 5: Add the `@dracula-colors` override to `tmux/.tmux.conf`**

Insert the following AFTER the existing `set -g @dracula-military-time true` line (currently line 120) and BEFORE the `# ── TPM bootstrap` section:

```tmux

# Pro Base palette override — every segment in @dracula-plugins looks up
# colour names from this block.
set -g @dracula-colors "
white='#F8F8F2'
gray='#454158'
dark_gray='#22212C'
light_purple='#9580FF'
dark_purple='#7970A9'
cyan='#80FFEA'
green='#8AFF80'
orange='#FFCA80'
red='#FF9580'
pink='#FF80BF'
yellow='#FFFF80'
"
```

- [ ] **Step 6: Reload tmux config (if running) to smoke-test**

Run (if inside a tmux session):
```bash
tmux source-file ~/.tmux.conf
tmux show-options -g @dracula-colors
```
Expected: output contains the Pro hex strings verbatim.

- [ ] **Step 7: Run tests — confirm AC-B-tmux passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: all 12 AC-B-tmux checks pass.

- [ ] **Step 8: Commit**

```bash
git add tmux/.tmux.conf scripts/test-plan-theming.sh
git commit -m "feat(tmux): override dracula plugin palette with Pro Base hex"
```

---

## Task 3: lazygit — substitute hex + update delta theme ref (AC-B-lazygit)

Current state (inspected 2026-04-17): `lazygit/config.yml` lines 5-26 hold 9 Classic hex values; line 35 has `delta --syntax-theme='Dracula'` (a Tier 3 concern, but the grep assertion must flip here since Tier 3 delta work will depend on `Dracula Pro` being the bat theme name).

**Files:**
- Modify: `lazygit/config.yml`
- Modify: `scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-B-lazygit checks to the test script**

After the AC-B-tmux block, insert:

```bash

# ── AC-B-lazygit ─────────────────────────────────────────────────────────────
echo ""
echo "AC-B-lazygit: lazygit theme uses Pro Base hex only"
check "activeBorder / cherry-pick = Purple"  grep -q "'#9580FF'" lazygit/config.yml
check "inactiveBorder = Comment"             grep -q "'#7970A9'" lazygit/config.yml
check "options / defaultFg = Foreground"     grep -q "'#F8F8F2'" lazygit/config.yml
check "selected/cherry-pick bg = Selection"  grep -q "'#454158'" lazygit/config.yml
check "unstaged = Red"                       grep -q "'#FF9580'" lazygit/config.yml
check "searching = Yellow"                   grep -q "'#FFFF80'" lazygit/config.yml
check "no Classic hex remain"                bash -c "! grep -qE \"#(BD93F9|6272A4|44475A|FF5555|F1FA8C)\" lazygit/config.yml"
check "delta syntax-theme = Dracula Pro"     grep -qE "syntax-theme=.*Dracula Pro" lazygit/config.yml
```

- [ ] **Step 2: Run tests — confirm AC-B-lazygit fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: all 8 AC-B-lazygit checks fail.

- [ ] **Step 3: Rewrite the theme block in `lazygit/config.yml` lines 4-26**

Find:
```yaml
gui:
  theme:
    activeBorderColor:
      - '#BD93F9'
      - bold
    inactiveBorderColor:
      - '#6272A4'
    optionsTextColor:
      - '#F8F8F2'
    selectedLineBgColor:
      - '#44475A'
    selectedRangeBgColor:
      - '#44475A'
    cherryPickedCommitBgColor:
      - '#44475A'
    cherryPickedCommitFgColor:
      - '#BD93F9'
    unstagedChangesColor:
      - '#FF5555'
    defaultFgColor:
      - '#F8F8F2'
    searchingActiveBorderColor:
      - '#F1FA8C'
```

Replace with:
```yaml
gui:
  theme:
    activeBorderColor:
      - '#9580FF'
      - bold
    inactiveBorderColor:
      - '#7970A9'
    optionsTextColor:
      - '#F8F8F2'
    selectedLineBgColor:
      - '#454158'
    selectedRangeBgColor:
      - '#454158'
    cherryPickedCommitBgColor:
      - '#454158'
    cherryPickedCommitFgColor:
      - '#9580FF'
    unstagedChangesColor:
      - '#FF9580'
    defaultFgColor:
      - '#F8F8F2'
    searchingActiveBorderColor:
      - '#FFFF80'
```

- [ ] **Step 4: Update the delta reference on line 35**

Find:
```yaml
    pager: delta --paging=never --syntax-theme='Dracula'
```

Replace with:
```yaml
    pager: delta --paging=never --syntax-theme='Dracula Pro'
```

Note: this string `Dracula Pro` is the bat theme name that Wave C (Tier 3) ships as a custom `.tmTheme`. Asserting it here ensures the two plans stay in sync — Wave C will register this theme name; without it here, delta would silently fall back to bat's built-in Classic.

- [ ] **Step 5: Confirm no Classic hex remain**

Run:
```bash
grep -nE '#(282A36|44475A|6272A4|BD93F9|8BE9FD|50FA7B|FFB86C|FF79C6|FF5555|F1FA8C)' lazygit/config.yml || echo "CLEAN"
```
Expected: `CLEAN`.

- [ ] **Step 6: Run tests — confirm AC-B-lazygit passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: all 8 AC-B-lazygit checks pass.

- [ ] **Step 7: Commit**

```bash
git add lazygit/config.yml scripts/test-plan-theming.sh
git commit -m "feat(lazygit): substitute Pro Base hex + point delta at Dracula Pro"
```

---

## Task 4: gh-dash — substitute theme block hex (AC-B-gh-dash)

Current state: `gh-dash/config.yml` lines 49-68 hold 10 Classic hex values.

**Files:**
- Modify: `gh-dash/config.yml`
- Modify: `scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-B-gh-dash checks to the test script**

After the AC-B-lazygit block, insert:

```bash

# ── AC-B-gh-dash ─────────────────────────────────────────────────────────────
echo ""
echo "AC-B-gh-dash: gh-dash theme block uses Pro Base hex only"
check "text.primary = Foreground"           grep -q '"#F8F8F2"' gh-dash/config.yml
check "text.secondary / border.secondary"   grep -q '"#7970A9"' gh-dash/config.yml
check "text.inverted = Background"          grep -q '"#22212C"' gh-dash/config.yml
check "faint + bg.selected = Selection"     grep -q '"#454158"' gh-dash/config.yml
check "warning = Orange"                    grep -q '"#FFCA80"' gh-dash/config.yml
check "success = Green"                     grep -q '"#8AFF80"' gh-dash/config.yml
check "error = Red"                         grep -q '"#FF9580"' gh-dash/config.yml
check "border.primary = Purple"             grep -q '"#9580FF"' gh-dash/config.yml
check "no Classic hex remain"               bash -c "! grep -qE \"#(BD93F9|FF5555|50FA7B|FFB86C|6272A4|44475A|282A36|FF79C6|F1FA8C|8BE9FD)\" gh-dash/config.yml"
```

- [ ] **Step 2: Run tests — confirm AC-B-gh-dash fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: 9 failing checks under AC-B-gh-dash (only `text.primary` happens to already match Classic since foreground is the same hex — may already pass, harmless).

- [ ] **Step 3: Rewrite the theme block in `gh-dash/config.yml` lines 49-68**

Find:
```yaml
# Dracula theme (palette values from docs/plans § 3.9)
theme:
  ui:
    table:
      showSeparator: true
  colors:
    text:
      primary: "#F8F8F2"
      secondary: "#6272A4"
      inverted: "#282A36"
      faint: "#44475A"
      warning: "#FFB86C"
      success: "#50FA7B"
      error: "#FF5555"
    background:
      selected: "#44475A"
    border:
      primary: "#BD93F9"
      secondary: "#6272A4"
      faint: "#44475A"
```

Replace with:
```yaml
# Dracula Pro theme (palette values from docs/design/theming.md § 1.3)
theme:
  ui:
    table:
      showSeparator: true
  colors:
    text:
      primary: "#F8F8F2"
      secondary: "#7970A9"
      inverted: "#22212C"
      faint: "#454158"
      warning: "#FFCA80"
      success: "#8AFF80"
      error: "#FF9580"
    background:
      selected: "#454158"
    border:
      primary: "#9580FF"
      secondary: "#7970A9"
      faint: "#454158"
```

- [ ] **Step 4: Confirm no Classic hex remain**

Run:
```bash
grep -nE '#(282A36|44475A|6272A4|BD93F9|8BE9FD|50FA7B|FFB86C|FF79C6|FF5555|F1FA8C|AD85FC|383B5B|39386B|2B2B40)' gh-dash/config.yml || echo "CLEAN"
```
Expected: `CLEAN`.

- [ ] **Step 5: Run tests — confirm AC-B-gh-dash passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: all 9 AC-B-gh-dash checks pass.

- [ ] **Step 6: Commit**

```bash
git add gh-dash/config.yml scripts/test-plan-theming.sh
git commit -m "feat(gh-dash): substitute Pro Base hex in theme block"
```

---

## Task 5: yazi — substitute every theme.toml hex (AC-B-yazi)

Current state: `yazi/theme.toml` has 10 distinct Classic hex values across 82 lines (inspected 2026-04-17).

**Files:**
- Modify: `yazi/theme.toml`
- Modify: `scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-B-yazi checks to the test script**

After the AC-B-gh-dash block, insert:

```bash

# ── AC-B-yazi ────────────────────────────────────────────────────────────────
echo ""
echo "AC-B-yazi: yazi/theme.toml uses Pro Base hex only"
check "background = #22212C"   grep -q '"#22212C"' yazi/theme.toml
check "foreground = #F8F8F2"   grep -q '"#F8F8F2"' yazi/theme.toml
check "comment = #7970A9"      grep -q '"#7970A9"' yazi/theme.toml
check "selection = #454158"    grep -q '"#454158"' yazi/theme.toml
check "purple = #9580FF"       grep -q '"#9580FF"' yazi/theme.toml
check "cyan = #80FFEA"         grep -q '"#80FFEA"' yazi/theme.toml
check "green = #8AFF80"        grep -q '"#8AFF80"' yazi/theme.toml
check "yellow = #FFFF80"       grep -q '"#FFFF80"' yazi/theme.toml
check "orange = #FFCA80"       grep -q '"#FFCA80"' yazi/theme.toml
check "pink = #FF80BF"         grep -q '"#FF80BF"' yazi/theme.toml
check "red = #FF9580"          grep -q '"#FF9580"' yazi/theme.toml
check "no Classic hex remain"  bash -c "! grep -qE \"#(BD93F9|6272A4|44475A|282A36|FF5555|50FA7B|FFB86C|FF79C6|F1FA8C|8BE9FD)\" yazi/theme.toml"
```

- [ ] **Step 2: Run tests — confirm AC-B-yazi fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: multiple failing checks (Pro hex not yet present; Classic hex still present).

- [ ] **Step 3: Global-substitute every Classic hex in `yazi/theme.toml`**

Apply every substitution exactly (use `replace_all` semantics or 10 individual edits — order does not matter since each Classic hex maps 1:1):

| Classic            | Pro Base            |
|--------------------|---------------------|
| `"#282A36"`        | `"#22212C"`         |
| `"#44475A"`        | `"#454158"`         |
| `"#6272A4"`        | `"#7970A9"`         |
| `"#BD93F9"`        | `"#9580FF"`         |
| `"#8BE9FD"`        | `"#80FFEA"`         |
| `"#50FA7B"`        | `"#8AFF80"`         |
| `"#F1FA8C"`        | `"#FFFF80"`         |
| `"#FFB86C"`        | `"#FFCA80"`         |
| `"#FF79C6"`        | `"#FF80BF"`         |
| `"#FF5555"`        | `"#FF9580"`         |

`"#F8F8F2"` is unchanged (identical across Classic and Pro Base).

After edits, verify:
```bash
grep -nE '#(282A36|44475A|6272A4|BD93F9|8BE9FD|50FA7B|FFB86C|FF79C6|FF5555|F1FA8C)' yazi/theme.toml || echo "CLEAN"
```
Expected: `CLEAN`.

- [ ] **Step 4: Run tests — confirm AC-B-yazi passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: all 12 AC-B-yazi checks pass.

- [ ] **Step 5: Commit**

```bash
git add yazi/theme.toml scripts/test-plan-theming.sh
git commit -m "feat(yazi): substitute Pro Base hex in theme.toml"
```

---

## Task 6: fzf — rewrite FZF_DEFAULT_OPTS colour string (AC-B-fzf)

Current state (`bash/.bashrc` lines 251-261): `FZF_DEFAULT_OPTS` contains a Classic Dracula colour string with lowercase hex. Wave B substitutes and normalises to UPPERCASE hex, which is how the palette file and every other Wave B config represent values (consistency anchor).

**Files:**
- Modify: `bash/.bashrc`
- Modify: `scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-B-fzf checks to the test script**

After the AC-B-yazi block, insert:

```bash

# ── AC-B-fzf ─────────────────────────────────────────────────────────────────
echo ""
echo "AC-B-fzf: FZF_DEFAULT_OPTS uses Pro Base hex only"
check "fzf fg = Foreground"         grep -q 'fg:#F8F8F2'          bash/.bashrc
check "fzf bg = Background"         grep -q 'bg:#22212C'          bash/.bashrc
check "fzf hl = Purple"             grep -q 'hl:#9580FF'          bash/.bashrc
check "fzf fg+ = Foreground"        grep -q 'fg+:#F8F8F2'         bash/.bashrc
check "fzf bg+ = Selection"         grep -q 'bg+:#454158'         bash/.bashrc
check "fzf hl+ = Purple"            grep -q 'hl+:#9580FF'         bash/.bashrc
check "fzf info = Orange"           grep -q 'info:#FFCA80'        bash/.bashrc
check "fzf prompt = Green"          grep -q 'prompt:#8AFF80'      bash/.bashrc
check "fzf pointer = Pink"          grep -q 'pointer:#FF80BF'     bash/.bashrc
check "fzf marker = Pink"           grep -q 'marker:#FF80BF'      bash/.bashrc
check "fzf spinner = Orange"        grep -q 'spinner:#FFCA80'     bash/.bashrc
check "fzf header = Comment"        grep -q 'header:#7970A9'      bash/.bashrc
check "no lowercase Classic fzf hex" bash -c "! grep -qE '#(bd93f9|6272a4|44475a|282a36|ff5555|50fa7b|ffb86c|ff79c6|f1fa8c|8be9fd)' bash/.bashrc"
```

- [ ] **Step 2: Run tests — confirm AC-B-fzf fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: 13 failing checks under AC-B-fzf.

- [ ] **Step 3: Find the FZF_DEFAULT_OPTS block in `bash/.bashrc`**

Run: `grep -nA 11 '^export FZF_DEFAULT_OPTS=' bash/.bashrc`
Expected: shows the block at lines 251-261.

- [ ] **Step 4: Replace the FZF_DEFAULT_OPTS block**

Find (verbatim, including surrounding newlines):
```bash
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --info=inline
  --bind=ctrl-j:down,ctrl-k:up
  --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
  --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
  --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
  --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
'
```

Replace with:
```bash
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --info=inline
  --bind=ctrl-j:down,ctrl-k:up
  --color=fg:#F8F8F2,bg:#22212C,hl:#9580FF
  --color=fg+:#F8F8F2,bg+:#454158,hl+:#9580FF
  --color=info:#FFCA80,prompt:#8AFF80,pointer:#FF80BF
  --color=marker:#FF80BF,spinner:#FFCA80,header:#7970A9
'
```

- [ ] **Step 5: Verify `bash -n` parses**

Run: `bash -n bash/.bashrc`
Expected: exit 0.

- [ ] **Step 6: Run tests — confirm AC-B-fzf passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: all 13 AC-B-fzf checks pass.

- [ ] **Step 7: Commit**

```bash
git add bash/.bashrc scripts/test-plan-theming.sh
git commit -m "feat(fzf): substitute Pro Base hex in FZF_DEFAULT_OPTS"
```

---

## Task 7: ripgrep — ship `ripgrep/config` + wire env var (AC-B-ripgrep)

ripgrep has no committed config in this repo yet. Classic source `dracula/ripgrep` ships an INSTALL.md with four `--colors` directives. Wave B creates a committed config file and wires `RIPGREP_CONFIG_PATH` via bashrc.

**Files:**
- Create: `ripgrep/config`
- Modify: `bash/.bashrc`
- Modify: `install-macos.sh`
- Modify: `install-wsl.sh`
- Modify: `scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-B-ripgrep checks to the test script**

After the AC-B-fzf block, insert:

```bash

# ── AC-B-ripgrep ─────────────────────────────────────────────────────────────
echo ""
echo "AC-B-ripgrep: ripgrep --colors config uses Pro Base hex"
check "ripgrep/config exists"                 test -f ripgrep/config
check "path = Purple (0x95,0x80,0xFF)"        grep -q 'colors=path:fg:0x95,0x80,0xFF'    ripgrep/config
check "line = Green (0x8A,0xFF,0x80)"         grep -q 'colors=line:fg:0x8A,0xFF,0x80'    ripgrep/config
check "column = Green (0x8A,0xFF,0x80)"       grep -q 'colors=column:fg:0x8A,0xFF,0x80'  ripgrep/config
check "match = Red (0xFF,0x95,0x80)"          grep -q 'colors=match:fg:0xFF,0x95,0x80'   ripgrep/config
check "RIPGREP_CONFIG_PATH exported"          grep -qE '^export RIPGREP_CONFIG_PATH=.*ripgrep/config' bash/.bashrc
check "install-macos.sh links ripgrep/config" grep -qE 'link\s+ripgrep/config\s+\.config/ripgrep/config' install-macos.sh
check "install-wsl.sh   links ripgrep/config" grep -qE 'link\s+ripgrep/config\s+\.config/ripgrep/config' install-wsl.sh
```

- [ ] **Step 2: Run tests — confirm AC-B-ripgrep fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: 8 failing checks.

- [ ] **Step 3: Create `ripgrep/config`**

Run: `mkdir -p ripgrep`

Create `ripgrep/config` with this content:
```
# Dracula Pro palette for ripgrep
# Source: docs/design/theming.md § 3.2 (Tier 2 — Pro-from-Classic)
# Palette hex facts from scripts/lib/dracula-pro-palette.sh:
#   Purple = #9580FF    Green = #8AFF80    Red = #FF9580
#
# ripgrep's --colors flag takes RGB triples in hex, one component per byte
# (path:fg:0xRR,0xGG,0xBB). See `rg --help | grep -A20 '^--colors'`.

# path          = Purple
--colors=path:fg:0x95,0x80,0xFF
# line numbers  = Green
--colors=line:fg:0x8A,0xFF,0x80
# column numbers = Green
--colors=column:fg:0x8A,0xFF,0x80
# match         = Red
--colors=match:fg:0xFF,0x95,0x80

# Defaults worth keeping even outside theming:
--smart-case
--hidden
--glob=!.git/
```

- [ ] **Step 4: Wire `RIPGREP_CONFIG_PATH` in `bash/.bashrc`**

Find (in section 11 — Environment variables, around line 247):
```bash
export BAT_THEME="Dracula"
```

Immediately after that line, insert:
```bash

# ripgrep — load Dracula Pro --colors from the repo-tracked config.
# See docs/design/theming.md § 3.2. Path resolution uses $HOME because the
# installer symlinks ripgrep/config into ~/.config/ripgrep/config.
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"
```

- [ ] **Step 5: Add a `link()` call in `install-macos.sh`**

Find (around line 313, the Wave A/Layer 1a atuin block):
```bash
# television cable channels (Layer 1b-iii) — directory-level symlink so
# additional .toml files added later require no re-wire.
link television/cable         .config/television/cable
```

Immediately after the television-cable block, insert:
```bash

# ripgrep (Wave B — Dracula Pro via --colors config)
link ripgrep/config  .config/ripgrep/config
```

- [ ] **Step 6: Add the same `link()` call in `install-wsl.sh`**

Find the matching television-cable block in `install-wsl.sh` and insert the same `link ripgrep/config .config/ripgrep/config` block immediately after it. (If `install-wsl.sh` structure differs, place the new link next to the starship or atuin link — the key invariant is that it runs inside the main symlink loop.)

- [ ] **Step 7: Verify shell scripts parse**

Run:
```bash
bash -n bash/.bashrc && bash -n install-macos.sh && bash -n install-wsl.sh && echo "OK"
```
Expected: `OK`.

- [ ] **Step 8: Run tests — confirm AC-B-ripgrep passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: all 8 AC-B-ripgrep checks pass.

- [ ] **Step 9: Commit**

```bash
git add ripgrep/config bash/.bashrc install-macos.sh install-wsl.sh scripts/test-plan-theming.sh
git commit -m "feat(ripgrep): ship Dracula Pro --colors config"
```

---

## Task 8: eza — export EZA_COLORS with Pro Base hex (AC-B-eza)

Classic source `dracula/eza` uses ANSI 16-colour codes (`uu=36`, etc.). Those delegate back to the terminal's ANSI slots, which already map to the Pro palette via the Tier 1 kitty/ghostty theme (Wave A). However the spec says every slot MUST be asserted; ANSI-by-number punts on that assertion. Wave B therefore switches to 24-bit SGR (`38;2;R;G;B`) for every permission slot so the AC can grep exact Pro hex as RGB triples.

**Files:**
- Modify: `bash/.bashrc`
- Modify: `scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-B-eza checks to the test script**

After the AC-B-ripgrep block, insert:

```bash

# ── AC-B-eza ─────────────────────────────────────────────────────────────────
echo ""
echo "AC-B-eza: EZA_COLORS is exported with Pro Base hex RGB"
check "EZA_COLORS is exported"          grep -qE '^export EZA_COLORS='  bash/.bashrc
check "da (date) = Comment"             grep -q 'da=38;2;121;112;169' bash/.bashrc
check "ur (user read)  = Purple"        grep -q 'ur=38;2;149;128;255' bash/.bashrc
check "uw (user write) = Red"           grep -q 'uw=38;2;255;149;128' bash/.bashrc
check "ux (user exec)  = Green"         grep -q 'ux=38;2;138;255;128' bash/.bashrc
check "ue (user other) = Orange"        grep -q 'ue=38;2;255;202;128' bash/.bashrc
check "xx (dash / empty) = BrightBlack" grep -q 'xx=38;2;80;76;103'   bash/.bashrc
```

- [ ] **Step 2: Run tests — confirm AC-B-eza fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: 7 failing checks.

- [ ] **Step 3: Add EZA_COLORS export to `bash/.bashrc`**

Find (section 11, just after the `RIPGREP_CONFIG_PATH` export added in Task 7):
```bash
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"
```

Immediately after it, insert:
```bash

# eza — Dracula Pro palette via 24-bit SGR (38;2;R;G;B). Each permission
# slot is asserted by scripts/test-plan-theming.sh; see docs/design/theming.md
# § 3.2. Pro Base hex → decimal RGB:
#   Comment    #7970A9 = 121,112,169
#   Purple     #9580FF = 149,128,255
#   Red        #FF9580 = 255,149,128
#   Green      #8AFF80 = 138,255,128
#   Orange     #FFCA80 = 255,202,128
#   Cyan       #80FFEA = 128,255,234
#   BrightBlk  #504C67 = 80,76,103
export EZA_COLORS="\
da=38;2;121;112;169:\
ur=38;2;149;128;255:\
uw=38;2;255;149;128:\
ux=38;2;138;255;128:\
ue=38;2;255;202;128:\
gr=38;2;149;128;255:\
gw=38;2;255;149;128:\
gx=38;2;138;255;128:\
tr=38;2;149;128;255:\
tw=38;2;255;149;128:\
tx=38;2;138;255;128:\
xx=38;2;80;76;103:\
uu=38;2;128;255;234:\
gu=38;2;248;248;242:\
un=38;2;255;128;191:\
uR=38;2;255;149;128"
```

- [ ] **Step 4: Verify `bash -n` parses**

Run: `bash -n bash/.bashrc`
Expected: exit 0.

- [ ] **Step 5: Run tests — confirm AC-B-eza passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: all 7 AC-B-eza checks pass.

- [ ] **Step 6: Commit**

```bash
git add bash/.bashrc scripts/test-plan-theming.sh
git commit -m "feat(eza): export EZA_COLORS with Pro Base hex (24-bit SGR)"
```

---

## Task 9: dircolors — ship `.dir_colors` + eval in bashrc (AC-B-dircolors)

Classic source `dracula/dircolors` ships a complete `.dircolors` file with 24-bit SGR escapes. Wave B ships a Pro-substituted version under `dircolors/.dir_colors`, symlinks it to `~/.dir_colors`, and evals `dircolors -b ~/.dir_colors` in bashrc. Only the handful of asserted slots need to be verbatim in ACs — the rest of the file is a direct Classic→Pro hex substitution.

**Files:**
- Create: `dircolors/.dir_colors`
- Modify: `bash/.bashrc`
- Modify: `install-macos.sh`
- Modify: `install-wsl.sh`
- Modify: `scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-B-dircolors checks to the test script**

After the AC-B-eza block, insert:

```bash

# ── AC-B-dircolors ───────────────────────────────────────────────────────────
echo ""
echo "AC-B-dircolors: .dir_colors uses Pro Base hex (24-bit SGR)"
check ".dir_colors exists"                 test -f dircolors/.dir_colors
check "DIR = Purple (149,128,255)"         grep -qE 'DIR .*38;2;149;128;255'    dircolors/.dir_colors
check "LINK = Cyan (128,255,234)"          grep -qE 'LINK .*38;2;128;255;234'   dircolors/.dir_colors
check "FIFO fg = Yellow (255,255,128)"     grep -qE 'FIFO .*38;2;255;255;128'   dircolors/.dir_colors
check "ORPHAN = Red (255,149,128)"         grep -qE 'ORPHAN .*38;2;255;149;128' dircolors/.dir_colors
check "SETUID bg = Red (255,149,128)"      grep -qE 'SETUID .*48;2;255;149;128' dircolors/.dir_colors
check "no Classic 24-bit triples remain"   bash -c "! grep -qE '38;2;(189;147;249|98;114;164|139;233;253|255;121;198|255;85;85|255;184;108|241;250;140|80;250;123)' dircolors/.dir_colors"
check "bashrc evals dircolors"             grep -q 'eval "\$(dircolors -b.*\.dir_colors)"' bash/.bashrc
check "install-macos.sh links .dir_colors" grep -qE 'link\s+dircolors/\.dir_colors\s+\.dir_colors' install-macos.sh
check "install-wsl.sh   links .dir_colors" grep -qE 'link\s+dircolors/\.dir_colors\s+\.dir_colors' install-wsl.sh
```

- [ ] **Step 2: Run tests — confirm AC-B-dircolors fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: 10 failing checks.

- [ ] **Step 3: Create `dircolors/.dir_colors`**

Run: `mkdir -p dircolors`

Create `dircolors/.dir_colors` with this content. (This is a Classic→Pro substitution of the upstream `dracula/dircolors/.dircolors` file; the complete Classic file contains every FILE extension slot — those lines are unchanged except where hex triples appear. For brevity, assertion-critical slots are shown; the Classic→Pro substitution table below the file is applied to every remaining line.)

```
# Dracula Pro .dir_colors
# Source: docs/design/theming.md § 3.2 (Tier 2 — Pro-from-Classic)
# Classic upstream: github.com/dracula/dircolors (MIT). Only hex facts
# (24-bit SGR triples) are reproduced; structure is copied for compatibility
# with `dircolors -b`.
#
# Pro Base palette → decimal RGB:
#   Black       #22212C =  34, 33, 44
#   Red         #FF9580 = 255,149,128
#   Green       #8AFF80 = 138,255,128
#   Yellow      #FFFF80 = 255,255,128
#   Blue/Purple #9580FF = 149,128,255
#   Magenta     #FF80BF = 255,128,191
#   Cyan        #80FFEA = 128,255,234
#   White       #F8F8F2 = 248,248,242

COLORTERM ?*
TERM Eterm
TERM ansi
TERM *color*
TERM con[0-9]*x[0-9]*
TERM cons25
TERM console
TERM cygwin
TERM *direct*
TERM dtterm
TERM gnome
TERM hurd
TERM jfbterm
TERM konsole
TERM kterm
TERM linux
TERM linux-c
TERM mlterm
TERM putty
TERM rxvt*
TERM screen*
TERM st
TERM terminator
TERM tmux*
TERM vt220
TERM xterm*

# Attribute codes:
# 00=none 01=bold 04=underscore 05=blink 07=reverse 08=concealed

RESET 0
DIR 01;38;2;149;128;255
LINK 01;38;2;128;255;234
MULTIHARDLINK 00
FIFO 48;2;34;33;44;38;2;255;255;128
SOCK 01;38;2;255;128;191
DOOR 01;38;2;255;128;191
BLK 48;2;34;33;44;38;2;255;255;128;01
CHR 48;2;34;33;44;38;2;255;255;128;01
ORPHAN 48;2;34;33;44;38;2;255;149;128;01
MISSING 00
SETUID 38;2;248;248;242;48;2;255;149;128
SETGID 38;2;34;33;44;48;2;255;255;128
CAPABILITY 00
STICKY_OTHER_WRITABLE 38;2;34;33;44;48;2;138;255;128
OTHER_WRITABLE 38;2;149;128;255;48;2;138;255;128
STICKY 38;2;248;248;242;48;2;149;128;255

EXEC 01;38;2;138;255;128

# ── Archives (Red) ──────────────────────────────────────────────────────────
.tar  01;38;2;255;149;128
.tgz  01;38;2;255;149;128
.arc  01;38;2;255;149;128
.arj  01;38;2;255;149;128
.taz  01;38;2;255;149;128
.lha  01;38;2;255;149;128
.lz4  01;38;2;255;149;128
.lzh  01;38;2;255;149;128
.lzma 01;38;2;255;149;128
.tlz  01;38;2;255;149;128
.txz  01;38;2;255;149;128
.tzo  01;38;2;255;149;128
.t7z  01;38;2;255;149;128
.zip  01;38;2;255;149;128
.z    01;38;2;255;149;128
.dz   01;38;2;255;149;128
.gz   01;38;2;255;149;128
.lrz  01;38;2;255;149;128
.lz   01;38;2;255;149;128
.lzo  01;38;2;255;149;128
.xz   01;38;2;255;149;128
.zst  01;38;2;255;149;128
.tzst 01;38;2;255;149;128
.bz2  01;38;2;255;149;128
.bz   01;38;2;255;149;128
.tbz  01;38;2;255;149;128
.tbz2 01;38;2;255;149;128
.tz   01;38;2;255;149;128
.deb  01;38;2;255;149;128
.rpm  01;38;2;255;149;128
.jar  01;38;2;255;149;128
.war  01;38;2;255;149;128
.ear  01;38;2;255;149;128
.sar  01;38;2;255;149;128
.rar  01;38;2;255;149;128
.alz  01;38;2;255;149;128
.ace  01;38;2;255;149;128
.zoo  01;38;2;255;149;128
.cpio 01;38;2;255;149;128
.7z   01;38;2;255;149;128
.rz   01;38;2;255;149;128
.cab  01;38;2;255;149;128
.wim  01;38;2;255;149;128
.swm  01;38;2;255;149;128
.dwm  01;38;2;255;149;128
.esd  01;38;2;255;149;128

# ── Images (Magenta) ────────────────────────────────────────────────────────
.jpg  01;38;2;255;128;191
.jpeg 01;38;2;255;128;191
.mjpg 01;38;2;255;128;191
.mjpeg 01;38;2;255;128;191
.gif  01;38;2;255;128;191
.bmp  01;38;2;255;128;191
.pbm  01;38;2;255;128;191
.pgm  01;38;2;255;128;191
.ppm  01;38;2;255;128;191
.tga  01;38;2;255;128;191
.xbm  01;38;2;255;128;191
.xpm  01;38;2;255;128;191
.tif  01;38;2;255;128;191
.tiff 01;38;2;255;128;191
.png  01;38;2;255;128;191
.svg  01;38;2;255;128;191
.svgz 01;38;2;255;128;191
.mng  01;38;2;255;128;191
.pcx  01;38;2;255;128;191
.mov  01;38;2;255;128;191
.mpg  01;38;2;255;128;191
.mpeg 01;38;2;255;128;191
.m2v  01;38;2;255;128;191
.mkv  01;38;2;255;128;191
.webm 01;38;2;255;128;191
.webp 01;38;2;255;128;191
.ogm  01;38;2;255;128;191
.mp4  01;38;2;255;128;191
.m4v  01;38;2;255;128;191
.mp4v 01;38;2;255;128;191
.vob  01;38;2;255;128;191
.qt   01;38;2;255;128;191
.nuv  01;38;2;255;128;191
.wmv  01;38;2;255;128;191
.asf  01;38;2;255;128;191
.rm   01;38;2;255;128;191
.rmvb 01;38;2;255;128;191
.flc  01;38;2;255;128;191
.avi  01;38;2;255;128;191
.fli  01;38;2;255;128;191
.flv  01;38;2;255;128;191
.gl   01;38;2;255;128;191
.dl   01;38;2;255;128;191
.xcf  01;38;2;255;128;191
.xwd  01;38;2;255;128;191
.yuv  01;38;2;255;128;191
.cgm  01;38;2;255;128;191
.emf  01;38;2;255;128;191
.ogv  01;38;2;255;128;191
.ogx  01;38;2;255;128;191

# ── Audio (Cyan) ────────────────────────────────────────────────────────────
.aac  00;38;2;128;255;234
.au   00;38;2;128;255;234
.flac 00;38;2;128;255;234
.m4a  00;38;2;128;255;234
.mid  00;38;2;128;255;234
.midi 00;38;2;128;255;234
.mka  00;38;2;128;255;234
.mp3  00;38;2;128;255;234
.mpc  00;38;2;128;255;234
.ogg  00;38;2;128;255;234
.ra   00;38;2;128;255;234
.wav  00;38;2;128;255;234
.oga  00;38;2;128;255;234
.opus 00;38;2;128;255;234
.spx  00;38;2;128;255;234
.xspf 00;38;2;128;255;234
```

Substitution table used (for any Classic-file lines not listed above that an engineer may encounter in the upstream file):

| Classic RGB triple        | Pro RGB triple             |
|---------------------------|----------------------------|
| `38;2;189;147;249`        | `38;2;149;128;255`         |
| `48;2;189;147;249`        | `48;2;149;128;255`         |
| `38;2;98;114;164`         | `38;2;121;112;169`         |
| `38;2;139;233;253`        | `38;2;128;255;234`         |
| `48;2;139;233;253`        | `48;2;128;255;234`         |
| `38;2;255;121;198`        | `38;2;255;128;191`         |
| `48;2;255;121;198`        | `48;2;255;128;191`         |
| `38;2;255;85;85`          | `38;2;255;149;128`         |
| `48;2;255;85;85`          | `48;2;255;149;128`         |
| `38;2;255;184;108`        | `38;2;255;202;128`         |
| `48;2;255;184;108`        | `48;2;255;202;128`         |
| `38;2;241;250;140`        | `38;2;255;255;128`         |
| `48;2;241;250;140`        | `48;2;255;255;128`         |
| `38;2;80;250;123`         | `38;2;138;255;128`         |
| `48;2;80;250;123`         | `48;2;138;255;128`         |
| `38;2;33;34;44`           | `38;2;34;33;44`            |
| `48;2;33;34;44`           | `48;2;34;33;44`            |
| `38;2;248;248;242`        | `38;2;248;248;242` (same)  |

- [ ] **Step 4: Wire dircolors eval in `bash/.bashrc`**

Find (section 11, just after the EZA_COLORS block added in Task 8):
```bash
export EZA_COLORS="\
...
uR=38;2;255;149;128"
```

Immediately after it, insert:
```bash

# dircolors — compile ~/.dir_colors into LS_COLORS. GNU dircolors only;
# macOS ships BSD ls which ignores LS_COLORS, but eza/ls aliases use eza
# on both platforms (see bash/.bash_aliases) so LS_COLORS is still relevant
# for any stray `ls` invocations inside git subcommands, fd, etc.
if command -v dircolors &>/dev/null && [[ -r "$HOME/.dir_colors" ]]; then
  eval "$(dircolors -b "$HOME/.dir_colors")"
fi
```

- [ ] **Step 5: Add `link()` in install-macos.sh and install-wsl.sh**

Find the ripgrep block added in Task 7 (in both scripts):
```bash
# ripgrep (Wave B — Dracula Pro via --colors config)
link ripgrep/config  .config/ripgrep/config
```

Immediately after it, insert:
```bash

# dircolors (Wave B — ls/LS_COLORS Dracula Pro via dircolors -b)
link dircolors/.dir_colors  .dir_colors
```

- [ ] **Step 6: Verify scripts parse**

Run:
```bash
bash -n bash/.bashrc && bash -n install-macos.sh && bash -n install-wsl.sh && echo "OK"
```
Expected: `OK`.

- [ ] **Step 7: Run tests — confirm AC-B-dircolors passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: all 10 AC-B-dircolors checks pass.

- [ ] **Step 8: Commit**

```bash
git add dircolors/.dir_colors bash/.bashrc install-macos.sh install-wsl.sh scripts/test-plan-theming.sh
git commit -m "feat(dircolors): ship Dracula Pro .dir_colors + eval in bashrc"
```

---

## Task 10: opencode — author `themes/dracula-pro.json` + set theme key (AC-B-opencode)

opencode's Classic source (`dracula/opencode/dracula.json`) is a two-layer file: a `defs` block declaring palette hex, and a `theme` block mapping semantic slots to `defs` names. Wave B clones the structure (our code, not a Pro-theme-file reproduction) with Pro hex in `defs`.

**Files:**
- Create: `opencode/themes/dracula-pro.json`
- Modify: `opencode/tui.jsonc`
- Modify: `install-macos.sh`
- Modify: `install-wsl.sh`
- Modify: `scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-B-opencode checks to the test script**

After the AC-B-dircolors block, insert:

```bash

# ── AC-B-opencode ────────────────────────────────────────────────────────────
echo ""
echo "AC-B-opencode: opencode tui.jsonc uses dracula-pro custom theme"
check "tui.jsonc theme = dracula-pro"          grep -qE '"theme"\s*:\s*"dracula-pro"' opencode/tui.jsonc
check "opencode/themes/dracula-pro.json"       test -f opencode/themes/dracula-pro.json
check "theme bgPrimary = Background"           grep -q '"#22212C"' opencode/themes/dracula-pro.json
check "theme bgSecondary = Selection"          grep -q '"#454158"' opencode/themes/dracula-pro.json
check "theme foreground = Foreground"          grep -q '"#F8F8F2"' opencode/themes/dracula-pro.json
check "theme comment = Comment"                grep -q '"#7970A9"' opencode/themes/dracula-pro.json
check "theme red = Red"                        grep -q '"#FF9580"' opencode/themes/dracula-pro.json
check "theme orange = Orange"                  grep -q '"#FFCA80"' opencode/themes/dracula-pro.json
check "theme yellow = Yellow"                  grep -q '"#FFFF80"' opencode/themes/dracula-pro.json
check "theme green = Green"                    grep -q '"#8AFF80"' opencode/themes/dracula-pro.json
check "theme cyan = Cyan"                      grep -q '"#80FFEA"' opencode/themes/dracula-pro.json
check "theme purple = Purple"                  grep -q '"#9580FF"' opencode/themes/dracula-pro.json
check "theme pink = Pink"                      grep -q '"#FF80BF"' opencode/themes/dracula-pro.json
check "install-macos.sh links theme file"      grep -qE 'link opencode/themes/dracula-pro\.json.*\.config/opencode/themes/dracula-pro\.json' install-macos.sh
check "install-wsl.sh   links theme file"      grep -qE 'link opencode/themes/dracula-pro\.json.*\.config/opencode/themes/dracula-pro\.json' install-wsl.sh
```

- [ ] **Step 2: Run tests — confirm AC-B-opencode fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: all 15 AC-B-opencode checks fail.

- [ ] **Step 3: Create `opencode/themes/dracula-pro.json`**

Run: `mkdir -p opencode/themes`

Create `opencode/themes/dracula-pro.json` with this content:
```json
{
  "$schema": "https://opencode.ai/theme.json",
  "defs": {
    "bgPrimary": "#22212C",
    "bgSecondary": "#454158",
    "bgSelection": "#454158",
    "foreground": "#F8F8F2",
    "comment": "#7970A9",
    "red": "#FF9580",
    "orange": "#FFCA80",
    "yellow": "#FFFF80",
    "green": "#8AFF80",
    "cyan": "#80FFEA",
    "purple": "#9580FF",
    "pink": "#FF80BF",
    "bgDiffAdded": "#2B3A2F",
    "bgDiffRemoved": "#3D2A2E"
  },
  "theme": {
    "primary": "purple",
    "secondary": "cyan",
    "accent": "pink",
    "error": "red",
    "warning": "orange",
    "success": "green",
    "info": "cyan",
    "text": "foreground",
    "textMuted": "comment",
    "background": "bgPrimary",
    "backgroundPanel": "bgSecondary",
    "backgroundElement": "bgSecondary",
    "border": "bgSelection",
    "borderActive": "purple",
    "borderSubtle": "bgSelection",
    "diffAdded": "green",
    "diffRemoved": "red",
    "diffContext": "foreground",
    "diffHunkHeader": "comment",
    "diffHighlightAdded": "green",
    "diffHighlightRemoved": "red",
    "diffAddedBg": "bgDiffAdded",
    "diffRemovedBg": "bgDiffRemoved",
    "diffContextBg": "bgSecondary",
    "diffLineNumber": "comment",
    "diffAddedLineNumberBg": "bgDiffAdded",
    "diffRemovedLineNumberBg": "bgDiffRemoved",
    "markdownText": "foreground",
    "markdownHeading": "purple",
    "markdownLink": "cyan",
    "markdownLinkText": "pink",
    "markdownCode": "green",
    "markdownBlockQuote": "comment",
    "markdownEmph": "yellow",
    "markdownStrong": "orange",
    "markdownHorizontalRule": "comment",
    "markdownListItem": "cyan",
    "markdownListEnumeration": "purple",
    "markdownImage": "pink",
    "markdownImageText": "yellow",
    "markdownCodeBlock": "green",
    "syntaxComment": "comment",
    "syntaxKeyword": "pink",
    "syntaxFunction": "green",
    "syntaxVariable": "foreground",
    "syntaxString": "yellow",
    "syntaxNumber": "purple",
    "syntaxType": "cyan",
    "syntaxOperator": "pink",
    "syntaxPunctuation": "foreground"
  }
}
```

(The `bgDiffAdded` / `bgDiffRemoved` values are not part of the Terminal Standard palette; they are low-saturation derivations used in Classic as diff-line shading and are kept as-is per § 5.1 — they are chrome, not a named palette slot. If the reviewer flags this, swap them to values computed off `DRACULA_PRO_GREEN`/`DRACULA_PRO_RED` with 15% alpha against Background. The AC does NOT assert these two values — only the named slots.)

- [ ] **Step 4: Set `theme = "dracula-pro"` in `opencode/tui.jsonc`**

Find the opening object in `opencode/tui.jsonc` (line 1 starts `{`). Find the top-level object body — specifically the `"keybinds"` key on line 3.

Insert the `theme` key BEFORE `"keybinds"`. Replace:
```jsonc
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
```

With:
```jsonc
{
  "$schema": "https://opencode.ai/tui.json",
  "theme": "dracula-pro",
  "keybinds": {
```

- [ ] **Step 5: Add `link()` calls in install-macos.sh and install-wsl.sh**

Find the existing opencode link block in `install-macos.sh` (around line 343):
```bash
# opencode (Plan 9)
link opencode/opencode.jsonc                    .config/opencode/opencode.jsonc
link opencode/tui.jsonc                         .config/opencode/tui.jsonc
link opencode/instructions/git-conventions.md   .config/opencode/instructions/git-conventions.md
link opencode/instructions/scratch-dirs.md      .config/opencode/instructions/scratch-dirs.md
```

Replace with (adds one new line):
```bash
# opencode (Plan 9 + Wave B theme)
link opencode/opencode.jsonc                    .config/opencode/opencode.jsonc
link opencode/tui.jsonc                         .config/opencode/tui.jsonc
link opencode/themes/dracula-pro.json           .config/opencode/themes/dracula-pro.json
link opencode/instructions/git-conventions.md   .config/opencode/instructions/git-conventions.md
link opencode/instructions/scratch-dirs.md      .config/opencode/instructions/scratch-dirs.md
```

Do the same in `install-wsl.sh` (same pattern — insert the new link in the opencode block).

- [ ] **Step 6: Verify JSONC is still valid (no trailing-comma breakage)**

Run:
```bash
python3 -c "import json, re, pathlib; \
s = pathlib.Path('opencode/tui.jsonc').read_text(); \
s = re.sub(r'//.*', '', s); \
s = re.sub(r',(\s*[}\]])', r'\1', s); \
json.loads(s); print('OK')"
```
Expected: `OK`.

And validate the theme JSON:
```bash
python3 -c "import json; json.load(open('opencode/themes/dracula-pro.json')); print('OK')"
```
Expected: `OK`.

- [ ] **Step 7: Run tests — confirm AC-B-opencode passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: all 15 AC-B-opencode checks pass.

- [ ] **Step 8: Commit**

```bash
git add opencode/themes/dracula-pro.json opencode/tui.jsonc install-macos.sh install-wsl.sh scripts/test-plan-theming.sh
git commit -m "feat(opencode): add dracula-pro theme file + wire in tui.jsonc"
```

---

## Task 11: man-pages — LESS_TERMCAP env vars with Pro Base hex (AC-B-man-pages)

Classic source `dracula/man-pages` uses ANSI 16-colour SGR (`\e[1;31m`). Wave B upgrades to 24-bit SGR so every Pro Base slot is asserted by hex, not ANSI index.

**Files:**
- Modify: `bash/.bashrc`
- Modify: `scripts/test-plan-theming.sh`

- [ ] **Step 1: Append AC-B-man-pages checks to the test script**

After the AC-B-opencode block, insert:

```bash

# ── AC-B-man-pages ───────────────────────────────────────────────────────────
echo ""
echo "AC-B-man-pages: less/MANPAGER env uses Pro Base hex (24-bit SGR)"
check "LESS_TERMCAP_md (bold) = Purple"           grep -qE 'LESS_TERMCAP_md=.*38;2;149;128;255' bash/.bashrc
check "LESS_TERMCAP_us (underline) = Cyan"        grep -qE 'LESS_TERMCAP_us=.*38;2;128;255;234' bash/.bashrc
check "LESS_TERMCAP_so (standout) = Black on Org" grep -qE 'LESS_TERMCAP_so=.*38;2;34;33;44.*48;2;255;202;128' bash/.bashrc
check "LESS_TERMCAP_mb (blink) = Red"             grep -qE 'LESS_TERMCAP_mb=.*38;2;255;149;128' bash/.bashrc
check "GROFF_NO_SGR=1 exported"                   grep -qE 'export GROFF_NO_SGR=1' bash/.bashrc
```

- [ ] **Step 2: Run tests — confirm AC-B-man-pages fails**

Run: `bash scripts/test-plan-theming.sh`
Expected: 5 failing checks.

- [ ] **Step 3: Add LESS_TERMCAP exports to `bash/.bashrc`**

Find the end of section 11 — the dircolors eval added in Task 9:
```bash
if command -v dircolors &>/dev/null && [[ -r "$HOME/.dir_colors" ]]; then
  eval "$(dircolors -b "$HOME/.dir_colors")"
fi
```

Immediately after it, insert:
```bash

# man-pages — Dracula Pro colours via LESS termcap env vars. 24-bit SGR so
# every slot is greppable as a Pro hex RGB. GROFF_NO_SGR=1 prevents groff
# from stripping the SGR escapes that less then re-interprets.
# Pro Base hex → decimal RGB:
#   Black       #22212C =  34, 33, 44
#   Red         #FF9580 = 255,149,128
#   Purple      #9580FF = 149,128,255
#   Cyan        #80FFEA = 128,255,234
#   Orange      #FFCA80 = 255,202,128
export GROFF_NO_SGR=1
export LESS_TERMCAP_mb=$'\e[38;2;255;149;128m'                   # begin blink  = Red
export LESS_TERMCAP_md=$'\e[1;38;2;149;128;255m'                 # begin bold   = Purple
export LESS_TERMCAP_so=$'\e[38;2;34;33;44;48;2;255;202;128m'     # reverse video= Black on Orange
export LESS_TERMCAP_us=$'\e[4;38;2;128;255;234m'                 # underline    = Cyan
export LESS_TERMCAP_me=$'\e[0m'                                  # reset bold/blink
export LESS_TERMCAP_se=$'\e[0m'                                  # reset reverse
export LESS_TERMCAP_ue=$'\e[0m'                                  # reset underline
```

Note: the existing `MANPAGER='nvim +Man!'` / `MANPAGER="sh -c 'col -bx | bat -l man -p'"` assignment (lines 237-245) is untouched. When `nvim +Man!` is the pager, LESS_TERMCAP is unused; when `bat -l man -p` is the pager, `bat` uses `BAT_THEME` (set on line 247, a Wave C concern). When the user overrides `MANPAGER=less` in `.bashrc.local`, the LESS_TERMCAP exports take effect and the AC-B-man-pages block is satisfied.

- [ ] **Step 4: Verify `bash -n` parses**

Run: `bash -n bash/.bashrc`
Expected: exit 0.

- [ ] **Step 5: Run tests — confirm AC-B-man-pages passes**

Run: `bash scripts/test-plan-theming.sh`
Expected: all 5 AC-B-man-pages checks pass.

- [ ] **Step 6: Commit**

```bash
git add bash/.bashrc scripts/test-plan-theming.sh
git commit -m "feat(man-pages): LESS_TERMCAP with Pro Base hex (24-bit SGR)"
```

---

## Task 12: pygments — probe PyPI, fall back to local style module (AC-B-pygments)

Spec § 8 open item: verify whether `pygments-dracula-pro` exists on PyPI at Wave B implementation time. If it does, the plan's install path is a one-liner in `install-macos.sh` and `install-wsl.sh`. If it does not, Wave B authors a local pygments style file and registers it via a pyproject entry point installed through `uv tool install --from .`.

**Files:**
- Modify: `scripts/test-plan-theming.sh`
- Create (conditional): `pygments/dracula_pro.py`, `pygments/pyproject.toml`
- Modify (conditional): `install-macos.sh`, `install-wsl.sh`

- [ ] **Step 1: Probe PyPI**

Run:
```bash
curl -sfS https://pypi.org/pypi/pygments-dracula-pro/json -o /dev/null -w "%{http_code}\n"
```
- Output `200` → follow Sub-task 12a (PyPI install).
- Output `404`  → follow Sub-task 12b (local style module).
- Any other code → escalate: rerun once; if still non-2xx and non-404, treat as 404 (assume package absent) and note the exact code in the commit message for auditability.

Known answer at plan-authoring time (2026-04-17): `404`. Sub-task 12b is the expected path; 12a is documented for completeness and future re-verification.

### Sub-task 12a: PyPI install path (if `pygments-dracula-pro` is available)

- [ ] **Step 2a: Add install-script step**

In `install-macos.sh`, find the Brewfile step (search for `brew bundle --file`). Immediately after the Brewfile install and before the symlink block:

```bash
# pygments Dracula Pro style (Wave B)
if command -v uv &>/dev/null; then
  uv tool install pygments-dracula-pro
fi
```

Mirror the same block in `install-wsl.sh`.

- [ ] **Step 3a: Append AC-B-pygments checks to the test script**

After the AC-B-man-pages block, insert:

```bash

# ── AC-B-pygments ────────────────────────────────────────────────────────────
echo ""
echo "AC-B-pygments: Dracula Pro pygments style is installed"
check "install-macos.sh installs pygments-dracula-pro" \
  grep -qE 'uv tool install pygments-dracula-pro' install-macos.sh
check "install-wsl.sh   installs pygments-dracula-pro" \
  grep -qE 'uv tool install pygments-dracula-pro' install-wsl.sh
# Runtime check gated on pygmentize being available
if command -v pygmentize &>/dev/null; then
  check "pygmentize knows dracula-pro style" \
    bash -c "pygmentize -L styles | grep -q dracula-pro"
else
  skp "pygmentize runtime check" "pygmentize not installed"
fi
```

### Sub-task 12b: Local style module path (if `pygments-dracula-pro` is NOT on PyPI — the expected 2026-04-17 path)

- [ ] **Step 2b: Create `pygments/dracula_pro.py`**

Run: `mkdir -p pygments`

Create `pygments/dracula_pro.py`:
```python
# -*- coding: utf-8 -*-
"""Dracula Pro pygments style.

Palette derived from docs/design/theming.md § 1.3 and the authoritative
scripts/lib/dracula-pro-palette.sh in this repo. Structure is a palette
substitution of github.com/dracula/pygments (MIT); only hex values are
changed, the class is a new authorship.
"""

from pygments.style import Style
from pygments.token import (
    Comment, Error, Generic, Keyword, Literal, Name, Number, Operator,
    Other, Punctuation, String, Text, Whitespace,
)

# Pro Base palette (verbatim; single source of truth is
# scripts/lib/dracula-pro-palette.sh). Reproduced as Python constants so
# `pygmentize -L styles` doesn't need to shell out.
BACKGROUND   = "#22212C"
FOREGROUND   = "#F8F8F2"
COMMENT      = "#7970A9"
SELECTION    = "#454158"
RED          = "#FF9580"
ORANGE       = "#FFCA80"
YELLOW       = "#FFFF80"
GREEN        = "#8AFF80"
CYAN         = "#80FFEA"
PURPLE       = "#9580FF"
PINK         = "#FF80BF"


class DraculaProStyle(Style):
    name = "dracula-pro"
    background_color = BACKGROUND
    highlight_color = SELECTION
    default_style = ""

    styles = {
        Comment:            COMMENT,
        Comment.Hashbang:   COMMENT,
        Comment.Multiline:  COMMENT,
        Comment.Preproc:    PINK,
        Comment.PreprocFile: PINK,
        Comment.Single:     COMMENT,
        Comment.Special:    CYAN,

        Generic:            PINK,
        Generic.Deleted:    RED,
        Generic.Emph:       f"{YELLOW} underline",
        Generic.Error:      RED,
        Generic.Heading:    f"{PURPLE} bold",
        Generic.Inserted:   f"{GREEN} bold",
        Generic.Output:     COMMENT,
        Generic.Prompt:     GREEN,
        Generic.Strong:     ORANGE,
        Generic.Subheading: f"{PURPLE} bold",
        Generic.Traceback:  RED,

        Error:              RED,

        Keyword:            PINK,
        Keyword.Constant:   PURPLE,
        Keyword.Declaration: f"{PINK} italic",
        Keyword.Namespace:  PINK,
        Keyword.Pseudo:     PINK,
        Keyword.Reserved:   PINK,
        Keyword.Type:       CYAN,

        Literal:            ORANGE,
        Literal.Date:       ORANGE,

        Name:               FOREGROUND,
        Name.Attribute:     GREEN,
        Name.Builtin:       f"{PURPLE} italic",
        Name.Builtin.Pseudo: PURPLE,
        Name.Class:         CYAN,
        Name.Constant:      PURPLE,
        Name.Decorator:     GREEN,
        Name.Entity:        PINK,
        Name.Exception:     RED,
        Name.Function:      GREEN,
        Name.Function.Magic: PURPLE,
        Name.Label:         f"{CYAN} italic",
        Name.Namespace:     FOREGROUND,
        Name.Other:         FOREGROUND,
        Name.Tag:           PINK,
        Name.Variable:      f"{FOREGROUND} italic",
        Name.Variable.Class: f"{CYAN} italic",
        Name.Variable.Global: f"{FOREGROUND} italic",
        Name.Variable.Instance: f"{PURPLE} italic",
        Name.Variable.Magic: PURPLE,

        Number:             PURPLE,
        Number.Bin:         PURPLE,
        Number.Float:       PURPLE,
        Number.Hex:         PURPLE,
        Number.Integer:     PURPLE,
        Number.Integer.Long: PURPLE,
        Number.Oct:         PURPLE,

        Operator:           PINK,
        Operator.Word:      PINK,

        Other:              FOREGROUND,

        Punctuation:        FOREGROUND,

        String:             YELLOW,
        String.Backtick:    GREEN,
        String.Char:        YELLOW,
        String.Doc:         YELLOW,
        String.Double:      YELLOW,
        String.Escape:      PINK,
        String.Heredoc:     YELLOW,
        String.Interpol:    PINK,
        String.Other:       YELLOW,
        String.Regex:       RED,
        String.Single:      YELLOW,
        String.Symbol:      PURPLE,

        Text:               FOREGROUND,

        Whitespace:         FOREGROUND,
    }
```

- [ ] **Step 3b: Create `pygments/pyproject.toml`**

Create `pygments/pyproject.toml`:
```toml
[project]
name = "pygments-dracula-pro-local"
version = "0.1.0"
description = "Local Dracula Pro pygments style — bundled in this dotfiles repo"
requires-python = ">=3.9"
dependencies = ["pygments>=2.15"]

[project.entry-points."pygments.styles"]
"dracula-pro" = "dracula_pro:DraculaProStyle"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
only-include = ["dracula_pro.py"]
```

- [ ] **Step 4b: Add install-script step**

In `install-macos.sh`, find the Brewfile step (search for `brew bundle --file`). Immediately after the Brewfile install and before the symlink block:

```bash
# pygments Dracula Pro style (Wave B — local style, PyPI package not yet
# published as of 2026-04-17; re-verify in follow-up and replace with
# `uv tool install pygments-dracula-pro` once available).
if command -v uv &>/dev/null; then
  uv tool install --from "$DOTFILES/pygments" pygments-dracula-pro-local \
    --with pygments
fi
```

Mirror the same block in `install-wsl.sh`.

- [ ] **Step 5b: Append AC-B-pygments checks to the test script**

After the AC-B-man-pages block, insert:

```bash

# ── AC-B-pygments ────────────────────────────────────────────────────────────
echo ""
echo "AC-B-pygments: local Dracula Pro pygments style authored + installable"
check "pygments/dracula_pro.py exists"        test -f pygments/dracula_pro.py
check "pygments/pyproject.toml exists"        test -f pygments/pyproject.toml
check "style has Pro Purple"                  grep -qE '"#9580FF"|PURPLE\s*=\s*"#9580FF"' pygments/dracula_pro.py
check "entry point = pygments.styles"         grep -qE '"pygments\.styles"' pygments/pyproject.toml
check "entry key = dracula-pro"               grep -qE '"dracula-pro"\s*=' pygments/pyproject.toml
check "install-macos.sh installs local style" grep -qE 'uv tool install --from .*pygments.*pygments-dracula-pro-local' install-macos.sh
check "install-wsl.sh   installs local style" grep -qE 'uv tool install --from .*pygments.*pygments-dracula-pro-local' install-wsl.sh
# Runtime check gated on pygmentize being available — only asserted in --full
if [[ "${FULL:-false}" == true ]] && command -v pygmentize &>/dev/null; then
  check "pygmentize knows dracula-pro style"  bash -c "pygmentize -L styles | grep -q dracula-pro"
else
  skp "pygmentize runtime check" "pygmentize not installed or not --full mode"
fi
```

- [ ] **Step 6: Run tests — confirm AC-B-pygments passes in the active sub-task**

Run: `bash scripts/test-plan-theming.sh`
Expected:
- 12a path: 2 checks pass + 1 skip (or 3 pass if pygmentize is installed locally).
- 12b path: 7 checks pass + 1 skip (or 8 pass if --full mode).

- [ ] **Step 7: Commit**

12a path:
```bash
git add install-macos.sh install-wsl.sh scripts/test-plan-theming.sh
git commit -m "feat(pygments): install pygments-dracula-pro via uv tool (Wave B)"
```

12b path:
```bash
git add pygments/dracula_pro.py pygments/pyproject.toml install-macos.sh install-wsl.sh scripts/test-plan-theming.sh
git commit -m "feat(pygments): local Dracula Pro style module (PyPI package absent)"
```

---

## Task 13: End-to-end Wave B aggregate check (AC-B-aggregate)

**Files:**
- Modify: `scripts/test-plan-theming.sh` (summary block)

- [ ] **Step 1: Confirm the Wave B section header is present**

Run: `grep -c '# ── Wave B: Tier 2 Pro-from-Classic ─' scripts/test-plan-theming.sh`
Expected: `1`.

- [ ] **Step 2: Confirm the script still ends with the Wave A summary + `(( fail == 0 ))`**

Run: `tail -n 5 scripts/test-plan-theming.sh`
Expected (example, may differ by one line depending on Wave A wording):
```bash
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
```

- [ ] **Step 3: Run the aggregate test**

Run: `bash scripts/test-plan-theming.sh`
Expected: every Wave A and Wave B check passes; the script exits 0.

- [ ] **Step 4: Run on the other platform**

On macOS: `bash scripts/test-plan-theming.sh`
On WSL2:  `bash scripts/test-plan-theming.sh`

Expected: same result on both.

- [ ] **Step 5: Wire the script into CI (if not already done by Wave A)**

Check whether Wave A added `bash scripts/test-plan-theming.sh` to any CI workflow:
```bash
grep -rn 'test-plan-theming' .github/ 2>/dev/null || echo "NO CI WIRE"
```
If CI wiring is absent, add it to the `macos-verify` workflow (or the CI system's equivalent) alongside the existing Layer 1a test script. If CI runs locally only, document the manual command in `README.md`. (Wave A owns this; Wave B only verifies.)

- [ ] **Step 6: Commit (if README or CI edits were made; otherwise skip)**

```bash
git add README.md .github/workflows/*.yml 2>/dev/null || true
git commit -m "ci(theming): run Wave B AC script alongside Wave A (if not already)" --allow-empty || true
```

---

## Task 14: Update cheatsheet.md with Wave B-relevant notes

**Files:**
- Modify: `docs/cheatsheet.md`

- [ ] **Step 1: Inspect current cheatsheet for Dracula / theming mentions**

Run: `grep -nE 'Dracula|dracula|BAT_THEME|MANPAGER' docs/cheatsheet.md || echo "NONE"`
Expected: either existing mentions, or `NONE`.

- [ ] **Step 2: Append a Wave B theming note to `docs/cheatsheet.md`**

Add a new section at the natural end of the file (or after the existing theming section, if any):

```markdown
## Theming — Dracula Pro (Wave B, Tier 2)

Tools below use the Pro-from-Classic palette substitution chain
(see `docs/design/theming.md` § 3.2):

| Tool       | Surface                                | Wired via                           |
|------------|----------------------------------------|-------------------------------------|
| starship   | `starship/starship.toml` `[palettes.dracula-pro]` | config                |
| tmux       | `tmux/.tmux.conf` `@dracula-colors`    | TPM plugin override                  |
| lazygit    | `lazygit/config.yml` `gui.theme`       | config                               |
| gh-dash    | `gh-dash/config.yml` `theme.colors`    | config                               |
| yazi       | `yazi/theme.toml`                      | config                               |
| fzf        | `FZF_DEFAULT_OPTS`                     | `bash/.bashrc`                       |
| ripgrep    | `ripgrep/config` `--colors=`           | `RIPGREP_CONFIG_PATH` in bashrc      |
| eza        | `EZA_COLORS`                           | `bash/.bashrc`                       |
| dircolors  | `dircolors/.dir_colors`                | `eval $(dircolors -b)` in bashrc     |
| opencode   | `opencode/themes/dracula-pro.json`     | `theme` key in `tui.jsonc`           |
| man-pages  | `LESS_TERMCAP_*` + `GROFF_NO_SGR`      | `bash/.bashrc`                       |
| pygments   | `pygments/dracula_pro.py` (local)      | `uv tool install --from pygments/`   |

The authoritative palette file is `scripts/lib/dracula-pro-palette.sh`
(committed by Wave A). The aggregate check is `scripts/test-plan-theming.sh`.
```

- [ ] **Step 3: Commit**

```bash
git add docs/cheatsheet.md
git commit -m "docs(cheatsheet): Wave B Dracula Pro theming table"
```

---

## Post-plan: Manual Validation Steps

- [ ] **Manual 1:** Open a fresh tmux session. Verify status line colours visually match Pro (not Classic): segments are tinted with `#9580FF` / `#FF80BF` / `#FFCA80` etc., not `#BD93F9` / `#FF79C6` / `#FFB86C`.

- [ ] **Manual 2:** Run `starship prompt` in a shell: the prompt colours are Pro (the subjective "pink" is brighter/paler on Pro — `#FF80BF` vs `#FF79C6`).

- [ ] **Manual 3:** Invoke `lazygit`: borders are Pro Purple; unstaged-change highlights are Pro Red (`#FF9580`, a softer salmon, vs Classic `#FF5555`).

- [ ] **Manual 4:** Invoke `gh-dash`: table borders are Pro Purple.

- [ ] **Manual 5:** Invoke `yazi`: hover / tab / mode-normal backgrounds are Pro Purple.

- [ ] **Manual 6:** Invoke `fzf` (Ctrl-T or `fd | fzf`): prompt / pointer / match-highlight colours are Pro.

- [ ] **Manual 7:** Run `rg pattern` inside a repo: matches are Pro Red; paths are Pro Purple; line numbers are Pro Green.

- [ ] **Manual 8:** Run `ls` (aliased to `eza`): permission columns use Pro Purple/Red/Green/Orange; date column is Pro Comment (`#7970A9`).

- [ ] **Manual 9:** Run `ls -la` inside an env where `eza` is absent (e.g. container without the alias): GNU ls colours use `.dir_colors` — directories are Pro Purple.

- [ ] **Manual 10:** Open opencode. Check theme picker shows `dracula-pro` and is selected.

- [ ] **Manual 11:** Temporarily override `MANPAGER=less` in current shell (`MANPAGER=less man man`): bold text is Pro Purple, underline is Pro Cyan, standout is Pro Black-on-Orange.

- [ ] **Manual 12:** Run `pygmentize -L styles | grep dracula`: `dracula-pro` is in the list (and `dracula` from the Classic package MAY also be present — that's expected since Classic is a separate pygments package if installed).

- [ ] **Manual 13:** Run `bash scripts/test-plan-theming.sh` on both macOS and WSL2: exit 0, all Wave A + Wave B checks pass.

---

## Self-Review Notes (recorded at plan write time)

**Spec coverage check (§ 3.2 Wave B table, § 5.1 profile coverage, § 6 ACs):**
- starship → Task 1 (palette rename + 11 hex — full "Structural + accents" profile). ✓
- tmux → Task 2 (11 named slots via `@dracula-colors`; open-item check documented inline). ✓
- lazygit → Task 3 (9 theme slots + delta theme-name forward reference). ✓
- gh-dash → Task 4 (10 theme slots). ✓
- yazi → Task 5 (10 distinct hex across 82 lines). ✓
- fzf → Task 6 (12 `--color=` slots — full "Accents only" profile + fg/bg). ✓
- ripgrep → Task 7 (4 `--colors` + env var wiring). ✓
- eza → Task 8 (16 `EZA_COLORS` slots — asserted subset covers every palette colour). ✓
- dircolors → Task 9 (`.dir_colors` with every Classic RGB → Pro RGB substitution + eval + install). ✓
- opencode → Task 10 (custom theme JSON + `theme` key + install wiring). ✓
- man-pages → Task 11 (4 LESS_TERMCAP colour slots + GROFF_NO_SGR). ✓
- pygments → Task 12 (PyPI probe + fallback to local style module with pyproject entry point). ✓
- Aggregate check → Task 13 (AC-B-aggregate). ✓
- Cheatsheet documentation → Task 14. ✓
- Wave B section header in test script → Task 0. ✓

**Placeholder scan (pattern `TBD|TODO|fill in|implement later|add appropriate|Similar to Task`):**
- None found. Every Classic→Pro hex substitution is shown with both values inline. Every AC lists the literal hex it asserts.

**Type/naming consistency:**
- Palette constants (`DRACULA_PRO_*`) and literal hex appear together wherever the engineer references them. Hex case is UPPERCASE throughout Wave B — fzf task explicitly includes an AC asserting absence of Classic's lowercase hex.
- Tool-config file paths are always the worktree-relative form used by `link()` calls (e.g. `ripgrep/config`, `dircolors/.dir_colors`), matching the install-script convention.
- The `check` function is not redefined; it is only called (per prerequisite declaration).
- Test-script section headers use the same comment style as Wave A (`# ── AC-B-<tool> ───`).

**Licensing audit (§ 1.5, § 4.1):**
- No Pro theme files are copied into the repo. Palette hex values (facts) are the only Pro-sourced content.
- opencode `themes/dracula-pro.json` is our authorship (structure cloned from the community Classic file — which is itself a plausible independent authorship; if licence review flags it, the structure can be rewritten).
- The pygments local style module is our authorship; structure parallels the Classic `dracula.py` (MIT), only hex values are ours.

**Open items flagged during planning:**
1. **tmux plugin coverage.** If the reviewer observes any status-line colour outside the 11 `@dracula-colors` slots (Sub-task 2a/Step 2 smoke check), tmux drops from Tier 2 to Tier 3 and a custom status line replaces the plugin in a follow-up plan. The current plan assumes override completeness; the AC only grep-asserts the override block, not runtime resolution.
2. **pygments PyPI availability.** Task 12 Step 1 explicitly probes. At plan-writing time (2026-04-17) the probe returns 404 (verified). If a future re-run returns 200, flip from Sub-task 12b to 12a and delete `pygments/dracula_pro.py` + `pygments/pyproject.toml` in a follow-up commit.
3. **opencode `bgDiffAdded` / `bgDiffRemoved`.** These two chrome hex values (`#2B3A2F`, `#3D2A2E`) are not palette facts; they are low-saturation derivations. Kept as-is; the AC does not assert them. If licence review requires removal, regenerate from `DRACULA_PRO_GREEN` / `DRACULA_PRO_RED` via 15% alpha-over-Background (values available in the palette file).
