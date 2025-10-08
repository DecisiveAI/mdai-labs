#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MDAI="${ROOT_DIR}/mdai.sh"
: "${MDAI:?expected mdai.sh next to tests/}"
chmod +x "${MDAI}" || true
failures=0
total=0
for t in "${ROOT_DIR}/tests/cases/"*.sh; do
  [[ -e "$t" ]] || continue
  total=$((total+1))
  echo "------------------------------"
  echo "▶ running ${t##*/}"
  echo "------------------------------"
  MDAI="${MDAI}" bash "$t" && echo "✅ ${t##*/} passed" || { echo "❌ ${t##*/} failed"; failures=$((failures+1)); }
done
echo
if [[ $failures -eq 0 ]]; then
  echo "🎉 All ${total} test(s) passed."
  exit 0
else
  echo "❌ ${failures}/${total} test(s) failed."
  exit 1
fi
