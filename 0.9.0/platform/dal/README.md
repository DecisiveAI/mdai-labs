# How to DAL with MDAI

## Install OTEL collector to export to MDAI DAL

```bash
mdai install --version 0.9.0 -f values/overrides_0.9.0-partial.yaml
```

## Install

```bash
./0.9.0/platform/dal/aws_secret_from_env.sh
kubectl create namespace synthetics
kubectl apply -f mock-data/data_filtration.yaml \
              -f 0.9.0/platform/dal/mdai-dal.yaml \     # creates MDAI DAL service
              -f 0.9.0/platform/dal/collector_dal.yaml  # creates OTEL collector pointing to MDAI DAL service
```

