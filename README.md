# mdai-labs

A repository full of reference solutions for getting started with MDAI.

## Manual Installation (Cluster + MDAI Dependencies)

If you'd like to setup  [Manual Installation](manual-install.md)

## Automated Install/Uninstall (Cluster + MDAI Dependencies)

Run the following to make our install/uninstall script executable.
```
chmod +x ./cli/mdai.sh
```

You can use the following commands to setup and install your mdai instance locally...

```
./cli/mdai.sh install

./cli/mdai.sh logs

./cli/mdai.sh hub

./cli/mdai.sh collector

./cli/mdai.sh fluentd
```

### Available commands

#### 🛠 Basic Commands

| Action                          | Command                      | Description                                   |
|---------------------------------|------------------------------|-----------------------------------------------|
| Install Cluster                 | `./cli/mdai.sh install`      | Installs the MDAI cluster                     |
| Delete Cluster                  | `./cli/mdai.sh delete`       | Deletes the MDAI cluster                      |
| Uninstalls config deployments   | `./cli/mdai.sh clean`        | Deletes all resources in the `mdai` namespace |

#### 📈 Data generators

| Action                          | Command                         | Description                                                   |
|---------------------------------|---------------------------------|---------------------------------------------------------------|
| Deploy Log Generators           | `./cli/mdai.sh logs`            | Deploys synthetic noisy and normal log services               |


#### 🐙 MDAI Commands

| Action                          | Command                         | Description                                                   |
|---------------------------------|---------------------------------|---------------------------------------------------------------|
| Install MDAI Smart Hub          | `./cli/mdai.sh hub`             | Applies the MDAI Smart Telemetry Hub manifest                 |
| Install Collector               | `./cli/mdai.sh collector`       | Applies the OpenTelemetry Collector manifest                  |
| Forward Logs to MDAI via Fluentd| `./cli/mdai.sh fluentd`         | Installs Fluentd Helm chart with log forwarding config        |

### What do to after automated install?

Jump to our docs to see how to use mdai to:
1. [setup dashboards for mdai monitoring](https://docs.mydecisive.ai/quickstart/dashboard/index.html)
2. [automate dynamic filtration](https://docs.mydecisive.ai/quickstart/filter/index.html)
