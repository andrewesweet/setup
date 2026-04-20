# Tier 2 Retint Audit — Derivative Colour Survey

**Date**: 2026-04-20
**Spec**: `theming-qa.md` § 6 (AC-theme-tier2-retint)
**Scope**: eleven Tier 2 tools remaining after OpenCode (seeded in PR #32).

## Method

Every hex (`#RRGGBB`) or 24-bit SGR triple (`[34]8;2;R;G;B`) in each
committed file was extracted, canonicalised to lowercase `#RRGGBB`,
and classified against the Pro Base palette
(`scripts/lib/dracula-pro-palette.sh`) and the Classic blocklist
(`scripts/lib/classic-blocklist.sh`, § 4.2). A hex in neither set is
a derivative requiring § 6.3 re-tint analysis.

## Results

| Tool       | File(s) inspected                                    | Hex | Pro | Classic | Derivative |
|------------|------------------------------------------------------|-----|-----|---------|------------|
| tmux       | `macos-dev/tmux/.tmux.conf`                          | 11  | 11  | 0       | 0          |
| starship   | `macos-dev/starship/starship.toml`                   | 11  | 11  | 0       | 0          |
| lazygit    | `macos-dev/lazygit/config.yml`                       | 6   | 6   | 0       | 0          |
| gh-dash    | `macos-dev/gh-dash/config.yml`                       | 8   | 8   | 0       | 0          |
| yazi       | `macos-dev/yazi/theme.toml`                          | 11  | 11  | 0       | 0          |
| fzf        | `FZF_DEFAULT_OPTS` in `macos-dev/bash/.bashrc`       | 8   | 8   | 0       | 0          |
| ripgrep    | `macos-dev/ripgrep/config`                           | 3   | 3   | 0       | 0          |
| eza        | `EZA_COLORS` in `macos-dev/bash/.bashrc`             | 9   | 9   | 0       | 0          |
| dircolors  | `macos-dev/dircolors/.dir_colors`                    | 8   | 8   | 0       | 0          |
| man-pages  | `LESS_TERMCAP_*` in `macos-dev/bash/.bashrc`         | 5   | 5   | 0       | 0          |
| pygments   | `macos-dev/pygments/dracula_pro.py`                  | 11  | 11  | 0       | 0          |

## Conclusion

All eleven tools are straight Pro palette substitutions — no derived
tints, no extra slots, no leaks. `retint.sh` seeding is not required;
`TIER2_RETINT_EXPECTED` stays at the two OpenCode keys from PR #32 and
`check_tier2_retint`'s extractor switch needs no new cases. § 6's AC
exists because OpenCode leaked undetected; these eleven tools are
covered by AC-theme-no-classic-leak (§ 4) alone.
