-- plugins/octo.lua — GitHub PR/Issue review inside nvim.
-- Requires `gh` CLI authenticated (shipped in Layer 1b-iii).

return {
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {},
  },
}
