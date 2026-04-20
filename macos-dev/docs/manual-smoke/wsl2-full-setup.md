# WSL2 Full-Setup Test Plan

## Context

Desktop layers 1–3 and the LazyVim Extras adoption (PR #18) have been
smoke-tested on the Mac. The WSL2 host has never been end-to-end
validated against the current config — much of it (bash, git, tmux,
nvim, kitty, all the Layer 1a–1c tools) is shared between platforms.

Before continuing Mac smoke-testing, validate the whole setup on WSL2.
Fix any WSL2-specific regressions here, then return to Mac.

Host under test: current WSL2 Ubuntu instance (destructive reinstall on
top of existing dotfiles — backup first).

---

## Pre-flight: review of WSL-sensitive config

**kitty/kitty.conf (macos-dev/kitty/kitty.conf)**
- `copy_on_select clipboard` — on WSL2 via WSLg this copies to the
  Wayland clipboard (not Windows system clipboard). OSC 52 via tmux is
  the cross-env path. Documented in inline comment.
- `include ~/.config/kitty/dracula-pro.generated.conf` — generated at
  install time; must exist before kitty starts cleanly.
- No explicit GPU / image_protocol / linux_display_server overrides —
  kitty uses defaults under WSLg.

**bash/.bashrc**
- Lines 11–12: `_OS=wsl` branch driven by `WSL_DISTRO_NAME`.
- Lines 199–215: OSC 9 notification guard. Enabled when terminal is
  WezTerm / iTerm.app / vscode / xterm-kitty / Windows Terminal
  (`WT_SESSION`) / manual override (`NOTIFY_OSC9=1`).

**install-wsl.sh**
- 44 `link` entries → 44 dotfile paths get symlinked (full list in
  Phase 0 backup section).
- Apt installs: bash bash-completion git tmux tree wget curl jq
  shellcheck direnv.
- GitHub release installs (via `gh_release_install` helper): atuin, tv,
  xh, sesh, yazi, rip2, jqp, diffnav, carapace.
- Post-bootstrap: uv tools (ty, prek, pygments-dracula-pro-local),
  bun global (opencode-ai, critique), gh extensions (7 of them), TPM
  clone.

---

## Phase 0 — Backup (one-time, ~2 min)

Take a snapshot of every path install-wsl.sh will write to, plus the
nvim config (linked as a directory) and the two dracula-pro generated
files that live under `~/.config/kitty/` and `~/.config/starship/`.

```bash
BACKUP="$HOME/wsl2-pretest-$(date +%Y%m%d-%H%M%S).tgz"
tar czvf "$BACKUP" \
  --ignore-failed-read \
  -C "$HOME" \
  .bash_aliases .bash_profile .bashrc .inputrc \
  .dir_colors .gitconfig .gitignore_global .jqp.yaml \
  .pre-commit-config.yaml .tmux.conf \
  .config/atuin .config/bat .config/btop .config/diffnav \
  .config/freeze .config/gh-dash .config/glow .config/httpie \
  .config/k9s .config/kitty .config/lazydocker .config/lazygit \
  .config/mise .config/nvim .config/opencode .config/ripgrep \
  .config/starship.toml .config/television .config/yazi \
  .lnav .local/bin/dev \
  .tmux/plugins \
  .vscode-server/data/Machine 2>&1 | tail -20
ls -lh "$BACKUP"
```

Rollback command (run only if Phase 4–8 reveal breakage):
```bash
tar xzvf "$BACKUP" -C "$HOME"
```

---

## Phase 1 — Static pre-install validation (~30 s)

All 18 WSL-relevant test-plan scripts must pass *before* install. This
establishes the baseline.

```bash
cd /home/sweeand/andrewesweet/setup/macos-dev
FAILED=()
for f in scripts/test-plan{1,2,3,4,5,9,10,11,12,13}.sh \
         scripts/test-plan{6-8,14-16}.sh \
         scripts/test-plan-layer1a.sh \
         scripts/test-plan-layer1b-i.sh \
         scripts/test-plan-layer1b-ii.sh \
         scripts/test-plan-layer1b-iii.sh \
         scripts/test-plan-layer1c.sh \
         scripts/test-plan-theming.sh; do
  bash "$f" >/dev/null 2>&1 || FAILED+=("$f")
done
[[ ${#FAILED[@]} -eq 0 ]] && echo "ALL 18 PASS" || printf 'FAIL: %s\n' "${FAILED[@]}"
```

STOP if any fail — fix before proceeding. (Exception: test-plan10 only
passes on `feature/editor-lazyvim-extras`, not main. Check out that
branch for the run.)

---

## Phase 2 — Install (~5–15 min)

```bash
cd /home/sweeand/andrewesweet/setup/macos-dev
bash install-wsl.sh 2>&1 | tee /tmp/install-wsl.log
echo "EXIT=$?"
```

Post-install checks:
```bash
grep -E 'FAIL|ERROR|could not|not found' /tmp/install-wsl.log || echo "log clean"
grep '^warn:' /tmp/install-wsl.log          # tolerate warns, but read them
grep '^  linked' /tmp/install-wsl.log | wc -l   # expect ≥ 40 lines
```

Expected warnings (not failures):
- `bun not available` → only if bun isn't installed on this host yet
- `uv not available` → only if uv isn't installed
- gh extensions that 404 behind corporate proxy

Hard failures to chase:
- `apt install failed` — stop, investigate
- `gh_release_install: cannot reach GitHub API` — network issue
- `err:` lines — anything that exits the script

---

## Phase 3 — Static post-install validation (~30 s)

Re-run the same 18 scripts. All must still pass after install.

```bash
# (same loop as Phase 1)
```

---

## Phase 4 — Shell runtime smoke (~3 min)

Fresh login shell, verify each section of .bashrc loads without error.

```bash
bash -l -c 'echo $_OS'                 # → wsl
bash -l -c 'type ll && type gs'        # aliases exist
bash -l -c 'starship --version'        # starship on PATH
bash -l -c 'atuin --version'           # atuin on PATH
bash -l -c 'which carapace'            # carapace on PATH
bash -l -c 'echo "section count: $(grep -c "^# ── [0-9]" ~/.bashrc)"'  # → 14
```

Interactive checks (open a new terminal):
- [ ] Starship prompt renders with Dracula Pro colors (not plain `$ `)
- [ ] `Ctrl-R` opens atuin history UI
- [ ] `git che<Tab>` triggers carapace completions (checkout, cherry-pick, …)
- [ ] `bat /etc/hosts` — Dracula theme visible
- [ ] `ls --color=auto /tmp` — directory color matches Dracula palette
- [ ] `tv` launches television fuzzy finder

---

## Phase 5 — Tmux runtime smoke (~5 min)

```bash
tmux kill-server 2>/dev/null
tmux new-session -d -s smoketest
tmux list-plugins 2>/dev/null || echo "list-plugins unavailable — normal for TPM"
```

Interactive (attach with `tmux attach -t smoketest`):
- [ ] Status bar renders Dracula Pro (fg #F8F8F2, bg #22212C)
- [ ] `prefix + I` installs all declared plugins (first-run only)
- [ ] `prefix + p` opens floax
- [ ] `prefix + o` opens sessionx
- [ ] `prefix + Space` opens tmux-thumbs
- [ ] `cheat tmux-plugins` prints the keybinding summary (from
      bash/.bash_aliases; references docs/cheatsheet.md)
- [ ] Resurrect: save (`prefix + Ctrl-s`), kill session, reattach,
      restore (`prefix + Ctrl-r`) — windows/panes come back

---

## Phase 6 — Neovim (LazyVim) runtime smoke (~10 min)

> **Branch gate:** PR #18 (feature/editor-lazyvim-extras) is the
> current target nvim config. If testing pre-merge, check out that
> branch first: `git checkout feature/editor-lazyvim-extras`. If
> already merged to main, skip.

First launch seeds the lockfile and installs plugins:
```bash
nvim +Lazy +qall
```

Interactive checks (`nvim` in a dev directory):
- [ ] `:Lazy` — 13 Extras enabled (lazyvim.json), no red errors
- [ ] `:checkhealth` — no **red** errors under lsp, treesitter, lazy.
      Documented warnings OK: luarocks, Snacks.image, Node/Perl/Ruby
      providers, keymap overlaps.
- [ ] `.py` file → `:lua for _,c in pairs(vim.lsp.get_clients({bufnr=0})) do print(c.name) end`
      prints only `ty` and `ruff` (no `pyright`, no `basedpyright`).
- [ ] `.go` file → gopls attaches; `:LazyExtras` shows lang.go enabled.
- [ ] `.sh` file → bashls attaches; shellcheck diagnostics appear on
      lint errors (e.g. `if [ $var = foo ]`).
- [ ] `.github/workflows/verify.yml` → filetype is `yaml.github`;
      gh_actions_ls + actionlint fire.
- [ ] Misformatted `.yaml` file on save → yamlfmt reformats.
- [ ] `<leader>ff/fs/fb/fh/fr/fc/fd/fw` — all eight FZF keymaps fire.
      (`<leader>fz` zoxide requires zoxide history first; skip if
      fresh machine.)
- [ ] `gsa`/`gsd`/`gsr` — mini.surround add/delete/replace.
- [ ] Harpoon: `<leader>ha` adds file, `<leader>hH` opens menu,
      `<leader>h1`/`h2` jumps to file 1/2.

---

## Phase 7 — Kitty runtime smoke (~3 min)

> Kitty on WSL2 runs under WSLg. Graphics rendering uses Wayland.
> No special GPU/image_protocol overrides are set — defaults are
> fine for WSLg.

```bash
ls -la ~/.config/kitty/kitty.conf                     # symlink to repo
ls ~/.config/kitty/dracula-pro.generated.conf        # generated by install
kitty --debug-config 2>&1 | grep -E 'font|background|foreground' | head -10
```

Interactive (launch kitty fresh from Windows):
- [ ] Kitty window opens, no error dialog
- [ ] Font renders as JetBrainsMono Nerd Font (icons visible in
      `ls --color=auto` output — check for nf-* glyph rendering)
- [ ] Background is Dracula Pro bg (#22212C), not default black
- [ ] `ctrl+shift+t` opens new tab in cwd
- [ ] `ctrl+shift+=` / `ctrl+shift+-` resizes font
- [ ] Select text → auto-copied to Wayland clipboard (paste in same
      kitty window works); cross to Windows clipboard only via tmux
      OSC 52 (not a bug — documented).
- [ ] OSC 9 notification: run `sleep 11; echo done` in kitty, confirm
      Windows notification fires at exit (OSC 9 supported in kitty via
      `TERM=xterm-kitty` guard in .bashrc line 209).

---

## Phase 8 — Integrations (~10 min)

```bash
ghq --version && lazygit --version && gh --version
sesh --version && tv --version && gh dash --help >/dev/null && echo "all present"
```

Interactive:
- [ ] `ghq get https://github.com/sharkdp/bat` clones to
      `~/ghq/github.com/sharkdp/bat`
- [ ] `lazygit` inside a repo launches Dracula-themed TUI
- [ ] `sesh connect $(sesh list | fzf)` switches tmux sessions
- [ ] `gh dash` opens the PR / issue dashboard
- [ ] `mise use` in a directory with `.mise.toml` installs pinned
      versions
- [ ] `opencode` launches (if bun global install succeeded in Phase 2)

---

## Phase 9 — Rollback (only if breakage)

```bash
tar xzvf "$BACKUP" -C "$HOME"
```

Restore = full revert to pre-test state. Re-run Phase 1 scripts to
confirm baseline.

---

## Appendix A — Pass/fail ledger

Record the result of each phase. A single-line-per-phase summary is
enough; paste the output of failing commands verbatim.

```
Phase 0 backup path : ________________________
Phase 1 static pre  : [ ] PASS  [ ] FAIL — details:
Phase 2 install     : [ ] PASS  [ ] FAIL — details:
Phase 3 static post : [ ] PASS  [ ] FAIL — details:
Phase 4 shell       : [ ] PASS  [ ] FAIL — details:
Phase 5 tmux        : [ ] PASS  [ ] FAIL — details:
Phase 6 nvim        : [ ] PASS  [ ] FAIL — details:
Phase 7 kitty       : [ ] PASS  [ ] FAIL — details:
Phase 8 integrations: [ ] PASS  [ ] FAIL — details:
```

## Appendix B — Known non-blockers

- `:checkhealth` warnings for Snacks.image (magick/gs/tectonic
  missing), luarocks, Perl/Ruby/Node providers — optional features
  we don't use.
- `opencode.nvim [snacks]: snacks.picker is disabled` — expected;
  we use fzf-lua via the editor.fzf Extra.
- `<leader>fz` with no zoxide history does nothing — populate by
  using zoxide first.
- `tmux-thumbs` Rust build caveat on WSL2 — the plugin ships a
  precompiled binary for some arches; if the binary is missing on
  your arch, `prefix + Space` silently does nothing. Known issue,
  noted in install-wsl.sh.
- bun global install CA cert path (seen on Mac smoke) — Linux bun
  uses system trust store, not the macOS-specific `~/db-ca-bundle.pem`
  path. Should not reproduce on WSL2.
