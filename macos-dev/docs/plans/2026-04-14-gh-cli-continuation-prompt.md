# Continuation prompt — gh CLI safe-allowlist implementation

Paste the block below into a fresh Claude Code session to execute the gh CLI allowlist plan autonomously.

---

Execute the plan at `macos-dev/docs/plans/2026-04-14-gh-cli-safe-allowlist.md` end-to-end.

**Starting state.** Current branch is `worktree-feat-opencode-safe-bash-allowlist` in worktree `/home/sweeand/andrewesweet/setup/.claude/worktrees/feat-opencode-safe-bash-allowlist` — start there. It already contains: (a) an expanded `macos-dev/opencode/opencode.jsonc` with 320 bash rules (curl and `gh api` GET-only policy landed, last-match-wins-aware); (b) the plan doc; (c) the previously-ported Python matcher simulator was used inline last session — reconstruct it from scratch using `Wildcard.match` semantics in `packages/opencode/src/util/wildcard.ts` upstream. All three files are uncommitted. Commit them first on this branch before spawning subagents so the subagents see a stable base. Do not push.

**Pre-decided answers to the plan's open questions** — do not stop to ask me:

1. Local-write verbs (`gh repo clone`, `gh pr checkout`, `gh release download`): **ask** by default. Do not scope to workspace — consistent with the curl file-write policy already in this config.
2. `gh auth token`: **ask**. Token exposure risk outweighs debugging convenience.
3. Extensions: explicit **deny** for `gh extension install|remove|upgrade|exec|create`. Only `gh extension list|view|browse|search` allowed.
4. Re-run cadence: ship `scripts/gh-allowlist-audit.sh` so it can be re-run on gh version bumps. Do not add CI wiring in this pass — flag it as a follow-up.
5. Scope: gh only. No gh-dash, no ad-hoc extension scoping.

