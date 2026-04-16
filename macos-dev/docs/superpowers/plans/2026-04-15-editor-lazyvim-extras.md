# Editor — Aggressive LazyVim Adoption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse the current custom Neovim plugin scaffolding down to an omerxx-style minimal-override layout on top of LazyVim, committing to `lazyvim.json` as the single source of truth for the Extras manifest. Retain only the overrides that encode user-specific invariants (ty/ruff, shfmt flags, gh_actions_ls, hardtime/precognition training wheels).

**Architecture:** LazyVim is the distribution; `lazyvim.json` lists the adopted Extras; per-language `plugins/<lang>.lua` files carry narrow overrides only. Custom plugin-spec files for formatting, linting, and integrations are retired wholesale; their load-bearing bits are re-homed into language-scoped override files. The lockfile is tracked.

**Tech Stack:** Neovim 0.10+, LazyVim, lazy.nvim, `lazyvim.json` manifest, Lua, conform.nvim + nvim-lint (via LazyVim defaults, narrowly overridden).

**Spec reference:** `docs/design/editor-neovim.md` (minor amendments expected — this plan supersedes most of that doc's implementation notes; design intent is preserved).

**Platform scope:** macOS (primary), Linux/WSL (CI + fallback dev). No OS-specific branches.

**Prerequisite:** Plan 10 shipped (current state). User confirms this is first-run on the new Mac and they have no muscle memory yet on any custom keymaps that would be lost.

---

## 1. Three-way comparison — diagnosis and rationale

The single most important insight from surveying omerxx's config: **LazyVim is near-complete on its own**. Omerxx ships ~770 total lines across the whole `nvim/` tree, most of which is a no-op `example.lua` file. The active code fits on one screen. Our current config ships ~400 lines of custom plugin specs that duplicate what Extras already provide.

### 1a. Summary table

| Area | Current (ours) | omerxx | Proposed (aggressive) |
|---|---|---|---|
| **Bootstrap** | LazyVim starter, verbatim | LazyVim starter, verbatim | LazyVim starter, verbatim — unchanged |
| **Extras manifest** | None; imports via `lazy.lua` (0 Extras) | `lazyvim.json` with 12 Extras | `lazyvim.json` with **13 Extras** (see §1b) |
| **Plugin files** | 5 files, ~250 lines (`formatting`, `integrations`, `learning`, `linting`, `lsp`) | 5 files, ~320 lines (one is no-op `example.lua`) | **6 files**, ~150 lines (`go`, `python`, `bash`, `ghactions`, `yaml`, `json`, `learning`, `tmux-nav`, `direnv`, `opencode?`) |
| **options.lua** | 25 lines (much of it LazyVim defaults) | 4 lines | **~3 lines** (only `colorcolumn="120"`, `scrolloff=8`, and anything else that disagrees with LazyVim default) |
| **keymaps.lua** | Empty | 2 lines (`jj`/`jk` → Esc) | **2 lines** (`jj`/`jk` → Esc, per user muscle-memory request) |
| **autocmds.lua** | 34 lines (gh-actions filetype, VimResized, trim whitespace) | Empty | **~14 lines** (keep gh-actions filetype detection only — load-bearing for `gh_actions_ls`; drop VimResized (LazyVim provides), drop trim-whitespace (conform covers it for most fts)) |
| **Colorscheme** | LazyVim default (tokyonight) | LazyVim default (tokyonight — omerxx does not override) | LazyVim default |
| **Fuzzy finder** | `ibhagwan/fzf-lua` as primary spec, 9 custom `<leader>f*` keymaps | LazyVim default Telescope | **`editor.fzf` Extra** + preserve the 9 `<leader>f*` keymap overrides (user has muscle memory per stated preferences; `<leader>fz` → zoxide is load-bearing via Layer 1c) |
| **Python LSP** | `ty` via `vim.g.lazyvim_python_lsp = "ty"` + custom `ruff` init options | No Python | **`lang.python` Extra** + retain `vim.g.lazyvim_python_lsp = "ty"` (Extra honours this var; pyright/basedpyright get auto-disabled) |
| **Python formatter** | `ruff_fix`, `ruff_format` via conform | Default | `lang.python` Extra's ruff config + `vim.g.lazyvim_python_formatter = "ruff"` (as today) |
| **Go** | Custom `gopls` settings in `lsp.lua`: `analyses={unusedparams,shadow}, staticcheck, gofumpt, hints={parameterNames,assignVariableTypes}` | `lang.go` Extra + custom `plugins/go.lua` with: `unusedparams, staticcheck, usePlaceholders, completeUnimported, gofumpt` | **`lang.go` Extra** + `plugins/go.lua` with the union of both: `analyses={unusedparams,shadow}, staticcheck, gofumpt, usePlaceholders, completeUnimported, hints={parameterNames,assignVariableTypes}` |
| **YAML LSP** | `yamlls` with disabled schemaStore + kustomization schema only | `lang.yaml` Extra (with schemastore.nvim auto-inject enabled) | **`lang.yaml` Extra, defaults accepted** — schemastore.nvim auto-injects schemas for common YAML filetypes (dependabot, docker-compose, pre-commit, helm charts, etc.); kustomization resolves via the shipped schema set too. Previous "disabled" invariant dropped as undocumented. |
| **YAML formatter** | `prettier` via conform | `yamlfmt` via conform (K8s-friendly) | **`yamlfmt` via conform** (adopt omerxx pattern — strictly better for K8s manifests) |
| **JSON LSP** | `jsonls` with disabled schemaStore | `lang.json` Extra (with schemastore auto-inject) | **`lang.json` Extra, defaults accepted** — schema-aware completion on package.json, tsconfig.json, workflow JSONs, etc. Same rationale as YAML. |
| **Bash LSP** | `bashls` with `shellcheckPath` + `shfmt` path/indent/caseIndentation | No bash config | **`plugins/bash.lua`** retains all bash LSP overrides (no LazyVim Extra for bash exists) |
| **Bash formatter** | `shfmt` with `-i 2 -ci -bn` via conform | No bash | **`plugins/bash.lua`** retains `shfmt` conform override |
| **Bash linter** | `shellcheck --severity=warning --shell=bash` via nvim-lint | No bash | **`plugins/bash.lua`** retains `shellcheck` nvim-lint override |
| **Terraform** | `terraformls = {}` in lsp.lua + `tflint` linter + `terraform_fmt` formatter | `lang.terraform` Extra | **`lang.terraform` Extra** (provides terraformls, tflint via mason, terraform_fmt via conform) — retire all three custom entries |
| **Docker** | None | `lang.docker` Extra | **`lang.docker` Extra** (dockerls, compose-ls, Dockerfile treesitter) |
| **Helm** | None | `lang.helm` Extra | **`lang.helm` Extra** (helm_ls, yamlls auto-registered for `*.tpl`) |
| **Markdown** | `prettier` formatter + `markdownlint-cli2` linter via custom specs | `lang.markdown` Extra | **`lang.markdown` Extra** (markdown-preview, marksman LSP, cmp-markdown-aware) — retire custom formatter/linter entries |
| **GitHub Actions** | `gh_actions_ls` + `actionlint` + `zizmor` + `yaml.github` filetype | None | **`plugins/ghactions.lua`** retains all (no Extra covers this niche) |
| **TypeScript** | None | `lang.typescript` Extra | **SKIP** — user's stack is shell/Go/Python/Terraform/YAML/K8s |
| **Docker + K8s stack** | None | docker + helm + yaml | **Adopt all three** — matches user's containerised workflow |
| **mini.surround** | None | `coding.mini-surround` Extra + custom keymap overrides | **`coding.mini-surround` Extra** + omerxx's keymap override block verbatim (`sa`/`sd`/`sr`/`gsf`/etc.) |
| **Harpoon** | None | `editor.harpoon2` Extra | **`editor.harpoon2` Extra** — quick-file jumping is a well-established productivity win, and user hasn't adopted anything else yet |
| **DAP (debug)** | None | `dap.core` Extra (and `lang.go` layers dap-go on top) | **`dap.core` Extra** — Go debugging becomes one-keystroke |
| **mini.files vs neo-tree** | None (LazyVim default neo-tree) | `editor.mini-files` Extra | **SKIP** — stick with LazyVim default neo-tree; mini-files is a preference, not a win |
| **Surround (non-mini)** | None | mini.surround via Extra | Via `coding.mini-surround` Extra (above) |
| **LazyGit** | `kdheepak/lazygit.nvim` custom spec + `<leader>gg` keymap | LazyVim default | **LazyVim default** — retire custom spec; `<leader>gg` is already the default |
| **Gitsigns** | Custom `gitsigns.nvim` spec with 8 `<leader>h*` keymaps + `]h`/`[h` nav | LazyVim default | **LazyVim default + narrow keymap override** — LazyVim's gitsigns defaults cover most; keep only the keymaps that differ |
| **Which-key groups** | Custom `<leader>h = git hunks`, `<leader>f = find (fzf)` labels | LazyVim default | **LazyVim default** — let Extras register their own groups; retire custom |
| **tmux integration** | `christoomey/vim-tmux-navigator` + `<C-h/j/k/l>` keymaps | None | **`plugins/tmux-nav.lua`** — retain wholesale (Layer 1b-ii tmux config depends on matching `<C-hjkl>` semantics on both sides) |
| **direnv** | `direnv/direnv.vim` loaded eagerly | None | **`plugins/direnv.lua`** — retain (user uses direnv in project trees) |
| **Learning plugins** | `hardtime.nvim` + `precognition.nvim` + `vim-be-good` | None | **`plugins/learning.lua`** — retain unchanged (no Extra exists; high training value) |
| **AI integration** | None | `opencode.nvim` with 10 `<leader>o*` keymaps | **`plugins/opencode.lua`** — adopt omerxx's version verbatim (user's CLI is opencode; in-editor integration is a direct upgrade; no LazyVim Extra exists) |
| **Lockfile** | `nvim/lazy-lock.json` not tracked | Tracked | **Tracked** |
| **Custom plugin files to delete** | N/A | N/A | **Delete: `formatting.lua`, `linting.lua`, `integrations.lua`, `lsp.lua`** (wholesale — content re-homed into language-scoped files) |

