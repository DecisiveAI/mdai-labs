# How2Replay

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

```sh
kubectl apply -f ./0.9.0/use_cases/buffer_replay/basic/hub.yaml -n mdai
```

```sh
kubectl apply -f ./0.9.0/use_cases/buffer_replay/basic/otel.yaml -n mdai
```

```sh
helm upgrade --install --repo https://fluent.github.io/helm-charts fluent fluentd -f ./0.9.0/use_cases/buffer_replay/mock_data/fluentd_config.yaml
```

```
kubectl port-forward $(kubectl get pods -l app=mdai-gateway -o jsonpath='{.items[0].metadata.name}') 8081:8081
```

```
curl --request POST \
  --url http://localhost:8081/variables/hub/mdaihub-sample/var/replay_a_request \
  --header 'Content-Type: application/json' \
  --data "{
	\"data\": \"{\\\"replayName\\\":\\\"test-replay\\\",\\\"startTime\\\":\\\"$(if [[ "$OSTYPE" == "darwin"* ]]; then date -v-5M '+%Y-%m-%d %H:%M'; else date -d '30 minutes ago' '+%Y-%m-%d %H:%M'; fi)\\\",\\\"endTime\\\":\\\"$(date '+%Y-%m-%d %H:%M')\\\",\\\"telemetryType\\\":\\\"logs\\\"}\"
}"
```
