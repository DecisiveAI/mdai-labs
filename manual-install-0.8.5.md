# Manual Installation

## Step 1. Create kind cluster

```sh
kind create cluster -n mdai
```

## Step 2. Install `cert-manager`

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
```

## Step 3. Install MDAI dependencies via Helm chart

**Install MDAI Collector**

#### With chart repo locally

```sh
helm upgrade --install mdai ../mdai-hub \
  --repo https://charts.mydecisive.ai \
  --namespace mdai \
  --create-namespace \
  --wait-for-jobs \
  --cleanup-on-fail \
  --set mdai-s3-logs-reader.enabled=false \
  -f ../mdai-hub/values.yaml
```

<details>

<summary>From remote</summary>

```sh
helm upgrade --install mdai mdai-hub \
  --repo https://charts.mydecisive.ai \
  --namespace mdai \
  --create-namespace \
  --version v0.8.5-dev \
  --set mdai-operator.manager.env.otelSdkDisabled=true \
  --set mdai-gateway.otelSdkDisabled=true \
  --set mdai-s3-logs-reader.enabled=false \
  --cleanup-on-fail
```

</details>

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

> Get your Slack wehbook URL and update the `hub_ref.yaml` [here](https://github.com/DecisiveAI/mdai-labs/blob/00b05e9589d53b6cfac3361c4605b38f41b702a3/mdai/hub/0.8.5/hub_ref.yaml#L88-L109) to receive Slack messages. Follow [this guide](https://api.slack.com/messaging/webhooks) to get a webhook URL.

```sh
kubectl apply -f ./mdai/hub/0.8.5/hub_ref.yaml -n mdai
```
```sh
kubectl apply -f ./mdai/collector/0.8.5/collector_ref.yaml -n mdai
```
```sh
kubectl apply -f ./mdai/observer/0.8.5/observer_ref.yaml -n mdai
```

## Step 6: Create + Install collector

```sh
kubectl apply -f ./otel/otel_log_severity_counts.yaml -n mdai
```

## Step 7: Configure prometheus to scrape error log counts from collector

```sh
kubectl apply -f ./prometheus/scrape_collector_count_metrics.yaml -n mdai
```

## Step 8: Fwd logs from the loggen services to MDAI
```sh
helm upgrade --install --repo https://fluent.github.io/helm-charts fluent fluentd -f ./synthetics/loggen_fluent_config.yaml
```

## Step 8: What do to after manual install?

Jump to our docs to see how to use mdai to:
1. [setup dashboards for mdai monitoring](https://docs.mydecisive.ai/quickstart/dashboard/index.html)
2. [automate dynamic filtration](https://docs.mydecisive.ai/quickstart/filter/index.html)

## Appendix: how to make error conditions happen for testing

* The `anomalous_error_rate` prometheus alert currently requires at least an hour's worth of data to trigger. Swap in [this version](https://github.com/DecisiveAI/mdai-labs/blob/e5c0309ad478cdd441c7463def5b0a9390cbb40b/mdai/hub/0.8.5/hub_ref.yaml#L66-L73) to guarantee alerts trigger that should call the webhook.
