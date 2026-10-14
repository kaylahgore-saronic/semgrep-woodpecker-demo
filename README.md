# Semgrep CE + Woodpecker CI demo

Proves that **Semgrep Community Edition** (free, open-source, no login required) can
scan Terraform and Kubernetes manifests inside a **Woodpecker CI** pipeline, and
showcases the CE features listed below. Everything here is sample/demo content:
Terraform is never applied, no real cloud resources exist, and every "secret" is
fake.

- Public demo repo (pushed from here, feature 4.11): <https://github.com/kaylahgore-saronic/semgrep-woodpecker-demo>
- Start here: `scripts/demo-walkthrough.md` (10-15 min script)
- What was caught/missed and why: `docs/FINDINGS.md`
- What CE doesn't do vs. a paid tier: `docs/CE-VS-PAID.md`

## Repo layout

```
.woodpecker/            Woodpecker pipelines (main scan, rule validation/tests, offline variant)
.github/workflows/      GitHub code scanning (SARIF upload, public-repo feature)
.pre-commit-config.yaml Pre-commit hook (same rules as CI)
.semgrepignore          Scan-target exclusions
rules/                  Custom org-policy rules + their test fixtures (ruleid/ok)
terraform/, k8s/        Intentionally-vulnerable scan targets, plus *.example "fixed" references
k8s/ci-stack/           Kind cluster config + Helm values for hosting Forgejo + Woodpecker locally
                        (hosts the CI; unrelated to k8s/deployment.yaml, the scan target)
vendor/semgrep-rules/   Intentionally empty -- see docs/FINDINGS.md (licensing)
scripts/                scan-local.sh (same scans as CI) + demo-walkthrough.md
docs/                   FINDINGS.md, CE-VS-PAID.md
```

Two git branches: `main` (vulnerable samples -- pipelines fail) and `fixed` (every
planted issue remediated -- pipelines pass).

## Pinned versions

| Tool | Version |
|---|---|
| Semgrep CLI / `semgrep/semgrep` image | `1.180.0` |
| Woodpecker CLI / server / agent | `3.19.0` (≥ v3.16.0 required -- fixes CVE-2026-61549 in the Kubernetes backend) |
| `semgrep/pre-commit` hook | `v1.180.0` |
| `github/codeql-action/upload-sarif` | `v4` |
| kind | `0.33.0` |
| kubectl | `v1.37.0` |
| Helm | `v4.2.4` |

## Quick start

```bash
pipx install semgrep==1.180.0   # or: brew install semgrep
./scripts/scan-local.sh         # runs the same scans CI does
```

## Status of each phase

- **Phase 1 (samples, custom rules, local scans):** done. See `docs/FINDINGS.md`.
- **Phase 2 (Woodpecker pipeline via `woodpecker-cli exec`):** done. Pipeline fails
  on `main`, passes on `fixed`. Diff-aware scanning and severity gating both
  verified locally (`docs/FINDINGS.md`).
- **Phase 3 (Forgejo + Woodpecker hosted on a local kind cluster):** **blocked**,
  not a design problem -- the development machine used to build this currently
  can't pull fresh Docker images at all (colima VM networking times out on every
  new pull, even though some older images were cached from before; looks like
  corporate VPN/network egress filtering, confirmed by testing raw-IP connectivity
  from the host itself, which also times out). This blocks every image/chart pull
  Phase 3 needs (kind node image already cached from prior work, but ingress-nginx,
  Forgejo, and the Woodpecker Helm charts are not). `k8s/ci-stack/` holds the kind
  config and Helm values prepared and ready to run once network access is
  restored; see `docs/FINDINGS.md` for the exact retry steps.
- **Phase 4 (GitHub code scanning, fixed branch, offline rules, pre-commit, docs):**
  done. See `docs/FINDINGS.md` for each feature's proof.

## A note on how pipelines were tested locally without network

`.woodpecker/semgrep.yaml` and `.woodpecker/semgrep-custom.yaml` are the real,
correct pipeline definitions (container-image steps) -- that's what a working
Woodpecker agent runs. To validate pipeline *logic* (step ordering, `when:`
conditions, exit codes) in this network-constrained environment, a temporary copy
with `image: semgrep/semgrep:1.180.0` swapped to `image: bash` was run via
`woodpecker-cli exec --backend-engine local`, which executes `commands:` directly
against the host's natively-installed `semgrep` (same `1.180.0`) instead of in a
container. That substitution was never committed -- it's a local-only testing
workaround, documented here and in `docs/FINDINGS.md` so it isn't mistaken for the
real pipeline design.

## GitHub code scanning note

Feature 4.11 is genuinely optional and only works on a **public** repo for free; a
private repo needs GitHub Code Security / Secret Protection licensed (see
`docs/CE-VS-PAID.md`). The public demo repo linked above is under the author's
personal GitHub account, not an org, specifically to keep this sample content
(even though entirely fake) separate from any organization's name.
