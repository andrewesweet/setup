-- plugins/ghactions.lua — GitHub Actions tooling.
-- No LazyVim Extra covers this niche. yaml.github filetype is
-- registered in config/options.lua (load-bearing, runs at init).

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.gh_actions_ls = vim.tbl_deep_extend("force", opts.servers.gh_actions_ls or {}, {
        filetypes = { "yaml.github" },
        root_dir = function(fname)
          return vim.fs.root(fname, ".git")
        end,
      })
      return opts
    end,
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        ["yaml.github"] = { "actionlint", "zizmor" },
      },
      -- DO NOT override zizmor args: nvim-lint ships with
      -- `{ "--format", "json-v1" }` and a parser that expects the
      -- json-v1 schema. Forcing plain/no-progress output made the
      -- parser emit "Expected value but found invalid token at
      -- character 1" on every save. Accept the default.
    },
  },
}
