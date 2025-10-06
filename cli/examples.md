# MDAI CLI Examples (updated)

This page collects practical, copy‑pasteable examples for common workflows using `./mdai.sh` — now including the unified **use‑case** command, `--data` support, richer usage‑doc generation, and a basic unit test runner.

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

```bash
# Default OCI ref (oci://ghcr.io/decisiveai/mdai-hub), latest devel
./mdai.sh install_mdai

# Pin a specific chart version (works with OCI)
./mdai.sh --chart-version v0.8.9 install_mdai

# Use values files (repeat --values) and specific image tags with --set
./mdai.sh   --values ./values/base.yaml   --values ./values/dev.yaml   --set mdai-gateway.image.tag=0.8.9   --set mdai-operator.image.tag=0.8.9   install_mdai

# Pass extra helm args (repeatable)
./mdai.sh --helm-extra "--atomic" --helm-extra "--timeout 10m" install_mdai
```

## Installing from a Helm repo (instead of OCI)

```bash
# Override repo/name if you don’t want the default OCI ref
./mdai.sh   --chart-ref ""   --chart-repo https://charts.mydecisive.ai   --chart-name mdai-hub   --chart-version v0.x.x   install_mdai
```

## Namespaces

```bash
# Change the app namespace for kubectl resources
./mdai.sh --namespace observability install_mdai

# Install the Helm release into a different helm namespace
./mdai.sh --chart-namespace mdai-system install_mdai
```

## Skipping cert-manager or customizing install_deps

```bash
# Skip cert-manager during deps install
./mdai.sh --no-cert-manager install_deps

# Use a Kind config file
./mdai.sh --kind-config ./kind-config.yaml install_deps
```

## Use‑case bundles (unified command)

The new **unified** `use-case` (alias: `use_case`) command applies a use‑case bundle consisting of **otel** and **hub** manifests, optional **mock‑data**, and any extra files you pass with `--apply`.

> Resolution order for bundle files (high‑level): versioned directories → local `./use-cases/<case>` → fallbacks in `$OTEL_PATH` / `$MDAI_PATH`.

### Basic apply

```bash
# Apply the "compliance" bundle for a specific version layout:
#   $USE_CASES_ROOT/0.8.6/use-cases/compliance/{otel.yaml,hub.yaml}
./mdai.sh use-case compliance --version 0.8.6
```

### Explicit files override

```bash
./mdai.sh use-case df   --otel ./use-cases/df/otel.yaml   --hub  ./use-cases/df/hub.yaml
```

### Auto‑applied mock‑data (default) or explicit `--data`

If you don’t pass `--data`, the CLI auto‑searches common mock‑data locations and applies the first match (e.g. `./mock-data/fluentd_config.yaml`, `/mock-data/fluentd_config.yaml`, and a few case‑based variants).

```bash
# Will auto‑apply the first mock-data file found by the resolver
./mdai.sh use-case compliance --version 0.8.6

# Explicitly choose a data file
./mdai.sh use-case compliance --version 0.8.6 --data ./mock-data/custom.yaml
```

### Extra files (repeatable) and delete

```bash
# Apply extras (repeat --apply)
./mdai.sh use-case pii   --version 0.8.6   --apply ./extras/alerts.yaml   --apply ./extras/dashboards.yaml

# Delete the bundle (also deletes the resolved data file and extras, best effort)
./mdai.sh use-case compliance --version 0.8.6 --delete
```

### Legacy bundle commands (still supported)

```bash
# Legacy shorthands kept for backward compatibility
./mdai.sh compliance --version 0.8.6
./mdai.sh df         --version 0.8.6
./mdai.sh pii        --version 0.8.6
```

### Use-case workflows (new)

Each use-case can define one or more **workflow** variants — typically:

- `basic` — default starter flow
- `static` — fixed resources for reproducible replay
- `dynamic` — self-adjusting, Smart Telemetry-driven

Use the `--workflow` flag (or `-w`) to select the flavor.  
When omitted, `basic` is assumed.

```bash
# Apply the compliance use-case (basic workflow)
./mdai.sh use-case compliance --version 0.8.6

# Static workflow
./mdai.sh use-case compliance --version 0.8.6 --workflow static

# Dynamic workflow
./mdai.sh use-case compliance --version 0.8.6 -w dynamic
```

**File resolution priority** (for both hub & otel):

```
<version>/use_cases/<case>/<workflow>/{hub.yaml,otel.yaml}
<version>/use_cases/<case>/{hub.yaml,otel.yaml}
```
> Explicit `--hub` / `--otel` arguments still override all.

## Individual components

```bash
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

## Generate usage docs (new: command details + use‑case data)

Use `mdai-usage-gen.sh` to generate a **Usage** page straight from the CLI:

```bash
# Simple usage doc
./mdai-usage-gen.sh --in ./mdai.sh --out ./docs/usage.md   --section "synopsis,globals,commands,defaults,usecase-data"

# Include per-command help (collected by running '<cmd> --help')
./mdai-usage-gen.sh --in ./mdai.sh --out ./docs/usage.md   --section "synopsis,globals,commands,command-details,defaults,usecase-data"   --scan-cmd-help

# Attach your examples page to the end (this file)
./mdai-usage-gen.sh --in ./mdai.sh --out ./docs/usage.md   --examples ./examples.md   --section "synopsis,commands,defaults,examples,usecase-data"
```

> The generator also emits a **Use‑Case Data Defaults** section summarizing the mock‑data search order used by `use-case` when `--data` isn’t provided.

## Unit test (no cluster required)

A lightweight test script stubs `kubectl`/`helm` so you can validate `use-case` behavior (apply, `--data`, and `--delete`) without touching a real cluster.

```bash
# From repo root (ensure the test file is executable)
chmod +x ./tests/mdai.test.sh

# Run tests
./tests/mdai.test.sh

# You should see "+ kubectl ..." lines and a final success message:
# ✅ All tests passed.
```

## Troubleshooting & tips

```bash
# Verbose mode (stream command output)
./mdai.sh --verbose install_mdai

# Verify script syntax quickly
bash -n mdai.sh && echo "Syntax OK"

# Confirm your alias/path resolves to the intended file
type -a mdai    # or: which mdai

# DRY-RUN everything to see what would be changed
./mdai.sh --dry-run use-case compliance --version 0.8.6

# Check cert-manager pods if install_deps didn’t wait long enough
kubectl get pods -n cert-manager -w
```
