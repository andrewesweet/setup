# Layer 1b-iii Implementation Plan: television cable channels + gh extensions + gh-dash

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the complete set of television cable channels (files, dirs, env, alias, git-branch/diff/log/stash/worktrees/reflog/remotes/repos, docker-containers/images, k8s-pods/contexts, make-targets, ssh-hosts, procs, gcloud-configs/instances/run-services/sql) and six GitHub CLI extensions (gh-dash, gh-copilot, gh-poi, gh-markdown-preview, gh-grep, gh-aw, gh-token) with aliases, configuration, and Dracula theming.

**Architecture:** Cable channels are TOML files at `television/cable/<name>.toml`. The directory is symlinked as a whole (`link television/cable .config/television/cable`) so new channels added later require no re-symlink. `git-repos.toml` sources directly from `ghq list --full-path` (Layer 1c is shipped; this is a hard dependency, not a forward reference). gh extensions install via `gh extension install <owner>/<repo>` from install scripts, gated on `command -v gh`. gh-dash has a YAML config with the `C` binding that opens the selected PR in OpenCode via `tmux new-window`. All aliases go in `bash/.bash_aliases`; new cheat subcommand `gh-ext` lists installed extensions via `gh extension list`.

**Tech Stack:** television (>= 0.11), gh CLI (>= 2.40), bash, brew, podman (cable channels use podman — matches existing setup).

**Spec reference:** `docs/plans/2026-04-12-shell-modernisation-design.md` §§ 3.2 (cable channels), 3.5 (gh-dash), 3.8 (aliases), 3.11 (ghq — consumed here), 4 (Layer 1b bullet 2), 7.2 (cable channel safety), Appendix C "gh Extensions — Layer 1b scope".

**Platform scope:** macOS + WSL2. Cable channels source from tools (`git`, `kubectl`, `podman`, `gcloud`, `ssh`) — gracefully no-op when the underlying tool isn't installed (television just shows empty results).

**Prerequisites:** Layers 1a, 1c, 1b-i merged. 1b-ii is a sibling (independent). `git-repos.toml` REQUIRES ghq (Layer 1c) — this plan fails the channel AC if ghq is absent in `--full` mode.

---

## Acceptance Criteria (Specification by Example)

**AC-1: All cable channel files exist**
```
Given: television/cable/
When: inspected
Then: the following .toml files exist (22 channels):
  alias, env, dirs, files, procs,
  git-branch, git-diff, git-log, git-stash, git-worktrees, git-reflog, git-remotes, git-repos,
  docker-containers, docker-images,
  k8s-pods, k8s-contexts,
  make-targets, ssh-hosts,
  gcloud-configs, gcloud-instances, gcloud-run-services, gcloud-sql
```

**AC-2: television/cable is symlinked as a directory**
```
Given: install-macos.sh and install-wsl.sh
When: grepped
Then: a `link television/cable .config/television/cable` call exists in both
(directory symlink means future cable-file additions require no re-wire)
```

**AC-3: git-repos.toml sources from `ghq list --full-path`**
```
Given: television/cable/git-repos.toml
When: inspected
Then: the source.command field contains `ghq list --full-path`
And: does NOT contain `fd .git$` or similar pre-1c fallback
```

**AC-4: env.toml filters sensitive variable patterns**
```
Given: television/cable/env.toml
When: inspected
Then: the source.command includes a grep/sed filter that excludes patterns:
  GITHUB_TOKEN, GH_TOKEN, AWS_.*, SECRET, PASSWORD, KEY, BEARER, AUTHORIZATION, ANTHROPIC, OPENAI
```

**AC-5: procs.toml uses POSIX-compatible ps flags**
```
Given: television/cable/procs.toml
When: inspected
Then: the source.command uses `ps -e -o pid=,ucomm=` (POSIX-portable)
And: does NOT use GNU-only flags like `--no-headers` or `-o comm` without `=`
```

**AC-6: docker-*.toml channels use podman, not docker**
```
Given: television/cable/docker-containers.toml and docker-images.toml
When: inspected
Then: both source.command fields start with `podman `
And: neither mentions `docker ` (bare docker) as the source command
```

**AC-7: gcloud-*.toml channels exist with the expected commands**
```
Given: television/cable/gcloud-configs.toml, gcloud-instances.toml,
       gcloud-run-services.toml, gcloud-sql.toml
When: inspected
Then: each file exists
And: each source.command uses `gcloud ... --format='value(...)'`
And: each channel has an action that invokes a gcloud subcommand on the selection
```

**AC-8: gh-dash config exists and is correct**
```
Given: gh-dash/config.yml
When: inspected
Then: a prSections array has at least three sections (My PRs, Needs Review, Involved)
And: defaults.view = prs
And: pager.diff = diffnav
And: keybindings.universal has an entry with name: "lazygit"
And: keybindings.prs has a `C` binding that opens the PR in opencode via tmux new-window
And: a theme section uses Dracula colors (via the `dracula/gh-dash` palette)
And: install-macos.sh and install-wsl.sh both link it to .config/gh-dash/config.yml
```

**AC-9: install scripts install all gh extensions**
```
Given: install-macos.sh and install-wsl.sh
When: grepped
Then: both contain `gh extension install` calls for:
  dlvhdr/gh-dash
  github/gh-copilot
  seachicken/gh-poi
  yusukebe/gh-markdown-preview
  k1Low/gh-grep                (OR k1low/gh-grep — accept either case)
  github/gh-aw
  Link-/gh-token
And: each call is wrapped in a `command -v gh &>/dev/null` guard
And: each call ends with `|| true` or equivalent (extension already installed is not an error)
```

**AC-10: new aliases exist with exact definitions**
```
Given: bash/.bash_aliases
When: grepped
Then: alias ghd='gh dash'
And: alias ghce='gh copilot explain'
And: alias ghcs='gh copilot suggest'
And: alias ghp='gh poi'
And: alias ghmd='gh markdown-preview'
And: alias ghg='gh grep'
And: alias ghaw='gh aw'
And: no alias for gh-token (it's automation-only per design Appendix C)
```

**AC-11: cheat() has a `gh-ext` subcommand and channel-trigger subcommand**
```
Given: bash/.bash_aliases cheat() body
When: inspected
Then: case arm `gh-ext)` exists and runs `gh extension list`
And: case arm `ghd)` references gh-dash keybindings (including C for opencode)
And: case arm `channels)` or `tv-channels)` exists listing the cable-channel triggers
```

**AC-12: cheatsheet.md has TV channel trigger + gh-dash workflow sections**
```
Given: docs/cheatsheet.md
When: inspected
Then: a "Television channel triggers" subsection lists each triggered channel with its command
And: a "gh-dash workflow" subsection documents Enter/G/C bindings
And: a row exists for each new gh alias (ghd, ghce, ghcs, ghp, ghmd, ghg, ghaw)
```

