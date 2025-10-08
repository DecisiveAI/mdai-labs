#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/helpers.sh"
OUT="${SANDBOX}/r_table.txt"
RC=$(run_cli_rc "${OUT}" --dry-run report --format table)
assert_ok "${RC}"
OUT2="${SANDBOX}/r_json.txt"
RC2=$(run_cli_rc "${OUT2}" --dry-run report --format json)
assert_ok "${RC2}"
OUT3="${SANDBOX}/r_yaml.txt"
RC3=$(run_cli_rc "${OUT3}" --dry-run report --format yaml)
assert_ok "${RC3}"
