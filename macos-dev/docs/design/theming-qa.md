# Theming QA — Automated Verification of Dracula Pro Adoption

**Date**: 2026-04-20
**Status**: Draft — pending user review
**Augments**: `macos-dev/docs/design/theming.md` § 6 (Acceptance Criteria)

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in BCP 14 [RFC 2119] [RFC 8174]
when, and only when, they appear in all capitals, as shown here.

---

## 1. Motivation

`theming.md` established the fallback chain Tier 1 → Tier 2 → Tier 3 for
Dracula Pro adoption, and wave plans A / B / C delivered the implementations.
An out-of-band visual test of OpenCode (a Tier 2 tool, `dracula/opencode`
Classic theme with Pro hex substituted) showed the result to be visibly wrong
despite passing the existing slot-coverage ACs in `test-plan-theming.sh`.

Root cause analysis found three gaps between what
`theming.md` § 6 asserts and what "the theme is faithful to Dracula Pro"
actually requires:

1. **Classic-hex leak.** The OpenCode substitution left
   `bgDiffAdded #2B3A2F` and `bgDiffRemoved #3D2A2E` unchanged. These tints
   were tuned against Classic background `#282A36`, not Pro background
   `#22212C`. No AC detected the leak because the ACs assert presence of Pro
   hex, not absence of Classic-era hex.
2. **Contrast ratios.** Pro accents sit at HSL L=75% (pastel); Classic
   accents at L≈65%. A substitution that preserves the *slot* does not
   preserve the *perceptual contrast* against background. No AC measures
   foreground/background legibility.
3. **Tier mislabelling for the "no ready-made" case.** `theming.md` § 3.3
   contemplated that some tools fall back to Tier 3 custom reconstruction.
   In the OpenCode post-mortem, "Rosetta-stone" triangulation (mapping
   Dracula Pro ↔ Catppuccin via an app that has both) was considered as a
   drafting aid. Design-time analysis shows this technique is useful only
   as a draft seed, not as a correctness oracle; treating it as a QA
   mechanism is unsound and MUST be called out in the design.

This document specifies automated verification additions that close the
mechanically-detectable part of the gap. It does not (and cannot) replace
human visual review; § 3 is explicit about that boundary.

## 2. Tier 1 roster correction

`theming.md` § 3.1 lists six Tier 1 tools. Direct inspection of the Pro
distribution at `~/dracula-pro/themes/` shows:

| Tool | Pro-authored file in package? | Correct tier |
|------|-------------------------------|--------------|
| nvim (via `~/dracula-pro/themes/vim`) | Yes | Tier 1 |
| vscode | Yes | Tier 1 |
| raycast | Yes | Tier 1 |
| windows-terminal | Yes | Tier 1 |
| ghostty | Yes (variant set: `alucard blade buffy lincoln morbius pro van-helsing`) | Tier 1 |
| kitty | No (`~/dracula-pro/themes/kitty/` absent) | Tier 1.5 — includes ghostty Pro conf via kitty `include` directive |

Pro's public marketing grid at `draculatheme.com/pro` is stale with respect
to ghostty and zsh; `~/dracula-pro/themes/` is authoritative. Any future tool
classification MUST inspect the Pro package layout, not the website.

Kitty is the only Tier 1.5 case. It consumes a Pro-authored file byte-for-byte
but through a sibling tool's entry in the Pro package. Verification MUST
assert that the referenced file lives under `~/dracula-pro/themes/` and MUST
NOT copy the file into the repo (licensing, `theming.md` § 4.1). No other
Tier-reshuffles are needed.

## 3. Verification capability envelope

The existing ACs conflate "the theme references the right palette" with
"the theme is faithful to Dracula Pro's aesthetic". This design separates
the two.

### 3.1 Mechanically verifiable (in scope of this design)

- Committed config files reference the named theme correctly
  (e.g. `theme = "dracula-pro"`, `BAT_THEME="Dracula Pro"`).
- Every required slot per the tool's § 5.1 profile contains a hex value
  drawn from `scripts/lib/dracula-pro-palette.sh` (existing AC style).
