#!/usr/bin/env bash
# test-plan10.sh — smoke tests for Plan 10 (neovim configuration)
#
# Validates:
#   - All 8 nvim config files exist
#   - init.lua bootstraps LazyVim
#   - options.lua has required settings
#   - autocmds.lua has yaml.github detection
#   - lsp.lua: vim.g before return, no require('lspconfig'), ty not in Mason
#   - formatting.lua: format_on_save, no markdownlint in conform
#   - linting.lua: zizmor, no InsertLeave
#   - integrations.lua: all plugins present, key mappings correct
#   - Install scripts have correct link() mapping
#   - Plans 2–9 link() calls preserved (regression)
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

# ── File existence ─────────────────────────────────────────────────────────
echo "File existence:"
check "init.lua exists"            test -f "$REPO_ROOT/nvim/init.lua"
check "lazy.lua exists"            test -f "$REPO_ROOT/nvim/lua/config/lazy.lua"
check "options.lua exists"         test -f "$REPO_ROOT/nvim/lua/config/options.lua"
check "keymaps.lua exists"         test -f "$REPO_ROOT/nvim/lua/config/keymaps.lua"
check "autocmds.lua exists"        test -f "$REPO_ROOT/nvim/lua/config/autocmds.lua"
check "lsp.lua exists"            test -f "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "formatting.lua exists"      test -f "$REPO_ROOT/nvim/lua/plugins/formatting.lua"
check "linting.lua exists"        test -f "$REPO_ROOT/nvim/lua/plugins/linting.lua"
check "integrations.lua exists"    test -f "$REPO_ROOT/nvim/lua/plugins/integrations.lua"

# ── init.lua ──────────────────────────────────────────────────────────────
echo ""
echo "init.lua:"
check "bootstraps LazyVim"         grep -q 'config.lazy' "$REPO_ROOT/nvim/init.lua"

# ── lazy.lua ──────────────────────────────────────────────────────────────
# Bootstrap file from LazyVim/starter — without it, init.lua's
# require('config.lazy') fails on startup with E5113 module not found.
echo ""
echo "lazy.lua:"
check "clones lazy.nvim"           grep -q 'lazy.nvim.git' "$REPO_ROOT/nvim/lua/config/lazy.lua"
check "prepends lazypath to rtp"   grep -q "vim.opt.rtp:prepend(lazypath)" "$REPO_ROOT/nvim/lua/config/lazy.lua"
check "imports lazyvim.plugins"    grep -q 'lazyvim.plugins' "$REPO_ROOT/nvim/lua/config/lazy.lua"
check "imports plugins dir"        grep -q '"plugins"' "$REPO_ROOT/nvim/lua/config/lazy.lua"

# ── options.lua ───────────────────────────────────────────────────────────
echo ""
echo "options.lua:"
check "tabstop = 2"                grep -q 'tabstop.*2' "$REPO_ROOT/nvim/lua/config/options.lua"
check "shiftwidth = 2"            grep -q 'shiftwidth.*2' "$REPO_ROOT/nvim/lua/config/options.lua"
check "expandtab = true"           grep -q 'expandtab.*true' "$REPO_ROOT/nvim/lua/config/options.lua"
check "relativenumber = true"      grep -q 'relativenumber.*true' "$REPO_ROOT/nvim/lua/config/options.lua"
check "colorcolumn = 100"          grep -q 'colorcolumn.*100' "$REPO_ROOT/nvim/lua/config/options.lua"
check "clipboard = unnamedplus"    grep -q 'clipboard.*unnamedplus' "$REPO_ROOT/nvim/lua/config/options.lua"
check "scrolloff = 8"             grep -q 'scrolloff.*8' "$REPO_ROOT/nvim/lua/config/options.lua"
check "updatetime = 200"           grep -q 'updatetime.*200' "$REPO_ROOT/nvim/lua/config/options.lua"
check "undofile = true"            grep -q 'undofile.*true' "$REPO_ROOT/nvim/lua/config/options.lua"
check "listchars with trail"       grep -q 'trail' "$REPO_ROOT/nvim/lua/config/options.lua"
check "smartindent = true"         grep -q 'smartindent.*true' "$REPO_ROOT/nvim/lua/config/options.lua"
check "number = true"              grep -q 'number.*true' "$REPO_ROOT/nvim/lua/config/options.lua"
check "wrap = false"               grep -q 'wrap.*false' "$REPO_ROOT/nvim/lua/config/options.lua"
check "undolevels = 10000"         grep -q 'undolevels.*10000' "$REPO_ROOT/nvim/lua/config/options.lua"
check "splitbelow = true"          grep -q 'splitbelow.*true' "$REPO_ROOT/nvim/lua/config/options.lua"
check "splitright = true"          grep -q 'splitright.*true' "$REPO_ROOT/nvim/lua/config/options.lua"

