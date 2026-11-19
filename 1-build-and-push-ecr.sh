#!/bin/bash
set -e
# PROD FLOW: Build -> Tag -> Push to ECR
# Usage: ./1-build-and-push-ecr.sh 293160392232 eu-north-1

ACCOUNT_ID=${1:?ERROR: Provide AWS Account ID -> ./1-build-and-push-ecr.sh 293160392232 eu-north-1}
REGION=${2:-eu-north-1}
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

echo "=== STEP 1: ECR LOGIN ==="
【entity-aws¦canonical_name=AWS】 ecr get-login-password --region $REGION | docker login --username 【entity-AWS¦canonical_name=AWS】 --password-stdin $REGISTRY

echo "=== STEP 2: BUILD & PUSH - LATEST TAGS ==="
# Latest known-good tags per service (Nov 19)
# frontend v7 = food photos + sticky nav
# order v6 = delivery_address + phone + notes
# review v5 = Dockerfile fix
# others v4 = stable
declare -A TAGS=(
  [frontend]=v7
  [api-gateway]=v4
  [auth-service]=v4
  [user-service]=v4
  [cart-service]=v4
  [order-service]=v6
  [payment-service]=v4
  [restaurant-service]=v4
  [search-service]=v4
  [menu-service]=v4
  [review-service]=v5
  [notification-service]=v4
  [delivery-service]=v4
  [analytics-service]=v4
)

for s in frontend api-gateway auth-service user-service cart-service order-service payment-service \
         restaurant-service search-service menu-service review-service notification-service \
         delivery-service analytics-service; do
  TAG=${TAGS[$s]}
  echo ""
  echo ">>> Building $s:$TAG"
  docker build -t $s:$TAG ./swiftbite/$s
  echo ">>> Tagging $s for ECR"
  docker tag $s:$TAG $REGISTRY/$s:$TAG
  echo ">>> Creating ECR repo if not exists"
  aws ecr describe-repositories --repository-names $s --region $REGION 2>&1 >/dev/null || aws ecr create-repository --repository-name $s --region $REGION --image-scanning-configuration scanOnPush=true
  echo ">>> Pushing $REGISTRY/$s:$TAG"
  docker push $REGISTRY/$s:$TAG
done

echo ""
echo "=== DONE ==="
echo "All images pushed to: $REGISTRY"
echo "frontend:v7 order:v6 review:v5 others:v4"
