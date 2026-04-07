-- linting.lua — nvim-lint configuration
-- See docs/design/editor-neovim.md for the specification.
--
-- Note: InsertLeave removed from events to prevent lag from slow linters.
-- Fast linting feedback comes from LSP servers (bashls, ruff, ty).

return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      events = { "BufWritePost", "BufReadPost" },
      linters_by_ft = {
        sh       = { "shellcheck" },
        bash     = { "shellcheck" },
        python   = { "ruff" },
        go       = { "golangcilint" },
        terraform     = { "tflint" },
        ["yaml.github"] = { "actionlint", "zizmor" },
        markdown = { "markdownlint-cli2" },
      },
      linters = {
        shellcheck = { args = { "--severity=warning", "--shell=bash" } },
        golangcilint = { args = { "run", "--output.formats.text.path=stderr", "--issues-exit-code=1" } },
        tflint = { args = { "--format", "compact" } },
        zizmor = { args = { "--format", "plain", "--no-progress" } },
      },
    },
  },
}