# ── autocmds.lua ──────────────────────────────────────────────────────────
echo ""
echo "autocmds.lua:"
check "yaml.github filetype"       grep -q 'yaml.github' "$REPO_ROOT/nvim/lua/config/autocmds.lua"
check "treesitter yaml register"   grep -q 'treesitter.language.register' "$REPO_ROOT/nvim/lua/config/autocmds.lua"
check "VimResized autocmd"         grep -q 'VimResized' "$REPO_ROOT/nvim/lua/config/autocmds.lua"
check "strip whitespace on save"   grep -q 'strip_whitespace' "$REPO_ROOT/nvim/lua/config/autocmds.lua"
check "github workflows pattern"   grep -q 'github/workflows' "$REPO_ROOT/nvim/lua/config/autocmds.lua"
check "github actions pattern"     grep -q 'github/actions' "$REPO_ROOT/nvim/lua/config/autocmds.lua"

# ── lsp.lua — critical requirements ──────────────────────────────────────
echo ""
echo "lsp.lua — critical requirements:"
check "lazyvim_python_lsp = ty"    grep -q 'lazyvim_python_lsp.*ty' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "lazyvim_python_formatter"   grep -q 'lazyvim_python_formatter.*ruff' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"

# vim.g assignments MUST be before return
vimg_line=$(grep -n 'lazyvim_python_lsp' "$REPO_ROOT/nvim/lua/plugins/lsp.lua" | head -1 | cut -d: -f1)
return_line=$(grep -n '^return' "$REPO_ROOT/nvim/lua/plugins/lsp.lua" | head -1 | cut -d: -f1)
if [[ -n "$vimg_line" && -n "$return_line" ]] && (( vimg_line < return_line )); then
  ok "vim.g assignments before return"
else
  nok "vim.g assignments before return"
fi

# MUST NOT use require('lspconfig')
if grep -q "require.*lspconfig" "$REPO_ROOT/nvim/lua/plugins/lsp.lua"; then
  nok "no require('lspconfig') call"
else
  ok "no require('lspconfig') call"
fi

# ty MUST NOT be in Mason's ensure_installed
if grep -A 20 'ensure_installed' "$REPO_ROOT/nvim/lua/plugins/lsp.lua" | grep -q '"ty"'; then
  nok "ty not in Mason ensure_installed"
else
  ok "ty not in Mason ensure_installed"
fi

# ── lsp.lua — servers ────────────────────────────────────────────────────
echo ""
echo "lsp.lua — servers:"
check "basedpyright disabled"      grep -q 'basedpyright.*false' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "pyright disabled"           grep -q 'pyright.*false' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "pylsp disabled"             grep -q 'pylsp.*false' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "ty enabled"                 grep -q 'ty.*enabled.*true' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "ruff enabled"               grep -q 'ruff.*enabled.*true' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "gopls configured"           grep -q 'gopls' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "bashls configured"          grep -q 'bashls' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "terraformls configured"     grep -q 'terraformls' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "yamlls configured"          grep -q 'yamlls' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "gh_actions_ls configured"   grep -q 'gh_actions_ls' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "jsonls configured"          grep -q 'jsonls' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "schemastore.nvim"           grep -q 'schemastore.nvim' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"
check "gh_actions_ls yaml.github"  grep -q 'gh_actions_ls.*yaml\.github' "$REPO_ROOT/nvim/lua/plugins/lsp.lua"

