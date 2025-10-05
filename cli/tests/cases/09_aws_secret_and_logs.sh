#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/helpers.sh"
OUT="${SANDBOX}/out_secret.txt"
RC=$(run_cli_rc "${OUT}" --dry-run aws_secret --script ./aws_secret.sh)
assert_ok "${RC}"
grep -E -q "\+ ./aws_secret.sh" "${OUT}"
OUT2="${SANDBOX}/out_logs.txt"
RC2=$(run_cli_rc "${OUT2}" --dry-run logs)
assert_ok "${RC2}"
grep -E -q "loggen_service_xtra_noisy.yaml" "${OUT2}"
grep -E -q "loggen_service_noisy.yaml" "${OUT2}"
grep -E -q "loggen_services.yaml" "${OUT2}"