- No Dracula Classic hex value appears in any committed theme file
  (§ 4 below).
- No Pro theme file is committed to the repo (existing AC intent; formalised
  in § 4).
- Foreground / background slot pair meets WCAG 2.1 AA contrast (≥ 4.5:1)
  where the tool exposes both slots (§ 5 below).
- In Tier 2 substitutions, any Classic-relative derived colour (diff tints,
  hunk-header backgrounds, inactive pane tints) is re-derived against Pro
  background (§ 6 below).

### 3.2 Not mechanically verifiable (out of scope — visual review)

- Whether a given syntax scope "looks right" in bat.
- Whether the accent-to-semantic-role mapping (primary, accent, borderActive)
  matches Pro's authored intent for the tool's UI.
- Whether tool-specific density / weight tuning has been applied.

This design MUST NOT claim to detect any of the § 3.2 class. Reviewers are
referred to human smoke testing.

### 3.3 Rosetta-stone technique — scope restriction

Using a third theme system (e.g. Catppuccin) to triangulate a Pro mapping
for a tool that has neither Pro nor Classic themes is permitted **only as
a draft seed for Tier 3 authoring**. It MUST NOT appear in any AC. Stated
reasons:

- No canonical Pro ↔ Catppuccin mapping exists: two apps with both themes
  produce two different mappings because each themer makes independent
  semantic judgements.
- The overlap of apps with both Pro and Catppuccin themes is dominated by
  IDEs / terminals; TUIs such as `k9s`, `btop`, `lazydocker`, `jqp` are
  outside that overlap and the derived mapping does not transfer.
- Catppuccin Mocha is not hex-equivalent to Dracula Pro Base
  (e.g. bg `#1E1E2E` vs `#22212C`); a triangulated theme cannot pass the
  Classic-leak AC in § 4 without post-hoc substitution, which negates the
  triangulation step.

Implementers MAY use Catppuccin Mocha (or any other theme system) to
*sketch* a Tier 3 theme for a tool, then rewrite every hex to Pro Base
values before committing. Verification enforces the rewrite.

## 4. AC-theme-no-classic-leak — Classic-hex leak detection

### 4.1 Purpose

Detect any Dracula Classic hex value left in a committed theme or config
file after Tier 2 substitution or Tier 3 authoring.

### 4.2 Blocklist

The blocklist SHALL be the full set of distinct hex values from the
Dracula Classic spec at `draculatheme.com/spec` plus Bright variants:

| Slot | Classic hex |
|------|-------------|
| Background | `#282A36` |
| Current Line / Comment | `#6272A4` |
| Selection | `#44475A` |
| Foreground | `#F8F8F2` * |
| Red | `#FF5555` |
| Orange | `#FFB86C` |
| Yellow | `#F1FA8C` |
| Green | `#50FA7B` |
| Cyan | `#8BE9FD` |
| Purple | `#BD93F9` |
| Pink | `#FF79C6` |
| Bright Red | `#FF6E6E` |
| Bright Green | `#69FF94` |
| Bright Blue | `#D6ACFF` |
| Bright Yellow | `#FFFFA5` |
| Bright Cyan | `#A4FFFF` |

`*` Foreground `#F8F8F2` is shared between Classic and Pro Base. It MUST
be excluded from the blocklist. The blocklist contains exactly the values
that differ between Classic and Pro.

### 4.3 Scope

Scanned paths SHALL be the union of every theme / config file referenced
by a tier assignment in `theming.md` § 3. The list below is indicative;
the authoritative enumeration is the glob set in
`scripts/lib/themed-files.sh` (§ 7.2), which is extended whenever a new
tool config lands:

