# Phase 3: Forgejo + Woodpecker on local kind

**Status: prepared but not yet run end-to-end.** The machine used to build this repo
currently can't pull fresh Docker images (see `docs/FINDINGS.md` and the repo
README). Once network access is confirmed (`docker pull alpine:3.20` succeeds),
run through this checklist, bailing out to the `woodpecker-cli exec` demo
(`scripts/demo-walkthrough.md` step 5) if the OAuth/ingress step stalls past ~90
minutes.

1. `kind create cluster --name semgrep-demo --config k8s/ci-stack/kind-config.yaml`
2. Install the **kind-specific** ingress-nginx manifest (not the generic cloud one --
   check <https://kind.sigs.k8s.io/docs/user/ingress/> for the current URL) and wait
   for its pods to be ready.
3. Add `127.0.0.1 forgejo.localtest.me woodpecker.localtest.me` to `/etc/hosts`
   (`*.localtest.me` already resolves to `127.0.0.1` publicly, but a local override
   is more reliable offline).
4. `helm install forgejo oci://code.forgejo.org/forgejo-helm/forgejo --namespace ci-stack --create-namespace -f k8s/ci-stack/forgejo-values.yaml --set gitea.admin.password=<generate one>`
5. Log into Forgejo at `http://forgejo.localtest.me:8080`, create an OAuth app with
   redirect URI `http://woodpecker.localtest.me:8080/authorize`.
6. Create the `woodpecker-forgejo-oauth` Secret from that OAuth app's client
   id/secret (as files, per the chart's `_FILE` convention), then:
   `helm install woodpecker woodpecker-ci/woodpecker --namespace ci-stack -f k8s/ci-stack/woodpecker-values.yaml`
7. Log into Woodpecker at `http://woodpecker.localtest.me:8080` via the Forgejo
   OAuth button, activate this repo (push it to the local Forgejo first).
8. Push a commit -- confirm the Forgejo webhook fires and a pipeline pod runs.
9. Open a PR from a branch with one new issue on top of `main`'s existing ones --
   confirm `.woodpecker/semgrep.yaml`'s `diff-aware-scan` step now has real
   `CI_COMMIT_TARGET_BRANCH`/`CI_COMMIT_PULL_REQUEST` values from Woodpecker itself
   (not simulated), and ignores the legacy findings while catching the new one.

If anything here doesn't match current chart/docs behavior, that's expected --
these files were written from research, not a verified run (see README.md's
"Status of each phase" section). Fix forward and record what changed in
`docs/FINDINGS.md`.
