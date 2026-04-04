# Neovim — LazyVim configuration

Extends `dotfiles-setup.md`. Covers LazyVim installation, LSP setup for
the full language stack, formatter/linter config, and key integrations.

---

## Dotfiles additions

```
~/.dotfiles/
├── Brewfile                     # neovim + node
└── nvim/
    ├── init.lua                 # LazyVim bootstrap (minimal)
    └── lua/
        ├── config/
        │   ├── options.lua      # vim options
        │   ├── keymaps.lua      # custom keymaps
        │   └── autocmds.lua     # filetype detection + autocmds
        └── plugins/
            ├── lsp.lua          # LSP overrides
            ├── formatting.lua   # conform.nvim
            ├── linting.lua      # nvim-lint
            └── integrations.lua # lazygit, fzf-lua, tmux nav, direnv
```

Add to `install.sh`:

```bash
link nvim   .config/nvim
```

---

## Brewfile additions

```ruby
brew "neovim"
brew "node"        # required by several Mason-managed LSP servers
                   # (yaml-language-server, gh-actions-ls, json-lsp)
```

---

## 1. Installation

```bash
# Install LazyVim (one-time bootstrap)
# Back up any existing Neovim config first
mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null

# Clone the LazyVim starter
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git   # detach from starter, use your own dotfiles

# Copy into dotfiles repo
cp -r ~/.config/nvim/* ~/.dotfiles/nvim/

# Symlink (install.sh handles this going forward)
ln -sf ~/.dotfiles/nvim ~/.config/nvim
```

Launch Neovim once — LazyVim will bootstrap lazy.nvim and install all
default plugins automatically. Quit and reopen to finish.

```bash
nvim   # wait for install to complete, then :q
```

---

## 2. Shell integration

Set Neovim as `$EDITOR` in `.bashrc`:

```bash
# Replace the VS Code $EDITOR line from dotfiles-setup.md
export EDITOR='nvim'
export VISUAL='nvim'
export MANPAGER='nvim +Man!'   # use Neovim as man pager
```

Neovim alias in `.bash_aliases`:

```bash
alias v='nvim'
alias vd='nvim -d'    # vimdiff two files: vd file1 file2
```

---

## 3. Neovim options: `lua/config/options.lua`

```lua
-- lua/config/options.lua
-- These extend LazyVim's defaults, not replace them.

local opt = vim.opt

-- Indentation
opt.tabstop     = 2
opt.shiftwidth  = 2
opt.expandtab   = true
opt.smartindent = true

-- Line display
opt.number         = true
opt.relativenumber = true    -- relative line numbers aid vim motion counts
opt.cursorline     = true
opt.colorcolumn    = "100"   -- soft guide at 100 chars
opt.wrap           = false

-- Search
opt.ignorecase = true
opt.smartcase  = true        -- case-sensitive if query contains uppercase

-- Undo
opt.undofile   = true        -- persistent undo across sessions
opt.undolevels = 10000

-- Behaviour
opt.confirm     = true       -- ask before closing unsaved buffer
opt.splitbelow  = true
opt.splitright  = true
opt.scrolloff   = 8          -- keep 8 lines visible above/below cursor
opt.updatetime  = 200        -- faster CursorHold events (used by gitsigns)

-- Whitespace display
opt.list      = true
opt.listchars = { tab = "→ ", trail = "·", nbsp = "␣" }

-- Clipboard — use system clipboard via OSC 52 (works inside tmux/containers)
opt.clipboard = "unnamedplus"
```

---

## 4. Filetype detection: `lua/config/autocmds.lua`

This is the key file for the GitHub Actions Language Server scoping.
It defines a custom `yaml.github` filetype assigned to workflow and
composite action paths, keeping the Actions LS separate from yamlls.

