-- options.lua — non-default editor options.
-- LazyVim provides sensible defaults (tabstop=2, shiftwidth=2, number,
-- relativenumber, cursorline, ignorecase, smartcase, undofile,
-- splitbelow, splitright, clipboard=unnamedplus, list, listchars, etc.)
-- Only document DIVERGENCES here.

vim.opt.colorcolumn = "120"  -- visible right margin (was 100; user preference)
vim.opt.scrolloff   = 8      -- keep 8 lines of context above/below cursor

-- yaml.github filetype detection. Must run at init (here) rather than in
-- autocmds.lua: LazyVim loads config.autocmds on VeryLazy, which fires
-- AFTER cmdline-opened buffers have resolved their filetype — so a
-- `nvim .github/workflows/ci.yml` invocation would otherwise end up as
-- plain `yaml`. options.lua is loaded by LazyVim during init, before any
-- buffer filetype resolution.
-- Patterns: neovim's vim.filetype pattern matcher rejects the trailing `$`
-- end-of-string anchor (hits go to plain `yaml`). Leave the match open-ended
-- and require `.+/` at the start so we only match nested paths, never a
-- bare `.github/` string embedded in some other filename.
vim.filetype.add({
  pattern = {
    [".+/%.github/workflows/[^/]+%.ya?ml"] = "yaml.github",
    [".+/%.github/actions/[^/]+/action%.ya?ml"] = "yaml.github",
  },
  filename = {
    ["action.yml"] = "yaml.github",
    ["action.yaml"] = "yaml.github",
  },
})

vim.treesitter.language.register("yaml", "yaml.github")

-- Treesitter's language.register only teaches the parser registry about
-- the alias; it doesn't start the highlighter. Hook FileType directly so
-- yaml.github buffers get syntax highlighting without needing a manual
-- `:TSBufEnable`. FileType covers buffers opened after this module loads;
-- a VimEnter sweep catches the cmdline-opened buffer (e.g. `nvim ci.yml`)
-- whose FileType already fired before options.lua registered the autocmd.
local function start_ts_yaml(buf)
  pcall(vim.treesitter.start, buf, "yaml")
end
vim.api.nvim_create_autocmd("FileType", {
  pattern = "yaml.github",
  callback = function(ev) start_ts_yaml(ev.buf) end,
})
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].filetype == "yaml.github" then
        start_ts_yaml(buf)
      end
    end
  end,
})

-- First-line-only diagnostic underline handler.
--
-- zizmor emits multi-line range diagnostics: `overly broad permissions`
-- spans from the top of the workflow to EOF, `credential persistence`
-- spans each affected job's steps block. nvim's default underline
-- handler paints the entire range, so a workflow with several findings
-- ends up underlined top-to-bottom and the syntax highlighting becomes
-- almost invisible.
--
-- Override the underline handler to clamp each diagnostic's extmark to
-- its starting line only. First line still underlined → location at a
-- glance. Subsequent lines of the range stay clean → syntax legible.
-- Signs + virtual_text still receive the full range info, so nothing
-- is lost, it's just displayed less aggressively.
local diag_underline_hl = {
  [vim.diagnostic.severity.ERROR] = "DiagnosticUnderlineError",
  [vim.diagnostic.severity.WARN]  = "DiagnosticUnderlineWarn",
  [vim.diagnostic.severity.INFO]  = "DiagnosticUnderlineInfo",
  [vim.diagnostic.severity.HINT]  = "DiagnosticUnderlineHint",
}
vim.diagnostic.handlers.underline = {
  show = function(ns, bufnr, diagnostics, display_opts)
    local priority = (display_opts and display_opts.priority) or 50
    for _, d in ipairs(diagnostics) do
      local end_col
      if d.lnum == d.end_lnum then
        end_col = d.end_col
      else
        local line = vim.api.nvim_buf_get_lines(bufnr, d.lnum, d.lnum + 1, false)[1]
        end_col = line and #line or d.col + 1
      end
      pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, d.lnum, d.col, {
        end_row = d.lnum,
        end_col = end_col,
        hl_group = diag_underline_hl[d.severity] or "DiagnosticUnderlineHint",
        priority = priority,
        strict = false,
      })
    end
  end,
  hide = function(ns, bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end,
}
