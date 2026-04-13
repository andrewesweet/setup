# Layer 1b-ii Implementation Plan: tmux + TPM + plugins + Dracula theming

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current hand-rolled tmux theme + minimal config with TPM and nine tmux plugins (sensible, yank, resurrect, continuum, thumbs, tmux-fzf, fzf-url, sessionx, floax, dracula/tmux); finish the Dracula Pro theming rollout across the remaining existing tools (BAT_THEME, FZF colors, delta, lazygit, kitty).

**Architecture:** Install TPM via `git clone` from install scripts. Declare plugins in `tmux/.tmux.conf` using TPM's `set -g @plugin` DSL. Remove the four settings that tmux-sensible provides (`escape-time`, `history-limit`, `default-shell`, `default-terminal`) and the manual 4-line theme (replaced by `dracula/tmux`). Update five existing config files to the Dracula palette: `bash/.bashrc` (BAT_THEME, FZF_DEFAULT_OPTS colors), `git/.gitconfig` (delta syntax-theme), `lazygit/config.yml` (theme section), `kitty/kitty.conf` (font + `include dracula-pro.conf`), plus ship `kitty/dracula-pro.conf`. Starship already uses the Dracula palette (Layer 1a shipped it).

**Tech Stack:** tmux (>= 3.2), TPM (tmux-plugins/tpm), bash, brew, git.

**Spec reference:** `docs/plans/2026-04-12-shell-modernisation-design.md` §§ 3.6, 3.9, 4 (Layer 1b bullet 3), 5 (install scripts TPM bootstrap), Appendix A (review findings on Dracula tmux plugin).

**Platform scope:** macOS + WSL2 (Linux). `tmux-thumbs` requires a Rust toolchain to compile on first `prefix + I`; documented as a post-install caveat with a pre-built-binary fallback.

**Prerequisites:** Layers 1a, 1c, and 1b-i merged. 1b-i introduced `gh_release_install` which this plan does not re-use (TPM is a `git clone`, not a release binary). This plan is a sibling to 1b-iii (cable channels + gh) — no shared files except `docs/cheatsheet.md`.

---

## Acceptance Criteria (Specification by Example)

**AC-1: tmux.conf has the canonical plugin block with all ten plugins**
```
Given: tmux/.tmux.conf
When: grepped for `set -g @plugin`
Then: rows exist for every plugin in this exact list:
  tmux-plugins/tpm
  tmux-plugins/tmux-sensible
  tmux-plugins/tmux-yank
  tmux-plugins/tmux-resurrect
  tmux-plugins/tmux-continuum
  fcsonline/tmux-thumbs
  sainnhe/tmux-fzf
  wfxr/tmux-fzf-url
  omerxx/tmux-sessionx
  omerxx/tmux-floax
  dracula/tmux
```

**AC-2: TPM bootstrap (`run '~/.tmux/plugins/tpm/tpm'`) is the LAST non-blank non-comment line**
```
Given: tmux/.tmux.conf
When: awk for the last non-blank line that is not a full-line comment
Then: that line matches `^run '~/.tmux/plugins/tpm/tpm'$`
```

**AC-3: settings redundant with tmux-sensible are removed**
```
Given: tmux/.tmux.conf
When: grepped
Then: `set -sg escape-time 10` is GONE
And: `set -g history-limit 50000` is GONE
And: a comment explains why (points to tmux-sensible)
And: `set -g default-terminal "tmux-256color"` is KEPT (sensible defaults differ)
And: `set -sa terminal-overrides ",xterm-kitty:RGB"` is KEPT (user-specific)
```

**AC-4: resurrect + continuum plugin configuration**
```
Given: tmux/.tmux.conf
When: grepped
Then: `@continuum-restore 'on'`
And: `@resurrect-strategy-nvim 'session'`
```

**AC-5: clipboard and session behaviour**
```
Given: tmux/.tmux.conf
When: grepped
Then: `set -g set-clipboard on`         (OSC 52 passthrough for yank)
And: `set -g detach-on-destroy off`     (switch to next session)
```

**AC-6: floax plugin configuration**
```
Given: tmux/.tmux.conf
When: grepped
Then: `@floax-bind 'p'`
And: `@floax-width '80%'`
And: `@floax-height '80%'`
And: `@floax-change-path 'true'`
```

**AC-7: sessionx plugin configuration**
```
Given: tmux/.tmux.conf
When: grepped
Then: `@sessionx-bind 'o'`
And: `@sessionx-zoxide-mode 'on'`
And: `@sessionx-window-height '85%'`
And: `@sessionx-window-width '75%'`
And: `@sessionx-filter-current 'false'`
```

**AC-8: fzf-url plugin configuration**
```
Given: tmux/.tmux.conf
When: grepped
Then: `@fzf-url-history-limit '2000'`
```

**AC-9: Dracula tmux plugin configuration**
```
Given: tmux/.tmux.conf
When: grepped
Then: `@dracula-show-powerline true`
And: `@dracula-plugins "git time"`
And: `@dracula-show-left-icon session`
And: `@dracula-military-time true`
```

**AC-10: manual hand-rolled status-bar theme is removed**
```
Given: tmux/.tmux.conf
When: grepped
Then: `status-style "bg=#1e1e2e,fg=#cdd6f4"`  is GONE
And: `window-status-current-style "bold,fg=#89b4fa"`  is GONE
And: no remaining `#89b4fa` or `#1e1e2e` references (those are catppuccin)
```

**AC-11: install scripts clone TPM on first run**
```
Given: install-macos.sh and install-wsl.sh
When: grepped
Then: both have a conditional `git clone https://github.com/tmux-plugins/tpm`
And: both guard on `[[ ! -d "$HOME/.tmux/plugins/tpm" ]]` (idempotent)
And: install-wsl.sh mentions tmux-thumbs Rust-toolchain caveat in its next-steps output
```

**AC-12: BAT_THEME is Dracula in .bashrc**
```
Given: bash/.bashrc section 11
When: grepped
Then: `export BAT_THEME="Dracula"`
And: the previous `Monokai Extended` value is GONE
```

**AC-13: FZF_DEFAULT_OPTS uses Dracula colors**
```
Given: bash/.bashrc section 11
When: the FZF_DEFAULT_OPTS string is inspected
Then: it contains `fg:#f8f8f2` and `bg:#282a36` and `hl:#bd93f9`
And: it still contains the existing `--bind=ctrl-j:down,ctrl-k:up` binding
And: it still contains `--height 40%` and `--layout=reverse`
```

**AC-14: delta uses Dracula syntax theme**
```
Given: git/.gitconfig
When: the [delta] section is inspected
Then: `syntax-theme = Dracula`
```

**AC-15: lazygit uses Dracula theme**
```
Given: lazygit/config.yml
When: inspected
Then: a top-level `gui.theme` or `theme` section exists with Dracula activeBorderColor/inactiveBorderColor/selectedLineBgColor set to Dracula palette values (purple/comment/current_line)
```

**AC-16: kitty uses Dracula Pro + JetBrainsMono Nerd Font + ligatures**
```
Given: kitty/kitty.conf
When: grepped
Then: `font_family      JetBrainsMono Nerd Font`
And: `disable_ligatures never`
And: `include dracula-pro.conf`

