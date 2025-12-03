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
