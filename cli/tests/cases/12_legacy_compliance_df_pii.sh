#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/helpers.sh"
OUT="${SANDBOX}/out_legacy_compliance.txt"
RC=$(run_cli_rc "${OUT}" --dry-run compliance --version 0.8.6)
assert_ok "${RC}"
assert_contains "${OUT}" "apply -f .*(0\.8\.6/(use[_-]cases)|(use[_-]cases)/0\.8\.6)/compliance/otel\.yaml"
OUT2="${SANDBOX}/out_legacy_df.txt"
RC2=$(run_cli_rc "${OUT2}" --dry-run df --version 0.8.6)
assert_ok "${RC2}"
assert_contains "${OUT2}" "apply -f .*(0\.8\.6/(use[_-]cases)|(use[_-]cases)/0\.8\.6)/data_filtration/otel.yaml"
OUT3="${SANDBOX}/out_legacy_pii.txt"
RC3=$(run_cli_rc "${OUT3}" --dry-run pii --version 0.8.6)
assert_ok "${RC3}"
assert_contains "${OUT3}" "apply -f .*(0\.8\.6/(use[_-]cases)|(use[_-]cases)/0\.8\.6)/pii/otel.yaml"
