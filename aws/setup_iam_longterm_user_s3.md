# Setup MDAI Collector with S3 Access

## Steps involved

1. Create and obtain AWS IAM User with a long-term access key

1. Set up an IAM Policy to enable S3 permissions

1. Generate a secret using the long-term credentials

1. The `mdai-collector` references the secret to enable the e2e connectivity for MDAI to access the specified s3 bucket.


>[!NOTE]
>
>This guide assumes you have
>1. Cloned our [`mdai-labs` repo](https://github.com/DecisiveAI/mdai-labs/tree/main) set this as your working directory
>2. Have access to an AWS account with Admin access

### Step 1: Create a user via IAM

For our quickstart example, we will use a [non-federated user in AWS IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started-workloads.html) that has long-term credentials. You do not need console access for this user.

#### Set Permissions: Attach inline policies

Using our [`./aws/s3-policy.json` file](https://github.com/DecisiveAI/mdai-labs/blob/main/aws/s3-policy.json), you should be able to _Attach policies directly_ to the user. Don't forget to update the policy to point to your bucket.

#### Create an Access Key for the user

For this example, we can choose _Local Code_ or _Other_. You will likely be [recommended to use an IDE](https://aws.amazon.com/developer/tools/#IDE_and_IDE_Toolkits) for access management or warned of the risks of using long-term credentials with a non-federated user. Please do not dismiss these risks.

>[!NOTE]
>
> 🛑 **Warning**
>
> We do not recommend using this setup for a development or greater environment -- this is truly for the quickstart. If you're in AWS EKS, we recommend [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) for a similar effect.
>
>
> ⚠️ **Important**
>
> When you create the access key, you will need to download the file or make note of the `Access key ID` and the `Secret access key`.

### Step 2: Apply secret via long-term access key

There are two options:
1. [Programatically (recommended)](#option-1-programatically-recommended) - Add keys and deploy secret via a script
2. [Manually](#option-2-manually) - Add keys manually to a secret deployment

#### Option 1: Programatically (recommended)

Programatically update the `.env` file to use your long-term access keys

##### Create / Use `.env` file to store Access Keys

If you don't already, create a `.env` file. Then, update the `.env` file to have your credentials. It should look similar to the following:

```
AWS_ACCESS_KEY_ID="50M3R@ND0M@CC355K3Y"
AWS_SECRET_ACCESS_KEY="50M3R@ND0M53CR3T@CC355K3Y"
```

##### Ensure MDAI script executable

Make sure to run the following so the shell script is executable.

```
chmod +x ./aws/aws_secret_from_env.sh
```


##### Run script to create secret

Execute the shell script to generate and map new long-term aws credentials as a secret to your cluster

```
./aws/aws_secret_from_env.sh
```

After running this, you will have a secret created inside of your cluster.

##### Deploy the MDAI Collector to your cluster**

```sh
kubectl apply -f ./mdai/hub_monitor/mdai_monitor_no_secrets.yaml
```
<br />


>[!NOTE]
>
>To stop logs from sending to s3, you will need to delete the MdaiCollector Custom Resource


<br />

Jump ahead to [Install MDAI Collector](../install.md#install-mdai-dependencies-via-helm)

---

#### Option 2: Manually

Manually update the MDAI Collector CR with Access keys (not recommended)

From Step 1, you should have saved your credentials. You can update the file `mdai/hub_monitor/mdai_monitor.yaml` with your access keys.

**Deploy the MDAI Collector with updated keys**

```sh
kubectl apply -f ./mdai/hub_monitor/mdai_monitor.yaml
```

>[!WARNING]
>
>Do not check in this file to source control with the access keys.

## Notes

>[!INFO]
>
> Related to either monitor config
>* `mdai/hub_monitor/mdai_monitor_no_secrets.yaml`
>* `mdai/hub_monitor/mdai_monitor.yaml`
>
> The name (`hub-monitor`) must correspond to the beginning of the host name in the `values.yaml` for the [operator](https://github.com/DecisiveAI/mdai-hub/blob/422e1c345806f634ed92db2a67a672ed7e9c7101/values.yaml#L52) and [mdai-gateway](https://github.com/DecisiveAI/mdai-hub/blob/422e1c345806f634ed92db2a67a672ed7e9c7101/values.yaml#L59). So if the MdaiCollector resource name is `hub-monitor`, the corresponding service endpoint created is `http://hub-monitor-mdai-collector-service.mdai.svc.cluster.local:4318`.
>
> ⚠️ **Important**
>
> To stop logs from sending to s3, you will need to delete the MdaiCollector Custom Resource

----

<br />

## Next steps: [Install MDAI Collector](../install.md#install-mdai-dependencies-via-helm)



