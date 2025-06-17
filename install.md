# Install MDAI into your cluster

Make sure Docker is running.

## Step 1. Create kind cluster

 Use kind to create a new cluster.

```
kind create cluster --name mdai
```

## Step 2. Install cert-manager

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
```

## Step 3. Install MDAI dependencies via Helm chart

### MDAI with Self-Monitoring via S3

Send MDAI Smart Telemetry hub component logs to an s3 bucket for explainability of MDAI operations.

#### Setup Long-Term IAM User and MDAI Collector

>[!NOTE]
>
>***DO NOT IGNORE THIS STEP***
>
>This is an involved step that cannot be skipped
>
>* **If you have an AWS account**, jump over to our [Setup IAM & MDAI Collector User Guide](./aws/setup_iam_longterm_user_s3.md).
>
>* **If you do not have an AWS account**, please see our [Alternative Install methods](./installMethods.md)


#### Install MDAI dependencies via Helm

>[!Note]
>If you came from the automated install, you don't need to run the next command. Continue on to the next step. If you end up running it more than once, it will just create a new deployment revision.


```sh
helm upgrade --install --create-namespace --namespace mdai --cleanup-on-fail --wait-for-jobs mdai mdai/mdai-hub --version v0.8.0-dev
```

**Jump ahead to [Install MDAI Smart Telemetry Hub](#install-mdai-smart-telemetry-hub)**

---

#### Alternative installation methods

>[!Note]
>
>*There are multiple [MDAI-supported installation methods](./installMethods.md), however, the MDAI with Self-Monitoring is our recommended approach*

---

## Install MDAI Smart Telemetry Hub

```
kubectl apply -f ./mdai/hub/0.8/hub_guaranteed_working.yaml -n mdai
```

# Install Log Generators

## 1. Initiate super noisy logs
```sh
kubectl apply -f ./synthetics/loggen_service_xtra_noisy.yaml
```

## 2. Initiate semi-noisy logs
```sh
kubectl apply -f ./synthetics/loggen_service_noisy.yaml
```

## 3. Initiate normal log flow
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