```lua
-- lua/config/autocmds.lua

-- ── GitHub Actions filetype detection ────────────────────────────────────────
-- Assigns yaml.github to files the GitHub Actions LS should handle.
-- yamlls is configured for 'yaml' only; gh_actions_ls for 'yaml.github' only.
-- This MUST be defined before any LSP setup runs.
--
-- Patterns covered:
--   .github/workflows/*.yml / .yaml
--   .github/actions/<name>/action.yml / .yaml  (composite actions)
--   action.yml / action.yaml at repo root       (standalone action repos)
--
-- Limitation: root-level action.yml is hard to distinguish from any other
-- action.yml by path alone. The pattern below matches ONLY action.yml files
-- that sit at the git root (no parent path segments before the filename).
-- If a repo's action.yml is in a subdirectory, add its path manually or
-- add a modeline: # vim: ft=yaml.github
vim.filetype.add({
  pattern = {
    -- Workflow files
    ['.*/%.github/workflows/[^/]+%.ya?ml$'] = 'yaml.github',
    -- Composite actions in .github/actions/<name>/
    ['.*/%.github/actions/[^/]+/action%.ya?ml$'] = 'yaml.github',
  },
  filename = {
    -- Root-level action file (standalone action repos)
    -- This matches action.yml / action.yaml only when it's the exact filename.
    -- It WILL match any file named action.yml anywhere, so keep an eye on
    -- false positives in repos with action.yml files in unexpected locations.
    ['action.yml']  = 'yaml.github',
    ['action.yaml'] = 'yaml.github',
  },
})

-- Register yaml.github with treesitter so it uses YAML highlighting
vim.treesitter.language.register('yaml', 'yaml.github')

-- ── Auto-resize splits on window resize ──────────────────────────────────────
vim.api.nvim_create_autocmd('VimResized', {
  callback = function() vim.cmd('tabdo wincmd =') end,
})

-- ── Strip trailing whitespace on save ────────────────────────────────────────
-- conform.nvim handles this for supported filetypes; this is a fallback.
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = { '*.md', '*.txt' },
  callback = function()
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[%s/\s\+$//e]])
    vim.api.nvim_win_set_cursor(0, pos)
  end,
})
```

---

## 5. LSP configuration: `lua/plugins/lsp.lua`

LazyVim's Python extra defaults to `basedpyright`. The single global
variable `vim.g.lazyvim_python_lsp = "ty"` switches it to ty.

