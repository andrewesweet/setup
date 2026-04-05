# Security

This document consolidates all security decisions. It is the single source of truth for credential handling, container hardening, OpenCode permissions, and secret detection.

## Threat model

Environment: senior engineering leader at a regulated financial institution. AI agents (OpenCode) run inside a Podman container with read/write access to working repos and read-only access to credentials. The agent has outbound network access (slirp4netns).

Primary risks:
1. Credential exfiltration by AI agent via outbound HTTPS
2. Accidental credential commit to git
3. Container escape or privilege escalation
4. Supply chain compromise via unsigned/unverified tools

## OpenCode permissions

Global default: `"*": "ask"`. See opencode.md for full config.

Security updates:
- `"echo *": "allow"` has been REMOVED from bash permissions to prevent credential laundering (agent could echo $VAR > /tmp/file).
- `autoupdate` is now DISABLED (`false`) for supply-chain security. Updates SHOULD be applied deliberately.

Key restrictions:
- `read` MUST be scoped to workspace + /tmp + specific config paths. MUST NOT be broadly allowed.
- `cat` in bash MUST be scoped to `/home/dev/workspace/*` and `/tmp/*`. The original broad `"cat *": "allow"` is REMOVED.
- `edit` MUST be scoped to workspace + /tmp.
- `grep`, `glob`, `list` MAY be broadly allowed (read-only, no credential exposure risk from search results themselves).
- `rm -rf *`, `rm -fr *`, `sudo *`, `chmod 777 *` MUST be denied.
- `webfetch`, `websearch` MUST require confirmation.

Rationale: the agent can still search broadly (grep/glob) to understand code, but cannot read arbitrary files (credentials) or edit outside the workspace.

## Credential handling

### No secrets in dotfiles

Credentials MUST NOT be hardcoded in any config file. All credentials come from:
- Environment variables
- `gh auth token`
- `opencode auth login` (stores in auth.json)
- `gcloud auth login` (stores in ~/.config/gcloud/)
- Tool-managed credential stores

### Container credential mounts

| Credential | Mount path | Mode | Security boundary |
|------------|-----------|------|-------------------|
| OpenCode auth | `/home/dev/.opencode-auth/auth.json` | read-only | Copilot API access only |
| GitHub CLI | `/home/dev/.config/gh/` | read-only | GitHub API (gh auth scope) |
| GCP ADC | `/home/dev/.config/gcloud/` | read-only | GCP IAM (dev environments only) |
| CodeQL packs | `/home/dev/.codeql/` | read-only | No credentials, query definitions only |
| SSH agent | `/run/ssh-agent.sock` | read-only | Host MUST use `ssh-add -c` |

OpenCode auth MUST be mounted at `/home/dev/.opencode-auth/` (not inside `.local/share/opencode/`) to avoid being shadowed by the `dev-data-opencode` named volume.

GCP credentials: IAM is the security boundary. The user's GCP access is limited to dev environments. Mounting credentials is accepted with this constraint documented.

SSH agent: `ssh-add -c` on the host REQUIRES user confirmation for each key use inside the container. This prevents silent agent use of SSH keys.

### GITHUB_TOKEN in shell history

Aliases like `gha-pin` expand `$(gh auth token)` into shell history, making tokens visible via `/proc/*/cmdline`.

SHOULD wrap in functions using environment variable injection rather than inline expansion.

MUST add to .bashrc:
```bash
HISTIGNORE="*GITHUB_TOKEN*:*TOKEN*:*SECRET*:*PASSWORD*:*KEY*"
```

## .gitignore_global

The complete `.gitignore_global` is defined in git.md. It MUST include patterns for macOS, editor artefacts, secrets/credentials, and dotfiles local overrides. See git.md for the authoritative list.

## Container hardening

### Runtime flags

```
--read-only
--cap-drop=ALL
--cap-add=CHOWN,DAC_OVERRIDE,FOWNER
--security-opt=no-new-privileges
--network=slirp4netns
--userns=keep-id
```

- MUST NOT add SETUID or SETGID capabilities (not needed at runtime)
- MUST NOT use --privileged
- On macOS Podman Machine, SHOULD use `--userns=keep-id:uid=1000,gid=1000` for deterministic UID mapping

### Network

slirp4netns provides outbound HTTPS only. No inbound ports unless explicitly opened with `--port`.

Future enhancement (deferred): proxy-based allowlist using mitmproxy + cntlm for destination restriction and traffic audit.

### Named volumes

`dev-data-opencode` persists OpenCode session history which MAY contain user-pasted secrets. Document this risk. A `dev clean-sessions` command SHOULD be provided.

## Secret detection in git hooks

gitleaks runs as a prek hook (`.pre-commit-config.yaml`). It scans staged changes for secrets before commit.

This is a second line of defence after `.gitignore_global`. Both MUST be in place.

## Supply chain

### Homebrew (macOS)

All 51 tools verified — zero binary signature issues on target machine. No source builds required.

### WSL2 install scripts

Scripts using `curl | bash` for mise, uv, starship SHOULD pin versions and verify checksums. Document expected checksums in the install script.

### Container

Containerfile MUST pin versions with checksums for all static binary downloads from GitHub releases. apk packages are signed by Chainguard.

## Deferred security enhancements

- Proxy-based allowlist and audit (mitmproxy + cntlm) — credential injection, destination allowlisting, traffic audit from containers
- `--network=none` for fully offline agent runs (requires proxy above)
- Volume-at-rest encryption for dev-data-opencode
