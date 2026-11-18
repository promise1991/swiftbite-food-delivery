#!/bin/bash
set -e
NAMESPACE="swiftbitens"
helm dependency update ./helm/swiftbite
helm upgrade --install swiftbite ./helm/swiftbite --namespace $NAMESPACE --create-namespace
kubectl get pods -n $NAMESPACE