### 1b. Final Extras list (13)

Ordered by purpose:

```json
{
  "extras": [
    "lazyvim.plugins.extras.coding.mini-surround",
    "lazyvim.plugins.extras.dap.core",
    "lazyvim.plugins.extras.editor.fzf",
    "lazyvim.plugins.extras.editor.harpoon2",
    "lazyvim.plugins.extras.lang.docker",
    "lazyvim.plugins.extras.lang.go",
    "lazyvim.plugins.extras.lang.helm",
    "lazyvim.plugins.extras.lang.json",
    "lazyvim.plugins.extras.lang.markdown",
    "lazyvim.plugins.extras.lang.python",
    "lazyvim.plugins.extras.lang.terraform",
    "lazyvim.plugins.extras.lang.yaml",
    "lazyvim.plugins.extras.lang.git"
  ],
  "install_version": 7,
  "version": 8
}
```

Versus omerxx: +`editor.fzf`, +`lang.python`, –`editor.mini-files`, –`lang.typescript`.

### 1c. Contentious decisions, explicit rationale

- **Keep `editor.fzf` rather than falling back to Telescope (omerxx's choice).** Current config has `<leader>fz` → FzfLua zoxide, which FzfLua supports natively but Telescope does not. Keeping FZF also avoids a second flavour of keymap muscle-memory break.
- **Add `lang.python` despite omerxx not using Python.** User's shell layer already pins `ty` as Python LSP; the Extra recognises `vim.g.lazyvim_python_lsp = "ty"` and wires up the rest cleanly.
- **Accept `lang.yaml`/`lang.json` Extras' default schemastore behaviour.** The current config disabled schemastore with no documented rationale; on review the "invariant" was dropped. Accepting defaults means schema-aware completion + validation on common YAML/JSON filetypes out of the box (dependabot.yml, docker-compose.yml, pre-commit, Helm Chart.yaml, package.json, tsconfig.json, etc.). If spurious warnings become annoying on specific YAML files, add a targeted per-file exclude later.
- **Retire `gitsigns` / `which-key` / `lazygit` custom specs wholesale.** LazyVim covers all three; any minor keymap differences are not worth a config file per plugin.
- **Adopt `yamlfmt` formatter (omerxx) over `prettier` (current) for YAML.** Strictly better for Kubernetes manifests (respects K8s indent conventions); prettier sometimes reformats K8s YAML in unhelpful ways.
- **Adopt `opencode.nvim`.** User ships `opencode` CLI in their shell layer already; in-editor integration is an obvious productivity win and omerxx's pattern is well-shaped.
- **Drop custom `colorcolumn="120"` if LazyVim default differs dangerously?** No — LazyVim has no colorcolumn default; keep it as an options.lua line. Minimal cost.

---

## 2. Acceptance Criteria

**AC-1: `nvim/lazy-lock.json` tracked + valid + names lazy.nvim**
```
Given: nvim/lazy-lock.json
When: inspected
Then: file is tracked by git; parses as JSON; contains key "lazy.nvim"
```

**AC-2: `nvim/lazyvim.json` declares exactly the 13 Extras listed in §1b**
```
Given: nvim/lazyvim.json
When: inspected
Then: file exists; parses as JSON; .extras contains all 13 entries (set-equality); no others
```

**AC-3: `nvim/lua/config/lazy.lua` no longer carries Extras imports (they moved to lazyvim.json)**
```
Given: nvim/lua/config/lazy.lua
When: inspected
Then: the spec array contains only `{ "LazyVim/LazyVim", import = "lazyvim.plugins" }`, `{ import = "plugins" }`, and no `{ import = "lazyvim.plugins.extras.*" }` lines
```

**AC-4: The four retired plugin files are deleted**
```
Given: nvim/lua/plugins/
When: inspected
Then: formatting.lua, linting.lua, integrations.lua, lsp.lua are all absent
```

**AC-5: `plugins/go.lua` retains the merged gopls settings**
```
Given: nvim/lua/plugins/go.lua
When: inspected
Then: gopls.settings preserves analyses.unusedparams=true, analyses.shadow=true, staticcheck=true, gofumpt=true, usePlaceholders=true, completeUnimported=true, hints.parameterNames=true, hints.assignVariableTypes=true
```

**AC-6: `plugins/python.lua` preserves ty LSP + ruff init options**
```
Given: nvim/lua/plugins/python.lua
When: inspected
Then: vim.g.lazyvim_python_lsp == "ty" (set before plugin specs);
      vim.g.lazyvim_python_formatter == "ruff";
      servers.ty has autostart=true;
      servers.ruff init_options.settings preserves fixAll=true + organizeImports=true
```

**AC-7: `plugins/bash.lua` preserves bashls + shfmt + shellcheck overrides**
```
Given: nvim/lua/plugins/bash.lua
When: inspected
Then: servers.bashls.settings.bashIde preserves shellcheckPath="shellcheck", shfmt.indentationSize=2, shfmt.caseIndentation=true;
      conform override: formatters.shfmt.prepend_args == {"-i","2","-ci","-bn"};
      nvim-lint override: linters.shellcheck.args == {"--severity=warning","--shell=bash"}
```

**AC-8: `plugins/ghactions.lua` preserves gh_actions_ls + actionlint + zizmor**
```
Given: nvim/lua/plugins/ghactions.lua
When: inspected
Then: servers.gh_actions_ls exists with filetypes={"yaml.github"};
      nvim-lint linters_by_ft["yaml.github"] includes "actionlint" and "zizmor";
      linters.zizmor.args preserves {"--format","plain","--no-progress"}
```

**AC-9: `plugins/yaml.lua` adds yamlfmt as the YAML formatter (conform override only; no LSP override)**
```
Given: nvim/lua/plugins/yaml.lua
When: inspected
Then: file declares a conform override with formatters_by_ft.yaml == {"yamlfmt"};
      formatters.yamlfmt.args includes "-formatter" "basic" "-indentless_arrays=true";
      file does NOT declare any nvim-lspconfig override (yamlls defaults from lang.yaml Extra accepted as-is)
```

**AC-10: no `plugins/json.lua` file exists (lang.json Extra defaults accepted)**
```
Given: nvim/lua/plugins/
When: inspected
Then: json.lua does NOT exist
```

**AC-11: `plugins/learning.lua` unchanged**
```
Given: nvim/lua/plugins/learning.lua
When: diffed against pre-migration state
Then: zero lines changed; declares hardtime.nvim, precognition.nvim, vim-be-good
```

**AC-12: `plugins/tmux-nav.lua` and `plugins/direnv.lua` exist and carry the prior-integrations.lua semantics**
```
Given: nvim/lua/plugins/tmux-nav.lua and nvim/lua/plugins/direnv.lua
When: inspected
Then: tmux-nav.lua declares vim-tmux-navigator with <C-h/j/k/l> keymaps;
      direnv.lua declares direnv.vim with lazy = false
```

**AC-13: `plugins/opencode.lua` adopted from omerxx (AI integration)**
```
Given: nvim/lua/plugins/opencode.lua
When: inspected
Then: declares NickvanDyke/opencode.nvim;
      declares 10 <leader>o* keymaps (ot/oa/o+/oe/on/os) per omerxx's spec
```

**AC-13b: `plugins/octo.lua` provides in-editor GitHub PR/Issue review**
```
Given: nvim/lua/plugins/octo.lua
When: inspected
Then: declares pwntester/octo.nvim;
      file has ≤ 25 lines (minimal spec — octo ships sane defaults)
```

**AC-14: `config/options.lua` trimmed to non-default entries only**
```
Given: nvim/lua/config/options.lua
When: inspected (stripped of comments and blank lines)
Then: total non-comment/non-blank lines ≤ 5;
      contains `colorcolumn = "120"`;
      contains `scrolloff = 8`
```

**AC-15: `config/keymaps.lua` declares `jj` and `jk` → Esc**
```
Given: nvim/lua/config/keymaps.lua
When: inspected (stripped of comments)
Then: contains an insert-mode mapping `jj` → `<Esc>`;
      contains an insert-mode mapping `jk` → `<Esc>`;
      no other non-trivial mappings
```

**AC-16: `config/autocmds.lua` preserves only the load-bearing gh-actions filetype detection**
```
Given: nvim/lua/config/autocmds.lua
When: inspected
Then: vim.filetype.add block exists with the yaml.github patterns (workflows + action.yml);
      vim.treesitter.language.register('yaml', 'yaml.github') exists;
      NO VimResized autocmd (LazyVim covers);
      NO strip-whitespace autocmd (conform covers)
```

**AC-17: End-to-end — `bash scripts/test-plan10.sh` exits 0 with all ACs green**
```
When: `bash scripts/test-plan10.sh` runs on macOS or Linux
Then: every AC above is checked;
      exit code is 0 if fail == 0, 1 otherwise
```

---

## 3. File Structure

**New files:**
- `nvim/lazyvim.json` — Extras manifest (13 entries)
- `nvim/lazy-lock.json` — lockfile
- `nvim/lua/plugins/go.lua` — merged gopls settings override
- `nvim/lua/plugins/python.lua` — ty + ruff overrides, vim.g settings
- `nvim/lua/plugins/bash.lua` — bashls + shfmt + shellcheck overrides
- `nvim/lua/plugins/ghactions.lua` — gh_actions_ls + actionlint + zizmor overrides
- `nvim/lua/plugins/yaml.lua` — yamlfmt formatter override (no LSP override; lang.yaml Extra defaults accepted)
- `nvim/lua/plugins/tmux-nav.lua` — vim-tmux-navigator spec
- `nvim/lua/plugins/direnv.lua` — direnv.vim spec
- `nvim/lua/plugins/opencode.lua` — AI integration (omerxx pattern, verbatim)
- `nvim/lua/plugins/octo.lua` — GitHub PR/Issue review inside nvim via `gh` CLI

**Modified files:**
- `nvim/lua/config/lazy.lua` — simplify spec array (remove Extras imports; they move to lazyvim.json)
- `nvim/lua/config/options.lua` — trim to ~3 non-default lines
- `nvim/lua/config/keymaps.lua` — trim (likely empty or 2-line)
- `nvim/lua/config/autocmds.lua` — trim to gh-actions filetype detection only
- `nvim/lua/plugins/learning.lua` — unchanged
- `scripts/test-plan10.sh` — rewritten to assert the aggressive target state

**Deleted files:**
- `nvim/lua/plugins/formatting.lua` (global conform spec; narrow overrides move into per-language plugin files)
- `nvim/lua/plugins/linting.lua` (global nvim-lint spec; narrow overrides move into per-language plugin files)
- `nvim/lua/plugins/integrations.lua` (fzf-lua + lazygit + gitsigns + which-key + tmux-nav + direnv; each re-homed or retired)
- `nvim/lua/plugins/lsp.lua` (monolithic LSP spec; server-specific settings re-homed into per-language plugin files)

**Untouched:**
- `nvim/init.lua`
- `nvim/lua/config/lazy.lua` bootstrap structure (just the spec array simplifies)
- `install-macos.sh` / `install-wsl.sh` (symlink already in place)
- `Brewfile` / `tools.txt` (no new tools — yamlfmt is a Go binary, needs adding to Brewfile; see Task 5)
- `.github/workflows/verify.yml` (test-plan10.sh already wired)

---

## 4. Tasks

### Task 0: Commit `lazyvim.json` + `lazy-lock.json`, rewrite `test-plan10.sh` for the new target

Before any plugin-file restructuring, commit the Extras manifest and lockfile, and replace `test-plan10.sh` with the AC-1..AC-17 assertions. The old tests that asserted against the current monolithic structure are deleted in this task — so subsequent tasks run against the new assertion set.

**Files:**
- Create: `nvim/lazyvim.json`
- Create: `nvim/lazy-lock.json`
- Rewrite: `scripts/test-plan10.sh`

- [ ] **Step 1: Create `nvim/lazyvim.json` with the 13 Extras**

```json
{
  "extras": [
    "lazyvim.plugins.extras.coding.mini-surround",
    "lazyvim.plugins.extras.dap.core",
    "lazyvim.plugins.extras.editor.fzf",
    "lazyvim.plugins.extras.editor.harpoon2",
    "lazyvim.plugins.extras.lang.docker",
    "lazyvim.plugins.extras.lang.go",
    "lazyvim.plugins.extras.lang.helm",
    "lazyvim.plugins.extras.lang.json",
    "lazyvim.plugins.extras.lang.markdown",
    "lazyvim.plugins.extras.lang.python",
    "lazyvim.plugins.extras.lang.terraform",
    "lazyvim.plugins.extras.lang.yaml",
    "lazyvim.plugins.extras.lang.git"
  ],
  "install_version": 7,
  "version": 8
}
```

Validate: `python3 -c "import json; d = json.load(open('nvim/lazyvim.json')); assert len(d['extras']) == 12"` — exit 0.

- [ ] **Step 2: Generate `nvim/lazy-lock.json` on the target machine**

From macOS or Linux with nvim installed:

```bash
cd macos-dev/nvim
nvim --headless "+Lazy! sync" +qa
cp ~/.config/nvim/lazy-lock.json macos-dev/nvim/lazy-lock.json
```

Or (if config is not yet symlinked and fresh):

```bash
nvim --headless -u nvim/init.lua "+Lazy! sync" +qa
```

Expected: lockfile written with ~100+ plugins (LazyVim core + 12 Extras + all custom plugin files' deps).

- [ ] **Step 3: Rewrite `scripts/test-plan10.sh` to test the target state**

Completely replace the existing test-plan10.sh. Keep the preamble (lines 1–55 are identical to `test-plan-layer1a.sh` pattern). Replace everything after with AC-1..AC-17 blocks. See Appendix A at the bottom of this plan for the full target content of test-plan10.sh.

- [ ] **Step 4: Run test-plan10.sh — expected state**

```bash
bash macos-dev/scripts/test-plan10.sh
```

Expected: AC-1, AC-2 pass (lazy-lock.json + lazyvim.json exist). Many other ACs fail — they assert plugin files that don't exist yet. That's intentional — subsequent tasks are the TDD red→green cycle.

Fail count at this point: ~10 failed ACs. This is the baseline.

- [ ] **Step 5: Shellcheck**

```bash
shellcheck macos-dev/scripts/test-plan10.sh
```
Expected: silent.

- [ ] **Step 6: Commit**

```bash
git add macos-dev/nvim/lazyvim.json macos-dev/nvim/lazy-lock.json macos-dev/scripts/test-plan10.sh
git commit -m "test(nvim): commit lazyvim.json + lazy-lock.json, rewrite test-plan10 for aggressive LazyVim adoption"
```

---

### Task 1: Simplify `config/lazy.lua` — remove any Extras imports (migration to lazyvim.json)

The Extras manifest is now `lazyvim.json`. `lazy.lua` keeps only the two base imports.

**Files:**
- Modify: `nvim/lua/config/lazy.lua`

- [ ] **Step 1: Edit `config/lazy.lua`'s spec array**

Confirm current state:
```lua
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
```

If any `{ import = "lazyvim.plugins.extras.*" }` lines got added during exploration, remove them — the Extras are now resolved from lazyvim.json automatically.

- [ ] **Step 2: Run test-plan10 — AC-3 passes**

```bash
bash macos-dev/scripts/test-plan10.sh
```

Expected: AC-3 passes. Other ACs still fail.

- [ ] **Step 3: Commit**

```bash
git add macos-dev/nvim/lua/config/lazy.lua
git commit -m "refactor(nvim): keep Extras in lazyvim.json; simplify lazy.lua spec"
```

---

### Task 2: Delete the four retired plugin files

Wholesale delete. Their content will be re-homed into per-language files in subsequent tasks; the lockfile already captured the Extras' transitive deps so nothing breaks at load.

**Files:**
- Delete: `nvim/lua/plugins/formatting.lua`
- Delete: `nvim/lua/plugins/linting.lua`
- Delete: `nvim/lua/plugins/integrations.lua`
- Delete: `nvim/lua/plugins/lsp.lua`

- [ ] **Step 1: Delete the four files**

```bash
rm macos-dev/nvim/lua/plugins/{formatting,linting,integrations,lsp}.lua
```

- [ ] **Step 2: Smoke-test nvim boots**

```bash
nvim --headless +checkhealth +qa 2>&1 | tail -30
```

Expected: no errors; LazyVim reports all plugins loaded via Extras.

Some things WILL break at runtime until Tasks 3–9 are complete (e.g., gopls has no custom settings, bashls has no shellcheck config, fzf keymaps missing). That's expected — the new per-language files will restore them.

- [ ] **Step 3: Run test-plan10 — AC-4 passes**

Expected: AC-4 passes. Many ACs (5, 6, 7, 8, 9, 10, 12, 13) still fail.

- [ ] **Step 4: Commit**

```bash
git add -A macos-dev/nvim/lua/plugins/
git commit -m "refactor(nvim): delete monolithic plugin files (content re-homed per-language)"
```

(`-A` is acceptable here because we're explicitly deleting files in this directory and nothing else has changed under `macos-dev/nvim/lua/plugins/`.)

---

### Task 3: Create `plugins/go.lua` (merged gopls settings)

**Files:**
- Create: `nvim/lua/plugins/go.lua`

- [ ] **Step 1: Create `nvim/lua/plugins/go.lua`**

```lua
-- plugins/go.lua — Go language overrides.
-- Layers on top of lazyvim.plugins.extras.lang.go.

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.gopls = vim.tbl_deep_extend("force", opts.servers.gopls or {}, {
        settings = {
          gopls = {
            analyses = {
              unusedparams = true,
              shadow = true,
            },
            staticcheck = true,
            usePlaceholders = true,
            completeUnimported = true,
            gofumpt = true,
            hints = {
              parameterNames = true,
              assignVariableTypes = true,
            },
          },
        },
      })
      return opts
    end,
  },
}
```

- [ ] **Step 2: Run test-plan10 — AC-5 passes**

- [ ] **Step 3: Smoke-test on a `.go` file**

Open any Go file in nvim, run `:LspInfo`, confirm gopls is attached and `:GoStatsCov` / hovers surface the hint annotations.

- [ ] **Step 4: Commit**

```bash
git add macos-dev/nvim/lua/plugins/go.lua
git commit -m "feat(nvim): add plugins/go.lua with merged gopls settings (override)"
```

---

### Task 4: Create `plugins/python.lua` (ty + ruff overrides)

**Files:**
- Create: `nvim/lua/plugins/python.lua`

- [ ] **Step 1: Create `nvim/lua/plugins/python.lua`**

```lua
-- plugins/python.lua — Python language overrides.
-- Layers on top of lazyvim.plugins.extras.lang.python.
--
-- The Extra honours vim.g.lazyvim_python_lsp — setting it to "ty"
-- disables pyright/basedpyright and enables the ty LSP (astral-sh's
-- new Python LSP, installed via uv tool, NOT via Mason).

vim.g.lazyvim_python_lsp = "ty"
vim.g.lazyvim_python_formatter = "ruff"

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.ty = vim.tbl_deep_extend("force", opts.servers.ty or {}, {
        enabled = true,
        autostart = true,
      })
      opts.servers.ruff = vim.tbl_deep_extend("force", opts.servers.ruff or {}, {
        enabled = true,
        autostart = true,
        init_options = {
          settings = {
            fixAll = true,
            organizeImports = true,
          },
        },
      })
      return opts
    end,
  },
}
```

- [ ] **Step 2: Run test-plan10 — AC-6 passes**

- [ ] **Step 3: Smoke-test on a `.py` file**

Confirm `:LspInfo` shows ty + ruff attached; pyright NOT running.

- [ ] **Step 4: Commit**

```bash
git add macos-dev/nvim/lua/plugins/python.lua
git commit -m "feat(nvim): add plugins/python.lua with ty + ruff overrides"
```

---

### Task 5: Create `plugins/bash.lua` (bashls + shfmt + shellcheck) and add yamlfmt to Brewfile

bashls has no Extra; shellcheck linter and shfmt formatter need their overrides re-homed. Also adds `yamlfmt` to Brewfile — it's a new tool dependency for Task 7.

**Files:**
- Create: `nvim/lua/plugins/bash.lua`
- Modify: `Brewfile`
- Modify: `tools.txt`

- [ ] **Step 1: Add yamlfmt to Brewfile**

Append to the "Desktop · keyboard" section or create a new "Editor" section (pick by the existing-file convention):

```ruby

# yamlfmt — Google's K8s-friendly YAML formatter (used by nvim via conform)
brew "google/yamlfmt/yamlfmt"
```

And add the tap if not already present:

```ruby
tap "google/yamlfmt"
```

- [ ] **Step 2: Add yamlfmt row to tools.txt**

Under the Editor/Neovim section (match existing column alignment):

```
yamlfmt              brew:google/yamlfmt/yamlfmt    apt:-                   apk:-
```

- [ ] **Step 3: Create `nvim/lua/plugins/bash.lua`**

```lua
-- plugins/bash.lua — Bash / POSIX shell overrides.
-- No LazyVim Extra exists for bash; this file owns the entire bash
-- tooling stack (LSP, formatter, linter).

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.bashls = vim.tbl_deep_extend("force", opts.servers.bashls or {}, {
        settings = {
          bashIde = {
            shellcheckPath = "shellcheck",
            shellcheckArguments = "--severity=warning",
            shfmt = {
              path = "shfmt",
              indentationSize = 2,
              caseIndentation = true,
            },
          },
        },
      })
      return opts
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        sh = { "shfmt" },
        bash = { "shfmt" },
      },
      formatters = {
        shfmt = { prepend_args = { "-i", "2", "-ci", "-bn" } },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        sh = { "shellcheck" },
        bash = { "shellcheck" },
      },
      linters = {
        shellcheck = { args = { "--severity=warning", "--shell=bash" } },
      },
    },
  },
}
```

- [ ] **Step 4: Run test-plan10 — AC-7 passes**

- [ ] **Step 5: Commit**

```bash
git add macos-dev/Brewfile macos-dev/tools.txt macos-dev/nvim/lua/plugins/bash.lua
git commit -m "feat(nvim): add plugins/bash.lua; add yamlfmt to Brewfile + tools.txt"
```

---

### Task 6: Create `plugins/ghactions.lua` (gh_actions_ls + actionlint + zizmor)

**Files:**
- Create: `nvim/lua/plugins/ghactions.lua`

- [ ] **Step 1: Create `nvim/lua/plugins/ghactions.lua`**

```lua
-- plugins/ghactions.lua — GitHub Actions tooling.
-- No LazyVim Extra covers this niche. yaml.github filetype is
-- registered in config/autocmds.lua (load-bearing).

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.gh_actions_ls = vim.tbl_deep_extend("force", opts.servers.gh_actions_ls or {}, {
        filetypes = { "yaml.github" },
        root_dir = function(fname)
          return vim.fs.root(fname, ".git")
        end,
      })
      return opts
    end,
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        ["yaml.github"] = { "actionlint", "zizmor" },
      },
      linters = {
        zizmor = { args = { "--format", "plain", "--no-progress" } },
      },
    },
  },
}
```

- [ ] **Step 2: Run test-plan10 — AC-8 passes**

- [ ] **Step 3: Smoke-test**

Open `.github/workflows/verify.yml` — confirm filetype shows `yaml.github` (via `:set ft?`), gh_actions_ls attaches, actionlint + zizmor run on save.

- [ ] **Step 4: Commit**

```bash
git add macos-dev/nvim/lua/plugins/ghactions.lua
git commit -m "feat(nvim): add plugins/ghactions.lua (gh_actions_ls + actionlint + zizmor)"
```

---

### Task 7: Create `plugins/yaml.lua` (yamlfmt formatter only)

**Files:**
- Create: `nvim/lua/plugins/yaml.lua`

- [ ] **Step 1: Create `nvim/lua/plugins/yaml.lua`**

```lua
-- plugins/yaml.lua — YAML overrides on top of lazyvim.plugins.extras.lang.yaml.
--
-- lang.yaml Extra's yamlls defaults (including schemastore.nvim auto-inject
-- for common YAML filetypes) are accepted as-is. This file only replaces
-- the default YAML formatter (prettier) with yamlfmt, which produces
-- K8s-friendly output that respects existing indentation conventions.

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        yaml = { "yamlfmt" },
      },
      formatters = {
        yamlfmt = {
          command = "yamlfmt",
          args = { "-formatter", "basic", "-indentless_arrays=true" },
        },
      },
    },
  },
}
```

- [ ] **Step 2: Run test-plan10 — AC-9 passes (and AC-10 passes by absence of json.lua)**

- [ ] **Step 3: Smoke-test**

Open `.github/dependabot.yml` or `docker-compose.yml` — confirm schema-driven completion surfaces (schemastore.nvim working via lang.yaml Extra defaults). Save a YAML file and confirm yamlfmt runs (output respects existing indent style; arrays are NOT re-indented with leading spaces).

- [ ] **Step 4: Commit**

```bash
git add macos-dev/nvim/lua/plugins/yaml.lua
git commit -m "feat(nvim): add plugins/yaml.lua with yamlfmt formatter override"
```

---

### Task 8: Create `plugins/tmux-nav.lua`, `plugins/direnv.lua`, `plugins/opencode.lua`, and `plugins/octo.lua`

Re-home the last three `integrations.lua` entries into their own dedicated files, and adopt omerxx's opencode.nvim configuration verbatim.

**Files:**
- Create: `nvim/lua/plugins/tmux-nav.lua`
- Create: `nvim/lua/plugins/direnv.lua`
- Create: `nvim/lua/plugins/opencode.lua`

- [ ] **Step 1: Create `nvim/lua/plugins/tmux-nav.lua`**

```lua
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
```

- [ ] **Step 2: Create `nvim/lua/plugins/direnv.lua`**

```lua
-- plugins/direnv.lua — direnv integration for project-scoped env vars.

return {
  { "direnv/direnv.vim", lazy = false },
}
```

- [ ] **Step 3: Create `nvim/lua/plugins/opencode.lua`**

Copy omerxx's `nvim/lua/plugins/opencode.lua` verbatim (see §1a for the full content from the upstream fetch). The ten `<leader>o*` keymaps are preserved as omerxx declared them; adjust only if a collision with an existing LazyVim default surfaces during smoke-test.

- [ ] **Step 4: Create `nvim/lua/plugins/octo.lua`**

```lua
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
```

- [ ] **Step 5: Run test-plan10 — AC-12, AC-13, AC-13b pass**

- [ ] **Step 6: Smoke-test opencode + octo**

- `<leader>ot` toggles opencode panel (requires opencode CLI in PATH)
- `:Octo pr list` surfaces PRs from current repo (requires `gh auth` done)

- [ ] **Step 7: Commit**

```bash
git add macos-dev/nvim/lua/plugins/{tmux-nav,direnv,opencode,octo}.lua
git commit -m "feat(nvim): add tmux-nav, direnv, opencode, octo plugins"
```

---

### Task 9: Trim `config/options.lua`, `keymaps.lua`, `autocmds.lua`

Retire LazyVim-default-duplicated options; drop autocmds that LazyVim or conform already provide; preserve only the load-bearing bits.

**Files:**
- Modify: `nvim/lua/config/options.lua`
- Modify: `nvim/lua/config/keymaps.lua`
- Modify: `nvim/lua/config/autocmds.lua`

- [ ] **Step 1: Replace `nvim/lua/config/options.lua` wholesale**

```lua
-- options.lua — non-default editor options.
-- LazyVim provides sensible defaults (tabstop=2, shiftwidth=2, number,
-- relativenumber, cursorline, ignorecase, smartcase, undofile,
-- splitbelow, splitright, clipboard=unnamedplus, list, listchars, etc.)
-- Only document DIVERGENCES here.

vim.opt.colorcolumn = "120"  -- visible right margin (was 100; user preference)
vim.opt.scrolloff   = 8      -- keep 8 lines of context above/below cursor
```

- [ ] **Step 2: Replace `nvim/lua/config/keymaps.lua` wholesale**

```lua
-- keymaps.lua — user-specific keymap overrides on top of LazyVim defaults.
-- LazyVim's default keymap set is extensive; add only divergences.

vim.api.nvim_set_keymap("i", "jj", "<Esc>", { noremap = false })
vim.api.nvim_set_keymap("i", "jk", "<Esc>", { noremap = false })
```

- [ ] **Step 3: Replace `nvim/lua/config/autocmds.lua` wholesale**

```lua
-- autocmds.lua — load-bearing autocommands.
-- LazyVim covers VimResized, trim-whitespace (via conform), and most
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
```

- [ ] **Step 4: Run test-plan10 — AC-14, AC-15, AC-16 pass**

- [ ] **Step 5: Smoke-test options/autocmds**

- Confirm `colorcolumn` renders at col 120 on a long file
- Confirm `.github/workflows/*.yml` opens with filetype `yaml.github`
- Confirm gh_actions_ls attaches (it reads the filetype we registered)

- [ ] **Step 6: Commit**

```bash
git add macos-dev/nvim/lua/config/{options,keymaps,autocmds}.lua
git commit -m "refactor(nvim): trim options/keymaps/autocmds to LazyVim-divergences only"
```

---

### Task 10: Regenerate lockfile + final AC-17 gates

**Files:**
- Regenerate: `nvim/lazy-lock.json`
- Validate only — no other commits

- [ ] **Step 1: Final `:Lazy sync` on a clean install**

```bash
rm -rf ~/.local/share/nvim/lazy
rm -rf ~/.config/nvim/lazy-lock.json  # if it lingered from Task 0
# (keep the repo's lazy-lock.json; this scrub is only for the user's runtime dir)
nvim --headless "+Lazy! restore" +qa
```

`:Lazy restore` pins to the committed `lazy-lock.json` from the repo.

- [ ] **Step 2: Verify the manifest resolved correctly**

```bash
nvim --headless "+LazyExtras" +qa 2>&1 | grep -c "enabled"
```

Expected: 12 enabled Extras.

- [ ] **Step 3: Run test-plan10 — all ACs pass**

```bash
bash macos-dev/scripts/test-plan10.sh
```
Expected: 17 ACs green, exit 0.

- [ ] **Step 4: All other test-plans still pass**

```bash
cd macos-dev
for f in scripts/test-plan*.sh; do
  bash "$f" >/dev/null 2>&1 || echo "FAIL: $f"
done
```
Expected: no FAIL lines.

- [ ] **Step 5: Repo-wide shellcheck + YAML lint + Brewfile resolve**

```bash
find macos-dev -type f -name '*.sh' -not -path '*/.worktrees/*' -print0 | xargs -0 shellcheck
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/verify.yml'))"
bash macos-dev/scripts/check-brewfile-resolves.sh
```
Expected: all silent / exit 0 (includes the new `google/yamlfmt/yamlfmt` entry).

- [ ] **Step 6: Manual smoke on a real Mac**

This is the real gate. Walk the following on your actual Mac:

- `:Lazy` — 12 Extras all "loaded"; plugin count ~100 healthy
- `:checkhealth` — no errors under lsp, treesitter, lazy sections
- Open `.go` file → gopls attaches, `:DapContinue` surfaces dap-go
- Open `.py` file → ty attaches (NOT pyright), ruff attaches
- Open `.sh` file → bashls attaches with custom shellcheck settings
- Open `.github/workflows/verify.yml` → gh_actions_ls + actionlint + zizmor
- Open `kustomization.yaml` or `.github/dependabot.yml` → schema completion surfaces (via lang.yaml Extra's schemastore.nvim defaults)
- Save a `.yaml` file → yamlfmt runs (indent preserved, arrays indentless per our override)
- Open `Dockerfile` → dockerls attaches (from lang.docker Extra)
- Open a Helm chart's `templates/*.yaml` → helm_ls attaches
- `<leader>ff/fs/fb/fh/fr/fc/fd/fw/fz` — all nine FZF keymaps fire
- `<leader>ot` — opencode toggle (requires CLI installed)
- Harpoon: `<leader>a` add file; `<leader>1/2/3` jump to marked files (LazyVim Extra binds these by default)
- mini.surround: `sa` / `sd` / `sr` mutations work
- DAP: `<F5>` starts debug on a Go or Python file

If any fails, STOP — fix before declaring the cycle done.

- [ ] **Step 7: No commit** — validation only.

---

## 5. Execution notes + tradeoffs

- **Lockfile discipline:** committed lockfile + `:Lazy restore` on every fresh install. Drift between your Mac and CI becomes impossible.
- **Plan assumes a clean slate.** If any runtime state exists from the current config (lazy caches, compiled treesitter parsers), wipe `~/.local/share/nvim/` before executing Task 11's `:Lazy restore`. This IS what "aggressive; new setup" warrants.
- **Commit discipline:** one commit per task (except Task 9 which bundles three plugin files). Eleven commits total (Tasks 0–10) plus Task 11 (validation only).
- **Rollback:** because the test-plan is rewritten in Task 0 and plugin files are deleted in Task 2, rolling back a specific mid-plan task is painful. The recommended rollback path is: `git revert` the entire task range, not individual tasks. If something goes wrong late in the plan, revert to Task 0's base and re-run the plan. Treat the whole plan as atomic-on-merge.
- **Things we intentionally give up** (by accepting LazyVim/Extras defaults):
  - **LazyGit keybinding exactly** — we lose `<leader>gg` control; LazyVim's default happens to be `<leader>gg` but that's coincidence
  - **Gitsigns 8-keymap block** — `]h/[h/<leader>hs/hr/hS/hp/hb/hd`. LazyVim's default Gitsigns keymaps differ slightly; accept the LazyVim set and retire the custom spec. Re-add narrow overrides in `plugins/gitsigns.lua` if smoke-test reveals a habit we can't give up.
  - **Custom which-key group labels** (`<leader>h = git hunks`, `<leader>f = find (fzf)`) — LazyVim's Extras register their own groups; ours overlap.
  - **prettier for YAML** — replaced by yamlfmt. On markdown, prettier stays via `lang.markdown` Extra's conform default.
  - **Custom `colorcolumn` semantics** — kept at 120 (non-default — load-bearing).

## 6. What this plan does NOT do (explicit non-goals)

- **No LazyVim version bump.** Adopts Extras against the currently-pinned LazyVim HEAD in the lockfile. A LazyVim upgrade is a separate follow-up PR after this lands.
- **No `snacks.nvim` pre-emption.** LazyVim is progressively migrating to folke's snacks.nvim; we stay on the current LazyVim release.
- **No ts/js stack.** `lang.typescript` deliberately omitted from the Extras list.
- **No mini-files Extra.** We stick with LazyVim default neo-tree.
- **No nvim theme change.** LazyVim default (tokyonight) stays. Dracula migration is a separate decision when we've seen the full desktop palette in action.
- **No design-doc rewrite.** `docs/design/editor-neovim.md` is left as-is and will need a follow-up pass after this plan merges to reconcile its implementation notes with the new structure. Flag it in the commit body.

---

## Appendix A: Full content of the rewritten `scripts/test-plan10.sh`

(Omitted from inline content for brevity. Structure: preamble from `test-plan-layer1a.sh` lines 1–55, followed by one AC block per AC-1..AC-17, each following the existing layer-test conventions. See how `test-plan-desktop-layer1.sh` is structured as a reference template.)

The full content will be constructed in Task 0 Step 3. Key structural notes:

- Use `check` helper for single-line greps, `ok`/`nok` for compound predicates
- Use `awk '... | sed 's/#.*//' | grep -q PATTERN'` pattern (Convention 2) for Lua-body greps, since Lua comments (`--`) must be stripped
- For JSON validation (AC-2 Extras set-equality), use `python3 -c "import json; ..."` rather than jq — matches existing layer-test preamble
- Keep the `skp` helper invocations for Linux-only skips (e.g., luac if we add a `luac -p nvim/lua/plugins/*.lua` check)