Given: kitty/dracula-pro.conf
When: test -f
Then: file exists
And: contains `foreground` and `background` directives
```

**AC-17: `cheat tmux-plugins` subcommand exists**
```
Given: bash/.bash_aliases cheat() body
When: inspected
Then: a `tmux-plugins)` case arm exists
And: the help text mentions prefix+I (install), prefix+p (floax),
     prefix+o (sessionx), prefix+Space (thumbs), prefix+u (fzf-url), prefix+F (tmux-fzf)
```

**AC-18: .bashrc structural invariants preserved**
```
When: bash scripts/test-plan2.sh runs
Then: ".bashrc has 14 numbered sections" passes (no new section added — BAT_THEME/FZF changes are in §11)
```

**AC-19: starship TOML section count preserved (or updated in test-plan6-8.sh)**
```
When: bash scripts/test-plan6-8.sh runs
Then: exit 0
Note: this plan does not modify starship.toml. If module styles are added, update the expected count in test-plan6-8.sh (currently 11).
```

**AC-20: End-to-end acceptance script enumerates every AC**
```
When: bash scripts/test-plan-layer1b-ii.sh runs
Then: every AC above is checked
And: exit 0 if all pass, 1 otherwise
```

---

## File Structure

**New files:**
- `kitty/dracula-pro.conf` — palette pulled from Dracula Pro download (manually created from the design's Dracula Pro palette § 3.9). Committed to this (private) repo; would be gitignored if repo went public.
- `scripts/test-plan-layer1b-ii.sh` — ATDD script

**Modified:**
- `tmux/.tmux.conf` — plugin block, plugin config blocks, removed sensible-overlap settings, removed hand-rolled status-bar theme
- `bash/.bashrc` — BAT_THEME="Dracula" (§11), FZF_DEFAULT_OPTS Dracula color string (§11)
- `git/.gitconfig` — `syntax-theme = Dracula` in [delta]
- `lazygit/config.yml` — Dracula theme section
- `kitty/kitty.conf` — JetBrainsMono Nerd Font + `include dracula-pro.conf`
- `bash/.bash_aliases` — `tmux-plugins)` case arm in `cheat()`
- `docs/cheatsheet.md` — tmux plugin keybindings block
- `install-macos.sh` — TPM clone + note in next-steps
- `install-wsl.sh` — TPM clone + tmux-thumbs Rust caveat in next-steps
- `scripts/verify.sh` — TPM presence check

**Untouched:**
- `starship/starship.toml` (already Dracula from Layer 1a)
- `atuin/config.toml`, `television/config.toml` (theme already `dracula`)

---

## Task 0: Bootstrap acceptance test script (Red)

**Files:**
- Create: `scripts/test-plan-layer1b-ii.sh`

- [ ] **Step 1: Skeleton** — copy preamble lines 1–55 verbatim from `scripts/test-plan-layer1a.sh`. Update header to "test-plan-layer1b-ii.sh — acceptance tests for Layer 1b-ii (tmux + TPM + plugins + Dracula theming)".

- [ ] **Step 2: Append banner + AC-1 stub**

```bash
echo "Layer 1b-ii acceptance tests (tmux plugins + Dracula theming rollout)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1: tmux plugin block present ───────────────────────────────────────
echo "AC-1: tmux.conf plugin block"
for p in 'tmux-plugins/tpm' 'tmux-plugins/tmux-sensible' 'tmux-plugins/tmux-yank' \
         'tmux-plugins/tmux-resurrect' 'tmux-plugins/tmux-continuum' \
         'fcsonline/tmux-thumbs' 'sainnhe/tmux-fzf' 'wfxr/tmux-fzf-url' \
         'omerxx/tmux-sessionx' 'omerxx/tmux-floax' 'dracula/tmux'; do
  check "plugin '$p' declared" grep -qE "^\s*set -g @plugin '$p'" tmux/.tmux.conf
done

# Later tasks append AC-2 through AC-20.

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
```

- [ ] **Step 3:** `chmod +x scripts/test-plan-layer1b-ii.sh`

- [ ] **Step 4:** Run — AC-1 checks all fail. Exit 1.

- [ ] **Step 5: Commit**

```
git add scripts/test-plan-layer1b-ii.sh
git commit -m "test(plan-layer1b-ii): scaffold acceptance test script with AC-1"
```

---

## Task 1: Rewrite tmux/.tmux.conf with the plugin block (AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10)

**Files:**
- Modify: `tmux/.tmux.conf`
- Modify: `scripts/test-plan-layer1b-ii.sh`

- [ ] **Step 1: Add AC-2 through AC-10 checks to the test script** (before the summary):

```bash
# ── AC-2: TPM bootstrap is the last non-comment line ─────────────────────
echo ""
echo "AC-2: TPM bootstrap is last non-comment non-blank line"
last_line="$(awk '!/^[[:space:]]*#/ && NF' tmux/.tmux.conf | tail -1)"
if [[ "$last_line" == "run '~/.tmux/plugins/tpm/tpm'" ]]; then
  ok "TPM bootstrap is last effective line"
else
  nok "TPM bootstrap not last (got: $last_line)"
fi