**AC-13: verify.sh checks all Layer 1b-iii artefacts**
```
Given: scripts/verify.sh
When: inspected
Then: a Layer 1b-iii block exists
And: it checks the television/cable symlink resolves as a directory
And: it checks gh-dash config symlink resolves
And: it checks for each gh extension via `gh extension list` (full mode only, skipped in safe mode)
```

**AC-14: structural invariants preserved**
```
When: bash scripts/test-plan2.sh runs
Then: exit 0 (.bashrc still 14 sections — no new sections added)

When: bash scripts/test-plan6-8.sh runs
Then: exit 0 (starship unchanged)
```

**AC-15: End-to-end acceptance script enumerates every AC**
```
When: bash scripts/test-plan-layer1b-iii.sh runs
Then: every AC is checked
And: exit 0 if all pass, 1 otherwise
```

---

## File Structure

**New files (television cable channels, 22 TOML files):**
- `television/cable/alias.toml`
- `television/cable/env.toml`
- `television/cable/dirs.toml`
- `television/cable/files.toml`
- `television/cable/procs.toml`
- `television/cable/git-branch.toml`
- `television/cable/git-diff.toml`
- `television/cable/git-log.toml`
- `television/cable/git-stash.toml`
- `television/cable/git-worktrees.toml`
- `television/cable/git-reflog.toml`
- `television/cable/git-remotes.toml`
- `television/cable/git-repos.toml`
- `television/cable/docker-containers.toml`
- `television/cable/docker-images.toml`
- `television/cable/k8s-pods.toml`
- `television/cable/k8s-contexts.toml`
- `television/cable/make-targets.toml`
- `television/cable/ssh-hosts.toml`
- `television/cable/gcloud-configs.toml`
- `television/cable/gcloud-instances.toml`
- `television/cable/gcloud-run-services.toml`
- `television/cable/gcloud-sql.toml`

**New files (gh-dash + tests):**
- `gh-dash/config.yml`
- `scripts/test-plan-layer1b-iii.sh`

**Modified:**
- `bash/.bash_aliases` — seven new gh aliases + extended `cheat()` with `gh-ext`, `ghd`, `channels` arms
- `install-macos.sh` — symlinks for `television/cable` dir + `gh-dash/config.yml`; `gh extension install` block
- `install-wsl.sh` — same
- `docs/cheatsheet.md` — TV channel triggers + gh-dash workflow + new alias rows
- `scripts/verify.sh` — Layer 1b-iii block

**Untouched:**
- `bash/.bashrc`, `tmux/.tmux.conf`, `starship/starship.toml`, `atuin/config.toml`, `television/config.toml`, `git/.gitconfig`, all 1b-i tool configs

---

## Task 0: Bootstrap acceptance test script (Red)

**Files:**
- Create: `scripts/test-plan-layer1b-iii.sh`

- [ ] **Step 1: Skeleton** — copy preamble 1–55 from `scripts/test-plan-layer1a.sh`. Header: "test-plan-layer1b-iii.sh — acceptance tests for Layer 1b-iii (cable channels + gh extensions + gh-dash)".

- [ ] **Step 2: Banner + AC-1 stub**

```bash
echo "Layer 1b-iii acceptance tests (TV cable channels + gh extensions + gh-dash)"
echo "Platform: $PLATFORM    Mode: $([ "$FULL" = true ] && echo "full" || echo "safe")"
echo ""

# ── AC-1: all cable channel files exist ──────────────────────────────────
echo "AC-1: cable channel files"
for c in alias env dirs files procs \
         git-branch git-diff git-log git-stash git-worktrees \
         git-reflog git-remotes git-repos \
         docker-containers docker-images \
         k8s-pods k8s-contexts \
         make-targets ssh-hosts \
         gcloud-configs gcloud-instances gcloud-run-services gcloud-sql; do
  check "television/cable/$c.toml exists" test -f "television/cable/$c.toml"
done

# Later tasks append AC-2 through AC-15.

echo ""
echo "─────────────────────────────────────────────────────────────"
printf "Passed: ${C_GREEN}%d${C_RESET}  Failed: ${C_RED}%d${C_RESET}  Skipped: ${C_YELLOW}%d${C_RESET}\n" "$pass" "$fail" "$skip"
(( fail == 0 ))
```

- [ ] **Step 3:** `chmod +x scripts/test-plan-layer1b-iii.sh`.

- [ ] **Step 4:** Run — AC-1 checks fail (no channel files yet). Exit 1.

- [ ] **Step 5: Commit**

```
git add scripts/test-plan-layer1b-iii.sh
git commit -m "test(plan-layer1b-iii): scaffold acceptance test script with AC-1"
```

---

## Task 1: Create cable channel files (AC-1, AC-3, AC-4, AC-5, AC-6, AC-7)

This is the bulk of the plan — 22 channel files. Each channel has this canonical shape:

```toml
[metadata]
name = "<channel>"
description = "..."
requirements = ["<tool>"]  # optional

[source]
command = "<shell pipeline>"

[preview]
command = "<preview pipeline>"  # optional

[actions.<name>]
command = "<action pipeline>"
```

Channel files use Dracula via the TV main config's `theme = "dracula"` (Layer 1a already set this). Per-channel theming isn't needed.

**Files:**
- Create: 22 files under `television/cable/`
- Modify: `scripts/test-plan-layer1b-iii.sh`

- [ ] **Step 1: Create `television/cable/` directory**

```
mkdir -p television/cable
```

- [ ] **Step 2: Add AC-3 through AC-7 checks** (before the summary):

```bash
# ── AC-3: git-repos.toml sources from ghq ────────────────────────────────
echo ""
echo "AC-3: git-repos channel sources from ghq list --full-path"
check "git-repos.toml uses 'ghq list --full-path'" \
  grep -qE 'ghq list --full-path' television/cable/git-repos.toml
check "git-repos.toml has no pre-1c fd fallback" \
  bash -c "! grep -qE 'fd.*\\.git\\\$' television/cable/git-repos.toml"

# ── AC-4: env.toml filters secrets ───────────────────────────────────────
echo ""
echo "AC-4: env.toml filters sensitive patterns"
for p in GITHUB_TOKEN GH_TOKEN 'AWS_' SECRET PASSWORD KEY BEARER AUTHORIZATION ANTHROPIC OPENAI; do
  check "env.toml filter covers $p" grep -qE "$p" television/cable/env.toml
done

# ── AC-5: procs.toml uses POSIX ps flags ─────────────────────────────────
echo ""
echo "AC-5: procs.toml POSIX ps flags"
check "procs.toml uses 'ps -e -o pid=,ucomm='" \
  grep -qE 'ps -e -o pid=,ucomm=' television/cable/procs.toml
check "procs.toml avoids GNU-only --no-headers" \
  bash -c "! grep -q -- '--no-headers' television/cable/procs.toml"

# ── AC-6: docker-*.toml use podman ───────────────────────────────────────
echo ""
echo "AC-6: docker channels use podman"
check "docker-containers.toml uses podman" \
  grep -qE '^command = "podman ' television/cable/docker-containers.toml
check "docker-images.toml uses podman" \
  grep -qE '^command = "podman ' television/cable/docker-images.toml
check "docker-containers.toml does not invoke bare docker" \
  bash -c "! grep -qE '^command = \"docker ' television/cable/docker-containers.toml"

# ── AC-7: gcloud channels present with value-format commands ────────────
echo ""
echo "AC-7: gcloud channels"
for g in gcloud-configs gcloud-instances gcloud-run-services gcloud-sql; do
  check "$g.toml exists"                 test -f television/cable/$g.toml
  check "$g.toml uses gcloud"            grep -qE 'command = "gcloud ' television/cable/$g.toml
  check "$g.toml uses --format=value()"  grep -qE "format=.value\\(" television/cable/$g.toml
done
```

