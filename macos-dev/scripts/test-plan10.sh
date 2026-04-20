#!/usr/bin/env bash
# test-plan10.sh — smoke tests for Plan 10 (neovim configuration)
#
# Validates the aggressive LazyVim Extras adoption target state:
#   - lazyvim.json declares 13 Extras (the canonical manifest)
#   - lazy-lock.json is tracked and valid JSON
#   - lazy.lua has NO extras imports (lazyvim.json owns them)
#   - Old monolithic plugin files deleted (formatting/linting/integrations/lsp)
#   - Per-language plugin files: go, python, bash, ghactions, yaml
#   - Misc plugins: tmux-nav, direnv, opencode, octo, learning (unchanged)
#   - config/ trimmed: options (2 non-defaults), keymaps (jj/jk), autocmds (gh-actions only)
#   - Install script link() calls preserved (regression)
#
# Usage: bash scripts/test-plan10.sh
# Exit: 0 if all tests pass, 1 if any fail

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass=0
fail=0

ok() {
  printf "  \033[0;32m✓\033[0m %s\n" "$1"
  pass=$((pass + 1))
}

nok() {
  printf "  \033[0;31m✗\033[0m %s\n" "$1"
  fail=$((fail + 1))
}

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "$desc"
  else
    nok "$desc"
  fi
}

echo "Plan 10: neovim configuration smoke tests"
echo ""

# ── File existence (target state) ────────────────────────────────────────
echo "File existence (target state):"
check "init.lua exists"            test -f "$REPO_ROOT/nvim/init.lua"
check "lazy.lua exists"            test -f "$REPO_ROOT/nvim/lua/config/lazy.lua"
check "lazyvim.json exists"        test -f "$REPO_ROOT/nvim/lazyvim.json"
check "lazy-lock.json exists"      test -f "$REPO_ROOT/nvim/lazy-lock.json"
check "options.lua exists"         test -f "$REPO_ROOT/nvim/lua/config/options.lua"
check "keymaps.lua exists"         test -f "$REPO_ROOT/nvim/lua/config/keymaps.lua"
check "autocmds.lua exists"        test -f "$REPO_ROOT/nvim/lua/config/autocmds.lua"
check "plugins/learning.lua exists" test -f "$REPO_ROOT/nvim/lua/plugins/learning.lua"
check "plugins/go.lua exists"      test -f "$REPO_ROOT/nvim/lua/plugins/go.lua"
check "plugins/python.lua exists"  test -f "$REPO_ROOT/nvim/lua/plugins/python.lua"
check "plugins/bash.lua exists"    test -f "$REPO_ROOT/nvim/lua/plugins/bash.lua"
check "plugins/ghactions.lua exists" test -f "$REPO_ROOT/nvim/lua/plugins/ghactions.lua"
check "plugins/yaml.lua exists"    test -f "$REPO_ROOT/nvim/lua/plugins/yaml.lua"
check "plugins/tmux-nav.lua exists" test -f "$REPO_ROOT/nvim/lua/plugins/tmux-nav.lua"
check "plugins/direnv.lua exists"  test -f "$REPO_ROOT/nvim/lua/plugins/direnv.lua"
check "plugins/opencode.lua exists" test -f "$REPO_ROOT/nvim/lua/plugins/opencode.lua"
check "plugins/octo.lua exists"    test -f "$REPO_ROOT/nvim/lua/plugins/octo.lua"

# ── AC-1: lazy-lock.json valid JSON + names lazy.nvim ────────────────────
echo ""
echo "AC-1: nvim/lazy-lock.json committed and valid"
if command -v python3 &>/dev/null; then
  if python3 -c "import json; d = json.load(open('$REPO_ROOT/nvim/lazy-lock.json')); assert 'lazy.nvim' in d" 2>/dev/null; then
    ok "lazy-lock.json parses as JSON and names lazy.nvim"
  else
    nok "lazy-lock.json parses as JSON and names lazy.nvim"
  fi
else
  nok "lazy-lock.json parses as JSON and names lazy.nvim (python3 not available)"
fi

# ── AC-2: lazyvim.json declares exactly 13 Extras ────────────────────────
echo ""
echo "AC-2: lazyvim.json declares 13 Extras"
if command -v python3 &>/dev/null; then
  extras_count=$(python3 -c "import json; d = json.load(open('$REPO_ROOT/nvim/lazyvim.json')); print(len(d.get('extras', [])))" 2>/dev/null)
  if [[ "$extras_count" == "13" ]]; then
    ok "lazyvim.json has exactly 13 extras ($extras_count)"
  else
    nok "lazyvim.json has exactly 13 extras (got: $extras_count)"
  fi
  for extra in 'coding.mini-surround' 'dap.core' 'editor.fzf' 'editor.harpoon2' \
               'lang.docker' 'lang.git' 'lang.go' 'lang.helm' 'lang.json' \
               'lang.markdown' 'lang.python' 'lang.terraform' 'lang.yaml'; do
    if python3 -c "import json; d = json.load(open('$REPO_ROOT/nvim/lazyvim.json')); assert any('$extra' in e for e in d['extras'])" 2>/dev/null; then
      ok "lazyvim.json includes $extra"
    else
      nok "lazyvim.json includes $extra"
    fi
  done
