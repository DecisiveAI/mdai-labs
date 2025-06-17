# mdai-labs

A repository full of reference solutions for getting started with MDAI.

## [Manual Installation](install.md)

## Automated Install/Uninstall

Run the following to make our install/uninstall script executable.
```
chmod +x mdai-kind.sh
```

### 🛠 Available Commands

| Action                | Command                      | Description                     |
|-----------------------|------------------------------|---------------------------------|
| Cluster Installation  | `./setup_mdai.sh install`    | Installs the MDAI cluster       |
| Cluster Deletion      | `./setup_mdai.sh delete`     | Deletes the MDAI Kind cluster   |


### What do to after cluster install?

>[!WARNING]
>
>You will likely see an error with the `svc/mdai-s3-logs-reader-service`. This is due to a missing secret attached to this service that enable this service to write to S3. You can jump ahead to [MDAI collector install with s3 access](./aws/setup_iam_longterm_user_s3.md). Follow instructions from here through the rest of the installation flow.