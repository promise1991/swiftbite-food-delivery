#!/bin/bash
set -e
# Deploy SwiftBite umbrella - Tags from versions.env (SINGLE SOURCE OF TRUTH)
# Usage: ./3-deploy-with-ecr.sh
source ./versions.env
NAMESPACE="swiftbitens"
REGISTRY="293160392232.dkr.ecr.eu-north-1.amazonaws.com"
helm dependency update ./helm/swiftbite
helm upgrade --install swiftbite ./helm/swiftbite --namespace $NAMESPACE --create-namespace \
  --set global.image.registry=$REGISTRY \
  --set frontend.image.tag=$FRONTEND_TAG \
  --set api-gateway.image.tag=$API_GATEWAY_TAG \
  --set auth-service.image.tag=$AUTH_TAG \
  --set user-service.image.tag=$USER_TAG \
  --set cart-service.image.tag=$CART_TAG \
  --set order-service.image.tag=$ORDER_TAG \
  --set payment-service.image.tag=$PAYMENT_TAG \
  --set restaurant-service.image.tag=$RESTAURANT_TAG \
  --set search-service.image.tag=$SEARCH_TAG \
  --set menu-service.image.tag=$MENU_TAG \
  --set review-service.image.tag=$REVIEW_TAG \
  --set notification-service.image.tag=$NOTIFICATION_TAG \
  --set delivery-service.image.tag=$DELIVERY_TAG \
  --set analytics-service.image.tag=$ANALYTICS_TAG
kubectl get pods -n $NAMESPACE