# ── AC-3: sensible-overlap settings removed ──────────────────────────────
echo ""
echo "AC-3: sensible-overlap settings removed"
check "escape-time 10 is removed"  bash -c "! grep -qE 'set -sg escape-time 10' tmux/.tmux.conf"
check "history-limit 50000 removed" bash -c "! grep -qE 'set -g history-limit 50000' tmux/.tmux.conf"
check "default-terminal tmux-256color KEPT" \
  grep -qE 'set +-g +default-terminal +"tmux-256color"' tmux/.tmux.conf
check "xterm-kitty:RGB override KEPT" \
  grep -qE 'set +-sa +terminal-overrides +",xterm-kitty:RGB"' tmux/.tmux.conf

# ── AC-4: resurrect + continuum ──────────────────────────────────────────
echo ""
echo "AC-4: resurrect + continuum"
check "continuum-restore on"  grep -qE "@continuum-restore +'on'"  tmux/.tmux.conf
check "resurrect-strategy-nvim session" grep -qE "@resurrect-strategy-nvim +'session'" tmux/.tmux.conf

# ── AC-5: clipboard + detach-on-destroy ──────────────────────────────────
echo ""
echo "AC-5: clipboard + session destruction behaviour"
check "set-clipboard on"       grep -qE 'set +-g +set-clipboard +on'       tmux/.tmux.conf
check "detach-on-destroy off"  grep -qE 'set +-g +detach-on-destroy +off'  tmux/.tmux.conf

# ── AC-6: floax ──────────────────────────────────────────────────────────
echo ""
echo "AC-6: floax"
check "@floax-bind 'p'"          grep -qE "@floax-bind +'p'"          tmux/.tmux.conf
check "@floax-width '80%'"       grep -qE "@floax-width +'80%'"       tmux/.tmux.conf
check "@floax-height '80%'"      grep -qE "@floax-height +'80%'"      tmux/.tmux.conf
check "@floax-change-path true"  grep -qE "@floax-change-path +'true'" tmux/.tmux.conf

# ── AC-7: sessionx ───────────────────────────────────────────────────────
echo ""
echo "AC-7: sessionx"
check "@sessionx-bind 'o'"                 grep -qE "@sessionx-bind +'o'"                 tmux/.tmux.conf
check "@sessionx-zoxide-mode 'on'"         grep -qE "@sessionx-zoxide-mode +'on'"         tmux/.tmux.conf
check "@sessionx-window-height '85%'"      grep -qE "@sessionx-window-height +'85%'"      tmux/.tmux.conf
check "@sessionx-window-width '75%'"       grep -qE "@sessionx-window-width +'75%'"       tmux/.tmux.conf
check "@sessionx-filter-current 'false'"   grep -qE "@sessionx-filter-current +'false'"   tmux/.tmux.conf

# ── AC-8: fzf-url ────────────────────────────────────────────────────────
echo ""
echo "AC-8: fzf-url"
check "@fzf-url-history-limit '2000'" grep -qE "@fzf-url-history-limit +'2000'" tmux/.tmux.conf

# ── AC-9: Dracula plugin ─────────────────────────────────────────────────
echo ""
echo "AC-9: Dracula tmux plugin configuration"
check "@dracula-show-powerline true"    grep -qE '@dracula-show-powerline +true'    tmux/.tmux.conf
check '@dracula-plugins "git time"'     grep -qE '@dracula-plugins +"git time"'     tmux/.tmux.conf
check '@dracula-show-left-icon session' grep -qE '@dracula-show-left-icon +session' tmux/.tmux.conf
check '@dracula-military-time true'     grep -qE '@dracula-military-time +true'     tmux/.tmux.conf

# ── AC-10: manual theme removed ──────────────────────────────────────────
echo ""
echo "AC-10: hand-rolled catppuccin theme removed"
check "no status-style bg=#1e1e2e" bash -c "! grep -qE 'status-style.*#1e1e2e'  tmux/.tmux.conf"
check "no window-status-current-style #89b4fa" bash -c "! grep -qE 'window-status-current-style.*#89b4fa' tmux/.tmux.conf"
check "no remaining #1e1e2e or #89b4fa refs"   bash -c "! grep -qE '#1e1e2e|#89b4fa' tmux/.tmux.conf"
```

- [ ] **Step 2: Run — AC-2 through AC-10 fail.**

- [ ] **Step 3: Rewrite `tmux/.tmux.conf`.** Produce the following full file (replaces the current version — which had the hand-rolled status line and sensible-overlap settings):

```tmux
# .tmux.conf — tmux configuration
# See docs/plans/2026-04-12-shell-modernisation-design.md § 3.6 for the spec.
# Layer 1b-ii: TPM + plugins + Dracula tmux theme.

# ── Server and session settings ───────────────────────────────────────────────
# Settings NOT provided by tmux-sensible (kept explicit):
set  -g default-terminal   "tmux-256color"
set  -sa terminal-overrides ",xterm-kitty:RGB"
set  -g mouse              on
set  -g base-index         1
setw -g pane-base-index    1
set  -g renumber-windows   on
# Switch to the next session when one is killed instead of detaching.
set  -g detach-on-destroy  off
# OSC 52 clipboard passthrough (tmux-yank uses this on macOS + WSL2).
set  -g set-clipboard      on

# NOTE: the following settings were previously declared here but are now
# provided by tmux-plugins/tmux-sensible and removed to avoid duplication:
#   set -sg escape-time 10       (sensible: 0, faster vi-mode)
#   set -g history-limit 50000   (sensible: 50000 default)

# ── Prefix key ────────────────────────────────────────────────────────────────
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# ── Split creation (preserve cwd) ────────────────────────────────────────────
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# ── Pane navigation (prefix + vi keys) ───────────────────────────────────────
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# ── Pane resizing (repeatable) ────────────────────────────────────────────────
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r Right resize-pane -R 5   # Not L — prefix+L is last-window (see Workarounds)

# ── Copy mode (vi keys) ──────────────────────────────────────────────────────
setw -g mode-keys vi

bind Enter copy-mode
bind -T copy-mode-vi v      send-keys -X begin-selection
bind -T copy-mode-vi y      send-keys -X copy-selection-and-cancel
bind -T copy-mode-vi Escape send-keys -X cancel

