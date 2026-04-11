# Plans 14–16: Utility scripts, cheatsheet, README

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the remaining repo files — utility scripts (verify.sh, check-configs.sh), the cheatsheet reference document, and the repository README. These are the final implementation plans; after this, the dotfiles repo is complete.

**Architecture:** Two utility scripts in `scripts/`, one documentation file in `docs/`, one README at repo root. A combined smoke test validates all files. No install script modifications needed (these files are not symlinked).

**Tech Stack:** Bash (scripts), Markdown (cheatsheet, README)

**Design references:**
- `docs/design/install.md` — § verify.sh, § CI
- `docs/design/cheatsheet-spec.md` — full cheatsheet specification
- `docs/design/DESIGN.md` — repo structure, implementation order (steps 15–17)

**Design amendments:** None.

**Out of scope:**
- PDF generation (runtime operation, not config)
- Container base build in CI (already in verify.yml as a commented template)

**Prerequisites:**
- Plans 1–13 merged to `tool-verification-script`

**Branch strategy:** New worktree on branch `plan14-16-final` off `tool-verification-script`.

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `scripts/verify.sh` | Create | Post-install verification script |
| `scripts/check-configs.sh` | Create | Config parse validation |
| `docs/cheatsheet.md` | Create | Key bindings + tool reference |
| `README.md` | Create | Repository documentation |
| `scripts/test-plan14-16.sh` | Create | Smoke tests for all four files |
| `.github/workflows/verify.yml` | Modify | Add test-plan14-16.sh |

---

## Task 1: Create `scripts/verify.sh`

**Files:**
- Create: `macos-dev/scripts/verify.sh`

- [ ] **Step 1: Write verify.sh**

A post-install verification script that checks:
1. Symlink verification (platform-aware: macOS Library paths vs WSL .vscode-server paths)
2. `bash -n` on all bash config files (.bashrc, .bash_aliases, .bash_profile)
3. Config parse validation (calls check-configs.sh)
4. Tool availability spot-checks (git, delta, starship, mise, uv, fzf, bat, rg, fd)
5. Print remaining manual steps (Neovim LSP, opencode auth login, gcloud auth)

The script MUST:
- Start with `#!/usr/bin/env bash` and `set -euo pipefail`
- Detect platform (macOS vs WSL/Linux)
- Use colored output for pass/fail
- Exit 0 if all checks pass, 1 if any fail
- Print a summary at the end

- [ ] **Step 2: Make executable and syntax check**

```bash
chmod +x macos-dev/scripts/verify.sh
bash -n macos-dev/scripts/verify.sh
```

- [ ] **Step 3: Commit**

```bash
git add macos-dev/scripts/verify.sh
git commit -m "feat(scripts): add verify.sh post-install verification script"
```

---

## Task 2: Create `scripts/check-configs.sh`

**Files:**
- Create: `macos-dev/scripts/check-configs.sh`

- [ ] **Step 1: Write check-configs.sh**

A config validation script that checks:
1. `bash -n` on all bash config files
2. JSON validity of opencode.jsonc and tui.jsonc (strip comments, pipe to python3 json.load)
3. TOML validity of starship.toml and mise/config.toml (check for syntax errors via grep for common issues)
4. YAML validity of lazygit/config.yml and prek/.pre-commit-config.yaml (python3 yaml.safe_load)
5. JSON validity of vscode/settings.json and vscode/extensions.json

The script MUST:
- Start with `#!/usr/bin/env bash` and `set -uo pipefail`
- Use the same ok/nok/check pattern as other test scripts
- Exit 0 if all pass, 1 if any fail

- [ ] **Step 2: Make executable and syntax check**

```bash
chmod +x macos-dev/scripts/check-configs.sh
bash -n macos-dev/scripts/check-configs.sh
```

- [ ] **Step 3: Commit**

```bash
git add macos-dev/scripts/check-configs.sh
git commit -m "feat(scripts): add check-configs.sh config validation script"
```

---

## Task 3: Create `docs/cheatsheet.md`

**Files:**
- Create: `macos-dev/docs/cheatsheet.md`

- [ ] **Step 1: Write cheatsheet.md**

Write the cheatsheet per cheatsheet-spec.md. The document MUST have exactly two major sections:

**`## Key bindings`** — Page 1 (key bindings by action):
- Navigation table (Down/Up/Half page/etc across Shell, tmux, Neovim, lazygit, OpenCode, btop, lnav)
- Search table (Search/Next/Previous/Fuzzy across tools)
- Copy/yank table
- Quit/back table
- Known friction points table

**`## Tool reference`** — Page 2 (tool for the job):
- Searching table (fd, rg, fzf, zoxide)
- Git table (lazygit, delta, difftastic, cocogitto, git-cliff, critique)
- Formatting & Linting table (prek, pinact, zizmor)
- GCP table (gcloud, bq)
- Container table (dev, lazydocker, k9s)

