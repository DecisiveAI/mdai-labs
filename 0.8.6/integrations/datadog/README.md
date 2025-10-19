# DD Integration (logs) Local Example

Create an OTLP shim surrounding an incoming "datadog" payload.

## Install mdai

In your terminal, go to your local path where your `mdai-labs` repo exits.

```bash
mdai install --version 0.8.6 -f values/overrides_0.8.6.yaml
```

## Install Dynamic data filtration lab resources

Add your Datadog API Key as a secret in k8s

```bash
# Make sure the namespace is the same namespace your collector is in.
# Alternatively, you can create a secret per namespace where resources require the secret.
kubectl -n your_namespace create secret generic datadog-secret --from-literal api-key=*****dd_api_key*****
kubectl -n datadog create secret generic datadog-secret --from-literal api-key=*****dd_api_key*****
```

Install the mdai resources

```bash
mdai use_case data_filtration --version 0.8.6 --workflow static --otel ./0.8.6/integrations/datadog/otel.yaml
```

## Add `dd-otlp-shim` Service

[Setup dd-otlp-shim service](dd-otlp-shim/README.md)


After initial setup steps, apply the k8s deployment to provision the service resources.

```bash
cd 0.8.6/integrations/datadog/dd-otlp-shim

kubectl apply -f k8s/deployment.yaml
```

## Add DD Agent

```bash
helm repo add datadog https://helm.datadoghq.com
helm repo update
helm install datadog-agent -f 0.8.6/integrations/datadog/dd_values.yaml datadog/datadog --create-namespace -n datadog
```

If you ever need to, you can uninstall the datadog agent using the following command...

```bash
helm uninstall datadog-agent
```