# ── Session and config management ────────────────────────────────────────────
bind s choose-session
bind r source-file ~/.tmux.conf \; display-message "Config reloaded"

# ── vim-tmux-navigator ────────────────────────────────────────────────────────
# Seamless Ctrl+h/j/k/l navigation between vim and tmux panes.
# Uses BSD ps (macOS) with pgrep fallback (WSL2/containers).
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$' \
    || { tty='#{pane_tty}'; pgrep -t \"\${tty#/dev/}\" '(view|l?n?vim?x?|fzf)(diff)?' >/dev/null 2>&1; }"
bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'

# ── Workarounds ───────────────────────────────────────────────────────────────
# Ctrl+L is consumed by vim-tmux-navigator; restore via prefix + Ctrl+L
bind C-l send-keys C-l

# prefix + l is consumed by pane navigation; restore last-window via prefix + L
bind L last-window

# ── Plugin manager (TPM) ──────────────────────────────────────────────────────
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'fcsonline/tmux-thumbs'
set -g @plugin 'sainnhe/tmux-fzf'
set -g @plugin 'wfxr/tmux-fzf-url'
set -g @plugin 'omerxx/tmux-sessionx'
set -g @plugin 'omerxx/tmux-floax'
set -g @plugin 'dracula/tmux'

# ── Plugin configuration ──────────────────────────────────────────────────────
# Resurrect + Continuum (auto-save / restore).
# Continuum saves every 15m by default and restores on tmux start-up.
set -g @continuum-restore 'on'
set -g @resurrect-strategy-nvim 'session'

# Floax — prefix+p opens a floating pane. Does not shadow previous-window
# (we use prefix+h/j/k/l for navigation, not prefix+n/p).
set -g @floax-width '80%'
set -g @floax-height '80%'
set -g @floax-border-color 'magenta'
set -g @floax-text-color 'blue'
set -g @floax-bind 'p'
set -g @floax-change-path 'true'

# SessionX — prefix+o opens an fzf session picker with zoxide entries.
set -g @sessionx-bind 'o'
set -g @sessionx-zoxide-mode 'on'
set -g @sessionx-window-height '85%'
set -g @sessionx-window-width '75%'
set -g @sessionx-filter-current 'false'

# Thumbs — default trigger prefix+Space. Highlights URLs, hashes, paths.
# No override needed — defaults are what we want.

# fzf-url — prefix+u opens an fzf picker over URLs in scrollback.
set -g @fzf-url-fzf-options '-p 60%,30% --prompt="   " --border-label=" Open URL "'
set -g @fzf-url-history-limit '2000'

# Dracula tmux plugin (replaces the previous hand-rolled status line).
# Segments: git branch + clock. Military time avoids AM/PM ambiguity.
set -g @dracula-show-powerline true
set -g @dracula-plugins "git time"
set -g @dracula-show-left-icon session
set -g @dracula-military-time true

# ── TPM bootstrap (MUST be last line) ─────────────────────────────────────────
run '~/.tmux/plugins/tpm/tpm'
```

- [ ] **Step 4: Validate tmux syntax.** Requires `tmux` on PATH. If not available in CI, skip this local step; the test script's static greps will catch structural regressions.

```
tmux -f tmux/.tmux.conf -L test-layer1b-ii new-session -d \; kill-server
```

Expected: exit 0 (server starts, then exits cleanly). If it errors, the error output points to the offending line.

- [ ] **Step 5:** `bash scripts/test-plan-layer1b-ii.sh` → AC-1 through AC-10 pass.

- [ ] **Step 6: Commit**

```
git add tmux/.tmux.conf scripts/test-plan-layer1b-ii.sh
git commit -m "feat(tmux): add TPM + 10 plugins + Dracula theme, drop sensible overlap (Layer 1b-ii)"
```

---

## Task 2: Install TPM from install scripts (AC-11)

**Files:**
- Modify: `install-macos.sh`, `install-wsl.sh`
- Modify: `scripts/test-plan-layer1b-ii.sh`

- [ ] **Step 1: Add AC-11 checks**

```bash
# ── AC-11: TPM clone from install scripts ────────────────────────────────
echo ""
echo "AC-11: install scripts clone TPM idempotently"
check "install-macos.sh clones TPM" \
  grep -qE 'git clone https://github.com/tmux-plugins/tpm' install-macos.sh
check "install-macos.sh guards TPM clone on [[ ! -d ]]" \
  grep -PzoE '(?s)\[\[ ! -d "\$HOME/\.tmux/plugins/tpm" \]\][^\n]*\n[^\n]*git clone' install-macos.sh >/dev/null 2>&1
check "install-wsl.sh clones TPM" \
  grep -qE 'git clone https://github.com/tmux-plugins/tpm' install-wsl.sh
check "install-wsl.sh guards TPM clone on [[ ! -d ]]" \
  grep -PzoE '(?s)\[\[ ! -d "\$HOME/\.tmux/plugins/tpm" \]\][^\n]*\n[^\n]*git clone' install-wsl.sh >/dev/null 2>&1
check "install-wsl.sh mentions tmux-thumbs Rust caveat in next steps" \
  grep -qE 'tmux-thumbs.*Rust|Rust.*tmux-thumbs' install-wsl.sh
```

- [ ] **Step 2: Run — AC-11 fails.**

- [ ] **Step 3: Add TPM clone to install-macos.sh.** Insert AFTER the existing `brew bundle` success check (Step 1), BEFORE Step 2 (Post-brew tool installs):

```bash
# ── Step 1b: TPM (tmux plugin manager) ───────────────────────────────────
# TPM is not a brew formula. Clone directly; plugins install on first
# tmux launch with `prefix + I` (or continuum auto-restore). Idempotent.
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  log "installing TPM"
  if ! git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"; then
    warn "TPM clone failed — install manually before first tmux launch"
  fi
else
  log "TPM already installed at ~/.tmux/plugins/tpm"
