#!/bin/bash
set -e
ACCOUNT_ID=${1:-293160392232}  # i replaced ? with - so that it can run without args(USER ID and REGION) for testing
REGION=${2:-eu-north-1}
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
NAMESPACE="swiftbite"

echo "=== Deploying with Helm Umbrella using ECR images ==="

# Update helm dependencies
helm dependency update ./helm/swiftbite

# Deploy using ECR registry
helm upgrade --install swiftbite ./helm/swiftbite   --namespace $NAMESPACE --create-namespace   --set global.imageRegistry=$REGISTRY   --set global.imageTag=v1   --set global.imagePullSecrets=ecr-secret

echo ""
echo "Waiting for pods to pull from ECR..."
kubectl get pods -n $NAMESPACE -w
