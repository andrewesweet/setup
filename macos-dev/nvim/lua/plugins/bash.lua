-- plugins/bash.lua — Bash / POSIX shell overrides.
-- No LazyVim Extra exists for bash; this file owns the entire bash
-- tooling stack (LSP, formatter, linter).

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.bashls = vim.tbl_deep_extend("force", opts.servers.bashls or {}, {
        settings = {
          bashIde = {
            shellcheckPath = "shellcheck",
            shellcheckArguments = "--severity=warning",
            shfmt = {
              path = "shfmt",
              indentationSize = 2,
              caseIndentation = true,
            },
          },
        },
      })
      return opts
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        sh = { "shfmt" },
        bash = { "shfmt" },
      },
      formatters = {
        shfmt = { prepend_args = { "-i", "2", "-ci", "-bn" } },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        sh = { "shellcheck" },
        bash = { "shellcheck" },
      },
      linters = {
        shellcheck = { args = { "--severity=warning", "--shell=bash" } },
      },
    },
  },
}
