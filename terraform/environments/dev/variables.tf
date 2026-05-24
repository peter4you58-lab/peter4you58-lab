variable "region"          { default = "us-east-1" }
variable "environment"     { default = "dev" }
variable "vpc_cidr"        { default = "10.0.0.0/16" }
variable "allowed_cidr_blocks" { default = ["0.0.0.0/0"] }
variable "key_name"        { description = "EC2 key pair name for SSH access" }
variable "ecr_account_id"  { description = "AWS account ID" }