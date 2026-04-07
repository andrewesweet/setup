-- options.lua — editor options
-- See docs/design/editor-neovim.md for the specification.

local opt = vim.opt
opt.tabstop     = 2
opt.shiftwidth  = 2
opt.expandtab   = true
opt.smartindent = true
opt.number         = true
opt.relativenumber = true
opt.cursorline     = true
opt.colorcolumn    = "100"
opt.wrap           = false
opt.ignorecase = true
opt.smartcase  = true
opt.undofile   = true
opt.undolevels = 10000
opt.confirm     = true
opt.splitbelow  = true
opt.splitright  = true
opt.scrolloff   = 8
opt.updatetime  = 200
opt.list      = true
opt.listchars = { tab = "→ ", trail = "·", nbsp = "␣" }
opt.clipboard = "unnamedplus"
