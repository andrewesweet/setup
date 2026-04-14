#!/usr/bin/env python3
"""Port of OpenCode's Wildcard.match + findLast rule resolver for offline
testing of the bash allowlist in opencode.jsonc.

Semantics (from packages/opencode/src/util/wildcard.ts + permission resolver):
  - `Wildcard.match` compiles the pattern to a regex: `*` becomes `.*` under
    the `s` flag. Other regex metacharacters are escaped.
  - A trailing ` *` (space + star) becomes optional `( .*)?` so `"curl *"`
    also matches bare `curl` with no args.
  - `*` is greedy across whitespace, so `"curl *"` matches
    `curl -X POST https://x`.
  - Permission resolution uses `rules.findLast(rule => match(cmd, rule))`
    walking rules in config key-order. The LAST matching rule wins.

This simulator runs 60+ test cases against opencode.jsonc's bash block and
asserts the expected final verdict (allow / ask / deny) for each.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG    = REPO_ROOT / "macos-dev/opencode/opencode.jsonc"


def strip_jsonc(src: str) -> str:
    """Strip // line comments outside strings, plus trailing commas."""
    out: list[str] = []
    i = 0
    in_str = False
    esc = False
    while i < len(src):
        c = src[i]
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == "/" and i + 1 < len(src) and src[i + 1] == "/":
            while i < len(src) and src[i] != "\n":
                i += 1
            continue
        out.append(c)
        i += 1
    stripped = "".join(out)
    return re.sub(r",(\s*[}\]])", r"\1", stripped)


def compile_pattern(pat: str) -> re.Pattern[str]:
    """Port of Wildcard.match pattern compilation."""
    # Handle trailing " *" specially: make the " <rest>" optional.
    trailing_optional = pat.endswith(" *")
    core = pat[:-2] if trailing_optional else pat
    # Escape regex metacharacters, then re-expand `*` to `.*`.
    escaped = re.escape(core).replace(r"\*", ".*")
    if trailing_optional:
        regex = f"^{escaped}( .*)?$"
    else:
        regex = f"^{escaped}$"
    return re.compile(regex, re.DOTALL)


def resolve(command: str, rules: list[tuple[str, str]]) -> tuple[str, str]:
    """Return (action, matching_pattern) using findLast semantics.

    Defaults to ('ask', '<no-match>') if no rule matches (shouldn't happen
    because `*: ask` is always first).
    """
    verdict = ("ask", "<no-match>")
    for pat, action in rules:
        if compile_pattern(pat).fullmatch(command):
            verdict = (action, pat)
    return verdict


def load_bash_rules() -> list[tuple[str, str]]:
    src = CONFIG.read_text()
    data = json.loads(strip_jsonc(src))
    bash = data["permission"]["bash"]
    # Dict preserves insertion order (Python 3.7+). opencode reads the config
    # and uses the same iteration order, so this matches production behavior.
    return list(bash.items())


