#!/usr/bin/env bash
# Creates/refreshes the imagePullSecret "ecr-creds" so minikube can pull from ECR.
# ECR tokens last 12 hours: rerun this if new pods hit ImagePullBackOff later.
set -euo pipefail
AWS_REGION="${AWS_REGION:?set AWS_REGION, e.g. export AWS_REGION=eu-west-1}"
NS="${NS:-swiftbite}"
REGISTRY="$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create secret docker-registry ecr-creds \
  --docker-server="$REGISTRY" --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region "$AWS_REGION")" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "ecr-creds ready in namespace $NS for $REGISTRY"
