# What's not available in Semgrep Community Edition (CE)

This demo only uses the free, open-source Semgrep CLI with no `semgrep login` /
AppSec Platform account. Everything in this repo works without one. For context,
here's what a paid Semgrep tier (Semgrep Code / the AppSec Platform) adds on top,
and what GitHub-side features this demo's optional feature 4.11 runs into.

## Not in CE

- **Cross-file / cross-function dataflow analysis.** CE's engine matches patterns
  within a single file (with some intraprocedural reasoning); tracing a tainted
  value across file or function boundaries is a Semgrep Code (paid) capability.
- **A dashboard / fleet-wide view.** CE has no hosted UI for tracking findings
  across repos over time, trends, or SLA tracking -- every run in this demo is
  stateless (reads files, prints/exits, nothing persisted anywhere).
- **Triage workflows.** No "mark as false positive / won't fix / accepted risk"
  state that persists across runs; every scan starts from zero knowledge of past
  decisions (other than what's encoded in-repo via `# nosemgrep` and `.semgrepignore`,
  both of which this demo uses and documents in `docs/FINDINGS.md`).
- **Automatic PR comments.** CE doesn't post inline PR review comments with
  findings; it only exits non-zero and prints to the build log (what Woodpecker
  shows). A paid platform integration adds this directly on the PR diff.
- **Semgrep Supply Chain** (dependency/SCA scanning, reachability analysis for
  vulnerable dependencies) -- out of scope per the original spec, not evaluated
  here.
- **"Pro rules"** -- Semgrep's paid tiers ship additional, higher-precision rules
  (including some cross-file ones) not in the free Registry packs used here
  (`p/terraform`, `p/kubernetes`, `p/secrets`, `p/security-audit`, `p/default`).
- **`semgrep ci`'s policy-based blocking.** The `semgrep ci` subcommand is built
  around a logged-in AppSec Platform project with configurable blocking policies;
  without a login it doesn't reliably exit non-zero on findings the way `semgrep
  scan --error` does, which is why this repo uses `semgrep scan --error` throughout
  instead (see `docs/FINDINGS.md`).

## GitHub-side: code scanning pricing (relevant to feature 4.11)

Not a Semgrep limitation, but adjacent and worth noting since feature 4.11 pushes
to GitHub: **public repos get the Security → Code scanning tab for free** (this demo
uses a public repo specifically so this works without a paid add-on). For **private**
repos, GitHub unbundled "Advanced Security" in April 2025 into two separately
purchasable products -- **GitHub Code Security** (~$30/active committer/month, code
scanning + Copilot Autofix) and **GitHub Secret Protection** (~$19/active
committer/month) -- previously bundled and gated behind a GitHub Enterprise plan;
now purchasable standalone, pay-as-you-go, even on a Team plan. If this demo's
GitHub Actions workflow were pointed at a private repo instead, the SARIF upload
step would still run, but no alerts would appear under Security without one of
these add-ons licensed.
