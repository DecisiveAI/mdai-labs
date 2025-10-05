#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/../tests/helpers.sh" 2>/dev/null || source "${ROOT}/helpers.sh"
MAN="${SANDBOX}/tmp.yaml"; echo "apiVersion: v1" > "${MAN}"
OUT="${SANDBOX}/c09.txt"
RC=$(run_cli_rc "${OUT}" --dry-run apply "${MAN}")
assert_ok "${RC}"
grep -E -q "apply -f .*tmp\.yaml" "${OUT}"
