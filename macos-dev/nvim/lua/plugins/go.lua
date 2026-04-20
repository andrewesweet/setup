-- plugins/go.lua — Go language overrides.
-- Layers on top of lazyvim.plugins.extras.lang.go.

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.gopls = vim.tbl_deep_extend("force", opts.servers.gopls or {}, {
        settings = {
          gopls = {
            analyses = {
              unusedparams = true,
              shadow = true,
            },
            staticcheck = true,
            usePlaceholders = true,
            completeUnimported = true,
            gofumpt = true,
            hints = {
              parameterNames = true,
              assignVariableTypes = true,
            },
          },
        },
      })
      return opts
    end,
  },
}
