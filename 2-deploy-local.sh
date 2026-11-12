#!/bin/bash
set -e
echo "🍔 SwiftBite — Deploying to minikube..."
helm dependency update ./helm/platform || true
helm upgrade --install swiftbite ./helm/platform -n swiftbite --create-namespace || echo "Helm chart not ready yet — will add in Phase 1"
kubectl get pods -n swiftbite
echo "Next: kubectl port-forward svc/frontend-service 3000:80 -n swiftbite"
