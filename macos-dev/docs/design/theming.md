# Theming Design — Dracula Pro

**Date**: 2026-04-17
**Status**: Draft — pending user review
**Supersedes**: § 3.9 of `docs/plans/2026-04-12-shell-modernisation-design.md`

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in BCP 14 [RFC 2119] [RFC 8174]
when, and only when, they appear in all capitals, as shown here.

---

## 1. Principle & Fallback Chain

### 1.1 Principle

Dracula Pro (paid) is the canonical theme across every tool in this dotfiles
repository that has a theming surface. Font remains JetBrainsMono Nerd Font
with ligatures enabled (unchanged from prior design).

### 1.2 Fallback chain

When a Dracula Pro-authored theme is not available for a tool, we do not fall
back to unmodified Dracula Classic. Instead we fall back through a chain that
keeps the Pro palette throughout.

| Tier | Source | When used |
|------|--------|-----------|
| **1** | Dracula Pro ready-made theme from `~/dracula-pro/themes/<tool>/` | Tool has a Pro-authored theme |
| **2** | Pro-from-Classic: take the `dracula/<tool>` Classic theme and substitute Classic hex values for Dracula Pro Base hex values | No Pro theme; Classic ready-made exists |
| **3** | Custom theme reconstructed from the Dracula Pro Base palette | No ready-made theme of either flavour |
| **N/A** | — | Tool has no theming surface |

Unmodified Dracula Classic themes MUST NOT be used. The Classic spec at
`https://draculatheme.com/spec` MUST NOT be used as a reconstruction source.

### 1.3 Palette scope

The authoritative palette is **Dracula PRO Base / Terminal Standard**, verbatim
from `~/dracula-pro/design/palette.md` § "Color Palette - Terminal Standard /
Dracula PRO - Base". The committed palette file (see § 6.3) reproduces those
values as shell-exportable constants.

Included slots:

- ANSI 0-7 (Black, Red, Green, Yellow, Blue, Magenta, Cyan, White)
- ANSI 8-15 Bright variants
- 8 Dim variants (for muted / inactive states)
- Structural: Background, Foreground, Comment, Selection, Cursor
- Extra semantic accent: Orange

Excluded (deferred to a future design revision): Blade, Buffy, Lincoln,
Morbius, Van Helsing, Alucard variants. If adoption of a Pro variant is
requested, a design revision MUST add a companion palette file and a
`DRACULA_PRO_VARIANT` selector; the present design covers Base only.

### 1.4 Name convention

Terminal Standard names (Black / Red / Green / Yellow / Blue / Magenta / Cyan /
White) are authoritative. Alias names (Purple = Blue, Pink = Magenta) MAY be
used only where a tool's native theme vocabulary is non-terminal — for example
`sketchybar` semantic names for focus borders, or `starship` module styles
that conventionally reference "pink" for git branches. Where both are valid,
prefer Terminal Standard.

### 1.5 Licensing constraint

Dracula Pro themes are licensed and MUST NOT be redistributed via this
repository. Pro theme files live at `~/dracula-pro/` on every target machine
and are referenced by path, never copied into the repo. Palette hex values
(facts) are reproduced in the committed palette file; theme files (expressive
works) are not. See § 4 for install mechanics.

---

## 2. Scope & Tool Inventory

Every tool in `macos-dev/` (Brewfile, `tools.txt`, and repo config directories)
was surveyed for a theming surface. Tools with a surface are in scope and
retroactive to shipped configs — any tool currently themed against Classic
(Dracula or otherwise — e.g. Catppuccin, Monokai Extended) MUST be migrated to
the new chain.

### 2.1 Tools with theming surface (in scope)

