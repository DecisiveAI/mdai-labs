# Setting up the Opamp Supervisor for the collector

## Create a kind cluster with a mount for the otelcol binary
```shell
kind create cluster --config kind-config.yaml
```

## Download a collector binary for the supervisor to use inside the kind cluster node (docker container)
```shell
docker exec -it 9ac6899bc25e bash
curl --proto '=https' --tlsv1.2 -fOL https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.141.0/otelcol_0.141.0_linux_amd64.tar.gz
tar -xvf otelcol_0.141.0_linux_amd64.tar.gz
mv otelcol /usr/bin/otelcol-contrib
chown root:root /usr/bin/otelcol-contrib
```

## Install mdai
```shell
cd ~/src/mdai-labs && ./cli/mdai.sh install
```

## Apply the opamp supervisor k8s resources
```shell
k apply -f opamp-supervisor-configmap.yaml
k apply -f opamp-supervisor-deployment.yaml
k apply -f opamp-supervisor-service.yaml
```
