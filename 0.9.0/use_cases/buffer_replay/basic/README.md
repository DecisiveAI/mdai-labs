# How2Replay

# Send replay request to mdai-gateway

```
curl --request POST \
  --url http://localhost:8081/variables/hub/mdaihub-sample/var/replay_a_request \
  --header 'Content-Type: application/json' \
  --data '{
	"data": "{\"replayName\":\"test-replay\",\"startTime\":\"2025-08-19 12:00\",\"endTime\":\"2025-08-19 12:10\",\"telemetryType\":\"logs\"}"
}'
```