| Category | Tools |
|----------|-------|
| Terminals / multiplexers / prompts | kitty, windows-terminal, ghostty, tmux, starship |
| Git / diff / review | git (ui.color), git-delta, difftastic, lazygit, gh-dash, diffnav |
| File / text viewing | bat, eza, glow, lnav, ripgrep, tree (LS_COLORS), dircolors |
| Search / navigation | fzf, television, atuin, yazi, sesh |
| Data wrangling | jq, jqp, yq, httpie, xh |
| Process / system | btop, k9s, lazydocker |
| Editors | nvim (+ LazyVim plugins), vscode |
| Recorders | freeze (chroma syntax theme) |
| Desktop (macOS) | sketchybar, jankyborders, aerospace (via borders), raycast |
| AI tooling | opencode (+ tui.jsonc theme) |
| Man pages | env-driven colour via `MANPAGER` / LESS termcap |
| Pygments | registered style (consumed by freeze, pandoc) |

### 2.2 Tools explicitly N/A (no theming surface)

git-cliff, cocogitto, gh, zoxide, fd, ghq, ghorg, miller, wget, pandoc, typst,
mise, uv, golangci-lint, gofumpt, goimports, shellcheck, shfmt,
markdownlint-cli2, tflint, actionlint, zizmor, pinact, kubectl, kubectx, tenv,
tf-summarize, asciinema, vhs, gcloud, cloud-sql-proxy, codeql, bun, direnv,
rip2, carapace, podman, hammerspoon, karabiner, skhd, prek, sesh (picker
inherits fzf — see § 5), aerospace (inherits borders — see § 5).

### 2.3 Container

`container/dev.sh` mounts the host's themed shell / editor configs. Tools
running inside the Wolfi container inherit theming from the host mount; the
container itself requires no separate theming spec.

---

## 3. Per-Tool Tier Assignment

### 3.1 Tier 1 — Dracula Pro ready-made

| Tool | Pro theme path | Repo dir |
|------|----------------|----------|
| kitty | `~/dracula-pro/themes/ghostty/` adapted via kitty-compatible include, or kitty-native conf if present at spec-implementation time | `kitty/` |
| windows-terminal | `~/dracula-pro/themes/windows-terminal/` | WSL fallback |
| nvim | `~/dracula-pro/themes/vim/` (lazy.nvim local `dir` plugin) | `nvim/` |
| vscode | `~/dracula-pro/themes/visual-studio-code/*.vsix` | `vscode/` |
| raycast | `~/dracula-pro/themes/raycast/` (manual import) | `raycast/` |
| ghostty | `~/dracula-pro/themes/ghostty/` | available if adopted |

### 3.2 Tier 2 — Pro-from-Classic (palette substitution)

| Tool | Classic source repo | Install form |
|------|---------------------|--------------|
| tmux | `dracula/tmux` | TPM plugin with `@dracula-*` colour overrides |
| starship | `dracula/starship` | `palette = "dracula-pro"` section in `starship.toml` |
| lazygit | `dracula/lazygit` | theme block in `config.yml` |
| gh-dash | `dracula/gh-dash` | theme section in gh-dash config |
| yazi | `dracula/yazi` | `theme.toml` with Pro hex |
| fzf | `dracula/fzf` | `FZF_DEFAULT_OPTS` color string |
| ripgrep | `dracula/ripgrep` | `--colors` config via `~/.config/ripgrep/config` |
| eza | `dracula/eza` | `EZA_COLORS` env var |
| dircolors | `dracula/dircolors` | `.dir_colors` sourced via `dircolors -b` in bashrc |
| opencode | `dracula/opencode` | theme config in `opencode.jsonc` |
| man-pages | `dracula/man-pages` | `MANPAGER` / LESS termcap env vars |
| pygments | `dracula/pygments` | install via `uv tool install pygments-dracula-pro` (rebuild if using swap approach) |

### 3.3 Tier 3 — Custom from Pro palette

