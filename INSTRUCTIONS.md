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

**Install Methods**

Read about [self-monitoring](self_monitoring.md) with MDAI to understand the right choice for you. We highly recommend choosing self-monitoring.

1. [MDAI with Self-Monitoring (powered on s3)](#mdai-with-self-monitoring-powered-on-s3)
2. [MDAI without Self-Monitoring](#mdai-without-self-monitoring)


### MDAI Collector with Self-Monitoring

**Install MDAI Collector **

```sh
helm upgrade --install --create-namespace --namespace mdai --cleanup-on-fail --wait-for-jobs mdai mdai/mdai-hub --version v0.8.0-dev
```

> ❌ **Expected Error**
>
>You will now see an error with the service, `mdai-s3-logs-reader`, until you finish adding valid AWS IAM long-term credentials. Instructions to follow.

**Setup Long-Term IAM User and MDAI Collector**

Jump to [Setup IAM Long-term User](./aws/setup_iam_longterm_user_s3.md) for setting up a user and access keys for your cluster.

*After running through the IAM and collector setup, skip ahead to [Step 4](#step-4-install-mdai-collector)*


### MDAI Collector without Self-Monitoring

> ⚠️ **Warning**
>
>Without this capability, you will not have access to our built-in, self-instrumentation that ensures visibility and accuracy of MDAI operations.

**Install MDAI Collector**

```sh
helm upgrade --install --create-namespace --namespace mdai --cleanup-on-fail --wait-for-jobs mdai mdai/mdai-hub --set mdai-s3-logs-reader.enabled=false --version v0.8.0-dev
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
kubectl apply -f ./mdai/hub/0.8/hub_guaranteed_working.yaml -n mdai
```

## Step 6: Create + Install collector

```sh
kubectl apply -f ./otel/0.8/otel_guaranteed_working.yaml -n mdai
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