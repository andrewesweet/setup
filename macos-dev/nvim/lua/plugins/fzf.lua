-- plugins/fzf.lua — fzf-lua keymap overrides.
--
-- LazyVim's editor.fzf Extra wires a different <leader>f* namespace
-- (<leader>ff/fb/fc/fg/fr/fR/fe/fE/fn/ft/fT) focused on files + recent
-- + explorer + terminal. Per docs/design/editor-neovim.md this setup
-- preserves the older 9-keymap layout the user has muscle memory for:
--
--   <leader>ff  files
--   <leader>fs  live grep       (matches shell `fs` alias)
--   <leader>fb  buffers
--   <leader>fh  help tags
--   <leader>fr  recent files
--   <leader>fc  commands
--   <leader>fd  document diagnostics
--   <leader>fw  grep word under cursor
--   <leader>fz  zoxide (Layer 1c dependency)
--
-- Override LazyVim's keys by re-declaring them with the same lhs —
-- lazy.nvim merges keys entries by lhs, last declaration wins.

return {
  {
    "ibhagwan/fzf-lua",
    keys = {
      { "<leader>ff", "<cmd>FzfLua files<cr>",               desc = "Find files" },
      { "<leader>fs", "<cmd>FzfLua live_grep<cr>",           desc = "Find string (live grep)" },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>",             desc = "Buffers" },
      { "<leader>fh", "<cmd>FzfLua help_tags<cr>",           desc = "Help tags" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<cr>",            desc = "Recent files" },
      { "<leader>fc", "<cmd>FzfLua commands<cr>",            desc = "Commands" },
      { "<leader>fd", "<cmd>FzfLua diagnostics_document<cr>", desc = "Diagnostics (buffer)" },
      { "<leader>fw", "<cmd>FzfLua grep_cword<cr>",          desc = "Find word under cursor" },
      { "<leader>fz", "<cmd>FzfLua zoxide<cr>",              desc = "Zoxide dirs" },
    },
    opts = {
      -- Isolate fzf-lua from ambient $FZF_DEFAULT_OPTS; the shell's
      -- Dracula-Pro colours + ctrl-j/k already live there and they'd
      -- double-apply on top of fzf-lua's own bindings, changing
      -- behaviour in subtle ways. Set the binds we need explicitly.
      fzf_opts = { ["--bind"] = "ctrl-j:down,ctrl-k:up" },
      winopts = { height = 0.4, width = 1.0, row = 1.0 },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>f", group = "find (fzf)" },
      },
    },
  },
}