fi
```

- [ ] **Step 4: Add the same TPM clone block to install-wsl.sh**, at the analogous location (after apt install in Step 1, before Step 2 release installs).

- [ ] **Step 5: Update post-install "Next steps" in install-wsl.sh.** Locate the trailing `cat <<EOF ... EOF` block and append a tmux-thumbs note. Find the existing "Layer 1a tools (manual install on WSL2 ..." block and replace it with:

```
Layer 1b-ii tmux plugins (first tmux launch):
  Inside tmux, press `prefix + I` (Ctrl-A then Shift-I) to install plugins.
  Note: tmux-thumbs compiles from source and requires a Rust toolchain.
  If compilation fails (common on stripped WSL images), install pre-built
  binary from https://github.com/fcsonline/tmux-thumbs/releases and drop
  it at ~/.tmux/plugins/tmux-thumbs/target/release/tmux-thumbs.
```

- [ ] **Step 6: Update install-macos.sh "Next steps"** with an equivalent tmux plugins instruction if not already present. Replace the existing "1. Switch shell" step ordering to include:

```
  2. Install tmux plugins (first tmux launch):
       prefix + I  (Ctrl-A then Shift-I)
     Note: tmux-thumbs requires a Rust toolchain to compile on macOS too.
     If compilation fails, install from:
       https://github.com/fcsonline/tmux-thumbs/releases
```

(Existing steps 2–5 renumber accordingly.)

- [ ] **Step 7: Syntax check**

`bash -n install-macos.sh && bash -n install-wsl.sh` → exit 0.

- [ ] **Step 8: Test**

`bash scripts/test-plan-layer1b-ii.sh` → AC-11 passes.

- [ ] **Step 9: Commit**

```
git add install-macos.sh install-wsl.sh scripts/test-plan-layer1b-ii.sh
git commit -m "feat(install): clone TPM + document tmux plugin install steps (Layer 1b-ii)"
```

---

## Task 3: Update BAT_THEME and FZF_DEFAULT_OPTS to Dracula (AC-12, AC-13, AC-18)

**Files:**
- Modify: `bash/.bashrc`
- Modify: `scripts/test-plan-layer1b-ii.sh`

- [ ] **Step 1: Add AC-12, AC-13 checks**

```bash
# ── AC-12: BAT_THEME = Dracula ───────────────────────────────────────────
echo ""
echo "AC-12: BAT_THEME is Dracula"
check "BAT_THEME=Dracula"  grep -qE 'export BAT_THEME="Dracula"' bash/.bashrc
check "old Monokai theme removed" bash -c '! grep -q "Monokai Extended" bash/.bashrc'

# ── AC-13: FZF_DEFAULT_OPTS has Dracula colors ───────────────────────────
echo ""
echo "AC-13: FZF_DEFAULT_OPTS Dracula palette"
check "FZF opts include fg:#f8f8f2"  grep -q 'fg:#f8f8f2' bash/.bashrc
check "FZF opts include bg:#282a36"  grep -q 'bg:#282a36' bash/.bashrc
check "FZF opts include hl:#bd93f9"  grep -q 'hl:#bd93f9' bash/.bashrc
check "FZF opts retain ctrl-j:down,ctrl-k:up" grep -q 'ctrl-j:down,ctrl-k:up' bash/.bashrc
check "FZF opts retain --height 40%"  grep -q 'height 40%' bash/.bashrc
check "FZF opts retain --layout=reverse" grep -q 'layout=reverse' bash/.bashrc

# ── AC-18: .bashrc still 14 sections ─────────────────────────────────────
echo ""
echo "AC-18: .bashrc structural invariants"
n=$(grep -c '^# ── [0-9]' bash/.bashrc)
if [[ "$n" -eq 14 ]]; then ok ".bashrc has 14 numbered sections"; else nok ".bashrc has $n sections"; fi
check "test-plan2.sh still passes" bash scripts/test-plan2.sh
```

- [ ] **Step 2: Run — AC-12 and AC-13 fail.**

- [ ] **Step 3: Edit section 11 of `bash/.bashrc`.** Replace the existing BAT_THEME line and the FZF_DEFAULT_OPTS block. Find:

```
export BAT_THEME="Monokai Extended"
```

Replace with:

```
export BAT_THEME="Dracula"
```

Find the existing `FZF_DEFAULT_OPTS` block (around lines 241-247):

```
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --info=inline
  --bind=ctrl-j:down,ctrl-k:up
'
```

Replace with:

```
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --info=inline
  --bind=ctrl-j:down,ctrl-k:up
  --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
  --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
  --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
  --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
'
```

- [ ] **Step 4: Syntax + structural check**

```
bash -n bash/.bashrc
grep -c '^# ── [0-9]' bash/.bashrc   # must still be 14
```

- [ ] **Step 5: Run test-plan2.sh**

`bash scripts/test-plan2.sh` → exit 0.

- [ ] **Step 6:** `bash scripts/test-plan-layer1b-ii.sh` → AC-12, AC-13, AC-18 pass.

- [ ] **Step 7: Commit**

```
git add bash/.bashrc scripts/test-plan-layer1b-ii.sh
git commit -m "style(bash): switch bat+fzf to Dracula palette (Layer 1b-ii)"
```

---

## Task 4: Update delta syntax-theme to Dracula (AC-14)

**Files:**
- Modify: `git/.gitconfig`
- Modify: `scripts/test-plan-layer1b-ii.sh`

- [ ] **Step 1: Add AC-14 check**

```bash
# ── AC-14: delta uses Dracula syntax theme ───────────────────────────────
echo ""
echo "AC-14: delta syntax-theme = Dracula"
check "git .gitconfig delta syntax-theme = Dracula" \
  bash -c "awk '/^\\[delta\\]/,/^\\[/' git/.gitconfig | grep -qE 'syntax-theme[[:space:]]*=[[:space:]]*Dracula'"
```

- [ ] **Step 2: Run — AC-14 fails.**

- [ ] **Step 3: Edit `git/.gitconfig`.** Find the `[delta]` section. Add or update the `syntax-theme` line to:

```ini
[delta]
  # existing keys preserved...
  syntax-theme = Dracula
```

If a previous `syntax-theme` exists with a different value, REPLACE the value. If no `syntax-theme` key exists, add it within the `[delta]` block.

Also add the `--hyperlinks-file-link-format` enhancement per design § 3.10.3 (makes paths clickable in kitty/iTerm):

```ini
  hyperlinks = true
  hyperlinks-file-link-format = "lazygit-edit://{path}:{line}"