# ── formatting.lua ────────────────────────────────────────────────────────
echo ""
echo "formatting.lua:"
check "conform.nvim plugin"        grep -q 'conform.nvim' "$REPO_ROOT/nvim/lua/plugins/formatting.lua"
check "format_on_save"             grep -q 'format_on_save' "$REPO_ROOT/nvim/lua/plugins/formatting.lua"
check "timeout_ms = 1000"          grep -q 'timeout_ms.*1000' "$REPO_ROOT/nvim/lua/plugins/formatting.lua"
check "lsp_format = fallback"      grep -q 'lsp_format.*fallback' "$REPO_ROOT/nvim/lua/plugins/formatting.lua"
check "shfmt for sh"               grep -q 'sh.*shfmt' "$REPO_ROOT/nvim/lua/plugins/formatting.lua"
check "ruff_fix + ruff_format"     grep -q 'ruff_fix.*ruff_format' "$REPO_ROOT/nvim/lua/plugins/formatting.lua"
check "gofumpt + goimports"        grep -q 'gofumpt.*goimports' "$REPO_ROOT/nvim/lua/plugins/formatting.lua"
check "yaml.github = prettier"     grep -q 'yaml.github.*prettier' "$REPO_ROOT/nvim/lua/plugins/formatting.lua"
check "markdown = prettier"        grep -q 'markdown.*prettier' "$REPO_ROOT/nvim/lua/plugins/formatting.lua"
check "shfmt args -i 2 -ci"       grep -q 'shfmt.*prepend_args' "$REPO_ROOT/nvim/lua/plugins/formatting.lua"

# markdownlint-cli2 MUST NOT be in conform (it's a linter)
if grep -q 'markdownlint' "$REPO_ROOT/nvim/lua/plugins/formatting.lua"; then
  nok "no markdownlint in conform (it's a linter)"
else
  ok "no markdownlint in conform (it's a linter)"
fi

# ── linting.lua ───────────────────────────────────────────────────────────
echo ""
echo "linting.lua:"
check "nvim-lint plugin"           grep -q 'nvim-lint' "$REPO_ROOT/nvim/lua/plugins/linting.lua"
check "BufWritePost event"         grep -q 'BufWritePost' "$REPO_ROOT/nvim/lua/plugins/linting.lua"
check "BufReadPost event"          grep -q 'BufReadPost' "$REPO_ROOT/nvim/lua/plugins/linting.lua"
check "shellcheck for sh"          grep -q 'sh.*shellcheck' "$REPO_ROOT/nvim/lua/plugins/linting.lua"
check "golangcilint for go"        grep -q 'go.*golangcilint' "$REPO_ROOT/nvim/lua/plugins/linting.lua"
check "zizmor for yaml.github"     grep -q 'yaml.github.*zizmor' "$REPO_ROOT/nvim/lua/plugins/linting.lua"
check "markdownlint-cli2 for md"   grep -q 'markdown.*markdownlint' "$REPO_ROOT/nvim/lua/plugins/linting.lua"
check "actionlint for yaml.github" grep -q 'yaml.github.*actionlint' "$REPO_ROOT/nvim/lua/plugins/linting.lua"
check "tflint for terraform"       grep -q 'terraform.*tflint' "$REPO_ROOT/nvim/lua/plugins/linting.lua"

# InsertLeave MUST NOT be in events (prevents lag)
if grep -q 'InsertLeave' "$REPO_ROOT/nvim/lua/plugins/linting.lua"; then
  nok "no InsertLeave in lint events (prevents lag)"