| Tool | Surface |
|------|---------|
| git (ui.color) | `.gitconfig` `[color.branch/diff/status]` blocks |
| git-delta | `syntax-theme = "Dracula Pro"` (uses bat custom theme) |
| difftastic | `DFT_BACKGROUND`-respecting colour env |
| diffnav | inherits delta — no direct theme |
| bat | custom `Dracula Pro.tmTheme` in `~/.config/bat/themes/` + `BAT_THEME="Dracula Pro"` |
| lnav | theme file in `~/.lnav/formats/installed/` |
| btop | `~/.config/btop/themes/dracula-pro.theme` + `color_theme` in config |
| k9s | `~/.config/k9s/skins/dracula-pro.yaml` + `skin: dracula-pro` in config |
| jqp | custom theme block in `.jqp.yaml` with Pro hex |
| glow | `~/.config/glow/styles/dracula-pro.json` + `--style` alias |
| freeze | `--theme=dracula-pro.json` chroma style |
| lazydocker | `config.yml` colors section |
| httpie | `~/.httpie/config.json` `--style=dracula-pro` |
| xh | `XH_STYLE=dracula-pro` env |
| jq | `JQ_COLORS` env var |
| atuin | `style` block in `config.toml` with Pro hex |
| television | `~/.config/television/themes/dracula-pro.toml` + `theme = "dracula-pro"` |
| sketchybar | `sketchybar/colors.sh` — palette exports sourced by `sketchybarrc` and `bordersrc` |
| jankyborders | reads `$COLOR_PURPLE` / `$COLOR_SELECTION` via sketchybar colors.sh |
| aerospace | inherits borders; no direct theme |

### 3.4 N/A — tools without a theming surface

See § 2.2. hammerspoon, karabiner, skhd, prek, sesh (picker only, inherits fzf),
mise, vhs, asciinema, direnv, bun, and others listed in § 2.2 have no
colour-configurable surface and are excluded from per-tool tier assignment.

---

## 4. Licensing & Install Handling

### 4.1 Constraints

- Dracula Pro themes are licensed. Repository MUST contain zero Pro theme
  files or Pro-palette reconstructions that duplicate the Pro aesthetic.
- Palette hex values are facts, not expressive works, and MAY be reproduced
  in the committed palette file (§ 6.3).
- `~/dracula-pro/` is assumed present on every target machine, in the same
  layout as the design-time reference host.

### 4.2 Install mechanism per Tier 1 tool

| Tool | Mechanism | Rationale |
|------|-----------|-----------|
| kitty | `kitty.conf` contains `include ~/dracula-pro/themes/<file>.conf` | kitty supports the `include` directive; no install-time copy needed |
| windows-terminal | `install-wsl.sh` copies scheme JSON from `~/dracula-pro/themes/windows-terminal/` into Windows Terminal `settings.json` | no include directive; copy at install |
| vscode | `install-macos.sh` runs `code --install-extension <vsix-path>` against the Pro `.vsix` in `~/dracula-pro/themes/visual-studio-code/` | extension install is symlink-agnostic |
| raycast | Manual import at first run, documented in `install-macos.sh` Next Steps output | Raycast has no CLI install for themes |
| nvim | `lazy.nvim` plugin spec uses local `dir = "~/dracula-pro/themes/vim"` (dev-mode plugin) | lazy.nvim supports local directory plugins |
| ghostty | `config` contains `theme = ~/dracula-pro/themes/ghostty/<file>` | ghostty supports theme file references |

### 4.3 Handling of `~/dracula-pro` absence

The new fallback chain has no Tier "Classic ready-made" — Tier 1 cannot silently
fall back. Behaviour when `~/dracula-pro/` is missing:

- **Dev machines** (macOS / WSL2 primary targets): `install-macos.sh` and
  `install-wsl.sh` MUST fail loud with:
  `error: ~/dracula-pro/ not found. Install Dracula Pro from draculatheme.com/pro before running this script.`
- **CI machines** (no Pro installed): `install-*.sh` MUST honour a
  `SKIP_DRACULA_PRO=1` environment variable. When set, Tier 1 install steps
  emit a warning, are skipped, and install continues with Tier 2 / Tier 3
  tools only.
- **Verification script** `scripts/verify.sh` MUST detect `~/dracula-pro/`
  presence and skip Tier 1 assertions when absent, so that CI runs remain
  green without Pro content.

