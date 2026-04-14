# gh CLI Classification — Agent B (repo, pr, issue)

**Families**: `repo`, `pr`, `issue`
**Source**: `macos-dev/docs/research/gh-cli-commands.json` (gh 2.89.0)
**Leaf counts**: repo=23, pr=18, issue=15 (total 56)
**Rubric**: see `macos-dev/docs/plans/2026-04-14-gh-cli-safe-allowlist.md` §"Phase 2 — Classify".

## Semantics reminder

OpenCode uses `rules.findLast(wildcardMatch)`; `*` is greedy across whitespace; trailing ` *` is optional (so `"gh pr view *"` matches bare `gh pr view` too). The proposed-pattern column below only emits per-verb allows for SAFE leaves. Broad family allows (`gh repo *` etc.), flag demotions (`gh * --web*: ask`, `gh * --edit*: ask`, `gh * --output *: ask`, `gh * --clobber*: ask`, `gh * --watch*: ask`, `gh * --follow*: ask`), and the `*: ask` default are emitted by the aggregator in a later phase. MUTATING / WRITES-LOCAL / AUTH / INTERACTIVE / INSTALLS-CODE / MANUAL-REVIEW rows fall through to `*: ask` and therefore carry no pattern.

### `repo` (23 leaves)

#### top-level

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh repo archive | MUTATING | — | | Archives repo on server (GraphQL). |
| gh repo clone | WRITES-LOCAL | — | | Writes to disk (policy: ask, no workspace scoping). |
| gh repo create | MUTATING | — | | Creates repo on server; also writes files with `--clone`. |
| gh repo delete | MUTATING | — | | Irreversible server-side delete. |
| gh repo edit | MUTATING | — | | PATCH `/repos/{owner}/{repo}`. |
| gh repo fork | MUTATING | — | | Creates fork; can also clone locally. |
| gh repo list | SAFE | `--web` (browser) | `"gh repo list": "allow"`, `"gh repo list *": "allow"` | GET `/search/repositories` (or user). Output via `--json`/`--template` is SAFE; `--web` demoted globally. |
| gh repo rename | MUTATING | — | | PATCH repo name. |
| gh repo set-default | MUTATING | — | | Writes local git config (SetRemoteResolution) and interactive by default. Source-confirmed. |
| gh repo sync | MUTATING | — | | Server sync + local `git fetch`/`merge --ff-only`/`reset --hard`/`update-ref`. Source-confirmed. |
| gh repo unarchive | MUTATING | — | | Reverses archive on server. |
| gh repo view | SAFE | `--web` (browser), `--branch <string>` is safe (read selector) | `"gh repo view": "allow"`, `"gh repo view *": "allow"` | GET repo metadata + README. `--web` demoted globally. |

#### `gh repo autolink`

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh repo autolink create | MUTATING | — | | POST `/repos/{owner}/{repo}/autolinks`. |
| gh repo autolink delete | MUTATING | — | | DELETE autolink. |
| gh repo autolink list | SAFE | `--web` (browser) | `"gh repo autolink list": "allow"`, `"gh repo autolink list *": "allow"` | GET autolinks. |
| gh repo autolink view | SAFE | none | `"gh repo autolink view": "allow"`, `"gh repo autolink view *": "allow"` | GET single autolink. |

#### `gh repo deploy-key`

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh repo deploy-key add | MUTATING | — | | POST a key; also reads a local key file (implicit). |
| gh repo deploy-key delete | MUTATING | — | | DELETE key. |
| gh repo deploy-key list | SAFE | none | `"gh repo deploy-key list": "allow"`, `"gh repo deploy-key list *": "allow"` | GET `/repos/{owner}/{repo}/keys`. |

#### `gh repo gitignore`

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh repo gitignore list | SAFE | none | `"gh repo gitignore list": "allow"`, `"gh repo gitignore list *": "allow"` | GET `/gitignore/templates` (curated list; source-confirmed). |
| gh repo gitignore view | SAFE | none | `"gh repo gitignore view": "allow"`, `"gh repo gitignore view *": "allow"` | GET single template; prints to stdout. |

