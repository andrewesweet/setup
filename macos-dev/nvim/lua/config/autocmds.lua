-- autocmds.lua — load-bearing autocommands.
-- LazyVim covers split-resize, trim-whitespace (via conform), and most
-- ergonomic defaults. Only the gh-actions filetype detection remains
-- here because the filetype `yaml.github` is referenced from
-- plugins/ghactions.lua.

vim.filetype.add({
  pattern = {
    [".*/%.github/workflows/[^/]+%.ya?ml$"] = "yaml.github",
    [".*/%.github/actions/[^/]+/action%.ya?ml$"] = "yaml.github",
  },
  filename = {
    ["action.yml"] = "yaml.github",
    ["action.yaml"] = "yaml.github",
  },
})

vim.treesitter.language.register("yaml", "yaml.github")
