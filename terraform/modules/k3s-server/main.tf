variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "key_name" { type = string }
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "ecr_account" { type = string }

resource "aws_iam_role" "k3s" {
  name = "${var.environment}-k3s-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.k3s.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "k3s" {
  name = "${var.environment}-k3s-profile"
  role = aws_iam_role.k3s.name
}

resource "aws_security_group" "k3s" {
  name   = "${var.environment}-k3s-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.environment}-k3s-sg" }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "k3s" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.k3s.id]
  iam_instance_profile        = aws_iam_instance_profile.k3s.name
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = <<-USERDATA
    #!/bin/bash
    apt-get update -y
    apt-get install -y curl unzip
    curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
    systemctl enable k3s
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
  USERDATA

  tags = {
    Name        = "${var.environment}-k3s-server"
    Environment = var.environment
  }
}

resource "aws_eip" "k3s" {
  instance = aws_instance.k3s.id
  domain   = "vpc"
  tags     = { Name = "${var.environment}-k3s-eip" }
}

output "k3s_public_ip" { value = aws_eip.k3s.public_ip }
output "k3s_instance_id" { value = aws_instance.k3s.id }