### 4.4 Existing palette-reconstruction files

`kitty/dracula-pro.conf` (palette reconstruction committed to the repo) MUST
be removed as part of the Wave A migration. The file was authored before Pro
ready-made adoption was agreed; with Tier 1 kitty now consuming
`~/dracula-pro/themes/<file>.conf` via `include`, the reconstruction is
redundant and risks licence drift.

### 4.5 `.gitignore`

Add `/dracula-pro/` at repo root as a safety rail against accidentally
committing symlinks, caches, or copies of Pro content into the tree. This
MUST land in the same PR as the first install-script change that references
`~/dracula-pro/`.

---

## 5. Migration State & Ordering

### 5.1 Palette-slot profiles

Every Tier 2 / Tier 3 theme authoring MUST choose a coverage profile and cover
every slot in that profile. ACs assert full profile coverage, not cherry-picked
slots.

| Profile | Slots required |
|---------|----------------|
| **Full ANSI + Dim** | 8 Base + 8 Bright + 8 Dim + Background / Foreground / Comment / Selection / Cursor |
| **Full ANSI** | 8 Base + 8 Bright + Background / Foreground / Comment / Selection / Cursor |
| **Structural + accents** | Background / Foreground / Comment / Selection + Red / Green / Yellow / Blue / Magenta / Cyan + Orange |
| **Accents only** | Red / Green / Yellow / Blue / Magenta / Cyan + Orange (no Background) |
| **Single semantic** | One or two named slots |

### 5.2 Tool → profile

| Tool | Profile | Tier | Notes |
|------|---------|------|-------|
| kitty, ghostty, windows-terminal | Full ANSI + Dim | 1 | Handled by Pro ready-made |
| nvim | Full ANSI + Dim | 1 | Handled by Pro vim plugin |
| vscode | Full ANSI + Dim | 1 | Handled by `.vsix` |
| tmux | Full ANSI | 2 | Status / tab / messages / copy-mode |
| bat `.tmTheme` | Full ANSI + Dim | 3 | Syntax scopes use Dim for secondary tokens |
| starship | Structural + accents | 2 | Module styles reference named colours |
| lazygit, gh-dash, yazi, opencode, btop, k9s, jqp, lazydocker, atuin, television, glow, lnav | Structural + accents | 2 / 3 | UI chrome + text |
| fzf, ripgrep, eza, dircolors, httpie, xh, jq, git ui.color, man-pages | Accents only | 2 / 3 | Rendered over terminal background |
| sketchybar | Structural + accents | 3 | Exports every slot as `COLOR_*` — single source of truth |
| jankyborders | Single semantic (focus = Blue/Purple, unfocus = Selection) | 3 | Reads sketchybar colors.sh |
| aerospace | Single semantic | — | Inherits borders |

### 5.3 Migration waves

Waves are ordered by risk and authoring cost. Each wave produces its own
implementation plan via `superpowers:writing-plans`; each tool within a wave
MAY be further decomposed into its own branch if cross-tool coupling is low.

#### Wave A — Tier 1 adoption

| Tool | Current state | Target state | Action |
|------|---------------|--------------|--------|
| kitty | `include dracula-pro.conf` (local reconstruction) | `include ~/dracula-pro/themes/<file>` | Remove `kitty/dracula-pro.conf`; update include path |
| nvim | LazyVim default colorscheme | Pro vim plugin via lazy.nvim local `dir` | Add plugin spec; set colorscheme |
| vscode | `catppuccin.catppuccin-vsc` in `extensions.json` | Pro `.vsix` installed via `code --install-extension` | Swap extension ID; update install script |
| windows-terminal | (no shipped theming) | Pro scheme JSON copied into Windows Terminal settings | New install-wsl.sh step |
| raycast | `extensions.md` only | Pro theme imported at first run | Document step in install-macos.sh Next Steps |
| ghostty | (not shipped) | Pro ghostty theme referenced | Add ghostty config if adopted; optional this wave |

#### Wave B — Tier 2 palette substitution

