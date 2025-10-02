# Manual Local Installation 0.9.0-dev
> Warning: this is a development release. Install at your own risk.

## Step 1. Create kind cluster

```sh
kind create cluster -n mdai
```

## Step 2. Install `cert-manager`

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
kubectl wait --for=condition=available --timeout=600s deployment --all -n cert-manager
```

## Step 3. Install MDAI Helm chart

<details>

<summary>With chart repo locally</summary>  

* Checkout the desired version of [mdai-hub](https://github.com/DecisiveAI/mdai-hub)   
* Update values.yaml if needed.  
* Run:

```sh
helm upgrade --install mdai ../mdai-hub \
  --namespace mdai \
  --create-namespace \
  --wait-for-jobs \
  --cleanup-on-fail \
  --set mdai-s3-logs-reader.enabled=false \
  -f ../mdai-hub/values.yaml
```
</details>

<details>

<summary>From remote</summary>

```sh
  helm upgrade --install mdai oci://ghcr.io/decisiveai/mdai-hub \
  --version 0.9.0-dev \
  --namespace mdai \
  --create-namespace \
  --set mdai-operator.manager.env.otelSdkDisabled=true \
  --set mdai-gateway.otelSdkDisabled=true \
  --set mdai-event-hub.otelSdkDisabled=true \
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
```sh
kubectl apply -f ./mdai/hub/0.9.0/hub_ref.yaml -n mdai
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

## Step 9: What to do after manual installation?

Jump to our docs to see how to use mdai to:
1. [setup dashboards for mdai monitoring](https://docs.mydecisive.ai/quickstart/dashboard/index.html)
2. [automate dynamic filtration](https://docs.mydecisive.ai/quickstart/filter/index.html)

## Appendix 1: How to make error conditions happen for testing

The `anomalous_error_rate` prometheus alert currently requires at least an hour's worth of data to trigger.   
To test it sooner, temporarily replace the expression in [hub_ref.yaml](https://github.com/DecisiveAI/mdai-labs/blob/01701c6b71f9ab478bec0157406f1cb520d8d54d/mdai/hub/0.9.0/hub_ref.yaml#L75) with the lower-threshold expression below:
```yaml
expr: 'sum(increase(error_logs_by_service_total[5m])) by (mdai_service) > 0.1 * sum(avg_over_time(increase(error_logs_by_service_total[5m])[1h:])) by (mdai_service)'
```
## Appendix 2: How to set up webhook actions
This appendix shows two common webhook patterns for MDAI Hub actions:
1.	sending a message to Slack, and
2.	triggering a GitHub Actions workflow_dispatch.  

Some examples of webhook action templates: `mdai/hub/0.9.0/configmaps/webhook-templates.yaml`
#### Prereqs
* Your MDAI Hub custom resource (CR) is deployed.
* You know the namespace of that CR (examples below use mdai).
* `kubectl` is pointed at the correct cluster/namespace.
* Any Secrets referenced by actions must live in the same namespace as the Hub CR.
### Slack webhook setup
Get your Slack wehbook URL. Follow [this guide](https://api.slack.com/messaging/webhooks) to get a webhook URL.  
For security, store it in a Secret and reference it from the action.  
#### 1) Create the Secret (replace the URL):
```shell
kubectl -n mdai create secret generic slack-webhook-secret \
  --from-literal=url='https://hooks.slack.com/services/XXXXXXXXXXXXXXXXXXXXXXXX'
```
#### 2) Reference it from your Hub CR action:
Use built-in slack template. Use examples from [hub_ref_webhook_actions.yaml](https://github.com/DecisiveAI/mdai-labs/blob/01701c6b71f9ab478bec0157406f1cb520d8d54d/mdai/hub/0.9.0/hub_ref_webhook_actions.yaml#L137-L181)

### GitHub Action trigger (workflow_dispatch)
You can trigger a repository workflow that supports workflow_dispatch.   
#### 1) Example workflow in your repo (e.g., .github/workflows/deploy.yml):
```yaml
name: Dispatch Test
on:
  workflow_dispatch:
    inputs:
      env:
        description: Environment
        required: true
        default: dev
      build_id:
        description: Build ID
        required: true
        default: local
jobs:
  echo:
    runs-on: ubuntu-latest
    steps:
      - run: echo "env=${{ github.event.inputs.env }} build_id=${{ github.event.inputs.build_id }}"
```
#### 2) Action in your Hub CR to call GitHub’s dispatch API:
Use examples from [hub_ref_webhook_actions.yaml](https://github.com/DecisiveAI/mdai-labs/blob/01701c6b71f9ab478bec0157406f1cb520d8d54d/mdai/hub/0.9.0/hub_ref_webhook_actions.yaml#L182-L206)   
Templates referenced in examples could be found at [webhook-templates.yaml](https://github.com/DecisiveAI/mdai-labs/blob/01701c6b71f9ab478bec0157406f1cb520d8d54d/mdai/hub/0.9.0/configmaps/webhook-templates.yaml)
#### 3) Create a GitHub token and Secret
* Use a fine-grained PAT (or classic PAT) with Read and Write access to Actions for the target repo.
* Store it as a bearer value in a Secret (same namespace as the Hub CR):
```shell
kubectl -n mdai create secret generic github-token \
  --from-literal=authorization="Bearer github_pat_********_*********"
```
### Validation & best practices
•	URL must be an absolute http(s) URL (whether provided inline via url.value or indirectly via urlFrom.secretKeyRef).  
•	HTTP method must be one of the allowed values (use POST when payloadTemplate is present).  
•	Do not combine a Slack-specific template (if your cluster provides one) with payloadTemplate. Use one or the other.   
•	Keep tokens and webhooks only in Secrets; never commit them to Git.  
•	Ensure Secrets and the Hub CR are in the same namespace.   