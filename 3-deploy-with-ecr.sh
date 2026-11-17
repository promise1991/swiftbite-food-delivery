#!/bin/bash
set -e
ACCOUNT_ID=${1:-293160392232}
REGION=${2:-eu-north-1}
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
NAMESPACE="swiftbitens"

echo "=== Deploying with Helm Umbrella using ECR images ==="

# Your ECR repos have no "swiftbite/" prefix, so make sure the charts match (safe to run repeatedly)
sed -i 's#repository: swiftbite/#repository: #' helm/charts/*/values.yaml

# Repackage the subcharts so Helm uses the latest files
helm dependency update ./helm/swiftbite

# Deploy using the ECR registry
helm upgrade --install swiftbite ./helm/swiftbite \
  --namespace $NAMESPACE --create-namespace \
  --set global.image.registry=$REGISTRY \
  --set global.image.tag=v1 \
  --set global.imagePullSecrets=ecr-secret

echo ""
echo "Waiting for pods to pull from ECR... (Ctrl+C to stop watching)"
kubectl get pods -n $NAMESPACE -w
