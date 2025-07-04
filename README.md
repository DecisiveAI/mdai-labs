# mdai-labs

A repository full of reference solutions for getting started with MDAI.

## Manual Installation (Cluster + MDAI Dependencies)

If you'd like to setup  [Manual Installation](manual-install.md)

## Automated Install/Uninstall (Cluster + MDAI Dependencies)

Run the following to make our install/uninstall script executable.
```
chmod +x mdai-kind.sh
```

You can use the following commands to setup and install your mdai instance locally...

```
./mdai-kind.sh install

./mdai-kind.sh logs

./mdai-kind.sh hub

./mdai-kind.sh collector

./mdai-kind.sh fluentd
```

### Available commands

#### 🛠 Basic Commands

| Action                          | Command                      | Description                                   |
|---------------------------------|------------------------------|-----------------------------------------------|
| Install Cluster                 | `./mdai-kind.sh install`    | Installs the MDAI cluster                      |
| Delete Cluster                  | `./mdai-kind.sh delete`     | Deletes the MDAI cluster                       |
| Uninstalls config deployments   | `./mdai-kind.sh rm_configs`  | Deletes all resources in the `mdai` namespace |

#### 📈 Data generators

| Action                          | Command                         | Description                                                   |
|---------------------------------|---------------------------------|---------------------------------------------------------------|
| Deploy Log Generators           | `./mdai-kind.sh logs`           | Deploys synthetic noisy and normal log services               |


#### 🐙 MDAI Commands

| Action                          | Command                         | Description                                                   |
|---------------------------------|---------------------------------|---------------------------------------------------------------|
| Install MDAI Smart Hub          | `./mdai-kind.sh hub`            | Applies the MDAI Smart Telemetry Hub manifest                 |
| Install Collector               | `./mdai-kind.sh collector`      | Applies the OpenTelemetry Collector manifest                  |
| Forward Logs to MDAI via Fluentd| `./mdai-kind.sh fluentd`        | Installs Fluentd Helm chart with log forwarding config        |

#### What do to after automated install?

Jump to our docs to see how to use mdai to:
1. [setup dashboards for mdai monitoring](https://docs.mydecisive.ai/quickstart/dashboard/index.html)
2. [automate dynamic filtration](https://docs.mydecisive.ai/quickstart/filter/index.html)