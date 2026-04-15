# OpenCode and critique

## Overview

This document specifies the configuration and permissions for OpenCode, an AI-powered development assistant for dotfiles management. The configuration MUST enforce security boundaries while enabling productive workflows for code editing, git operations, and temporary file handling.

## Provider and Models

The system MUST use GitHub Copilot as the exclusive provider. The primary model MUST be `github-copilot/claude-sonnet-4-6`. The small model MUST be `github-copilot/gpt-4o-mini`.

## Instructions

The AI assistant MUST load the following instruction files in order:

1. `~/.config/opencode/instructions/git-conventions.md`
2. `~/.config/opencode/instructions/scratch-dirs.md`

These files MUST be consulted for all operations affecting git repositories and temporary file creation.

## opencode.jsonc Configuration

The configuration file MUST conform to the OpenCode schema at `https://opencode.ai/config.json`. The authoritative configuration lives at `macos-dev/opencode/opencode.jsonc`. The skeleton below defines the required top-level shape; the full `bash` allowlist is enumerated in the runtime file and summarized by category in the [Bash Allowlist Policy](#bash-allowlist-policy) section.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "github-copilot/claude-sonnet-4-6",
  "small_model": "github-copilot/gpt-4o-mini",
  "instructions": [
    "~/.config/opencode/instructions/git-conventions.md",
    "~/.config/opencode/instructions/scratch-dirs.md"
  ],
  "permission": {
    "*": "ask",
    "read": {
      "*": "ask",
      "~/workspace/**": "allow",
      "/home/dev/workspace/**": "allow",
      "/tmp/**": "allow",
      "~/.config/opencode/**": "allow",
      "~/.config/mise/**": "allow"
    },
    "grep": "allow",
    "glob": "allow",
    "list": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "bash": {
      "*": "ask",
      // ... see opencode.jsonc for the full allowlist; policy below.
      "rm -rf /tmp/opencode-*": "allow",
      "rm -rf *": "deny", "rm -fr *": "deny",
      "sudo *": "deny", "chmod 777 *": "deny"
    },
    "edit": {
      "*": "ask",
      "~/workspace/**": "allow",
      "/home/dev/workspace/**": "allow",
      "/tmp/**": "allow"
    },
    "webfetch": "ask",
    "websearch": "ask",
    "external_directory": {
      "*": "ask",
      "/tmp/**": "allow"
    },
    "doom_loop": "ask"
  },
  "share": "disabled",
  "autoupdate": false // Pin version for supply-chain security. Update deliberately.
}
```

### Permission Scoping Requirements

The `read` permission MUST be restricted to workspace directories, the `/tmp` directory, and specific configuration paths. Broad read access MUST NOT be granted.

The `cat` bash command MUST be scoped exclusively to workspace and `/tmp/*` paths. The permission entry `"cat *": "allow"` MUST NOT be applied. The same scoping MUST apply to `bat`, `glow`, and `delta`.

The `edit` permission MUST be scoped to workspace directories and the `/tmp` directory. Editing arbitrary files MUST require explicit user confirmation.

Destructive commands `rm -rf` and `rm -fr` MUST be denied unconditionally, with the single scoped exception `rm -rf /tmp/opencode-*` for scratch cleanup (see [Rule Evaluation Semantics](#rule-evaluation-semantics) for how the exception is made to win over the broader deny). Privileged operations with `sudo` and insecure permission changes with `chmod 777` MUST be denied unconditionally.

### Rule Evaluation Semantics

OpenCode resolves a matching rule via `rules.findLast(rule => wildcardMatch(command, rule.pattern))` — **the LAST matching rule in the config wins, in config key-order**. This is not specificity-based. The `Wildcard.match` implementation (see `packages/opencode/src/util/wildcard.ts` upstream) compiles the pattern to a regex with `*` → `.*` under the `s` flag, with a special case that makes a trailing ` *` optional (so `"curl *"` matches both `curl` and `curl https://x`). `*` is greedy across whitespace — `"curl *"` matches `curl -X POST https://x` too.

Two consequences drive the policy shape:

1. **Broad allows MUST be followed by narrower `ask`/`deny` rules to restrict them.** A later rule overrides an earlier rule when both match.
2. **Scoped exceptions to a deny MUST be placed AFTER that deny.** For example, `"rm -rf *": "deny"` appears before `"rm -rf /tmp/opencode-*": "allow"`, so `findLast` returns the allow for `/tmp/opencode-*` paths and the deny for everything else.

The opencode.jsonc runtime file MUST be organized so that:
- The `"*": "ask"` default comes first.
- Broad category allows come next.
- Narrower `ask` overrides for mutating flags follow the broad allows they restrict.
- Re-allow rules (for explicitly-safe forms like `-X GET`) come AFTER the mutation-flag asks.
- Unconditional denies come last, EXCEPT scoped allow exceptions to a deny, which come after their corresponding deny.

### Bash Allowlist Policy

The bash allowlist MUST follow a read-only, inspect-only philosophy. A command pattern MAY be allowed only if all of the following hold under its allowed invocations:

1. It does not write, rename, delete, or move files on disk.
2. It does not launch a long-running or interactive TUI that would block an AI session.
3. It does not initiate a network request that carries a body (POST/PUT/PATCH/DELETE) or uploads a file.
4. It does not escalate privileges.
5. Flags that would flip the command into a mutating mode are excluded by the pattern or demoted to `ask`/`deny` by a later rule per [Rule Evaluation Semantics](#rule-evaluation-semantics).

Patterns MUST be grouped by category in the runtime file. The required categories are:

- **Git read-only verbs** — status/diff/log/show/branch/stash list/blame/reflog/remote/config get/tag/describe/rev-parse/ls-files/ls-tree/for-each-ref/shortlog/cat-file/grep/worktree list/whatchanged/name-rev/merge-base/count-objects.
- **GitHub CLI read verbs** — enumerated from the full `gh` command surface (see [gh Allowlist Policy](#gh-allowlist-policy) below) and catalogued with class, flags, and justification in [`docs/research/gh-cli-command-matrix.md`](../research/gh-cli-command-matrix.md). The runtime allow set is derived from the matrix and MUST be regenerated when `gh` is bumped in `Brewfile`.
- **Filesystem inspection (stdlib)** — `ls`, `pwd`, `which`, `type`, `command -v`, `whereis`, `apropos`, `file`, `stat`, `readlink`, `realpath`, `basename`, `dirname`, `wc`, `head`, `tail` (excluding `-f`/`-F`), `du`, `df`, `tree`, `eza`.
- **Hashing / diff** — `diff`, `cmp`, `md5sum`, `sha1sum`, `sha256sum`, `sha512sum`, `shasum`, `hexdump`, `xxd`, `od`, `strings`.
- **Text-transform pipes** — `sort`, `uniq`, `cut`, `tr`, `tac`, `rev`, `nl`, `column`, `paste`, `join`, `comm`, `fold`, `fmt`, `expand`, `unexpand`. `sed`, `awk`, `tee`, and scripting interpreters MUST NOT be blanket-allowed.
- **Search** — `rg`, `fd`.
- **Data wrangling** — `jq`, `yq`, `mlr` (`miller`).
- **Scoped viewers** — `bat`, `cat`, `glow`, `delta`, `difft` restricted to workspace and `/tmp`.
- **Environment/system info** — `env`, `printenv`, `uname`, `hostname`, `whoami`, `id`, `groups`, `uptime`, `locale`, `date`.
- **Version/help probes** — `* --version`, `* -V`, `* --help`, `* -h`.
- **Package inventory (list-only)** — `brew list`, `brew info`, `brew outdated`, `brew doctor`, `npm list`, `pnpm list`, `yarn list`, `bun pm ls`, `pip list/show/freeze`, `uv pip list`, `uv tree`, `cargo tree`, `cargo metadata`, `go list`, `go env`, `go version`, `bundle list`, `gem list`, `dpkg -l`, `apt list --installed`, `mise list|current|env|doctor|which`.
- **Linters / analyzers (non-mutating only)** — `shellcheck`, `shfmt -d|-l` (NOT `-w`), `actionlint`, `zizmor`, `pinact run --check`, `markdownlint-cli2 *.md` (NOT `--fix`), `tflint`, `golangci-lint run|config`, `gofmt -l|-d` (NOT `-w`), `goimports -l|-d` (NOT `-w`).
- **Containers (read verbs)** — `podman|docker ps|images|inspect|logs|version|info`.
- **Kubernetes (read verbs)** — `kubectl get|describe|logs|explain|api-resources|api-versions|cluster-info`, `kubectl config view|get-contexts|current-context`, `kubectx`, `kubens`.
- **Google Cloud CLI** — enumerated from the full `gcloud` command surface (see [gcloud Allowlist Policy](#gcloud-allowlist-policy) below) and catalogued in [`docs/research/gcloud-cli-policy.md`](../research/gcloud-cli-policy.md). Uses verb-pattern rules rather than per-leaf enumeration; the runtime allow set is derived from the policy doc and MUST be regenerated when the Cloud SDK is bumped.
- **Cocogitto / changelog (read-only)** — `cog verify|check|log`, `git-cliff --context` (NOT `--output`).
- **Terraform** — every side-effect-free subcommand for Terraform 1.14.x is allow-listed: `version`/`-version`/`-help`, `fmt -check`, `validate`, `show`, `output`, `graph`, `providers` (bare + `providers schema`), `state list|show|pull`, `workspace list|show`, `metadata functions`. Each has a `terraform -chdir=<path>` variant. Mutating verbs (`init|plan|apply|destroy|refresh|get|import|taint|untaint|force-unlock|push|fmt` without `-check`, `state mv|rm|push|replace-provider`, `workspace new|select|delete`, `providers lock|mirror`), interactive verbs (`console`), credential-managing verbs (`login|logout`), and verbs that may provision real infrastructure (`test`) fall through to `*: ask`. Classification in [`docs/research/terraform-cli-policy.md`](../research/terraform-cli-policy.md). Adjacent tools: `tf-summarize`, `tenv list`.
- **Archives (list only)** — `tar -tvf|--list`, `unzip -l|-v`, `7z l`, `zipinfo`.
- **History/session/misc** — `atuin search|stats|status`, `zoxide query`, `ghq list`, `direnv status|version`, `starship --print-config|config|module`, `tmux list-sessions|list-windows|list-panes|show-options|display-message -p`.
- **Network (passive only)** — `dig`, `host`, `nslookup`, `ping -c`, `traceroute`, `tracepath`.

### curl and gh api — GET-Only Policy

The `curl` command MUST be allowed for implicit-GET invocations and for explicit GET (`curl -X GET`, `curl -XGET`, `curl --request GET`). Because OpenCode's matcher is greedy across whitespace and resolves rules by last-match-wins ([see semantics](#rule-evaluation-semantics)), the broad `"curl *": "allow"` entry MUST be followed by explicit `ask` overrides for every flag that selects or implies a non-GET method:

- **Explicit method flags** — `-X *`, `--request *`, `-XPOST`, `-XPUT`, `-XDELETE`, `-XPATCH` (the last four cover curl's no-space short-option form).
- **Body flags that silently flip the default method to POST** — `-d`, `--data*` (urlencode, raw, binary), `-F`, `--form`.
- **Upload flags that silently flip the default method to PUT** — `-T`, `--upload-file`.

After those asks, explicit GET forms MUST be re-allowed (`curl -X GET*`, `curl --request GET*`, `curl *-XGET*`) so that the re-allow wins over the generic `-X *: ask`.

The `gh api` command MUST follow the same three-layer structure (broad allow → method/body asks → GET re-allow). The body-flag set differs from curl's: `gh api` flips the default method to POST whenever `-f`, `--raw-field`, `-F`, `--field`, or `--input` is present (per `gh api --help`), so those flags MUST be demoted to `ask` even without an explicit `-X`. The no-space method forms (`-XPOST`, `-XPUT`, `-XDELETE`, `-XPATCH`) MUST also be explicitly handled.

A per-endpoint POST allowlist will be defined in a follow-up and MUST NOT be introduced via broad patterns.

Other network writers — `wget`, `xh`, `httpie`, `http` — MUST NOT be added to the allowlist.

### gh Allowlist Policy

Beyond the `gh api` GET-only block described above, every other `gh` verb MUST be classified against a rubric (SAFE / MUTATING / WRITES-LOCAL / AUTH / INTERACTIVE / INSTALLS-CODE) before it can appear in an allow pattern. The authoritative enumeration and classification live in [`docs/research/gh-cli-command-matrix.md`](../research/gh-cli-command-matrix.md); the enumeration is re-generated by `scripts/gh-allowlist-audit.sh` against the locally-installed `gh`.

The runtime policy in `opencode.jsonc` MUST be structured as four layers, placed in this order (last-match-wins, per [Rule Evaluation Semantics](#rule-evaluation-semantics)):

1. **Per-family SAFE allows** — one `"gh <family> <verb>"` + `"gh <family> <verb> *"` pair for every SAFE leaf in the matrix, grouped by family with comment headers. Whole-family `"gh <family> *": "allow"` MUST NOT be used because every family mixes SAFE and ask-class verbs; a broad family allow would admit mutations.
2. **Global side-effect flag demotions** — emitted AFTER the allows so they override any SAFE allow that would otherwise accept a side-effecting flag. At minimum: `"gh * --web*": "ask"`, `"gh * -w *": "ask"`, `"gh * -w": "ask"`, `"gh * --edit*": "ask"`, `"gh * --output*": "ask"`, `"gh * --dir *": "ask"`, `"gh * --dir=*": "ask"`, `"gh * --clobber*": "ask"`, `"gh * --watch*": "ask"`, `"gh * --follow*": "ask"`. These cover browser (`--web`/`-w`), editor (`--edit`/`--editor`), local writes (`--output`/`--dir`/`--clobber`), and long-running streams (`--watch`/`--follow`).
3. **Per-command credential demotions** — any SAFE verb that exposes a credential via a flag MUST have its own `ask` override emitted after its allow. Specifically, `gh auth status --show-token` / `-t` prints the authentication token; `"gh auth status --show-token*": "ask"`, `"gh auth status -t*": "ask"`, `"gh auth status * --show-token*": "ask"`, `"gh auth status * -t*": "ask"` MUST be present.
4. **Explicit extension asks** — `gh extension install|remove|upgrade|exec|create` invoke arbitrary third-party binaries or scaffold executable code on disk and MUST be demoted to ask with `"gh extension install*": "ask"`, `"gh extension remove*": "ask"`, `"gh extension upgrade*": "ask"`, `"gh extension exec*": "ask"`, `"gh extension create*": "ask"`. These asks MUST be placed at the **absolute end of the bash rules block**, after even the `rm -rf` scoped allow, so the asks win over every prior rule — including `* --help` and `* --version` — preventing bypass via help/version suffixes. (Promoting from `deny` to `ask` lets the user approve individual extension operations when intentional, rather than requiring a config edit.)

User-defined aliases (`gh <user-alias>`) expand to arbitrary commands and MUST NOT be enumerated in the allow set; they correctly fall through to the top-level `"*": "ask"` default.

`scripts/gh-allowlist-simulator.py` ports `Wildcard.match` + `findLast` and MUST pass 100% of its test cases against `opencode.jsonc` before any change to the `gh` block lands.

### gcloud Allowlist Policy

The `gcloud` CLI surface is two orders of magnitude larger than `gh` (18,728 commands vs 183 on the current pinned versions) and therefore uses **verb-pattern rules** rather than per-leaf enumeration. The classification follows a rubric:

- **admin/metadata read = allow** and **data read = allow**
- **admin/metadata write = ask** and **data write = ask**
- **Credential / token retrieval = ask (MUST)** — this includes anything that returns a bearer token, private key, wrapped-secret plaintext, signature, or MAC
- **Interactive / session-blocking = ask** — ssh/scp/tunnels/shells/waits/tails/streams
- **`gcloud alpha` and `gcloud beta` = blanket ask**

The authoritative policy doc, classification matrix, and audit reports live in [`docs/research/gcloud-cli-policy.md`](../research/gcloud-cli-policy.md) (+ supporting [`gcloud-audit-data-plane.md`](../research/gcloud-audit-data-plane.md), [`gcloud-audit-interactive-credential-installs.md`](../research/gcloud-audit-interactive-credential-installs.md)). The enumeration is re-generated by `scripts/gcloud-allowlist-audit.sh` (which wraps `gcloud meta list-commands`) against the locally-installed Cloud SDK.

The runtime policy in `opencode.jsonc` MUST be structured as nine layers, placed in this order (last-match-wins, per [Rule Evaluation Semantics](#rule-evaluation-semantics)):

1. **Universal SAFE verb allows** — one `"gcloud * <verb>"` + `"gcloud * <verb> *"` pair per verb that is universally safe across every service: `list`, `describe`, `get-iam-policy`, `get-ancestors-iam-policy`, `test-iam-permissions`, `get-value`, `get-public-key`, `search`, `lookup`, `explain`, `print-settings`. Because OpenCode's matcher is greedy across whitespace, a single pattern matches every service and every resource depth.
2. **Singleton utility allows** — `gcloud info`, `gcloud version`, `gcloud --version`, `gcloud help`, `gcloud topic`, `gcloud cheat-sheet`, `gcloud auth list`, `gcloud config list`, `gcloud config configurations list|describe`.
3. **Data-read allows** (verbs not in the universal SAFE set): `gcloud storage ls|cat|du|hash*`, `gcloud logging read*`, `gcloud pubsub subscriptions pull*` (without `--auto-ack`; the with-`--auto-ack` form is demoted in tier 4), `gcloud pubsub message-transforms test*`, `gcloud pubsub schemas validate-message*`, `gcloud kms encrypt|raw-encrypt|asymmetric-encrypt|asymmetric-verify|mac-verify*`, `gcloud ai endpoints predict|raw-predict|direct-predict|direct-raw-predict|explain*`, `gcloud ai-platform predict|local predict*`, `gcloud ml * *`, `gcloud model-armor templates sanitize-*`, `gcloud vector-search collections data-objects query|batch-search|aggregate*`, `gcloud healthcare consent-stores check-data-access|query-accessible-data|evaluate-user-consents*`, `gcloud functions logs read*`, `gcloud app logs read*`, `gcloud run services logs read*`, `gcloud run jobs logs read*`, `gcloud compute instances get-serial-port-output|get-screenshot*`, `gcloud compute routers download-route-policy*`, `gcloud asset query|get-history*`, `gcloud policy-intelligence query-activity*`, `gcloud metastore services query-metadata*`, `gcloud netapp kms-configs encrypt|verify*`.
4. **Data-write asks** — override tier 1–3 where a read-like verb would otherwise admit a write: `storage cp|mv|rm|rsync|restore|objects create|update|compose|delete|batch-operations *|managed-folders create|update|delete|folders create|delete`, `logging write|copy`, `pubsub subscriptions ack|topics publish|lite-topics publish|lite-subscriptions ack-up-to` + the `pubsub subscriptions pull* --auto-ack*` demotion, `kms keys versions import`, arbitrary-SQL executors (`spanner databases execute-sql|sessions execute-sql`, `sql instances execute-sql`, `spanner cli`), `spanner rows *`, `sql export|import|instances export|instances import`, `alloydb clusters export|import`, `firestore export|import|bulk-delete`, `datastore export|import`, `bigtable backups copy|tables restore|instances tables restore`, `ai endpoints stream-*` (interactive), `ai-platform jobs submit prediction`, `vector-search collections data-objects create|update|delete|batch-create|batch-update|batch-delete|export-data-objects|import-data-objects`, all `healthcare * export|import|deidentify`, `functions call`, `compute images export|import|machine-images import|instances export|import|diagnose export-logs|routers upload-route-policy`, `composer/transfer/backup-dr/redis/looker/memorystore/lustre/metastore/netapp volumes/scc/infra-manager/artifacts` writes.
5. **Interactive / session-blocking asks** — `init`, `docker`, `feedback`, `survey`, `* operations wait*`, `* wait`, `* stream-logs*`, per-service `ssh`/`scp`/`start-iap-tunnel`/`connect-to-serial-port`/`config-ssh`/`copy-files`/`reset-windows-password`/`instances tail-serial-port-output`, `compute tpus * ssh|scp`, `cloud-shell ssh|scp|get-mount-command`, `sql connect`, `app open-console|instances ssh|instances scp|logs tail`, `workstations ssh|start-tcp-tunnel`, `dataproc batches|jobs wait`, `workflows executions wait|wait-last`, `emulators * start*`, `ai endpoints stream-*`.
6. **Credential / token retrieval asks** — **MUST** include: `gcloud auth (login|logout|revoke|activate-service-account|print-access-token|print-identity-token|application-default *|configure-docker|enterprise-certificate-config *)*`, `anthos auth login|create-login-config`, the universal `gcloud * get-credentials*`, `gcloud iam service-accounts keys create|upload|sign-blob|sign-jwt`, `gcloud iam workforce-pools create-login-config|providers keys create`, `gcloud iam workload-identity-pools providers keys create`, `gcloud compute|storage sign-url`, **`gcloud kms decrypt|raw-decrypt|asymmetric-decrypt|decapsulate|asymmetric-sign|mac-sign`** (decrypted plaintext is typically wrapped credential; signatures and MACs ARE credentials), **`gcloud secrets versions access*`** (returns the secret payload), `gcloud redis instances get-auth-string*`, `gcloud sql generate-login-token*`, `gcloud developer-connect connections git-repository-links fetch-read-token|fetch-read-write-token`, `gcloud iap oauth-clients reset-secret*`, `gcloud services api-keys get-key-string*`. Plus **defensive wildcards** that catch future credential-retrieval verbs: `gcloud * fetch-read-token*`, `gcloud * fetch-read-write-token*`, `gcloud * get-auth-string*`, `gcloud * generate-login-token*`, `gcloud * get-key-string*`. These never match a universal SAFE verb, so they do not over-ask metadata reads.
7. **Components (installs-code) asks** — `gcloud components (install|update|remove|reinstall)*`, `gcloud components repositories *`.
8. **Per-service demotion for credential-adjacent SAFE verbs** — `"gcloud artifacts print-settings*": "ask"` MUST demote the universal `print-settings` allow for this specific service because `--json-key=<path>` can embed SA key material into the printed snippet.
9. **Alpha / beta blanket ask** — `"gcloud alpha"`, `"gcloud alpha *"`, `"gcloud beta"`, `"gcloud beta *"`. Placed **last** in the gcloud section so these asks win over every prior allow.

Metadata-admin writes (`create`, `delete`, `update`, `patch`, `set-*`, `add-*`, `remove-*`, `enable`, `disable`, `cancel`, `start`, `stop`, `resume`, `restore`, `rollback`, `revoke`, `reset`, `move`, `rename`, `attach`, `detach`, `bind`, `unbind`, `link`, `unlink`, `connect`, `disconnect`, `migrate`, `run`, `submit`, `deploy`) MUST NOT appear in any universal SAFE allow. They fall through to the top-level `"*": "ask"` default automatically; no explicit ask rule is required.

`scripts/gcloud-allowlist-simulator.py` ports `Wildcard.match` + `findLast` and MUST pass 100% of its test cases against `opencode.jsonc` before any change to the `gcloud` block lands. The gh simulator (`scripts/gh-allowlist-simulator.py`) MUST also continue to pass after any change, as a regression check.

### Deliberately Excluded

The following MUST NOT appear in any allow pattern, either bare or wildcarded:

- Shell interpreters that bypass the allowlist: `bash -c`, `sh -c`, `zsh -c`, `python`, `python3`, `node`, `ruby`, `perl`.
- `find` (its `-exec`, `-delete`, and `-fprint*` make it mutation-capable); use `fd` instead.
- Long-running TUIs that would block a session: `lazygit`, `lazydocker`, `k9s`, `btop`, `htop`, `yazi`, `sesh` (interactive), `television`, `nvim`, bare `fzf`, bare `less`/`more`.
- Writing network utilities: `curl` body methods (see above), `wget`, `xh`, `httpie`, `http`.
- Package install/build verbs: `brew install`, `npm install`, `pip install`, `uv add`, `cargo build`, `go build`, `go generate`, `make`, `just`, `bun install`.
- Mutating Kubernetes/container verbs: `kubectl apply|create|delete|edit|patch|scale|rollout`, `docker|podman run|exec|rm|pull|push|build`.

## tui.jsonc Configuration

The terminal user interface configuration file MUST conform to the OpenCode TUI schema at `https://opencode.ai/tui.json`. The following keybinding configuration MUST be applied:

```jsonc
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
    "leader": "ctrl+x",
    "session_new": "<leader>n",
    "session_list": "<leader>l",
    "session_timeline": "<leader>g",
    "session_compact": "<leader>c",
    "session_interrupt": "escape",
    "session_export": "<leader>x",
    "session_share": "<leader>S",
    "session_fork": "none",
    "session_rename": "none",
    "messages_half_page_up": "ctrl+alt+u",
    "messages_half_page_down": "ctrl+alt+d",
    "messages_page_up": "pageup,ctrl+alt+b",
    "messages_page_down": "pagedown,ctrl+alt+f",
    "messages_first": "ctrl+g,home",
    "messages_last": "ctrl+alt+g,end",
    "messages_copy": "<leader>y",
    "messages_undo": "<leader>u",
    "sidebar_toggle": "<leader>b",
    "model_list": "<leader>m",
    "agent_list": "<leader>a",
    "theme_list": "<leader>t",
    "editor_open": "<leader>e",
    "status_view": "<leader>s",
    "agent_cycle": "tab",
    "agent_cycle_reverse": "shift+tab",
    "command_list": "ctrl+p",
    "scrollbar_toggle": "none",
    "username_toggle": "none",
    "tool_details": "none",
    "session_child_first": "<leader>down",
    "session_child_cycle": "right",
    "session_child_cycle_reverse": "left",
    "session_parent": "up",
    "display_thinking": "none"
  }
}
```

### Keybinding Collision Avoidance

The `messages_half_page_up` action MUST be bound to `ctrl+alt+u` (not bare `ctrl+u`) to prevent collision with emacs Ctrl+U behavior in the input area.

The `messages_half_page_down` action MUST be bound to `ctrl+alt+d` (not bare `ctrl+d`) to prevent collision with emacs Ctrl+D behavior in the input area.

## Instruction Files

### git-conventions.md

The file MUST be located at `~/.config/opencode/instructions/git-conventions.md` and MUST contain the following content:

```markdown
# Git conventions
- Commit messages follow Conventional Commits: `type(scope): description`
- Valid types: feat, fix, docs, style, refactor, perf, test, chore, ci
- Breaking changes: append `!` after type or add `BREAKING CHANGE:` footer
- Subject line: imperative mood, under 72 characters
- Changelog generated by git-cliff. Do not hand-edit CHANGELOG.md.
- Version bumps managed by cocogitto (`cog bump --auto`).
- Before proposing a commit, verify with: `cog verify "<message>"`
```

### scratch-dirs.md

The file MUST be located at `~/.config/opencode/instructions/scratch-dirs.md` and MUST contain the following content:

```markdown
# Scratch and temporary files
When you need temporary files, use /tmp rather than $TMPDIR.
/tmp is stable on macOS and explicitly permitted by permissions.
Use prefix: /tmp/opencode-<short-description>
Clean up after task completion: rm -rf /tmp/opencode-*
```

## Critique Functions

Critique functions `cr`, `crw`, and `crs` MUST be defined in `.bash_aliases`. These functions enable code review operations and MUST follow the specifications in `shell.md`.

## Known Keybinding Limitations

The following keybinding collisions are known and have documented workarounds:

- **Tmux context**: When running OpenCode inside a tmux session, the tmux prefix `Ctrl+A` intercepts the start-of-line command. The workaround is to send `Ctrl+A Ctrl+A` to produce a literal start-of-line action.

- **VS Code context**: When running in a VS Code integrated terminal, `Ctrl+P` (VS Code Quick Open) intercepts the command palette binding. Additionally, `Ctrl+K` (VS Code chord) intercepts delete-to-end behavior.

## Installation and Runtime

The Brewfile MUST include the following entry:

```ruby
brew "bun"    # runtime for OpenCode and critique
```

OpenCode and critique MUST be installed via the bun package manager:

```bash
bun install -g opencode-ai critique
```

The PATH environment variable MUST include `~/.bun/bin` to ensure the installed binaries are discoverable.

## Configuration Auto-Updates

The `autoupdate` field MUST be set to `false` to pin versions for supply-chain security. Updates SHOULD be applied deliberately after review.

## Session Sharing

The `share` field MUST be set to `"disabled"`. Session data MUST NOT be shared externally, even with explicit user action, under this configuration. If sharing is ever enabled, it MUST be a deliberate configuration change reviewed alongside any tooling that would ingest the shared content.
