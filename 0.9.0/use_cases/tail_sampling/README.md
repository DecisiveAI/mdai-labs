# Intelligent Tail Sampling

## How to run use case

### Required configs

Create relevant k8s Load Balancing resources

```bash
kubectl apply -f ./0.9.0/use_cases/tail_sampling/k8s_rbac.yaml

kubectl create rolebinding loadbalancer-endpointslices-reader \
  -n mdai \
  --role=loadbalancer-endpointslices-reader \
  --serviceaccount=mdai:loadbalancer
```

Create a custom scrape job for scraping traces metrics created by the load balancing count/service connector.

```bash
kubectl apply -f ./0.9.0/use_cases/tail_sampling/scrape_trace_count_metrics.yaml
```

### Basic workflow

#### Goal

Get your trace streams flowing.

#### Installing the relevant components

The following command installs:
- Synthetic data generator jobs
- OTel load balancing collector - balances traces by unique root spans
- OTel gateway collector - receives and forwards traces from the load balancer collector -> the configured destination.

```bash
mdai use_case tail_sampling --version 0.9.0 --workflow basic
```

#### Validate
Open the Grafana OTel dashboard to see your trace data flowing in real-time.

----

### Static workflow

#### Goal

Set hard-coded sampling rules

#### Installing the relevant components

Get your trace streams flowing.

The following command installs:
- Synthetic data generator jobs
- OTel load balancing collector
- OTel gateway collector

#### Validate

Open the Grafana OTel dashboard to see your trace data being sampled in real-time.

----

```bash
mdai use_case tail_sampling --version 0.9.0 --workflow static
```

### Dynamic workflow

```bash
mdai use_case tail_sampling --version 0.9.0 --workflow dynamic
```

