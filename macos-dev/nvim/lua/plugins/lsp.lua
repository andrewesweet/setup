-- lsp.lua — LSP server configuration
-- See docs/design/editor-neovim.md for the specification.
--
-- CRITICAL: vim.g assignments MUST be before the return statement.
-- ty is installed via uv tool, not Mason.
-- Use vim.lsp.config / vim.lsp.enable instead of direct lspconfig calls.

vim.g.lazyvim_python_lsp       = "ty"
vim.g.lazyvim_python_formatter = "ruff"

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        basedpyright = { enabled = false },
        pyright      = { enabled = false },
        pylsp        = { enabled = false },
        ty = { enabled = true, autostart = true },
        ruff = { enabled = true, autostart = true,
          init_options = {
            settings = { fixAll = true, organizeImports = true },
          },
        },
        gopls = {
          settings = {
            gopls = {
              analyses = { unusedparams = true, shadow = true },
              staticcheck = true, gofumpt = true,
              hints = { parameterNames = true, assignVariableTypes = true },
            },
          },
        },
        bashls = {
          settings = {
            bashIde = {
              shellcheckPath = "shellcheck",
              shellcheckArguments = "--severity=warning",
              shfmt = { path = "shfmt", indentationSize = 2, caseIndentation = true },
            },
          },
        },
        terraformls = {},
        yamlls = {
          filetypes = { "yaml" },
          settings = {
            yaml = {
              validate = true, hover = true, completion = true,
              schemaStore = { enable = false, url = "" },
              schemas = {
                ["https://json.schemastore.org/kustomization.json"] = "kustomization.{yml,yaml}",
              },
            },
          },
        },
        gh_actions_ls = { filetypes = { "yaml.github" },
          root_dir = function(fname)
            return vim.fs.root(fname, ".git")
          end,
        },
        jsonls = {
          settings = {
            json = {
              validate = { enable = true },
              schemaStore = { enable = false, url = "" },
            },
          },
        },
      },
    },
  },
  -- schemastore.nvim is a lazy dep only. Do NOT call require("schemastore") to inject schemas
  -- while schemaStore.enable = false in yamlls/jsonls above.
  { "b0o/schemastore.nvim", lazy = true, version = false },
  {
    -- mason.nvim moved orgs from williamboman to mason-org in 2025.
    -- Pinning the new URL keeps lazy.nvim from emitting an "origin
    -- changed" error against existing local clones (LazyVim's spec
    -- already points here, but a bare repo name is robust to future
    -- reorgs and matches the upstream LazyVim convention).
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "bash-language-server", "gopls", "terraform-ls",
        "yaml-language-server", "gh-actions-language-server", "json-lsp",
        "shfmt", "gofumpt", "goimports", "prettier",
        "shellcheck", "golangci-lint", "tflint", "actionlint",
        "markdownlint-cli2",
      },
    },
  },
}