```

- [ ] **Step 4: Smoke-check**

```
git config --file git/.gitconfig delta.syntax-theme
```

Expected: `Dracula`.

- [ ] **Step 5:** `bash scripts/test-plan-layer1b-ii.sh` → AC-14 passes.

- [ ] **Step 6: Commit**

```
git add git/.gitconfig scripts/test-plan-layer1b-ii.sh
git commit -m "style(git): switch delta syntax-theme to Dracula + enable hyperlinks (Layer 1b-ii)"
```

---

## Task 5: Update lazygit theme to Dracula (AC-15)

**Files:**
- Modify: `lazygit/config.yml`
- Modify: `scripts/test-plan-layer1b-ii.sh`

- [ ] **Step 1: Add AC-15 check.** Because yaml structure varies, use a broad content check:

```bash
# ── AC-15: lazygit Dracula theme ─────────────────────────────────────────
echo ""
echo "AC-15: lazygit Dracula theme colors"
check "lazygit theme activeBorderColor uses purple"  grep -qE 'activeBorderColor:.*#BD93F9|activeBorderColor:.*\bpurple\b' lazygit/config.yml
check "lazygit theme inactiveBorderColor uses comment"  grep -qE 'inactiveBorderColor:.*#6272A4|inactiveBorderColor:.*\bcomment\b' lazygit/config.yml
check "lazygit theme selectedLineBgColor uses current_line"  grep -qE 'selectedLineBgColor:.*#44475A|selectedLineBgColor:.*\bcurrent_line\b|selectedLineBgColor:.*\bbg\b' lazygit/config.yml
```

- [ ] **Step 2: Read existing lazygit config.** `cat lazygit/config.yml` to see the current structure and where the `gui` / `theme` section lives (or doesn't).

- [ ] **Step 3: Add or update the theme section.** Merge the Dracula theme block into the existing `gui:` section (or add the block if no `gui:` exists). Use the canonical lazygit Dracula theme (from `github.com/dracula/lazygit`). lazygit config uses a nested key structure; the canonical shape is:

```yaml
gui:
  theme:
    activeBorderColor:
      - '#BD93F9'
      - bold
    inactiveBorderColor:
      - '#6272A4'
    optionsTextColor:
      - '#F8F8F2'
    selectedLineBgColor:
      - '#44475A'
    selectedRangeBgColor:
      - '#44475A'
    cherryPickedCommitBgColor:
      - '#44475A'
    cherryPickedCommitFgColor:
      - '#BD93F9'
    unstagedChangesColor:
      - '#FF5555'
    defaultFgColor:
      - '#F8F8F2'
    searchingActiveBorderColor:
      - '#F1FA8C'
```

PRESERVE all other `gui.*` keys that already exist (pager, mouseEvents, etc.). Only add/replace the `theme:` child.

- [ ] **Step 4: YAML syntax check**

```
python3 -c 'import sys,yaml; yaml.safe_load(open("lazygit/config.yml"))' || \
  ruby -ryaml -e 'YAML.load_file("lazygit/config.yml")' || \
  echo "(no yaml parser available — relying on lazygit's own load)"
```

Expected: no error. If python/ruby unavailable, `lazygit --use-config-file lazygit/config.yml --version` will error on malformed YAML.

- [ ] **Step 5:** `bash scripts/test-plan-layer1b-ii.sh` → AC-15 passes.

- [ ] **Step 6: Commit**

```
git add lazygit/config.yml scripts/test-plan-layer1b-ii.sh
git commit -m "style(lazygit): switch theme to Dracula (Layer 1b-ii)"
```

---

## Task 6: Update kitty.conf for Dracula Pro + JetBrainsMono Nerd Font (AC-16)

**Files:**
- Modify: `kitty/kitty.conf`
- Create: `kitty/dracula-pro.conf`
- Modify: `scripts/test-plan-layer1b-ii.sh`
- Modify: `install-macos.sh` (symlink the new conf file)

- [ ] **Step 1: Add AC-16 checks**

```bash
# ── AC-16: kitty font + dracula-pro ──────────────────────────────────────
echo ""
echo "AC-16: kitty font and Dracula Pro"
check "kitty font_family = JetBrainsMono Nerd Font" \
  grep -qE '^font_family[[:space:]]+JetBrainsMono Nerd Font' kitty/kitty.conf
check "kitty disable_ligatures never"  grep -qE '^disable_ligatures[[:space:]]+never' kitty/kitty.conf
check "kitty includes dracula-pro.conf" grep -qE '^include[[:space:]]+dracula-pro\.conf' kitty/kitty.conf
check "kitty/dracula-pro.conf exists"   test -f kitty/dracula-pro.conf
check "dracula-pro.conf has foreground" grep -qE '^foreground[[:space:]]+#' kitty/dracula-pro.conf
check "dracula-pro.conf has background" grep -qE '^background[[:space:]]+#' kitty/dracula-pro.conf
check "install-macos.sh links dracula-pro.conf" \
  grep -qE 'link\s+kitty/dracula-pro\.conf' install-macos.sh
```

- [ ] **Step 2: Run — AC-16 fails.**

- [ ] **Step 3: Create `kitty/dracula-pro.conf`** using the Dracula Pro palette from design § 3.9. (The commercial Dracula Pro zip contains an official `.conf`; absent a license, a palette-accurate community reconstruction is used. This committed file is a palette-accurate reconstruction — not redistributed from the paid package.)

```
# kitty/dracula-pro.conf — Dracula Pro palette for kitty
# Palette values from docs/plans/2026-04-12-shell-modernisation-design.md § 3.9
# (Not redistributed from the paid Dracula Pro package — reconstructed from the
# public palette spec.)

foreground            #F8F8F2
background            #282A36
selection_foreground  #F8F8F2
selection_background  #44475A

url_color             #8BE9FD
cursor                #F8F8F2
cursor_text_color     #282A36

active_tab_foreground   #282A36
active_tab_background   #BD93F9
inactive_tab_foreground #F8F8F2
inactive_tab_background #44475A

