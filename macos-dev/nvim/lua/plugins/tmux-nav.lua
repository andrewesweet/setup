-- plugins/tmux-nav.lua — seamless tmux <-> nvim pane navigation.
-- Companion to the tmux tmux-navigator binding in Layer 1b-ii.

return {
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
    },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  desc = "Navigate left" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>",  desc = "Navigate down" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>",    desc = "Navigate up" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right" },
    },
  },
}