else
  ok "no InsertLeave in lint events (prevents lag)"
fi

# ── integrations.lua ──────────────────────────────────────────────────────
echo ""
echo "integrations.lua:"
check "lazygit.nvim"               grep -q 'lazygit.nvim' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"
check "vim-tmux-navigator"         grep -q 'vim-tmux-navigator' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"
check "direnv.vim"                 grep -q 'direnv.vim' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"
check "fzf-lua"                    grep -q 'fzf-lua' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"
check "gitsigns.nvim"              grep -q 'gitsigns.nvim' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"
check "which-key.nvim"             grep -q 'which-key.nvim' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"
check "leader+fs = live_grep"      grep -q 'leader>fs.*live_grep' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"
check "leader+fw = grep_cword"     grep -q 'leader>fw.*grep_cword' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"
check "fzf_opts explicit"          grep -q 'fzf_opts' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"
check "C-h tmux navigate"          grep -q 'C-h.*TmuxNavigateLeft' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"
check "leader+gg = LazyGit"        grep -q 'leader>gg.*LazyGit' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"
check "gitsigns stage_hunk"        grep -q 'stage_hunk' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"
check "gitsigns blame_line"        grep -q 'blame_line' "$REPO_ROOT/nvim/lua/plugins/integrations.lua"

# ── Install script link() calls ──────────────────────────────────────────
echo ""
echo "Install scripts:"
check "macos: nvim mapping"        grep -q 'link nvim.*\.config/nvim' "$REPO_ROOT/install-macos.sh"
check "wsl: nvim mapping"          grep -q 'link nvim.*\.config/nvim' "$REPO_ROOT/install-wsl.sh"

# Regression: Plans 2–9 link() calls preserved
check "macos: bash links preserved"      test "$(grep -c 'link bash/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "macos: git links preserved"       test "$(grep -c 'link git/' "$REPO_ROOT/install-macos.sh")" -eq 2
check "macos: kitty links preserved"     test "$(grep -c 'link kitty/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: tmux links preserved"      test "$(grep -c 'link tmux/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: starship links preserved"  test "$(grep -c 'link starship/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: lazygit links preserved"   test "$(grep -c 'link lazygit/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: mise links preserved"      test "$(grep -c 'link mise/' "$REPO_ROOT/install-macos.sh")" -eq 1
check "macos: opencode links preserved"  test "$(grep -c 'link opencode/' "$REPO_ROOT/install-macos.sh")" -eq 4
check "wsl: bash links preserved"        test "$(grep -c 'link bash/' "$REPO_ROOT/install-wsl.sh")" -eq 4
check "wsl: git links preserved"         test "$(grep -c 'link git/' "$REPO_ROOT/install-wsl.sh")" -eq 2
check "wsl: kitty links preserved"       test "$(grep -c 'link kitty/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: tmux links preserved"        test "$(grep -c 'link tmux/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: starship links preserved"    test "$(grep -c 'link starship/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: lazygit links preserved"     test "$(grep -c 'link lazygit/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: mise links preserved"        test "$(grep -c 'link mise/' "$REPO_ROOT/install-wsl.sh")" -eq 1
check "wsl: opencode links preserved"    test "$(grep -c 'link opencode/' "$REPO_ROOT/install-wsl.sh")" -eq 4

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
total=$((pass + fail))
echo "─────────────────────────────────────────"
printf "Results: %d/%d passed" "$pass" "$total"
if [[ "$fail" -gt 0 ]]; then
  printf " (\033[0;31m%d failed\033[0m)" "$fail"
fi
echo ""

# Current count: 101 tests. Floor should be within ~10% of actual.
if (( total < 91 )); then
  echo "WARNING: only $total tests ran (expected >= 91). Were tests deleted?"
  exit 1
fi

exit "$( (( fail > 0 )) && echo 1 || echo 0 )"