All tables and content MUST match cheatsheet-spec.md exactly. The `cheat` function in .bash_aliases relies on the `## Key bindings` and `## Tool reference` headers being exactly as specified.

- [ ] **Step 2: Verify section headers**

Run: `grep -c '^## ' macos-dev/docs/cheatsheet.md`
Expected: At least `2` (Key bindings, Tool reference).

Run: `grep '## Key bindings' macos-dev/docs/cheatsheet.md`
Expected: At least one match.

Run: `grep '## Tool reference' macos-dev/docs/cheatsheet.md`
Expected: At least one match.

- [ ] **Step 3: Commit**

```bash
git add macos-dev/docs/cheatsheet.md
git commit -m "docs: add keybinding and tool reference cheatsheet"
```

---

## Task 4: Create `README.md`

**Files:**
- Create: `macos-dev/README.md`

- [ ] **Step 1: Write README.md**

The README MUST include:
1. **Title and description** — Personal dotfiles for macOS + WSL2 + Podman container
2. **Quick start** — Clone, install Homebrew, run install-macos.sh (macOS) or install-wsl.sh (WSL)
3. **What's included** — Brief list of all configured tools organized by category
4. **Repository structure** — Mirror the structure from DESIGN.md
5. **Configuration** — How to customize via .bashrc.local, .gitconfig.local, dev.env
6. **Container development** — `dev shell`, `dev build`, `dev init-machine`
7. **Cheatsheet** — `cheat`, `cheat keys`, `cheat tools` commands
8. **Design documents** — Link to docs/design/ files
9. **License** — MIT or similar (ask if not specified)

The README MUST NOT:
- Hardcode credentials or tokens
- Include API keys
- Duplicate the full design spec (link to it instead)

- [ ] **Step 2: Commit**

```bash
git add macos-dev/README.md
git commit -m "docs: add README with quick start, structure, and usage guide"
```

---

## Task 5: Create `scripts/test-plan14-16.sh` and wire into CI

**Files:**
- Create: `macos-dev/scripts/test-plan14-16.sh`
- Modify: `.github/workflows/verify.yml`

- [ ] **Step 1: Write smoke test**

The test MUST validate:
- verify.sh exists and is executable
- check-configs.sh exists and is executable
- Both scripts pass `bash -n` syntax check
- check-configs.sh runs successfully (validates all config files)
- cheatsheet.md exists and has both required section headers
- cheatsheet.md has key binding tables (grep for Navigation, Search, Copy, Quit headers)
- cheatsheet.md has tool reference tables (grep for Searching, Git, Formatting headers)
- README.md exists and has key sections (Quick start, What's included, Repository structure)
- cheatsheet.pdf in .gitignore
- Prior plan regression checks (link counts)

Target test count: ~40-50.

- [ ] **Step 2: Make executable, syntax check, run tests**

- [ ] **Step 3: Wire into CI**

Add to both lint and macos-verify jobs after Plan 13 step:
```yaml

      - name: Plans 14-16 scripts/cheatsheet/readme smoke tests
        run: bash macos-dev/scripts/test-plan14-16.sh
```

- [ ] **Step 4: Commit**

```bash
git add macos-dev/scripts/test-plan14-16.sh .github/workflows/verify.yml
git commit -m "test: add Plans 14-16 smoke tests and wire into CI"
```

---

## Task 6: Final verification

- [ ] **Step 1: Run all test suites**

```bash
bash macos-dev/scripts/test-plan14-16.sh
bash macos-dev/scripts/test-plan13.sh
bash macos-dev/scripts/test-plan12.sh
bash macos-dev/scripts/test-plan11.sh
bash macos-dev/scripts/test-plan10.sh
bash macos-dev/scripts/test-plan9.sh
bash macos-dev/scripts/test-plan6-8.sh
bash macos-dev/scripts/test-plan5.sh
bash macos-dev/scripts/test-plan4.sh
bash macos-dev/scripts/test-plan3.sh
bash macos-dev/scripts/test-plan2.sh
bash macos-dev/scripts/check-tool-manifest.sh
bash macos-dev/scripts/check-configs.sh
```

Expected: All pass.

- [ ] **Step 2: Confirm clean working tree and push**

---

## Success criteria

Plans 14–16 are complete when:

1. `verify.sh` checks symlinks, bash syntax, tool availability, and prints manual steps
2. `check-configs.sh` validates all config file formats (bash, JSON, TOML, YAML)
3. `cheatsheet.md` has `## Key bindings` and `## Tool reference` sections matching cheatsheet-spec.md
4. `README.md` has quick start, structure, configuration, and container sections
5. All smoke tests pass, CI wired
6. All prior plan regression tests pass
7. `check-configs.sh` passes when run as part of the test suite

This is the FINAL plan. After merging, the dotfiles repository implementation is complete.
