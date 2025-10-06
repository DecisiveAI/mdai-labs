#!/usr/bin/env bash
set -euo pipefail

# Location of mdai.sh (adjust if different path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MDAI="${ROOT_DIR}/mdai.sh"

# Create a temp sandbox
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

echo "🧪 Using sandbox: $WORK"

mkdir -p "$WORK/bin" "$WORK/use-cases/0.8.6/compliance" "$WORK/mock-data"

# Stub kubectl & helm to avoid real cluster calls
cat >"$WORK/bin/kubectl" <<'KUB'
#!/usr/bin/env bash
echo "+ kubectl $*"
# Return success for get ns, apply, delete, wait, create, etc.
exit 0
KUB
chmod +x "$WORK/bin/kubectl"

cat >"$WORK/bin/helm" <<'HELM'
#!/usr/bin/env bash
echo "+ helm $*"
exit 0
HELM
chmod +x "$WORK/bin/helm"

export PATH="$WORK/bin:$PATH"
export NAMESPACE="mdai"
export KUBE_CONTEXT="test"
export KCTX="--context ${KUBE_CONTEXT}"
export USE_CASES_ROOT="$WORK"
export DRY_RUN=true

# Minimal manifests
cat >"$WORK/use-cases/0.8.6/compliance/otel.yaml" <<'Y1'
apiVersion: v1
kind: ConfigMap
metadata: { name: otel-cm }
data: { foo: bar }
Y1

cat >"$WORK/use-cases/0.8.6/compliance/hub.yaml" <<'Y2'
apiVersion: v1
kind: ConfigMap
metadata: { name: hub-cm }
data: { baz: qux }
Y2

cat >"$WORK/mock-data/fluentd_config.yaml" <<'Y3'
apiVersion: v1
kind: ConfigMap
metadata: { name: mock-data }
data: { key: value }
Y3

# 1) Default resolver should pick mock-data/fluentd_config.yaml
OUT1="$WORK/out1.txt"
( cd "$WORK" && bash "$MDAI" use-case compliance --version 0.8.6 ) | tee "$OUT1"
grep -q '+ kubectl .* apply -f .*use-cases/0.8.6/compliance/otel.yaml' "$OUT1"
grep -q '+ kubectl .* apply -f .*use-cases/0.8.6/compliance/hub.yaml' "$OUT1"
grep -q '+ kubectl .* apply -f .*mock-data/fluentd_config.yaml' "$OUT1"

# 2) Explicit --data override
cat >"$WORK/mock-data/custom.yaml" <<'Y4'
apiVersion: v1
kind: ConfigMap
metadata: { name: custom-data }
data: { hello: world }
Y4
OUT2="$WORK/out2.txt"
( cd "$WORK" && bash "$MDAI" use-case compliance --version 0.8.6 --data ./mock-data/custom.yaml ) | tee "$OUT2"
grep -q '+ kubectl .* apply -f .*mock-data/custom.yaml' "$OUT2"

# 3) Delete path should issue delete calls
OUT3="$WORK/out3.txt"
( cd "$WORK" && bash "$MDAI" use-case compliance --version 0.8.6 --delete ) | tee "$OUT3"
grep -q '+ kubectl .* delete -f .*use-cases/0.8.6/compliance/otel.yaml' "$OUT3"
grep -q '+ kubectl .* delete -f .*use-cases/0.8.6/compliance/hub.yaml' "$OUT3"
grep -q '+ kubectl .* delete -f .*mock-data/fluentd_config.yaml' "$OUT3"

# --- workflow directories/manifests ---
mkdir -p "$WORK/use-cases/0.8.6/compliance/basic" \
         "$WORK/use-cases/0.8.6/compliance/static" \
         "$WORK/use-cases/0.8.6/compliance/dynamic"

for wf in basic static dynamic; do
  cat >"$WORK/use-cases/0.8.6/compliance/${wf}/otel.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata: { name: otel-${wf} }
data: { type: ${wf} }
EOF

  cat >"$WORK/use-cases/0.8.6/compliance/${wf}/hub.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata: { name: hub-${wf} }
data: { type: ${wf} }
EOF
done

# 4) Workflow-specific resolver
for wf in basic static dynamic; do
  OUT="$WORK/out-${wf}.txt"
  ( cd "$WORK" && bash "$MDAI" use-case compliance --version 0.8.6 --workflow "$wf" ) | tee "$OUT"
  grep -q "+ kubectl .*apply -f .*use-cases/0.8.6/compliance/${wf}/otel.yaml" "$OUT"
  grep -q "+ kubectl .*apply -f .*use-cases/0.8.6/compliance/${wf}/hub.yaml" "$OUT"
done

echo "✅ All tests passed."
