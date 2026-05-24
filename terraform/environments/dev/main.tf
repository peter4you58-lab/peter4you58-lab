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
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "devops-portfolio"
      Environment = "dev"
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

module "k3s" {
  source      = "../../modules/k3s-server"
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  subnet_id   = module.vpc.public_subnet_ids[0]
  key_name    = var.key_name
  aws_region  = var.region
  ecr_account = var.ecr_account_id
}

output "k3s_public_ip" { value = module.k3s.k3s_public_ip }