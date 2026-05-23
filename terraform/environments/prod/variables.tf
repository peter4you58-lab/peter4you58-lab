variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.1.0.0/16" # Non-overlapping with dev (10.0.0.0/16)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the EKS public API endpoint"
  type        = list(string)
  # Tighten this to your VPN / bastion IP in production
  default = ["0.0.0.0/0"]
}
