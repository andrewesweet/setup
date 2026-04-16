-- options.lua — non-default editor options.
-- LazyVim provides sensible defaults (tabstop=2, shiftwidth=2, number,
-- relativenumber, cursorline, ignorecase, smartcase, undofile,
-- splitbelow, splitright, clipboard=unnamedplus, list, listchars, etc.)
-- Only document DIVERGENCES here.

vim.opt.colorcolumn = "120"  -- visible right margin (was 100; user preference)
vim.opt.scrolloff   = 8      -- keep 8 lines of context above/below cursor
