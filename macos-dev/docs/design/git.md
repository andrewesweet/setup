# Git — configuration, diff tools, conventional commits

## Overview

This specification defines the git configuration, global ignore patterns, and conventional commit practices for the dotfiles repository. Configuration MUST follow the structure and values defined herein.

## .gitconfig

The primary git configuration file contains user identity, core behaviors, diff/merge tools, and workflow preferences.

```ini
[user]
    name  = Your Name
    email = you@example.com

[core]
    pager        = delta
    excludesFile = ~/.gitignore_global
    autocrlf     = input

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate        = true
    side-by-side    = true
    line-numbers    = true
    syntax-theme    = Monokai Extended
    features        = decorations

[delta "decorations"]
    file-style                   = bold yellow
    file-decoration-style        = none
    hunk-header-style            = line-number syntax

[diff]
    colorMoved = default
    tool       = difftastic

[difftool]
    prompt = false

[difftool "difftastic"]
    cmd = difft "$LOCAL" "$REMOTE"

[merge]
    conflictstyle = diff3
    tool          = vscode

[mergetool "vscode"]
    cmd = code --wait --merge $REMOTE $LOCAL $BASE $MERGED

[mergetool]
    keepBackup = false

[pull]
    rebase = true

[rebase]
    autoStash   = true
    autoSquash  = true

[push]
    default        = current
    autoSetupRemote = true

[fetch]
    prune = true

[branch]
    sort = -committerdate

[log]
    date = relative

[stash]
    showPatch = true

[alias]
    undo    = reset HEAD~1 --mixed
    wip     = !git add -A && git commit -m "WIP"
    unwip   = !git log -1 --format='%s' | grep -q 'WIP' && git reset HEAD~1
    aliases = config --get-regexp alias
```

### Configuration requirements

- The `[core]` section MUST NOT include an `editor` field. Git MUST fall back to the `$EDITOR` environment variable, which is set conditionally in `.bashrc`.
- The `excludesFile` key MUST use camelCase (not lowercase `excludesfile`).
- Delta MUST be configured as the default pager for all diff operations.
- Interactive staging (`git add -i`) MUST use delta for syntax highlighting via `interactive.diffFilter`.
- The `difftastic` tool is the primary diff engine, invoked by `git difftool`.
- VS Code is the merge conflict resolution tool, blocking until resolved with `code --wait`.
- Pull operations MUST rebase instead of merge by default (`pull.rebase = true`).
- Rebase operations MUST automatically stash and squash fixup commits (`rebase.autoStash`, `rebase.autoSquash`).
- Push MUST default to the current branch and auto-track remote branches (`push.default`, `push.autoSetupRemote`).
- Fetch MUST automatically prune deleted remote branches (`fetch.prune = true`).
- Stash display MUST show patch diffs by default (`stash.showPatch = true`).

## .gitignore_global

The global ignore file applies to all repositories without explicit configuration.

```gitignore
# macOS
.DS_Store
.AppleDouble
.LSOverride
._*

# Editor artefacts
.vscode/
.idea/
*.swp
*.swo
*~
.aider*

# OS / tools
Thumbs.db
.direnv/

# Secrets and credentials
.env
.env.*
.env.local
*.pem
*.key
*.p12
*.pfx
auth.json
credentials.json
application_default_credentials.json
*.keystore

# Dotfiles local overrides
.bashrc.local
dev.env
```

### Ignore requirements

- Patterns MUST ignore macOS metadata files (`.DS_Store`, `.AppleDouble`, `._*`).
- Editor state files and plugin directories MUST be ignored (`.vscode/`, `.idea/`, vim swap files, `.aider*`).
- Secrets and credential files MUST be ignored in all formats (`.env*`, `.pem`, `.key`, keys, keystores).
- Local dotfiles overrides MUST be ignored (`.bashrc.local`, `dev.env`).
- The `.direnv/` cache directory MUST be ignored.

## lazygit configuration

Lazygit provides a terminal UI for git workflows. Configuration MUST specify theme, keybindings, and paging behavior.

```yaml
gui:
  theme:
    activeBorderColor:
      - '#89b4fa'
      - bold
    selectedLineBgColor:
      - '#313244'
  sidePanelWidth: 0.25
  expandFocusedSidePanel: true
  showFileTree: true
  nerdFontsVersion: "3"

git:
  paging:
    colorArg: always
    pager: delta --paging=never --syntax-theme='Monokai Extended'
  commit:
    signOff: false
  fetching:
    interval: 60

keybinding:
  universal:
    quit:            q
    return:          "<esc>"
    scrollUpMain:    k
    scrollDownMain:  j
    prevItem:        k
    nextItem:        j
    scrollLeft:      h
    scrollRight:     l
    nextTab:         "]"
    prevTab:         "["
    openRecentRepos: "<c-r>"
```

### lazygit requirements

- The pager MUST be configured with explicit `--syntax-theme='Monokai Extended'` because lazygit invokes delta directly, bypassing the `.gitconfig` file.
- Keybindings MUST follow vim conventions (hjkl for navigation, q to quit).
- The side panel width MUST be 25% of the terminal width.
- Nerd Fonts version 3 is REQUIRED for icon rendering.
- Commit signing (GPG) is DISABLED by default (`commit.signOff: false`).
- Fetch operations MUST run on a 60-second interval in the background.

## Go formatting tools

The Brewfile SHOULD include both `gofumpt` and `goimports` for comprehensive Go code formatting. `goimports` handles import organization and MUST be available alongside `gofumpt`.

## Conventional commits

Commit messages follow the conventional commits specification for semantic versioning and changelog generation.

### Format

```
type(scope): description
```

### Commit types

The following types are REQUIRED:

- `feat` — new feature
- `fix` — bug fix
- `docs` — documentation changes
- `style` — code style changes (formatting, missing semicolons)
- `refactor` — code refactoring without feature or fix
- `perf` — performance improvements
- `test` — test additions or changes
- `chore` — build process, dependencies, tooling
- `ci` — CI/CD configuration changes

### Subject line requirements

- MUST use imperative mood ("add feature" not "added feature")
- MUST be under 72 characters
- MUST not end with a period
- SHOULD reference issue numbers when applicable

### Tooling

- `cocogitto` (`cog`) MUST be used for interactive commits and automated version bumping.
- `git-cliff` MUST be used for changelog generation from commit history.

## Delta configuration notes

The `navigate=true` setting remaps `n` and `N` keys to jump between hunks within a diff view. This overrides the default `less` search-next behavior. Developers SHOULD be aware that interactive search functionality is disabled in delta diff pagers. This trade-off enables faster hunk navigation in large diffs.

The `stash.showPatch = true` setting ensures that `git stash show` renders output through delta, providing syntax highlighting and hunk navigation in stash previews.

## Theme consistency

- **tmux**: Status bar and UI chrome MUST use Catppuccin Mocha hex color palette.
- **bat, delta, lazygit**: Code syntax highlighting MUST use Monokai Extended color theme.

These are distinct color palettes. Catppuccin Mocha is designed for terminal UI chrome; Monokai Extended is optimized for code readability. This separation is intentional and MUST NOT be unified.
