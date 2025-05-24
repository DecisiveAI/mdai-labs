# Makefile for deploying MDAI stack with Kind, Helm, and K8s configs

CLUSTER_NAME ?= mdai
CERT_MANAGER_URL ?= https://github.com/cert-manager/cert-manager/releases/download/v1.17.0/cert-manager.yaml
MDAI_REPO ?= https://decisiveai.github.io/mdai-helm-charts

# Acceptable overrides from CLI: e.g., make hub-config HUB_CONFIG=somefile.yaml
FLUENT ?= $(FLUENT_CONFIG)
HUB ?= $(HUB_CONFIG)
OTEL ?= $(OTEL_CONFIG)

.PHONY: all cluster cert-manager helm-repo mdai-deploy hub-config otel-config fluentd postcheck clean

all: cluster cert-manager helm-repo mdai-deploy hub-config otel-config fluentd postcheck

cluster:
	@echo "🧱 Creating Kind cluster: $(CLUSTER_NAME)"
	kind create cluster --name $(CLUSTER_NAME)

cert-manager:
	@echo "🔐 Applying Cert-Manager from $(CERT_MANAGER_URL)"
	kubectl apply -f $(CERT_MANAGER_URL)

helm-repo:
	@echo "📦 Adding and updating MDAI Helm repo"
	helm repo add mdai $(MDAI_REPO)
	helm repo update

mdai-deploy:
	@echo "🚀 Deploying MDAI Hub via Helm"
	helm upgrade --install --create-namespace --namespace mdai --cleanup-on-fail --wait-for-jobs mdai mdai/mdai-hub --devel

hub-config:
	@echo "🐙 Applying mdai hub config files: $(HUB)"
	kubectl apply -f $(HUB)

otel-config:
	@echo "🛠️ Applying otel config files: $(OTEL)"
	kubectl apply -f $(OTEL)

fluentd:
	@echo "📡 Deploying Fluentd with loggen config: $(FLUENT)"
	helm upgrade --install --repo https://fluent.github.io/helm-charts fluent fluentd -f $(FLUENT)

postcheck:
	@echo "🔍 Running post-deploy checks..."

	@echo "⏳ Waiting for pods to be ready in namespace 'mdai'..."
	kubectl wait --for=condition=Ready pods --all -n mdai --timeout=180s || (echo "❌ Timeout waiting for pods" && exit 1)

	@echo "🚨 Checking for pod failures in namespace 'mdai'..."
	@FAILED_PODS=$$(kubectl get pods -n mdai --field-selector=status.phase!=Running,status.phase!=Succeeded -o jsonpath='{.items[*].metadata.name}'); \
	if [ ! -z "$$FAILED_PODS" ]; then \
	  echo "❌ ERROR: Some pods failed to start properly:"; \
	  echo "$$FAILED_PODS"; \
	  kubectl describe pods $$FAILED_PODS -n mdai || true; \
	  exit 1; \
	else \
	  echo "✅ All pods are healthy"; \
	fi

	@echo "✅ Helm release status (mdai):"
	helm status mdai -n mdai

	@echo "✅ Helm release status (fluent):"
	helm status fluent

	@echo "📋 Resource summary:"
	kubectl get all -n mdai

clean:
	@echo "🧹 Cleaning up cluster and resources"
	kind delete cluster --name $(CLUSTER_NAME)