# ANSI 16-color palette
color0  #21222C
color1  #FF5555
color2  #50FA7B
color3  #F1FA8C
color4  #BD93F9
color5  #FF79C6
color6  #8BE9FD
color7  #F8F8F2
color8  #6272A4
color9  #FF6E6E
color10 #69FF94
color11 #FFFFA5
color12 #D6ACFF
color13 #FF92DF
color14 #A4FFFF
color15 #FFFFFF
```

- [ ] **Step 4: Update `kitty/kitty.conf`.** Open the file, and at the TOP of the effective config (after any existing comments), set/replace the font and add the Dracula include:

```
# ── Font (Layer 1b-ii) ─────────────────────────────────────────────────
font_family      JetBrainsMono Nerd Font
font_size        13.0
disable_ligatures never

# ── Theme (Layer 1b-ii) ────────────────────────────────────────────────
include dracula-pro.conf
```

Remove/comment out any prior `font_family`, `include <other-theme>.conf`, or explicit color tables that conflict.

- [ ] **Step 5: Add symlink for the new conf file to install-macos.sh.** Near the existing `link kitty/kitty.conf` call:

```bash
link kitty/dracula-pro.conf  .config/kitty/dracula-pro.conf
```

- [ ] **Step 6: Add the same symlink to install-wsl.sh** (kitty is cross-platform).

- [ ] **Step 7:** `bash scripts/test-plan-layer1b-ii.sh` → AC-16 passes.

- [ ] **Step 8: Commit**

```
git add kitty/kitty.conf kitty/dracula-pro.conf install-macos.sh install-wsl.sh scripts/test-plan-layer1b-ii.sh
git commit -m "style(kitty): switch to JetBrainsMono Nerd Font + Dracula Pro (Layer 1b-ii)"
```

---

## Task 7: Extend `cheat tmux-plugins` + cheatsheet.md (AC-17)

**Files:**
- Modify: `bash/.bash_aliases`
- Modify: `docs/cheatsheet.md`
- Modify: `scripts/test-plan-layer1b-ii.sh`

- [ ] **Step 1: Add AC-17 checks**

```bash
# ── AC-17: cheat tmux-plugins subcommand ─────────────────────────────────
echo ""
echo "AC-17: cheat tmux-plugins case arm"
cheat_body() { awk '/^cheat\(\) \{/,/^\}/' bash/.bash_aliases | sed 's/#.*//'; }
if cheat_body | grep -qE '^[[:space:]]*tmux-plugins\)'; then
  ok "cheat: 'tmux-plugins' case arm present"
else
  nok "cheat: 'tmux-plugins' case arm present"
fi
check "tmux-plugins arm lists prefix+I"     bash -c "cheat_body() { awk '/^cheat\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//'; }; cheat_body | grep -q 'prefix + I'"
check "tmux-plugins arm lists prefix+p (floax)"     bash -c "cheat_body() { awk '/^cheat\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//'; }; cheat_body | grep -q 'prefix + p.*floax\\|floax.*prefix + p'"
check "tmux-plugins arm lists prefix+o (sessionx)"  bash -c "cheat_body() { awk '/^cheat\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//'; }; cheat_body | grep -q 'prefix + o.*sessionx\\|sessionx.*prefix + o'"
check "tmux-plugins arm lists prefix+Space (thumbs)" bash -c "cheat_body() { awk '/^cheat\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//'; }; cheat_body | grep -q 'prefix + Space'"
check "cheatsheet.md has tmux plugins section"  grep -qE '^### tmux plugin keybindings|^### tmux plugins' docs/cheatsheet.md
```

- [ ] **Step 2: Run — AC-17 fails.**

- [ ] **Step 3: Add `tmux-plugins)` arm to `cheat()` in bash/.bash_aliases.** Insert after the `tmux)` arm:

```bash
    tmux-plugins)
      cat <<'EOF'
tmux plugins (TPM + 10 plugins — see docs/plans § 3.6)
  prefix + I          install declared plugins
  prefix + U          update plugins
  prefix + alt+u      uninstall plugins not in config
  prefix + Space      tmux-thumbs — highlight URLs/paths/hashes on screen
  prefix + p          tmux-floax — toggle floating pane
  prefix + o          tmux-sessionx — session picker (zoxide-aware)
  prefix + u          tmux-fzf-url — URL picker over scrollback
  prefix + F          tmux-fzf — fuzzy tmux command runner
  prefix + Ctrl-S     tmux-resurrect — save session
  prefix + Ctrl-R     tmux-resurrect — restore session (continuum auto-restores too)
EOF
      ;;
```

Also add `tmux-plugins` to the help listing (search for `Per-tool subcommands:` inserted in 1b-i Task 8; append `, tmux-plugins`).

- [ ] **Step 4: Update `docs/cheatsheet.md`.** After `### Known friction points`, insert a new subsection:

```markdown
### tmux plugin keybindings

All bindings are relative to `prefix` (Ctrl-A).

| Action | Binding | Plugin |
|--------|---------|--------|
| Install plugins | `prefix + I` | TPM |
| Update plugins | `prefix + U` | TPM |
| Floating pane | `prefix + p` | tmux-floax |
| Session picker | `prefix + o` | tmux-sessionx |
| Highlight on-screen patterns | `prefix + Space` | tmux-thumbs |
| URL picker (scrollback) | `prefix + u` | tmux-fzf-url |
| Fuzzy tmux command | `prefix + F` | tmux-fzf |
| Save session | `prefix + Ctrl-S` | tmux-resurrect |
| Restore session | `prefix + Ctrl-R` | tmux-resurrect |
```

- [ ] **Step 5: Syntax check**

`bash -n bash/.bash_aliases` → exit 0.

- [ ] **Step 6:** `bash scripts/test-plan-layer1b-ii.sh` → AC-17 passes.

- [ ] **Step 7: Commit**

```
git add bash/.bash_aliases docs/cheatsheet.md scripts/test-plan-layer1b-ii.sh
git commit -m "docs(cheat): document tmux plugin keybindings (Layer 1b-ii)"
```

---

## Task 8: Preserve starship invariants (AC-19)

**Files:**
- Modify: `scripts/test-plan-layer1b-ii.sh`

This plan intentionally does NOT modify `starship/starship.toml` (Layer 1a already shipped the Dracula palette). This task just wires a guard so a later accidental edit wouldn't silently break test-plan6-8.

- [ ] **Step 1: Add AC-19 guard**

