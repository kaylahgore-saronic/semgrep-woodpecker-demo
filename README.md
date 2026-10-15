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
- **Phase 3 (Forgejo + Woodpecker triggering real builds on push and PR):** **done**,
  via a different hosting mechanism than originally planned. `docker-compose.yaml`
  is written and ready (see below), but Docker image pulls never became available
  in the development environment -- every network fix attempted (VPN disconnect,
  colima's `--network-address`/`--network-mode bridged`) made no difference (see
  `docs/FINDINGS.md`). Rather than leave Phase 3 unverified, Forgejo and Woodpecker
  were run as **native macOS processes** instead: Forgejo via its official Homebrew
  formula (a real prebuilt binary), and `woodpecker-server`/`woodpecker-agent`
  **built from source** with Go (both only need plain HTTPS to GitHub/the Go module
  proxy, which work fine on this network) with the agent's `local` backend running
  pipeline steps as host processes. The entire OAuth app registration and login
  flow was automated via curl against Forgejo's and Woodpecker's own APIs -- no
  browser needed. This produced a **fully real, webhook-triggered, end-to-end
  proof**:
  - A real `git push` to the local Forgejo instance fired a real webhook, which a
    real Woodpecker agent picked up and ran -- failing exactly as expected on the
    vulnerable samples.
  - A real pull request (opened via Forgejo's API) triggered a real
    `pull_request`-event pipeline. This surfaced and fixed a genuine bug: Woodpecker's
    built-in clone step only shallow-fetches the PR commit itself (depth 1, no
    parent history), so `git merge-base` against the target branch could never
    find a common ancestor -- the diff-aware step silently skipped every time on a
    real PR. Fixed by unshallowing first (now in `.woodpecker/semgrep.yaml`).
  - With that fix, a second real PR adding one new issue correctly showed exactly
    **1 new finding** (ignoring 13 pre-existing legacy ones); a third real PR with
    no new issues correctly showed **0 findings** and passed, despite those same
    legacy findings still existing in a full scan. Both the "fails on a new issue"
    and "passes despite legacy issues" halves of the PR-diff-aware acceptance
    criterion are now proven against a live forge, not a push-event simulation.
  - Full details, exact commands, and log excerpts are in `docs/FINDINGS.md`.
  - **`docker-compose.yaml` remains the intended/documented hosting mechanism** --
    it's written, syntax-validated, and ready to use once Docker image pulls work
    in whatever environment runs this next. The native-process path above was a
    one-time, local verification exercise, not a replacement for it.
- **Phase 4 (GitHub code scanning, fixed branch, offline rules, pre-commit, docs):**
  done. See `docs/FINDINGS.md` for each feature's proof.

## A note on how pipelines were tested locally without network

`.woodpecker/semgrep.yaml`, `.woodpecker/semgrep-custom.yaml`, and
`.woodpecker/semgrep-offline.yaml` are the real, correct pipeline definitions
(container-image steps) -- that's what a working Woodpecker agent runs, and what
`docker-compose.yaml` hosts. Because Docker image pulls were never available in
this environment, verifying them used **temporary copies** with `image:
semgrep/semgrep:1.180.0` swapped to `image: bash`, run two ways:

1. `woodpecker-cli exec --backend-engine local` (Phase 2) -- no server at all,
   purely local simulation.
2. A real, natively-built Woodpecker server + agent, with the agent's `local`
   backend (Phase 3) -- full webhook/OAuth/PR flow for real, against real Forgejo
   repos and pull requests.

Both substitutions were local-only testing workarounds, never committed -- the
repo's actual pipeline files always reference the real container images. One real
bug was found and fixed this way regardless of the `image:` swap (the diff-aware
clone-depth issue above), since that bug lived in the pipeline's shell logic, not
in how the step's image was invoked.

## GitHub code scanning note

Feature 4.11 is genuinely optional and only works on a **public** repo for free; a
private repo needs GitHub Code Security / Secret Protection licensed (see
`docs/CE-VS-PAID.md`). The public demo repo linked above is under the author's
personal GitHub account, not an org, specifically to keep this sample content
(even though entirely fake) separate from any organization's name.
