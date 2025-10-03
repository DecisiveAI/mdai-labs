# mdai.sh — Usage

_Generated on 2025-10-03T07:06:48Z_

## Synopsis (from `--help`)

```text
mdai.sh - Modular MDAI quickstart

USAGE:
  ./mdai.sh [global flags] <command> [command flags]

GLOBAL FLAGS:
  --cluster-name NAME        Kind cluster name (default: $KIND_CLUSTER_NAME)
  --kind-config FILE         Kind cluster config file (optional)
  --namespace NS             App namespace for kubectl applies (default: $NAMESPACE)
  --chart-namespace NS       Helm namespace (defaults to --namespace if omitted)
  --kube-context NAME        kubecontext for kubectl/helm
  --release-name NAME        Helm release name (default: mdai)
  --chart-ref REF            Full chart ref (e.g., oci://ghcr.io/decisiveai/mdai-hub)
  --chart-repo URL           Helm repo URL (default: $HELM_REPO_URL)
  --chart-name NAME          Helm chart name (default: $HELM_CHART_NAME)
  --chart-version VER        Helm chart version (default: $HELM_CHART_VERSION)
  --values FILE              Add a Helm values file (repeatable)
  --set key=val              Add a Helm --set (repeatable)
  --helm-extra "ARGS"        Extra Helm args (repeatable)
  --cert-manager-url URL     Override cert-manager manifest URL
  --no-cert-manager          Skip installing cert-manager
  --wait-timeout 120s        kubectl wait timeout (default: $KUBECTL_WAIT_TIMEOUT)
  --dry-run                  Print commands without executing
  --verbose                  Print commands and stream output
  -h, --help                 Show help

COMMANDS:

INSTALL / UPGRADE
  install                        Create Kind deps then install MDAI (alias: install_deps + install_mdai)
  install_deps                   Prepare Kind cluster + dependencies
  install_mdai                   Helm install/upgrade + wait
                                 [--version VER] [--values FILE] [--set k=v] [--resources [PREFIX]] [--no-cert-manager]
  upgrade                        Helm upgrade/install only

COMPONENTS
  hub [--file FILE]              Apply Hub manifest (default: ./mdai/hub/hub_ref.yaml)
  collector [--file FILE]        Apply OTel Collector (default: ./otel/otel_ref.yaml)
  fluentd [--values FILE]        Install Fluentd with values
  mdai_monitor [--file FILE]     Apply Monitor manifest
  aws_secret [--script FILE]     Create Kubernetes secret from env script

DATA GENERATION
  datagen [--apply FILE ...]     Apply custom generator YAMLs (falls back to built-in synthetics)
  logs                           Alias for 'datagen'

USE-CASES
  use-case <pii|compliance|tail-sampling>
           [--version VER] [--hub PATH] [--otel PATH] [--apply FILE ...]
                                 Apply a named bundle. If --hub/--otel not given, resolves:
                                 ./use-cases/<case>[/<version>]/{hub.yaml,otel.yaml}
                                 Extras can be added with repeatable --apply.
                                 Examples:
                                   use-case compliance --version 0.8.6
                                   use-case pii --hub ./use-cases/pii/0.8.6/hub.yaml --otel ./use-cases/pii/0.8.6/otel.yaml

KUBECTL HELPERS
  apply FILE                     kubectl apply -f FILE -n $NAMESPACE
  delete_file FILE               kubectl delete -f FILE -n $NAMESPACE

MAINTENANCE
  clean                          Remove common resources (keeps namespace)
  delete                         Delete the Kind cluster

REPORTING / DOCS
  report [--format table|json|yaml] [--out FILE]
                                 Show what’s installed
  gen-usage [--out FILE] [--examples FILE] [--section "..."]
                                 Generate usage.md

DEPRECATED (prefer `use-case`)
  compliance [--version VER] [--delete] [--otel FILE --hub FILE]
  df         [--version VER] [--delete] [--otel FILE --hub FILE]
  pii        [--version VER] [--delete] [--otel FILE --hub FILE]

For a full, nicely formatted guide, run:
  ./mdai.sh gen-usage --out ./docs/usage.md --examples ./cli/examples.md
```

## Global Flags

