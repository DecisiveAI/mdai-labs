# mdai.sh — Usage

_Generated on 2025-10-01T08:06:12Z_

## Synopsis (from `--help`)

```text
mdai.sh - MDAI CLI

USAGE:
  ./mdai.sh [global flags] <command> [command flags]

GLOBAL FLAGS:
  ... (your existing help content) ...

COMMANDS:
  ... (your existing help content) ...

For a full, nicely formatted guide, run:
  ./mdai.sh gen-usage --out ./usage.md --examples ./cli-examples.md
```

## Global Flags

```text
  ... (your existing help content) ...
```

## Commands

```text
  ... (your existing help content) ...

For a full, nicely formatted guide, run:
  ./mdai.sh gen-usage --out ./usage.md --examples ./cli-examples.md
```

## Defaults (auto-detected)

| Variable | Default | Note |
|---|---|---|
| KIND_CLUSTER_NAME | mdai |  |
| KIND_CONFIG |  |  |
| NAMESPACE | mdai | app namespace for kubectl applies |
| CHART_NAMESPACE |  | helm namespace (defaults to NAMESPACE if empty) |
| HELM_REPO_URL | https://charts.mydecisive.ai |  |
| HELM_CHART_NAME | mdai-hub |  |
| HELM_CHART_VERSION | 0.x.x |  |
| HELM_CHART_REF | oci://ghcr.io/decisiveai/mdai-hub |  |
| HELM_RELEASE_NAME | mdai | helm release name |
| CERT_MANAGER_URL | https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml |  |
| KUBECTL_WAIT_TIMEOUT | 180s |  |
| KUBE_CONTEXT |  | --kube-context |
| SYN_PATH | ./synthetics |  |
| OTEL_PATH | ./otel |  |
| MDAI_PATH | ./mdai |  |
| HELP_EXAMPLES_FILE | ./cli/examples.md |  |
| HELP_EXAMPLES_LINES | 40 |  |
| DRY_RUN | false |  |
| VERBOSE | false |  |
| INSTALL_CERT_MANAGER | true |  |

## Examples

# MDAI CLI Examples

This page collects practical, copy-pasteable examples for common workflows using `./mdai.sh`.

---

## Quickstart

```bash
# Create a local Kind cluster + cert-manager, then install MDAI
./mdai.sh install

# Or run in two explicit steps
./mdai.sh install_deps
./mdai.sh install_mdai

# Dry run (print commands without executing)
./mdai.sh --dry-run install
```

## Targeting a kube-context / cluster

```bash
# Use a specific kube context
./mdai.sh --kube-context kind-mdai install

# Create a cluster with a custom name and then install
./mdai.sh --cluster-name mdai-dev install_deps
./mdai.sh --cluster-name mdai-dev --kube-context kind-mdai-dev install_mdai
```

## Installing with the OCI chart (default) + extras

```
# Default OCI ref (oci://ghcr.io/decisiveai/mdai-hub), latest devel
./mdai.sh install_mdai

# Pin a specific chart version (works with OCI)
./mdai.sh --chart-version v0.8.9 install_mdai

# Use values files (repeat --values) and specific image tags with --set
./mdai.sh \
  --values ./values/base.yaml \
  --values ./values/dev.yaml \
  --set mdai-gateway.image.tag=0.8.9 \
  --set mdai-operator.image.tag=0.8.9 \
  install_mdai

# Pass extra helm args (repeatable)
./mdai.sh --helm-extra "--atomic" --helm-extra "--timeout 10m" install_mdai
```

## Installing from a Helm repo (instead of OCI)

```
# Override repo/name if you don’t want the default OCI ref
./mdai.sh \
  --chart-ref "" \
  --chart-repo https://charts.mydecisive.ai \
  --chart-name mdai-hub \
  --chart-version v0.x.x \
  install_mdai

```

## Namespaces

```
# Change the app namespace for kubectl resources
./mdai.sh --namespace observability install_mdai

# Install the Helm release into a different helm namespace
./mdai.sh --chart-namespace mdai-system install_mdai
```

## Skipping cert-manager or customizing install_deps

```
# Skip cert-manager during deps install
./mdai.sh --no-cert-manager install_deps

# Use a Kind config file
./mdai.sh --kind-config ./kind-config.yaml install_deps
```

## Bundles (one-shot applies)

```
# Compliance bundle (otel + hub)
./mdai.sh compliance

# Dynamic filtration bundle
./mdai.sh df

# PII bundle
./mdai.sh pii

# Override paths explicitly
./mdai.sh compliance --otel ./otel/otel_compliance.yaml --hub ./mdai/hub/hub_compliance.yaml
./mdai.sh df         --otel ./otel/otel_dynamic_filtration.yaml --hub ./mdai/hub/hub_dynamic_filtration.yaml
./mdai.sh pii        --otel ./otel/otel_pii.yaml        --hub ./mdai/hub/hub_pii.yaml
```

## Individual components

```
# Apply Hub / Collector directly (defaults shown)
./mdai.sh hub --file ./mdai/hub/hub_ref.yaml
./mdai.sh collector --file ./otel/otel_ref.yaml

# Deploy synthetic log generators
./mdai.sh logs

# Install Fluentd with a values file
./mdai.sh fluentd --values ./synthetics/loggen_fluent_config.yaml

# Apply AWS creds secret via helper script
./mdai.sh aws_secret --script ./aws/aws_secret_from_env.sh

# Apply monitor (no secrets) manifest
./mdai.sh mdai_monitor --file ./mdai/hub_monitor/mdai_monitor_no_secrets.yaml
```

## Upgrades

```
# Upgrade to a newer chart (OCI)
./mdai.sh --chart-version v0.9.0 upgrade

# Upgrade with new values/sets
./mdai.sh \
  --values ./values/prod.yaml \
  --set mdai-gateway.replicas=3 \
  upgrade
```

## Reports

```
# Human-readable table to stdout
./mdai.sh report

# JSON to a file, then inspect with jq
./mdai.sh report --format json --out build.json
jq '.helm.chart_version, .workloads.deployments' build.json

# YAML (pretty if yq is installed)
./mdai.sh report --format yaml --out build.yaml
```

## Cleanup

```
# Uninstall Helm release/resources but keep the namespace
./mdai.sh clean

# Delete the Kind cluster
./mdai.sh delete
```

## Troubleshooting & Tips

```
# Verbose mode (stream command output)
./mdai.sh --verbose install_mdai

# Verify script syntax quickly
bash -n mdai.sh && echo "Syntax OK"

# Check cert-manager pods if install_deps didn’t wait long enough
kubectl get pods -n cert-manager -w
```