- [ ] **Step 3: Create each of the 22 channel files.**

The canonical file contents follow. Preview commands use `bat --color=always` for file-like content (inherits `BAT_THEME=Dracula` from §1b-ii Task 3) and `|| true` guards for channels that may have no sources (e.g. no k8s cluster). Actions use `{}` as the selected-value placeholder per television syntax.

### `television/cable/files.toml`
```toml
[metadata]
name = "files"
description = "Files under current dir (respects .gitignore)"
requirements = ["fd"]

[source]
command = "fd --type f --hidden --follow --exclude .git --exclude .env --exclude .ssh --exclude .aws --exclude .gnupg"

[preview]
command = "bat --color=always --style=numbers --line-range=:500 '{}'"

[actions.edit]
command = "${EDITOR:-nvim} '{}'"
default = true
```

### `television/cable/dirs.toml`
```toml
[metadata]
name = "dirs"
description = "Directories under current dir"
requirements = ["fd"]

[source]
command = "fd --type d --hidden --follow --exclude .git"

[preview]
command = "ls -la '{}'"

[actions.cd]
command = "cd '{}'"
default = true
```

### `television/cable/alias.toml`
```toml
[metadata]
name = "alias"
description = "Shell aliases"

[source]
command = "alias 2>/dev/null | sed 's/^alias //; s/=/\\t/'"

[actions.print]
command = "echo '{}'"
default = true
```

### `television/cable/env.toml`
```toml
[metadata]
name = "env"
description = "Environment variables (secret patterns filtered)"

# Secret filter: mirrors bash/.bashrc HISTIGNORE patterns.
# Any var whose NAME matches one of these is dropped before display.
[source]
command = """env | grep -viE '^(GITHUB_TOKEN|GH_TOKEN|GITHUB_PAT|TOKEN|SECRET|PASSWORD|KEY|BEARER|AUTHORIZATION|AWS_ACCESS|AWS_SECRET|AWS_SESSION|ANTHROPIC|OPENAI)='"""

[actions.print]
command = "echo '{}'"
default = true
```

### `television/cable/procs.toml`
```toml
[metadata]
name = "procs"
description = "Running processes (POSIX-compatible ps flags)"

# `ps -e -o pid=,ucomm=` is POSIX-portable across macOS BSD ps and GNU procps.
# The `=` suppresses column headers without needing --no-headers (GNU-only).
[source]
command = "ps -e -o pid=,ucomm= | awk '{printf \"%-8s %s\\n\", $1, $2}'"

[actions.kill]
command = "kill $(echo '{}' | awk '{print $1}')"
default = true

[actions.term]
command = "kill -TERM $(echo '{}' | awk '{print $1}')"

[actions.hup]
command = "kill -HUP $(echo '{}' | awk '{print $1}')"
```

### `television/cable/git-branch.toml`
```toml
[metadata]
name = "git-branch"
description = "Git branches (local + remote)"
requirements = ["git"]

[source]
command = "git branch --all --sort=-committerdate --format='%(refname:short)' | sed 's|^origin/||' | awk '!seen[$0]++'"

[preview]
command = "git log --oneline --decorate --color=always -20 '{}'"

[actions.checkout]
command = "git checkout '{}'"
default = true

[actions.delete]
command = "git branch -d '{}'"
```

### `television/cable/git-diff.toml`
```toml
[metadata]
name = "git-diff"
description = "Files with unstaged changes"
requirements = ["git"]

[source]
command = "git status --porcelain | awk '{print $2}'"

[preview]
command = "git diff --color=always -- '{}'"

[actions.add]
command = "git add '{}'"
default = true

[actions.restore]
command = "git restore '{}'"
```

### `television/cable/git-log.toml`
```toml
[metadata]
name = "git-log"
description = "Recent git commits"
requirements = ["git"]

[source]
command = "git log --oneline --decorate --color=always -n 500"

[preview]
command = "git show --color=always --stat $(echo '{}' | awk '{print $1}')"

[actions.show]
command = "git show $(echo '{}' | awk '{print $1}')"
default = true
```

### `television/cable/git-stash.toml`
```toml
[metadata]
name = "git-stash"
description = "Git stashes"
requirements = ["git"]

[source]
command = "git stash list"

[preview]
command = "git stash show -p --color=always $(echo '{}' | awk -F: '{print $1}')"

[actions.apply]
command = "git stash apply $(echo '{}' | awk -F: '{print $1}')"
default = true

[actions.pop]
command = "git stash pop $(echo '{}' | awk -F: '{print $1}')"

[actions.drop]
command = "git stash drop $(echo '{}' | awk -F: '{print $1}')"
```

### `television/cable/git-worktrees.toml`
```toml
[metadata]
name = "git-worktrees"
description = "Git worktrees"
requirements = ["git"]

[source]
command = "git worktree list"

[preview]
command = "cd $(echo '{}' | awk '{print $1}') && git log --oneline -20 --color=always"

[actions.cd]
command = "cd $(echo '{}' | awk '{print $1}')"
default = true
```

### `television/cable/git-reflog.toml`
```toml
[metadata]
name = "git-reflog"
description = "Git reflog"
requirements = ["git"]

[source]
command = "git reflog --color=always -n 200"

[preview]
command = "git show --color=always --stat $(echo '{}' | awk '{print $1}')"

[actions.checkout]
command = "git checkout $(echo '{}' | awk '{print $1}')"
default = true
```

### `television/cable/git-remotes.toml`
```toml
[metadata]
name = "git-remotes"
description = "Git remotes"
requirements = ["git"]

[source]
command = "git remote -v | awk '!seen[$1]++ {print $1, $2}'"

[actions.show]
command = "git remote show $(echo '{}' | awk '{print $1}')"
default = true
```

### `television/cable/git-repos.toml`

**This channel depends on Layer 1c (ghq).** It is non-functional without ghq installed — television will display an empty list. Per design § 3.2 cable channel safety note, this is the expected behaviour.

