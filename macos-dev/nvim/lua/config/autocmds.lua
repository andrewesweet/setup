-- autocmds.lua — autocommands
-- See docs/design/editor-neovim.md for the specification.

-- GitHub Actions filetype detection (yaml.github)
vim.filetype.add({
  pattern = {
    ['.*/%.github/workflows/[^/]+%.ya?ml$'] = 'yaml.github',
    ['.*/%.github/actions/[^/]+/action%.ya?ml$'] = 'yaml.github',
  },
  filename = {
    ['action.yml']  = 'yaml.github',
    ['action.yaml'] = 'yaml.github',
  },
})
vim.treesitter.language.register('yaml', 'yaml.github')

-- Auto-resize splits on VimResized
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("auto_resize", { clear = true }),
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- Strip trailing whitespace on save for markdown and text files
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("strip_whitespace", { clear = true }),
  pattern = { "*.md", "*.txt" },
  callback = function()
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[%s/\s\+$//e]])
    vim.api.nvim_win_set_cursor(0, pos)
  end,
})
