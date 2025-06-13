#!/usr/bin/env bash
set -euo pipefail

# 1. Grab creds from your AWS CLI profile

CREDS_JSON=$(aws sts get-caller-identity --profile your_profile_here)
AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id --profile your_profile_here)
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key --profile your_profile_here)

# 2. Create or update the k8s secret

kubectl -n kube-system delete secret kube2iam-creds --ignore-not-found
kubectl -n kube-system create secret generic kube2iam-creds \
  --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"