```toml
[metadata]
name = "git-repos"
description = "Git repos under the ghq tree (~/code)"
requirements = ["ghq"]

# Source: ghq list --full-path (absolute paths under ~/code/<host>/<org>/<repo>).
# Layer 1c (shipped) installs ghq and seeds the tree.
[source]
command = "ghq list --full-path"

[preview]
command = "ls -la '{}' | head -40"

[actions.cd]
command = "cd '{}'"
default = true

[actions.nvim]
command = "cd '{}' && ${EDITOR:-nvim}"

[actions.code]
command = "code '{}'"
```

### `television/cable/docker-containers.toml`
```toml
[metadata]
name = "docker-containers"
description = "Podman containers (matches existing container setup)"
requirements = ["podman"]

[source]
command = "podman ps -a --format '{{.ID}}\\t{{.Names}}\\t{{.Image}}\\t{{.Status}}'"

[preview]
command = "podman inspect $(echo '{}' | awk '{print $1}') 2>/dev/null | head -40"

[actions.exec]
command = "podman exec -it $(echo '{}' | awk '{print $1}') sh"
default = true

[actions.logs]
command = "podman logs $(echo '{}' | awk '{print $1}')"

[actions.stop]
command = "podman stop $(echo '{}' | awk '{print $1}')"

[actions.rm]
command = "podman rm $(echo '{}' | awk '{print $1}')"
```

### `television/cable/docker-images.toml`
```toml
[metadata]
name = "docker-images"
description = "Podman images"
requirements = ["podman"]

[source]
command = "podman images --format '{{.Repository}}:{{.Tag}}\\t{{.ID}}\\t{{.Size}}'"

[preview]
command = "podman inspect $(echo '{}' | awk '{print $2}') 2>/dev/null | head -40"

[actions.run]
command = "podman run -it --rm $(echo '{}' | awk '{print $1}')"
default = true

[actions.rm]
command = "podman rmi $(echo '{}' | awk '{print $2}')"
```

### `television/cable/k8s-pods.toml`
```toml
[metadata]
name = "k8s-pods"
description = "Kubernetes pods (current context)"
requirements = ["kubectl"]

[source]
command = "kubectl get pods --all-namespaces --no-headers 2>/dev/null || true"

[preview]
command = "kubectl describe pod -n $(echo '{}' | awk '{print $1}') $(echo '{}' | awk '{print $2}') 2>/dev/null | head -60"

[actions.exec]
command = "kubectl exec -it -n $(echo '{}' | awk '{print $1}') $(echo '{}' | awk '{print $2}') -- sh"
default = true

[actions.logs]
command = "kubectl logs -n $(echo '{}' | awk '{print $1}') $(echo '{}' | awk '{print $2}')"
```

### `television/cable/k8s-contexts.toml`
```toml
[metadata]
name = "k8s-contexts"
description = "Kubernetes contexts"
requirements = ["kubectl"]

[source]
command = "kubectl config get-contexts -o name 2>/dev/null || true"

[actions.use]
command = "kubectl config use-context '{}'"
default = true
```

### `television/cable/make-targets.toml`
```toml
[metadata]
name = "make-targets"
description = "Make targets in the current directory"
requirements = ["make"]

[source]
command = "make -qp 2>/dev/null | awk -F':' '/^[a-zA-Z0-9_.-]+:/ {print $1}' | sort -u"

[actions.run]
command = "make '{}'"
default = true
```

### `television/cable/ssh-hosts.toml`
```toml
[metadata]
name = "ssh-hosts"
description = "SSH hosts from ~/.ssh/config"

[source]
command = "awk '/^Host[[:space:]]+/ {for (i=2; i<=NF; i++) if ($i !~ /[*?]/) print $i}' ~/.ssh/config 2>/dev/null | sort -u"

[actions.ssh]
command = "ssh '{}'"
default = true
```

### `television/cable/gcloud-configs.toml`
```toml
[metadata]
name = "gcloud-configs"
description = "gcloud CLI configurations"
requirements = ["gcloud"]

[source]
command = "gcloud config configurations list --format='value(name,properties.core.project)' 2>/dev/null || true"

[actions.activate]
command = "gcloud config configurations activate $(echo '{}' | awk '{print $1}')"
default = true
```

### `television/cable/gcloud-instances.toml`
```toml
[metadata]
name = "gcloud-instances"
description = "GCE VM instances"
requirements = ["gcloud"]

[source]
command = "gcloud compute instances list --format='value(name,zone,status)' 2>/dev/null || true"

[actions.ssh]
command = "gcloud compute ssh $(echo '{}' | awk '{print $1}') --zone $(echo '{}' | awk '{print $2}')"
default = true

[actions.start]
command = "gcloud compute instances start $(echo '{}' | awk '{print $1}') --zone $(echo '{}' | awk '{print $2}')"

[actions.stop]
command = "gcloud compute instances stop $(echo '{}' | awk '{print $1}') --zone $(echo '{}' | awk '{print $2}')"
```

### `television/cable/gcloud-run-services.toml`
```toml
[metadata]
name = "gcloud-run-services"
description = "Cloud Run services"
requirements = ["gcloud"]

[source]
command = "gcloud run services list --format='value(metadata.name,metadata.namespace,status.url)' 2>/dev/null || true"

[actions.describe]
command = "gcloud run services describe $(echo '{}' | awk '{print $1}') --region $(echo '{}' | awk '{print $2}')"
default = true

[actions.logs]
command = "gcloud run services logs read $(echo '{}' | awk '{print $1}') --region $(echo '{}' | awk '{print $2}') --limit 50"

[actions.open]
command = "${BROWSER:-open} $(echo '{}' | awk '{print $3}')"
```

### `television/cable/gcloud-sql.toml`
```toml
[metadata]
name = "gcloud-sql"
description = "Cloud SQL instances"
requirements = ["gcloud"]

[source]
command = "gcloud sql instances list --format='value(name,region,state)' 2>/dev/null || true"

[actions.describe]
command = "gcloud sql instances describe $(echo '{}' | awk '{print $1}')"
default = true

[actions.proxy]
command = "cloud-sql-proxy $(echo '{}' | awk '{print $1}')"
```

- [ ] **Step 4: Run the test script**

`bash scripts/test-plan-layer1b-iii.sh` → AC-1, AC-3, AC-4, AC-5, AC-6, AC-7 pass.

- [ ] **Step 5: Commit**

```
git add television/cable/ scripts/test-plan-layer1b-iii.sh
git commit -m "feat(television): add 22 cable channels (Layer 1b-iii)"
```

---

## Task 2: Symlink television/cable from install scripts (AC-2)

**Files:**
- Modify: `install-macos.sh`, `install-wsl.sh`
- Modify: `scripts/test-plan-layer1b-iii.sh`

- [ ] **Step 1: Add AC-2 check**

