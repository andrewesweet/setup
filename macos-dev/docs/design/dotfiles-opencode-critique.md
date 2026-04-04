# OpenCode + critique — dotfiles supplement

Extends `dotfiles-setup.md`. Same repo, same install philosophy.

---

## Dotfiles additions

```
~/.dotfiles/
├── Brewfile                              # add bun
├── opencode/
│   ├── opencode.jsonc                    # global OpenCode config
│   ├── tui.jsonc                         # TUI keybinds
│   └── instructions/
│       ├── git-conventions.md
│       └── scratch-dirs.md
└── bash/
    └── .bash_aliases                     # add critique functions
```

Add to `install.sh`:

```bash
link opencode/opencode.jsonc        .config/opencode/opencode.jsonc
link opencode/tui.jsonc             .config/opencode/tui.jsonc
link opencode/instructions/git-conventions.md \
                                    .config/opencode/instructions/git-conventions.md
link opencode/instructions/scratch-dirs.md \
                                    .config/opencode/instructions/scratch-dirs.md
```

---

## Brewfile additions

```ruby
brew "bun"    # runtime for OpenCode and critique (not node)
```

Install OpenCode and critique globally once (not via Homebrew):

```bash
bun install -g opencode-ai   # opencode TUI + CLI
bun install -g critique      # diff review TUI
```

Update both later with:

```bash
bun update -g opencode-ai critique
```

---

## 1. opencode.jsonc — global config

```jsonc
// ~/.config/opencode/opencode.jsonc
// Committed to dotfiles. No secrets here — credentials live in
// ~/.local/share/opencode/auth.json (managed by `opencode auth login`)
// or in environment variables.
{
  "$schema": "https://opencode.ai/config.json",

  // ── Provider ──────────────────────────────────────────────────────
  // GitHub Copilot as the sole provider. Authenticate once with:
  //   opencode auth login
  // and select GitHub Copilot. Token is stored in auth.json.
  "model": "github-copilot/claude-sonnet-4-6",
  "small_model": "github-copilot/gpt-4o-mini",

  // ── Instructions ──────────────────────────────────────────────────
  // Loaded into every session on top of any project-level AGENTS.md.
  "instructions": [
    "~/.config/opencode/instructions/git-conventions.md",
    "~/.config/opencode/instructions/scratch-dirs.md"
  ],

  // ── Permissions ───────────────────────────────────────────────────
  // Defensive-by-default stance: ask for everything unless explicitly
  // allowed below. Rules are evaluated last-match-wins, so the "*"
  // catch-all always goes first.
  "permission": {

    // Global catch-all: prompt for anything not covered below
    "*": "ask",

    // Read-only tools: silent. Agents need to read freely to be useful.
    "read": "allow",
    "grep": "allow",
    "glob": "allow",
    "list": "allow",

    // Skills and todo management: silent (non-destructive)
    "skill": "allow",
    "todowrite": "allow",

    // Bash: ask by default, with specific safe patterns allowed silently.
    // Pattern matches against the parsed command string. Last rule wins.
    "bash": {
      "*": "ask",

      // Git read operations (no commit, no push)
      "git status *": "allow",
      "git status":   "allow",
      "git diff *":   "allow",
      "git diff":     "allow",
      "git log *":    "allow",
      "git log":      "allow",
      "git show *":   "allow",
      "git branch *": "allow",
      "git branch":   "allow",
      "git stash list": "allow",

      // Safe search/inspection tools
      "rg *":         "allow",
      "fd *":         "allow",
      "bat *":        "allow",
      "cat *":        "allow",
      "ls *":         "allow",
      "ls":           "allow",
      "echo *":       "allow",
      "which *":      "allow",
      "type *":       "allow",
      "pwd":          "allow",
      "date *":       "allow",
      "date":         "allow",

      // Package manager reads (not installs)
      "npm list *":   "allow",
      "brew list *":  "allow",

      // Explicitly block dangerous patterns regardless of other rules
      "rm -rf *":     "deny",
      "rm -fr *":     "deny",
      "sudo *":       "deny",
      "chmod 777 *":  "deny"
    },

    // File edits: ask for everything.
    // 'edit' covers write, apply_patch, and multiedit too.
    "edit": "ask",

    // Web access: ask (avoid uncontrolled outbound requests)
    "webfetch": "ask",
    "websearch": "ask",

    // External directories: ask by default, /tmp explicitly allowed.
    //
    // $TMPDIR is NOT used here. On macOS it resolves to a session-specific
    // path under /private/var/folders/... which varies per user and cannot
    // be referenced by environment variable name in permission patterns
    // (only ~ and $HOME expansion is supported).
    //
    // /tmp on macOS is a stable symlink to /private/tmp and works reliably.
    // The scratch-dirs.md instruction tells agents to prefer /tmp.
    //
    // Known limitation (opencode issue #20045): the 'edit' permission uses
    // relative paths internally while external_directory uses absolute paths,
    // so an 'edit' allow rule for /tmp/** may not match correctly. Agent
    // writes to /tmp will typically go via bash (cp, tee, redirect) rather
    // than the edit tool directly, so this is unlikely to cause friction.
    "external_directory": {
      "*":       "ask",
      "/tmp/**": "allow"
    },

    // doom_loop fires when the same tool call repeats 3x with identical
    // input. Keep at ask — it usually signals something has gone wrong.
    "doom_loop": "ask"
  },

  // ── Share ─────────────────────────────────────────────────────────
  "share": {
    "mode": "manual"    // use /share explicitly; never auto-share
  },

  // ── Autoupdate ────────────────────────────────────────────────────
  "autoupdate": true
}
```

