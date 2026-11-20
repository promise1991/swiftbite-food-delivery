
# Karpenter - Node Autoscaler (replaces default Cluster Autoscaler)
# HPA scales pods, Karpenter scales nodes

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.31.0"

  cluster_name          = module.eks.cluster_name
  enable_v1_permissions = true

  # Karpenter controller IAM + IRSA
  namespace = "kube-system"

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

# Karpenter NodePool - m7i-flex.large, spot + on-demand
# Apply after EKS is up: kubectl apply -f k8s/karpenter-nodepool.yaml
