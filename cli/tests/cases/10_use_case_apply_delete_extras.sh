#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/helpers.sh"
OUT="${SANDBOX}/out_uc_apply.txt"
RC=$(run_cli_rc "${OUT}" --dry-run use-case compliance --version 0.8.6 --apply ./extras/extra.yaml)
assert_ok "${RC}"
assert_contains "${OUT}" "apply -f .*(0\.8\.6/(use[_-]cases)|(use[_-]cases)/0\.8\.6)/compliance/otel\.yaml"
assert_contains "${OUT}" "apply -f .*(0\.8\.6/(use[_-]cases)|(use[_-]cases)/0\.8\.6)/compliance/hub\.yaml"
grep -E -q "apply -f .*extras/extra.yaml" "${OUT}"