### Project-level override template

Each repo gets `.opencode/opencode.jsonc`. Commit this alongside `AGENTS.md`:

```jsonc
// .opencode/opencode.jsonc
{
  "$schema": "https://opencode.ai/config.json",

  // Project-specific instructions (generated by /init inside OpenCode)
  "instructions": [
    ".opencode/AGENTS.md"
  ]

  // Uncomment to override model for this repo:
  // "model": "github-copilot/gpt-4o"
}
```

Generate `AGENTS.md` by running `/init` inside an OpenCode session in the
repo. It describes the repo structure, stack, and conventions that agents
use for context. Commit it.

---

## 2. tui.jsonc — keybinds

OpenCode keybinds live in a separate `tui.json` (or `.jsonc`), not in
`opencode.jsonc`.

The TUI has two distinct input contexts with different binding schemes:

- **Message list / navigation panels**: uses a configurable `<leader>` key.
- **Input area (the prompt box)**: emacs-style bindings (`Ctrl+A`, `Ctrl+E`,
  `Ctrl+K`, etc.) that are hardcoded and not configurable.

The emacs bindings in the input area are consistent with bash readline in
emacs mode, so they feel natural at the prompt regardless of your `set -o vi`
setting. They do not conflict with shell vi mode because OpenCode fully owns
that input box.

The leader key defaults to `Ctrl+X` and is kept as-is — it does not conflict
with tmux (`Ctrl+A`), lazygit, or anything else in the stack.

