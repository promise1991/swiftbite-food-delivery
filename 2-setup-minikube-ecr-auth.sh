#!/bin/bash
set -e
# Makes minikube able to PULL from ECR (prod process)
# Tags from versions.env - SINGLE SOURCE OF TRUTH

ACCOUNT_ID=${1:-293160392232}
REGION=${2:-eu-north-1}
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
NAMESPACE="swiftbitens"

# Load versions
source ./versions.env

echo "=== Setting up Minikube to pull from ECR ==="
echo "Registry: $REGISTRY"

# Ensure minikube is running
minikube status || minikube start --cpus=4 --memory=8192 --driver=docker

# Create namespace if not exists
kubectl create namespace $NAMESPACE 2>/dev/null || true

echo "Creating docker-registry secret 'ecr-secret'..."
kubectl delete secret ecr-secret -n $NAMESPACE 2>/dev/null || true

# ECR password expires every 12 hours - this is why prod uses helpers
ECR_PASSWORD=$(aws ecr get-login-password --region $REGION)

kubectl create secret docker-registry ecr-secret --docker-server=$REGISTRY --docker-username=AWS --docker-password=$ECR_PASSWORD --docker-email=no@email.com -n $NAMESPACE

echo "Secret created. It will expire in 12h."
echo "For auto-refresh in prod, install: https://github.com/upmc-enterprises/registry-creds or use EKS IRSA"

# Test pull - using versions.env, no hardcoded v4
echo ""
echo "Testing pull from ECR..."
docker pull $REGISTRY/api-gateway:$API_GATEWAY_TAG || true
docker pull $REGISTRY/frontend:$FRONTEND_TAG || true
docker pull $REGISTRY/order-service:$ORDER_TAG || true

echo ""
echo "Next: Run ./3-deploy-with-ecr.sh"