# ---------------------------------------------------------------------------
# Test suite. Each entry: (command, expected_action, short_label)
# ---------------------------------------------------------------------------
CASES: list[tuple[str, str, str]] = [
    # Default fallthrough — unknown verb asks.
    ("gh something-nonexistent foo",   "ask",   "unknown gh verb falls through"),
    ("ls /etc",                        "allow", "ls allowed broadly"),

    # ── gh family allows ──
    ("gh auth status",                 "allow", "auth status bare"),
    ("gh auth status --hostname x",    "allow", "auth status with args"),
    ("gh config get editor",           "allow", "config get"),
    ("gh config list",                 "allow", "config list bare"),
    ("gh config ls",                   "allow", "config ls alias"),
    ("gh status",                      "allow", "status dashboard"),
    ("gh cache list",                  "allow", "cache list"),
    ("gh cache ls",                    "allow", "cache ls alias"),
    ("gh completion bash",             "allow", "completion"),
    ("gh licenses",                    "allow", "licenses"),
    ("gh repo list octocat",           "allow", "repo list"),
    ("gh repo view cli/cli",           "allow", "repo view"),
    ("gh repo autolink list",          "allow", "repo autolink list"),
    ("gh repo deploy-key list",        "allow", "repo deploy-key list"),
    ("gh repo gitignore view Go",      "allow", "repo gitignore view"),
    ("gh repo license view mit",       "allow", "repo license view"),
    ("gh pr list",                     "allow", "pr list"),
    ("gh pr view 123",                 "allow", "pr view"),
    ("gh pr diff 123",                 "allow", "pr diff"),
    ("gh pr checks 123",               "allow", "pr checks"),
    ("gh pr status",                   "allow", "pr status"),
    ("gh issue view 456",              "allow", "issue view"),
    ("gh issue status",                "allow", "issue status"),
    ("gh workflow view ci.yml",        "allow", "workflow view"),
    ("gh run view 789",                "allow", "run view"),
    ("gh release view v1.0",           "allow", "release view"),
    ("gh release verify checksum",     "allow", "release verify"),
    ("gh release verify-asset foo",    "allow", "release verify-asset"),
    ("gh label list",                  "allow", "label list"),
    ("gh project list --owner me",     "allow", "project list"),
    ("gh project view 1",              "allow", "project view"),
    ("gh project field-list 1",        "allow", "project field-list"),
    ("gh project item-list 1",         "allow", "project item-list"),
    ("gh gist view abc123",            "allow", "gist view"),
    ("gh search repos hello",          "allow", "search repos"),
    ("gh search code foo",             "allow", "search code"),
    ("gh codespace list",              "allow", "codespace list"),
    ("gh codespace view name",         "allow", "codespace view"),
    ("gh agent-task list",             "allow", "agent-task list"),
    ("gh agent-task view task1",       "allow", "agent-task view"),
    ("gh secret list",                 "allow", "secret list"),
    ("gh variable get MYVAR",          "allow", "variable get"),
    ("gh ruleset check main",          "allow", "ruleset check"),
    ("gh alias list",                  "allow", "alias list"),
    ("gh extension list",              "allow", "extension list"),
    ("gh extension search foo",        "allow", "extension search"),
    ("gh attestation verify ./file",   "allow", "attestation verify"),
    ("gh gpg-key list",                "allow", "gpg-key list"),
    ("gh ssh-key list",                "allow", "ssh-key list"),
    ("gh org list",                    "allow", "org list"),

    # ── Mutating / interactive / writes-local / auth fall through to ask ──
    ("gh pr create --title foo",       "ask",   "pr create MUTATING"),
    ("gh pr merge 123",                "ask",   "pr merge MUTATING"),
    ("gh pr close 123",                "ask",   "pr close MUTATING"),
    ("gh pr checkout 123",             "ask",   "pr checkout WRITES-LOCAL"),
    ("gh pr revert 123",               "ask",   "pr revert MUTATING"),
    ("gh pr update-branch 123",        "ask",   "pr update-branch MUTATING"),
    ("gh issue create --title foo",    "ask",   "issue create MUTATING"),
    ("gh issue develop 456",           "ask",   "issue develop MUTATING"),
    ("gh repo clone cli/cli",          "ask",   "repo clone WRITES-LOCAL"),
    ("gh repo create foo",             "ask",   "repo create MUTATING"),
    ("gh repo delete foo",             "ask",   "repo delete MUTATING"),
    ("gh repo sync",                   "ask",   "repo sync MUTATING"),
    ("gh repo set-default",            "ask",   "repo set-default MUTATING"),
    ("gh auth login",                  "ask",   "auth login AUTH"),
    ("gh auth logout",                 "ask",   "auth logout AUTH"),
    ("gh auth token",                  "ask",   "auth token AUTH"),
    ("gh auth switch",                 "ask",   "auth switch AUTH"),
    ("gh config set editor vim",       "ask",   "config set MUTATING"),
    ("gh cache delete abc",            "ask",   "cache delete MUTATING"),
    ("gh workflow run ci.yml",         "ask",   "workflow run MUTATING"),
    ("gh run watch 789",               "ask",   "run watch INTERACTIVE"),
    ("gh run download 789",            "ask",   "run download WRITES-LOCAL"),
    ("gh run rerun 789",               "ask",   "run rerun MUTATING"),
    ("gh release download v1.0",       "ask",   "release download WRITES-LOCAL"),
    ("gh release create v1.0",         "ask",   "release create MUTATING"),
    ("gh label clone src dst",         "ask",   "label clone MUTATING (not local)"),
    ("gh project create --title foo",  "ask",   "project create MUTATING"),
    ("gh project item-add 1 --url u",  "ask",   "project item-add MUTATING"),
    ("gh gist create file.txt",        "ask",   "gist create MUTATING"),
    ("gh gist clone abc",              "ask",   "gist clone WRITES-LOCAL"),
    ("gh gist edit abc",               "ask",   "gist edit MUTATING"),
    ("gh browse",                      "ask",   "browse INTERACTIVE"),
    ("gh copilot",                     "ask",   "copilot INSTALLS-CODE"),
    ("gh codespace ssh mycs",          "ask",   "codespace ssh INTERACTIVE"),
    ("gh codespace create",            "ask",   "codespace create MUTATING"),
    ("gh codespace delete mycs",       "ask",   "codespace delete MUTATING"),
    ("gh codespace cp src dst",        "ask",   "codespace cp WRITES-LOCAL"),
    ("gh codespace ports forward 80",  "ask",   "codespace ports forward INTERACTIVE"),
    ("gh agent-task create --title x", "ask",   "agent-task create MUTATING"),
    ("gh preview prompter",            "ask",   "preview prompter INTERACTIVE"),
    ("gh secret set FOO",              "ask",   "secret set MUTATING"),
    ("gh variable delete X",           "ask",   "variable delete MUTATING"),
    ("gh alias set co 'pr checkout'",  "ask",   "alias set WRITES-LOCAL"),
    ("gh attestation download foo",    "ask",   "attestation download WRITES-LOCAL"),
    ("gh gpg-key add key.pub",         "ask",   "gpg-key add MUTATING"),
    ("gh ssh-key delete 123",          "ask",   "ssh-key delete MUTATING"),
    ("gh extension browse",            "ask",   "extension browse INTERACTIVE"),

    # ── Global flag demotions (last-match-wins over family allow) ──
    ("gh pr view 123 --web",           "ask",   "--web demoted"),
    ("gh pr view 123 -w",              "ask",   "-w short-form demoted"),
    ("gh issue list --web",            "ask",   "--web demoted on issue list"),
    ("gh pr checks --watch",           "ask",   "--watch demoted"),
    ("gh repo view --editor vim",      "ask",   "--editor demoted"),
    ("gh agent-task view t1 --follow", "ask",   "--follow demoted"),
    ("gh repo view foo --output=bar",  "ask",   "--output= demoted"),
    ("gh pr view 1 --clobber",         "ask",   "--clobber demoted"),

    # ── gh auth status --show-token: per-command demotion ──
    ("gh auth status --show-token",    "ask",   "--show-token bare demoted"),
    ("gh auth status -t",              "ask",   "-t bare demoted"),
    ("gh auth status --hostname x --show-token",
                                        "ask",  "--show-token late demoted"),
    ("gh auth status --hostname x -t", "ask",   "-t late demoted"),

    # ── gh api block (unchanged; GET-only policy, last-match-wins) ──
    ("gh api",                         "allow", "gh api bare"),
    ("gh api repos/cli/cli",           "allow", "gh api implicit GET"),
    ("gh api -X GET repos/cli/cli",    "allow", "gh api explicit -X GET"),
    ("gh api --method GET repos/cli/cli","allow","gh api --method GET"),
    ("gh api -XGET repos/cli/cli",     "allow", "gh api -XGET no-space"),
    ("gh api -X POST repos/cli/cli",   "ask",   "gh api -X POST ask"),
    ("gh api -XPOST repos/cli/cli",    "ask",   "gh api -XPOST ask"),
    ("gh api -XPUT repos/cli/cli",     "ask",   "gh api -XPUT ask"),
    ("gh api -XDELETE repos/cli/cli",  "ask",   "gh api -XDELETE ask"),
    ("gh api -XPATCH repos/cli/cli",   "ask",   "gh api -XPATCH ask"),
    ("gh api repos/cli/cli -f x=1",    "ask",   "gh api -f body flips to POST"),
    ("gh api repos/cli/cli --field x=1","ask",  "gh api --field body"),
    ("gh api repos/cli/cli -F f=@f",   "ask",   "gh api -F raw field"),
    ("gh api repos/cli/cli --raw-field x=1","ask","gh api --raw-field"),
    ("gh api repos/cli/cli --input in.json","ask","gh api --input body"),

    # ── Extension explicit denies (must win over help/version etc.) ──
    ("gh extension install owner/repo","deny",  "extension install denied"),
    ("gh extension install owner/repo --help","deny","install --help still deny"),
    ("gh extension install --force x", "deny",  "install --force denied"),
    ("gh extension remove foo",        "deny",  "extension remove denied"),
    ("gh extension upgrade --all",     "deny",  "extension upgrade denied"),
    ("gh extension exec foo",          "deny",  "extension exec denied"),
    ("gh extension create my-ext",     "deny",  "extension create denied"),

    # ── Extension SAFE allows still work (not in deny set) ──
    ("gh extension list",              "allow", "extension list still allowed"),
    ("gh extension search mcp",        "allow", "extension search still allowed"),

    # ── rm -rf deny + scoped exception (regression: extension denies at end
    #    must NOT disturb the /tmp/opencode-* allow) ──
    ("rm -rf /etc/foo",                "deny",  "rm -rf outside /tmp denied"),
    ("rm -rf /tmp/opencode-xxx",       "allow", "rm -rf scoped cleanup allowed"),
]


def main() -> int:
    rules = load_bash_rules()
    print(f"Loaded {len(rules)} bash rules from {CONFIG.relative_to(REPO_ROOT)}\n")

    failures: list[str] = []
    for cmd, expected, label in CASES:
        actual, pat = resolve(cmd, rules)
        if actual != expected:
            failures.append(
                f"  {cmd!r}\n    expected={expected} actual={actual} "
                f"(matched pattern: {pat!r})\n    [{label}]"
            )
        # Only print failures + summary; keeps re-runs terse.
    passed = len(CASES) - len(failures)
    print(f"Passed {passed}/{len(CASES)} test cases.")
    if failures:
        print("\nFailures:")
        for f in failures:
            print(f)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
