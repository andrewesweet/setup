# gcloud Audit — Interactive / Credential / Installs-Code

**Agent**: β (interactive / credential / installs-code coverage)
**Inputs**: `macos-dev/docs/plans/2026-04-14-gcloud-cli-safe-allowlist.md` (plan, draft policy), `macos-dev/docs/research/gcloud-cli-commands.json` (enumeration; gcloud SDK 564.0.0; 5,302 stable leaves).
**Scope**: stable gcloud commands only. Alpha/beta are covered by the plan's blanket ask.
**Method**: grep `.leaves` (alpha/beta stripped) for the agreed token set; read `gcloud <path> --help` on any non-obvious hit to confirm session-blocking, credential-writing, or code-installing behavior; reject false positives already covered by the fall-through `*: ask` default when there is no risk the SAFE-verb allow patterns from the plan would ever match.

Policy recap (from plan § "Rule layering"): the universal SAFE-verb allows are `list | describe | get-iam-policy | get-ancestors-iam-policy | test-iam-permissions | get-value | get-public-key | get | search | lookup | explain | print-settings | versions list | versions describe | operations list | operations describe`. A command only needs an explicit demoting ask when (a) its name matches one of those SAFE patterns, OR (b) it is a session-blocking / credential-producing / code-installing command we want to guarantee asks even if a future edit accidentally whitelists it.

The matrix below includes both cases and errs toward inclusion — "uncertain — recommend ask" is used when behavior is not 100% verifiable from `--help`.

---

## Matrix

### INTERACTIVE / SESSION-BLOCKING

