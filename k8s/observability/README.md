# Observability - SwiftBite
Install on EKS (Evidence Day):
- helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring -f k8s/observability/values-prometheus.yaml
- helm install loki grafana/loki-stack -n monitoring -f k8s/observability/values-loki.yaml
- helm install tempo grafana/tempo -n monitoring
- Velero backup to S3 bucket swiftbite-assets
Dashboards to screenshot:
- Grafana: Orders per min, Revenue, Pod CPU/Memory, Latency p95, HPA scaling
- Loki: Logs for order-service, payment-service
- Tempo: Trace order -> payment -> delivery
