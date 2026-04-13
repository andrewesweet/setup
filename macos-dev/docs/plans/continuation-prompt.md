# Continuation Prompt — Shell Modernisation & Tool Integration

Paste the text below into a clean Claude Code session to resume work.

---

## Prompt

I'm continuing a shell modernisation project for my macOS + WSL2 dotfiles repo.
All context is in the repo at `/home/sweeand/andrewesweet/setup/macos-dev/`.
Do not consult external sources — everything you need is in the repo.

### Required reading (in this order)

1. **`docs/plans/2026-04-12-shell-modernisation-design.md`** — the complete design
   doc (~1,800 lines). This is the spec. It has been through four adversarial
   reviews (UX, consistency, cross-platform, security), documentation verification
   against current upstream docs for every tool, and cross-integration research.
   All findings are incorporated. Status: Approved.

2. **`docs/superpowers/plans/2026-04-12-layer1a-atuin-television.md`** — the first
   implementation plan (~1,300 lines, 14 acceptance criteria, 13 ATDD tasks).
   Ready to execute.

3. **`bash/.bashrc`, `bash/.bash_aliases`, `Brewfile`, `tools.txt`, `install-macos.sh`,
   `install-wsl.sh`, `scripts/verify.sh`, `scripts/test-plan*.sh`** — current state.
   The design preserves these; new work layers on top.

### What the project is

Migrate from bash-only interactive shell to:
- **zsh** (primary interactive shell)
- **nushell** (first-class secondary shell, same integration quality as zsh)
- **bash** preserved as the scripting/CI shell (team default; `#!/usr/bin/env bash`
  in all shared scripts)

Along the way, integrate ~13 new CLI tools and ~10 tmux plugins, adopt Dracula Pro
theming with JetBrainsMono Nerd Font across the stack, and add six gh extensions.

### Non-negotiable principles from the design

- Bash is NEVER broken. Every bash change is opt-in via env var gates.
- Atuin is the SOLE owner of Ctrl-R. Television is the SOLE owner of Ctrl-T.
  Television's shell integration MUST NOT claim `command_history`.
- Atuin sync is DISABLED by default (`auto_sync = false`).
- rip2 graveyard is `~/.local/share/graveyard` (not /tmp).
- Nushell's native `ls` is preserved — NOT aliased to eza.
- zsh-syntax-highlighting MUST be sourced LAST in .zshrc.
- sesh `path` fields are ABSOLUTE — install script uses sed template substitution
  (no env var expansion in sesh.toml itself).
- Every tool in Brewfile has a matching entry in tools.txt. `scripts/check-tool-manifest.sh`
  enforces this. Every new tool requires both files updated.
- `link()` helper in install-macos.sh / install-wsl.sh is the symlink mechanism.
  NOT GNU Stow (evaluated and rejected — stow requires XDG-mirror structure;
  link() handles arbitrary mappings + backup/restore).

### Phased Implementation Order

Work one layer at a time. Validate each layer before starting the next.

**Layer 1a — atuin + television + Dracula starship** (plan written, ready)
- File: `docs/superpowers/plans/2026-04-12-layer1a-atuin-television.md`
- 13 tasks, 14 acceptance criteria, platform-aware test script
- Opt-in via `ENABLE_ATUIN=1` and `ENABLE_TV=1` in `~/.bashrc.local`
- No shell change yet — all bash-compatible
- Execution: subagent-driven-development (recommended) or executing-plans inline
- Validation: `bash scripts/test-plan-layer1a.sh` then `--full` mode

**Layer 1b — remaining shell-agnostic tools + tmux plugins + cable channels + gh extensions** (plan not yet written)
- Tools: sesh, yazi, xh, rip (cesarferreira — process killer), rip2 (MilesCranmer
  — safe rm), jqp, gh-dash, diffnav, carapace
- Tmux plugins via TPM: sensible, yank, resurrect, continuum, thumbs, tmux-fzf,
  fzf-url, sessionx, floax, dracula/tmux
- Television cable channels: ~30 channels incl. custom GCP ones (configs,
  instances, run-services, sql)
- gh extensions: gh-copilot, gh-poi, gh-markdown-preview, gh-grep, gh-aw, gh-token
- Dracula Pro theming across tools (see design § 3.9)
- Still in bash — opt-in gates remain
- Size: ~60-80 tasks. Consider splitting into 1b-i (tools), 1b-ii (tmux plugins +
  theming), 1b-iii (cable channels + gh extensions) when writing the plan.

