# Demo walkthrough (10-15 minutes)

Assumes: repo cloned, `semgrep` installed locally (`pipx install semgrep` or
`brew install semgrep`), `jq` installed. Docker/`woodpecker-cli` steps are optional
(see the network caveat in step 5).

## 1. The problem (1 min)

Open `terraform/main.tf` and `k8s/deployment.yaml`. Point out a couple of planted
issues out loud: hardcoded fake AWS credentials in the provider block, a security
group open to the world on SSH, a privileged Kubernetes container running as root
with a `latest` image tag. All fake/sample content -- nothing here is ever applied
or deployed for real.

## 2. Local scan, same commands CI runs (2 min)

```bash
./scripts/scan-local.sh
```

Walk through the output: Terraform findings, Kubernetes findings, then the custom
org-policy rules firing (S3 owner tag, image tag pinning, privilege escalation),
then the non-blocking secrets/audit pack report, then the severity summary. Point
out the exit code at the end -- `Result: FAIL`.

## 3. Custom rules: write once, test like code (2 min)

```bash
semgrep --validate --config rules/
semgrep --test rules/
```

Both pass. Then break one on purpose to show the failure path:

```bash
sed -i.bak 's/languages: \[yaml\]/languages: [nonexistent-lang]/' rules/kubernetes/no-latest-image-tag.yaml
semgrep --validate --config rules/   # fails: invalid language
mv rules/kubernetes/no-latest-image-tag.yaml.bak rules/kubernetes/no-latest-image-tag.yaml
```

## 4. Autofix (2 min)

```bash
cp k8s/deployment.yaml /tmp/demo.yaml
semgrep scan --config rules/kubernetes/autofix-pin-nginx-tag.yaml --autofix --dryrun /tmp/demo.yaml   # preview only
semgrep scan --config rules/kubernetes/autofix-pin-nginx-tag.yaml --autofix /tmp/demo.yaml            # applies it
diff k8s/deployment.yaml /tmp/demo.yaml
```

Point out: never run `--autofix` inside CI in this repo -- demoed locally only.

## 5. The Woodpecker pipeline (3 min)

```bash
woodpecker-cli exec --backend-engine docker .woodpecker/semgrep.yaml
```

**Network caveat:** this needs to pull the `semgrep/semgrep:1.180.0` image. If Docker
image pulls are blocked in your environment (as they were while building this repo
-- see `docs/FINDINGS.md`), swap `image: semgrep/semgrep:1.180.0` for `image: bash`
in a scratch copy and run with `--backend-engine local` instead; same commands run
directly against your host's installed `semgrep`.

Show: all three blocking scans run and print findings even though the first one
already failed (`when: status: [success, failure]`), then the non-blocking
secrets/audit step, then the severity-gating demo step (passes on ERROR-only,
still shows WARNINGs), then SARIF/JSON generation and the summary. Exit code 1.

Then check out `fixed` and re-run -- exit code 0.

## 6. Diff-aware scanning: only new issues block (2 min)

```bash
git log --oneline   # point at 139ca4d (legacy) and b82225e (adds one new issue)
semgrep scan --config p/terraform --config p/kubernetes --config rules/ \
  --baseline-commit 139ca4d84877bed4502fbbcc4a332acc7423f87b --error --metrics=off \
  terraform/ k8s/deployment.yaml
```

One finding: the newly-added `aws_s3_bucket.reports` missing its `owner` tag --
none of the 12 pre-existing legacy findings show up. Then show the same command
with `--baseline-commit` set to the current commit itself: 0 findings, passes,
despite the exact same legacy findings existing in a full scan.

## 7. Pre-commit (1 min)

```bash
pre-commit run --all-files   # fails on the samples
git checkout fixed -- terraform/main.tf k8s/deployment.yaml
pre-commit run --all-files   # passes
git checkout main -- terraform/main.tf k8s/deployment.yaml
```

## 8. GitHub code scanning (1 min)

Open <https://github.com/kaylahgore-saronic/semgrep-woodpecker-demo/security/code-scanning>
-- 13 real alerts from a real `git push`, no local Semgrep account needed. Mention
the SARIF-suppression gotcha documented in `docs/FINDINGS.md` if there's time.

## 9. Wrap-up (1 min)

Everything above ran with zero Semgrep account, zero login, zero paid tier --
`docs/CE-VS-PAID.md` lists what you'd be giving up by staying on CE (cross-file
dataflow, a dashboard, PR-comment triage, Supply Chain, Pro rules) against what
this demo already covers for free.
