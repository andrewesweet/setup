# gh CLI Classification — Agent A (auth, config, status, cache, completion, licenses)

**Source enumeration**: `macos-dev/docs/research/gh-cli-commands.json` (gh 2.89.0).
**Scope**: 16 leaf commands across 6 families.
**Policy references**: `macos-dev/docs/plans/2026-04-14-gh-cli-safe-allowlist.md` (verb rubric); `macos-dev/docs/design/opencode.md` § Rule Evaluation Semantics (greedy `*`, `findLast` wins).

## Cross-cutting notes

- The aggregator will append global side-effect-flag asks (e.g. `"gh * --web*": "ask"`, `"gh * --edit*": "ask"`, `"gh * --output *": "ask"`). Per-verb allows below assume that later, broader asks will demote any unsafe flag appearances. No command in Agent A's scope takes `--web`, `--edit`, `--output`, `--dir`, `--clobber`, or `--watch`. The only local side-effect flag is `gh auth status --show-token` / `-t`, flagged below and handled by an explicit per-command ask.
- Last-match-wins: per-verb allows must be emitted AFTER any wider `gh auth *: ask` entries the aggregator writes. Because some verbs in the `auth` family are AUTH (ask) and one is SAFE (allow), I propose per-verb allows only — never `gh auth *: allow`.

## Pattern grammar reminder

`*` is greedy across whitespace. `"gh auth status"` matches only the bare verb with no flags; `"gh auth status *"` matches any suffix including flag combos. Both are needed to cover the no-args and with-args cases per the project's convention (see `opencode.jsonc` `git status *` / `git status` pair).

---

### Family: `auth`

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh auth login | AUTH | — | — | Credential mutation; writes hosts.yml. Falls through to `*: ask`. |
| gh auth logout | AUTH | — | — | Credential mutation; removes auth state. Falls through to `*: ask`. |
| gh auth refresh | AUTH | — | — | Rewrites token / scopes; AUTH per rubric. Falls through to `*: ask`. |
| gh auth setup-git | AUTH | — | — | Mutates git credential helper config. Falls through to `*: ask`. |
| gh auth status | SAFE | `-t`, `--show-token` (prints secret to stdout) | `"gh auth status": "allow"`, `"gh auth status *": "allow"`, then explicit `"gh auth status --show-token*": "ask"` and `"gh auth status -t*": "ask"` emitted AFTER the allow (last-match-wins demotes the secret-exposing flag) | Read-only dashboard of auth state; verb is on the SAFE side of the rubric. `--show-token` leaks a credential so it must be demoted, analogous to the pre-decided `gh auth token: ask` rule. |
| gh auth switch | AUTH | — | — | Changes active credential context; rewrites config. Falls through to `*: ask`. |
| gh auth token | AUTH | — | — | Pre-decided ask (token exposure risk). Falls through to `*: ask`. |

### Family: `config`

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh config get | SAFE | — | `"gh config get": "allow"`, `"gh config get *": "allow"` | Pure read of a config key. No network, no write. Only flags are `-h/--hostname` (context selection) and formatting flags. |
| gh config list | SAFE | — | `"gh config list": "allow"`, `"gh config list *": "allow"`, `"gh config ls": "allow"`, `"gh config ls *": "allow"` | Pure read of the config map. Alias `ls` exists per `--help`; covered explicitly. Only flag is `-h/--hostname`. |
| gh config set | MUTATING | — | — | Rewrites config file (`Set` verb). Falls through to `*: ask`. Per guidance, never use `gh config *: allow` because it would wrongly admit `set` / `clear-cache`. |
| gh config clear-cache | MUTATING | — | — | Local-state write: deletes cache dir on disk. Classified MUTATING per plan hint — a local write is still a write. Falls through to `*: ask`. |

### Family: `status`

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh status | SAFE | — | `"gh status": "allow"`, `"gh status *": "allow"` | Prints the user's notifications / mentions / review-requests dashboard. Only flags are `-e/--exclude` (filter) and `-o/--org` (scope). No mutation, no browser, no file write. |

### Family: `cache`

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh cache list | SAFE | — | `"gh cache list": "allow"`, `"gh cache list *": "allow"`, `"gh cache ls": "allow"`, `"gh cache ls *": "allow"` | GET of Actions caches. Alias `ls`. Only flags are filters and formatting. |
| gh cache delete | MUTATING | — | — | Server-side DELETE of Actions caches (requires `repo` scope per `--help`). Falls through to `*: ask`. Per guidance, emit per-verb allow for `list` only, never `gh cache *: allow`. |

### Family: `completion`

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh completion | SAFE | — | `"gh completion": "allow"`, `"gh completion *": "allow"` | Writes a shell-completion script to stdout. The output is generated code, not executed by `gh`. The only flag `-s/--shell` selects shell dialect. If the user pipes stdout to a file, that is the user's action outside `gh`; the command itself is a read. |

### Family: `licenses`

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh licenses | SAFE | — | `"gh licenses": "allow"`, `"gh licenses *": "allow"` | Prints third-party-license information baked into the binary. No flags beyond `--help`. On gh 2.89.0 this is a single leaf (no `list`/`view` subverbs, contrary to the plan's pre-verification hint). The broad `gh licenses *` pattern therefore safely covers any subverb cli/cli might add in a future minor version — and if such a subverb were mutating, a later `gh licenses * <mutating-flag>` ask from the aggregator would take precedence. |

---

## Summary

- **Leaf count (Agent A scope)**: 16.
- **Per-class counts**: SAFE 7 (`auth status`, `config get`, `config list`, `status`, `cache list`, `completion`, `licenses`); MUTATING 3 (`config set`, `config clear-cache`, `cache delete`); AUTH 6 (`auth login`, `auth logout`, `auth refresh`, `auth setup-git`, `auth switch`, `auth token`); WRITES-LOCAL 0; INTERACTIVE 0; INSTALLS-CODE 0; MANUAL-REVIEW 0.
- **Manual-review commands resolved**: none — every leaf fell on a clear side of the verb rubric, and no ambiguous flag semantics (e.g. `--web`, `--watch`, `--edit`) appear in any command in this scope. No `cli/cli` source inspection was necessary.
- **Commands not confidently classified**: none.
- **Flagged side-effect on a SAFE command**: `gh auth status --show-token` / `-t` prints a credential — requires an explicit per-command `ask` demotion emitted after the corresponding allow (patterns listed in the table).
- **Family-wide allow patterns avoided**: `gh auth *`, `gh config *`, `gh cache *` are NOT proposed, because each family mixes SAFE and ask-class verbs; `findLast` semantics make whole-family allows dangerous.
