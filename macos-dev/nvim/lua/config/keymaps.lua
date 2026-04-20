-- keymaps.lua — user-specific keymap overrides on top of LazyVim defaults.
-- LazyVim's default keymap set is extensive; add only divergences.

vim.api.nvim_set_keymap("i", "jj", "<Esc>", { noremap = false })
vim.api.nvim_set_keymap("i", "jk", "<Esc>", { noremap = false })
