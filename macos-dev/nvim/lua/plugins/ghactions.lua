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
        -- nvim-lspconfig's gh_actions_ls upstream expects the new
        -- neovim 0.11+ root_dir signature: `function(bufnr, on_dir)`
        -- and calls `on_dir(root)` when a match is found. An old-style
        -- `function(fname) return root end` is silently ignored by
        -- vim.lsp.enable — on_dir never fires, no root gets picked,
        -- autostart quietly declines to attach. (Found via divergence
        -- from upstream lspconfig spec.)
        root_dir = function(bufnr, on_dir)
          local parent = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
          if
            vim.endswith(parent, "/.github/workflows")
            or vim.endswith(parent, "/.forgejo/workflows")
            or vim.endswith(parent, "/.gitea/workflows")
          then
            on_dir(parent)
            return
          end
          local root = vim.fs.root(bufnr, { ".git", ".github" })
          if root then
            on_dir(root)
          end
        end,
        init_options = {
          sessionToken = gh_token(),
        },
      })

      -- yamlls also needs to attach to yaml.github (schemastore completion
      -- + validation). LazyVim's lang.yaml extra registers the default
      -- filetypes { yaml, yaml.docker-compose, yaml.gitlab, yaml.helm-values }
      -- — append yaml.github so workflow buffers match.
      opts.servers.yamlls = opts.servers.yamlls or {}
      local yamlls_ft = opts.servers.yamlls.filetypes
        or { "yaml", "yaml.docker-compose", "yaml.gitlab", "yaml.helm-values" }
      if not vim.tbl_contains(yamlls_ft, "yaml.github") then
        table.insert(yamlls_ft, "yaml.github")
      end
      opts.servers.yamlls.filetypes = yamlls_ft

      -- Retro-attach sweep: LazyVim's lsp plugin loads on BufReadPre and
      -- mason-lspconfig.setup calls vim.lsp.enable asynchronously inside
      -- the plugin's config() — so for a cmdline-opened buffer
      -- (`nvim .github/workflows/ci.yml`) the FileType event can fire
      -- before vim.lsp.enable's internal autocmd is registered, and the
      -- LSP never sees that buffer. After VimEnter everything is wired;
      -- re-emit a synthetic FileType on every already-open yaml.github
      -- buffer so the autostart path engages retroactively.
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.bo[buf].filetype == "yaml.github" then
              vim.api.nvim_exec_autocmds("FileType", {
                buffer = buf,
                modeline = false,
              })
            end
          end
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