#### `gh repo license`

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh repo license list | SAFE | none | `"gh repo license list": "allow"`, `"gh repo license list *": "allow"` | GET `/licenses`. |
| gh repo license view | SAFE | `--web` (browser) | `"gh repo license view": "allow"`, `"gh repo license view *": "allow"` | GET `/licenses/{key}`. `--web` demoted globally. |

### `pr` (18 leaves)

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh pr checkout | WRITES-LOCAL | — | | Local `git fetch`/`checkout`; policy: ask. |
| gh pr checks | SAFE | `--web` (browser), `--watch` (long-running stream), `--interval` (only meaningful with --watch) | `"gh pr checks": "allow"`, `"gh pr checks *": "allow"` | GET check runs. `--web` and `--watch` demoted globally (`gh * --web*`, `gh * --watch*` → ask). |
| gh pr close | MUTATING | — | | PATCH state=closed; may also delete branch with `--delete-branch`. |
| gh pr comment | MUTATING | — | | POST comment. |
| gh pr create | MUTATING | — | | Opens editor / pushes branch / creates PR. |
| gh pr diff | SAFE | `--web` (browser) | `"gh pr diff": "allow"`, `"gh pr diff *": "allow"` | GET diff/patch stream; `--patch` and `--name-only` are output-format flags. `--web` demoted globally. |
| gh pr edit | MUTATING | — | | PATCH PR; may open editor. |
| gh pr list | SAFE | `--web` (browser) | `"gh pr list": "allow"`, `"gh pr list *": "allow"` | GET search/issues. |
| gh pr lock | MUTATING | — | | PUT lock. |
| gh pr merge | MUTATING | — | | Merge via API; may delete branch / push. |
| gh pr ready | MUTATING | — | | Mark PR ready / draft (GraphQL mutation). |
| gh pr reopen | MUTATING | — | | PATCH state=open. |
| gh pr revert | MUTATING | — | | GraphQL `revertPullRequest` creates a new revert PR. Source-confirmed. |
| gh pr review | MUTATING | — | | POST review (approve/request-changes/comment). |
| gh pr status | SAFE | none | `"gh pr status": "allow"`, `"gh pr status *": "allow"` | GET current-user PR context. Output-only flags. |
| gh pr unlock | MUTATING | — | | DELETE lock. |
| gh pr update-branch | MUTATING | — | | GraphQL `UpdatePullRequestBranch` merge/rebase into branch. Source-confirmed. |
| gh pr view | SAFE | `--web` (browser) | `"gh pr view": "allow"`, `"gh pr view *": "allow"` | GET PR + optional comments. `--web` demoted globally. |

### `issue` (15 leaves)

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh issue close | MUTATING | — | | PATCH state=closed; supports `--reason`. |
| gh issue comment | MUTATING | — | | POST comment; may open editor. |
| gh issue create | MUTATING | — | | POST issue; may open editor and/or browser. |
| gh issue delete | MUTATING | — | | GraphQL `deleteIssue`. Irreversible. |
| gh issue develop | MUTATING | — | | GraphQL `CreateLinkedBranch` + optional local `git fetch`/`checkout`/`pull` and `git config` write. Source-confirmed. |
| gh issue edit | MUTATING | — | | PATCH issue; may open editor. |
| gh issue list | SAFE | `--web` (browser) | `"gh issue list": "allow"`, `"gh issue list *": "allow"` | GET search/issues. |
| gh issue lock | MUTATING | — | | PUT lock. |
| gh issue pin | MUTATING | — | | GraphQL pin (max 3 per repo). |
| gh issue reopen | MUTATING | — | | PATCH state=open. |
| gh issue status | SAFE | none | `"gh issue status": "allow"`, `"gh issue status *": "allow"` | GET current-user issue context. Output-only flags. |
| gh issue transfer | MUTATING | — | | GraphQL `transferIssue`. |
| gh issue unlock | MUTATING | — | | DELETE lock. |
| gh issue unpin | MUTATING | — | | GraphQL unpin. |
| gh issue view | SAFE | `--web` (browser), `--comments` is SAFE (extra GET) | `"gh issue view": "allow"`, `"gh issue view *": "allow"` | GET issue. `--web` demoted globally. |

