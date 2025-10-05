#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/../tests/helpers.sh" 2>/dev/null || source "${ROOT}/helpers.sh"
OUT="${SANDBOX}/c10.txt"
RC=$(run_cli_rc "${OUT}" --dry-run report --format table)
assert_ok "${RC}"
