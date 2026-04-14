# gh CLI Classification — Agent C (workflow, run, release, label, project)

**Source**: `macos-dev/docs/research/gh-cli-commands.json` (gh 2.89.0, generated 2026-03-26).
**Families**: workflow (5) + run (7) + release (10) + label (5) + project (19) = **46 leaves**.
**Rubric**: per plan `2026-04-14-gh-cli-safe-allowlist.md`. Last-match-wins with `*` greedy across whitespace (`opencode.md` Rule Evaluation Semantics). Global `--web / --edit / --output / --dir / --clobber` demotion is emitted by the aggregator; side-effect flags are noted per-row, not re-patterned here.

## Summary counts

| Class | Count |
|---|---|
| SAFE | 13 |
| MUTATING | 29 |
| WRITES-LOCAL | 2 |
| INTERACTIVE | 1 |
| AUTH / INSTALLS-CODE / MANUAL-REVIEW | 0 / 0 / 0 (all resolved) |

Manual-review resolved via `gh api repos/cli/cli/contents/pkg/cmd/<family>/<verb>/`:

- `gh release verify` — SAFE. Source `pkg/cmd/release/verify/verify.go` uses `api.NewLiveClient(...).GetByDigest(...)` (attestation GET) and `fmt.Fprintln`; no `api.Post|Put|Patch|Delete`, no `os.Create|WriteFile`, no browser.
- `gh release verify-asset` — SAFE. Source `pkg/cmd/release/verify-asset/verify_asset.go` likewise reads attestations + local asset bytes; no writes.
- `gh run view --log / --log-failed` — SAFE with note. Stream is bounded by run size. `pkg/cmd/run/view/view.go` does call `os.Create` but only against gh's own cache dir (`RunLogCache`), not cwd; treat as low-risk cache write analogous to `--cache` in the rubric.
- `gh run watch` — INTERACTIVE. `pkg/cmd/run/watch/watch.go` is a `for { ...; time.Sleep(duration) }` refresh loop (default 3 s interval, "Press Ctrl+C to quit"). Hangs an OpenCode session.
- `gh label clone` — MUTATING. Despite the "clone" verb, this copies labels *into* a target repo via label-create API calls (not a local clone). Distinct from `gh repo clone`.
- `gh workflow run|enable|disable` — MUTATING (workflow dispatch = POST; enable/disable = PUT).

**Unclassifiable**: none in this family set.

---

## workflow (5)

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh workflow list | SAFE | — | `"gh workflow list": "allow"`, `"gh workflow list *": "allow"` | Read-only listing; flags are `--all/--jq/--json/--limit/--template` — all stdout-only. |
| gh workflow view | SAFE | `--web` (browser) | `"gh workflow view *": "allow"` | Prints workflow definition / recent runs. `--yaml` is stdout. `--web` demoted to ask by aggregator global. |
| gh workflow run | MUTATING | — | (no allow) | Triggers `workflow_dispatch` via POST. |
| gh workflow enable | MUTATING | — | (no allow) | PUT to enable workflow. |
| gh workflow disable | MUTATING | — | (no allow) | PUT to disable workflow. |

## run (7)

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh run list | SAFE | — | `"gh run list": "allow"`, `"gh run list *": "allow"` | Filter/list workflow runs; all flags stdout-only. |
| gh run view | SAFE | `--web` (browser); `--log`/`--log-failed` stream logs bounded by run size, but write to gh's `RunLogCache` (`os.Create` in cache dir) — low-risk cache like `--cache` rubric entry. `--exit-status` only affects exit code. | `"gh run view *": "allow"` | Displays run summary + optional bounded log stream. `--web` demoted globally. |
| gh run watch | INTERACTIVE | `-i/--interval`, `--compact`, `--exit-status` — inert, but command itself is a `for { ... time.Sleep } ` refresh loop | (no allow; aggregator may add `"gh run watch*": "ask"` explicitly) | Long-running TTY refresh; hangs a session. |
| gh run download | WRITES-LOCAL | `-D/--dir`, `-n/--name`, `-p/--pattern` — writes artifact files to cwd/dir | (no allow) | Downloads artifacts to disk; no workspace scoping in this pass (plan §Risks: local writes default to ask). |
| gh run rerun | MUTATING | — | (no allow) | POST to re-run workflow. |
| gh run cancel | MUTATING | — | (no allow) | POST to cancel run. |
| gh run delete | MUTATING | — | (no allow) | DELETE run. |

