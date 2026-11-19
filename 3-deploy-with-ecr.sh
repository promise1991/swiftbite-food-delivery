#!/bin/bash
set -e
NAMESPACE="swiftbitens"
REGISTRY="293160392232.dkr.ecr.eu-north-1.amazonaws.com"
helm dependency update ./helm/swiftbite
helm upgrade --install swiftbite ./helm/swiftbite --namespace $NAMESPACE --create-namespace \
  --set global.image.registry=$REGISTRY \
  --set frontend.image.tag=v7 \
  --set order-service.image.tag=v6 \
  --set review-service.image.tag=v5
kubectl get pods -n $NAMESPACE
