-- plugins/python.lua — Python language overrides.
-- Layers on top of lazyvim.plugins.extras.lang.python.
--
-- Sets the Python LSP to 'ty' (astral-sh's new type checker, installed
-- via uv tool, NOT via Mason). Explicitly disables pyright/basedpyright
-- since vim.g.lazyvim_python_lsp alone does not prevent them from loading.

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
      opts.servers.basedpyright = vim.tbl_deep_extend("force", opts.servers.basedpyright or {}, {
        enabled = false,
      })
      opts.servers.pyright = vim.tbl_deep_extend("force", opts.servers.pyright or {}, {
        enabled = false,
      })
      return opts
    end,
  },
}
