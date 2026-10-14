#!/usr/bin/env bash
# Runs the same Semgrep scans locally that the Woodpecker pipeline runs in CI.
# Exit code reflects only the "blocking" steps (Terraform, Kubernetes, custom rules).
set -uo pipefail

cd "$(dirname "$0")/.."

SEMGREP_IMAGE="${SEMGREP_IMAGE:-semgrep/semgrep:1.180.0}"
USE_DOCKER="${USE_DOCKER:-0}"

run_semgrep() {
  if [ "$USE_DOCKER" = "1" ]; then
    docker run --rm -v "$PWD:/src" -w /src "$SEMGREP_IMAGE" semgrep "$@"
  else
    semgrep "$@"
  fi
}

status=0

echo "== [1/6] Terraform scan (blocking: p/terraform) =="
run_semgrep scan --config p/terraform --severity ERROR --severity WARNING --error --metrics=off terraform/ || status=1

echo
echo "== [2/6] Kubernetes scan (blocking: p/kubernetes) =="
run_semgrep scan --config p/kubernetes --severity ERROR --severity WARNING --error --metrics=off k8s/deployment.yaml || status=1

echo
echo "== [3/6] Custom org rules (blocking: rules/) =="
run_semgrep scan --config rules/ --error --metrics=off terraform/ k8s/deployment.yaml || status=1

echo
echo "== [4/6] Secrets + security-audit packs (reporting only, does not fail the build) =="
run_semgrep scan --config p/secrets --config p/security-audit --metrics=off . || true

echo
echo "== [5/6] SARIF + JSON output =="
run_semgrep scan --config p/terraform --config p/kubernetes --config rules/ \
  --json-output=semgrep.json --sarif-output=semgrep.sarif --metrics=off terraform/ k8s/deployment.yaml >/dev/null || true

echo
echo "== [6/6] Summary (by severity) =="
if [ -f semgrep.json ]; then
  jq -r '.results | group_by(.extra.severity) | map({severity: .[0].extra.severity, count: length}) | .[] | "\(.severity): \(.count)"' semgrep.json
fi

echo
if [ "$status" -eq 0 ]; then
  echo "Result: PASS (no blocking findings)"
else
  echo "Result: FAIL (blocking findings present)"
fi
exit "$status"
