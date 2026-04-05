# OpenCode and critique

## Overview

This document specifies the configuration and permissions for OpenCode, an AI-powered development assistant for dotfiles management. The configuration MUST enforce security boundaries while enabling productive workflows for code editing, git operations, and temporary file handling.

## Provider and Models

The system MUST use GitHub Copilot as the exclusive provider. The primary model MUST be `github-copilot/claude-sonnet-4-6`. The small model MUST be `github-copilot/gpt-4o-mini`.

## Instructions

The AI assistant MUST load the following instruction files in order:

1. `~/.config/opencode/instructions/git-conventions.md`
2. `~/.config/opencode/instructions/scratch-dirs.md`

These files MUST be consulted for all operations affecting git repositories and temporary file creation.

## opencode.jsonc Configuration

The configuration file MUST conform to the OpenCode schema at `https://opencode.ai/config.json`. The following configuration MUST be applied:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "github-copilot/claude-sonnet-4-6",
  "small_model": "github-copilot/gpt-4o-mini",
  "instructions": [
    "~/.config/opencode/instructions/git-conventions.md",
    "~/.config/opencode/instructions/scratch-dirs.md"
  ],
  "permission": {
    "*": "ask",
    "read": {
      "*": "ask",
      "~/workspace/**": "allow",
      "/home/dev/workspace/**": "allow",
      "/tmp/**": "allow",
      "~/.config/opencode/**": "allow",
      "~/.config/mise/**": "allow"
    },
    "grep": "allow",
    "glob": "allow",
    "list": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "bash": {
      "*": "ask",
      "git status *": "allow", "git status": "allow",
      "git diff *": "allow", "git diff": "allow",
      "git log *": "allow", "git log": "allow",
      "git show *": "allow",
      "git branch *": "allow", "git branch": "allow",
      "git stash list": "allow",
      "rg *": "allow", "fd *": "allow",
      "bat *": "allow",
      "cat /home/dev/workspace/*": "allow",
      "cat /tmp/*": "allow",
      "ls *": "allow", "ls": "allow",
      "which *": "allow", "type *": "allow",
      "pwd": "allow", "date *": "allow", "date": "allow",
      "npm list *": "allow", "brew list *": "allow",
      "rm -rf *": "deny", "rm -fr *": "deny",
      "sudo *": "deny", "chmod 777 *": "deny"
    },
    "edit": {
      "*": "ask",
      "~/workspace/**": "allow",
      "/home/dev/workspace/**": "allow",
      "/tmp/**": "allow"
    },
    "webfetch": "ask",
    "websearch": "ask",
    "external_directory": {
      "*": "ask",
      "/tmp/**": "allow"
    },
    "doom_loop": "ask"
  },
  "share": { "mode": "manual" },
  "autoupdate": false // Pin version for supply-chain security. Update deliberately.
}
```

### Permission Scoping Requirements

The `read` permission MUST be restricted to workspace directories, the `/tmp` directory, and specific configuration paths. Broad read access MUST NOT be granted.

The `cat` bash command MUST be scoped exclusively to `/home/dev/workspace/*` and `/tmp/*` paths. The permission entry `"cat *": "allow"` from any prior specification MUST NOT be applied.

The `edit` permission MUST be scoped to workspace directories and the `/tmp` directory. Editing arbitrary files MUST require explicit user confirmation.

Destructive commands `rm -rf` and `rm -fr` MUST be denied unconditionally. Privileged operations with `sudo` and insecure permission changes with `chmod 777` MUST be denied unconditionally.

## tui.jsonc Configuration

The terminal user interface configuration file MUST conform to the OpenCode TUI schema at `https://opencode.ai/tui.json`. The following keybinding configuration MUST be applied:

```jsonc
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
    "leader": "ctrl+x",
    "session_new": "<leader>n",
    "session_list": "<leader>l",
    "session_timeline": "<leader>g",
    "session_compact": "<leader>c",
    "session_interrupt": "escape",
    "session_export": "<leader>x",
    "session_share": "<leader>S",
    "session_fork": "none",
    "session_rename": "none",
    "messages_half_page_up": "ctrl+alt+u",
    "messages_half_page_down": "ctrl+alt+d",
    "messages_page_up": "pageup,ctrl+alt+b",
    "messages_page_down": "pagedown,ctrl+alt+f",
    "messages_first": "ctrl+g,home",
    "messages_last": "ctrl+alt+g,end",
    "messages_copy": "<leader>y",
    "messages_undo": "<leader>u",
    "sidebar_toggle": "<leader>b",
    "model_list": "<leader>m",
    "agent_list": "<leader>a",
    "theme_list": "<leader>t",
    "editor_open": "<leader>e",
    "status_view": "<leader>s",
    "agent_cycle": "tab",
    "agent_cycle_reverse": "shift+tab",
    "command_list": "ctrl+p",
    "scrollbar_toggle": "none",
    "username_toggle": "none",
    "tool_details": "none",
    "session_child_first": "<leader>down",
    "session_child_cycle": "right",
    "session_child_cycle_reverse": "left",
    "session_parent": "up",
    "display_thinking": "none"
  }
}
```

### Keybinding Collision Avoidance

The `messages_half_page_up` action MUST be bound to `ctrl+alt+u` (not bare `ctrl+u`) to prevent collision with emacs Ctrl+U behavior in the input area.

The `messages_half_page_down` action MUST be bound to `ctrl+alt+d` (not bare `ctrl+d`) to prevent collision with emacs Ctrl+D behavior in the input area.

## Instruction Files

### git-conventions.md

The file MUST be located at `~/.config/opencode/instructions/git-conventions.md` and MUST contain the following content:

```markdown
# Git conventions
- Commit messages follow Conventional Commits: `type(scope): description`
- Valid types: feat, fix, docs, style, refactor, perf, test, chore, ci
- Breaking changes: append `!` after type or add `BREAKING CHANGE:` footer
- Subject line: imperative mood, under 72 characters
- Changelog generated by git-cliff. Do not hand-edit CHANGELOG.md.
- Version bumps managed by cocogitto (`cog bump --auto`).
- Before proposing a commit, verify with: `cog verify "<message>"`
```

### scratch-dirs.md

The file MUST be located at `~/.config/opencode/instructions/scratch-dirs.md` and MUST contain the following content:

```markdown
# Scratch and temporary files
When you need temporary files, use /tmp rather than $TMPDIR.
/tmp is stable on macOS and explicitly permitted by permissions.
Use prefix: /tmp/opencode-<short-description>
Clean up after task completion: rm -rf /tmp/opencode-*
```

## Critique Functions

Critique functions `cr`, `crw`, and `crs` MUST be defined in `.bash_aliases`. These functions enable code review operations and MUST follow the specifications in `shell.md`.

## Known Keybinding Limitations

The following keybinding collisions are known and have documented workarounds:

- **Tmux context**: When running OpenCode inside a tmux session, the tmux prefix `Ctrl+A` intercepts the start-of-line command. The workaround is to send `Ctrl+A Ctrl+A` to produce a literal start-of-line action.

- **VS Code context**: When running in a VS Code integrated terminal, `Ctrl+P` (VS Code Quick Open) intercepts the command palette binding. Additionally, `Ctrl+K` (VS Code chord) intercepts delete-to-end behavior.

## Installation and Runtime

The Brewfile MUST include the following entry:

```ruby
brew "bun"    # runtime for OpenCode and critique
```

OpenCode and critique MUST be installed via the bun package manager:

```bash
bun install -g opencode-ai critique
```

The PATH environment variable MUST include `~/.bun/bin` to ensure the installed binaries are discoverable.

## Configuration Auto-Updates

The `autoupdate` field MUST be set to `false` to pin versions for supply-chain security. Updates SHOULD be applied deliberately after review.

## Session Sharing

The share mode MUST be set to `"manual"`, requiring explicit user action before session data is shared externally.