```text
  --cluster-name NAME        Kind cluster name (default: $KIND_CLUSTER_NAME)
  --kind-config FILE         Kind cluster config file (optional)
  --namespace NS             App namespace for kubectl applies (default: $NAMESPACE)
  --chart-namespace NS       Helm namespace (defaults to --namespace if omitted)
  --kube-context NAME        kubecontext for kubectl/helm
  --release-name NAME        Helm release name (default: mdai)
  --chart-ref REF            Full chart ref (e.g., oci://ghcr.io/decisiveai/mdai-hub)
  --chart-repo URL           Helm repo URL (default: $HELM_REPO_URL)
  --chart-name NAME          Helm chart name (default: $HELM_CHART_NAME)
  --chart-version VER        Helm chart version (default: $HELM_CHART_VERSION)
  --values FILE              Add a Helm values file (repeatable)
  --set key=val              Add a Helm --set (repeatable)
  --helm-extra "ARGS"        Extra Helm args (repeatable)
  --cert-manager-url URL     Override cert-manager manifest URL
  --no-cert-manager          Skip installing cert-manager
  --wait-timeout 120s        kubectl wait timeout (default: $KUBECTL_WAIT_TIMEOUT)
  --dry-run                  Print commands without executing
  --verbose                  Print commands and stream output
  -h, --help                 Show help
```

## Commands

```text
INSTALL / UPGRADE
  install                        Create Kind deps then install MDAI (alias: install_deps + install_mdai)
  install_deps                   Prepare Kind cluster + dependencies
  install_mdai                   Helm install/upgrade + wait
                                 [--version VER] [--values FILE] [--set k=v] [--resources [PREFIX]] [--no-cert-manager]
  upgrade                        Helm upgrade/install only

COMPONENTS
  hub [--file FILE]              Apply Hub manifest (default: ./mdai/hub/hub_ref.yaml)
  collector [--file FILE]        Apply OTel Collector (default: ./otel/otel_ref.yaml)
  fluentd [--values FILE]        Install Fluentd with values
  mdai_monitor [--file FILE]     Apply Monitor manifest
  aws_secret [--script FILE]     Create Kubernetes secret from env script

DATA GENERATION
  datagen [--apply FILE ...]     Apply custom generator YAMLs (falls back to built-in synthetics)
  logs                           Alias for 'datagen'

USE-CASES
  use-case <pii|compliance|tail-sampling>
           [--version VER] [--hub PATH] [--otel PATH] [--apply FILE ...]
                                 Apply a named bundle. If --hub/--otel not given, resolves:
                                 ./use-cases/<case>[/<version>]/{hub.yaml,otel.yaml}
                                 Extras can be added with repeatable --apply.
                                 Examples:
                                   use-case compliance --version 0.8.6
                                   use-case pii --hub ./use-cases/pii/0.8.6/hub.yaml --otel ./use-cases/pii/0.8.6/otel.yaml

KUBECTL HELPERS
  apply FILE                     kubectl apply -f FILE -n $NAMESPACE
  delete_file FILE               kubectl delete -f FILE -n $NAMESPACE

MAINTENANCE
  clean                          Remove common resources (keeps namespace)
  delete                         Delete the Kind cluster

REPORTING / DOCS
  report [--format table|json|yaml] [--out FILE]
                                 Show what’s installed
  gen-usage [--out FILE] [--examples FILE] [--section "..."]
                                 Generate usage.md

DEPRECATED (prefer `use-case`)
  compliance [--version VER] [--delete] [--otel FILE --hub FILE]
  df         [--version VER] [--delete] [--otel FILE --hub FILE]
  pii        [--version VER] [--delete] [--otel FILE --hub FILE]

For a full, nicely formatted guide, run:
  ./mdai.sh gen-usage --out ./docs/usage.md --examples ./cli/examples.md
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
| HELM_CHART_VERSION |  |  |
| HELM_CHART_REF | oci://ghcr.io/decisiveai/mdai-hub |  |
| HELM_RELEASE_NAME | mdai | helm release name |
| CERT_MANAGER_URL | https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml |  |
| KUBECTL_WAIT_TIMEOUT | 180s |  |
| KUBE_CONTEXT |  | --kube-context |
| SYN_PATH | ./synthetics |  |
| OTEL_PATH | ./otel |  |
| MDAI_PATH | ./mdai |  |
| USE_CASES_ROOT | . | root that contains versioned /use_cases trees |
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

```bash
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

# Apply versioned compliance bundle (uses 0.x.x/use_cases/compliance/{otel.yaml,mdaihub.yaml})
./mdai.sh compliance --version 0.x.x

# Delete the same (skips missing files with a warning)
./mdai.sh compliance --version 0.x.x --delete

# Explicit files override versioned defaults
./mdai.sh df --version 0.x.x --otel ./0.x.x/use_cases/dynamic_filtration/otel.yaml

# PII apply with fallback if versioned files are absent
./mdai.sh pii --version 0.x.x

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

