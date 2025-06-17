#!/usr/bin/env bash
set -euo pipefail

# ────────────────────────────────────────────────────────────────
# Configurable settings (can be overridden via environment)
# ────────────────────────────────────────────────────────────────
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-mdai}"
NAMESPACE="${NAMESPACE:-mdai}"
HELM_REPO_URL="https://charts.mydecisive.ai"
HELM_CHART_NAME="mdai-hub"
HELM_CHART_VERSION="${HELM_CHART_VERSION:-v0.8.0-dev}"
CERT_MANAGER_URL="https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml"

# ────────────────────────────────────────────────────────────────
# Functions
# ────────────────────────────────────────────────────────────────

ensure_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ Required command '$1' not found. Please install it and re-run."
    exit 1
  fi
}

create_cluster() {
  echo "🧪 MDAI Quickstart: Local Kind cluster setup with Helm install"
  ensure_command docker
  ensure_command kind
  ensure_command kubectl
  ensure_command helm

  if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
  fi

  if kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}\$"; then
    echo "🔁 Kind cluster '${KIND_CLUSTER_NAME}' already exists. Skipping creation."
  else
    echo "🔧 Creating Kind cluster '${KIND_CLUSTER_NAME}'..."
    kind create cluster -q --name "${KIND_CLUSTER_NAME}"
  fi

  echo "🔐 Installing Cert‑Manager..."
  kubectl apply -f "${CERT_MANAGER_URL}" > /dev/null

  echo "⏳ Waiting for cert-manager webhook to be ready..."
  kubectl wait deployment cert-manager-webhook \
    --namespace cert-manager \
    --for=condition=Available=True \
    --timeout=120s > /dev/null

  echo "🚀 Installing MDAI Helm chart '${HELM_CHART_NAME}'..."
  helm upgrade --install mdai "${HELM_CHART_NAME}" \
    --repo "${HELM_REPO_URL}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --version "${HELM_CHART_VERSION}" \
    --cleanup-on-fail >/dev/null 2>&1

  echo "✅ MDAI Quickstart complete! Cluster: '${KIND_CLUSTER_NAME}', Namespace: '${NAMESPACE}'"
}

delete() {
  echo "🧨 Deleting Kind cluster '${KIND_CLUSTER_NAME}'..."
  kind delete cluster --name "${KIND_CLUSTER_NAME}"
  echo "🧼 Clean-up complete."
}


# ────────────────────────────────────────────────────────────────
# Entrypoint
# ────────────────────────────────────────────────────────────────

main() {
  case "${1:-}" in
    install)
      create_cluster
      ;;
    delete)
      delete_cluster
      ;;
    *)
      echo "Usage: $0 {install|delete}"
      exit 1
      ;;
  esac
}

main "$@"
