# Findings: what Semgrep CE caught, what it missed

Semgrep version used throughout: `1.180.0` (CLI, installed natively; the Woodpecker
pipeline uses the pinned `semgrep/semgrep` container of the same version). All runtimes
below are on this repo's tiny sample set (1-4 files) on a single developer laptop --
not representative of a large-repo scan.

## Terraform (`terraform/main.tf`, scanned with `--config p/terraform`)

Runtime: ~1.6s, 56 rules evaluated, 1 file scanned.

**Caught (4 findings):**

| Rule | Line | Severity | What it caught |
|---|---|---|---|
| `terraform.aws.security.aws-provider-static-credentials` | 19 | WARNING | Hardcoded fake AWS access/secret key in the `provider "aws"` block |
| `terraform.aws.security.aws-ebs-volume-unencrypted` | 66 | WARNING | `aws_ebs_volume` with `encrypted = false` |
| `terraform.aws.security.aws-db-instance-no-logging` | 73 | WARNING | `aws_db_instance` with no enabled CloudWatch log exports |
| `terraform.lang.security.rds-insecure-password-storage-in-source-code` | 80 | WARNING | Hardcoded fake RDS password -- **suppressed** via `# nosemgrep: <rule-id>` (feature 4.4 demo; see below) |

**Known misses (kept deliberately, not pack bugs we tried to work around):**

- **Public S3 bucket ACL** (`aws_s3_bucket_acl` with `acl = "public-read"`) -- not flagged by `p/terraform`. The newer `aws_s3_bucket_acl` resource (vs. the deprecated inline `acl` attribute on `aws_s3_bucket`) doesn't appear to have ruleset coverage in this pack version.
- **Missing S3 bucket encryption** (no `aws_s3_bucket_server_side_encryption_configuration`) -- not flagged. The pack checks several encrypted-at-rest resource types (EBS, RDS storage) but not "S3 bucket is missing its encryption resource entirely."
- **Missing S3 bucket versioning** -- not flagged, same story.
- **Security group open to `0.0.0.0/0` on port 22** -- not flagged by `p/terraform` despite being one of the most commonly-cited Terraform misconfigurations; a genuine, slightly surprising miss.
- **`aws_db_instance.publicly_accessible = true`** -- not flagged on its own (only the *no-logging* and *insecure-password* findings fired for this resource).
- **IAM policy with wildcard `Action = "*"` / `Resource = "*"`** -- not flagged by `p/terraform`, but **is** flagged by `p/default` (`terraform.lang.security.iam.no-iam-star-actions.no-iam-star-actions`). This is a useful finding in its own right: `p/terraform` and `p/default` are not redundant, they cover different rule subsets.

## Kubernetes (`k8s/deployment.yaml`, scanned with `--config p/kubernetes`)

