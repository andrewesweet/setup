# Plan: `gcloud` CLI Safe-Allowlist

**Status**: proposed
**Date**: 2026-04-14
**Owner**: you + Claude
**Related**: `macos-dev/opencode/opencode.jsonc`, `macos-dev/docs/design/opencode.md`, `macos-dev/docs/plans/2026-04-14-gh-cli-safe-allowlist.md`

## Objective

Produce an exhaustive, defensible safe-allowlist for `gcloud` (Google Cloud SDK) in `opencode.jsonc`. The team uses `gcloud` extensively across many GCP services, so the policy must generalize without requiring per-leaf enumeration, while still distinguishing admin/metadata reads (allow) from data reads, data writes, and metadata-admin writes (ask). Ship it with a re-runnable walker and a matcher simulator so the policy stays auditable on SDK version bumps.

## Why verb-pattern rules, not per-leaf allows

The gh CLI has 183 leaves; enumerating every SAFE verb as its own allow pattern was tractable. The gcloud surface is 100× larger:

- 18,728 total commands on gcloud 564.0.0.
- 12,204 of those (65%) are under `gcloud alpha` / `gcloud beta`, which this plan treats as uniformly ask by policy.
- The remaining 6,524 non-alpha/beta leaves are dominated by a small vocabulary of verbs: `list` (2,387), `describe` (2,375), `delete` (1,708), `create` (1,540), `update` (1,376), `get-iam-policy` (339), `set-iam-policy` (324), `add/remove-iam-policy-binding` (537), `export/import` (422), plus a long tail.

OpenCode's matcher is `*` → `.*` greedy-across-whitespace, so a single pattern like `"gcloud * list *": "allow"` matches every `gcloud <family> <resource> list ...` command in one rule. Verb-pattern rules therefore compact the policy from thousands of lines to tens.

## Classification rubric

| Class | Examples | Policy |
|---|---|---|
| SAFE — admin/metadata read | `gcloud * list`, `gcloud * describe`, `gcloud * get-iam-policy`, `gcloud * test-iam-permissions`, `gcloud auth list`, `gcloud config list`, `gcloud info`, `gcloud version`, `gcloud * get-value`, `gcloud * get-ancestors-iam-policy`, `gcloud * get-public-key`, `gcloud * explain`, `gcloud * search` | allow |
| DATA-READ | `gcloud storage ls/cat/du`, `gcloud storage objects list/describe`, `gcloud secrets versions access`, `gcloud logging read/tail`, `gcloud pubsub subscriptions pull`, `gcloud kms decrypt/raw-decrypt/asymmetric-decrypt/asymmetric-verify/mac-verify`, `gcloud spanner databases execute-sql`, `gcloud ai endpoints predict`, `gcloud ai-platform predict`, `gcloud ml language/speech/vision *` | ask |
| DATA-WRITE | `gcloud storage cp/mv/rm/rsync`, `gcloud storage objects *`, `gcloud kms encrypt/raw-encrypt/asymmetric-encrypt/asymmetric-sign/mac-sign`, `gcloud logging write`, `gcloud pubsub topics publish`, `gcloud firestore/datastore import/export`, `gcloud transfer jobs run` | ask |
| METADATA-ADMIN WRITE | `create`, `delete`, `update`, `patch`, `set-*`, `add-*`, `remove-*`, `enable`, `disable`, `restore`, `revoke`, `suspend`, `rollback`, `cancel`, `start`, `stop`, `resume`, `deploy`, `submit`, `run` | ask (fall through to `*: ask` default — no allow pattern needed) |
| INTERACTIVE | `gcloud * ssh`, `gcloud * scp`, `gcloud compute start-iap-tunnel`, `gcloud sql connect`, `gcloud cloud-shell ssh/scp`, `gcloud init`, `gcloud emulators * start`, `gcloud docker`, `gcloud * operations wait`, `gcloud logging tail` | ask |
| AUTH / CREDENTIAL | `gcloud auth login/logout/revoke`, `gcloud auth activate-service-account`, `gcloud auth print-access-token`, `gcloud auth print-identity-token`, `gcloud auth application-default login/revoke/print-access-token`, `gcloud iam service-accounts keys create`, `gcloud container clusters get-credentials` | ask |
| INSTALLS-CODE | `gcloud components install/update/remove/restore/reinstall` | ask |
| ALPHA / BETA | `gcloud alpha *`, `gcloud beta *` | ask (blanket) |

