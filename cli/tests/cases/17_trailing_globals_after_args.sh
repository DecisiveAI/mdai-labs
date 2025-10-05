#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/helpers.sh"
OUT="${SANDBOX}/out_trailing_globals.txt"
RC=$(run_cli_rc "${OUT}" --dry-run install_mdai --values ./mock-data/fluentd_config.yaml --set foo=bar)
assert_ok "${RC}"