```bash
# ── AC-19: starship TOML section invariant preserved ─────────────────────
echo ""
echo "AC-19: starship structural invariants"
check "test-plan6-8.sh still passes" bash scripts/test-plan6-8.sh
```

- [ ] **Step 2: Run**

`bash scripts/test-plan-layer1b-ii.sh` → AC-19 passes.

- [ ] **Step 3: Commit**

```
git add scripts/test-plan-layer1b-ii.sh
git commit -m "test(plan-layer1b-ii): guard starship invariants (AC-19)"
```

---

## Task 9: Update verify.sh to check TPM presence (bonus coverage)

**Files:**
- Modify: `scripts/verify.sh`

- [ ] **Step 1: Add a "Layer 1b-ii" block** after the Layer 1b-i block (added in 1b-i Task 12):

```bash
# ── Layer 1b-ii (TPM + theming) ──────────────────────────────────────────
echo ""
echo "Layer 1b-ii:"
# shellcheck disable=SC2016  # $HOME expanded inside inner bash -c intentionally
check "TPM clone at ~/.tmux/plugins/tpm" \
  bash -c 'test -d "$HOME/.tmux/plugins/tpm"'
# shellcheck disable=SC2016
check "kitty dracula-pro.conf symlink resolves" \
  bash -c 'test -L "$HOME/.config/kitty/dracula-pro.conf" && test -e "$HOME/.config/kitty/dracula-pro.conf"'
# BAT_THEME env var check (indirect): .bashrc content
check "BAT_THEME is Dracula in tracked .bashrc" \
  grep -qE 'export BAT_THEME="Dracula"' "$REPO_ROOT/bash/.bashrc"
```

- [ ] **Step 2: Sanity-run**

`bash scripts/verify.sh || true` — expect PATH/TPM failures if the install hasn't been run locally, but no syntax errors.

- [ ] **Step 3: Commit**

```
git add scripts/verify.sh
git commit -m "feat(verify): add Layer 1b-ii TPM + kitty-theme checks"
```

---

## Task 10: End-to-end acceptance (AC-20)

**Files:**
- Modify: `scripts/test-plan-layer1b-ii.sh`

- [ ] **Step 1: Verify AC sequence is complete**

```
grep -E '^# ── AC-[0-9]+' scripts/test-plan-layer1b-ii.sh | sort -V
```

Expected: AC-1 through AC-20. If AC-20 itself isn't listed (it's the final summary, not its own block), that's fine — the composite pass count covers it.

- [ ] **Step 2: Run all safety checks**

```
bash scripts/test-plan-layer1b-ii.sh
```

Exit 0.

- [ ] **Step 3: Shellcheck sweep**

```
find . -type f -name '*.sh' -not -path './.worktrees/*' -print0 | xargs -0 shellcheck
```

Silent.

- [ ] **Step 4: Run every test-plan-*.sh script in safe mode**

```
for f in scripts/test-plan*.sh; do bash "$f" >/dev/null 2>&1 || echo "FAIL: $f"; done
```

No FAIL output. Particularly verify test-plan2, test-plan5 (tmux plan), and test-plan6-8 still pass — the tmux.conf rewrite could interact with test-plan5's expectations.

- [ ] **Step 5: If test-plan5 fails** (it likely tests line counts or specific bindings that moved), UPDATE test-plan5.sh's expectations to match the new file — do NOT revert the tmux.conf changes. Document the updates in the commit message.

- [ ] **Step 6: Commit (if updates needed)**

```
git add scripts/test-plan5.sh scripts/test-plan-layer1b-ii.sh
git commit -m "test(plan5): update expectations for Layer 1b-ii tmux plugin block"
```

---

## Post-plan: Manual Validation Steps

After CI passes, verify on macOS:

1. `bash install-macos.sh` — clones TPM, symlinks new `kitty/dracula-pro.conf`.
2. Launch kitty → Dracula Pro palette + JetBrainsMono Nerd Font visible.
3. `tmux` → prefix+I installs all plugins; Dracula status bar appears at bottom.
4. `prefix + p` opens floating pane.
5. `prefix + o` opens sessionx picker with zoxide entries.
6. `prefix + Space` highlights patterns on screen.
7. `prefix + u` picks URLs from scrollback.
8. `git diff` output uses Dracula syntax highlighting (delta).
9. `bat somefile` uses Dracula theme.
10. `fzf` prompts show Dracula colors.
11. `lazygit` shows Dracula borders/selection colors.
12. `cheat tmux-plugins` renders the keybinding table.

On WSL2: same, plus first-run of `prefix + I` may fail on tmux-thumbs if no Rust toolchain (expected; the fallback instruction is in the next-steps output).

---

## Self-Review Notes (at plan write time)

- **Spec coverage:** design §§ 3.6 (tmux plugins), 3.9 (Dracula rollout across bat/delta/fzf/kitty/lazygit/tmux), 4 (Layer 1b bullets 3 + Dracula), 5 (TPM clone in install scripts), 8.2 (cheatsheet tmux-plugins block) all mapped.
- **Scope boundary:** does NOT touch cable channels (1b-iii), gh-dash (1b-iii), sesh/yazi/jqp/diffnav (1b-i). Starship stays untouched (1a-shipped). Atuin/television themes untouched (already `dracula`).
- **Structural invariants:** `.bashrc` stays at 14 sections (changes are in §11). Starship stays at 11 TOML sections. `test-plan2.sh` and `test-plan6-8.sh` remain unmodified and must pass unchanged.
- **`test-plan5.sh` risk:** the tmux.conf rewrite may force updates to test-plan5's expectations. Task 10 explicitly plans for this.
- **Forward compat:** sesh session `[[window]]` blocks from 1b-i (editor/git/files) start working once tmux plugins land in 1b-ii (sessionx picks up the windows). No re-ordering needed — 1b-i shipped the sesh config already; 1b-ii just makes it cohesive.
- **Dracula Pro licensing:** `kitty/dracula-pro.conf` is a palette-accurate reconstruction from the design's public spec, not redistribution of the paid package. Noted in the file header. If the repo goes public, the file would need to be regenerated from the commercial package and gitignored.
- **No placeholders:** each task has actual file content and actual commands.
