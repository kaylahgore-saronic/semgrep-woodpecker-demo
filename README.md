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
docker-compose.yaml     Forgejo + Woodpecker server + agent, hosting the CI locally
                        (unrelated to k8s/deployment.yaml, the scan target)
.env.example            Template for docker-compose's secrets (copy to .env, never commit .env)
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
| Woodpecker CLI / server / agent | `3.19.0` (≥ v3.16.0 required -- fixes CVE-2026-61549) |
| Forgejo (`codeberg.org/forgejo/forgejo`) | `16` |
| `semgrep/pre-commit` hook | `v1.180.0` |
| `github/codeql-action/upload-sarif` | `v4` |

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
- **Phase 3 (Forgejo + Woodpecker hosted via `docker-compose`):** **blocked**, not a
  design problem. `docker-compose.yaml` is written against current upstream docs,
  syntax-validated (`docker-compose config` succeeds), but every attempt to
  actually bring up a service hangs indefinitely pulling its image. The
  development machine used to build this currently can't get fresh Docker images
  into its colima VM at all, under any configuration tried:
  - A plain `docker pull` of any image not already cached locally times out at the
    TCP level (`dial tcp ... i/o timeout`), while the exact same host machine
    reaches the same registry/IP over its real network interface just fine.
  - Disconnecting the corporate VPN (GlobalProtect) made no difference -- ruling
    that out as the sole cause.
  - `colima start --network-address` and `--network-mode bridged` (different VM
    networking modes) made no difference either.
  - From inside the VM itself (`colima ssh`), *nothing* is reachable -- not even a
    raw IP, with or without VPN connected.
  - This machine also runs CrowdStrike Falcon (EDR, installed as a macOS system
    extension with its own network-filtering driver) -- the most likely remaining
    candidate, since Falcon-style tools commonly block traffic from VM/bridged
    interfaces by design, independent of VPN state.
  - An alternative that avoids the VM/Docker entirely (installing `forgejo` via
    Homebrew -- a real prebuilt macOS binary -- and building `woodpecker-server`/
    `agent` from source with Go) was scoped but not attempted; real but unverified
    build risk, parked per the author's direction to keep the Docker/compose path
    as primary.
  - **To retry:** confirm `docker pull alpine:3.20` succeeds first (fast, cheap
    check), then `cp .env.example .env`, fill in `WOODPECKER_AGENT_SECRET`
    (`openssl rand -hex 32`), run `docker-compose up -d forgejo`, and follow the
    setup steps documented at the top of `docker-compose.yaml`.
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