**Layer 2 — zsh as login shell** (plan not yet written)
- 15-section `.zshrc` mirroring `.bashrc` structure (see design § 3.7)
- `.zsh_aliases` ported from `.bash_aliases` with adjustments:
  - Remove `fh` (replaced by atuin)
  - Add `http=xh`, `rrip=rip2 -u`, `ghd`, `dn`, `sx=sesh connect`, `sxl`, `jqi`, `y()`
  - gh extension aliases: `ghce`, `ghcs`, `ghp`, `ghmd`, `ghg`, `ghaw`
- zsh-autosuggestions + zsh-syntax-highlighting (last!)
- Completions: bundled init (atuin/tv/zoxide), separate fpath (bat/eza/fd),
  generated (mise/rg/xh/rip2/cog/uv), carapace backstop
- `chsh -s "$(which zsh)"` — platform-portable
- Size: ~30-40 tasks

**Layer 3 — nushell as first-class secondary** (plan not yet written)
- `config.nu` + `env.nu` (see design § 3)
- Cached init pattern using `$nu.cache-dir` (nushell-idiomatic)
- vi-mode with `jj` escape keybinding
- carapace as external completer with CARAPACE_BRIDGES
- yazi cd-on-quit nushell wrapper
- Native `ls` preserved; `ll/la/lt` use eza
- Size: ~25-35 tasks

**Future plans (out of scope until layers 1-3 land)** — see design Appendix C:
- macOS desktop environment (AeroSpace + SketchyBar) — separate plan cycle,
  macOS-only, orthogonal to shell work
- OpenCode ecosystem (ocx, opencode-scheduler, nickjvandyke/opencode.nvim primary
  candidates) — separate plan cycle, depends on zsh/nushell for notification hooks

**Explicitly out of scope (evaluated and rejected or deferred)**:
- fish shell (chose zsh+nushell instead, per conversation with user)
- GNU Stow (link() is better for this repo shape)
- catppuccin theming (switched to Dracula Pro)
- Apple container / apple/containerization (too alpha, macOS 26+ only)
- podman-desktop (duplicates lazydocker TUI; no current need)
- gh extensions beyond the 6 selected (gh-branch, gh-notify, gh-f, gh-pr-review
  overlap existing tools; gh-clean-branches superseded by gh-poi; gh-gonest narrow)
- Trunk vs individual linters (deferred; needs CI compatibility testing)
- Log tooling for GCP / Terraform / GHA (deferred; needs hands-on evaluation)

### What to do next

**Ask the user which of these to do**:

1. **Execute Layer 1a plan now.** Choose subagent-driven (fresh subagent per task,
   two-stage review — use `superpowers:subagent-driven-development`) or inline
   batch execution (use `superpowers:executing-plans`). Layer 1a is low-risk and
   lets the user validate atuin+television muscle memory before further commits.

2. **Write Layer 1b plan.** Larger scope. Consider splitting into three sub-plans
   (1b-i tools, 1b-ii tmux + theming, 1b-iii cable channels + gh extensions) so
   each is independently shippable. Use `superpowers:writing-plans`.

3. **Write Layer 2 plan.** Depends on Layer 1a landing (atuin/tv working in bash
   first proves the keybinding strategy).

4. **Add more late-arriving tooling** if the user wants. Historically the user has
   added several rounds of additions; watch for follow-up requests.

Do NOT automatically start executing anything. Always ask.

### Context summary from the prior session

- All adversarial reviews + doc verification + integration research already done
  and incorporated into the design. Do not redo them.
- The conversation produced ~40 resolved adversarial findings, 10 doc-verification
  corrections, and 9 concrete cross-integration decisions — all captured in the
  design appendices.
- Three design commits in git log: initial design, TODO appendix for macOS desktop
  + gh extensions, OpenCode ecosystem placeholder.
- The Layer 1a plan has been committed.
- User prefers Dracula Pro (paid v2.2.2 license) where available, Dracula free
  where not, custom Dracula palette as last resort. Font: JetBrainsMono Nerd Font
  with ligatures enabled.
- User's shell environment: Bash 5, starship, fzf, zoxide, tmux, kitty, well-
  structured dotfiles repo with `scripts/test-plan*.sh` as the ATDD convention.
- User has a Mac device AND WSL2 available for local testing; CI runs on both.
- User's corporate context: GCP, Kubernetes, Terraform, CyberArk PAM, corporate
  proxies. Security-conscious.
- User is a `/remote-control` user — multi-device session management may apply.

Begin by reading the design doc and Layer 1a plan. Summarise your understanding
back to me in 3-5 sentences. Then ask which of the four next-steps options to
pursue.

---

## End of continuation prompt.
