-- learning.lua — vim motion training plugins
-- See docs/cheatsheet.md "Vim training" for usage commands.

return {
  -- hardtime.nvim — block bad habits (hjkl repetition, arrow keys, mouse)
  -- and surface hints for better motions. Active enforcement; expects
  -- you to fight back with proper motions.
  --   :Hardtime toggle  enable/disable
  --   :Hardtime report  show your most-triggered hints
  {
    "m4xshen/hardtime.nvim",
    lazy = false,
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {},
  },

  -- precognition.nvim — render virtual hints showing the motions you
  -- could use to reach interesting positions on the current line / buffer.
  -- Passive (no enforcement). Off by default; toggle when you want
  -- training wheels.
  --   :Precognition toggle  show/hide hints
  --   :Precognition peek    show until next cursor move
  {
    "tris203/precognition.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- vim-be-good — practice game by ThePrimeagen. Loaded only on demand.
  --   :VimBeGood
  {
    "ThePrimeagen/vim-be-good",
    cmd = "VimBeGood",
  },
}