| Tool | Current state | Target state | Action |
|------|---------------|--------------|--------|
| starship | `palette = "dracula"` (Classic hex) | `palette = "dracula-pro"` (Pro Base hex) | Rename palette; replace hex values |
| tmux | `dracula/tmux` plugin, Classic colours | Same plugin; `@dracula-*` colour overrides to Pro hex | Add override vars in `.tmux.conf` |
| lazygit | `theme:` block with Classic or mixed hex | Pro hex | Replace hex values |
| gh-dash | `theme: dracula` | Custom theme section with Pro hex | Replace theme block |
| yazi | community Dracula `theme.toml` | Same structure, Pro hex | Replace hex |
| opencode | `theme = "dracula"` in `tui.jsonc` | `theme = "dracula-pro"` + custom theme block | Add Pro theme block |
| fzf | `FZF_DEFAULT_OPTS` (current hex to be verified at impl time) | Pro hex | Update env string in `bash/.bashrc` or equivalent |
| ripgrep | (check current) | `--colors` config with Pro hex | Ship `~/.config/ripgrep/config`; reference in env |
| eza | (check `EZA_COLORS`) | Pro hex | Update env |
| dircolors | (check) | `.dir_colors` with Pro hex | Ship file; `eval $(dircolors .dir_colors)` in bashrc |
| man-pages | (check `MANPAGER`, LESS termcap) | Pro hex | Update env in bashrc |
| pygments | (not currently registered) | `dracula-pro` style registered via uv-installed package | Install at Brewfile-adjacent step |

#### Wave C — Tier 3 custom reconstruction

| Tool | Current state | Target state | Action |
|------|---------------|--------------|--------|
| bat | `BAT_THEME="Dracula"` (Classic built-in) | Custom `Dracula Pro.tmTheme` in `~/.config/bat/themes/`; `BAT_THEME="Dracula Pro"`; `bat cache --build` at install | Author tmTheme; ship file; wire install step |
| delta | `syntax-theme = Dracula` | `syntax-theme = "Dracula Pro"` | Update `.gitconfig` |
| difftastic | default colours | Pro-palette colour env vars | Update env in bashrc |
| diffnav | pager = delta | Inherits delta/bat | No direct change |
| lnav | (not shipped) | Pro theme file | Author + install |
| btop | (not shipped) | `dracula-pro.theme` file; config refers | Author + install |
| k9s | (not shipped) | `dracula-pro.yaml` skin; config refers | Author + install |
| jqp | `theme: dracula` (built-in Classic) | Custom theme block with Pro hex | Replace block |
| glow | (not shipped) | `dracula-pro.json` style; alias wraps `--style=<path>` | Author + install |
| freeze | (not shipped) | `dracula-pro.json` chroma style; alias wraps `--theme=<path>` | Author + install |
| lazydocker | (not shipped) | `config.yml` colors block | Author + install |
| httpie | (not shipped) | `~/.httpie/config.json` with `--style` default | Author config |
| xh | (not shipped) | `XH_STYLE` env | Env var |
| jq | (not shipped) | `JQ_COLORS` env var | Env var |
| atuin | current `config.toml` (check at impl time) | `style` block + colours | Update / add block |
| television | current `config.toml` (check at impl time) | `themes/dracula-pro.toml`; `theme` key | Author + reference |
| sketchybar | `colors.sh` with Pro-palette intent | Hex values audited against `~/dracula-pro/design/palette.md`; any drift reconciled; slot coverage matches "Structural + accents" profile | Audit + align |
| jankyborders | reads `colors.sh` | Inherits | No direct change |
| aerospace | no direct theme | Inherits | No direct change |
| git (ui.color) | default | `[color.branch]` / `[color.diff]` / `[color.status]` blocks using Pro hex | Add blocks to `.gitconfig` |

#### Wave Z — Supersession and cleanup

- Replace the body of `docs/plans/2026-04-12-shell-modernisation-design.md`
  § 3.9 with a one-line supersession note pointing to this file (dated
  2026-04-17). Keep the section heading so plan-doc references continue to
  resolve.
