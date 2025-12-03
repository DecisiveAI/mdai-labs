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
./cli/mdai.sh use-case buffer-replay --version 0.9.0 --hub ./0.9.0/use_cases/buffer-replay/hub.yaml --otel ./0.9.0/use_cases/buffer-replay/otel.yaml
```

## Start log generation

```sh
helm upgrade --install --repo https://fluent.github.io/helm-charts fluent fluentd -f ./0.9.0/use_cases/buffer-replay/mock_data/fluentd_config.yaml
```

```sh
kubectl port-forward -n mdai service/mdai-gateway 8081:8081
```

```
curl --request POST \
  --url http://localhost:8081/variables/hub/mdaihub-sample/var/replay_a_request \
  --header 'Content-Type: application/json' \
  --data "{
	\"data\": \"{\\\"replayName\\\":\\\"test-replay\\\",\\\"startTime\\\":\\\"$(if [[ "$OSTYPE" == "darwin"* ]]; then TZ=UTC date -v-30M '+%Y-%m-%d %H:%M'; else TZ=UTC date -d '30 minutes ago' '+%Y-%m-%d %H:%M'; fi)\\\",\\\"endTime\\\":\\\"$(TZ=UTC date '+%Y-%m-%d %H:%M')\\\",\\\"telemetryType\\\":\\\"logs\\\"}\"
}"
```

# Manual

## Install dependencies

```sh
helm dependency update ../mdai-hub --repository-config /dev/null
```

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
```

```sh
helm upgrade --install mdai ../mdai-hub \
  --namespace mdai \
  --create-namespace \
  --wait-for-jobs \
  --cleanup-on-fail \
  --set mdai-s3-logs-reader.enabled=false \
  --set mdai-operator.manager.env.otelSdkDisabled=true \
  --set mdai-gateway.otelSdkDisabled=true \
  --set mdai-event-hub.otelSdkDisabled=true \
  -f ../mdai-hub/values.yaml
```

### Install AWS secret

> ℹ️ Create a `.env` file with `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`

```sh
./aws/aws_secret_from_env.sh
```

## Set up hub and collector

```sh
kubectl apply -f ./0.9.0/use_cases/buffer_replay/basic/hub.yaml -n mdai
```

```sh
kubectl apply -f ./0.9.0/use_cases/buffer_replay/basic/otel.yaml -n mdai
```

## Start log generation

```sh
helm upgrade --install --repo https://fluent.github.io/helm-charts fluent fluentd -f ./0.9.0/use_cases/buffer-replay/mock_data/fluentd_config.yaml
```

## Test replay

```sh
kubectl port-forward -n mdai service/mdai-gateway 8081:8081
```

### Send replay request

```
curl --request POST \
  --url http://localhost:8081/variables/hub/mdaihub-sample/var/replay_a_request \
  --header 'Content-Type: application/json' \
  --data "{
	\"data\": \"{\\\"replayName\\\":\\\"test-replay\\\",\\\"startTime\\\":\\\"$(if [[ "$OSTYPE" == "darwin"* ]]; then TZ=UTC date -v-30M '+%Y-%m-%d %H:%M'; else TZ=UTC date -d '30 minutes ago' '+%Y-%m-%d %H:%M'; fi)\\\",\\\"endTime\\\":\\\"$(TZ=UTC date '+%Y-%m-%d %H:%M')\\\",\\\"telemetryType\\\":\\\"logs\\\"}\"
}"
```
