terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Remote state — uncomment and configure before first apply:
  #
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "devops-portfolio"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source      = "../../modules/vpc"
  environment = var.environment
  region      = var.region
  vpc_cidr    = var.vpc_cidr
}

module "eks" {
  source              = "../../modules/eks"
  cluster_name        = "${var.environment}-devops-portfolio-cluster"
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_type  = "t3.large"   # Larger instances for prod workloads
  desired_nodes       = 3
  min_nodes           = 2
  max_nodes           = 10
  allowed_cidr_blocks = var.allowed_cidr_blocks
}

module "rds" {
  source             = "../../modules/rds"
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_instance_class  = "db.t3.small"  # Upgrade to db.r6g.large for production traffic
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}

output "rds_secret_arn" {
  value       = module.rds.db_secret_arn
  description = "ARN of the Secrets Manager secret holding the RDS password"
}
