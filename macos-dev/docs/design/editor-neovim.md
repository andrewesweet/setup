# Editor — Neovim (LazyVim)

## LazyVim Distribution

LazyVim is the chosen starting point. Config in `lua/plugins/` MUST override and extend LazyVim defaults. Configuration MUST NOT fight LazyVim defaults — extend them.

**Note on node:** Node SHOULD be managed via mise global config (`nodejs = "lts"`) rather than Homebrew to avoid PATH conflicts. Mason LSP servers that need node use mise-managed node.

## init.lua

The `init.lua` file MUST be filled in from https://github.com/LazyVim/starter verbatim at implementation time.

## lua/config/options.lua

The following options MUST be set as specified:

```lua
local opt = vim.opt
opt.tabstop     = 2
opt.shiftwidth  = 2
opt.expandtab   = true
opt.smartindent = true
opt.number         = true
opt.relativenumber = true
opt.cursorline     = true
opt.colorcolumn    = "100"
opt.wrap           = false
opt.ignorecase = true
opt.smartcase  = true
opt.undofile   = true
opt.undolevels = 10000
opt.confirm     = true
opt.splitbelow  = true
opt.splitright  = true
opt.scrolloff   = 8
opt.updatetime  = 200
opt.list      = true
opt.listchars = { tab = "→ ", trail = "·", nbsp = "␣" }
opt.clipboard = "unnamedplus"
```

## lua/config/autocmds.lua

The following autocmds MUST be configured:

### GitHub Actions Filetype Detection

GitHub Actions filetype detection (yaml.github) MUST be implemented:

```lua
vim.filetype.add({
  pattern = {
    ['.*/%.github/workflows/[^/]+%.ya?ml$'] = 'yaml.github',
    ['.*/%.github/actions/[^/]+/action%.ya?ml$'] = 'yaml.github',
  },
  filename = {
    ['action.yml']  = 'yaml.github',
    ['action.yaml'] = 'yaml.github',
  },
})
vim.treesitter.language.register('yaml', 'yaml.github')
```

### Additional Autocmds

Auto-resize splits on VimResized.

Strip trailing whitespace on save for md/txt (fallback for conform).

## lua/plugins/lsp.lua

The LSP configuration MUST be implemented as follows. The vim.g assignments MUST be BEFORE the return statement:

```lua
vim.g.lazyvim_python_lsp       = "ty"
vim.g.lazyvim_python_formatter = "ruff"

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        basedpyright = { enabled = false },
        pyright      = { enabled = false },
        pylsp        = { enabled = false },
        ty = { enabled = true, autostart = true },
        ruff = {
          enabled = true, autostart = true,
          init_options = {
            settings = { fixAll = true, organizeImports = true },
          },
        },
        gopls = {
          settings = {
            gopls = {
              analyses = { unusedparams = true, shadow = true },
              staticcheck = true, gofumpt = true,
              hints = { parameterNames = true, assignVariableTypes = true },
            },
          },
        },
        bashls = {
          settings = {
            bashIde = {
              shellcheckPath = "shellcheck",
              shellcheckArguments = "--severity=warning",
              shfmt = { path = "shfmt", indentationSize = 2, caseIndentation = true },
            },
          },
        },
        terraformls = {},
        yamlls = {
          filetypes = { "yaml" },
          settings = {
            yaml = {
              validate = true, hover = true, completion = true,
              schemaStore = { enable = false, url = "" },
              schemas = {
                ["https://json.schemastore.org/kustomization.json"] = "kustomization.{yml,yaml}",
              },
            },
          },
        },
        gh_actions_ls = {
          filetypes = { "yaml.github" },
          root_dir = function(fname)
            return vim.fs.root(fname, ".git")
          end,
        },
        jsonls = {
          settings = {
            json = {
              validate = { enable = true },
              schemaStore = { enable = false, url = "" },
            },
          },
        },
      },
    },
  },
  { "b0o/schemastore.nvim", lazy = true, version = false },
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "bash-language-server", "gopls", "terraform-ls",
        "yaml-language-server", "gh-actions-language-server", "json-lsp",
        "shfmt", "gofumpt", "goimports", "prettier",
        "shellcheck", "golangci-lint", "tflint", "actionlint",
        "markdownlint-cli2",
      },
    },
  },
}
```

