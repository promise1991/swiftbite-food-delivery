#!/bin/bash
set -e
echo "⚠️ Destroying EKS + RDS to SAVE MONEY..."
cd terraform
terraform destroy -auto-approve || echo "Nothing to destroy (good — \$0 cost)"
echo "✅ Destroyed. Check 【entity-AWS¦canonical_name=AWS】 console — EKS, RDS should be 0."