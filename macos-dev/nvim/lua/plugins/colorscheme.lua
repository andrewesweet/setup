-- colorscheme.lua — Dracula Pro via lazy.nvim local `dir` plugin
-- See macos-dev/docs/design/theming.md § 3.1 Wave A.
--
-- Tier 1: Pro ready-made vim plugin from ~/dracula-pro/themes/vim.
-- Loaded with `lazy = false` + high priority so it is applied before any
-- LazyVim plugin resolves colours. We also override the LazyVim default
-- colorscheme opt so `:LazyVim` treats "dracula_pro" as the active theme.

return {
  -- 1. Ship the Pro vim plugin to lazy.nvim as a local-directory plugin.
  {
    dir = vim.fn.expand("~/dracula-pro/themes/vim"),
    name = "dracula-pro",
    lazy = false,
    priority = 1000,
    config = function()
      -- The plugin registers a `dracula_pro` colorscheme (see
      -- ~/dracula-pro/themes/vim/colors/dracula_pro.vim).
      vim.cmd.colorscheme("dracula_pro")
    end,
  },

  -- 2. Override the LazyVim default colorscheme opt so LazyVim's startup
  --    colorscheme switch resolves to dracula_pro.
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "dracula_pro",
    },
  },
}