## release (10)

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh release list | SAFE | — | `"gh release list": "allow"`, `"gh release list *": "allow"` | Read-only listing; all flags stdout-only. |
| gh release view | SAFE | `--web` (browser) | `"gh release view *": "allow"` | Prints release metadata; `--web` demoted globally. |
| gh release verify | SAFE | — | `"gh release verify *": "allow"` | Attestation GET only (`api.Client.GetByDigest`); no POST/PUT/PATCH/DELETE, no file writes, no browser. (Manual-review resolved via source.) |
| gh release verify-asset | SAFE | — | `"gh release verify-asset *": "allow"` | Same pattern as `verify`, scoped to a local asset path; reads file bytes + attestation GET. No writes. (Manual-review resolved via source.) |
| gh release download | WRITES-LOCAL | `-D/--dir`, `-O/--output`, `--clobber`, `--skip-existing`, `-A/--archive`, `-p/--pattern` — all write files | (no allow) | Pre-decided policy: local-write verbs are ask — no workspace scoping in this pass. |
| gh release create | MUTATING | — | (no allow) | Creates release (POST). |
| gh release edit | MUTATING | — | (no allow) | PATCH release. |
| gh release delete | MUTATING | — | (no allow) | DELETE release. |
| gh release delete-asset | MUTATING | — | (no allow) | DELETE asset. |
| gh release upload | MUTATING | — | (no allow) | Uploads asset (POST). |

## label (5)

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh label list | SAFE | `-w/--web` (browser) | `"gh label list": "allow"`, `"gh label list *": "allow"` | Read-only listing. `--web` demoted globally. |
| gh label clone | MUTATING | — | (no allow) | Copies labels *into* target repo via POST label-create — NOT a local clone. Name collides with `repo clone`; policy diverges. |
| gh label create | MUTATING | — | (no allow) | POST label. |
| gh label edit | MUTATING | — | (no allow) | PATCH label. |
| gh label delete | MUTATING | — | (no allow) | DELETE label. |

## project (19)

Mixed family: 4 SAFE read verbs, 15 mutating. Per plan, avoid `"gh project *": "allow"` — emit per-verb allows only.

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh project list | SAFE | `-w/--web` (browser) | `"gh project list": "allow"`, `"gh project list *": "allow"` | Read-only listing. |
| gh project view | SAFE | `-w/--web` (browser) | `"gh project view *": "allow"` | Read-only project display. |
| gh project field-list | SAFE | — | `"gh project field-list *": "allow"` | Read-only field enumeration. |
| gh project item-list | SAFE | — | `"gh project item-list *": "allow"` | Read-only item enumeration. |
| gh project create | MUTATING | — | (no allow) | Creates a project. |
| gh project copy | MUTATING | — | (no allow) | Copies a project (creates target). |
| gh project close | MUTATING | — | (no allow) | Closes a project. |
| gh project delete | MUTATING | — | (no allow) | Deletes a project. |
| gh project edit | MUTATING | — | (no allow) | Edits project metadata. |
| gh project link | MUTATING | — | (no allow) | Links project to repo/team. |
| gh project unlink | MUTATING | — | (no allow) | Unlinks project. |
| gh project mark-template | MUTATING | — | (no allow) | Toggles template flag. |
| gh project field-create | MUTATING | — | (no allow) | Creates field. |
| gh project field-delete | MUTATING | — | (no allow) | Deletes field. |
| gh project item-add | MUTATING | — | (no allow) | Adds existing issue/PR to project. |
| gh project item-archive | MUTATING | — | (no allow) | Archives item. |
| gh project item-create | MUTATING | — | (no allow) | Creates draft item. |
| gh project item-delete | MUTATING | — | (no allow) | Deletes item. |
| gh project item-edit | MUTATING | — | (no allow) | Edits item field values. |

---

## Notes for aggregator

- **Patterns are last-match-wins**: place the SAFE `allow` rules per family before the global `"gh * --web*": "ask"`, `"gh * --edit*": "ask"`, `"gh * --output *": "ask"`, `"gh * --clobber*": "ask"`, `"gh * --dir *": "ask"`, `"gh * --log*": "ask"` demotion layer, so `--web`/`--log`/... invocations on otherwise-SAFE verbs fall through to `ask`.
- **`gh run view --log` cache writes**: gh writes a zip to its own cache dir via `RunLogCache.Create` (`os.Create(<gh-cache>/run-log-*.zip)`). Not cwd. Classified SAFE consistent with the `--cache` rubric row; flag this to reviewer if cache writes are later tightened.
- **`gh workflow view --yaml`**: stdout-only; no extra demotion needed.
- **`gh run watch`**: if the aggregator wants belt-and-braces, add an explicit `"gh run watch*": "ask"` after the family rules — the verb has no SAFE allow above it, so the global `*: ask` would already catch it, but an explicit rule documents intent.
- **Bare forms**: both `"gh <family> <verb>": "allow"` and `"gh <family> <verb> *": "allow"` are listed where the bare form is useful (e.g. `gh run list`, `gh project list`); elsewhere the trailing `*` form alone suffices because the verb always takes an argument (release tag, run id, workflow id, project number).
