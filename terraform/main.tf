terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
}

# VPC - 2 AZs (plan only, no apply tonight)
module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "5.1.0"
  name               = "swiftbite-vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["${var.region}a", "${var.region}b"]
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.11.0/24", "10.0.12.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
  tags               = { Project = "swiftbite" }
}

# EKS - 2 nodes m7i-flex.large, plan only
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.8.0"
  cluster_name    = "swiftbite-eks"
  cluster_version = "1.32"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  eks_managed_node_groups = {
    default = {
      instance_types = ["m7i-flex.large"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
    }
  }
  tags = { Project = "swiftbite" }
}

# RDS Postgres - db.t3.micro, plan only (for prod, data chart goes away)
resource "aws_db_instance" "postgres" {
  identifier             = "swiftbite-postgres"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "swiftbite"
  username               = "swiftbite_admin"
  password               = var.db_password
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [module.vpc.default_security_group_id]
  skip_final_snapshot    = true
  tags                   = { Project = "swiftbite" }
}

# S3 for frontend assets / Terraform state
resource "aws_s3_bucket" "assets" {
  bucket = "swiftbite-assets-${data.aws_caller_identity.current.account_id}"
  tags   = { Project = "swiftbite" }
}

data "aws_caller_identity" "current" {}
