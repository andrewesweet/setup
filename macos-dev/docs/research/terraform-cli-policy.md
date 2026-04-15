# Terraform CLI Safe-Allowlist Policy

**Target version**: Terraform 1.14.x (policy also compatible with 1.10–1.13 surface).
**Runtime**: `macos-dev/opencode/opencode.jsonc` — see the `Terraform` block.
**Validated by**: `macos-dev/scripts/gh-allowlist-simulator.py` (the general bash-rule test harness).

## Shape of the policy

Every `terraform` subcommand that reads configs, reads provider metadata, or reads state is allow-listed. Every subcommand that **writes** files (including fmt without `-check`), **downloads** providers or modules (`init`, `get`, `providers lock`, `providers mirror`), **mutates** state (`apply`, `destroy`, `refresh`, `import`, `taint`, `untaint`, `force-unlock`, `state mv|rm|push|replace-provider`, `workspace new|select|delete`), **provisions** real infrastructure (`test`), **blocks the session** (`console`), or **manages credentials** (`login`, `logout`) falls through to `*: ask`.

Each SAFE verb is expressed with two patterns:

- Standard form: `"terraform <verb>"` + `"terraform <verb> *"` — covers the bare invocation and all flag combinations.
- `-chdir` form: `"terraform -chdir=* <verb>*"` — covers Terraform's global `-chdir=<path>` flag for selecting a working directory.

The one exception is `terraform fmt -check*`, which is allowed only with the `-check` flag present. `terraform fmt` without `-check` rewrites files in place (including with `-diff` or `-recursive`) and therefore falls through to ask.

## Allow list

### Top-level

| Command | Rationale |
|---|---|
| `terraform version` / `terraform -version` | prints version to stdout |
| `terraform -help` / `terraform -help <subcommand>` | prints help text |
| `terraform fmt -check` + args | checks formatting; exits non-zero on drift; does not modify files |
| `terraform validate` | parses configuration and prints diagnostics |
| `terraform show` / `terraform show <plan-or-state-file>` / `terraform show -json` | prints current state, saved plan, or a state file |
| `terraform output` / `terraform output <name>` / `terraform output -json` / `terraform output -raw <name>` | prints declared outputs from state |
| `terraform graph` / `terraform graph -type=*` | emits DOT-format dependency graph to stdout |
| `terraform providers` (bare) | prints provider requirements tree for the current configuration |

### Subcommand groups

| Command | Rationale |
|---|---|
| `terraform providers schema` / `terraform providers schema -json` | prints schema for each provider (read-only) |
| `terraform state list` | lists resources in state |
| `terraform state show <addr>` | prints a single resource's state |
| `terraform state pull` | prints the raw remote state as JSON |
| `terraform workspace list` | lists backend-visible workspaces |
| `terraform workspace show` | prints the currently selected workspace |
| `terraform metadata functions` / `terraform metadata functions -json` | lists provider-declared functions |

### `-chdir` variants

Every allow pattern above also has a `"terraform -chdir=* <verb>*"` counterpart, so the common CI / multi-environment pattern `terraform -chdir=./environments/prod validate` is allowed without a prompt.

## Ask list (fall-through)

Nothing in this group gets an explicit rule; they rely on the top-level `"*": "ask"` default.

| Command | Why ask |
|---|---|
| `terraform init` | downloads providers; writes `.terraform/` and `.terraform.lock.hcl` |
| `terraform plan` | by default refreshes remote state (mutates backend) and writes the lock file if missing |
| `terraform apply` / `terraform destroy` | changes infrastructure |
| `terraform refresh` | updates state from real infrastructure |
| `terraform get` | downloads modules |
| `terraform import` | writes a new resource into state |
| `terraform taint` / `terraform untaint` | deprecated; mutates state |
| `terraform force-unlock` | clears a state lock |
| `terraform push` (deprecated) | uploads state to Terraform Cloud |
| `terraform fmt` (without `-check`) | rewrites files in place |
| `terraform state mv` / `terraform state rm` / `terraform state push` / `terraform state replace-provider` | mutates state |
| `terraform workspace new` / `terraform workspace select` / `terraform workspace delete` | mutates workspace selection or backend |
| `terraform providers lock` | writes `.terraform.lock.hcl` |
| `terraform providers mirror` | downloads provider binaries to a mirror directory |
| `terraform login` / `terraform logout` | manages credentials |
| `terraform console` | interactive REPL — blocks the session |
| `terraform test` | runs `.tftest.hcl` files and may provision real infrastructure |

## Re-run cadence

On Terraform version bumps, re-inspect `terraform -help` for newly-introduced top-level subcommands and `state|workspace|providers|metadata -help` for new sub-subcommands. Add to either the allow layer or verify they fall through correctly.

## Validation

`scripts/gh-allowlist-simulator.py` (the general bash-rule tester despite its name) exercises the Terraform rules with **61 new test cases** covering every SAFE verb (with and without `-chdir`), every mutating verb, both fmt forms (`-check` allowed, bare / `-diff` / `-recursive` without `-check` asked), every interactive / auth / installs-code verb, and every state / workspace / providers / metadata sub-subcommand. Must pass 100% before any change to the Terraform block lands. The gcloud simulator must continue to pass as a regression check.
