#!/usr/bin/env bash
set -euo pipefail

KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-mdai}"
NAMESPACE="${NAMESPACE:-mdai}"
HELM_REPO_URL="https://charts.mydecisive.ai"
HELM_CHART_NAME="mdai-hub"
HELM_CHART_VERSION="${HELM_CHART_VERSION:-v0.8.0-dev}"
CERT_MANAGER_URL="https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml"

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

  echo "✅ MDAI cluster installed!"
}

upgrade_mdai() {
  echo "🐙 Upgrade MDAI '${HELM_CHART_NAME}'..."
  helm upgrade --install mdai "${HELM_CHART_NAME}" \
    --repo "${HELM_REPO_URL}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --version "${HELM_CHART_VERSION}" \
    --cleanup-on-fail

  echo "✅ MDAI cluster upgraded!"
}

deploy_log_generators() {
  echo "🧪 Deploying synthetic log generators..."
  ensure_command kubectl

  if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
    echo "📁 Namespace '${NAMESPACE}' does not exist. Creating it..."
    kubectl create namespace "${NAMESPACE}"
  fi

  kubectl apply -f ./synthetics/loggen_service_xtra_noisy.yaml -n "${NAMESPACE}" || echo "⚠️ Failed to apply loggen_service_xtra_noisy"
  kubectl apply -f ./synthetics/loggen_service_noisy.yaml -n "${NAMESPACE}" || echo "⚠️ Failed to apply loggen_service_noisy"
  kubectl apply -f ./synthetics/loggen_services.yaml -n "${NAMESPACE}" || echo "⚠️ Failed to apply loggen_services"
  echo "✅ Log generators deployed"
}

install_hub() {
  echo "🧠 Installing MDAI Smart Telemetry Hub..."
  kubectl apply -f ./mdai/hub/hub_ref.yaml -n "${NAMESPACE}"
  echo "✅ MDAI Hub deployed"
}

install_collector() {
  echo "📥 Installing OpenTelemetry Collector..."
  kubectl apply -f ./otel/otel_ref.yaml -n "${NAMESPACE}"
  echo "✅ OTel Collector deployed"
}

forward_logs() {
  echo "🔁 Forwarding logs with Fluentd config..."
  helm upgrade --install fluent fluentd \
    --repo https://fluent.github.io/helm-charts \
    -f ./synthetics/loggen_fluent_config.yaml
  echo "✅ Fluentd forwarding configured"
}

aws_secret_from_env() {
  echo "🔑 Applying AWS credentials secret from environment..."
  ./aws/aws_secret_from_env.sh || {
    echo "❌ Failed to apply AWS secret. Ensure the script and env vars are configured."
    exit 1
  }
  echo "✅ AWS secret applied"
}

apply_collector_with_keys() {
  echo "🔐 Deploying MDAI Collector with updated keys..."
  kubectl apply -f ./mdai/hub_monitor/mdai_monitor_no_secrets.yaml -n "${NAMESPACE}"
  echo "✅ MDAI Collector with updated keys deployed"
}

compliance() {
  echo "⚖️ Deploying Compliance configurations..."
  kubectl apply -f ./otel/otel_compliance.yaml -n "${NAMESPACE}"
  kubectl apply -f ./mdai/hub/hub_compliance.yaml -n "${NAMESPACE}"
  echo "✅ Compliance configurations deployed"
}

dynamic_filtration() {
  echo "📉 Deploying dynamic filtration configurations..."
  kubectl apply -f ./otel/otel_dynamic_filtration.yaml -n "${NAMESPACE}"
  kubectl apply -f ./mdai/hub/hub_dynamic_filtration.yaml -n "${NAMESPACE}"
  echo "✅ Dynamic filtration configurations deployed"
}

pii() {
  echo "🧼 Deploying PII configurations..."
  kubectl apply -f ./otel/otel_pii.yaml -n "${NAMESPACE}"
  kubectl apply -f ./mdai/hub/hub_pii.yaml -n "${NAMESPACE}"
  echo "✅ PII configurations deployed"
}

# note this only works for the default install
clean_configs() {
  echo "🔥 Deleting all resources in namespace '${NAMESPACE}'..."
  ensure_command kubectl
  ensure_command helm

  if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
    echo "⚠️ Namespace '${NAMESPACE}' does not exist. Nothing to delete."
    return
  fi


  kubectl delete -f ./synthetics/loggen_service_xtra_noisy.yaml -n "${NAMESPACE}"
  kubectl delete -f ./synthetics/loggen_service_noisy.yaml -n "${NAMESPACE}"
  kubectl delete -f ./synthetics/loggen_services.yaml -n "${NAMESPACE}"
  kubectl delete -f ./otel/0.8/otel_ref.yaml -n "${NAMESPACE}"
  kubectl delete -f ./mdai/hub/0.8/hub_ref.yaml -n "${NAMESPACE}"
  helm uninstall fluentd

  echo "✅ Namespace '${NAMESPACE}' cleaned (resources deleted, namespace remains)"
}


delete_cluster() {
  echo "🧨 Deleting Kind cluster '${KIND_CLUSTER_NAME}'..."
  kind delete cluster --name "${KIND_CLUSTER_NAME}"
  echo "🧼 Clean-up complete."
}

main() {
  case "${1:-}" in
    install)   create_cluster ;;
    upgrade)   upgrade_mdai;;
    clean)     clean_configs ;;
    delete)    delete_cluster ;;
    logs)      deploy_log_generators ;;
    hub)       install_hub ;;
    collector) install_collector ;;
    fluentd)   forward_logs ;;
    aws_secret) aws_secret_from_env ;;
    mdai_monitor) apply_collector_with_keys ;;
    compliance) compliance ;;
    df) dynamic_filtration ;;
    pii) pii ;;
    *)
      echo "Usage: $0 {install|upgrade|clean|delete|logs|hub|collector|fluentd|aws_secret|mdai_monitor|compliance|df|pii}"
      exit 1
      ;;
  esac
}

main "$@"
