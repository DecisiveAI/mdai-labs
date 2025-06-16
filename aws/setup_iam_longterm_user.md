# AWS S3 User, Access Keys, Use of Secrets for writing to s3

## Create a user via IAM

For our quickstart example, we will use a non-federated user in AWS IAM that has long-term credentials. You do not need console access for this user.

### Set Permissions: Attach inline policies

Using our `s3-policy.json` file, you should be able to _Attach policies directly_ to the user.

### Create an Access Key for the user

For this example, we can choose _Local Code_ or _Other_. You will likely be [recommended to use an IDE](https://aws.amazon.com/developer/tools/#IDE_and_IDE_Toolkits) for access management or warned of the risks of using long-term credentials with a non-federated user. Please do not dismiss these risks.

*Note: we don't recommend using this setup for a development + environment. If you're in AW EKS, we recommend [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) for a similar setup.*

> IMPORTANT! When you create the access key, you will need to download the file or make note of the `Access key ID` and the `Secret access key`.

## Apply secret via long-term access key

If you don't already, create a `.env` file. Then, update the `.env` file to have your credentials. It should look similar to the following:

```
AWS_ACCESS_KEY_ID="50M3R@ND0M@CC355K3Y"
AWS_SECRET_ACCESS_KEY="50M3R@ND0M53CR3T@CC355K3Y"
```

### Programatically update the file to use your long-term access keys

Make sure to run the following so the shell script is executable.
```
chmod +x ./aws/aws_secret_from_env.sh
```

Execute the shell script to generate and map new long-term aws credentials as a secret to your cluster
```
./aws/aws_secret_from_env.sh
```




