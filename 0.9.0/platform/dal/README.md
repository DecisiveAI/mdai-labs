# How to DAL with MDAI


## Install otel collector to write directly to s3

```bash
mdai install --version 0.9.0 -f values/overrides_0.9.0-partial.yaml
```

## Install

```bash
# TODO -- mdai platform dal-service
# TODO -- mdai platform dal-collector

kubectl create namespace synthetics
k apply -f mock-data/data_filtration.yaml
chmod +x 0.9.0/platform/dal/aws_secret_from_env.sh
./0.9.0/platform/dal/aws_secret_from_env.sh
k apply -f 0.9.0/platform/dal/s3_collector.yaml
```

## Install otel collector to write directly to s3

Go to [mdai-dal repo](https://github.com/DecisiveAI/mdai-dal).

```bash
cd /path/to/mdai-dal

chmod +x 0.9.0/platform/dal/aws_secret_from_env.sh
./0.9.0/platform/dal/aws_secret_from_env.sh

helm upgrade --install mdai-dal -n mdai ./deployment \
  --set dal.s3.bucket=mdai-test-dal \
  --set dal.s3.region=us-east-1
```
