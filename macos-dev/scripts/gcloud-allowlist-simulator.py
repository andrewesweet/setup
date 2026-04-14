#!/usr/bin/env python3
"""gcloud-allowlist-simulator — port of Wildcard.match + findLast for gcloud.

Loads `macos-dev/opencode/opencode.jsonc`, extracts the bash rules, and runs a
battery of gcloud test cases asserting each resolves to the expected
allow / ask / deny verdict.

Test cases cover:
  - every universal SAFE verb at multiple service depths (tier 1)
  - singleton utility allows (info, version, help, topic, auth list, config list)
  - data-plane asks (storage / secrets / logging / pubsub / kms / databases /
    ai / healthcare / vector-search / compute / artifacts / ...)
  - interactive / session-blocking asks (ssh, scp, tunnel, shell, wait, tail,
    init, emulators, feedback, survey, docker)
  - auth / credential asks (login, print-access-token, get-credentials wildcard,
    SA keys, sign-url, token prints)
  - components asks (install/update/remove/reinstall/repositories)
  - artifacts print-settings demotion (tier 7 over tier 1)
  - alpha / beta blanket ask (tier 8 over every prior tier, including SAFE verbs)
  - regressions: mutating verbs fall through to the top-level `*: ask`; unknown
    services default to ask; gh allowlist unaffected.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG    = REPO_ROOT / "macos-dev/opencode/opencode.jsonc"


def strip_jsonc(src: str) -> str:
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
    trailing_optional = pat.endswith(" *")
    core = pat[:-2] if trailing_optional else pat
    escaped = re.escape(core).replace(r"\*", ".*")
    regex = f"^{escaped}( .*)?$" if trailing_optional else f"^{escaped}$"
    return re.compile(regex, re.DOTALL)


def resolve(command: str, rules: list[tuple[str, str]]) -> tuple[str, str]:
    verdict = ("ask", "<no-match>")
    for pat, action in rules:
        if compile_pattern(pat).fullmatch(command):
            verdict = (action, pat)
    return verdict


def load_bash_rules() -> list[tuple[str, str]]:
    src = CONFIG.read_text()
    data = json.loads(strip_jsonc(src))
    return list(data["permission"]["bash"].items())


# ---------------------------------------------------------------------------
CASES: list[tuple[str, str, str]] = [
    # ── Tier 1: universal SAFE verbs (allow) ──
    ("gcloud projects list",                                      "allow", "projects list"),
    ("gcloud compute instances list",                             "allow", "compute instances list"),
    ("gcloud compute instances list --zones=us-central1-a",       "allow", "list with flags"),
    ("gcloud compute instances describe my-vm",                   "allow", "compute instances describe"),
    ("gcloud iam roles describe roles/viewer",                    "allow", "iam roles describe"),
    ("gcloud projects get-iam-policy my-proj",                    "allow", "projects get-iam-policy"),
    ("gcloud compute instances get-iam-policy my-vm",             "allow", "nested get-iam-policy"),
    ("gcloud resource-manager folders get-ancestors-iam-policy 1","allow", "get-ancestors-iam-policy"),
    ("gcloud projects test-iam-permissions my-proj --permissions=x","allow","test-iam-permissions"),
    ("gcloud config get-value project",                           "allow", "config get-value"),
    ("gcloud kms keys get-public-key key1 --keyring=r --location=l","allow","kms get-public-key"),
    ("gcloud source repos search foo",                            "allow", "search"),
    ("gcloud asset search-all-resources --scope=projects/foo",    "ask",   "asset search-all-resources (mutating verb)"),
    # ^ note search-all-resources ends in "search-all-resources" not "search", so doesn't match "gcloud * search"
    ("gcloud dns record-sets lookup foo.example.com",             "allow", "dns lookup"),
    ("gcloud iam roles explain roles/owner",                      "allow", "iam explain"),

    # ── Tier 2: singleton utilities (allow) ──
    ("gcloud info",                                               "allow", "info"),
    ("gcloud info --format=json",                                 "allow", "info with flag"),
    ("gcloud version",                                            "allow", "version"),
    ("gcloud --version",                                          "allow", "--version flag form"),
    ("gcloud help",                                               "allow", "help"),
    ("gcloud help compute",                                       "allow", "help <topic>"),
    ("gcloud topic configurations",                               "allow", "topic configurations"),
    ("gcloud cheat-sheet",                                        "allow", "cheat-sheet"),
    ("gcloud auth list",                                          "allow", "auth list"),
    ("gcloud auth list --format=json",                            "allow", "auth list with flag"),
    ("gcloud config list",                                        "allow", "config list"),
    ("gcloud config configurations list",                         "allow", "config configurations list"),
    ("gcloud config configurations describe my-config",           "allow", "config configurations describe"),

    # ── Tier 3: data-plane asks override tier 1/2 ──
    ("gcloud storage ls gs://bucket",                             "ask",   "storage ls"),
    ("gcloud storage cat gs://bucket/file",                       "ask",   "storage cat"),
    ("gcloud storage cp local.txt gs://bucket/",                  "ask",   "storage cp"),
    ("gcloud storage rm gs://bucket/file",                        "ask",   "storage rm"),
    ("gcloud storage du gs://bucket",                             "ask",   "storage du"),
    ("gcloud storage rsync src dst",                              "ask",   "storage rsync"),
    ("gcloud storage objects list gs://bucket",                   "ask",   "storage objects list (overrides * list)"),
    ("gcloud storage objects describe gs://bucket/f",             "ask",   "storage objects describe"),
    ("gcloud storage folders list gs://bucket",                   "ask",   "storage folders list"),
    ("gcloud storage managed-folders create gs://b/f/",           "ask",   "storage managed-folders create"),
    ("gcloud storage buckets list",                               "allow", "storage buckets list (bucket is metadata)"),
    ("gcloud storage buckets describe gs://bucket",               "allow", "storage buckets describe"),
    ("gcloud secrets versions access latest --secret=my-secret",  "ask",   "secrets versions access"),
    ("gcloud secrets list",                                       "allow", "secrets list (metadata)"),
    ("gcloud secrets versions list --secret=my-secret",           "allow", "secrets versions list (metadata)"),
    ("gcloud logging read 'resource.type=gae_app'",               "ask",   "logging read"),
    ("gcloud logging tail 'resource.type=gae_app'",               "ask",   "logging tail"),
    ("gcloud logging write my-log 'text'",                        "ask",   "logging write"),
    ("gcloud logging sinks list",                                 "allow", "logging sinks list (metadata)"),
    ("gcloud pubsub subscriptions pull my-sub --auto-ack",        "ask",   "pubsub pull"),
    ("gcloud pubsub topics publish my-topic --message=hi",        "ask",   "pubsub publish"),
    ("gcloud pubsub topics list",                                 "allow", "pubsub topics list"),
    ("gcloud kms encrypt --plaintext-file=in --ciphertext-file=out --key=k --keyring=r --location=l","ask","kms encrypt"),
    ("gcloud kms decrypt --ciphertext-file=in --plaintext-file=out --key=k --keyring=r --location=l","ask","kms decrypt"),
    ("gcloud kms asymmetric-sign --input-file=in --signature-file=out --key=k --version=1 --keyring=r --location=l","ask","kms asymmetric-sign"),
    ("gcloud kms mac-verify --input-file=in --mac-file=m --key=k --version=1 --keyring=r --location=l","ask","kms mac-verify"),
    ("gcloud kms keys list --keyring=r --location=l",             "allow", "kms keys list (metadata)"),
    ("gcloud kms keyrings describe r --location=l",               "allow", "kms keyrings describe"),
    ("gcloud spanner databases execute-sql my-db --sql='select 1'","ask",  "spanner execute-sql"),
    ("gcloud spanner rows insert --table=t --data=d --database=d2 --instance=i","ask","spanner rows insert"),
    ("gcloud spanner instances list",                             "allow", "spanner instances list"),
    ("gcloud sql connect my-instance",                            "ask",   "sql connect"),
    ("gcloud sql export csv my-instance gs://bucket/dump.csv",    "ask",   "sql export"),
    ("gcloud sql import csv my-instance gs://bucket/dump.csv",    "ask",   "sql import"),
    ("gcloud sql instances list",                                 "allow", "sql instances list"),
    ("gcloud firestore export gs://bucket",                       "ask",   "firestore export"),
    ("gcloud firestore bulk-delete --collection-ids=c",           "ask",   "firestore bulk-delete"),
    ("gcloud firestore databases list",                           "allow", "firestore databases list"),
    ("gcloud ai endpoints predict my-endpoint --region=us-c1 --json-request=r.json","ask","ai endpoints predict"),
    ("gcloud ai endpoints stream-direct-predict my-endpoint --region=us-c1 --inputs=i","ask","ai endpoints stream-direct-predict"),
    ("gcloud ai endpoints list --region=us-central1",             "allow", "ai endpoints list"),
    ("gcloud ai-platform predict --model=m --json-instances=i.json","ask", "ai-platform predict"),
    ("gcloud ml language analyze-entities --content='hello'",     "ask",   "ml language analyze-entities"),
    ("gcloud ml speech recognize audio.raw --language-code=en-US","ask",   "ml speech recognize"),
    ("gcloud vector-search collections data-objects create c d --index=i --region=r","ask","vector-search data-objects create"),
    ("gcloud vector-search collections data-objects list --index=i --region=r --collection=c","ask","vector-search data-objects list (overrides * list)"),
    ("gcloud vector-search indexes list --region=us-c1",          "allow", "vector-search indexes list (metadata)"),
    ("gcloud healthcare fhir-stores export gcs my-store --gcs-uri=gs://b --dataset=d --location=l","ask","healthcare fhir-stores export"),
    ("gcloud healthcare datasets deidentify my-dataset --destination-dataset=d2 --location=l","ask","healthcare deidentify"),
    ("gcloud healthcare datasets list --location=us-central1",    "allow", "healthcare datasets list"),
    ("gcloud functions call my-fn --data='{}'",                   "ask",   "functions call"),
    ("gcloud functions logs read my-fn",                          "ask",   "functions logs read"),
    ("gcloud functions list --region=us-central1",                "allow", "functions list"),
    ("gcloud app logs tail",                                      "ask",   "app logs tail"),
    ("gcloud app logs read",                                      "ask",   "app logs read"),
    ("gcloud run services logs read my-svc",                      "ask",   "run services logs read"),
    ("gcloud compute images export --image=i --destination-uri=gs://b/img.tar.gz","ask","compute images export"),
    ("gcloud compute instances get-serial-port-output my-vm",     "ask",   "compute get-serial-port-output"),
    ("gcloud compute instances tail-serial-port-output my-vm",    "ask",   "compute tail-serial-port-output"),
    ("gcloud compute images list",                                "allow", "compute images list"),
    ("gcloud artifacts files download --location=l --repository=r --package=p --version=v","ask","artifacts files download"),
    ("gcloud artifacts generic upload --source=f --location=l --repository=r --package=p --version=v","ask","artifacts generic upload"),
    ("gcloud artifacts repositories list --location=us-central1", "allow", "artifacts repositories list"),

    # ── Tier 4: interactive / session-blocking asks ──
    ("gcloud init",                                               "ask",   "init"),
    ("gcloud init --console-only",                                "ask",   "init with flag"),
    ("gcloud docker --authorize-only",                            "ask",   "docker"),
    ("gcloud feedback",                                           "ask",   "feedback"),
    ("gcloud survey",                                             "ask",   "survey"),
    ("gcloud compute operations wait op-123",                     "ask",   "compute operations wait"),
    ("gcloud container operations wait op-1 --location=us-c1",    "ask",   "container operations wait"),
    ("gcloud dataproc jobs wait job-id --region=us-c1",           "ask",   "dataproc jobs wait"),
    ("gcloud workflows executions wait e1 --workflow=w --location=l","ask","workflows executions wait"),
    ("gcloud ai custom-jobs stream-logs job-id --region=us-c1",   "ask",   "ai stream-logs"),
    ("gcloud cloud-shell ssh",                                    "ask",   "cloud-shell ssh"),
    ("gcloud cloud-shell scp localhost:src cloudshell:dst",       "ask",   "cloud-shell scp"),
    ("gcloud compute ssh my-vm",                                  "ask",   "compute ssh"),
    ("gcloud compute scp local.txt my-vm:~",                      "ask",   "compute scp"),
    ("gcloud compute start-iap-tunnel my-vm 22",                  "ask",   "start-iap-tunnel"),
    ("gcloud compute connect-to-serial-port my-vm",               "ask",   "connect-to-serial-port"),
    ("gcloud compute config-ssh",                                 "ask",   "config-ssh"),
    ("gcloud compute reset-windows-password my-vm",               "ask",   "reset-windows-password"),
    ("gcloud compute tpus tpu-vm ssh my-tpu --zone=us-c1-a",      "ask",   "compute tpus tpu-vm ssh"),
    ("gcloud compute tpus queued-resources ssh qr --zone=us-c1-a","ask",   "compute tpus queued-resources ssh"),
    ("gcloud emulators firestore start",                          "ask",   "emulators firestore start"),
    ("gcloud emulators spanner start --host-port=localhost:9010", "ask",   "emulators spanner start"),
    ("gcloud workstations ssh my-ws --cluster=c --config=cf --region=r","ask","workstations ssh"),
    ("gcloud app open-console",                                   "ask",   "app open-console"),
    ("gcloud app instances ssh default/i1",                       "ask",   "app instances ssh"),

    # ── Tier 5: auth / credential asks ──
    ("gcloud auth login",                                         "ask",   "auth login"),
    ("gcloud auth logout --all",                                  "ask",   "auth logout"),
    ("gcloud auth revoke user@example.com",                       "ask",   "auth revoke"),
    ("gcloud auth activate-service-account --key-file=k.json",    "ask",   "activate-service-account"),
    ("gcloud auth print-access-token",                            "ask",   "print-access-token"),
    ("gcloud auth print-identity-token --audiences=x",            "ask",   "print-identity-token"),
    ("gcloud auth application-default login",                     "ask",   "ADC login"),
    ("gcloud auth application-default print-access-token",        "ask",   "ADC print-access-token"),
    ("gcloud auth application-default set-quota-project my-p",    "ask",   "ADC set-quota-project"),
    ("gcloud auth configure-docker us-central1-docker.pkg.dev",   "ask",   "configure-docker"),
    ("gcloud auth enterprise-certificate-config create linux",    "ask",   "enterprise-certificate-config"),
    ("gcloud container clusters get-credentials my-cluster",      "ask",   "container get-credentials"),
    ("gcloud container fleet memberships get-credentials m1",     "ask",   "container fleet get-credentials"),
    ("gcloud container aws clusters get-credentials c1",          "ask",   "container aws get-credentials"),
    ("gcloud anthos config controller get-credentials c1 --location=l","ask","anthos config controller get-credentials"),
    ("gcloud iam service-accounts keys create key.json --iam-account=sa","ask","iam SA keys create"),
    ("gcloud iam service-accounts keys upload k.pub --iam-account=sa","ask","iam SA keys upload"),
    ("gcloud iam service-accounts sign-blob --iam-account=sa in.bin out.sig","ask","iam SA sign-blob"),
    ("gcloud iam service-accounts sign-jwt --iam-account=sa in.json out.jwt","ask","iam SA sign-jwt"),
    ("gcloud compute sign-url gs://b/obj --key-file=k",           "ask",   "compute sign-url"),
    ("gcloud storage sign-url gs://b/obj --duration=10m",         "ask",   "storage sign-url"),
    ("gcloud redis instances get-auth-string my-redis --region=us-c1","ask","redis get-auth-string"),
    ("gcloud sql generate-login-token",                           "ask",   "sql generate-login-token"),
    ("gcloud developer-connect connections git-repository-links fetch-read-token link --connection=c --location=l","ask","developer-connect fetch-read-token"),

    # ── Tier 6: components (installs code) ──
    ("gcloud components install kubectl",                         "ask",   "components install"),
    ("gcloud components update",                                  "ask",   "components update"),
    ("gcloud components remove gsutil",                           "ask",   "components remove"),
    ("gcloud components reinstall",                               "ask",   "components reinstall"),
    ("gcloud components repositories list",                       "ask",   "components repositories list (mutating-adjacent)"),
    ("gcloud components list",                                    "allow", "components list (safe — metadata)"),

    # ── Tier 7: artifacts print-settings demotion ──
    ("gcloud artifacts print-settings gradle --project=p --repository=r --location=l","ask","artifacts print-settings (demoted over tier 1)"),
    ("gcloud artifacts print-settings npm --json-key=/tmp/k.json --repository=r --location=l --scope=s","ask","artifacts print-settings with --json-key"),

    # ── Tier 8: alpha / beta blanket ask ──
    ("gcloud alpha",                                              "ask",   "alpha bare"),
    ("gcloud alpha compute instances list",                       "ask",   "alpha list (overrides * list allow)"),
    ("gcloud alpha projects describe my-proj",                    "ask",   "alpha describe"),
    ("gcloud alpha iam roles get-iam-policy p",                   "ask",   "alpha get-iam-policy"),
    ("gcloud beta",                                               "ask",   "beta bare"),
    ("gcloud beta compute instances list",                        "ask",   "beta list"),
    ("gcloud beta projects get-iam-policy my-proj",               "ask",   "beta get-iam-policy"),

    # ── Mutating verbs fall through to *: ask ──
    ("gcloud compute instances create my-vm --zone=us-c1-a",      "ask",   "compute instances create"),
    ("gcloud compute instances delete my-vm --zone=us-c1-a",      "ask",   "compute instances delete"),
    ("gcloud projects add-iam-policy-binding p --member=u --role=r","ask", "projects add-iam-policy-binding"),
    ("gcloud projects set-iam-policy p policy.json",              "ask",   "projects set-iam-policy"),
    ("gcloud config set project my-proj",                         "ask",   "config set"),
    ("gcloud services enable compute.googleapis.com",             "ask",   "services enable"),
    ("gcloud services disable compute.googleapis.com",            "ask",   "services disable"),

    # ── Unknown / unexpected — default *: ask ──
    ("gcloud madeup-service foo bar",                             "ask",   "unknown service"),
    ("gcloud",                                                    "ask",   "bare gcloud"),

    # ── Regressions: gh allowlist unaffected ──
    ("gh pr view 123",                                            "allow", "gh pr view still allowed"),
    ("gh extension install foo",                                  "ask",   "gh extension install still asks"),
    ("git status",                                                "allow", "git status still allowed"),
    ("ls /etc",                                                   "allow", "ls still allowed"),
    ("rm -rf /tmp/opencode-foo",                                  "allow", "rm -rf scoped cleanup still allowed"),
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
