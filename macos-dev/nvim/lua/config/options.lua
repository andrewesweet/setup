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
-- `:TSBufEnable`. FileType covers buffers opened after this module loads;
-- a VimEnter sweep catches the cmdline-opened buffer (e.g. `nvim ci.yml`)
-- whose FileType already fired before options.lua registered the autocmd.
local function start_ts_yaml(buf)
  pcall(vim.treesitter.start, buf, "yaml")
end
vim.api.nvim_create_autocmd("FileType", {
  pattern = "yaml.github",
  callback = function(ev) start_ts_yaml(ev.buf) end,
})
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].filetype == "yaml.github" then
        start_ts_yaml(buf)
      end
    end
  end,
})
