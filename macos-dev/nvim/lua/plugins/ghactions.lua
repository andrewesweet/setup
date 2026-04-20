-- plugins/ghactions.lua — GitHub Actions tooling.
-- No LazyVim Extra covers this niche. yaml.github filetype is
-- registered in config/autocmds.lua (load-bearing).

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
      linters = {
        zizmor = { args = { "--format", "plain", "--no-progress" } },
      },
    },
  },
}