| Service | Subcommand | Kind | Evidence | Proposed pattern |
|---|---|---|---|---|
| top-level | `init` | INTERACTIVE | Interactive wizard; prompts for account / project / config. | `gcloud init` |
| top-level | `docker` | INTERACTIVE | Shells out to `docker` with gcr auth and forwards stdin/stdout; can be long-running. | `gcloud docker *` |
| top-level | `feedback` | INTERACTIVE | Opens a web browser and prompts for feedback text on stdin. | `gcloud feedback` |
| top-level | `survey` | INTERACTIVE | Launches an interactive CLI satisfaction survey (prompts on stdin). | `gcloud survey` |
| ai | `custom-jobs stream-logs` | INTERACTIVE | Streams training-job logs indefinitely. | `gcloud ai * stream-logs` |
| ai | `hp-tuning-jobs stream-logs` | INTERACTIVE | Streams HP tuning logs indefinitely. | covered by `gcloud ai * stream-logs` |
| ai | `endpoints stream-direct-predict` | INTERACTIVE | Streaming prediction; blocks on bi-di stream. Also DATA-plane (Agent α). | `gcloud ai endpoints stream-*` |
| ai | `endpoints stream-direct-raw-predict` | INTERACTIVE | As above. | covered |
| ai | `endpoints stream-raw-predict` | INTERACTIVE | As above. | covered |
| ai-platform | `jobs stream-logs` | INTERACTIVE | Streams training-job logs. | `gcloud ai-platform jobs stream-logs` |
| app | `instances ssh` | INTERACTIVE | SSH to App Engine flex instance; TTY. | `gcloud app instances ssh` |
| app | `instances scp` | INTERACTIVE | SCP wrapper; opens SSH session. | `gcloud app instances scp` |
| app | `logs tail` | INTERACTIVE | Tails logs indefinitely. | `gcloud app logs tail` |
| app | `open-console` | INTERACTIVE | Opens the App Engine dashboard in a browser (side effect). | `gcloud app open-console` |
| app | `operations wait` | INTERACTIVE | Blocks until the LRO completes. | covered by `gcloud * operations wait` |
| ai-platform | `operations wait` | INTERACTIVE | LRO wait. | covered by `gcloud * operations wait` |
| api-gateway | `operations wait` | INTERACTIVE | LRO wait. | covered |
| apihub | `operations wait` | INTERACTIVE | LRO wait. | covered |
| bms | `instances enable-serial-console` | not-interactive | Metadata toggle; no TTY. Mutating, falls through. | (none) |
| bms | `instances disable-serial-console` | not-interactive | Mutating, falls through. | (none) |
| bms | `operations wait` | INTERACTIVE | LRO wait. | covered by `gcloud * operations wait` |
| cloud-shell | `ssh` | INTERACTIVE | Opens SSH session to Cloud Shell. | `gcloud cloud-shell ssh` |
| cloud-shell | `scp` | INTERACTIVE | SCP to Cloud Shell. | `gcloud cloud-shell scp` |
| cloud-shell | `get-mount-command` | INTERACTIVE | Starts Cloud Shell (side effect) then prints an sshfs mount command embedding connection details. | `gcloud cloud-shell get-mount-command` |
| compliance-manager | `operations wait` | INTERACTIVE | LRO wait. | covered |
| composer | `operations wait` | INTERACTIVE | LRO wait. | covered |
| compute | `ssh` | INTERACTIVE | SSH to GCE VM; TTY. | `gcloud compute ssh` |
| compute | `scp` | INTERACTIVE | SCP to GCE VM. | `gcloud compute scp` |
| compute | `copy-files` | INTERACTIVE | Deprecated alias for `scp`; opens SSH. | `gcloud compute copy-files` |
| compute | `start-iap-tunnel` | INTERACTIVE | Opens a persistent IAP TCP tunnel. | `gcloud compute start-iap-tunnel` |
| compute | `connect-to-serial-port` | INTERACTIVE | Interactive serial-console SSH session. | `gcloud compute connect-to-serial-port` |
| compute | `config-ssh` | INTERACTIVE | Rewrites `~/.ssh/config` to add Host entries; may generate SSH keys. Also credential-adjacent (writes keys). | `gcloud compute config-ssh` |
| compute | `reset-windows-password` | INTERACTIVE | Resets the Windows password and prints it; prompts for username. Credential-adjacent. | `gcloud compute reset-windows-password` |
| compute | `instances tail-serial-port-output` | INTERACTIVE | Streams serial-port output indefinitely. | `gcloud compute instances tail-serial-port-output` |
| compute | `instance-groups managed wait-until` | INTERACTIVE | Blocks until MIG reaches state. | `gcloud compute instance-groups managed wait-until*` |
| compute | `instance-groups managed wait-until-stable` | INTERACTIVE | Blocks until MIG is stable. | covered by the previous pattern |
| compute | `tpus queued-resources ssh` | INTERACTIVE | SSH to TPU VM. | `gcloud compute tpus * ssh` |
| compute | `tpus queued-resources scp` | INTERACTIVE | SCP to TPU VM. | `gcloud compute tpus * scp` |
| compute | `tpus tpu-vm ssh` | INTERACTIVE | SSH to TPU VM. | covered by `gcloud compute tpus * ssh` |
| compute | `tpus tpu-vm scp` | INTERACTIVE | SCP to TPU VM. | covered by `gcloud compute tpus * scp` |
| container | `attached operations wait` | INTERACTIVE | LRO wait. | covered by `gcloud * operations wait` |
| container | `aws operations wait` | INTERACTIVE | LRO wait. | covered |
| container | `azure operations wait` | INTERACTIVE | LRO wait. | covered |
| container | `bare-metal operations wait` | INTERACTIVE | LRO wait. | covered |
| container | `fleet operations wait` | INTERACTIVE | LRO wait. | covered |
| container | `hub operations wait` | INTERACTIVE | LRO wait. | covered |
| container | `operations wait` | INTERACTIVE | LRO wait. | covered |
| container | `vmware operations wait` | INTERACTIVE | LRO wait. | covered |
| dataproc | `batches wait` | INTERACTIVE | Blocks on batch completion. | `gcloud dataproc batches wait` |
| dataproc | `jobs wait` | INTERACTIVE | Blocks on job completion. | `gcloud dataproc jobs wait` |
| deployment-manager | `operations wait` | INTERACTIVE | LRO wait. | covered |
| design-center | `operations wait` | INTERACTIVE | LRO wait. | covered |
| developer-connect | `operations wait` | INTERACTIVE | LRO wait. | covered |
| domains | `registrations operations wait` | INTERACTIVE | LRO wait. | covered |
| edge-cloud | `container operations wait` | INTERACTIVE | LRO wait. | covered |
| edge-cloud | `networking operations wait` | INTERACTIVE | LRO wait. | covered |
| emulators | `firestore start` | INTERACTIVE | Foreground emulator; runs until Ctrl-C. | `gcloud emulators * start` |
| emulators | `spanner start` | INTERACTIVE | Foreground emulator. | covered by `gcloud emulators * start` |
| emulators | `spanner env-init` | not-interactive | Prints env vars; one-shot. Fall-through allow for safe read is fine (it is neither SAFE-verb nor mutating). Not demoted. | (none — uncertain, recommend ask only if the plan later adds an allow for `env-init`) |
| endpoints | `operations wait` | INTERACTIVE | LRO wait. | covered |
| gemini | `operations wait` | INTERACTIVE | LRO wait. | covered |
| lustre | `operations wait` | INTERACTIVE | LRO wait. | covered |
| metastore | `operations wait` | INTERACTIVE | LRO wait. | covered |
| ml | `speech operations wait` | INTERACTIVE | LRO wait. | covered |
| ml | `video operations wait` | INTERACTIVE | LRO wait. | covered |
| network-services | `operations wait` | INTERACTIVE | LRO wait. | covered |
| oracle-database | `operations wait` | INTERACTIVE | LRO wait. | covered |
| pam | `operations wait` | INTERACTIVE | LRO wait. | covered |
| services | `operations wait` | INTERACTIVE | LRO wait. | covered |
| services | `vpc-peerings operations wait` | INTERACTIVE | LRO wait. | covered |
| sql | `connect` | INTERACTIVE | Opens an interactive psql/mysql session. | `gcloud sql connect` |
| sql | `operations wait` | INTERACTIVE | LRO wait. | covered |
| telco-automation | `operations wait` | INTERACTIVE | LRO wait. | covered |
| vector-search | `operations wait` | INTERACTIVE | LRO wait. | covered |
| workflows | `executions wait` | INTERACTIVE | Blocks until execution completes. | `gcloud workflows executions wait*` |
| workflows | `executions wait-last` | INTERACTIVE | Blocks until last execution completes. | covered |
| workstations | `ssh` | INTERACTIVE | SSH to workstation. | `gcloud workstations ssh` |
| workstations | `start-tcp-tunnel` | INTERACTIVE | Opens a persistent TCP tunnel. | `gcloud workstations start-tcp-tunnel` |

