-- plugins/yaml.lua — YAML overrides on top of lazyvim.plugins.extras.lang.yaml.
--
-- lang.yaml Extra's yamlls defaults (including schemastore.nvim auto-inject
-- for common YAML filetypes) are accepted as-is. This file only replaces
-- the default YAML formatter (prettier) with yamlfmt.
--
-- Formatter args intentionally stay empty: yamlfmt's cosmetic knobs
-- (indentless_arrays, scan_folded_as_literal, etc.) are config-file-only
-- in v0.x — they're *not* CLI flags. Passing them as args made the
-- formatter abort with "flag provided but not defined" on every save.
-- Projects that want non-default behaviour drop a .yamlfmt in the repo
-- root; yamlfmt auto-discovers it.
--
-- LazyVim already wires format_on_save globally via conform, so this
-- spec no longer sets it locally (doing so triggered a "Don't set
-- opts.format_on_save for conform.nvim" warning on every session).

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        yaml = { "yamlfmt" },
        -- GitHub Actions workflow files get the `yaml.github` filetype
        -- from options.lua; map them explicitly so `:w` still reformats.
        ["yaml.github"] = { "yamlfmt" },
      },
    },
  },
}
