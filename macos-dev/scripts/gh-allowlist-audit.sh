#!/usr/bin/env bash
# gh-allowlist-audit.sh — enumerate gh CLI command surface for the OpenCode
# safe-bash allowlist. Walks `gh <cmd> --help` recursively, classifies every
# leaf, extracts flags and examples, and writes a structured JSON artifact.
#
# Output: macos-dev/docs/research/gh-cli-commands.json
#
# Re-run this on `gh` version bumps to detect new subcommands or flags.
# Diff the JSON to surface changes.

set -euo pipefail

# Resolve repo root so the script works from any cwd.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)
OUT_DIR="$REPO_ROOT/macos-dev/docs/research"
OUT_FILE="$OUT_DIR/gh-cli-commands.json"

mkdir -p "$OUT_DIR"

command -v gh >/dev/null || { echo "gh not found on PATH" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 not found on PATH" >&2; exit 1; }

GH_VERSION=$(gh --version 2>&1 | head -n1)

python3 - "$GH_VERSION" "$OUT_FILE" <<'PYEOF'
import json, re, subprocess, sys
from datetime import datetime, timezone

GH_VERSION = sys.argv[1]
OUT_FILE   = sys.argv[2]

# Section headers in `gh <cmd> --help` that enumerate child commands.
# Excludes ALIAS COMMANDS (user aliases) and HELP TOPICS (gh help <topic>).
CMD_SECTIONS = {
    "CORE COMMANDS",
    "GITHUB ACTIONS COMMANDS",
    "ADDITIONAL COMMANDS",
    "GENERAL COMMANDS",
    "TARGETED COMMANDS",
    "AVAILABLE COMMANDS",
    "COMMANDS",
}

# Non-command sections we parse from leaf help.
FLAG_SECTIONS     = {"FLAGS", "OPTIONS"}
INHERITED         = {"INHERITED FLAGS"}
EXAMPLE_SECTIONS  = {"EXAMPLES"}

# Max depth guard — gh nesting never exceeds 4 (e.g. gh extension ...).
MAX_DEPTH = 6

def run_help(path):
    """Invoke `gh <path...> --help` and return stdout (stderr merged)."""
    cmd = ["gh"] + path + ["--help"]
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=15, check=False,
        )
    except subprocess.TimeoutExpired:
        return ""
    # gh prints help to stdout for `--help`; fall back to stderr otherwise.
    return proc.stdout or proc.stderr or ""

def parse_sections(help_text):
    """Split help output into {SECTION_HEADER: [lines]} blocks.

    Section headers in gh help are all-caps, optionally followed by
    description on subsequent indented lines. A blank line ends a block.
    """
    sections = {}
    current = None
    header_re = re.compile(r"^([A-Z][A-Z0-9 /_-]*[A-Z])\s*$")
    for raw in help_text.splitlines():
        line = raw.rstrip()
        m = header_re.match(line)
        if m and not line.startswith(" "):
            current = m.group(1).strip()
            sections.setdefault(current, [])
            continue
        if current is None:
            continue
        if line == "":
            current = None
            continue
        sections[current].append(line)
    return sections

def parse_subcommands(section_lines):
    """Extract ``name: description`` entries from a command section."""
    entries = []
    # Lines look like "  name:  description" with 2+ space indent and a colon.
    line_re = re.compile(r"^\s{2,}([a-z][a-z0-9-]*):\s*(.*)$")
    for raw in section_lines:
        m = line_re.match(raw)
        if not m:
            continue
        entries.append({"name": m.group(1), "short": m.group(2).strip()})
    return entries

def parse_flags(section_lines):
    """Parse a FLAGS / INHERITED FLAGS section into a list of flag spec strings.

    gh formats each flag on its own line, potentially wrapping its description
    onto the next indented line. We preserve just the flag signature (short,
    long, argname) — enough for allowlist side-effect analysis.
    """
    flags = []
    # Signature patterns we accept at start of a flag line:
    #   -x, --long[=<v>] <v>
    #   --long[=<v>]
    sig_re = re.compile(
        r"^\s+("
        r"(?:-[a-zA-Z], )?--[a-zA-Z0-9][a-zA-Z0-9-]*"   # --long, -x, --long
        r"(?:[ =][A-Za-z<][A-Za-z0-9<>\[\]., '\"-]*)?"  # optional arg spec
        r")\s{2,}"                                      # 2+ spaces → description
    )
    # Some lines use only short form like "  -w  Watch"; allow that too.
    short_re = re.compile(r"^\s+(-[a-zA-Z])\s{2,}")
    for raw in section_lines:
        m = sig_re.match(raw)
        if m:
            flags.append(m.group(1).strip())
            continue
        m2 = short_re.match(raw)
        if m2:
            flags.append(m2.group(1).strip())
    return flags

def parse_examples(section_lines):
    """Return example command lines (stripped of leading `$ `)."""
    out = []
    for raw in section_lines:
        s = raw.strip()
        if s.startswith("$ "):
            out.append(s[2:])
    return out

def is_leaf(sections):
    """A node is a leaf if no subcommand section is present."""
    return not any(h in sections for h in CMD_SECTIONS)

def walk(path, depth=0):
    """Return a node dict for `gh <path>`, recursing into subcommands."""
    help_text = run_help(path)
    sections  = parse_sections(help_text)

    node = {
        "path":  " ".join(["gh"] + path),
        "depth": depth,
    }

    if is_leaf(sections) or depth >= MAX_DEPTH:
        # Leaf: capture flags + examples.
        flags = []
        for h in FLAG_SECTIONS:
            if h in sections:
                flags.extend(parse_flags(sections[h]))
        inherited = []
        for h in INHERITED:
            if h in sections:
                inherited.extend(parse_flags(sections[h]))
        examples = []
        for h in EXAMPLE_SECTIONS:
            if h in sections:
                examples.extend(parse_examples(sections[h]))
        node["kind"]      = "leaf"
        node["flags"]     = flags
        node["inherited"] = inherited
        node["examples"]  = examples
        return node

    # Branch: recurse into every subcommand.
    children = []
    seen_names = set()
    for h, lines in sections.items():
        if h not in CMD_SECTIONS:
            continue
        for entry in parse_subcommands(lines):
            name = entry["name"]
            if name in seen_names:
                continue
            seen_names.add(name)
            child = walk(path + [name], depth + 1)
            child["short"] = entry["short"]
            children.append(child)
    node["kind"]     = "branch"
    node["children"] = sorted(children, key=lambda c: c["path"])
    return node

def leaf_count(node):
    if node["kind"] == "leaf":
        return 1
    return sum(leaf_count(c) for c in node.get("children", []))

def flatten_leaves(node, out):
    if node["kind"] == "leaf":
        out.append(node)
    else:
        for c in node.get("children", []):
            flatten_leaves(c, out)

root = walk([], depth=0)
leaves = []
flatten_leaves(root, leaves)

artifact = {
    "gh_version": GH_VERSION,
    "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    "schema": "gh-cli-commands.v1",
    "leaf_count": len(leaves),
    "root": root,
    "leaves": sorted(
        [{"path": n["path"], "flags": n["flags"], "inherited": n["inherited"],
          "examples": n["examples"]} for n in leaves],
        key=lambda n: n["path"],
    ),
}

with open(OUT_FILE, "w") as f:
    json.dump(artifact, f, indent=2, sort_keys=False)
    f.write("\n")

print(f"Wrote {OUT_FILE}")
print(f"gh_version: {GH_VERSION}")
print(f"leaf_count: {len(leaves)}")
PYEOF
