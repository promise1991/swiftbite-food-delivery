#!/bin/bash
set -e
echo "🍔 SwiftBite — Building all services (LOCAL minikube, \$0 cost)..."
eval $(minikube docker-env)
SERVICES="api-gateway auth-service user-service restaurant-service menu-service cart-service order-service payment-service delivery-service notification-service search-service review-service analytics-service"
for svc in $SERVICES; do
  echo "→ Building $svc:v1..."
  mkdir -p services/$svc
  # If Dockerfile no dey yet, create placeholder so build no fail
  if [ ! -f services/$svc/Dockerfile ]; then
    echo "  (No Dockerfile yet for $svc — skipping, will add in Phase 1)"
    continue
  fi
  docker build -t $svc:v1 ./services/$svc
done
echo "✅ All built. No push to ECR yet — local only."
echo "Next: ./2-deploy-local.sh"
