# Optional: MDAI Self-Monitoring

## About Self-monitoring

The MDAI Smart Telemetry Hub contains complex infrastructure. To maintain and monitor operational excellence, we have included an opt-in capability to create an understanding internal metrics, audit history of change events, and log streams affording traceability across our services and their events.


## How it works

The `mdai-helm-chart` installed `mdai-operator` and `mdai-gateway` expect a destination to send their logs to, but this chart does not manage deploying the logs destination for those services.

The `mdai-operator` has the ability to manage an opinionated collector, via compatible configurations, called the `mdai-collector` (sometimes referred to as the `hub-monitor`). The `mdai-collector` receives from this fixed list of services and sends the logs to a compatible destination.


## Compatible Destinations

There are currently two compatible destinations the `mdai-collector` supports
1. S3 (preferred)
2. OTLP endpoint


### MDAI Collector -> S3 (MDAI Recommended)

Send MDAI Smart Telemetry hub component logs to an s3 bucket.

[Jump ahead to instructions](instructions.md#mdai-collector-with-self-monitoring)


### MDAI Collector -> OTLP endpoint

Send MDAI Smart Telemetry hub component logs to a custom OTLP HTTP destination.

You can update the `values.yaml` for the [operator](https://github.com/DecisiveAI/mdai-helm-chart/blob/422e1c345806f634ed92db2a67a672ed7e9c7101/values.yaml#L52) and [mdai-gateway](https://github.com/DecisiveAI/mdai-helm-chart/blob/422e1c345806f634ed92db2a67a672ed7e9c7101/values.yaml#L59) to send logs to a destination of your choosing that accepts OTLP HTTP logs.


## Opt-out of Self-Monitoring

You can also choose to opt-out of self-monitoring by disabling OTel logging for MDAI components.

If you do not want to send logs from these components, you can disable sending logs by updating the `values.yaml` by setting `mdai-operator.manager.env.otelSdkDisabled` and `mdai-gateway.otelSdkDisabled` to `"true"` (a string value, not boolean).

> ℹ️ To stop logs from sending to s3, you will need to delete the MdaiCollector Custom Resource

----

<br />
<br />


[Jump ahead to instructions](instructions.md#mdai-collector-with-self-monitoring)

