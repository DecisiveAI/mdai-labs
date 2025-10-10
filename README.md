# mdai-labs

A repository full of reference solutions for getting started with MDAI.

## Automated Install/Uninstall (Cluster + MDAI Dependencies)

Optional: In your .bashrc (or equivalent), add this to EOF. If you choose to do this, you can use `mdai` vs. `./cli/mdai.sh` to utlize the cli-like shell script 
```
# Set this to the path of your local clone of mdai-labs
export MDAI_LABS_DIR="$HOME/path/to/mdai-labs"
  
# Set mdai alias
  
alias mdai='"${MDAI_LABS_DIR%/}/cli/mdai.sh"'
```

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