**Note on SQL export/import**: the draft policy classifies `gcloud sql export ...` and `gcloud sql import ...` as INTERACTIVE. In practice they are LROs that can be polled; `--async` makes them return immediately. They are mutating data-plane operations and are therefore already asked via the fall-through `*: ask` default. Leaving them in the draft's interactive block is belt-and-braces and harmless — keep as drafted.

---

### AUTH / CREDENTIAL

| Service | Subcommand | Kind | Evidence | Proposed pattern |
|---|---|---|---|---|
| auth | `login` | AUTH | Opens browser, writes OAuth credential to `~/.config/gcloud`. | `gcloud auth login` |
| auth | `revoke` | AUTH | Removes credentials from disk. | `gcloud auth revoke` |
| auth | `activate-service-account` | AUTH | Writes SA key to `~/.config/gcloud` as the active credential. | `gcloud auth activate-service-account` |
| auth | `print-access-token` | AUTH | Prints a bearer access token to stdout. | `gcloud auth print-access-token` |
| auth | `print-identity-token` | AUTH | Prints an OIDC identity token to stdout. | `gcloud auth print-identity-token` |
| auth | `application-default login` | AUTH | Writes ADC JSON to `~/.config/gcloud/application_default_credentials.json`. | `gcloud auth application-default *` (covers all 4 subcommands below) |
| auth | `application-default revoke` | AUTH | Deletes the ADC file. | covered |
| auth | `application-default print-access-token` | AUTH | Prints ADC bearer token to stdout. | covered |
| auth | `application-default set-quota-project` | AUTH | Writes `quota_project_id` into the ADC file. | covered |
| auth | `configure-docker` | AUTH | Writes `credHelper` entries into `~/.docker/config.json`. | `gcloud auth configure-docker *` |
| auth | `enterprise-certificate-config create linux` | AUTH | Writes `enterprise_certificate_config.json` referencing hardware-backed certificates. | `gcloud auth enterprise-certificate-config create *` |
| auth | `enterprise-certificate-config create macos` | AUTH | As above. | covered |
| auth | `enterprise-certificate-config create windows` | AUTH | As above. | covered |
| anthos | `auth login` | AUTH | Interactive login that stores kubeconfig credentials for Anthos clusters. | `gcloud anthos auth login` |
| anthos | `create-login-config` | AUTH | Writes an Anthos kubelogin config file to disk (`kubectl-anthos`). | `gcloud anthos create-login-config` |
| anthos | `config controller get-credentials` | AUTH | Writes kubeconfig for the Config Controller instance. | covered by `gcloud * get-credentials` pattern (see below) |
| container | `clusters get-credentials` | AUTH | Writes kubeconfig entry for GKE cluster. | covered by `gcloud * get-credentials` |
| container | `attached clusters get-credentials` | AUTH | Writes kubeconfig for Attached cluster. | covered |
| container | `aws clusters get-credentials` | AUTH | Writes kubeconfig for GKE-on-AWS. | covered |
| container | `azure clusters get-credentials` | AUTH | Writes kubeconfig for GKE-on-Azure. | covered |
| container | `fleet memberships get-credentials` | AUTH | Writes kubeconfig for Fleet membership via Connect gateway. | covered |
| container | `fleet scopes namespaces get-credentials` | AUTH | Writes kubeconfig for Fleet scope namespace. | covered |
| container | `hub memberships get-credentials` | AUTH | Writes kubeconfig for Hub membership (legacy alias of `fleet`). | covered |
| container | `hub scopes namespaces get-credentials` | AUTH | Writes kubeconfig for Hub scope namespace. | covered |
| edge-cloud | `container clusters get-credentials` | AUTH | Writes kubeconfig for Edge cluster. | covered |
| iam | `service-accounts keys create` | AUTH | Writes an RSA private key (JSON or P12) to `--key-file-path`. | `gcloud iam service-accounts keys create` |
| iam | `service-accounts keys upload` | AUTH | Uploads a public key; not credential-material itself, but belongs in the credential-key family. | `gcloud iam service-accounts keys upload` |
| iam | `service-accounts sign-blob` | AUTH | Uses the SA's private key to sign arbitrary bytes; credential-use. | `gcloud iam service-accounts sign-blob` |
| iam | `service-accounts sign-jwt` | AUTH | Uses the SA's private key to sign a JWT; credential-use. | `gcloud iam service-accounts sign-jwt` |
| iam | `workforce-pools create-login-config` | AUTH | Writes a login config file used by 3P workforce identity providers. | `gcloud iam workforce-pools create-login-config` |
| iam | `workforce-pools providers keys create` | AUTH | Writes a workforce provider signing key to disk. | `gcloud iam workforce-pools providers keys create` |
| iam | `workload-identity-pools providers keys create` | AUTH | Writes a workload-identity provider signing key. | `gcloud iam workload-identity-pools providers keys create` |
| compute | `sign-url` | AUTH | Generates a Cloud CDN signed URL that embeds a keyed signature; caller needs and consumes a signing key. | `gcloud compute sign-url` |
| storage | `sign-url` | AUTH | Generates a GCS V4 signed URL with embedded authentication; may read SA key file. | `gcloud storage sign-url` |
| redis | `instances get-auth-string` | AUTH | Prints the Memorystore Redis AUTH password. | `gcloud redis instances get-auth-string` |
| sql | `generate-login-token` | AUTH | Prints an IAM DB access token used as a password. | `gcloud sql generate-login-token` |
| developer-connect | `connections git-repository-links fetch-read-token` | AUTH | Prints a Git repository read token (acts as a credential). | `gcloud developer-connect connections git-repository-links fetch-read-token` |
| developer-connect | `connections git-repository-links fetch-read-write-token` | AUTH | Prints a Git repository read-write token. | `gcloud developer-connect connections git-repository-links fetch-read-write-token` |
| iap | `oauth-clients reset-secret` | AUTH | Returns a freshly generated OAuth client secret. Deprecated but still present. Falls through to mutating-ask anyway. | `gcloud iap oauth-clients reset-secret` (defensive; uncertain — recommend ask) |
| publicca | `external-account-keys create` | AUTH | Returns EAB HMAC key material used for ACME registration. | `gcloud publicca external-account-keys create` (uncertain — recommend ask) |
| services | `api-keys create` | AUTH | Creates an API key; key string returned in response / `keyString` endpoint. Mutating, but credential-producing. | `gcloud services api-keys create` (defensive; already covered by fall-through) |
| artifacts | `print-settings gradle\|mvn\|npm\|python` | AUTH | Can embed SA credentials from `--json-key` into the output snippet; baseline output only references local gcloud creds. Draft includes `print-settings` in the universal SAFE allow-list; this MUST be demoted because the flag path can leak SA key material. | `gcloud artifacts print-settings *` (uncertain — recommend ask; supersedes the SAFE-verb allow for this service) |