```lua
-- lua/plugins/lsp.lua
return {
  -- ── Python LSP: ty (Astral) ──────────────────────────────────────────────
  -- ty is in beta. It is installed via `uv tool install ty@latest`,
  -- NOT via Mason. If ty is not found on $PATH, LSP will silently not attach.
  -- LazyVim's python extra handles the rest once this global is set.
  --
  -- Two LSPs run simultaneously on Python files:
  --   ty    — type checking, completions, go-to-definition, inlay hints
  --   ruff  — linting, formatting, auto-import organisation
  -- They are complementary; disable basedpyright/pyright explicitly.
  vim.g.lazyvim_python_lsp       = "ty",
  vim.g.lazyvim_python_formatter = "ruff",

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {

        -- ── Disable alternatives ────────────────────────────────────────────
        basedpyright = { enabled = false },
        pyright      = { enabled = false },
        pylsp        = { enabled = false },

        -- ── ty: Python type checking + LSP ─────────────────────────────────
        -- Neovim 0.11+ native API (no require('lspconfig') needed)
        ty = {
          enabled   = true,
          autostart = true,
          -- ty picks up config from pyproject.toml [tool.ty] automatically
        },

        -- ── ruff: Python linting + formatting ──────────────────────────────
        ruff = {
          enabled   = true,
          autostart = true,
          init_options = {
            settings = {
              fixAll        = true,   -- fix all auto-fixable issues on save
              organizeImports = true,
            },
          },
        },

        -- ── gopls: Go ───────────────────────────────────────────────────────
        gopls = {
          settings = {
            gopls = {
              analyses = {
                unusedparams = true,
                shadow       = true,
              },
              staticcheck  = true,
              gofumpt      = true,   -- use gofumpt formatting rules
              hints = {
                parameterNames = true,
                assignVariableTypes = true,
              },
            },
          },
        },

        -- ── bash-language-server: Bash ──────────────────────────────────────
        bashls = {
          settings = {
            bashIde = {
              shellcheckPath      = "shellcheck",
              shellcheckArguments = "--severity=warning",
              shfmt = {
                path              = "shfmt",
                indentationSize   = 2,
                caseIndentation   = true,
              },
            },
          },
        },

        -- ── terraform-ls: Terraform ─────────────────────────────────────────
        terraformls = {},

        -- ── yaml-language-server: YAML (NOT GitHub Actions files) ──────────
        -- Scoped to 'yaml' filetype only. 'yaml.github' files are handled
        -- by gh_actions_ls below. Disabling the built-in schema store and
        -- using schemastore.nvim gives cleaner schema matching.
        yamlls = {
          filetypes = { "yaml" },   -- explicitly exclude yaml.github
          settings = {
            yaml = {
              validate  = true,
              hover     = true,
              completion = true,
              schemaStore = {
                enable = false,     -- use schemastore.nvim instead
                url    = "",
              },
              schemas = {
                -- Add project-specific schemas here as needed.
                -- schemastore.nvim fills the rest from the catalog.
                ["https://json.schemastore.org/kustomization.json"] = "kustomization.{yml,yaml}",
              },
            },
          },
        },

        -- ── gh_actions_ls: GitHub Actions Language Server ──────────────────
        -- Scoped ONLY to 'yaml.github' filetype (see autocmds.lua).
        -- Provides value-aware, context-aware, expression-aware completions
        -- and diagnostics for workflow and composite action files.
        --
        -- Installation: Mason installs it as 'gh-actions-language-server'
        -- (Node-based, requires node in $PATH).
        gh_actions_ls = {
          filetypes = { "yaml.github" },    -- never applies to plain yaml
          root_dir = function(fname)
            return require("lspconfig.util").find_git_ancestor(fname)
          end,
        },

        -- ── jsonls: JSON ────────────────────────────────────────────────────
        jsonls = {
          settings = {
            json = {
              validate = { enable = true },
              schemaStore = {
                enable = false,
                url    = "",
              },
            },
          },
        },

      },

      -- ── Mason: managed LSP server installation ────────────────────────────
      -- ty is NOT listed here — it is installed via `uv tool install ty`.
      -- Everything else is managed by Mason.
    },
  },

  -- ── schemastore.nvim: JSON schema catalog for yamlls + jsonls ───────────
  {
    "b0o/schemastore.nvim",
    lazy = true,
    version = false,
  },

  -- ── Mason tool installation ───────────────────────────────────────────────
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        -- LSP servers
        "bash-language-server",
        "gopls",
        "terraform-ls",
        "yaml-language-server",
        "gh-actions-language-server",
        "json-lsp",
        -- Formatters
        "shfmt",
        "gofumpt",
        "goimports",
        "prettier",          -- YAML formatting fallback
        -- Linters
        "shellcheck",
        "golangci-lint",
        "tflint",
        "actionlint",
        -- Note: ruff is installed by LazyVim's python extra via Mason.
        -- ty is installed via `uv tool install ty` — not Mason.
      },
    },
  },
}
```

---

## 6. Formatting: `lua/plugins/formatting.lua`

```lua
-- lua/plugins/formatting.lua
return {
  {
    "stevearc/conform.nvim",
    opts = {
      -- Format on save (with a 500ms timeout)
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },

      formatters_by_ft = {
        sh   = { "shfmt" },
        bash = { "shfmt" },

        -- Python: ruff handles both linting fixes and formatting.
        -- ruff_format is the formatter; ruff_fix applies lint auto-fixes first.
        python = { "ruff_fix", "ruff_format" },

        go = { "gofumpt", "goimports" },

        terraform      = { "terraform_fmt" },
        ["tf"]         = { "terraform_fmt" },

        -- yaml.github uses the Actions LS for diagnostics;
        -- formatting falls back to prettier (consistent whitespace only).
        ["yaml.github"] = { "prettier" },
        yaml            = { "prettier" },
        json            = { "prettier" },
      },

      formatters = {
        shfmt = {
          prepend_args = { "-i", "2", "-ci", "-bn" },
          -- -i 2   : 2-space indent
          -- -ci    : case statement indent
          -- -bn    : binary ops at start of line
        },
      },
    },
  },
}
```

