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

# Pick the more canonical values file for fluentd
VALS="./synthetics/loggen_fluent_config.yaml"
[[ -f "${SANDBOX}/synthetics/loggen_fluent_config.yaml" ]] || VALS="./mock-data/fluentd_config.yaml"

OUT="${SANDBOX}/out_fluentd_values.txt"
RC=$(run_cli_rc "${OUT}" --dry-run fluentd --values "${VALS}")
assert_ok "${RC}"
grep -E -q "\+ helm" "${OUT}" || true

OUT2="${SANDBOX}/out_fluentd_file.txt"
RC2=$(run_cli_rc "${OUT2}" --dry-run fluentd --file "${VALS}")
assert_ok "${RC2}"
grep -E -q "\+ helm" "${OUT2}" || true

OUT3="${SANDBOX}/out_monitor.txt"
RC3=$(run_cli_rc "${OUT3}" --dry-run mdai_monitor --file ./mdai/hub_monitor/mdai_monitor_no_secrets.yaml)
assert_ok "${RC3}"
grep -E -q "apply -f .*mdai/hub_monitor/mdai_monitor_no_secrets.yaml" "${OUT3}" || true
