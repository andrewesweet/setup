# gh Classify — Agent E

**Families**: `secret`, `variable`, `ruleset`, `alias`, `extension`, `attestation`, `gpg-key`, `ssh-key`, `org`, `api`
**Source**: `macos-dev/docs/research/gh-cli-commands.json` (gh 2.89.0)
**Leaves classified**: 33

Rubric per plan §Phase 2. Per-verb allows used where a family mixes SAFE and MUTATING verbs. Global side-effect flag demotion (`--web`, `--edit`, `--output`, `--clobber`) is emitted by the aggregator in Phase 4, NOT here — so `--web` on SAFE verbs is noted in the side-effect column but NOT re-asked per-verb.

### secret

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh secret list | SAFE | none (flags are `--app`, `--env`, `--jq`, `--json`, `--org`, `--template`, `--user` — all read-scope selectors and stdout formatting) | `"gh secret list*": "allow"` | Enumeration: read-only list of secret names (values are never returned by the API). |
| gh secret set | MUTATING | n/a | (no allow — falls through to `*: ask`) | Creates or overwrites a repo/org/env secret via `PUT /secrets/{name}`. |
| gh secret delete | MUTATING | n/a | (no allow) | Deletes a secret via `DELETE /secrets/{name}`. |

### variable

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh variable list | SAFE | none (`--env`, `--jq`, `--json`, `--org`, `--template` — read selectors + formatting) | `"gh variable list*": "allow"` | Read-only list of Actions variables. |
| gh variable get | SAFE | none (`--env`, `--jq`, `--json`, `--org`, `--template`) | `"gh variable get*": "allow"` | Reads a single variable value; GET only. |
| gh variable set | MUTATING | n/a | (no allow) | Creates/updates variable via `PATCH`/`POST`. |
| gh variable delete | MUTATING | n/a | (no allow) | Deletes a variable via `DELETE`. |

### ruleset

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh ruleset list | SAFE | `--web` (browser — demoted globally) | `"gh ruleset list*": "allow"` | GET-only listing. `--limit`, `--org`, `--parents` are read selectors. |
| gh ruleset view | SAFE | `--web` | `"gh ruleset view*": "allow"` | GET-only ruleset details. |
| gh ruleset check | SAFE | `--web` | `"gh ruleset check*": "allow"` | DeepWiki-confirmed: `pkg/cmd/ruleset/check/check.go` uses a single `api.Client` GET to fetch branch rules; no Post/Put/Patch/Delete, no disk writes. `--web` opens the rules page (handled by global `gh * --web*: ask`). `--default` selects default branch. |

### alias

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh alias list | SAFE | none | `"gh alias list*": "allow"` | Prints configured aliases from local gh config. |
| gh alias set | WRITES-LOCAL (gh config) | `--clobber`, `-s, --shell` | (no allow) | Writes to `~/.config/gh/config.yml`. `--shell` makes the alias expand to an arbitrary shell command — treated as MUTATING per plan. |
| gh alias delete | WRITES-LOCAL (gh config) | `--all` | (no allow) | Mutates local gh config. |
| gh alias import | WRITES-LOCAL (gh config) | `--clobber` | (no allow) | Imports aliases from a YAML file into gh config. |

**Reminder (not a row — user-defined aliases):** `gh <user-alias>` expands to arbitrary commands (`gh alias set pv 'pr view'`, or `-s` shell aliases). We deliberately do NOT enumerate these; they fall through to `*: ask`.

### extension

Pre-decided policy: install/remove/upgrade/exec/create are **explicit deny** to catch social-engineering attempts that prepend allow-looking tokens. `gh extension view` does NOT exist in gh 2.89.0 (enumeration confirms: only `browse`, `create`, `exec`, `install`, `list`, `remove`, `search`, `upgrade`). So SAFE verbs reduce to `list`, `browse`, `search`.

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh extension list | SAFE | none | `"gh extension list*": "allow"` | Lists installed extensions from local config; no network writes, no disk writes. |
| gh extension browse | INTERACTIVE | `--debug`, `-s, --single-column` | (no allow — falls through to `*: ask`) | Launches a TUI browser for the extension marketplace. Blocks session per Bash Allowlist Policy §2. |
| gh extension search | SAFE | `--web` | `"gh extension search*": "allow"` | GET-only search of the extension marketplace. `--web` handled globally. |
| gh extension install | INSTALLS-CODE | n/a | `"gh extension install*": "deny"` | Downloads and installs a third-party gh extension binary — arbitrary code. Explicit deny. |
| gh extension remove | INSTALLS-CODE (mutates local install state) | n/a | `"gh extension remove*": "deny"` | Deletes extension install; mutating local state. Explicit deny for symmetry. |
| gh extension upgrade | INSTALLS-CODE | `--all`, `--dry-run`, `--force` | `"gh extension upgrade*": "deny"` | Pulls new extension code. Explicit deny (even `--dry-run` — avoid allow-adjacent forms). |
| gh extension exec | INSTALLS-CODE | n/a | `"gh extension exec*": "deny"` | Runs an extension binary with arbitrary args. Explicit deny. |
| gh extension create | WRITES-LOCAL + scaffolds code | `--precompiled` | `"gh extension create*": "deny"` | Scaffolds a new extension directory on disk (writes files). Explicit deny. |

