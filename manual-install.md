# Manual Installation

## Step 1. Create kind cluster

```sh
kind create cluster -n mdai
```

## Step 2. Install `cert-manager`

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

kubectl wait --for=condition=Established crd/certificates.cert-manager.io --timeout=60s

kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=60s

kubectl wait --for=condition=Available=True deploy -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=60s
```

## Step 3. Install MDAI dependencies via Helm chart

**Install MDAI Collector**

```sh
helm upgrade --install \
  --repo https://charts.mydecisive.ai \
  --namespace mdai \
  --create-namespace \
  --cleanup-on-fail \
  --set mdai-operator.manager.env.otelSdkDisabled=true \
  --set mdai-gateway.otelSdkDisabled=true \
  --set mdai-s3-logs-reader.enabled=false \
  --version v0.8.0-rc3 \
  mdai mdai-hub
```

## Step 4: Install Log Generators

### 1. Initiate super noisy logs
```sh
kubectl apply -f ./synthetics/loggen_service_xtra_noisy.yaml
```

### 2. Initiate semi-noisy logs
```sh
kubectl apply -f ./synthetics/loggen_service_noisy.yaml
```

### 3. Initiate normal log flow
```sh
kubectl apply -f ./synthetics/loggen_services.yaml
```

## Step 5: Create + Install MDAI Hub

```sh
kubectl apply -f ./mdai/hub/hub_ref.yaml -n mdai
```

## Step 6: Create + Install collector

```sh
kubectl apply -f ./otel/otel_ref.yaml -n mdai
```

## Step 7: Fwd logs from the loggen services to MDAI
```sh
helm upgrade --install --repo https://fluent.github.io/helm-charts fluent fluentd -f ./synthetics/loggen_fluent_config.yaml
```

## Step 8: What do to after manual install?

Jump to our docs to see how to use mdai to:
1. [setup dashboards for mdai monitoring](https://docs.mydecisive.ai/quickstart/dashboard/index.html)
2. [automate dynamic filtration](https://docs.mydecisive.ai/quickstart/filter/index.html)