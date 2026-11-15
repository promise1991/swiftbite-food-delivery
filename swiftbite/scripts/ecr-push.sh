#!/usr/bin/env bash
# Builds every service image and pushes it to ECR (repos are created if missing).
# Usage: AWS_REGION=eu-west-1 ./scripts/ecr-push.sh        (TAG defaults to v1)
set -euo pipefail
cd "$(dirname "$0")/.."
AWS_REGION="${AWS_REGION:?set AWS_REGION, e.g. export AWS_REGION=eu-west-1}"
TAG="${TAG:-v1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"
for s in frontend api-gateway auth-service user-service cart-service order-service payment-service \
         restaurant-service search-service menu-service review-service notification-service \
         delivery-service analytics-service; do
  aws ecr describe-repositories --repository-names "swiftbite/$s" --region "$AWS_REGION" >/dev/null 2>&1 \
    || aws ecr create-repository --repository-name "swiftbite/$s" --region "$AWS_REGION" \
         --image-scanning-configuration scanOnPush=true >/dev/null
  echo "==> $REGISTRY/swiftbite/$s:$TAG"
  docker build -t "$REGISTRY/swiftbite/$s:$TAG" "./$s"
  docker push "$REGISTRY/swiftbite/$s:$TAG"
done
echo; echo "Pushed. Use this registry with helm:  --set global.image.registry=$REGISTRY"
