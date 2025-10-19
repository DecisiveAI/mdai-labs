## How to run locally

### Enter the service directory

```
cd ./0.8.6/integrations/datadog/dd-otlp-shim
```

### Via Go

```bash
go build -o dd-otlp-shim .
./dd-otlp-shim \
  -listen :8080 \
  -path /dd \
  -otlp http://localhost:4318/v1/logs \
  -require-api-key datadog-secret \
  -default-tags "env:dev,cluster:kind"
```

## Via k8s

### Create a local docker container

```bash
# build your image
docker build -t dd-otlp-shim:dev .

# verify the image was created
docker images | grep dd-otlp-shim
```

### load it into kind cluster

```bash
kind load docker-image dd-otlp-shim:dev --name mdai-labs

# you will need to port-forward your gateway-collector to port `:4318` for the following to work
./dd-otlp-shim -listen :8080 -path /dd -otlp http://localhost:4318/v1/logs -require-api-key datadog-secret
```

## Test it!

You should see an `Ok` response.

```bash
curl -i -X POST "http://localhost:8080/dd" \
  -H 'Content-Type: application/json' \
  -H 'DD-API-KEY: datadog-secret' \
  --data-binary @- <<'JSON'
[
  {"service":"api","host":"node-a","status":"info","message":"hello 1","timestamp":1758210000},
  {"service":"api","status":"error","message":"boom","ddtags":"env:dev,team:core"}
]
JSON
```
