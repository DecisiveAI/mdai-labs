#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Try both helper locations to support different layouts
source "${ROOT}/../tests/helpers.sh" 2>/dev/null || source "${ROOT}/helpers.sh"

OUT="${SANDBOX}/c01.txt"
RC=$(run_cli_rc "${OUT}" --dry-run __definitely_not_a_command__)

# Must fail (unknown command/flag should be non-zero)
assert_not_ok "${RC}"

# Optional note: show first lines of output for visibility, but do not fail if message wording differs
head -n 40 "${OUT}" || true