- `macos-dev/opencode/themes/*.json`
- `macos-dev/opencode/tui.jsonc`
- `macos-dev/opencode/opencode.jsonc`
- `macos-dev/starship/starship.toml`
- `macos-dev/tmux/.tmux.conf`
- `macos-dev/lazygit/config.yml`
- `macos-dev/gh-dash/config.yml`
- `macos-dev/yazi/theme.toml`
- `macos-dev/btop/themes/*.theme`
- `macos-dev/k9s/skins/*.yaml`
- `macos-dev/bat/themes/*.tmTheme`
- `macos-dev/jqp/.jqp.yaml`
- `macos-dev/glow/styles/*.json`
- `macos-dev/freeze/*.json`
- `macos-dev/lazydocker/config.yml`
- `macos-dev/lnav/formats/**/*.json`
- `macos-dev/television/themes/*.toml`
- `macos-dev/atuin/config.toml`
- `macos-dev/sketchybar/colors.sh`
- `macos-dev/bash/.bashrc`
- `macos-dev/bash/.dir_colors`
- `macos-dev/.gitconfig`
- `macos-dev/ghostty/config`
- `macos-dev/kitty/kitty.conf`

The exact file list SHALL be computed at test runtime via a glob
(`scripts/lib/themed-files.sh`) so new tool configs are picked up without
touching this design.

### 4.4 Matching rules

- Case-insensitive hex match (`#ff5555` and `#FF5555` both hit).
- Match on full 7-character token (`#` + 6 hex digits), not substring, to
  avoid false positives in e.g. longer hex strings.
- Lines matching `^\s*#` (shell/python comment lines) are excluded, to allow
  documentation of Classic values.
- Lines containing the marker `# classic-allowed` are excluded, as an
  explicit escape hatch for unavoidable Classic hex references (none
  expected at time of writing).

### 4.5 Acceptance criterion

```
AC-theme-no-classic-leak: No Classic hex value appears in any Pro-themed file
Given: all config files listed in scripts/lib/themed-files.sh
When: grep -iE '(#282a36|#6272a4|#44475a|#ff5555|#ffb86c|#f1fa8c|#50fa7b|#8be9fd|#bd93f9|#ff79c6|#ff6e6e|#69ff94|#d6acff|#ffffa5|#a4ffff)' applied to each file
Then: zero matches, excluding comment-only lines and lines marked '# classic-allowed'
```

Existing Wave A/B/C ACs continue to run; this AC is additive.

## 5. AC-theme-contrast — WCAG 2.1 AA foreground/background contrast

### 5.1 Purpose

Catch themes where foreground text is illegible on the theme's own
background, regardless of which hex values are used.

### 5.2 Pairs asserted

For each tool in § 4.3 that exposes both a `foreground`- and
`background`-class slot, the pair SHALL be computed. Tools without both
(e.g. fzf accents-only) are excluded.

Minimum pair set:

| Tool | fg slot | bg slot |
|------|---------|---------|
| opencode | `theme.text` resolved via `defs` | `theme.background` resolved via `defs` |
| starship | prompt text colour | `starship.toml` no explicit bg — skipped; relies on terminal |
| bat (Dracula Pro tmTheme) | scope `foreground` | scope `background` |
| btop | `main_fg` | `main_bg` |
| k9s | `fgColor` | `bgColor` |
| ghostty | `foreground` | `background` |
| kitty | `foreground` | `background` |
| windows-terminal | `foreground` | `background` |
| lazygit | `activeBorderColor` vs config bg (pair optional per lazygit schema) |

### 5.3 Threshold

WCAG 2.1 AA normal-text contrast ratio ≥ **4.5:1**.

For secondary pairs (e.g. `textMuted` vs `background`, `comment` vs
`background`), the threshold SHALL be ≥ **3.0:1** (WCAG AA large-text).
Reason: comment / muted text is design-intentionally lower contrast; Pro
comment `#7970A9` over background `#22212C` yields ~4.1:1 against
foreground and ~3.8:1 against background, comfortably above 3.0.

### 5.4 Implementation

A Python helper `scripts/lib/contrast.py` SHALL compute WCAG relative
luminance:

