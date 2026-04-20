# shellcheck shell=bash
# scripts/lib/tier2-retint-expected.sh
#
# Expected Pro re-tint values for Tier 2 derived colours, keyed by
# "<tool>:<slot>". Values are the committed output of
# scripts/lib/retint.sh, per docs/design/theming-qa.md § 6.3 / § 7.2
# ("generated output of retint.sh, committed for determinism").
#
# Seed scope: OpenCode is the first Tier 2 tool subject to
# AC-theme-tier2-retint (spec § 6.4). Other Tier 2 tools are added as
# they are brought under the AC.
#
# Regenerate a value with:
#   bash scripts/lib/retint.sh '<C_hex>' '#282A36' '#22212C'

# shellcheck disable=SC2034  # sourced by test-plan-theming.sh via ${!TIER2_RETINT_EXPECTED[@]}
declare -gA TIER2_RETINT_EXPECTED=(
  # opencode/themes/dracula-pro.json
  # C=#2B3A2F, B_c=#282A36, B_p=#22212C — spec § 6.3 worked example.
  [opencode:bgDiffAdded]="#253125"
  # C=#3D2A2E, B_c=#282A36, B_p=#22212C — computed via retint.sh.
  [opencode:bgDiffRemoved]="#372124"
)
