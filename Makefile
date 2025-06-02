# Makefile for deploying MDAI stack with Kind, Helm, and K8s configs

CLUSTER_NAME ?= mdai
CERT_MANAGER_URL ?= https://github.com/cert-manager/cert-manager/releases/download/v1.17.0/cert-manager.yaml
MDAI_REPO ?= https://decisiveai.github.io/mdai-helm-charts

# Acceptable overrides from CLI: e.g., make hub-config HUB_CONFIG=somefile.yaml
FLUENT ?= $(FLUENT_CONFIG)
HUB ?= $(HUB_CONFIG)
OTEL ?= $(OTEL_CONFIG)
TYPE ?= $(USE_CASE)

.PHONY: all cluster cert-manager cert-manager-ready helm-repo mdai-deploy mdai-webhook-ready hub-config otel-config fluentd postcheck dynamic_filtration clean

all: cluster cert-manager cert-manager-ready helm-repo mdai-deploy mdai-webhook-ready hub-config otel-config fluentd postcheck

cluster:
	@echo "🧱 Creating Kind cluster: $(CLUSTER_NAME)"
	kind create cluster --name $(CLUSTER_NAME)

cert-manager:
	@echo "🔐 Applying Cert-Manager from $(CERT_MANAGER_URL)"
	kubectl apply -f $(CERT_MANAGER_URL)

cert-manager-ready:
	@echo "⏳ Waiting for Cert-Manager to be ready..."
	kubectl wait deployment cert-manager-webhook \
		--namespace cert-manager \
		--for=condition=Available=True \
		--timeout=120s

helm-repo:
	@echo "📦 Adding and updating MDAI Helm repo"
	helm repo add mdai $(MDAI_REPO)
	helm repo update

mdai-deploy:
	@echo "🚀 Deploying MDAI Hub via Helm"
	helm upgrade --install --create-namespace --namespace mdai --cleanup-on-fail --wait-for-jobs --timeout 60s mdai mdai/mdai-hub --devel

mdai-webhook-ready:
	@echo "⏳ Waiting for MDAI webhook to be ready…"

	kubectl -n mdai wait deployment mdai-kube-state-metrics \
		--for=condition=Available --timeout=2m
	kubectl -n mdai wait deployment kube-prometheus-stack-operator \
		--for=condition=Available --timeout=2m
	kubectl -n mdai wait deployment event-handler-webservice \
		--for=condition=Available --timeout=2m
	kubectl -n mdai wait deployment mdai-operator-controller-manager \
	  --for=condition=Available --timeout=2m
	kubectl -n mdai wait deployment opentelemetry-operator \
	  --for=condition=Available --timeout=2m
	kubectl -n mdai wait deployment mdai-grafana \
		--for=condition=Available --timeout=2m

hub-config:
	@echo "🐙 Applying mdai hub config files: $(HUB)"
	kubectl apply -f $(HUB)

otel-config:
	@echo "🛠️ Applying otel config files: $(OTEL)"
	kubectl apply -f $(OTEL)

run-synthetics:
	@echo "🛠️ Applying otel config files: $(OTEL)"
	kubectl apply -f


fluentd:
	@echo "📡 Deploying Fluentd with loggen config: $(FLUENT)"
	helm upgrade --install --repo https://fluent.github.io/helm-charts fluent fluentd -f $(FLUENT)

postcheck:
	@echo "🔍 Running post-deploy checks..."

	@echo "⏳ Waiting for pods to be ready in namespace 'mdai'..."
	kubectl wait --for=condition=Ready pods --all -n mdai --timeout=500s || (echo "❌ Timeout waiting for pods" && exit 1)

	@echo "🚨 Checking for pod failures in namespace 'mdai'..."
	@FAILED_PODS=$$(kubectl get pods -n mdai --field-selector=status.phase!=Running,status.phase!=Succeeded -o jsonpath='{.items[*].metadata.name}'); \
	if [ ! -z "$$FAILED_PODS" ]; then \
	  echo "❌ ERROR: Some pods failed to start properly and/or are still spinning up:"; \
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

dynamic_filtration:
	@echo "⏳ Spinning up MDAI Hub with Dynamic Filtration settings"

	make all FLUENT="./synthetics/loggen_fluent_config.yaml" HUB="mdai/mdaihub_dynamic_filtration_config.yaml" OTEL=./otel/otel_dyanmic_filtration_config.yaml USE_CASE="dynamic_filtration"

compliance:
	@echo "⏳ Spinning up MDAI Hub with Compliance settings"

	make all FLUENT="./synthetics/loggen_fluent_config.yaml" HUB="mdai/mdaihub_compliance_config.yaml" OTEL=./otel/otel_compliance_config.yaml USE_CASE="compliance"

pii:
	@echo "⏳ Spinning up MDAI Hub with PII settings"

	make all FLUENT="./synthetics/loggen_fluent_config.yaml" HUB="mdai/mdaihub_pii_config.yaml" OTEL=./otel/otel_pii_config.yaml USE_CASE="pii"

clean:
	@echo "🧹 Cleaning up cluster and resources"
	kind delete cluster --name $(CLUSTER_NAME)