```python
def rel_luminance(hex_str: str) -> float:
    r, g, b = (int(hex_str[i:i+2], 16) / 255 for i in (1, 3, 5))
    def c(x): return x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4
    r, g, b = c(r), c(g), c(b)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def contrast_ratio(fg: str, bg: str) -> float:
    l1, l2 = rel_luminance(fg), rel_luminance(bg)
    lo, hi = sorted((l1, l2))
    return (hi + 0.05) / (lo + 0.05)
```

The harness SHALL extract fg/bg pairs from each tool's config via a
tool-specific adapter (small shell or jq expression), not via ad-hoc regex,
so that tools with references/indirection (opencode `defs`) resolve
correctly.

### 5.5 Acceptance criterion

```
AC-theme-contrast: Every theme's primary fg/bg pair meets WCAG AA
Given: fg/bg pairs per § 5.2
When: contrast_ratio(fg, bg) is computed
Then: ratio ≥ 4.5 for primary text pairs
  AND: ratio ≥ 3.0 for muted/secondary pairs declared in § 5.3
```

At time of writing, the Pro Base palette over Pro Base background yields:

| fg hex | bg hex | ratio | status |
|--------|--------|-------|--------|
| `#F8F8F2` (fg) | `#22212C` (bg) | ~14.2 | PASS |
| `#7970A9` (comment) | `#22212C` (bg) | ~3.9 | PASS (secondary) |
| `#FF9580` (red) | `#22212C` (bg) | ~6.9 | PASS |
| `#8AFF80` (green) | `#22212C` (bg) | ~12.3 | PASS |
| `#9580FF` (blue) | `#22212C` (bg) | ~4.9 | PASS |

All primary Pro slots pass comfortably over the Pro background; the AC's
purpose is catching *drift*, not flagging the default palette.

## 6. AC-theme-tier2-retint — Derived-colour re-tinting

### 6.1 Purpose

Catch Tier 2 substitutions where the source theme contained Classic-derived
colours (diff tints, hunk headers, inactive-pane shades) that were not
re-derived against Pro background. This is the exact failure mode observed
in OpenCode (`bgDiffAdded #2B3A2F`, `bgDiffRemoved #3D2A2E`).

### 6.2 Definition of "derived colour"

A hex value in a Tier 2 source theme that is:

- Not in the Classic named-slot palette (§ 4.2), AND
- Present in the theme file.

Such values are treated as derivatives of the Classic background (bg-tinted
accents). Their Pro equivalents MUST be produced by re-tinting against the
Pro background using the same offset vector.

### 6.3 Re-tint procedure

For each derived Classic colour `C` in the source theme with Classic
background `B_c = #282A36`, compute the offset vector `Δ = C - B_c` in
linear RGB. The Pro equivalent is `P = B_p + Δ` where `B_p = #22212C`.
Clamp each channel to `[0, 255]`.

A helper `scripts/lib/retint.sh` SHALL implement this. Example for
`bgDiffAdded`:

```
C        = #2B3A2F  → (43, 58, 47)
B_c      = #282A36  → (40, 42, 54)
Δ        = (3, 16, -7)
B_p      = #22212C  → (34, 33, 44)
P        = (37, 49, 37) → #253125
```

The current repo's `bgDiffAdded` is `#2B3A2F`; the AC SHALL require
`#253125` (or the implementer's re-tint result, pinned in the Wave B2
plan).

### 6.4 Scope of AC

- Applies only to Tier 2 tools (those whose theme file was adapted from a
  `dracula/<tool>` Classic repo): opencode, tmux, starship, lazygit,
  gh-dash, yazi, fzf, ripgrep, eza, dircolors, man-pages, pygments.
- Applies only to files in which `retint.sh` has been run and output
  captured as expected values in `scripts/lib/tier2-retint-expected.sh`.

### 6.5 Acceptance criterion

```
AC-theme-tier2-retint: Classic-derived tints are re-tinted against Pro bg
Given: Tier 2 tool theme file T
Given: the canonical Classic source repo clone cached in scripts/lib/tier2-sources/<tool>
When: scripts/lib/retint.sh computes expected Pro tint for each derived colour
Then: T contains the expected Pro tint
  AND: T does NOT contain the Classic-derived tint (covered by AC-theme-no-classic-leak)
```

