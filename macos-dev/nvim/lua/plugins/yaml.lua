-- plugins/yaml.lua — YAML overrides on top of lazyvim.plugins.extras.lang.yaml.
--
-- lang.yaml Extra's yamlls defaults (including schemastore.nvim auto-inject
-- for common YAML filetypes) are accepted as-is. This file only replaces
-- the default YAML formatter (prettier) with yamlfmt, which produces
-- K8s-friendly output that respects existing indentation conventions.

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        yaml = { "yamlfmt" },
      },
      formatters = {
        yamlfmt = {
          command = "yamlfmt",
          args = { "-formatter", "basic", "-indentless_arrays=true" },
        },
      },
      format_on_save = function(bufnr)
        if vim.bo[bufnr].filetype == "yaml" then
          return { lsp_format = "fallback", timeout_ms = 1000 }
        end
      end,
    },
  },
}
