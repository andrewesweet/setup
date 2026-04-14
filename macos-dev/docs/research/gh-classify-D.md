# gh CLI Classification — Agent D

Families: `gist`, `search`, `browse`, `copilot`, `codespace`, `agent-task`, `preview`.

Source artifact: `macos-dev/docs/research/gh-cli-commands.json` (gh 2.89.0).

Leaf counts (matches enumeration): gist=7, search=5, browse=1, copilot=1, codespace=14, agent-task=3, preview=1. Total = 32.

Class totals: SAFE = 11, MUTATING = 8, WRITES-LOCAL = 1, INTERACTIVE = 8, INSTALLS-CODE = 1, MANUAL-REVIEW (resolved) = 3.

Patterns assume the aggregator will emit the global demotions `"gh * --web*": "ask"`, `"gh * --edit*": "ask"`, `"gh * --output *": "ask"`, `"gh * --clobber*": "ask"`, and that the file-ending `"*": "ask"` default already handles everything without an explicit `allow`. SAFE rows list only the per-verb `allow` needed; side-effect flags that are already handled by a global ask rule are noted in the Side-effect flags column but not repeated as per-verb asks.

### gist

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
| --- | --- | --- | --- | --- |
| gh gist list | SAFE | — | `"gh gist list": "allow"`, `"gh gist list *": "allow"` | Read-only enumeration; no mutating flags. |
| gh gist view | SAFE | `-w/--web` (demoted via global) | `"gh gist view *": "allow"` | Prints gist content to stdout. `--raw`, `--files`, `-f` are all read-only. `--web` demoted by `gh * --web*`. |
| gh gist create | MUTATING | `-w/--web`, `-p/--public` | (no allow) | Creates a remote gist (POST). Takes file args or stdin. |
| gh gist edit | MUTATING | `-a/--add`, `-r/--remove`, `-d/--desc`, `-f/--filename` | (no allow) | PATCHes an existing gist; opens `$EDITOR` when no flags given. Verb is `edit` → MUTATING per rubric. |
| gh gist delete | MUTATING | `--yes` | (no allow) | DELETEs the gist. |
| gh gist clone | WRITES-LOCAL | — | (no allow) | Writes a clone to disk under CWD; per curl/repo-clone precedent we ask. |
| gh gist rename | MUTATING | — | (no allow) | Renames a file within a gist via PATCH. Verb is `rename` → MUTATING. |

### search

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
| --- | --- | --- | --- | --- |
| gh search repos | SAFE | `-w/--web` (demoted via global) | `"gh search repos *": "allow"` | Pure GET against search API. `--json`, `--jq`, `-t` are stdout only. |
| gh search issues | SAFE | `-w/--web` (demoted via global) | `"gh search issues *": "allow"` | Pure GET. All filter flags are query params. |
| gh search prs | SAFE | `-w/--web` (demoted via global) | `"gh search prs *": "allow"` | Pure GET. `--merged`, `--draft` etc. are filters not mutations. |
| gh search code | SAFE | `-w/--web` (demoted via global) | `"gh search code *": "allow"` | Pure GET. |
| gh search commits | SAFE | `-w/--web` (demoted via global) | `"gh search commits *": "allow"` | Pure GET. |

### browse

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
| --- | --- | --- | --- | --- |
| gh browse | INTERACTIVE | all flags open browser; `-n/--no-browser` prints URL only | (no allow) | Pre-decided: `gh browse` opens a browser. Leave to global `"*": "ask"`. (A future scoped allow for `gh browse --no-browser *` is possible but out of scope for this agent.) |

### copilot

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
| --- | --- | --- | --- | --- |
| gh copilot | INSTALLS-CODE | `--remove` | (no allow; rely on global `*: ask`) | Source (`pkg/cmd/copilot/copilot.go`) confirms: downloads and executes the external `copilot` binary, installs into `config.DataDir()/copilot`, `--remove` deletes that tree, no-arg invocation runs the LLM CLI which emits arbitrary shell suggestions. Pre-decided: all copilot invocations ask. Enumeration has one leaf (the root command); there are no `suggest`/`explain` subverbs at the `gh` level — those are owned by the Copilot CLI. |

