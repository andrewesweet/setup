# Plan: Full `gh` CLI Safe-Allowlist Enumeration

**Status**: proposed
**Date**: 2026-04-14
**Owner**: you + Claude
**Related**: `macos-dev/opencode/opencode.jsonc`, `macos-dev/docs/design/opencode.md`

## Objective

Produce a tightly scoped, exhaustive allowlist for `gh` in `opencode.jsonc` by enumerating every `gh` command and subcommand, classifying each as SAFE / MUTATING / INTERACTIVE / AMBIGUOUS, and emitting the corresponding OpenCode permission patterns. Replace today's hand-curated ~10-verb block with a machine-backed full surface sweep.

## Motivation

Today's `gh` allowlist was written from memory and covers a handful of verbs (`auth status`, `repo view`, `pr list|view|diff|checks`, `issue list|view`, `workflow list|view`, `run list|view`, `release list|view`, `label list`). `gh pr checks` was added only because it came up in conversation — a strong signal that we are missing other read-only verbs (`gh status`, `gh search *`, `gh ruleset list`, `gh cache list`, `gh secret list`, `gh variable list`, `gh environment list`, `gh attestation verify`, possibly more). Guessing is error-prone and doesn't scale as gh ships new subcommands. Enumeration is cheap and gives a defensible, reviewable surface.

## Sources and tradeoffs

| Source | Authoritative | Machine-parseable | Matches our installed version | Notes |
|---|---|---|---|---|
| `gh help` self-documentation | Yes for our binary | Yes (structured stdout) | Yes | Primary. Version-accurate. |
| github.com/cli/cli source (`pkg/cmd/`) | Yes, ground truth | Yes (Go AST + dir tree) | Trunk may diverge from our pinned version | Cross-check for ambiguous classifications. |
| cli.github.com/manual/gh | Generated from source | Partial (HTML) | Matches a release, not our local | Tiebreaker. |

**Strategy**: `gh help` for the walk, source for ambiguity resolution, manual as tiebreaker.

## Methodology (5 phases)

### Phase 1 — Enumerate (scripted, ~30 min)

Walk `gh help` recursively. For each command node, extract:

- Full command path (e.g. `gh pr checks`)
- Short description
- Full flag list (parsed from `<cmd> --help`)
- Examples block (signal for read-vs-mutate)

Emit `docs/research/gh-cli-commands.json` — a structured tree per invocation point. Record gh version so we can detect drift on re-runs.

Script: a Python or bash walker that invokes `gh help`, `gh <family> --help`, `gh <family> <verb> --help`, using regex to extract subcommand names. Safe to run repeatedly — it only reads.

### Phase 2 — Classify (heuristic + manual, ~2 hrs)

Apply a verb rubric first:

| Verb / name signal | Class |
|---|---|
| `List`, `View`, `Show`, `Get`, `Check`, `Status`, `Logs`, `Diff`, `Print` | SAFE |
| `Create`, `Delete`, `Edit`, `Update`, `Set`, `Add`, `Remove`, `Merge`, `Close`, `Reopen`, `Rerun`, `Lock`, `Unlock`, `Enable`, `Disable`, `Sync`, `Rename`, `Transfer`, `Archive`, `Unarchive`, `Approve`, `Revoke`, `Restore` | MUTATING |
| `Clone`, `Download`, `Fork`, `Checkout` | WRITES-LOCAL |
| `Login`, `Logout`, `Refresh`, `Switch`, `Token` | AUTH (credential-mutating) |
| `Browse`, `Ssh` | INTERACTIVE (browser / TTY) |
| `Install`, `Upgrade`, `Uninstall` (extension) | INSTALLS-CODE |
| `Run`, `Exec`, `Compose`, `<ambiguous-name>` | MANUAL-REVIEW |

Manual-review bucket: anything whose class isn't obvious from the name. Expect 20-40 cases. Examples from today's `gh`:

