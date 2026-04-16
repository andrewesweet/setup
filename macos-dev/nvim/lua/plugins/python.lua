-- plugins/python.lua — Python language overrides.
-- Layers on top of lazyvim.plugins.extras.lang.python.
--
-- The Extra honours vim.g.lazyvim_python_lsp — setting it to "ty"
-- disables pyright/basedpyright and enables the ty LSP (astral-sh's
-- new Python LSP, installed via uv tool, NOT via Mason).

vim.g.lazyvim_python_lsp = "ty"
vim.g.lazyvim_python_formatter = "ruff"

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.ty = vim.tbl_deep_extend("force", opts.servers.ty or {}, {
        enabled = true,
        autostart = true,
      })
      opts.servers.ruff = vim.tbl_deep_extend("force", opts.servers.ruff or {}, {
        enabled = true,
        autostart = true,
        init_options = {
          settings = {
            fixAll = true,
            organizeImports = true,
          },
        },
      })
      return opts
    end,
  },
}