---

## 7. Linting: `lua/plugins/linting.lua`

```lua
-- lua/plugins/linting.lua
return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      -- Trigger linting on these events
      events = { "BufWritePost", "BufReadPost", "InsertLeave" },

      linters_by_ft = {
        sh       = { "shellcheck" },
        bash     = { "shellcheck" },
        python   = { "ruff" },        -- ruff also runs as LSP; belt+suspenders
        go       = { "golangcilint" },
        terraform     = { "tflint" },
        ["yaml.github"] = { "actionlint", "zizmor" },
        -- yamlls handles plain YAML diagnostics via LSP
      },

      linters = {
        shellcheck = {
          args = { "--severity=warning", "--shell=bash" },
        },
        golangcilint = {
          -- golangci-lint reads .golangci.yaml from project root automatically
          args = {
            "run",
            "--output.formats.text.path=stderr",
            "--issues-exit-code=1",
          },
        },
        tflint = {
          -- tflint reads .tflint.hcl from project root
          args = { "--format", "compact" },
        },
        zizmor = {
          -- zizmor reads .zizmor.yaml from project root if present
          args = { "--format", "plain", "--no-progress" },
        },
      },
    },
  },
}
```

---

## 8. Integrations: `lua/plugins/integrations.lua`

```lua
-- lua/plugins/integrations.lua
return {

  -- ── lazygit.nvim ─────────────────────────────────────────────────────────
  -- <leader>gg opens lazygit in a floating window.
  -- Closing lazygit returns focus to Neovim.
  -- Your shell `gl` alias still works outside Neovim.
  {
    "kdheepak/lazygit.nvim",
    cmd = "LazyGit",
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
    },
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  -- ── vim-tmux-navigator ───────────────────────────────────────────────────
  -- Ctrl+H/J/K/L moves between Neovim splits AND tmux panes transparently.
  -- Requires the corresponding tmux plugin (see tmux config below).
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft", "TmuxNavigateDown",
      "TmuxNavigateUp",   "TmuxNavigateRight",
    },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  desc = "Navigate left" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>",  desc = "Navigate down" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>",    desc = "Navigate up" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right" },
    },
  },

  -- ── direnv.nvim ──────────────────────────────────────────────────────────
  -- Reloads .envrc when Neovim's working directory changes, so LSP servers
  -- (gopls, ty, terraform-ls) see the correct environment variables.
  {
    "direnv/direnv.vim",
    lazy = false,   -- must load early so env is set before LSP starts
  },

  -- ── fzf-lua ──────────────────────────────────────────────────────────────
  -- Replaces Telescope. Uses your existing fzf binary.
  -- Keybinds mirror the shell aliases: ff=find file, fs=find string.
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>ff", "<cmd>FzfLua files<cr>",       desc = "Find files" },
      { "<leader>fg", "<cmd>FzfLua live_grep<cr>",   desc = "Live grep" },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>",     desc = "Buffers" },
      { "<leader>fh", "<cmd>FzfLua help_tags<cr>",   desc = "Help tags" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<cr>",    desc = "Recent files" },
      { "<leader>fc", "<cmd>FzfLua commands<cr>",    desc = "Commands" },
      { "<leader>fd", "<cmd>FzfLua diagnostics_document<cr>", desc = "Diagnostics" },
      { "<leader>fs", "<cmd>FzfLua grep_cword<cr>",  desc = "Find word under cursor" },
    },
    opts = {
      winopts = {
        height = 0.4,
        width  = 1.0,
        row    = 1.0,   -- open at bottom (mirrors fzf in shell)
      },
    },
  },

  -- ── gitsigns.nvim ────────────────────────────────────────────────────────
  -- Git diff in gutter. Stage/unstage hunks from within Neovim.
  -- Complements lazygit: use gitsigns for quick hunk ops, lazygit for
  -- full interactive staging + rebase.
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "" },
        topdelete    = { text = "" },
        changedelete = { text = "▎" },
      },
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns
        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end
        -- Navigation
        map("n", "]h", gs.next_hunk,    "Next hunk")
        map("n", "[h", gs.prev_hunk,    "Prev hunk")
        -- Actions
        map("n", "<leader>hs", gs.stage_hunk,   "Stage hunk")
        map("n", "<leader>hr", gs.reset_hunk,   "Reset hunk")
        map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
        map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>hd", gs.diffthis, "Diff this")
      end,
    },
  },

  -- ── which-key.nvim ───────────────────────────────────────────────────────
  -- Shows available keybinds when you pause after a leader prefix.
  -- LazyVim includes this; add group labels for custom bindings.
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>h", group = "git hunks" },
        { "<leader>f", group = "find (fzf)" },
      },
    },
  },

}
```

