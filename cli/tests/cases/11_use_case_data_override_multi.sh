#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/helpers.sh"
echo 'apiVersion: v1
kind: ConfigMap
metadata: { name: custom }
' > "${SANDBOX}/mock-data/custom.yaml"
OUT="${SANDBOX}/out_uc_data_override.txt"
RC=$(run_cli_rc "${OUT}" --dry-run use-case pii --version 0.8.6 --data ./mock-data/custom.yaml)
assert_ok "${RC}"
grep -E -q "apply -f .*mock-data/custom.yaml" "${OUT}"
