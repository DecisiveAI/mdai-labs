# How to test a basic buffer replay

# CLI

## Install dependencies

```sh
./cli/mdai.sh install --version 0.9.0-dev
```

```sh
./cli/mdai.sh aws_secret
```

```sh
./cli/mdai.sh use-case buffer-replay --version 0.9.0
```

## Start log generation

```sh
helm upgrade --install --repo https://fluent.github.io/helm-charts fluent fluentd -f ./0.9.0/use_cases/buffer-replay/mock_data/fluentd_config.yaml
```

```sh
kubectl port-forward -n mdai service/mdai-gateway 8081:8081
```

```sh
curl --request POST \
  --url http://localhost:8081/variables/hub/mdaihub-sample/var/replay_a_request \
  --header 'Content-Type: application/json' \
  --data "{
	\"data\": \"{\\\"replayName\\\":\\\"test-replay\\\",\\\"startTime\\\":\\\"$(if [[ "$OSTYPE" == "darwin"* ]]; then TZ=UTC date -v-30M '+%Y-%m-%d %H:%M'; else TZ=UTC date -d '30 minutes ago' '+%Y-%m-%d %H:%M'; fi)\\\",\\\"endTime\\\":\\\"$(TZ=UTC date '+%Y-%m-%d %H:%M')\\\",\\\"telemetryType\\\":\\\"logs\\\"}\"
}"
```

# How to see it in action

This replay example will re-emit data from S3 for the last half an hour to the same `gateway-collector`. This is meant to simulate sending data back through telemetry pipelines upon replay. MdaiReplay is also capable of sending data directly to a telemetry vendor via OTLP if desired.

In this example, you can check that replay worked via the logs of the `gateway-collector`. You will see debug logs denoting certain debug explorters like the following showing what was sent to S3, and was was replayed through the collector. Here's an example:

```
2025-12-03T22:35:49.260Z    info    Logs    {"resource": {"mdai-logstream": "collector"}, "otelcol.component.id": "debug/saved_to_s3", "otelcol.component.kind": "exporter", "otelcol.signal": "logs", "resource logs": 1, "log records": 32}
2025-12-03T22:36:02.358Z    info    Logs    {"resource": {"mdai-logstream": "collector"}, "otelcol.component.id": "debug/saved_to_s3", "otelcol.component.kind": "exporter", "otelcol.signal": "logs", "resource logs": 1, "log records": 20}
2025-12-03T22:36:14.825Z    info    Logs    {"resource": {"mdai-logstream": "collector"}, "otelcol.component.id": "debug/replayed", "otelcol.component.kind": "exporter", "otelcol.signal": "logs", "resource logs": 2, "log records": 52}
```

# How it works

The hub configuration is set up with two key rules for facilitating replay: `replay_requested` and `replay_completed`

## replay_requested

This rule sets up what amounts to a "replay slot", using the `replay_a_request` variable as the channel to request a replay by listening for changes that are formatted as a replay request JSON.

```yaml
- name: replay_requested
  when:
    variableUpdated: replay_a_request
    updateType: set
  then:
    - deployReplay:
        replaySpec:
          statusVariableRef: replay_a_status
          opampEndpoint: http://mdai-gateway.mdai.svc.cluster.local:8081/opamp
          source:
            aws:
              awsAccessKeySecret: aws-credentials
            s3:
              s3Region: us-east-2
              s3Bucket: mdai-labs
              s3Partition: minute # matches awss3 exporter s3_partition_format: '%Y/%m/%d/%H/%M' in the gateway collector config
              filePrefix: replay-basic-
              s3Path: replay-basic-logs
          destination:
            otlpHttp:
              endpoint: http://gateway-collector.mdai.svc.cluster.local:4318
```

The replay request JSON in the variable (sent by the curl command in the above example) looks like this:

```json
{
  "replayName": "test-replay",
  "startTime": "2025-12-03 21:17",
  "endTime": "2025-12-03 21:47",
  "telemetryType": "logs"
}
```

## replay_completed

The replay cleanup rule watches for changes on the `replay_a_status` variable to trigger cleanup of the replay resources when replay work is complete.

```yaml
- name: replay_completed
  when:
    variableUpdated: replay_a_status
    updateType: set
  then:
    - cleanUpReplay: {}
```
