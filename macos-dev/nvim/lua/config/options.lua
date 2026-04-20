-- options.lua — non-default editor options.
-- LazyVim provides sensible defaults (tabstop=2, shiftwidth=2, number,
-- relativenumber, cursorline, ignorecase, smartcase, undofile,
-- splitbelow, splitright, clipboard=unnamedplus, list, listchars, etc.)
-- Only document DIVERGENCES here.

vim.opt.colorcolumn = "120"  -- visible right margin (was 100; user preference)
vim.opt.scrolloff   = 8      -- keep 8 lines of context above/below cursor

-- yaml.github filetype detection. Must run at init (here) rather than in
-- autocmds.lua: LazyVim loads config.autocmds on VeryLazy, which fires
-- AFTER cmdline-opened buffers have resolved their filetype — so a
-- `nvim .github/workflows/ci.yml` invocation would otherwise end up as
-- plain `yaml`. options.lua is loaded by LazyVim during init, before any
-- buffer filetype resolution.
-- Patterns: neovim's vim.filetype pattern matcher rejects the trailing `$`
-- end-of-string anchor (hits go to plain `yaml`). Leave the match open-ended
-- and require `.+/` at the start so we only match nested paths, never a
-- bare `.github/` string embedded in some other filename.
vim.filetype.add({
  pattern = {
    [".+/%.github/workflows/[^/]+%.ya?ml"] = "yaml.github",
    [".+/%.github/actions/[^/]+/action%.ya?ml"] = "yaml.github",
  },
  filename = {
    ["action.yml"] = "yaml.github",
    ["action.yaml"] = "yaml.github",
  },
})

vim.treesitter.language.register("yaml", "yaml.github")

-- Treesitter's language.register only teaches the parser registry about
-- the alias; it doesn't start the highlighter. Hook FileType directly so
-- yaml.github buffers get syntax highlighting without needing a manual
-- `:TSBufEnable`.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "yaml.github",
  callback = function(ev)
    pcall(vim.treesitter.start, ev.buf, "yaml")
  end,
})