```jsonc
// ~/.config/opencode/tui.jsonc
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
    // Leader key: Ctrl+X (default — no conflicts in this stack)
    "leader": "ctrl+x",

    // Session management
    "session_new":       "<leader>n",
    "session_list":      "<leader>l",
    "session_timeline":  "<leader>g",   // g = git log mental model
    "session_compact":   "<leader>c",
    "session_interrupt": "escape",      // Esc = stop (vi feel)
    "session_export":    "<leader>x",
    "session_share":     "<leader>S",   // capital S = deliberate action
    "session_fork":      "none",
    "session_rename":    "none",

    // Message scrolling: add Ctrl+U/D alongside defaults
    // so muscle memory from tmux copy mode transfers
    "messages_half_page_up":   "ctrl+u,ctrl+alt+u",
    "messages_half_page_down": "ctrl+d,ctrl+alt+d",
    "messages_page_up":        "pageup,ctrl+alt+b",
    "messages_page_down":      "pagedown,ctrl+alt+f",
    "messages_first":          "ctrl+g,home",
    "messages_last":           "ctrl+alt+g,end",

    // y for yank (vi muscle memory)
    "messages_copy":     "<leader>y",
    "messages_undo":     "<leader>u",

    // UI toggles
    "sidebar_toggle":    "<leader>b",
    "model_list":        "<leader>m",
    "agent_list":        "<leader>a",
    "theme_list":        "<leader>t",
    "editor_open":       "<leader>e",
    "status_view":       "<leader>s",

    // Agent cycling — Tab/Shift+Tab (universal cycle convention)
    "agent_cycle":         "tab",
    "agent_cycle_reverse": "shift+tab",

    // Command palette — Ctrl+P (familiar from VS Code)
    "command_list":      "ctrl+p",

    // Disable unused defaults
    "scrollbar_toggle":          "none",
    "username_toggle":           "none",
    "tool_details":              "none",
    "session_child_first":       "<leader>down",
    "session_child_cycle":       "right",
    "session_child_cycle_reverse": "left",
    "session_parent":            "up",
    "display_thinking":          "none"
  }
}
```

---

## 3. Instruction files

### instructions/git-conventions.md

```markdown
# Git conventions

- Commit messages follow Conventional Commits: `type(scope): description`
- Valid types: feat, fix, docs, style, refactor, perf, test, chore, ci
- Breaking changes: append `!` after type (e.g. `feat!:`) or add a
  `BREAKING CHANGE:` footer
- Subject line: imperative mood, under 72 characters
  ("add feature" not "added feature")
- Changelog is generated by git-cliff from commit history.
  Do not hand-edit CHANGELOG.md.
- Version bumps are managed by cocogitto (`cog bump --auto`).
  Do not manually edit version fields in package files.
- Before proposing a commit, verify the message with:
  `cog verify "<message>"`
```

### instructions/scratch-dirs.md

```markdown
# Scratch and temporary files

When you need temporary files for intermediate work (patches, diffs,
generated content, build artefacts), use /tmp rather than $TMPDIR.

/tmp is stable on macOS and is explicitly permitted by the permission
config. $TMPDIR resolves to a session-specific path that may not be
accessible.

Use a consistent prefix for scratch files so they are easy to identify:
  /tmp/opencode-<short-description>

Clean up after task completion:
  rm -rf /tmp/opencode-*
```

---

## 4. critique — shell functions

Add to `~/.bash_aliases`:

```bash
# ── critique ──────────────────────────────────────────────────────────────────
# cr  [args]  — review diff in TUI (pass any critique args through)
# crw [args]  — open diff as shareable web preview
# crs [args]  — pick a recent OpenCode session interactively, then review
#
# Examples:
#   cr                   review unstaged changes
#   cr HEAD~1            review last commit
#   cr main              review branch vs main
#   cr --staged          review staged changes
#   crw main             web preview of branch diff (shareable link)
#   crs                  pick session with fzf, then review

cr() {
  critique review "$@"
}

crw() {
  critique review --web --open "$@"
}

crs() {
  # List recent OpenCode sessions, pick one with fzf, extract the session ID
  local session_id
  session_id=$(
    opencode session list 2>/dev/null \
      | fzf --height=40% \
            --layout=reverse \
            --border \
            --prompt="OpenCode session > " \
      | awk '{print $1}'
  )

  if [[ -z "$session_id" ]]; then
    echo "No session selected." >&2
    return 1
  fi

  critique review --agent opencode --session "$session_id" "$@"
}
```

### Workflow with lazygit

```
gl          open lazygit — hunk-level staging and commit
cr HEAD~1   word-level diff of last commit in critique TUI
crw main    shareable web preview of branch diff
crs         attach critique to the OpenCode session that made the changes
```

lazygit and critique are complementary: lazygit gives you hunk-level staging
control and interactive rebase; critique gives you word-level diff rendering
and optional AI review. Use both, in either order.

---

## 5. Vim keybinding reference — full stack

### Navigation (read-only contexts)

