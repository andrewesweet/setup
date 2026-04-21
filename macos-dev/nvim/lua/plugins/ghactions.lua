-- plugins/ghactions.lua — GitHub Actions tooling.
-- No LazyVim Extra covers this niche. yaml.github filetype is
-- registered in config/options.lua (load-bearing, runs at init).

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- First-line-only underline handler lives in config/options.lua
      -- (runs at init so the override is in place before any plugin
      -- publishes diagnostics). See the comment block there for why
      -- zizmor's multi-line range findings made this necessary.

      -- Tag every diagnostic with its source ([zizmor], [actionlint],
      -- [gh_actions_ls], [ty], [ruff], …). Without this, two linters
      -- producing superficially similar messages on the same file
      -- are indistinguishable in virtual_text + float.
      -- Append the rule code to every diagnostic (e.g. `[artipacked]`).
      -- Linters like zizmor and actionlint expose the audit rule name
      -- via `diagnostic.code`; that string is the googleable identifier
      -- for each finding and appears in the float popup by default, but
      -- the virtual_text trailer drops it. Add a `suffix` that puts it
      -- back — and keep `source = "always"` so the virtual_text reads
      -- `● zizmor: credential persistence [artipacked]`.
      local function code_suffix(diag)
        if diag.code and diag.code ~= "" then
          return " [" .. diag.code .. "]"
        end
        return ""
      end
      opts.diagnostics = opts.diagnostics or {}
      opts.diagnostics.virtual_text = vim.tbl_deep_extend(
        "force",
        opts.diagnostics.virtual_text or {},
        { source = "always", suffix = code_suffix }
      )
      opts.diagnostics.float = vim.tbl_deep_extend(
        "force",
        opts.diagnostics.float or {},
        { source = "always" }
      )

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

      -- Intentionally do NOT attach yamlls to yaml.github: yamlls has no
      -- GitHub Actions schema, so it marks every workflow-specific key
      -- (jobs, runs-on, uses, with, …) as a warning. Under LSP-based
      -- semantic highlighting that paints the whole file yellow with
      -- underlines. gh_actions_ls owns validation + completion for
      -- workflows; let yamlls stay on generic yaml only.

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