**Not included** (mutating verbs, fall through to `*: ask` default with no credential surface that the SAFE-verb allow-list would ever match):
- `kms keys create` — resource creation, no downloadable material.
- `recaptcha keys create`, `resource-manager tags keys create` — resource creation, no secret material in response (reCAPTCHA secret is separately fetched). Fall-through ask is adequate.
- `compute ssl-certificates create`, `sql ssl client-certs create`, `sql ssl-certs create`, `certificate-manager certificates create`, `privateca certificates create` — mutating-ask suffices. `sql ssl client-certs create --cert-file=... --key-file=...` can write a private key to the caller-supplied path, but the command itself is mutating-verb ask.
- `compute os-login ssh-keys add|remove|update` — metadata admin of OS Login SSH keys; mutating-ask.
- `bms ssh-keys add|remove` — mutating-ask.

---

### INSTALLS-CODE

| Service | Subcommand | Kind | Evidence | Proposed pattern |
|---|---|---|---|---|
| components | `install` | INSTALLS-CODE | Downloads and installs additional gcloud components (Python code, binaries). | `gcloud components install*` |
| components | `update` | INSTALLS-CODE | Downloads and updates component binaries. | `gcloud components update*` |
| components | `remove` | INSTALLS-CODE | Uninstalls components; modifies installation tree. | `gcloud components remove*` |
| components | `reinstall` | INSTALLS-CODE | Full reinstall of the SDK. | `gcloud components reinstall` |
| components | `repositories add` | INSTALLS-CODE | Registers an additional component repository (future installs flow from there). | `gcloud components repositories *` |
| components | `repositories remove` | INSTALLS-CODE | Unregisters a component repository. | covered |
| components | `list` | safe-read | Enumerates components; covered by universal `list` allow. | (none — keep SAFE allow) |
| components | `repositories list` | safe-read | Enumerates repositories; covered by universal `list` allow. | (none — keep SAFE allow) |