| Action | Bash vi normal | OpenCode nav | lazygit | btop | lnav | tmux copy |
|--------|---------------|--------------|---------|------|------|-----------|
| Down | `j` | `↓` | `j` | `j` | `j` | `j` |
| Up | `k` | `↑` | `k` | `k` | `k` | `k` |
| Half page ↓ | `Ctrl+D` | `Ctrl+D` | `Ctrl+D` | `d` | `Ctrl+D` | `Ctrl+D` |
| Half page ↑ | `Ctrl+U` | `Ctrl+U` | `Ctrl+U` | `u` | `Ctrl+U` | `Ctrl+U` |
| Search | `/` | — | `/` | `/` | `/` | `/` |
| Next result | `n` | — | `n` | — | `n` | `n` |
| Prev result | `N` | — | `N` | — | `N` | `N` |
| Quit / back | `q` | `Esc` | `q` / `Esc` | `q` | `q` | `q` |
| Yank / copy | `y` | `Ctrl+X` `y` | `y` | — | `c` | `y` |

### OpenCode input area (hardcoded — emacs-style, not configurable)

| Shortcut | Action |
|----------|--------|
| `Ctrl+A` | Start of line |
| `Ctrl+E` | End of line |
| `Ctrl+K` | Delete to end of line |
| `Ctrl+U` | Delete to start of line |
| `Ctrl+W` | Delete previous word |
| `Alt+F` / `Alt+B` | Forward / back one word |
| `Esc` | Interrupt running response |
| `Shift+Enter` | New line in multi-line input |
| `Ctrl+P` | Command palette |
| `Tab` / `Shift+Tab` | Cycle agents |

### Bash vi mode

| Mode | Starship indicator | Enter with |
|------|--------------------|------------|
| Insert (default) | `[I]` | Start typing |
| Normal | `[N]` | `Esc` |

Normal mode: `hjkl` move cursor · `w`/`b` word movement · `dd` delete line ·
`A` append at end · `I` insert at start · `u` undo

Both modes: `Ctrl+R` opens fzf history search without a mode switch.

### tmux (prefix model)

Prefix: `Ctrl+A` then release, then key.

| Action | Keys |
|--------|------|
| Split → | `Ctrl+A` `\|` |
| Split ↓ | `Ctrl+A` `-` |
| Move to pane | `Ctrl+A` `h/j/k/l` |
| New window | `Ctrl+A` `c` |
| Next window | `Ctrl+A` `n` |
| Session list | `Ctrl+A` `s` |
| Copy mode | `Ctrl+A` `Enter` |
| Detach | `Ctrl+A` `d` |

In copy mode: `v` select · `y` yank · `/` search — vi-style.

### Scheme summary

| Tool | Scheme | Caveat |
|------|--------|--------|
| Bash readline | vi mode | Esc → normal, hjkl, / |
| OpenCode input | emacs (hardcoded) | Ctrl+A/E/K/U — cannot change |
| OpenCode navigation | leader `Ctrl+X` | Separate from both |
| tmux | prefix `Ctrl+A` | Copy mode is vi-style |
| lazygit | vi-style | hjkl, q, /, n/N |
| critique | vi-style | hjkl, q |
| btop | vi-style | hjkl, q |
| lnav | vi-style | hjkl, /, ?, q |
| delta | vi-style | n/N between diff hunks |
| fzf (shell) | `Ctrl+J/K` | Works without leaving insert mode |

The only genuine inconsistency is the OpenCode input area. Its hardcoded
emacs bindings are independent of your shell vi mode setting. In practice
this is fine — the input area is a distinct context and the handful of
emacs shortcuts (`Ctrl+A`, `Ctrl+E`, `Ctrl+K`) are quick to internalise
separately from the rest of the scheme.

---

## 6. Team onboarding additions

Append to the onboarding sequence in `dotfiles-setup.md`:

```bash
# Install OpenCode and critique runtimes
bun install -g opencode-ai critique

# Authenticate with GitHub Copilot (opens browser)
opencode auth login
# Select: GitHub Copilot

# Verify model access
opencode models list | grep copilot

# Test critique on any repo with commits
cd <your-repo>
cr HEAD~1
```
