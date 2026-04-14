#!/usr/bin/env bash
# gcloud-allowlist-audit.sh — enumerate the gcloud CLI command surface for the
# OpenCode safe-bash allowlist. Wraps `gcloud meta list-commands` (the official
# one-command-per-line dump) into a structured JSON artifact with per-service
# summaries, verb distribution, and alpha/beta separation.
#
# Output: macos-dev/docs/research/gcloud-cli-commands.json
#
# Re-run this on SDK version bumps to detect new subcommands. Diff the JSON to
# surface changes; feed changes into the classification audit if they touch
# data-plane services.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)
OUT_DIR="$REPO_ROOT/macos-dev/docs/research"
OUT_FILE="$OUT_DIR/gcloud-cli-commands.json"

mkdir -p "$OUT_DIR"

command -v gcloud  >/dev/null || { echo "gcloud not found on PATH"  >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 not found on PATH" >&2; exit 1; }

SDK_VERSION=$(gcloud --version 2>&1 | head -n1)

# `gcloud meta list-commands` outputs one command path per line, covering the
# whole tree — branches and leaves. A branch is any path that has at least one
# child. Leaves are paths with no children.
TMP_LIST=$(mktemp)
trap 'rm -f "$TMP_LIST"' EXIT
gcloud meta list-commands > "$TMP_LIST"

python3 - "$SDK_VERSION" "$TMP_LIST" "$OUT_FILE" <<'PYEOF'
import json, sys
from collections import Counter, defaultdict
from datetime import datetime, timezone

SDK_VERSION = sys.argv[1]
LIST_FILE   = sys.argv[2]
OUT_FILE    = sys.argv[3]

with open(LIST_FILE) as f:
    lines = [ln.strip() for ln in f if ln.strip()]

# Each line is a command path like "gcloud compute instances list".
# Derive (service, depth, terminal-verb) per line and work out which paths are
# branches (have children) vs leaves (no children).
paths = sorted(set(lines))
children_of: dict[str, set[str]] = defaultdict(set)
for p in paths:
    parts = p.split()
    if len(parts) > 1:
        parent = " ".join(parts[:-1])
        children_of[parent].add(p)

leaves = [p for p in paths if not children_of.get(p)]

# Top-level service is parts[1] (parts[0] == "gcloud").
def top_service(p: str) -> str:
    parts = p.split()
    return parts[1] if len(parts) > 1 else ""

# Terminal token (verb or resource name depending on depth).
def terminal(p: str) -> str:
    return p.split()[-1]

def is_alpha_beta(p: str) -> bool:
    parts = p.split()
    return len(parts) > 1 and parts[1] in {"alpha", "beta"}

service_counts = Counter(top_service(p) for p in leaves)
verb_counts_all     = Counter(terminal(p) for p in leaves)
verb_counts_stable  = Counter(terminal(p) for p in leaves if not is_alpha_beta(p))

# Per-service terminal-verb summary (useful for audit agents). For each
# non-alpha/beta service, list the distinct terminal verbs and their counts.
per_service_verbs: dict[str, Counter[str]] = defaultdict(Counter)
for p in leaves:
    if is_alpha_beta(p):
        continue
    svc = top_service(p)
    if svc:
        per_service_verbs[svc][terminal(p)] += 1

artifact = {
    "sdk_version": SDK_VERSION,
    "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    "schema": "gcloud-cli-commands.v1",
    "total_paths": len(paths),
    "leaf_count": len(leaves),
    "alpha_beta_leaf_count": sum(1 for p in leaves if is_alpha_beta(p)),
    "stable_leaf_count": sum(1 for p in leaves if not is_alpha_beta(p)),
    "service_count": len(service_counts),
    "service_leaf_counts": dict(sorted(service_counts.items())),
    "verb_counts_all": dict(verb_counts_all.most_common(60)),
    "verb_counts_stable": dict(verb_counts_stable.most_common(60)),
    "per_service_verbs": {
        svc: dict(vc.most_common()) for svc, vc in sorted(per_service_verbs.items())
    },
    "leaves": leaves,
}

with open(OUT_FILE, "w") as f:
    json.dump(artifact, f, indent=2, sort_keys=False)
    f.write("\n")

print(f"Wrote {OUT_FILE}")
print(f"sdk_version: {SDK_VERSION}")
print(f"total_paths: {len(paths)}")
print(f"leaf_count: {len(leaves)} (alpha/beta={artifact['alpha_beta_leaf_count']}, stable={artifact['stable_leaf_count']})")
print(f"service_count: {len(service_counts)}")
PYEOF