```bash
# ── AC-2: television/cable symlinked as directory ────────────────────────
echo ""
echo "AC-2: television/cable directory symlink"
check "install-macos.sh links television/cable" \
  grep -qE 'link\s+television/cable\s+\.config/television/cable' install-macos.sh
check "install-wsl.sh links television/cable" \
  grep -qE 'link\s+television/cable\s+\.config/television/cable' install-wsl.sh
```

- [ ] **Step 2: Run — AC-2 fails.**

- [ ] **Step 3: Add the symlink to install-macos.sh.** Immediately after the existing `link television/config.toml` line:

```bash
# television cable channels (directory symlink — Layer 1b-iii)
link television/cable  .config/television/cable
```

- [ ] **Step 4: Add the same to install-wsl.sh.**

- [ ] **Step 5: Verify the `link()` helper handles directory sources correctly.** Re-read `link()` in both install scripts. It uses `ln -sf` with the backup-on-collision logic — both correctly handle a directory source (checked via `[[ ! -e "$src" ]]` guard at top). No change needed.

- [ ] **Step 6:** `bash scripts/test-plan-layer1b-iii.sh` → AC-2 passes.

- [ ] **Step 7: Commit**

```
git add install-macos.sh install-wsl.sh scripts/test-plan-layer1b-iii.sh
git commit -m "feat(install): symlink television/cable directory (Layer 1b-iii)"
```

---

## Task 3: Create gh-dash config (AC-8)

**Files:**
- Create: `gh-dash/config.yml`
- Modify: `install-macos.sh`, `install-wsl.sh`
- Modify: `scripts/test-plan-layer1b-iii.sh`

- [ ] **Step 1: Add AC-8 checks**

```bash
# ── AC-8: gh-dash config ─────────────────────────────────────────────────
echo ""
echo "AC-8: gh-dash/config.yml"
check "gh-dash/config.yml exists" test -f gh-dash/config.yml
check "gh-dash has prSections (>= 3)" \
  bash -c "grep -cE '^[[:space:]]*- title:' gh-dash/config.yml | awk '{exit !($1 >= 3)}'"
check "gh-dash defaults.view = prs"   grep -qE 'view:[[:space:]]*prs' gh-dash/config.yml
check "gh-dash pager.diff = diffnav"  grep -qE 'diff:[[:space:]]*"?diffnav"?' gh-dash/config.yml
check "gh-dash has lazygit keybinding" \
  grep -qE 'name:[[:space:]]*lazygit' gh-dash/config.yml
check "gh-dash has C → opencode binding" \
  bash -c 'grep -B1 -A4 -E "key:[[:space:]]*C\b" gh-dash/config.yml | grep -qE "tmux new-window|opencode"'
check "gh-dash theme uses Dracula palette (#BD93F9 or #6272A4)" \
  grep -qE '#BD93F9|#6272A4|#50FA7B' gh-dash/config.yml
check "install-macos.sh links gh-dash config" \
  grep -qE 'link\s+gh-dash/config\.yml' install-macos.sh
check "install-wsl.sh links gh-dash config" \
  grep -qE 'link\s+gh-dash/config\.yml' install-wsl.sh
```

- [ ] **Step 2: Run — AC-8 fails.**

- [ ] **Step 3: Create `gh-dash/config.yml`** from design § 3.5 plus the `C → opencode` binding from § 3.10.4:

```yaml
# gh-dash/config.yml — PR dashboard (dlvhdr/gh-dash)
# See docs/plans/2026-04-12-shell-modernisation-design.md § 3.5

prSections:
  - title: My Pull Requests
    filters: is:open author:@me
  - title: Needs My Review
    filters: is:open review-requested:@me
  - title: Involved
    filters: is:open involves:@me -author:@me

issuesSections:
  - title: My Issues
    filters: is:open author:@me
  - title: Assigned
    filters: is:open assignee:@me

defaults:
  preview:
    open: false
    width: 70
  prsLimit: 20
  issuesLimit: 20
  view: prs
  refetchIntervalMinutes: 30

keybindings:
  universal:
    - key: g
      name: lazygit
      command: >
        cd {{.RepoPath}}; lazygit

  prs:
    - key: C
      name: opencode
      # Opens the selected PR's repo in a new tmux window running opencode.
      # Requires tmux + opencode to be on PATH. Falls back to a no-op if tmux
      # isn't available (gh-dash just errors visibly).
      command: >
        tmux new-window -c {{.RepoPath}} "opencode"

pager:
  diff: "diffnav"

confirmQuit: false
showAuthorIcons: true

# Dracula theme (palette values from docs/plans § 3.9)
theme:
  ui:
    table:
      showSeparator: true
  colors:
    text:
      primary: "#F8F8F2"
      secondary: "#6272A4"
      inverted: "#282A36"
      faint: "#44475A"
      warning: "#FFB86C"
      success: "#50FA7B"
      error: "#FF5555"
    background:
      selected: "#44475A"
    border:
      primary: "#BD93F9"
      secondary: "#6272A4"
      faint: "#44475A"
```

- [ ] **Step 4: Add symlink to install-macos.sh** (after the Layer 1b-i jqp/diffnav block):

```bash
# gh-dash (Plan Layer 1b-iii)
link gh-dash/config.yml  .config/gh-dash/config.yml
```

- [ ] **Step 5: Add the same to install-wsl.sh.**

- [ ] **Step 6:** `bash scripts/test-plan-layer1b-iii.sh` → AC-8 passes.

- [ ] **Step 7: Commit**

```
git add gh-dash/ install-macos.sh install-wsl.sh scripts/test-plan-layer1b-iii.sh
git commit -m "feat(gh-dash): add gh-dash config with Dracula + C→opencode binding (Layer 1b-iii)"
```

---

## Task 4: Install gh extensions from install scripts (AC-9)

**Files:**
- Modify: `install-macos.sh`, `install-wsl.sh`
- Modify: `scripts/test-plan-layer1b-iii.sh`

- [ ] **Step 1: Add AC-9 checks**

```bash
# ── AC-9: install scripts install all gh extensions ──────────────────────
echo ""
echo "AC-9: gh extensions installed"
exts=(dlvhdr/gh-dash github/gh-copilot seachicken/gh-poi yusukebe/gh-markdown-preview k1Low/gh-grep github/gh-aw Link-/gh-token)
for e in "${exts[@]}"; do
  # Case-insensitive (-i) so either "k1Low" or "k1low" matches.
  # Also sidesteps the bash-4 ${VAR,,} expansion which breaks on macOS default bash 3.2.
  check "install-macos.sh installs $e" \
    grep -iqE "gh extension install[[:space:]]+$e\b" install-macos.sh
  check "install-wsl.sh installs $e" \
    grep -iqE "gh extension install[[:space:]]+$e\b" install-wsl.sh
done
check "install-macos.sh guards gh extension install on command -v gh" \
  grep -PzoE '(?s)command -v gh[^\n]*\n[^\n]*gh extension install' install-macos.sh >/dev/null 2>&1
check "install-wsl.sh guards gh extension install on command -v gh" \
  grep -PzoE '(?s)command -v gh[^\n]*\n[^\n]*gh extension install' install-wsl.sh >/dev/null 2>&1
```