### codespace

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
| --- | --- | --- | --- | --- |
| gh codespace list | SAFE | `-w/--web` (demoted via global) | `"gh codespace list": "allow"`, `"gh codespace list *": "allow"` | GET-only list of codespaces. |
| gh codespace view | SAFE | — | `"gh codespace view *": "allow"` | GET-only metadata dump. All flags are selector/formatting. No `--web`, no `--follow`. |
| gh codespace ssh | INTERACTIVE | all | (no allow) | Interactive SSH session. Pre-decided ask. |
| gh codespace code | INTERACTIVE | `-w/--web` | (no allow) | Opens VS Code (or Insiders) attached to codespace; pre-decided ask. |
| gh codespace cp | WRITES-LOCAL / MUTATING | `-r/--recursive`, `-e/--expand` | (no allow) | Copies files to/from codespace; writes local or remote FS. |
| gh codespace create | MUTATING | `-w/--web`, `-s/--status` | (no allow) | POST create. |
| gh codespace delete | MUTATING | `--all`, `--days`, `-f/--force` | (no allow) | DELETE. |
| gh codespace edit | MUTATING | — | (no allow) | PATCH. |
| gh codespace stop | MUTATING | — | (no allow) | POST stop. |
| gh codespace rebuild | MUTATING | `--full` | (no allow) | POST rebuild. |
| gh codespace jupyter | INTERACTIVE | — | (no allow) | Opens Jupyter in browser via tunnelled port; pre-decided ask. |
| gh codespace logs | INTERACTIVE when `-f/--follow`, otherwise SAFE-adjacent | `-f/--follow` | (no allow) | `--follow` streams indefinitely (blocks session). Without `--follow` it prints a snapshot, but safely distinguishing the two with OpenCode's wildcard grammar is fragile (`*` is greedy across whitespace), so keep ask. |
| gh codespace ports forward | INTERACTIVE | — | (no allow) | Long-running port-forward tunnel; blocks session. |
| gh codespace ports visibility | MUTATING | — | (no allow) | Mutates port visibility server-side. Example: `gh codespace ports visibility 80:org 3000:private 8000:public`. |

Note: enumeration does NOT include a standalone `gh codespace ports` (list) leaf — the only `ports` leaves are `forward` and `visibility`. Bare `gh codespace ports` dispatches at the parent level and falls through to the global `*: ask`.

### agent-task (preview)

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
| --- | --- | --- | --- | --- |
| gh agent-task list | SAFE | `-w/--web` (demoted via global) | `"gh agent-task list": "allow"`, `"gh agent-task list *": "allow"` | MANUAL-REVIEW resolved via source (`pkg/cmd/agent-task/list/*.go`): GET only, optional `--web` opens URL (handled by global). |
| gh agent-task view | SAFE | `-w/--web` (global), `--follow` (streams logs), `--log` | `"gh agent-task view *": "allow"` | MANUAL-REVIEW resolved via source (`pkg/cmd/agent-task/view/*.go`): default path is GET metadata. `--follow` streams session logs (blocks) and requires `--log`; per last-match-wins we would want `"gh agent-task view * --follow*": "ask"` appended after the allow. Flag demotions are aggregator scope; flagged here. |
| gh agent-task create | MUTATING | `-F/--from-file`, `--follow`, `-a/--custom-agent`, `-b/--base` | (no allow) | MANUAL-REVIEW resolved via source (`pkg/cmd/agent-task/create/*.go`): POSTs a new task and opens an interactive `MarkdownEditor` when the description is missing. Verb is `create` → MUTATING. |

### preview

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
| --- | --- | --- | --- | --- |
| gh preview prompter | INTERACTIVE | — | (no allow) | Source (`pkg/cmd/preview/prompter/prompter.go`): a developer test harness that runs every prompter type (select, multi-select, input, password, confirm, markdown-editor, etc.) interactively. Blocks session waiting for TTY input. |

## Per-command problematic flags summary (for the aggregator)

The following verb-flag combinations are SAFE on the happy path but are demoted by the global ask rules the aggregator emits:

- `gh gist view -w|--web`
- `gh search repos|issues|prs|code|commits -w|--web`
- `gh codespace list -w|--web`
- `gh agent-task list -w|--web`
- `gh agent-task view -w|--web`

The following verb-flag combinations are NOT covered by the standard globals and should be demoted per-verb by the aggregator (or left to `"*": "ask"`):

- `gh agent-task view --follow`, `gh agent-task view --log` — blocks session / streams.
- `gh codespace logs --follow` — blocks session (already not in allow list; noted for completeness).

No unclassifiable leaves. All 32 leaves are accounted for.