### attestation

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh attestation verify | SAFE | none (all flags are read-only: identity filters, digest, OIDC issuer, trusted-root path, `--jq`, `--template`, `-R`, `--hostname`) | `"gh attestation verify*": "allow"` | Pure crypto verification: downloads bundle via GET, validates signatures locally, prints result. No mutating API calls, no disk writes on the happy path. |
| gh attestation download | WRITES-LOCAL | `-o, --owner`, `-R, --repo`, `--predicate-type`, `--digest-alg`, `-L, --limit`, `--hostname` | (no allow) | Writes attestation bundle files to CWD by design. Ask-by-default per plan §Open Questions #1. |
| gh attestation trusted-root | SAFE | `--verify-only` (mutates local TUF cache — demote via global flag ask if desired; otherwise accept as cache-equivalent), `--tuf-root`, `--tuf-url` | `"gh attestation trusted-root*": "allow"` | DeepWiki-confirmed: downloads TUF trusted-root JSON and prints to stdout; writes to disk only if the user redirects (`>`). `--verify-only` refreshes the local TUF metadata cache (comparable to `--cache`, §Phase 3 SAFE). No mutating API calls. |

### gpg-key

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh gpg-key list | SAFE | none | `"gh gpg-key list*": "allow"` | Lists GPG keys on the account via GET. |
| gh gpg-key add | MUTATING (account credential) | `-t, --title` | (no allow) | `POST /user/gpg_keys` — adds a GPG key to the authenticated account. |
| gh gpg-key delete | MUTATING (account credential) | `-y, --yes` | (no allow) | `DELETE /user/gpg_keys/{id}`. |

### ssh-key

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh ssh-key list | SAFE | none | `"gh ssh-key list*": "allow"` | Lists SSH keys on the account via GET. |
| gh ssh-key add | MUTATING (account credential) | `-t, --title`, `--type` | (no allow) | `POST /user/keys` — adds SSH key to account. |
| gh ssh-key delete | MUTATING (account credential) | `-y, --yes` | (no allow) | `DELETE /user/keys/{id}`. |

### org

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh org list | SAFE | none (`-L, --limit` is a read selector) | `"gh org list*": "allow"` | GET-only list of orgs the user belongs to. |

### api

| Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
|---|---|---|---|---|
| gh api | SAFE-WITH-CAVEATS | n/a (handled by the existing three-layer `gh api` block in `opencode.jsonc`: broad allow → method/body flag asks (`-f`, `--raw-field`, `-F`, `--field`, `--input`, `-X *`, `--request *`, no-space `-XPOST/PUT/DELETE/PATCH`) → explicit GET re-allow) | **(handled by separate gh api block — do not re-pattern)** | `gh api` is the authenticated HTTP client for GitHub. POST/PUT/PATCH/DELETE are selected by explicit `-X` or by the POST-implying body flags per `gh api --help` (design doc §curl and gh api — GET-Only Policy). Patterning it per-endpoint here would shadow or conflict with that block; leave it to the dedicated section. |

---

## Summary

- **Total leaves classified**: 33
- **SAFE**: 13 — `secret list`, `variable list`, `variable get`, `ruleset list`, `ruleset view`, `ruleset check`, `alias list`, `extension list`, `extension search`, `attestation verify`, `attestation trusted-root`, `gpg-key list`, `ssh-key list`, `org list` (14 — `api` is SAFE-with-caveats, counted separately).

  Recount: 14 SAFE rows above. Strict SAFE (will emit `"... *": "allow"`): 14.
- **SAFE-WITH-CAVEATS**: 1 — `gh api` (handled by dedicated block).
- **MUTATING (API)**: 8 — `secret set`, `secret delete`, `variable set`, `variable delete`, `gpg-key add`, `gpg-key delete`, `ssh-key add`, `ssh-key delete`.
- **WRITES-LOCAL**: 4 — `alias set`, `alias delete`, `alias import` (gh config mutations), `attestation download` (file writes).
- **INTERACTIVE**: 1 — `extension browse`.
- **INSTALLS-CODE (explicit deny)**: 5 — `extension install`, `extension remove`, `extension upgrade`, `extension exec`, `extension create`.

  13 + 1 + 8 + 4 + 1 + 5 = 32 — plus `api` already counted as SAFE-WITH-CAVEATS → 33 total. ✓

**MANUAL-REVIEW cases resolved**:
- `gh ruleset check` — DeepWiki on `cli/cli` confirmed `pkg/cmd/ruleset/check/check.go` issues a single GET via `api.Client` and prints to `opts.IO.Out`. No Post/Put/Patch/Delete, no disk writes. `--web` opens a browser (demoted by global `gh * --web*: ask`). → **SAFE**.
- `gh attestation trusted-root` — DeepWiki confirmed the command fetches TUF trusted-root JSON and prints to stdout. Writes disk only if user shell-redirects (`>`). `--verify-only` refreshes a local TUF metadata cache (treat as cache-equivalent per Phase 3 rubric). No mutating API calls. → **SAFE**.

**Unclassifiable / ambiguities**: none. One policy judgement noted: `gh attestation trusted-root --verify-only` touches a local TUF metadata cache. I classified it SAFE because (a) the cache is internal to gh's trust-root handling, (b) stdout output is the primary effect, and (c) the Phase 3 rubric treats `--cache` as SAFE-but-noted. If reviewers prefer stricter handling, a per-flag ask (`"gh attestation trusted-root*--verify-only*": "ask"`) could be added by the aggregator; no change needed to this classify file.

**Enumeration drift note**: the task hints mentioned `gh extension view` as SAFE. gh 2.89.0 does NOT expose `extension view` — the enumeration shows only `browse/create/exec/install/list/remove/search/upgrade`. `view` is therefore omitted from the allow set. If a future gh release adds it, re-run the walker and re-classify.