Within a SAFE-verb family, specific resources may be data-plane and must therefore be re-asked even though the verb name (`list`, `describe`) is usually safe. For example `gcloud storage objects list` is listing *objects* (content metadata close to data), and the team prefers to treat all object-level storage ops as ask.

## Rule layering in `opencode.jsonc` (last-match-wins)

1. **Universal safe-verb allows** — one `"gcloud * <verb> *"` pattern per SAFE verb (list, describe, get-iam-policy, …). Plus hard-coded allows for gcloud's singleton utilities (`info`, `version`, `help`, `topic *`, `auth list`, `config list`, …).
2. **Data-plane and data-service asks** — override the universal allows for `gcloud storage ls|cp|mv|rm|cat|du|rsync|sign-url|hash|objects ...`, `gcloud secrets versions access`, `gcloud logging read|tail|write`, `gcloud pubsub subscriptions pull`, `gcloud pubsub topics publish`, `gcloud kms encrypt|decrypt|asymmetric-*|raw-*|mac-*`, `gcloud spanner databases execute-sql`, `gcloud firestore|datastore export|import`, `gcloud transfer jobs run`, `gcloud ai endpoints predict`, `gcloud ai-platform predict`, `gcloud ml * *`.
3. **Interactive / session-blocking asks** — `gcloud compute ssh|scp|start-iap-tunnel|reset-windows-password`, `gcloud sql connect|export|import`, `gcloud cloud-shell ssh|scp`, `gcloud init`, `gcloud emulators * start`, `gcloud docker *`, `gcloud * operations wait *`, `gcloud * tail *`, `gcloud container clusters get-credentials`.
4. **Auth / credential asks** — `gcloud auth login|logout|revoke|activate-service-account|print-access-token|print-identity-token`, `gcloud auth application-default *`, `gcloud iam service-accounts keys create`.
5. **Components installs-code asks** — `gcloud components install|update|remove|restore|reinstall|repositories *`.
6. **Alpha / beta blanket ask** — `gcloud alpha *`, `gcloud beta *`. Placed near the end so these win over every universal allow. Any allow for an alpha/beta verb therefore requires an explicit rule AFTER this layer, which we do not provide.

Note: ordering above is config-order (lexical order in the file), and findLast wins. Data-plane / interactive / auth / components asks must each appear AFTER the universal allows so they demote those matches. The alpha/beta blanket is placed after ALL of them.

## Data-plane service short-list (closed set)

The following services are considered to contain user data at the object level:

- `storage` — bucket objects.
- `secrets` — secret material (only `versions access`).
- `logging` — log entries.
- `pubsub` — messages (subscription pulls, topic publishes).
- `kms` — crypto primitives; operations operate on user-supplied plaintext / ciphertext.
- `spanner` — `databases execute-sql` runs user queries.
- `firestore`, `datastore` — document/entity exports and imports.
- `transfer` — Storage Transfer Service jobs move data.
- `ai`, `ai-platform`, `ml` — predict/detect endpoints operate on user payloads.

Every other top-level service is treated as metadata-plane unless an agent audit surfaces a counter-example.

## Verbs considered SAFE universally (applied across every non-alpha/beta service)

- `list` — enumerate resources.
- `describe` — show a single resource.
- `get-iam-policy`, `get-ancestors-iam-policy`, `test-iam-permissions` — IAM inspection, explicitly included per the rubric.
- `get-value` — config reads.
- `get-public-key` — public-key material is not a secret.
- `get` — used in a few services as a describe-equivalent.
- `search` — catalog search.
- `lookup` — name-to-resource resolution.
- `explain` — IAM role explanation.
- `print-settings` — config-style reads.
- `versions list|describe` — version metadata (but NOT `versions access`, see data-plane).
- `operations list|describe` — async-op metadata (NOT `operations wait`, see interactive).

`version` and `info` as standalone `gcloud` commands are allowed by name (no service prefix).