---

## 9. tmux: add vim-tmux-navigator plugin

Add to `~/.tmux.conf` (appends to the config from `dotfiles-setup.md`):

```conf
# vim-tmux-navigator — seamless Neovim split <-> tmux pane navigation
# These bindings are handled by the Neovim plugin on the Neovim side;
# tmux needs corresponding bindings for when focus is in a tmux pane.
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"

bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'
```

This makes `Ctrl+H/J/K/L` move between tmux panes when outside Neovim
and between Neovim splits when inside — no mode switch, no prefix key.
Note that `Ctrl+L` (clear screen) is lost in tmux panes; use
`Ctrl+A` `Ctrl+L` instead, or `clear` explicitly.

---

## 10. Keybinds reference — Neovim layer

This extends the full-stack keybinding table in `dotfiles-opencode-critique.md`.

### Leader key: `Space`

LazyVim uses Space as leader. All custom bindings follow its convention.

| Keys | Action |
|------|--------|
| `Space ff` | Find files (fzf) |
| `Space fg` | Live grep (fzf) |
| `Space fb` | Buffers (fzf) |
| `Space fr` | Recent files (fzf) |
| `Space fd` | Document diagnostics |
| `Space gg` | Open lazygit |
| `Space hs` | Stage hunk (gitsigns) |
| `Space hr` | Reset hunk |
| `Space hp` | Preview hunk |
| `Space hb` | Git blame line |
| `Space cm` | Open Mason |
| `Space cf` | Format file/selection |
| `]h` / `[h` | Next / prev git hunk |
| `]d` / `[d` | Next / prev diagnostic |
| `gd` | Go to definition |
| `gr` | Find references |
| `K` | Hover documentation |
| `Space ca` | Code actions |
| `Space cr` | Rename symbol |

### tmux navigator (cross-tool)

| Keys | Action |
|------|--------|
| `Ctrl+H/J/K/L` | Move between Neovim splits and tmux panes |

---

## 11. Verification

```bash
# Open Neovim and check LSP health
nvim
:checkhealth vim.lsp     # check LSP server status
:Mason                   # verify all ensure_installed tools are present
:LspInfo                 # show active servers for current buffer

# Open a Python file and verify
nvim example.py
# Expect: ty + ruff both listed in :LspInfo
# Expect: type errors from ty, lint warnings from ruff

# Open a workflow file and verify
nvim .github/workflows/ci.yml
# Expect: gh_actions_ls in :LspInfo (not yamlls)
# Expect: completions for 'on:', 'jobs:', 'uses:', expression syntax

# Open a plain YAML file and verify
nvim config.yaml
# Expect: yamlls in :LspInfo (not gh_actions_ls)
```

---

## 12. Notes on ty beta status

ty is officially in beta as of April 2026. Astral recommends it for
motivated users and uses it in their own projects (uv, ruff). Known
gaps vs pyright at beta:

- Some advanced type narrowing edge cases may differ
- Stub coverage is actively growing
- Report bugs at https://github.com/astral-sh/ty/issues

If you hit consistent false positives or missing features on a specific
repo, the fallback is straightforward: set `vim.g.lazyvim_python_lsp = "basedpyright"` and uninstall ty via `uv tool uninstall ty`. The rest of the
config (ruff, conform, nvim-lint) is unaffected.
