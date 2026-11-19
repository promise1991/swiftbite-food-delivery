output "vpc_id" { value = module.vpc.vpc_id }
output "eks_cluster_name" { value = module.eks.cluster_name }
output "rds_endpoint" { value = aws_db_instance.postgres.endpoint }
output "s3_assets_bucket" { value = aws_s3_bucket.assets.bucket }
