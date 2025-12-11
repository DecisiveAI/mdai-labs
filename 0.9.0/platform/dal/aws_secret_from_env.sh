#!/usr/bin/env bash
set -euo pipefail

# ─── Load .env ────────────────────────────────────────────────────────────────
if [[ -f .env ]]; then
  # Export every var in .env into the environment
  set -o allexport
  source .env
  set +o allexport
else
  echo "❌ .env file not found in $(pwd)"
  exit 1
fi

# ─── Validate ────────────────────────────────────────────────────────────────
: "${AWS_ACCESS_KEY_ID:?Please set AWS_ACCESS_KEY_ID in .env}"
: "${AWS_SECRET_ACCESS_KEY:?Please set AWS_SECRET_ACCESS_KEY in .env}"

# ─── Apply the Secret ────────────────────────────────────────────────────────
kubectl apply -n mdai -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
  namespace: mdai
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
  AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
EOF

echo "✅ Secret/aws-credentials applied in namespace mdai"