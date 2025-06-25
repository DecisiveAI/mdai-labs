# mdai-labs

A repository full of reference solutions for getting started with MDAI.

## Manual Installation (Cluster + MDAI Dependencies)

If you'd like to setup  [Manual Installation](install.md)

## Automated Install/Uninstall (Cluster + MDAI Dependencies)

Run the following to make our install/uninstall script executable.
```
chmod +x mdai-kind.sh
```


### 🛠 Basic Commands

| Action                          | Command                      | Description                                   |
|---------------------------------|------------------------------|-----------------------------------------------|
| Install Cluster                 | `./mdai-kind.sh install`    | Installs the MDAI cluster                      |
| Delete Cluster                  | `./mdai-kind.sh delete`     | Deletes the MDAI cluster                       |
| Uninstalls config deployments   | `./mdai-kind.sh rm_configs`  | Deletes all resources in the `mdai` namespace |


### ☁️ AWS Commands

| Action                          | Command                         | Description                                                   |
|---------------------------------|---------------------------------|---------------------------------------------------------------|
| Apply AWS Credentials Secret    | `./mdai-kind.sh aws_secret`     | Runs `aws_secret_from_env.sh` to create/update credentials    |


### 🐙 MDAI Commands

| Action                          | Command                         | Description                                                   |
|---------------------------------|---------------------------------|---------------------------------------------------------------|
| Deploy Collector with Keys      | `./mdai-kind.sh mdai_monitor`   | Applies `mdai_monitor.yaml` with updated collector keys       |
| Install MDAI Smart Hub          | `./mdai-kind.sh hub`            | Applies the MDAI Smart Telemetry Hub manifest                 |
| Install Collector               | `./mdai-kind.sh collector`      | Applies the OpenTelemetry Collector manifest                  |
| Forward Logs to MDAI via Fluentd| `./mdai-kind.sh fluentd`        | Installs Fluentd Helm chart with log forwarding config        |


### 💪 🐙 MDAI Advanced Commands

| Action                             | Command                               | Description                                                   |
|------------------------------------|---------------------------------------|---------------------------------------------------------------|
| Install Compliance configs         | `./mdai-kind.sh compliance`   |        |
| Install Dynamic Filtration configs | `./mdai-kind.sh df`   |        |
| Install PII Redaction configs      | `./mdai-kind.sh pii`   |        |

### 📈 Data generators

| Action                          | Command                         | Description                                                   |
|---------------------------------|---------------------------------|---------------------------------------------------------------|
| Deploy Log Generators           | `./mdai-kind.sh logs`           | Deploys synthetic noisy and normal log services               |

### What do to after automated install?

>[!WARNING]
>
>You will likely see an error with the `svc/mdai-s3-logs-reader-service`. This is due to a missing secret attached to this service that enable this service to write to S3. You can jump ahead to [MDAI collector install with s3 access](./aws/setup_iam_longterm_user_s3.md). Follow instructions from here through the rest of the installation flow.