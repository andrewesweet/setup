-- plugins/ghactions.lua — GitHub Actions tooling.
-- No LazyVim Extra covers this niche. yaml.github filetype is
-- registered in config/options.lua (load-bearing, runs at init).

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      -- Pull a GitHub token from gh CLI at server start. The actions
      -- language server version shipped by Mason dereferences
      -- init_options.sessionToken eagerly during its `initialize` RPC
      -- and crashes with "Cannot read properties of undefined (reading
      -- 'sessionToken')" when the option is absent — even though the
      -- upstream docs call it "optional". Graceful nil fallback for
      -- hosts without gh auth.
      local function gh_token()
        local out = vim.fn.systemlist({ "gh", "auth", "token" })
        if vim.v.shell_error == 0 and out[1] and out[1] ~= "" then
          return out[1]
        end
        return ""
      end
      opts.servers.gh_actions_ls = vim.tbl_deep_extend("force", opts.servers.gh_actions_ls or {}, {
        filetypes = { "yaml.github" },
        -- Prefer the repo root (.git or .github) as a root marker, but
        -- fall back to the file's directory so the server still starts
        -- on workflow files checked out in non-git trees.
        root_dir = function(fname)
          return vim.fs.root(fname, { ".git", ".github" }) or vim.fs.dirname(fname)
        end,
        init_options = {
          sessionToken = gh_token(),
        },
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