- `gh cache delete` — mutating, but scoped to an ephemeral cache; policy call.
- `gh copilot suggest` — calls an LLM that can produce arbitrary shell; treat as ask.
- `gh attestation verify` — reads only; SAFE.
- `gh release download` — writes local files; needs scope or ask.
- `gh run watch` — long-running stream; hangs a session — INTERACTIVE.
- `gh ruleset *` — most verbs are read-only but `check` is ambiguous; read source.
- `gh extension exec` — runs arbitrary extension code; NEVER auto-allow.

For each manual-review case, open `github.com/cli/cli/tree/trunk/pkg/cmd/<family>/<verb>/` and grep for `api.Post`, `api.Put`, `api.Patch`, `api.Delete`, `ioutil.WriteFile`, `os.Create`, `os.Mkdir`, `exec.Command`, browser-open helpers. Absence of these on the happy path confirms SAFE.

### Phase 3 — Flag analysis (~1 hr)

For every SAFE command, enumerate its flags from `--help` and flag any that introduce a side effect:

| Flag | Effect | Handling |
|---|---|---|
| `--web` | opens browser | global ask: `"gh * --web*": "ask"` |
| `--edit` | opens `$EDITOR` | ask |
| `--output <file>`, `--dir <path>`, `--clobber` | writes file | ask by default; allow scoped paths later if desired |
| `--json`, `--jq`, `-t/--template` | stdout formatting | SAFE |
| `-R <repo>`, `--hostname <h>` | context selection | SAFE |
| `--cache` | writes cache | SAFE (low-risk) but noted |

Global ask-overrides are cheaper than per-command denials. Example:

```jsonc
"gh * --web*": "ask",
"gh * --edit*": "ask",
"gh * --output *": "ask",
"gh * --clobber*": "ask"
```

Placed AFTER the per-command SAFE allows (last-match-wins).

### Phase 4 — Produce allowlist (~30 min)

Emit a review-ready matrix in `docs/research/gh-cli-command-matrix.md`:

```
| Command                      | Class    | Flag notes              | Pattern                                  |
| ---------------------------- | -------- | ----------------------- | ---------------------------------------- |
| gh pr checks                 | SAFE     | --web → ask via global  | "gh pr checks *": "allow"                |
| gh pr create                 | MUTATING | —                       | (no allow)                               |
| gh pr view                   | SAFE     | --web → ask via global  | "gh pr view *": "allow"                  |
| gh repo clone                | WRITES-LOCAL | asks                | (no allow)                               |
| gh extension exec            | INSTALLS-CODE | deny              | "gh extension exec *": "deny"            |
```

Derive the final `gh` block for `opencode.jsonc` directly from the matrix. Replace today's hand-curated block wholesale.

### Phase 5 — Validate and integrate (~1 hr)

1. Extend the matcher simulator with 50-80 `gh` test cases covering every classification bucket. Every SAFE pattern must resolve to `allow`; every MUTATING verb must resolve to `ask`; every `--web` invocation must resolve to `ask`; every denied extension/exec verb must resolve to `deny`.
2. Cross-check 20 random SAFE classifications by actually running them in a throwaway shell against a public read-only target and confirming no side effects.
3. Apply the new block. Re-run simulator against the final file.
4. Update `docs/design/opencode.md` gh section with a link to the matrix and a summary of the policy.

## Deliverables

1. `docs/research/gh-cli-commands.json` — structured enumeration (Phase 1 output).
2. `docs/research/gh-cli-command-matrix.md` — classification table (Phase 2-3 output).
3. Updated `macos-dev/opencode/opencode.jsonc` — new `gh` block.
4. Updated `macos-dev/docs/design/opencode.md` — new `gh` policy section.
5. `scripts/gh-allowlist-audit.sh` — re-runnable walker + simulator so we can re-classify on gh version bumps.

## Risks and edge cases

