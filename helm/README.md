# SwiftBite Helm (umbrella + one chart per service)

helm/swiftbite        umbrella chart (global values, depends on every chart below)
helm/charts/<name>    one chart per service (14 services) + rabbitmq

## Deploy to minikube with images from ECR
    export AWS_REGION=eu-west-1                   # your ECR region
    ./scripts/ecr-push.sh                         # build + push all images as :v1
    minikube start --cpus=4 --memory=4096
    ./scripts/ecr-secret.sh                       # imagePullSecret "ecr-creds" (expires after 12h, rerun to refresh)
    REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com
    helm dependency update helm/swiftbite
    helm upgrade --install swiftbite helm/swiftbite -n swiftbite --create-namespace --set global.image.registry=$REGISTRY

## Change one service
    helm upgrade swiftbite helm/swiftbite -n swiftbite --reuse-values --set order-service.image.tag=v2
Push the new image first (TAG=v2 ./scripts/ecr-push.sh). Use a new tag for every change: with IfNotPresent a re-pushed v1 is not pulled again.

## Notes
- Resource names equal chart names (order-service, ...), so install one release per namespace.
- The 14 service charts share identical templates. If you edit one, copy the change to the others.
- Disable a service with --set <name>.enabled=false.
