# IAM User Secrets for writing to S3

## Steps involved

* Create and obtain AWS IAM User with a long-term access key
* Set up an IAM Policy to enable S3 permissions
* Generate a secret using the long-term credentials
* The `mdai-collector` references the secret to enable the e2e connectivity for MDAI to access the specified s3 bucket.

### Step 1: Create a user via IAM

For our quickstart example, we will use a non-federated user in AWS IAM that has long-term credentials. You do not need console access for this user.

#### Set Permissions: Attach inline policies

Using our `./aws/s3-policy.json` file, you should be able to _Attach policies directly_ to the user. Don't forget to update the policy to point to your bucket.

#### Create an Access Key for the user

For this example, we can choose _Local Code_ or _Other_. You will likely be [recommended to use an IDE](https://aws.amazon.com/developer/tools/#IDE_and_IDE_Toolkits) for access management or warned of the risks of using long-term credentials with a non-federated user. Please do not dismiss these risks.

> 🛑 **Warming**
>
> We do not recommend using this setup for a development or greater environment -- this is truly for the quickstart. If you're in AW EKS, we recommend [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) for a similar effect.*
>
> ⚠️ **Important**
>
> When you create the access key, you will need to download the file or make note of the `Access key ID` and the `Secret access key`.

### Step 2: Apply secret via long-term access key

There are two options
1. Manual - Add keys manually to a secret deployment
2. Programatically - Add keys and deploy secret via a script (preferred)

#### Option 1: Manual

Manually update the MDAI Collector CR with Access keys (not recommended)

From Step 1, you should have saved your credentials. You can update the file `mdai/hub_monitor/mdai_monitor.yaml` with your access keys.

**Deploy the MDAI Collector with updated keys**

```sh
kubectl apply -f ./mdai/hub_monitor/mdai_monitor.yaml
```

> ⚠️ **Important**
>
> Do not check in this file to source control with the access keys.


#### Option 2: Programatically (recommended)

Programatically update the `.env` file to use your long-term access keys

If you don't already, create a `.env` file. Then, update the `.env` file to have your credentials. It should look similar to the following:

```
AWS_ACCESS_KEY_ID="50M3R@ND0M@CC355K3Y"
AWS_SECRET_ACCESS_KEY="50M3R@ND0M53CR3T@CC355K3Y"
```

Make sure to run the following so the shell script is executable.
```
chmod +x ./aws/aws_secret_from_env.sh
```

Execute the shell script to generate and map new long-term aws credentials as a secret to your cluster
```
./aws/aws_secret_from_env.sh
```

After running this, you will have a secret created inside of your cluster.

**Deploy the MDAI Collector**

```sh
kubectl apply -f ./mdai/hub_monitor/mdai_monitor_no_secrets.yaml
```


## Notes

> ℹ️ **Info**
>
> Related to either `mdai/hub_monitor/mdai_monitor_no_secrets.yaml` or `mdai/hub_monitor/mdai_monitor.yaml`
>
> The name (`hub-monitor`) must correspond to the beginning of the host name in the `values.yaml` for the [operator](https://github.com/DecisiveAI/mdai-helm-chart/blob/422e1c345806f634ed92db2a67a672ed7e9c7101/values.yaml#L52) and [mdai-gateway](https://github.com/DecisiveAI/mdai-helm-chart/blob/422e1c345806f634ed92db2a67a672ed7e9c7101/values.yaml#L59). So if the MdaiCollector resource name is `hub-monitor`, the corresponding service endpoint created is `http://hub-monitor-mdai-collector-service.mdai.svc.cluster.local:4318`.
>
> ⚠️ **Important**
>
> To stop logs from sending to s3, you will need to delete the MdaiCollector Custom Resource

----

<br />
<br />

## Next steps: Simulate log streams

Go back to [Installation: Step 4](../INSTRUCTIONS.md#step-4-install-log-generators)