- [ ] **Step 2: Run — AC-9 fails.**

- [ ] **Step 3: Add gh extension install block to install-macos.sh** immediately AFTER the bun global install block (Step 2 post-brew):

```bash
# ── gh extensions (Layer 1b-iii) ─────────────────────────────────────────
# Each install is idempotent: `gh extension install` is a no-op if already
# installed. `|| true` avoids failing the whole script if a single extension
# is unavailable (e.g. corporate network blocks a release asset).
if command -v gh &>/dev/null; then
  log "installing gh extensions"
  gh extension install dlvhdr/gh-dash             || true
  gh extension install github/gh-copilot          || true
  gh extension install seachicken/gh-poi          || true
  gh extension install yusukebe/gh-markdown-preview || true
  gh extension install k1Low/gh-grep              || true
  gh extension install github/gh-aw               || true
  gh extension install Link-/gh-token             || true
else
  warn "gh not on PATH — skipping gh extension installs"
fi
```

- [ ] **Step 4: Add the same block to install-wsl.sh** at the analogous location.

- [ ] **Step 5:** `bash scripts/test-plan-layer1b-iii.sh` → AC-9 passes.

- [ ] **Step 6: Commit**

```
git add install-macos.sh install-wsl.sh scripts/test-plan-layer1b-iii.sh
git commit -m "feat(install): install 7 gh extensions (Layer 1b-iii)"
```

---

## Task 5: Add gh aliases to bash/.bash_aliases (AC-10)

**Files:**
- Modify: `bash/.bash_aliases`
- Modify: `scripts/test-plan-layer1b-iii.sh`

- [ ] **Step 1: Add AC-10 checks**

```bash
# ── AC-10: gh aliases ────────────────────────────────────────────────────
echo ""
echo "AC-10: gh extension aliases"
check "alias ghd='gh dash'"                  grep -qE "^alias ghd='gh dash'"                  bash/.bash_aliases
check "alias ghce='gh copilot explain'"      grep -qE "^alias ghce='gh copilot explain'"      bash/.bash_aliases
check "alias ghcs='gh copilot suggest'"      grep -qE "^alias ghcs='gh copilot suggest'"      bash/.bash_aliases
check "alias ghp='gh poi'"                   grep -qE "^alias ghp='gh poi'"                   bash/.bash_aliases
check "alias ghmd='gh markdown-preview'"     grep -qE "^alias ghmd='gh markdown-preview'"     bash/.bash_aliases
check "alias ghg='gh grep'"                  grep -qE "^alias ghg='gh grep'"                  bash/.bash_aliases
check "alias ghaw='gh aw'"                   grep -qE "^alias ghaw='gh aw'"                   bash/.bash_aliases
check "no alias for gh-token"                bash -c "! grep -qE \"^alias ght.*='gh token|^alias ghtoken='\" bash/.bash_aliases"
```

- [ ] **Step 2: Run — AC-10 fails.**

- [ ] **Step 3: Append new aliases** to `bash/.bash_aliases`. Place AFTER the existing "── GitHub CLI ──" section and BEFORE the "── Search & find ──" section. Use a new banner to avoid diff noise:

```bash

# ── GitHub CLI extensions (Layer 1b-iii) ────────────────────────────────────
# gh-dash: PR dashboard. `ghd` is the entry point; see `cheat ghd`.
alias ghd='gh dash'
# gh-copilot: inline explain/suggest.
alias ghce='gh copilot explain'
alias ghcs='gh copilot suggest'
# gh-poi: prune merged branches (checks PR state).
alias ghp='gh poi'
# gh-markdown-preview: local GFM rendering.
alias ghmd='gh markdown-preview'
# gh-grep: cross-repo grep via GitHub API.
alias ghg='gh grep'
# gh-aw: agentic workflows.
alias ghaw='gh aw'
# gh-token: no alias — automation-only per design Appendix C.
```

- [ ] **Step 4: Syntax check**

`bash -n bash/.bash_aliases` → exit 0.

- [ ] **Step 5:** `bash scripts/test-plan-layer1b-iii.sh` → AC-10 passes.

- [ ] **Step 6: Commit**

```
git add bash/.bash_aliases scripts/test-plan-layer1b-iii.sh
git commit -m "feat(aliases): add gh extension aliases (ghd/ghce/ghcs/ghp/ghmd/ghg/ghaw)"
```

---

## Task 6: Extend `cheat()` with gh-ext, ghd, channels (AC-11)

**Files:**
- Modify: `bash/.bash_aliases`
- Modify: `scripts/test-plan-layer1b-iii.sh`

- [ ] **Step 1: Add AC-11 checks**

```bash
# ── AC-11: cheat() has gh-ext + ghd + channels arms ──────────────────────
echo ""
echo "AC-11: cheat() arms for gh extensions and TV channels"
cheat_body() { awk '/^cheat\(\) \{/,/^\}/' bash/.bash_aliases | sed 's/#.*//'; }
for arm in 'gh-ext' 'ghd' 'channels|tv-channels'; do
  if cheat_body | grep -qE "^[[:space:]]*(${arm})\)"; then
    ok "cheat: arm matching '$arm' present"
  else
    nok "cheat: arm matching '$arm' present"
  fi
done
check "cheat gh-ext runs gh extension list" \
  bash -c "cheat_body() { awk '/^cheat\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//'; }; cheat_body | grep -q 'gh extension list'"
check "cheat ghd mentions C → opencode" \
  bash -c "cheat_body() { awk '/^cheat\\(\\) \\{/,/^\\}/' bash/.bash_aliases | sed 's/#.*//'; }; cheat_body | grep -qiE 'C.*opencode|opencode.*C'"
```

- [ ] **Step 2: Run — AC-11 fails.**

- [ ] **Step 3: Add case arms to `cheat()`.** Insert BEFORE the `opencode|oc)` arm:

