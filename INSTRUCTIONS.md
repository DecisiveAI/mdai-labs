# 0.8 TESTING

## Steps

**Create kind cluster**

```sh
kind create cluster -n mdai
```
**Install `cert-manager`**

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.1/cert-manager.yaml
```


**With MDAI Self-Monitoring (powered on s3)**
```sh
helm upgrade --install --create-namespace --namespace mdai --cleanup-on-fail --wait-for-jobs mdai mdai/mdai-hub --version v0.8.0-dev
```

**Without MDAI Self-Monitoring (powered on s3)**

```sh
helm upgrade --install --create-namespace --namespace mdai --cleanup-on-fail --wait-for-jobs mdai mdai/mdai-hub --set mdai-s3-logs-reader.enabled=false --version v0.8.0-dev
```

### For s3 opt-in

Jump to [Setup IAM Long-term User](./aws/setup_iam_longterm_user.md) for setting up a user and access keys for your cluster.

#### Install MDAI Hub Monitor (used for MDAI Self-Monitoring)**

*Note: If You've chosen to hard code your secrets, use this deployment config*

```sh
kubectl apply -f ./mdai/hub_monitor/mdai_monitor_no_secrets.yaml
```

*Note: If You've chosen to programatically add secrets from an `.env` file, use this deployment config*
```sh
kubectl apply -f ./mdai/hub_monitor/mdai_monitor.yaml
```

**Install Log Generators**

1. Super noisy logs
```sh
kubectl apply -f ./synthetics/loggen_service_xtra_noisy.yaml
```

1. Semi noisy logs
```sh
kubectl apply -f ./synthetics/loggen_service_noisy.yaml
```

1. Normal log flow
```sh
kubectl apply -f ./synthetics/loggen_services.yaml
```


**Create + Install MDAI Hub**

```sh
kubectl apply -f ./mdai/hub/0.8/hub_guaranteed_working.yaml -n mdai
```

**Create + Install collector**

```sh
kubectl apply -f ./otel/0.8/otel_guaranteed_working.yaml -n mdai
```

**Fwd logs from the loggen services to MDAI**
```sh
helm upgrade --install --repo https://fluent.github.io/helm-charts fluent fluentd -f ./synthetics/loggen_fluent_config.yaml
```

**Fwd prometheus**

```sh
kubectl -n mdai port-forward svc/prometheus-operated 9090:9090
```
*Note: can also be done using k9s*

**See your alerts and dynamic filtration in action**

> Visit http://localhost:9090/alerts