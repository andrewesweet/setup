-- formatting.lua — conform.nvim configuration
-- See docs/design/editor-neovim.md for the specification.
--
-- Note: markdownlint-cli2 is a linter (not a formatter). Use prettier for markdown.

return {
  {
    "stevearc/conform.nvim",
    opts = {
      format_on_save = { timeout_ms = 1000, lsp_format = "fallback" }, -- conform v5+: renamed from lsp_fallback
      formatters_by_ft = {
        sh   = { "shfmt" },
        bash = { "shfmt" },
        python = { "ruff_fix", "ruff_format" },
        go = { "gofumpt", "goimports" },
        terraform = { "terraform_fmt" },
        tf = { "terraform_fmt" },
        ["yaml.github"] = { "prettier" },
        yaml = { "prettier" },
        json = { "prettier" },
        markdown = { "prettier" },
      },
      formatters = {
        shfmt = { prepend_args = { "-i", "2", "-ci", "-bn" } },
      },
    },
  },
}