```bash
    gh-ext)
      echo "Installed gh extensions:"
      if command -v gh &>/dev/null; then
        gh extension list
      else
        echo "  (gh not on PATH)"
      fi
      echo ""
      echo "Quick references:"
      echo "  gh-dash          PR/issue dashboard.   ghd / cheat ghd"
      echo "  gh-copilot       Inline explain/suggest. ghce / ghcs"
      echo "  gh-poi           Prune merged branches.  ghp"
      echo "  gh-markdown-preview  Local GFM render.   ghmd"
      echo "  gh-grep          Cross-repo grep.        ghg"
      echo "  gh-aw            Agentic workflows.      ghaw"
      echo "  gh-token         Installation token helper (scripting)."
      ;;
    ghd)
      cat <<'EOF'
gh-dash (gh dash) — PR/issue dashboard
  ?           help overlay
  j/k         down/up
  l/h         next/prev column
  r           refresh the current section
  Enter       preview the selected PR/issue
  g           open repo in lazygit (RepoPath-substituted)
  C           open PR in opencode via tmux new-window (1b-iii binding)
  o           open in browser
  d           view diff (uses diffnav as pager)
Config: ~/.config/gh-dash/config.yml
EOF
      ;;
    channels|tv-channels)
      cat <<'EOF'
television cable channels — shell-integration triggers
  Trigger on command              Channel
  ──────────────────────────────  ────────────
  cat/less/vim/nvim/bat/cp/mv/rm  files
  cd/ls/z/rmdir                   dirs
  alias/unalias                   alias
  export/unset                    env
  git checkout/branch/merge/...   git-branch
  git add/restore                 git-diff
  git log/show                    git-log
  podman exec/stop/rm             docker-containers
  podman run                      docker-images
  kubectl exec/logs               k8s-pods
  kubectx                         k8s-contexts
  make                            make-targets
  ssh/scp                         ssh-hosts
  nvim/code/git clone             git-repos (ghq tree)
Ctrl-T invokes the context-sensitive channel (default: files).
Invoke manually: `tv <channel>` (e.g. tv git-log, tv procs, tv gcloud-configs).
EOF
      ;;
```

- [ ] **Step 4: Add `gh-ext`, `ghd`, `channels` to the `Per-tool subcommands:` help block** (the `-h|--help|help)` arm). Append them to the list maintained by 1b-i Task 8 + 1b-ii Task 7 so the complete list becomes:

```
Per-tool subcommands:
  atuin, bash, btop, channels, delta, diffnav, fzf, git, gh-ext, ghd,
  jqp, k9s, lazydocker, lazygit, lnav, nvim, opencode, rip, rip2, sesh,
  starship, tmux, tmux-plugins, tv/television, xh, yazi
```

- [ ] **Step 5: Syntax check + test**

```
bash -n bash/.bash_aliases
bash scripts/test-plan-layer1b-iii.sh
```

AC-11 passes.

- [ ] **Step 6: Commit**

```
git add bash/.bash_aliases scripts/test-plan-layer1b-iii.sh
git commit -m "feat(cheat): add gh-ext, ghd, and channels subcommands (Layer 1b-iii)"
```

---

## Task 7: Update docs/cheatsheet.md (AC-12)

**Files:**
- Modify: `docs/cheatsheet.md`
- Modify: `scripts/test-plan-layer1b-iii.sh`

- [ ] **Step 1: Add AC-12 checks**

```bash
# ── AC-12: cheatsheet.md sections ────────────────────────────────────────
echo ""
echo "AC-12: cheatsheet additions"
check "cheatsheet has TV channel triggers section" \
  grep -qE '^### Television channel triggers|^### TV channel triggers' docs/cheatsheet.md
check "cheatsheet has gh-dash workflow section" \
  grep -qE '^### gh-dash workflow|^### PR review via gh-dash' docs/cheatsheet.md
for alias in ghd ghce ghcs ghp ghmd ghg ghaw; do
  # Use word-boundary match; avoid backticks in double-quoted strings
  # (which bash would treat as command substitution).
  check "cheatsheet lists $alias" grep -qE "\\b$alias\\b" docs/cheatsheet.md
done
```

- [ ] **Step 2: Run — AC-12 fails.**

- [ ] **Step 3: Add "Television channel triggers" subsection** under `## Key bindings` after `### Known friction points` (1b-ii added tmux plugin keybindings there; place this below that):

```markdown
### Television channel triggers

Ctrl-T invokes television; the channel is chosen by context (the command being typed). Add the trigger to `[shell_integration.channel_triggers]` in `~/.config/television/config.toml`.

| Command typed | Channel |
|---------------|---------|
| `cat`, `less`, `vim`, `nvim`, `bat`, `cp`, `mv`, `rm` | files |
| `cd`, `ls`, `z`, `rmdir` | dirs |
| `alias`, `unalias` | alias |
| `export`, `unset` | env |
| `git checkout`, `git branch`, `git merge`, `git rebase`, `git pull`, `git push` | git-branch |
| `git add`, `git restore` | git-diff |
| `git log`, `git show` | git-log |
| `podman exec`, `podman stop`, `podman rm` | docker-containers |
| `podman run` | docker-images |
| `kubectl exec`, `kubectl logs` | k8s-pods |
| `kubectx` | k8s-contexts |
| `make` | make-targets |
| `ssh`, `scp` | ssh-hosts |
| `nvim`, `code`, `git clone` | git-repos (from ghq tree) |

Invoke manually: `tv <channel>` (e.g. `tv git-log`, `tv gcloud-configs`, `tv procs`).
```

- [ ] **Step 4: Add "gh-dash workflow" subsection** under `## Tool reference` after `### Git`:

```markdown
### gh-dash workflow

gh-dash is the PR/issue dashboard. `ghd` launches it.

| Task | Binding | Result |
|------|---------|--------|
| Preview PR | Enter | Inline preview pane |
| Open repo in lazygit | g | `cd <repo>; lazygit` |
| Open PR in opencode | C | `tmux new-window -c <repo> "opencode"` (custom binding) |
| View diff | d | Delta-rendered diff via diffnav |
| Open PR in browser | o | `gh browse` on the selection |
| Refresh section | r | Re-fetch from GitHub |

Pager for diffs is `diffnav` (file-tree nav UI over delta output). Delta's syntax theme is Dracula via `git/.gitconfig`.

| Task | Tool | Command | Alias |
|------|------|---------|-------|
| PR/issue dashboard | gh-dash | `gh dash` | `ghd` |
| Explain a command | gh-copilot | `gh copilot explain <cmd>` | `ghce` |
| Suggest a command | gh-copilot | `gh copilot suggest <q>` | `ghcs` |
| Prune merged branches | gh-poi | `gh poi` | `ghp` |
| Render GFM locally | gh-markdown-preview | `gh markdown-preview <file>` | `ghmd` |
| Cross-repo grep | gh-grep | `gh grep <q>` | `ghg` |
| Agentic workflows | gh-aw | `gh aw ...` | `ghaw` |
| Installation token helper | gh-token | `gh token -i <id>` (automation) | — |
```

- [ ] **Step 5:** `bash scripts/test-plan-layer1b-iii.sh` → AC-12 passes.

- [ ] **Step 6: Commit**

```
git add docs/cheatsheet.md scripts/test-plan-layer1b-iii.sh
git commit -m "docs(cheatsheet): document TV channel triggers + gh-dash workflow (Layer 1b-iii)"
```

---

## Task 8: Update verify.sh (AC-13)

**Files:**
- Modify: `scripts/verify.sh`
- Modify: `scripts/test-plan-layer1b-iii.sh`

- [ ] **Step 1: Add AC-13 checks**