**CRITICAL requirements:**
- The vim.g assignments MUST be BEFORE the return statement.
- `ty` MUST NOT be used in `require("lspconfig.util")` — use `vim.fs.root()`.
- `ty` MUST NOT be in Mason's ensure_installed.

## lua/plugins/formatting.lua

The formatting configuration MUST be implemented as follows:

```lua
return {
  {
    "stevearc/conform.nvim",
    opts = {
      format_on_save = { timeout_ms = 500, lsp_format = "fallback" }, -- conform v5+: renamed from lsp_fallback
      formatters_by_ft = {
        sh   = { "shfmt" },
        bash = { "shfmt" },
        python = { "ruff_fix", "ruff_format" },
        go = { "gofumpt", "goimports" },
        terraform = { "terraform_fmt" },
        tf = { "terraform_fmt" },
        ["yaml.github"] = { "prettier" },
        yaml = { "prettier" },
        json = { "prettier" },
        markdown = { "prettier" },
      },
      formatters = {
        shfmt = { prepend_args = { "-i", "2", "-ci", "-bn" } },
      },
    },
  },
}
```

**Note:** markdownlint-cli2 MUST NOT be in conform (it is a linter with --fix, not a conform-compatible formatter). prettier MUST be used for markdown formatting.

## lua/plugins/linting.lua

The linting configuration MUST be implemented as follows:

```lua
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
```

**Note on linting events:** `InsertLeave` was removed from the events list to prevent lag from slow linters (golangcilint, tflint, zizmor, actionlint). These linters now only fire on `BufWritePost` and `BufReadPost`. Fast linting feedback for shell and Python comes from the LSP servers (bashls, ruff, ty) which run continuously.

## lua/plugins/integrations.lua

The integrations configuration MUST be implemented as follows:

```lua
return {
  { "kdheepak/lazygit.nvim", cmd = "LazyGit",
    keys = { { "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit" } },
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  { "christoomey/vim-tmux-navigator",
    cmd = { "TmuxNavigateLeft", "TmuxNavigateDown", "TmuxNavigateUp", "TmuxNavigateRight" },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate left" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right" },
    },
  },
  { "direnv/direnv.vim", lazy = false },
  { "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find files" },
      { "<leader>fs", "<cmd>FzfLua live_grep<cr>", desc = "Find string (live grep)" },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
      { "<leader>fh", "<cmd>FzfLua help_tags<cr>", desc = "Help tags" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent files" },
      { "<leader>fc", "<cmd>FzfLua commands<cr>", desc = "Commands" },
      { "<leader>fd", "<cmd>FzfLua diagnostics_document<cr>", desc = "Diagnostics" },
      { "<leader>fw", "<cmd>FzfLua grep_cword<cr>", desc = "Find word under cursor" },
      { "<leader>fz", "<cmd>FzfLua zoxide<cr>", desc = "Zoxide dirs" },
    },
    opts = {
      fzf_opts = { ["--bind"] = "ctrl-j:down,ctrl-k:up" },
      winopts = { height = 0.4, width = 1.0, row = 1.0 },
    },
  },
  { "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add = { text = "▎" }, change = { text = "▎" },
        delete = { text = "" }, topdelete = { text = "" },
        changedelete = { text = "▎" },
      },
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns
        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end
        map("n", "]h", gs.next_hunk, "Next hunk")
        map("n", "[h", gs.prev_hunk, "Prev hunk")
        map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
        map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
        map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
        map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>hd", gs.diffthis, "Diff this")
      end,
    },
  },
  { "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>h", group = "git hunks" },
        { "<leader>f", group = "find (fzf)" },
      },
    },
  },
}
```

**Key requirements:**
- fzf-lua MUST set fzf_opts explicitly to isolate from shell FZF_DEFAULT_OPTS.
- `<leader>fs` MUST equal live_grep (matches shell fs alias).
- `<leader>fw` MUST equal grep_cword.
- Esc in lazygit floating terminal: LazyVim SHOULD handle this. If not, add `vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>")` to keymaps.lua.

## ty Beta Status

ty is in beta as of April 2026. If ty becomes unavailable or unstable, the fallback configuration MUST be:

```lua
vim.g.lazyvim_python_lsp = "basedpyright"
```

In addition, ty MUST be uninstalled:

```bash
uv tool uninstall ty
```