- **Extensions (`gh <extension-name>`)**: invokes arbitrary third-party Go binaries installed via `gh extension install`. MUST NOT be auto-allowed. Safe verbs: `gh extension list|view|browse|search`. Unsafe: `install|remove|upgrade|create|exec`.
- **Aliases (`gh <user-alias>`)**: a user-defined alias expands to anything the user configured. Cannot be pattern-matched safely. `gh alias list` is fine; arbitrary alias invocations should fall through to the global `*: ask`.
- **`gh copilot *`**: calls an LLM; produces suggestions that might include mutating shell commands. All subverbs → ask.
- **`gh codespace *`**: mostly interactive (ssh, code, ports). All interactive verbs → ask. `gh codespace list|view` → SAFE.
- **`gh run watch`**: streams CI output indefinitely, hangs a session. INTERACTIVE.
- **`gh repo clone`, `gh pr checkout`**: useful but write to disk. Precedent from our curl discussion is ask-by-default for local writes. Apply same here.
- **Version drift**: gh ships new subcommands regularly. Plan a re-run cadence tied to Brewfile bumps (see Open Questions).
- **Enterprise/GHES-only features**: skip; the setup targets github.com.
- **`gh api`**: already handled separately in the existing GET-only policy. Not re-covered by this plan.

## Validation strategy

- **Simulator parity**: every `gh` test case passes the Python port of `Wildcard.match + findLast` (the same harness used for the curl/rm work).
- **Live spot check**: pick 5 SAFE and 5 MUTATING cases at random; run them inside an interactive `opencode` session with the new config; confirm SAFE run silently and MUTATING prompt.
- **Lint**: no duplicate pattern keys in the same category. No pattern allowed and denied without an intervening rule to disambiguate. No `allow` pattern that follows a `deny` it was meant to scope (ordering audit).
- **Diff review**: final `gh` block diff MUST be inspectable line-by-line. Grouped by family, commented by category.

## Dispatch plan

Phase 1 and the heuristic half of Phase 2 are scriptable — one session.
Phases 2-manual, 3, and 4 parallelize well across subagents grouped by command family:

- Agent A: `auth`, `config`, `status`, `cache`
- Agent B: `repo`, `pr`, `issue`
- Agent C: `workflow`, `run`, `release`, `label`
- Agent D: `gist`, `search`, `browse`, `copilot`, `codespace`
- Agent E: `secret`, `variable`, `environment`, `ruleset`, `alias`, `extension`, `attestation`

Each agent is briefed identically: read `gh <family> --help` and every subcommand help; classify against the rubric; cross-check ambiguous entries against `github.com/cli/cli/tree/trunk/pkg/cmd/<family>`; emit a standardized markdown row per subcommand with: full command, class, flag notes, proposed pattern(s), and a 1-line justification. The five outputs merge into a single matrix for your review.

## Effort estimate

| Phase | Time | Runs unattended? |
|---|---|---|
| 1. Enumerate | 30 min | yes |
| 2a. Heuristic classify | 20 min | yes |
| 2b. Manual review | 1.5 hrs | no (needs judgement) |
| 3. Flag analysis | 1 hr | partly |
| 4. Emit patterns | 30 min | yes |
| 5. Validate + integrate | 1 hr | partly |

Total ≈ 5 hrs, ≈ 3 of which are mechanical.

## Open questions

1. **Local writes**: for `gh repo clone`, `gh pr checkout`, `gh release download` — ask by default (consistent with curl file-write policy), or allow when scoped to `~/workspace/**` and `/tmp/**`?
2. **`gh auth token`**: allow (convenient for debugging token scope) or ask (token exposure risk if logs are captured)? Defaulting to ask seems right.
3. **Extensions**: deny-list `gh extension exec|install|remove|upgrade` explicitly, or trust the global `*: ask`? Explicit deny is louder and catches social-engineering attempts that would prepend allow-looking tokens.
4. **Re-run cadence**: tie to the version pinned in `Brewfile`. Every time `brew "gh"` bumps, re-run Phase 1 and diff the matrix. Add as a CI check?
5. **Scope of this plan**: strict `gh` only, or also `gh-dash` (already present in tooling) and any `gh` extensions we ship by default? Suggest: gh only for this pass, gh-dash in a follow-up.

## Not in scope

- `gh api` GET-only policy (already landed in the curl/gh api fixes).
- Allowing any `gh` verb beyond what static classification permits — no "let's allow mutations in workspace X" exceptions in this pass.
- Per-endpoint POST allowlist for `gh api` — separate follow-up.

## Next step if approved

Run Phase 1 now (scripted, 30 min), produce the enumeration artifact, then pause for your review before kicking off the Phase 2 classification agents.