else
  nok "lazyvim.json extras validation (python3 not available)"
fi

# ── AC-3: lazy.lua has no extras imports (lazyvim.json owns them) ────────
echo ""
echo "AC-3: lazy.lua has no extras imports"
if grep -qE 'lazyvim\.plugins\.extras\.' "$REPO_ROOT/nvim/lua/config/lazy.lua"; then
  nok "lazy.lua should NOT have lazyvim.plugins.extras imports (lazyvim.json owns them)"
else
  ok "lazy.lua has no lazyvim.plugins.extras imports (lazyvim.json owns them)"
fi
check "lazy.lua still imports lazyvim.plugins" \
  grep -q 'lazyvim.plugins' "$REPO_ROOT/nvim/lua/config/lazy.lua"
check "lazy.lua still imports plugins dir" \
  grep -q '"plugins"' "$REPO_ROOT/nvim/lua/config/lazy.lua"

# ── AC-4: Old monolithic plugin files deleted ────────────────────────────
echo ""
echo "AC-4: Old plugin files deleted"
for gone in formatting.lua linting.lua integrations.lua lsp.lua; do
  if [[ -f "$REPO_ROOT/nvim/lua/plugins/$gone" ]]; then
    nok "plugins/$gone should be DELETED"
  else
    ok "plugins/$gone deleted"
  fi
done

# ── AC-5: plugins/go.lua gopls settings ─────────────────────────────────
echo ""
echo "AC-5: plugins/go.lua merged gopls settings"
if [[ -f "$REPO_ROOT/nvim/lua/plugins/go.lua" ]]; then
  for needle in 'unusedparams.*true' 'shadow.*true' 'staticcheck.*true' \
                'gofumpt.*true' 'usePlaceholders.*true' 'completeUnimported.*true' \
                'parameterNames.*true' 'assignVariableTypes.*true'; do
    check "go.lua gopls has $needle" \
      grep -qE "$needle" "$REPO_ROOT/nvim/lua/plugins/go.lua"
  done
fi

# ── AC-6: plugins/python.lua ty + ruff overrides ────────────────────────
echo ""
echo "AC-6: plugins/python.lua preserves ty + ruff"
if [[ -f "$REPO_ROOT/nvim/lua/plugins/python.lua" ]]; then
  check "python.lua sets lazyvim_python_lsp = ty" \
    grep -qE 'lazyvim_python_lsp.*"ty"' "$REPO_ROOT/nvim/lua/plugins/python.lua"
  check "python.lua sets lazyvim_python_formatter = ruff" \
    grep -qE 'lazyvim_python_formatter.*"ruff"' "$REPO_ROOT/nvim/lua/plugins/python.lua"
  check "python.lua ty has autostart = true" \
    grep -qE 'autostart.*true' "$REPO_ROOT/nvim/lua/plugins/python.lua"
  check "python.lua ruff has fixAll" \
    grep -q 'fixAll' "$REPO_ROOT/nvim/lua/plugins/python.lua"
  check "python.lua ruff has organizeImports" \
    grep -q 'organizeImports' "$REPO_ROOT/nvim/lua/plugins/python.lua"
fi

# ── AC-7: plugins/bash.lua bashls + shfmt + shellcheck ──────────────────
echo ""
echo "AC-7: plugins/bash.lua preserves bash tooling"
if [[ -f "$REPO_ROOT/nvim/lua/plugins/bash.lua" ]]; then
  check "bash.lua has bashls" \
    grep -q 'bashls' "$REPO_ROOT/nvim/lua/plugins/bash.lua"
  check "bash.lua has shellcheckPath" \
    grep -q 'shellcheckPath' "$REPO_ROOT/nvim/lua/plugins/bash.lua"
  check "bash.lua has shfmt prepend_args" \
    grep -q 'prepend_args' "$REPO_ROOT/nvim/lua/plugins/bash.lua"
  check "bash.lua has shfmt -i 2" \
    grep -q '"-i"' "$REPO_ROOT/nvim/lua/plugins/bash.lua"
  check "bash.lua has shellcheck linter" \
    grep -q 'shellcheck' "$REPO_ROOT/nvim/lua/plugins/bash.lua"
  check "bash.lua conform for sh" \
    grep -q 'sh.*shfmt' "$REPO_ROOT/nvim/lua/plugins/bash.lua"
  check "bash.lua nvim-lint for sh" \
    grep -q 'sh.*shellcheck' "$REPO_ROOT/nvim/lua/plugins/bash.lua"