## Verbs considered unsafe universally (fall through to `*: ask`)

All mutating verbs (create, delete, update, patch, set-*, add-*, remove-*, enable, disable, cancel, run, submit, deploy, start, stop, resume, restore, rollback, activate, deactivate, suspend, promote, demote, expire, release, revoke, reset, move, rename, attach, detach, bind, unbind, link, unlink, connect, disconnect, sync, import, export, migrate).

## Not in scope

- Per-endpoint allow patterns for `gcloud` POST-equivalent verbs (no `gcloud api` command to allow narrowly).
- `bq` (BigQuery CLI) and `gsutil` — separate binaries shipped with the Cloud SDK; handled in follow-ups.
- Emulator-specific sub-commands beyond the blanket `start` INTERACTIVE ask.
- GCP service enablement / billing flows beyond the generic mutating-verb default.

## Methodology (3 phases)

### Phase 1 — Enumerate (scripted)

1. `scripts/gcloud-allowlist-audit.sh` — wraps `gcloud meta list-commands` into a JSON artifact at `docs/research/gcloud-cli-commands.json`. Records SDK version for drift detection on re-runs.
2. Extract verb distribution and service partition directly from the artifact.

### Phase 2 — Audit (parallel)

Three parallel subagents audit the draft policy in isolated worktrees. Each agent reads this plan plus the enumeration artifact and returns a markdown report documenting any additions or corrections to the draft policy.

- **Agent α — data-plane coverage**: for every top-level service in the enumeration, determine whether the service contains a data-plane subcommand not yet listed in the data-plane short-list. Output: complete data-plane ask list with source justification (service docs or source code).
- **Agent β — interactive / credential / installs-code coverage**: enumerate all commands that block a session (ssh, scp, tunnel, shell, wait, tail, attach, exec), write credentials (get-credentials, token print, key create), or install code (components), beyond the draft policy.
- **Agent γ — universal-verb-pattern sanity**: for each candidate SAFE verb (list, describe, get-iam-policy, etc.), confirm there is no service where the verb has mutating semantics. Flag counter-examples (e.g., a service where `describe` triggers side effects) for per-service asks.

### Phase 3 — Aggregate, simulate, integrate (sequential)

1. Merge audit findings into a canonical policy; emit `docs/research/gcloud-cli-policy.md` with the final ruleset and justification per rule.
2. Insert the gcloud block into `macos-dev/opencode/opencode.jsonc` after the existing gh block, before the curl block.
3. Extend `scripts/gh-allowlist-simulator.py` (or fork a `gcloud-allowlist-simulator.py`) with 60+ gcloud test cases covering every class, every data-plane service, every interactive case, and alpha/beta overrides.
4. Update `docs/design/opencode.md` with a new "gcloud Allowlist Policy" section referencing the policy doc and explaining the verb-pattern approach.
5. Commit on the feat branch; do not push.

## Risks

- **Verb overload**: some services use `list` / `describe` / `get` for operations that aren't pure reads. Agent γ mitigates by surveying counter-examples.
- **Alpha/beta override mistakes**: if a later rule allows `gcloud alpha * list`, it would escape the blanket ask. The simulator must assert that nothing in the config is placed after the alpha/beta asks.
- **Data-plane creep**: GCP regularly adds new data APIs to the CLI. Re-running the audit on SDK version bumps is required to catch new leaves (e.g., `gcloud aiplatform endpoints predict` under a new family).
- **`gcloud * list`** greedy interpretation: the pattern matches at all depths, including `gcloud alpha compute instances list`. The alpha/beta blanket ask demotes that. Simulator must confirm.

## Deliverables

1. `docs/research/gcloud-cli-commands.json` — enumeration artifact (Phase 1).
2. `docs/research/gcloud-cli-policy.md` — canonical policy (Phase 3).
3. `scripts/gcloud-allowlist-audit.sh` — re-runnable walker (Phase 1).
4. `scripts/gcloud-allowlist-simulator.py` — matcher simulator + test suite (Phase 3).
5. Updated `macos-dev/opencode/opencode.jsonc` — new gcloud block.
6. Updated `macos-dev/docs/design/opencode.md` — new gcloud policy section.
