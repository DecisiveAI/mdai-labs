#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# --- locate helpers robustly ---
HELPERS_CANDIDATES=(
  "${ROOT}/helpers.sh"
  "${ROOT}/../tests/helpers.sh"
  "${ROOT}/tests/helpers.sh"
  "${ROOT}/../helpers.sh"
)
__helpers_found=0
for H in "${HELPERS_CANDIDATES[@]}"; do
  if [[ -f "$H" ]]; then
    # shellcheck source=/dev/null
    source "$H"
    __helpers_found=1
    break
  fi
done
if [[ $__helpers_found -eq 0 ]]; then
  echo "helpers.sh not found (searched: ${HELPERS_CANDIDATES[*]})" >&2
  exit 2
fi

# --- default MDAI path if not set by runner ---
if [[ -z "${MDAI:-}" ]]; then
  # common locations relative to this test file
  for CAND in \
      "${ROOT}/mdai.sh" \
      "${ROOT}/../mdai.sh" \
      "${ROOT}/../cli/mdai.sh" \
      "${ROOT}/../../cli/mdai.sh" ; do
    if [[ -f "$CAND" ]]; then
      MDAI="$CAND"
      break
    fi
  done
fi
: "${MDAI:?mdai.sh path not found; set MDAI or place mdai.sh in a known location}"

OUT="${SANDBOX}/out_help.txt"; RC=$(run_cli_rc "${OUT}" --help); assert_ok "${RC}"
OUT2="${SANDBOX}/out_unknown.txt"; RC2=$(run_cli_rc "${OUT2}" --dry-run __definitely_not_a_command__); assert_not_ok "${RC2}"; grep -q "Unknown flag or command" "${OUT2}"
