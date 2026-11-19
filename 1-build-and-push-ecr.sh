#!/bin/bash
set -e
# PROD FLOW: Build -> Tag -> Push to ECR
# Usage: ./1-build-and-push-ecr.sh 293160392232 eu-north-1
# Tags come from versions.env - SINGLE SOURCE OF TRUTH. Update ONLY versions.env for new versions.

ACCOUNT_ID=${1:?ERROR: Provide AWS Account ID -> ./1-build-and-push-ecr.sh 293160392232 eu-north-1}
REGION=${2:-eu-north-1}
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# Load versions
source ./versions.env

echo "=== STEP 1: ECR LOGIN ==="
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY

echo "=== STEP 2: BUILD & PUSH - Tags from versions.env ==="
declare -A TAGS=(
  [frontend]=$FRONTEND_TAG
  [api-gateway]=$API_GATEWAY_TAG
  [auth-service]=$AUTH_TAG
  [user-service]=$USER_TAG
  [cart-service]=$CART_TAG
  [order-service]=$ORDER_TAG
  [payment-service]=$PAYMENT_TAG
  [restaurant-service]=$RESTAURANT_TAG
  [search-service]=$SEARCH_TAG
  [menu-service]=$MENU_TAG
  [review-service]=$REVIEW_TAG
  [notification-service]=$NOTIFICATION_TAG
  [delivery-service]=$DELIVERY_TAG
  [analytics-service]=$ANALYTICS_TAG
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
echo "Tags from versions.env: frontend=$FRONTEND_TAG order=$ORDER_TAG review=$REVIEW_TAG"