- Delete `kitty/dracula-pro.conf` after kitty is pointed at
  `~/dracula-pro/themes/…` in Wave A.
- Add `/dracula-pro/` to repo `.gitignore` alongside the first install-script
  change in Wave A.
- Update `scripts/verify.sh` and any per-tool check scripts to assert
  Pro-palette hex values (see § 6 ACs).

### 5.4 Sequencing rationale

1. Wave A first — Tier 1 tools are highest fidelity and isolate cleanly per
   tool. No cross-tool palette dependency.
2. Wave B second — palette substitutions touch existing files; each tool's
   tests are independent, so tools can land one per PR if reviewer load
   warrants.
3. Wave C last — custom theme authoring is the largest authoring cost and
   depends on the palette file from § 6.3 being committed upstream.
4. Wave Z after all waves land — supersession is only accurate once
   `theming.md` has fully replaced § 3.9 content.

### 5.5 Coordination with in-flight branches

| Branch | Overlap | Mitigation |
|--------|---------|-----------|
| `feature/editor-lazyvim-extras` | Touches nvim config; may introduce a colorscheme not aligned with Tier 1 Pro vim | Land ahead of Wave A nvim migration; rebase implementation plan after merge |
| `feature/desktop-layer1-wm-core`, `-layer2-keyboard`, `-layer3-launcher` | Touches sketchybar, jankyborders, aerospace, raycast, skhd | If these land first, Wave C sketchybar audit picks up any palette drift; if they land after, rebase against new `sketchybar/colors.sh` |
| `update-ultralight-orchestration-models` | No theming intersection | — |

No branch is a blocker; coordination is via rebase at wave-plan write time.

---

## 6. Acceptance Criteria

### 6.1 AC template

Every tool in scope SHALL have one AC in `scripts/test-plan-theming.sh`
(created in Wave C or earliest wave touching it).

```
### AC-<tool>: <Tool> uses Dracula Pro (Tier <N>)
Given: <tool> is installed and configured from this repo
When: inspecting the committed config or runtime output
Then: <specific grep or runtime check>
```

ACs SHALL assert every slot in the tool's coverage profile (§ 5.1). Partial
coverage fails the AC.

### 6.2 Illustrative ACs

```
AC-kitty: kitty includes Dracula Pro theme from ~/dracula-pro
Then: grep -E '^include\s+~?/dracula-pro/themes/' kitty/kitty.conf
  AND: ! test -f kitty/dracula-pro.conf    # reconstruction removed

AC-starship: starship palette is dracula-pro with Pro Base hex
Then: grep -qE '^palette\s*=\s*"dracula-pro"' starship/starship.toml
  AND: grep -qE 'background\s*=\s*"#22212C"' starship/starship.toml
  AND: grep -qE 'blue\s*=\s*"#9580FF"' starship/starship.toml
  AND: grep -qE 'selection\s*=\s*"#454158"' starship/starship.toml
  AND: grep -qE 'comment\s*=\s*"#7970A9"' starship/starship.toml
  AND: grep -qE 'foreground\s*=\s*"#F8F8F2"' starship/starship.toml

AC-bat: BAT_THEME is "Dracula Pro" and custom theme file ships
Then: grep -qE 'export BAT_THEME="Dracula Pro"' bash/.bashrc
  AND: test -f bash/bat-themes/Dracula\ Pro.tmTheme
  AND: install-macos.sh references 'bat cache --build'

AC-sketchybar: colors.sh hex values match Dracula PRO Base palette
Then: diff between sketchybar/colors.sh and
      scripts/lib/dracula-pro-palette.sh is empty for shared slots
  AND: colors.sh exports at minimum COLOR_BG / COLOR_FG / COLOR_COMMENT /
       COLOR_SELECTION / COLOR_RED / COLOR_GREEN / COLOR_YELLOW /
       COLOR_BLUE / COLOR_MAGENTA / COLOR_CYAN / COLOR_ORANGE

AC-pro-absent-fallback: install script handles SKIP_DRACULA_PRO=1 gracefully
Given: ~/dracula-pro does not exist
When: SKIP_DRACULA_PRO=1 ./install-macos.sh runs
Then: exit code is 0
  AND: Tier 1 install steps emit "SKIPPED" to stdout
  AND: Tier 2 / Tier 3 install steps complete normally
```

