#!/usr/bin/env bash
set -euo pipefail
fail() { echo "❌  $*" >&2; exit 1; }
assert_ok() { [[ "${1:-0}" -eq 0 ]] || fail "expected exit 0, got $1"; }
assert_not_ok() { [[ "${1:-1}" -ne 0 ]] || fail "expected non-zero exit, got 0"; }
assert_contains() { grep -E -q -- "${2}" "${1}" || fail "expected '${2}' in ${1}"; }
: "${MDAI:?set MDAI to path of mdai.sh}"
SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
export PATH="${SANDBOX}/bin:${PATH}"
mkdir -p "${SANDBOX}/bin" \
         "${SANDBOX}/0.8.6/use_cases/compliance" \
         "${SANDBOX}/0.8.6/use_cases/data_filtration" \
         "${SANDBOX}/0.8.6/use_cases/pii" \
         "${SANDBOX}/mdai/hub" \
         "${SANDBOX}/mdai/hub_monitor" \
         "${SANDBOX}/otel" \
         "${SANDBOX}/mock-data" \
         "${SANDBOX}/extras" \
         "${SANDBOX}/synthetics"
cat >"${SANDBOX}/bin/kubectl" <<'KUB'
#!/usr/bin/env bash
echo "+ kubectl $*"
exit 0
KUB
chmod +x "${SANDBOX}/bin/kubectl"
cat >"${SANDBOX}/bin/helm" <<'HELM'
#!/usr/bin/env bash
echo "+ helm $*"
exit 0
HELM
chmod +x "${SANDBOX}/bin/helm"
cat >"${SANDBOX}/bin/yq" <<'YQ'
#!/usr/bin/env bash
cat /dev/stdin 2>/dev/null || true
exit 0
YQ
chmod +x "${SANDBOX}/bin/yq"
cat >"${SANDBOX}/bin/jq" <<'JQ'
#!/usr/bin/env bash
cat /dev/stdin 2>/dev/null || true
exit 0
JQ
chmod +x "${SANDBOX}/bin/jq"
cat >"${SANDBOX}/bin/docker" <<'DOCK'
#!/usr/bin/env bash
echo "+ docker $*"
exit 0
DOCK
chmod +x "${SANDBOX}/bin/docker"
cat >"${SANDBOX}/bin/kind" <<'KIND'
#!/usr/bin/env bash
echo "+ kind $*"
exit 0
KIND
chmod +x "${SANDBOX}/bin/kind"
export DRY_RUN=true
export NAMESPACE="mdai"
export KUBE_CONTEXT="test"
export KCTX="--context ${KUBE_CONTEXT}"
export USE_CASES_ROOT="${SANDBOX}"
export MDAI_PATH="${SANDBOX}/mdai"
export OTEL_PATH="${SANDBOX}/otel"
cat >"${SANDBOX}/0.8.6/use_cases/compliance/otel.yaml" <<'Y1'
apiVersion: v1
kind: ConfigMap
metadata: { name: otel-compliance }
Y1
cat >"${SANDBOX}/0.8.6/use_cases/compliance/hub.yaml" <<'Y2'
apiVersion: v1
kind: ConfigMap
metadata: { name: hub-compliance }
Y2
cat >"${SANDBOX}/0.8.6/use_cases/data_filtration/otel.yaml" <<'Y3'
apiVersion: v1
kind: ConfigMap
metadata: { name: otel-df }
Y3
cat >"${SANDBOX}/0.8.6/use_cases/data_filtration/hub.yaml" <<'Y4'
apiVersion: v1
kind: ConfigMap
metadata: { name: hub-df }
Y4
cat >"${SANDBOX}/0.8.6/use_cases/pii/otel.yaml" <<'Y5'
apiVersion: v1
kind: ConfigMap
metadata: { name: otel-pii }
Y5
cat >"${SANDBOX}/0.8.6/use_cases/pii/hub.yaml" <<'Y6'
apiVersion: v1
kind: ConfigMap
metadata: { name: hub-pii }
Y6
cat >"${SANDBOX}/mock-data/fluentd_config.yaml" <<'MD1'
apiVersion: v1
kind: ConfigMap
metadata: { name: mock-data }
MD1
cat >"${SANDBOX}/synthetics/loggen_services.yaml" <<'LG1'
apiVersion: v1
kind: ConfigMap
metadata: { name: loggen-services }
LG1
cat >"${SANDBOX}/synthetics/loggen_service_noisy.yaml" <<'LG2'
apiVersion: v1
kind: ConfigMap
metadata: { name: loggen-noisy }
LG2
cat >"${SANDBOX}/synthetics/loggen_service_xtra_noisy.yaml" <<'LG3'
apiVersion: v1
kind: ConfigMap
metadata: { name: loggen-xtra }
LG3
cat >"${SANDBOX}/mdai/hub/hub_ref.yaml" <<'H1'
apiVersion: v1
kind: ConfigMap
metadata: { name: hub-ref }
H1
cat >"${SANDBOX}/otel/otel_ref.yaml" <<'O1'
apiVersion: v1
kind: ConfigMap
metadata: { name: otel-ref }
O1
cat >"${SANDBOX}/mdai/hub_monitor/mdai_monitor_no_secrets.yaml" <<'M1'
apiVersion: v1
kind: ConfigMap
metadata: { name: monitor }
M1
cat >"${SANDBOX}/aws_secret.sh" <<'AWS'
#!/usr/bin/env bash
echo "creating secret (stub)"
AWS
chmod +x "${SANDBOX}/aws_secret.sh"
run_cli_rc() {
  local out="$1"; shift
  set +e
  ( cd "${SANDBOX}" && bash "${MDAI}" "$@" ) >"${out}" 2>&1
  local rc=$?
  set -e
  echo "${rc}"
}