fi

# ── AC-8: plugins/ghactions.lua gh_actions_ls + linters ──────────────────
echo ""
echo "AC-8: plugins/ghactions.lua preserves GH Actions tooling"
if [[ -f "$REPO_ROOT/nvim/lua/plugins/ghactions.lua" ]]; then
  check "ghactions.lua has gh_actions_ls" \
    grep -q 'gh_actions_ls' "$REPO_ROOT/nvim/lua/plugins/ghactions.lua"
  check "ghactions.lua has yaml.github filetype" \
    grep -q 'yaml.github' "$REPO_ROOT/nvim/lua/plugins/ghactions.lua"
  check "ghactions.lua has actionlint" \
    grep -q 'actionlint' "$REPO_ROOT/nvim/lua/plugins/ghactions.lua"
  check "ghactions.lua has zizmor" \
    grep -q 'zizmor' "$REPO_ROOT/nvim/lua/plugins/ghactions.lua"
fi

# ── AC-9: plugins/yaml.lua is conform-only (no LSP override) ────────────
echo ""
echo "AC-9: plugins/yaml.lua is yamlfmt conform override only"
if [[ -f "$REPO_ROOT/nvim/lua/plugins/yaml.lua" ]]; then
  check "yaml.lua has yamlfmt" \
    grep -q 'yamlfmt' "$REPO_ROOT/nvim/lua/plugins/yaml.lua"
  check "yaml.lua has conform.nvim" \
    grep -q 'conform.nvim' "$REPO_ROOT/nvim/lua/plugins/yaml.lua"
  if grep -q 'nvim-lspconfig' "$REPO_ROOT/nvim/lua/plugins/yaml.lua"; then
    nok "yaml.lua should NOT have nvim-lspconfig override (lang.yaml Extra defaults accepted)"
  else
    ok "yaml.lua has no nvim-lspconfig override (lang.yaml Extra defaults accepted)"
  fi
fi

# ── AC-10: plugins/json.lua does NOT exist ───────────────────────────────
echo ""
echo "AC-10: no plugins/json.lua (lang.json Extra defaults accepted)"
if [[ -f "$REPO_ROOT/nvim/lua/plugins/json.lua" ]]; then
  nok "plugins/json.lua should NOT exist (lang.json Extra defaults accepted)"
else
  ok "plugins/json.lua does not exist (lang.json Extra defaults accepted)"
fi

# ── AC-11: plugins/learning.lua unchanged ────────────────────────────────
echo ""
echo "AC-11: plugins/learning.lua unchanged"
check "hardtime.nvim present" \
  grep -q 'm4xshen/hardtime.nvim' "$REPO_ROOT/nvim/lua/plugins/learning.lua"
check "precognition.nvim present" \
  grep -q 'tris203/precognition.nvim' "$REPO_ROOT/nvim/lua/plugins/learning.lua"
check "vim-be-good present" \
  grep -q 'ThePrimeagen/vim-be-good' "$REPO_ROOT/nvim/lua/plugins/learning.lua"

# ── AC-12: plugins/tmux-nav.lua + direnv.lua exist ──────────────────────
echo ""
echo "AC-12: tmux-nav + direnv plugins exist"
check "tmux-nav.lua has vim-tmux-navigator" \
  grep -q 'vim-tmux-navigator' "$REPO_ROOT/nvim/lua/plugins/tmux-nav.lua"
check "tmux-nav.lua has C-h keymap" \
  grep -q 'C-h' "$REPO_ROOT/nvim/lua/plugins/tmux-nav.lua"
check "direnv.lua has direnv.vim" \
  grep -q 'direnv.vim' "$REPO_ROOT/nvim/lua/plugins/direnv.lua"

# ── AC-13: plugins/opencode.lua adopted ──────────────────────────────────
echo ""
echo "AC-13: plugins/opencode.lua adopted"
check "opencode.lua has opencode.nvim" \
  grep -q 'opencode.nvim' "$REPO_ROOT/nvim/lua/plugins/opencode.lua"

# ── AC-13b: plugins/octo.lua adopted ────────────────────────────────────
echo ""
echo "AC-13b: plugins/octo.lua adopted"
check "octo.lua has octo.nvim" \
  grep -q 'octo.nvim' "$REPO_ROOT/nvim/lua/plugins/octo.lua"

# ── AC-14: config/options.lua trimmed ────────────────────────────────────
echo ""
echo "AC-14: config/options.lua trimmed to non-defaults"
check "colorcolumn = 120" \
  grep -qE 'colorcolumn.*120' "$REPO_ROOT/nvim/lua/config/options.lua"