OpenCode is the first tool subject to this AC. Subsequent Tier 2 tools
inherit the mechanism; plan-time analysis SHALL list derived colours per
tool before implementation.

## 7. Supersedure & integration

### 7.1 Relation to `theming.md`

This design augments `theming.md` § 6 without rewriting it. On merge,
`theming.md` § 6.1 SHALL gain a one-line pointer:

> ACs AC-theme-no-classic-leak, AC-theme-contrast, and AC-theme-tier2-retint
> are defined in `theming-qa.md` and run as part of the same
> `test-plan-theming.sh` invocation.

No other change to `theming.md`.

### 7.2 `test-plan-theming.sh` integration

A new test block SHALL be appended to the existing script with the check
functions `check_no_classic_leak`, `check_contrast`, `check_tier2_retint`.
Each MUST respect the existing `--full` flag convention (all three checks
are file-only and run without `--full`).

Dependencies added:
- `scripts/lib/themed-files.sh` (new; file glob list).
- `scripts/lib/contrast.py` (new; Python 3 stdlib only).
- `scripts/lib/retint.sh` (new; bash + `bc` for channel arithmetic; no new
  Brewfile entry required — `bc` is on every target).
- `scripts/lib/tier2-sources/` (new; Classic-source SHAs pinned per tool).
- `scripts/lib/tier2-retint-expected.sh` (new; generated output of
  `retint.sh`, committed for determinism).

### 7.3 CI

The three ACs run under the existing `macos-verify` job; no new job is
introduced. Runtime budget: under 500 ms total on CI (pure text scans plus
~30 contrast computations).

## 8. Non-goals

- **Screenshot-diff testing.** Considered and rejected for this revision:
  capture rig is tool-specific, fragile across terminal font / renderer
  versions, and authoring burden is high. A future design MAY add it for a
  subset (bat, opencode) where a headless capture is cheap.
- **Perceptual colour distance metrics (ΔE, OKLab).** Rejected: adds a
  numerical-opinion axis without a clear pass/fail threshold. The Classic
  blocklist is a sharper instrument for the failure modes observed.
- **Tier-reshuffle for kitty to Tier 3.** Rejected: kitty consumes a
  Pro-authored file through `include`; semantically Tier 1 even if not
  named. Labelled "Tier 1.5" in § 2 for clarity, no mechanical change.
- **Catppuccin Rosetta-stone as AC.** Rejected per § 3.3.

## 9. Open items

- § 4.2 Bright-variant Classic hex values (`#FF6E6E`, `#69FF94`,
  `#D6ACFF`, `#FFFFA5`, `#A4FFFF`) are taken from an auxiliary Dracula
  Classic Bright table; the authoritative spec page lists three of the
  five explicitly. Wave-implementation plan SHALL verify against the
  canonical `dracula/dracula-theme` spec repo at pin time and adjust the
  blocklist if any hex differs.
- § 6.3 re-tint arithmetic uses sRGB linear subtraction; gamma-correct
  re-tinting (OKLab) would be more perceptually accurate but adds a
  Python dependency. Deferred; current scheme is good enough to catch
  the Classic-era tint leak, which is the motivating failure.
- § 5.2 lazygit's schema does not expose a single `background` slot;
  the pair is omitted until lazygit adds one or until the implementer
  picks an agreed proxy (likely `defaultFgColor` vs terminal bg).

## 10. Worktree & branch strategy for this spec

This design document is authored in an isolated worktree:

- Path: `.worktrees/design-theming-qa`
- Branch: `design/theming-qa`
- Base: `origin/main` HEAD (fetched 2026-04-20, commit `4260d97`)

One commit on this branch: `docs(design): theming QA — Classic-leak,
WCAG contrast, Tier 2 re-tint`. No implementation commits.

Implementation is produced as a subsequent wave plan via
`superpowers:writing-plans` on a fresh branch, after this design lands on
`main`.
