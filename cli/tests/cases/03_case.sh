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

# default MDAI path if not provided
if [[ -z "${MDAI:-}" ]]; then
  for CAND in       "${ROOT}/mdai.sh"       "${ROOT}/../mdai.sh"       "${ROOT}/../cli/mdai.sh"       "${ROOT}/../../cli/mdai.sh" ; do
    if [[ -f "$CAND" ]]; then
      MDAI="$CAND"
      break
    fi
  done
fi
: "${MDAI:?mdai.sh path not found; set MDAI or place mdai.sh in a known location}"

# Prefer a likely existing values file; fall back to mock-data
VALS="./synthetics/loggen_fluent_config.yaml"
[[ -f "${SANDBOX}/synthetics/loggen_fluent_config.yaml" ]] || VALS="./mock-data/fluentd_config.yaml"

OUT="${SANDBOX}/c03.txt"
RC=$(run_cli_rc "${OUT}" --dry-run install_mdai --chart-ref "" --chart-repo https://charts.example.com --chart-name mdai-hub --values "${VALS}" --set foo=bar)

assert_ok "${RC}"
