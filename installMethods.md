# MDAI Install Methods

>[!TIP]
>**Read about [self-monitoring](self_monitoring.md) with MDAI to understand the right choice for you.**
>
>***We highly recommend choosing self-monitoring.***

## Your options for MDAI Installation

1. [MDAI with Self-Monitoring via S3](./install.md#mdai-with-self-monitoring-via-s3)
2. [MDAI with Self-Monitoring via OTLP Endpoint](#mdai-with-self-monitoring-via-otlp-endpoint)
3. [MDAI without Self-Monitoring](#opt-out-of-self-monitoring)

### MDAI with Self-Monitoring via OTLP Endpoint

Send MDAI Smart Telemetry hub component logs to a new or existing (not provided by MDAI) OTLP HTTP destination to fully-customize your explainability of MDAI operations.

#### Config Updates

You can update the  `values.yaml` [(found in our mdai-hub repo)](https://github.com/DecisiveAI/mdai-hub/blob/main/values.yaml) to modify where logs are sent. This destination must be able to accepts OTLP HTTP logs.

Changes should be made in the following locations:

1. [MDAI Operator Blob](https://github.com/DecisiveAI/mdai-hub/blob/422e1c345806f634ed92db2a67a672ed7e9c7101/values.yaml#L52)

    ```
    mdai-operator:
      enabled: true
      fullnameOverride: mdai-operator
      controllerManager:
        manager:
          env:
            otelExporterOtlpEndpoint: http://your-otlp-endpoint:4318
    ```

2. [mdai-gateway blob](https://github.com/DecisiveAI/mdai-hub/blob/a10d29cbe0331b1f22b41c576754dff702685a55/values.yaml#L47)
    ```
    mdai-gateway:
      enabled: true
      otelExporterOtlpEndpoint: http://your-otlp-endpoint:4318
    ```


#### Install MDAI

***Note**: Make sure you can access `values.yaml` your working directory. You have have to clone the `mdai-hub` repo.*

```sh
helm upgrade --install \
  mdai mdai-hub \
  --repo https://charts.mydecisive.ai \
  --version v0.8.0-dev \
  --namespace mdai \
  --create-namespace \
  --cleanup-on-fail
```

>[!NOTE]
>
>To stop logs from sending to s3, you will need to delete the MdaiCollector Custom Resource

<br />


Next step [Install MDAI](./install.md#install-mdai-dependencies-via-helm)

---

## Opt-out of Self-Monitoring

You can also choose to opt-out of self-monitoring by disabling OTel logging for MDAI components.

#### Config Updates

If you do not want to send logs from these components, you can disable sending logs to the MDAI Collector by updating the `values.yaml` [(found in our mdai-hub repo)](https://github.com/DecisiveAI/mdai-hub/blob/main/values.yaml).


You must change `otelSdkDisabled: "true"` in two locations:

1. [MDAI Operator Blob](https://github.com/DecisiveAI/mdai-hub/blob/422e1c345806f634ed92db2a67a672ed7e9c7101/values.yaml#L54)
    ```
    mdai-operator:
      enabled: true
      fullnameOverride: mdai-operator
      controllerManager:
        manager:
          env:
            otelExporterOtlpEndpoint: http://hub-monitor-mdai-collector-service.mdai.svc.cluster.local:4318
            otelSdkDisabled: "true"
    ```

2. [mdai-gateway blob](https://github.com/DecisiveAI/mdai-hub/blob/a10d29cbe0331b1f22b41c576754dff702685a55/values.yaml#L48)
    ```
    mdai-gateway:
      enabled: true
      otelExporterOtlpEndpoint: http://hub-monitor-mdai-collector-service.mdai.svc.cluster.local:4318
      otelSdkDisabled: "true"
    ```

#### Install MDAI

***Note**: Make sure you can access `values.yaml` your working directory. You have have to clone the `mdai-hub` repo.*

```sh
 helm upgrade --install \
   mdai mdai-hub \
   --repo https://charts.mydecisive.ai \
   --set mdai-s3-logs-reader.enabled=false
   --version v0.8.0-dev \
   --namespace mdai \
   --create-namespace \
   --cleanup-on-fail
```

## MDAI Collector without Self-Monitoring (opt-out)

>[!WARNING]
>
>Without this capability, you will not have access to our built-in, self-instrumentation that ensures visibility and accuracy of MDAI operations.

---

## Next step [Install MDAI](./install.md#install-mdai-dependencies-via-helm)