**Ground truth about the matcher** (don't re-derive):

- `Wildcard.match` compiles pattern to regex with `*` → `.*` under the `s` flag. Trailing ` *` becomes optional `( .*)?`. `*` is **greedy across whitespace** — `"gh *"` matches `gh pr create --title foo`.
- `evaluate` uses `findLast` over the rule array in config key-order. **Last matching rule wins.** Not specificity.
- Consequence for policy shape: broad category allows MUST be followed by narrower `ask`/`deny` overrides. Scoped allow exceptions to a deny MUST come AFTER the deny they scope.
- Full documentation of this is in `macos-dev/docs/design/opencode.md` under "Rule Evaluation Semantics" — read it before writing any new patterns.

## Execution — 3 logical phases, with parallel subagents in the middle

### Phase 1 — Enumerate (sequential, this session)

1. Check gh version: `gh --version`. Record it in the enumeration artifact.
2. Write `macos-dev/scripts/gh-allowlist-audit.sh` that walks `gh help` recursively — starting at root, extracting subcommand names from the "COMMANDS" / "CORE COMMANDS" / "ADDITIONAL COMMANDS" sections, recursing into each, capturing for every leaf: `{path, short, flags, examples}`. Emit `macos-dev/docs/research/gh-cli-commands.json`.
3. Run the script. Sanity check: leaf count should be O(200-400). If much less, the walker missed a section format — fix and re-run.
4. Commit on the feat branch: "feat(opencode): enumerate gh CLI command surface for allowlist audit". DO NOT push.

### Phase 2 — Classify in parallel (5 subagents, each in its own worktree)

Dispatch all five in a single message with multiple `Agent` tool-use blocks. Use `subagent_type: "general-purpose"` with `isolation: "worktree"` so each gets an isolated copy of the repo.

Family partitioning (per the plan):
- **Agent A**: auth, config, status, cache
- **Agent B**: repo, pr, issue
- **Agent C**: workflow, run, release, label
- **Agent D**: gist, search, browse, copilot, codespace
- **Agent E**: secret, variable, environment, ruleset, alias, extension, attestation

Each agent's prompt (template, substitute `<letter>` and `<families>`):

> You are classifying gh CLI families **<families>** for inclusion in an OpenCode safe-bash allowlist.
>
> **Read first** (all in the worktree you start in):
> - `macos-dev/docs/plans/2026-04-14-gh-cli-safe-allowlist.md` — overall plan and verb rubric.
> - `macos-dev/docs/design/opencode.md` section "Rule Evaluation Semantics" — matcher behavior. Understand that `*` is greedy across whitespace and `findLast` wins; your patterns must reflect this.
> - `macos-dev/docs/research/gh-cli-commands.json` — enumeration artifact. Filter to your families only.
>
> **Pre-decided policy** (do not re-litigate):
> - Local-write verbs (`clone`, `checkout`, `release download`): ask — no workspace scoping.
> - `gh auth token`: ask.
> - Extension install/remove/upgrade/exec/create: deny.
> - Global side-effect flag demotion via `"gh * --web*": "ask"` etc. — you do NOT emit these; the aggregator does. Just note per-command which flags are problematic.
>
> **Task**, for each leaf command in your families:
>
> 1. Classify against the rubric (SAFE / MUTATING / WRITES-LOCAL / AUTH / INTERACTIVE / INSTALLS-CODE / MANUAL-REVIEW).
> 2. For SAFE commands, list every flag that introduces a side effect (`--web` opens browser, `--edit` opens editor, `--output`/`--dir` writes file, `--clobber` overwrites, anything launching a long-running stream).
> 3. For MANUAL-REVIEW cases, cross-check against `github.com/cli/cli` at `pkg/cmd/<family>/<verb>/`. Use `gh api repos/cli/cli/contents/pkg/cmd/<family>/<verb>` or `mcp__claude_ai_DeepWiki__ask_question` on `cli/cli`. Look for `api.Post|Put|Patch|Delete`, `os.Create`, `ioutil.WriteFile`, browser-open helpers (`browser.New`, `OpenURL`). Absence on the happy path ⇒ SAFE.
> 4. Emit `macos-dev/docs/research/gh-classify-<letter>.md` using this row format:
>    ```
>    | Command | Class | Side-effect flags | Proposed pattern(s) | Justification |
>    ```
>    One row per leaf command. Group by family. For MUTATING/WRITES-LOCAL/AUTH/INTERACTIVE commands, proposed-pattern column is empty (falls through to `*: ask`). For denied extension verbs, column shows the deny pattern.
>
> **Constraints**:
> - Do NOT edit `opencode.jsonc` or `docs/design/opencode.md`. Aggregation happens later.
> - Do NOT commit. Leave the classify file uncommitted in your worktree.
> - Do NOT run the matcher simulator. That's a Phase 3 job.
>
> **Return**: <200-word report with leaf count, per-class counts, list of MANUAL-REVIEW commands resolved (with how you resolved each), list of any commands you could not classify confidently (with the ambiguity).

When all five return, copy their `gh-classify-<letter>.md` files from their worktrees back into the main feat worktree at `macos-dev/docs/research/`. If an agent's classifications look wrong (hallucinated verbs not in the JSON; class mismatches obvious category), re-spawn that family — do not silently accept garbage.

### Phase 3 — Aggregate, validate, integrate (sequential, main feat worktree)

1. **Merge** the five `gh-classify-<letter>.md` files into `macos-dev/docs/research/gh-cli-command-matrix.md`, sorted by family then verb, retaining columns: command, class, side-effect flags, proposed pattern(s), justification.
2. **Derive the final `gh` block** for `opencode.jsonc`:
   - Per-family grouped allows for SAFE verbs.
   - Global side-effect flag asks AFTER the allows:
     ```jsonc
     "gh * --web*": "ask",
     "gh * --edit*": "ask",
     "gh * --output *": "ask",
     "gh * --clobber*": "ask"
     ```
   - Explicit extension denies:
     ```jsonc
     "gh extension install*": "deny",
     "gh extension remove*": "deny",
     "gh extension upgrade*": "deny",
     "gh extension exec*": "deny",
     "gh extension create*": "deny"
     ```
3. **Replace** the existing narrow gh block in `macos-dev/opencode/opencode.jsonc`. Do NOT touch the `gh api` block — it's already correct and order-sensitive.
4. **Validate** with the Python matcher simulator (reconstruct from `Wildcard.match` + `findLast` semantics). Write 60+ test cases covering every bucket and every global flag override. Require 100% pass. If it fails, diagnose rule order — do NOT mask failures with ad-hoc exceptions.
5. **Update** `macos-dev/docs/design/opencode.md`:
   - Replace the "GitHub CLI read verbs" bullet under "Bash Allowlist Policy" with a one-paragraph summary plus a link to `docs/research/gh-cli-command-matrix.md`.
   - Add a new "gh Allowlist Policy" section describing the per-family structure, global flag demotions, and extension denies.
6. **Commit** on the feat branch with message `feat(opencode): enumerate gh CLI safe-allowlist from full command surface`. DO NOT push.
7. **Clean up** subagent worktrees (`git worktree remove`) once their classifications are merged.

## Report format when done

Terse summary, under 300 words:

- gh version enumerated, total leaf commands.
- Per-class counts (SAFE / MUTATING / WRITES-LOCAL / AUTH / INTERACTIVE / INSTALLS-CODE / MANUAL-REVIEW resolved).
- Final gh rule count in opencode.jsonc (before → after).
- Matcher simulator pass rate.
- Diffstat for the commit.
- Any commands left as MANUAL-REVIEW that you could not resolve (with why).
- Any items flagged for follow-up (CI wiring, gh-dash, extension scoping).

## Guardrails

- Worktrees: every subagent gets isolation. You work in the main feat worktree only. Never `cd` to the repo root.
- Never commit on `main`. All commits on `worktree-feat-opencode-safe-bash-allowlist` or subagent branches.
- Never push. I review and push.
- The matcher simulator must pass 100% before integrating. Ordering bugs are fixable by moving rules, not by adding new ones.
- If a subagent's classification disagrees with the gh source code, trust the source.
- Don't invent new policy. If a case genuinely doesn't fit the pre-decided answers, pause and surface it in your final report rather than guessing.

---

(End of continuation prompt.)