Runtime: ~1.6s, 10 rules evaluated (an intentionally small, focused pack -- 11 rules
were "run" on the unsuppressed sample, 10 after the `docs/`/`.example` ignore changes
didn't affect this file), 1 file scanned.

**Caught (4 findings on the vulnerable `demo-app` deployment):**

| Rule | Line | Severity | What it caught |
|---|---|---|---|
| `yaml.kubernetes.security.run-as-non-root` | 20 | INFO | No explicit `runAsNonRoot: true` |
| `yaml.kubernetes.security.hostnetwork-pod` | 22 | WARNING | `hostNetwork: true` |
| `yaml.kubernetes.security.writable-filesystem-container` | 24 | WARNING | No `readOnlyRootFilesystem: true` |
| `yaml.kubernetes.security.privileged-container` | 29 | WARNING | `privileged: true` |

The sibling `demo-app-safe` deployment in the same file (used as the "known-good"
comparison) produces **zero** findings from this pack, confirming the rule set
correctly distinguishes the two.

**A real gotcha worth calling out:** `run-as-non-root` specifically checks for the
literal field `securityContext.runAsNonRoot: true` -- it does **not** infer
"non-root" from `runAsUser` being a non-zero value. An early draft of the "safe"
example set `runAsUser: 1000` but not `runAsNonRoot: true` and still triggered this
INFO finding; fixed by adding the explicit field. Document this if you reuse `p/kubernetes`
elsewhere -- it's an easy trap.

**Known misses:**

- **`hostPath` volume mounting `/` from the host** -- not flagged. `p/kubernetes` has no `hostPath`-specific rule in this version (confirmed: only 10-11 total rules in the pack, and none match on `hostPath`).
- **No resource requests/limits set** -- not flagged. Not covered by this pack at all.
- **`image: nginx:latest`** -- not flagged by `p/kubernetes` (expected; image-tag pinning is an org-policy choice, not a generic security pack concern -- this is exactly why it's a **custom rule** here, see below).
- **Hardcoded fake secret in a plain env var** (`DB_PASSWORD`) -- not flagged by `p/kubernetes`, and (see below) also not flagged by `p/secrets`. A genuine coverage gap for CE's out-of-the-box rules on Kubernetes manifests.

## Secrets pack (`p/secrets`, scanned over the whole repo)

Runtime: ~1.7s, 40 rules evaluated.

**Caught:** both fake Terraform secrets (`aws-provider-static-credentials`,
`rds-insecure-password-storage-in-source-code` -- the latter suppressed via
`# nosemgrep`, see below).

**Known miss:** the hardcoded `DB_PASSWORD` env var value in `k8s/deployment.yaml`
is **not** caught by `p/secrets`. Its generic hardcoded-password detectors appear to
target source-code-style assignments (`password = "..."`, `secret_key = "..."`)
rather than plain YAML `key: value` env entries. This is a meaningful real-world gap:
a team relying on `p/secrets` alone for Kubernetes manifests would miss a hardcoded
secret sitting in plain sight in a pod spec.

## `p/security-audit` and `p/default` (extra community packs)

- **`p/security-audit`**: only 5 rules applicable to this repo's 2 files, 0 findings. This pack is overwhelmingly general-purpose-language-oriented (its name notwithstanding) and has very little to say about Terraform/Kubernetes IaC specifically. Low noise, low signal for this use case -- include it for completeness, don't rely on it for IaC coverage.
- **`p/default`**: 1 additional finding beyond `p/terraform` -- the IAM wildcard-actions rule noted above. Modest but real added value; no noisy overlap observed with `p/terraform` on this sample set.

## Custom org rules (`rules/`)

Runtime: ~1.5s, 4 rules evaluated against both `terraform/main.tf` and `k8s/deployment.yaml`.

All 4 custom rules fire exactly where intended and are silent on the `-safe`/fixed
counterparts in the same files (verified with `semgrep --test rules/`, which passes
4/4 unit tests and 1/1 autofix test):

| Rule | Fires on | Silent on |
|---|---|---|
| `rules/terraform/s3-required-owner-tag.yaml` | `aws_s3_bucket.logs` (no `owner` tag) | `aws_s3_bucket.artifacts` (has `owner` tag) |
| `rules/kubernetes/no-latest-image-tag.yaml` | `nginx:latest` | `nginx:1.27.2` |
| `rules/kubernetes/require-no-priv-escalation.yaml` | missing or `allowPrivilegeEscalation: true` | `allowPrivilegeEscalation: false` |
| `rules/kubernetes/autofix-pin-nginx-tag.yaml` | `nginx:latest` (rewrites to `nginx:1.27.2`) | already-pinned `nginx:*` |

### A YAML pattern-matching gotcha hit while writing `no-latest-image-tag`

Semgrep's YAML/generic matcher treats a scalar value like `nginx:latest` as a single
atomic token -- you cannot write a pattern like `"image: $IMAGE:latest"` expecting it
to split on the colon the way it would in a programming language. The working
approach is `pattern: "image: $IMAGE"` (capturing the whole value) plus a
`metavariable-regex` on `$IMAGE`. A second, less obvious trap: the regex must be
fully anchored around the **entire alternation** (`"^([^:]+|.*:latest)$"`), not just
anchored per-branch (`"(:latest$)|(^[^:]+$)"` silently matched nothing) -- `metavariable-regex`
appears to require a full-string match, not a substring search.

### Inline suppression (feature 4.4)

The RDS password line in `terraform/main.tf` is suppressed with:

```hcl
password = "SuperSecretPassw0rd!" # nosemgrep: terraform.lang.security.rds-insecure-password-storage-in-source-code.rds-insecure-password-storage-in-source-code
```

Verified: running `semgrep scan --config p/terraform terraform/` with the suppression
in place reports 3 findings (not 4) -- the suppressed rule disappears, everything
else is unaffected. Both the bare `# nosemgrep` form and the
`# nosemgrep: <rule-id>` form were tested directly against this Semgrep version and
both work; the colon form is used here so the suppression is scoped to exactly one
rule rather than silencing the whole line.

**This suppression needs review** the next time this file changes -- it only exists
because the "secret" is fake and the point is to demonstrate the suppression
mechanism, not because the underlying finding is actually a false positive.

### `.semgrepignore` (feature 4.4)

Excludes `*.example` (fixed/reference files), `docs/`, `vendor/semgrep-rules/`, and
`rules/` (custom-rule test fixtures, which intentionally contain bad patterns and
would otherwise show up as noise in whole-repo pack scans like `p/secrets`).
Verified: `semgrep scan --config p/secrets .` reports 1 finding with `rules/`
ignored vs. additional unrelated noise from the fixture files without it.
Confirmed `semgrep --test` / `semgrep --validate` are unaffected by `.semgrepignore`
(they take `rules/` as an explicit `--config` path, not a scanned target, so the
exclusion doesn't block rule testing).

### Rule validation and testing (feature 4.6)

- `semgrep --validate --config rules/` → `Configuration is valid - found 0 configuration error(s), and 4 rule(s).`
- `semgrep --test rules/` → `4/4: All tests passed` / `1/1: All fix tests passed`
- **Proof of failure path:** temporarily setting `no-latest-image-tag.yaml`'s
  `languages:` to an invalid value made `--validate` fail with
  `semgrep error: invalid language: nonexistent-lang`. Temporarily breaking the
  rule's `metavariable-regex` (to a pattern that can never match) made `--test` fail
  with `missed lines: [9, 19]`. Both were reverted immediately after confirming the
  failure; the rule files in the repo are the known-good versions.
- Test file naming: `<rule-stem>.<language-extension>` for Terraform (e.g.
  `s3-required-owner-tag.tf`), and `<rule-stem>.test.yaml` for YAML-language rules
  (to avoid the rule file and its test fixture both being named `<rule>.yaml`).
  Autofix tests additionally need a `<rule-stem>.test.fixed.yaml` companion holding
  the expected post-fix content -- confirmed empirically (not documented clearly in
  current Semgrep docs; found by testing naming variants directly).

### Autofix (feature 4.7)

Demoed on a scratch copy of `k8s/deployment.yaml` (never on the committed sample,
so `nginx:latest` stays planted as a finding):

```
$ semgrep scan --config rules/kubernetes/autofix-pin-nginx-tag.yaml --autofix --dryrun /tmp/autofix-demo/deployment.yaml
...
    ▶▶┆ Autofix ▶ image: nginx:1.27.2
    26┆ image: nginx:1.27.2
```

`--dryrun` (no hyphen -- not `--dry-run`, the original spec's guess) only previews
the rewrite; the file on disk is confirmed unchanged afterward. Running the same
command without `--dryrun` applies it for real:

```diff
-          image: nginx:latest
+          image: nginx:1.27.2
```

Autofix is never run inside CI in this repo -- only demoed locally.

## Environment note: Docker image pulls are blocked in this environment

Fresh `docker pull`s through this machine's colima VM (and even raw-IP traffic from
the host) time out -- looks like corporate network/VPN egress filtering, not a
Semgrep or Woodpecker issue. This blocks pulling the `semgrep/semgrep` container image
and, more importantly, blocks **all of Phase 3** (kind cluster, ingress-nginx,
Forgejo, Woodpecker -- every one of those needs a fresh image/chart pull). Per the
plan's own ground rule ("if something differs, use what works and record it"):
`.woodpecker/semgrep.yaml` and `.woodpecker/semgrep-custom.yaml` are unchanged and
correct as container-image pipelines (that's what actually runs once a real
Woodpecker agent -- with working network -- executes them). For local validation in
this environment, a temporary copy with `image: semgrep/semgrep:1.180.0` swapped to
`image: bash` was run through `woodpecker-cli exec --backend-engine local`, which
executes step `commands:` directly against the host's natively-installed `semgrep`
(same version, `1.180.0`) instead of in a container. This is a deliberate,
documented substitution for local testing only -- never committed to the repo --
not a change to the actual pipeline definition. Phase 3 is deferred until network
access is restored.

## Diff-aware scanning (feature 4.2)

Demonstrated locally and fully working, using `woodpecker-cli exec`'s push-event
simulation (`--prev-commit-sha`) rather than a live pull-request (that needs a real
Woodpecker server to populate `CI_COMMIT_TARGET_BRANCH` from PR metadata -- deferred
to Phase 3; `woodpecker-cli exec` has no CLI flag to set that variable directly for
local testing, confirmed by checking `woodpecker-cli exec --help` for every
`CI_COMMIT_*`/`CI_PREV_COMMIT_*` flag).

Setup: commit `139ca4d` (legacy baseline, several pre-existing findings) → commit
`b82225e` adds exactly one new issue (`aws_s3_bucket.reports` with no `owner` tag).

- **Full (non-diff-aware) scan of the new commit:** 13 total findings (all legacy + the 1 new one).
- **`--baseline-commit 139ca4d` scan of the new commit:** exactly **1 finding** -- `rules.terraform.s3-required-owner-tag` on the new `aws_s3_bucket.reports` resource, line 108. Semgrep's own log makes the mechanism explicit: `Creating git worktree from '139ca4d...' to scan baseline` / `Will report findings introduced by these commits`. Exit code 1 (correctly blocks on the new issue).
- **`--baseline-commit <same commit as HEAD>` (simulating "no new issues since last push"):** 0 findings, exit code 0 -- passes cleanly despite 13 legacy findings existing in a full scan of the same tree.

This proves the core diff-aware mechanism end-to-end: legacy findings never block, only newly-introduced findings do.

## Severity gating (feature 4.3)

`.woodpecker/semgrep.yaml`'s `severity-gate-demo` step runs `p/terraform` twice:
`--severity ERROR --error` (blocking) then the same scan with no severity filter
(reporting only, `|| true`). Verified locally: every one of `p/terraform`'s findings
on `terraform/main.tf` is WARNING level, so the ERROR-only gate reports **0 findings
and passes** (`Findings: 0 (0 blocking)`), while the unfiltered reporting run in the
same step still shows the same **3 WARNING findings** it always does. This is the
exact mechanism the plan asked to demonstrate: severity-gating controls which
findings are allowed to fail a build, independent of whether those findings exist.
(Separately, `terraform-scan` and `kubernetes-scan` deliberately gate on
`ERROR + WARNING` so the overall demo build still fails on these samples -- the two
steps are testing different things, not contradicting each other.)

## Still to document in later phases

- Vendored/offline rule run results (feature 4.8).
- Pre-commit hook pass/fail demo (feature 4.9).
- GitHub code scanning alert screenshot/link (feature 4.11).
- Real pull_request-triggered diff-aware scan once Phase 3 (Forgejo + Woodpecker-on-k8s) is unblocked.