### 6.3 Authoritative palette file

The file `scripts/lib/dracula-pro-palette.sh` SHALL ship as the single
source of truth for Pro hex values. Content derived verbatim from
`~/dracula-pro/design/palette.md` § "Color Palette - Terminal Standard /
Dracula PRO - Base":

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

Consumers:

- `sketchybar/colors.sh` sources this file and re-exports `COLOR_*` aliases
  for its own consumers (`sketchybarrc`, `bordersrc`, plugin scripts).
- Theme-authoring tooling for Waves B and C imports this file and interpolates
  the named variables into config templates.
- `scripts/test-plan-theming.sh` sources this file and asserts that committed
  config files contain exactly the expected hex values.

### 6.4 Aggregate test

`scripts/test-plan-theming.sh` SHALL run every AC and exit non-zero on any
failure. It MUST be added to the existing four-job CI (lint, macos-verify,
macos-install, wsl-install) as part of `macos-verify` or a new `theming-verify`
job, at the implementer's discretion in the Wave writing-plans output.

---

## 7. Worktree & Branch Strategy for This Spec

### 7.1 Worktree

This design document itself is authored in an isolated worktree cut from
`origin/main`:

- Path: `/home/sweeand/andrewesweet/setup/.worktrees/design-theming`
- Branch: `design/dracula-pro-theming`
- Base: `origin/main` HEAD (fetched 2026-04-17, commit `2c45b3e`)

### 7.2 Commits on this branch

Two commits, in order:

1. `docs(design): add Dracula Pro theming spec` — creates this file at
   `macos-dev/docs/design/theming.md`.
2. `docs(design): mark § 3.9 superseded` — replaces the body of § 3.9 in
   `macos-dev/docs/plans/2026-04-12-shell-modernisation-design.md` with a
   one-line pointer to this file.

No implementation commits on this branch. No palette file commit. No
install-script edits. All implementation work is deferred to later branches
produced by `superpowers:writing-plans`.

### 7.3 Pull request and merge

- Title: `docs(design): Dracula Pro theming (§ 3.9 supersedure)`
- Single reviewer pass.
- Rebase against `origin/main` immediately before merge to absorb any
  in-flight PRs.
- Squash-merge to keep main history linear (matches existing repo merge
  pattern).

### 7.4 Post-merge

After this design lands on `main`, each wave in § 5.3 is produced as its own
implementation plan via `superpowers:writing-plans`, on a fresh
`feature/theming-wave-<a|b|c|z>` branch cut from then-current `origin/main`.
Each wave plan may itself sub-divide by tool if reviewer load warrants.

---

## 8. Open items

- § 3.1 kitty theme-file name: the exact file under `~/dracula-pro/themes/`
  that is kitty-compatible is verified at Wave A implementation time. Options
  seen during design research: the ghostty `.conf` format is close enough for
  manual adaptation; kitty-native `.conf` may be shipped by Pro at the time of
  implementation. Whichever is used is pinned in the kitty Wave A plan, not
  in this design.
- § 3.2 tmux: whether the Pro-palette override survives `dracula/tmux` plugin
  updates (the plugin MAY hardcode some colours beyond what `@dracula-*` vars
  cover) is validated at Wave B implementation time. If the plugin cannot be
  fully overridden, tmux drops from Tier 2 to Tier 3 (custom status line).
- § 3.3 pygments: whether a pre-packaged `dracula-pro` pygments style exists
  on PyPI at implementation time, versus requiring a local swap build, is
  validated in Wave B.

Each open item is a scoped risk; none blocks approval of this design.