Note: the draft listed `components restore`. There is no `gcloud components restore` leaf in the enumeration; the command was renamed to `reinstall` before SDK 564. Remove `restore` from the draft pattern set.

---

## Diff-to-draft

Items below are additions beyond the plan's "starting draft" (plan § "Rule layering" lines 41–44).

### Interactive additions (beyond draft)

1. `gcloud feedback` — opens a browser + prompts for feedback. Draft did not include it.
2. `gcloud survey` — interactive satisfaction survey.
3. `gcloud app open-console` — browser side effect.
4. `gcloud app logs tail` — log tail (the draft's `* tail *` covers this, but explicit mention is useful since `logging tail` is alpha/beta-only in SDK 564.0.0; the `* tail *` pattern in the stable surface matches only `app logs tail`, `compute instances tail-serial-port-output`, `storage insights inventory-reports details describe|list` — the last two are not tails, so the pattern is effectively narrow).
5. `gcloud cloud-shell get-mount-command` — starts Cloud Shell as a side effect and prints SSH-tunnel details.
6. `gcloud compute config-ssh` — writes to `~/.ssh/config` and may generate keys.
7. `gcloud compute copy-files` — deprecated alias for `compute scp`; still a TTY SCP.
8. `gcloud compute connect-to-serial-port` — interactive serial SSH. (Draft covers `compute ssh`; this is a distinct command.)
9. `gcloud compute reset-windows-password` — prompts and returns a plaintext password.
10. `gcloud compute instances tail-serial-port-output` — streaming.
11. `gcloud compute instance-groups managed wait-until` and `wait-until-stable` — blocking waits not captured by `operations wait`.
12. `gcloud compute tpus {queued-resources,tpu-vm} ssh|scp` — TTY SSH/SCP on TPUs.
13. `gcloud dataproc batches wait`, `gcloud dataproc jobs wait` — blocking waits.
14. `gcloud workflows executions wait`, `wait-last` — blocking waits.
15. `gcloud workstations ssh`, `gcloud workstations start-tcp-tunnel` — Cloud Workstations TTY + persistent tunnel.
16. `gcloud ai * stream-logs` (`custom-jobs`, `hp-tuning-jobs`), `gcloud ai-platform jobs stream-logs` — unbounded log streams.
17. `gcloud ai endpoints stream-direct-predict|stream-direct-raw-predict|stream-raw-predict` — bi-di streaming predict (also DATA-plane for Agent α).

### AUTH additions (beyond draft)

1. `gcloud auth application-default set-quota-project` — mutates ADC; covered by draft's `application-default *` wildcard but worth naming.
2. `gcloud auth configure-docker` — writes Docker credential helper.
3. `gcloud auth enterprise-certificate-config create linux|macos|windows` — writes certificate config.
4. `gcloud anthos auth login` — interactive login + kubeconfig write.
5. `gcloud anthos create-login-config` — writes Anthos kubelogin config.
6. `gcloud anthos config controller get-credentials` — writes kubeconfig (matches get-credentials pattern).
7. `gcloud container attached|aws|azure|fleet|hub` `clusters get-credentials` / `memberships get-credentials` / `scopes namespaces get-credentials` — all write kubeconfig. Draft only listed `container clusters get-credentials`. **Strongly recommend the pattern `gcloud * get-credentials`** (greedy across depth) rather than enumerating; the stable surface has no false positives.
8. `gcloud edge-cloud container clusters get-credentials` — kubeconfig write.
9. `gcloud iam service-accounts keys upload` — key-family, defensive.
10. `gcloud iam service-accounts sign-blob` — SA-key credential use.
11. `gcloud iam service-accounts sign-jwt` — SA-key credential use.
12. `gcloud iam workforce-pools create-login-config` — writes login config.
13. `gcloud iam workforce-pools providers keys create` — writes signing key.
14. `gcloud iam workload-identity-pools providers keys create` — writes signing key.
15. `gcloud compute sign-url` — generates credential-equivalent signed URL.
16. `gcloud storage sign-url` — generates GCS signed URL.
17. `gcloud redis instances get-auth-string` — prints Redis AUTH password.
18. `gcloud sql generate-login-token` — prints IAM DB access token.
19. `gcloud developer-connect connections git-repository-links fetch-read-token` — prints Git token.
20. `gcloud developer-connect connections git-repository-links fetch-read-write-token` — prints Git token.
21. `gcloud artifacts print-settings *` — MUST demote the draft's universal `print-settings` SAFE allow for this service because `--json-key` can embed SA key material in the printed snippet. (If the draft drops `print-settings` from the universal SAFE list, this demotion is unnecessary.)

### INSTALLS-CODE additions (beyond draft)

1. `components restore` does not exist in SDK 564 — remove from the draft pattern list; replace with `reinstall` (already listed) and `repositories *` (already listed).
2. No other stable installs-code surface beyond `gcloud components *`.

---

## Items needing human judgement

- `gcloud artifacts print-settings *` — only leaks credentials when `--json-key=<path>` is passed. If the operator accepts that a user running gcloud in an agent context will not pass `--json-key`, keep the universal SAFE allow and trust the user. Recommended: demote to ask (safer, breaks one workflow).
- `gcloud iap oauth-clients reset-secret` — deprecated and scheduled for shutdown 2026-03-19; still in surface. Fall-through `*: ask` suffices; defensive explicit rule is optional.
- `gcloud publicca external-account-keys create` — key material is returned by default (to stdout) unless `--key-output-file` is supplied. Fall-through mutating-ask covers it.
- `gcloud services api-keys create` — API key is returned via a separate `get-key-string` lookup; create response contains the key name, not the key string. Fall-through ask is adequate; listed defensively.
- `gcloud emulators spanner env-init` — prints environment variables to set. Not session-blocking, not mutating, not credential. It does not match any SAFE-verb allow. Fall-through `*: ask` handles it. No explicit rule needed.
- Draft's `gcloud sql export|import` in the INTERACTIVE class — these are LROs, not sessions. Leaving them in the draft's block is harmless (mutating-ask would demote them anyway); move to DATA-WRITE if taxonomy purity is desired.
