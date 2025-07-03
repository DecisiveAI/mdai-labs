# 0.8 TESTING


## Step 1. Create kind cluster

```sh
kind create cluster -n mdai
```

## Step 2. Install `cert-manager`

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.1/cert-manager.yaml
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

## Step 8: Check alerts in Prometheus

### Forward prometheus

```sh
kubectl -n mdai port-forward svc/prometheus-operated 9090:9090
```
*Note: can also be done using k9s*


### Check active alerts

See your alerts and dynamic filtration in action

> Visit http://localhost:9090/alerts