## Aggregate side-effect flag register

For the aggregator phase — flags to demote globally (not emitted here):

- `--web` on: `repo list`, `repo view`, `repo autolink list`, `repo license view`, `pr list`, `pr view`, `pr diff`, `pr checks`, `issue list`, `issue view`.
- `--watch` on: `pr checks` (long-running stream; hangs AI session).
- `--edit` / `--editor`: appears on MUTATING verbs (`pr create`, `pr edit`, `pr comment`, `pr review`, `issue create`, `issue edit`, `issue comment`) — already blocked by class.
- `--output` / `--dir` / `--clobber`: none on SAFE leaves in these families (relevant for `release download`, `run download`, `gist clone` — other agents).
- `--follow`: none on SAFE leaves in these families.

## Classification tally

| Class | Count | Commands |
|---|---|---|
| SAFE | 17 | repo {list, view, autolink list, autolink view, deploy-key list, gitignore list, gitignore view, license list, license view}; pr {list, view, diff, checks, status}; issue {list, view, status} |
| MUTATING | 35 | repo {archive, create, delete, edit, rename, set-default, sync, unarchive, autolink create, autolink delete, deploy-key add, deploy-key delete}; pr {close, comment, create, edit, lock, merge, ready, reopen, revert, review, unlock, update-branch}; issue {close, comment, create, delete, develop, edit, lock, pin, reopen, transfer, unlock, unpin} |
| WRITES-LOCAL | 2 | repo clone, pr checkout |
| AUTH | 0 | — |
| INTERACTIVE | 0 | (top-level; `--watch`/`--web` handled via flag demotion) |
| INSTALLS-CODE | 0 | — |
| MANUAL-REVIEW resolved | 4 | pr revert, pr update-branch, issue develop, repo sync (all resolved → MUTATING) |

## MANUAL-REVIEW resolutions

- **`gh pr revert`** — WebFetch `pkg/cmd/pr/revert/revert.go`: calls `api.PullRequestRevert` (GraphQL `revertPullRequest` mutation) and prints the new PR URL. **MUTATING**.
- **`gh pr update-branch`** — WebFetch `pkg/cmd/pr/update-branch/update_branch.go`: calls `api.UpdatePullRequestBranch` (GraphQL `UpdatePullRequestBranch` mutation). **MUTATING**.
- **`gh issue develop`** — WebFetch `pkg/cmd/issue/develop/develop.go`: calls `api.CreateLinkedBranch` (GraphQL) plus optional local `git fetch` / `git checkout` / `git pull` / `git config` writes via `gc.SetBranchConfig`. **MUTATING** (server + possibly local).
- **`gh repo sync`** — WebFetch `pkg/cmd/repo/sync/sync.go`: local mode runs `git fetch` + `git merge --ff-only FETCH_HEAD`; remote mode calls `triggerUpstreamMerge` / `syncFork` (API). Fast-forward only unless `--force` (uses `git reset --hard`). **MUTATING** (local git mutation and/or server mutation).
- **`gh repo set-default`** — WebFetch `pkg/cmd/repo/setdefault/setdefault.go`: writes local git config via `SetRemoteResolution`; interactive prompt by default. **MUTATING** (by local-config mutation + interactivity; keeps it off the allow-list).

## Confidently unclassifiable

None. All 56 leaves in these three families classify cleanly under the rubric after source cross-check of the five ambiguous cases above.