```bash
# ── AC-13: verify.sh Layer 1b-iii block ──────────────────────────────────
echo ""
echo "AC-13: verify.sh Layer 1b-iii coverage"
check "verify.sh checks television/cable symlink" \
  grep -qE 'television/cable' scripts/verify.sh
check "verify.sh checks gh-dash config symlink" \
  grep -qE 'gh-dash/config\.yml' scripts/verify.sh
check "verify.sh iterates gh extensions" \
  grep -qE 'gh extension list' scripts/verify.sh
```

- [ ] **Step 2: Run — AC-13 fails.**

- [ ] **Step 3: Add a Layer 1b-iii block to `scripts/verify.sh`** AFTER the Layer 1b-ii block (added in 1b-ii Task 9):

```bash
# ── Layer 1b-iii (cable channels + gh extensions + gh-dash) ──────────────
echo ""
echo "Layer 1b-iii:"
# shellcheck disable=SC2016  # $HOME expanded inside inner bash -c intentionally
check "television/cable symlink resolves as a directory" \
  bash -c 'test -L "$HOME/.config/television/cable" && test -d "$HOME/.config/television/cable"'
# shellcheck disable=SC2016
check "gh-dash config symlink resolves" \
  bash -c 'test -L "$HOME/.config/gh-dash/config.yml" && test -e "$HOME/.config/gh-dash/config.yml"'

# gh extensions (full mode only — requires `gh` authenticated)
if command -v gh &>/dev/null && gh extension list &>/dev/null; then
  ext_list="$(gh extension list 2>/dev/null)"
  for e in gh-dash gh-copilot gh-poi gh-markdown-preview gh-grep gh-aw gh-token; do
    if printf '%s' "$ext_list" | grep -q "$e"; then
      ok "gh extension installed: $e"
    else
      nok "gh extension installed: $e"
    fi
  done
else
  echo "  (gh extensions not checked — gh not on PATH or not authenticated)"
fi
```

- [ ] **Step 4:** `bash scripts/test-plan-layer1b-iii.sh` → AC-13 passes.

- [ ] **Step 5: Commit**

```
git add scripts/verify.sh scripts/test-plan-layer1b-iii.sh
git commit -m "feat(verify): add Layer 1b-iii smoke checks (cable + gh-dash + gh extensions)"
```

---

## Task 9: Guard structural invariants (AC-14) + e2e (AC-15)

**Files:**
- Modify: `scripts/test-plan-layer1b-iii.sh`

- [ ] **Step 1: Add AC-14 guard**

```bash
# ── AC-14: structural invariants preserved ───────────────────────────────
echo ""
echo "AC-14: structural invariants"
check ".bashrc section count unchanged (test-plan2.sh)" bash scripts/test-plan2.sh
check "starship unchanged (test-plan6-8.sh)"            bash scripts/test-plan6-8.sh
```

- [ ] **Step 2: Run**

`bash scripts/test-plan-layer1b-iii.sh` → AC-14 passes (no bashrc or starship changes in this plan).

- [ ] **Step 3: Full sweep**

```
for f in scripts/test-plan*.sh; do bash "$f" >/dev/null 2>&1 || echo "FAIL: $f"; done
```

Expected: no FAIL output. Particularly verify:
- test-plan-layer1a.sh (Layer 1a) — must still pass
- test-plan-layer1c.sh (Layer 1c) — must still pass; git-repos.toml sources from ghq list (this plan relies on 1c)
- test-plan-layer1b-i.sh — must still pass
- test-plan-layer1b-ii.sh — must still pass
- test-plan-layer1b-iii.sh — exit 0

- [ ] **Step 4: Shellcheck sweep**

```
find . -type f -name '*.sh' -not -path './.worktrees/*' -print0 | xargs -0 shellcheck
```

Silent.

- [ ] **Step 5: Verify AC coverage**

```
grep -E '^# ── AC-[0-9]+' scripts/test-plan-layer1b-iii.sh | sort -V
```

Expected: AC-1 through AC-14 listed (AC-15 is the composite summary, not a labelled block).

- [ ] **Step 6: Commit**

```
git add scripts/test-plan-layer1b-iii.sh
git commit -m "test(plan-layer1b-iii): wire AC-14 invariant guards + e2e (AC-15)"
```

---

## Post-plan: Manual Validation Steps

After CI passes:

**macOS + WSL2:**
1. `bash install-macos.sh` (or `install-wsl.sh`) — installs gh extensions, symlinks `television/cable` directory, symlinks `gh-dash/config.yml`.
2. `tv git-repos` → lists repos from `~/code/<host>/<org>/<repo>`.
3. `tv procs` → picks a process; default action kills it.
4. `tv gcloud-configs` → lists configured gcloud projects (if gcloud installed).
5. `git checkout <Ctrl-T>` → triggers `git-branch` channel; select a branch.
6. `ghd` → gh-dash opens; select a PR → `g` opens lazygit; `C` opens opencode in a new tmux window.
7. `ghp` → scans local branches, lists merged ones for deletion.
8. `echo 'what does rsync -a do' | ghce` → Copilot explanation.
9. `ghmd README.md` → local preview.
10. `ghg 'func main' | head` → cross-repo search (requires gh auth).
11. `cheat gh-ext` → lists extensions.
12. `cheat channels` → prints the trigger table.

---

## Self-Review Notes (at plan write time)

- **Spec coverage:** design §§ 3.2 (cable channels + security), 3.5 (gh-dash), 3.8 (gh aliases — complete list), 3.11 (ghq — consumed), 4 (Layer 1b bullet 2 + gh extensions in Appendix C), 8.1 (cheat gh-ext) all mapped. GCP channels match design § 4 "GCP television channels — defined now, refined later".
- **Forward dependencies resolved:** `git-repos.toml` sources from `ghq list --full-path` — design § 3.2 said this "SHOULD" be pre-emptive; we do it here as a hard dependency because 1c is already shipped.
- **Channel count discipline:** 22 channels total. Not "~30" as the design introduction approximated — the 22-channel list is the exhaustive enumeration from § 3.2 + § 4 (plus the 4 GCP channels + procs). Extra channels can be added later without re-wiring the symlink.
- **Safety:** env.toml filters mirror `.bashrc` HISTIGNORE patterns. Procs uses POSIX ps flags. Docker channels use podman (matches the project's podman-based container setup). Cable channels are single-quoted around `'{}'` to resist shell injection in selected values.
- **Invariants:** no changes to `.bashrc`, `starship.toml`, `tmux.conf`, `atuin/config.toml`, `television/config.toml`. test-plan2 + test-plan6-8 asserts remain green without updates.
- **License:** no Dracula Pro files introduced (1b-ii already shipped `kitty/dracula-pro.conf`; the gh-dash theme block uses only the free Dracula palette hex codes).
- **gh-token alias omission:** intentional, per design Appendix C — gh-token is automation-only (coexists with `gha-pin` PAT flow), not an interactive tool.
- **No placeholders:** every channel has actual commands, every alias has exact quoting, every AC has a concrete grep pattern.
