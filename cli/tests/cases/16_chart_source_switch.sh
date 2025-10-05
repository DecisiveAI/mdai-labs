#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/helpers.sh"
OUT="${SANDBOX}/out_repo_name.txt"
RC=$(run_cli_rc "${OUT}" --dry-run install_mdai --chart-ref "" --chart-repo https://charts.example.com --chart-name mdai-hub)
assert_ok "${RC}"
grep -E -q "--repo https://charts.example.com" "${OUT}"