check "scrolloff = 8" \
  grep -q 'scrolloff.*8' "$REPO_ROOT/nvim/lua/config/options.lua"
# Must NOT have LazyVim-default-duplicated settings
for default_setting in 'tabstop' 'shiftwidth' 'expandtab' 'smartindent' \
                       'relativenumber' 'number' 'cursorline' 'ignorecase' \
                       'smartcase' 'undofile' 'undolevels' 'confirm' \
                       'splitbelow' 'splitright' 'updatetime' 'listchars' \
                       'clipboard' 'wrap'; do
  if grep -qE "^[^-]*opt\.$default_setting" "$REPO_ROOT/nvim/lua/config/options.lua"; then
    nok "options.lua should NOT set $default_setting (LazyVim default)"
  else
    ok "options.lua does not redundantly set $default_setting"
  fi
done

# ── AC-15: config/keymaps.lua has jj/jk → Esc ───────────────────────────
echo ""
echo "AC-15: config/keymaps.lua has jj/jk escape bindings"
check "jj → Esc" grep -q '"jj".*Esc' "$REPO_ROOT/nvim/lua/config/keymaps.lua"
check "jk → Esc" grep -q '"jk".*Esc' "$REPO_ROOT/nvim/lua/config/keymaps.lua"

# ── AC-16: config/autocmds.lua has gh-actions filetype only ──────────────
echo ""
echo "AC-16: config/options.lua has gh-actions filetype detection"
# vim.filetype.add + vim.treesitter.language.register were relocated from
# autocmds.lua (loaded on VeryLazy — too late for cmdline-opened buffers)
# to options.lua (loaded at init).
check "yaml.github filetype" \
  grep -q 'yaml.github' "$REPO_ROOT/nvim/lua/config/options.lua"
check "treesitter yaml register" \
  grep -q 'treesitter.language.register' "$REPO_ROOT/nvim/lua/config/options.lua"
check "github workflows pattern" \
  grep -q 'github/workflows' "$REPO_ROOT/nvim/lua/config/options.lua"
# Must NOT have LazyVim-covered autocmds
if grep -q 'VimResized' "$REPO_ROOT/nvim/lua/config/autocmds.lua"; then
  nok "autocmds.lua should NOT have VimResized (LazyVim covers this)"
else
  ok "autocmds.lua does not have VimResized (LazyVim covers)"
fi
if grep -q 'strip_whitespace' "$REPO_ROOT/nvim/lua/config/autocmds.lua"; then
  nok "autocmds.lua should NOT have strip_whitespace (conform covers this)"
else
  ok "autocmds.lua does not have strip_whitespace (conform covers)"
fi

# ── Install script link() calls ──────────────────────────────────────────
echo ""
echo "Install scripts:"
check "macos: nvim mapping"        grep -q 'link nvim.*\.config/nvim' "$REPO_ROOT/install-macos.sh"
check "wsl: nvim mapping"          grep -q 'link nvim.*\.config/nvim' "$REPO_ROOT/install-wsl.sh"

# Regression: prior plans' link() calls preserved
check "macos: bash links preserved"      test "$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: git links preserved"       test "$(grep -c 'link git/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "macos: kitty link preserved (kitty.conf only — dracula-pro.conf removed by theming Wave A)"  test "$(grep -c 'link kitty/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: tmux links preserved"      test "$(grep -c 'link tmux/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: starship links preserved"  test "$(grep -c 'link starship/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: lazygit links preserved"   test "$(grep -c 'link lazygit/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: mise links preserved"      test "$(grep -c 'link mise/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: opencode links preserved"  test "$(grep -c 'link opencode/' "$REPO_ROOT/install-macos.sh")" -eq 5
check "wsl: bash links preserved"        test "$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: git links preserved"         test "$(grep -c 'link git/' "$REPO_ROOT/install-wsl.sh")" -eq 2
check "wsl: kitty link preserved (kitty.conf only — dracula-pro.conf removed by theming Wave A)"    test "$(grep -c 'link kitty/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: tmux links preserved"        test "$(grep -c 'link tmux/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: starship links preserved"    test "$(grep -c 'link starship/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: lazygit links preserved"     test "$(grep -c 'link lazygit/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: mise links preserved"        test "$(grep -c 'link mise/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: opencode links preserved"    test "$(grep -c 'link opencode/' "$REPO_ROOT/install-wsl.sh")" -eq 5

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Floor check: at full target state ~115 tests run. During migration,
# per-language plugin files don't exist yet so those AC blocks are skipped.
# Floor is set conservatively to catch accidental test deletion.
if (( total < 90 )); then
  echo "WARNING: only $total tests ran (expected >= 90). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
