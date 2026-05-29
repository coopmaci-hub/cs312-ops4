terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}


provider "aws" {
  region = "us-east-1"
  # If you configured a named profile above, add: profile = "cs312"
  profile = "cs312"
}

# Use the default VPC instead of creating a new one
data "aws_vpc" "default" {
  default = true
}


# Security Group for the managed node: SSH from control node only, HTTP from anywhere
resource "aws_security_group" "k3s" {
  name        = "cs312-tf-k3s-sg"
  description = "SSH from laptop, TCP from 25565 from anywhere"
  vpc_id      = data.aws_vpc.default.id

    ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["71.237.219.225/32"]
    }

  ingress {
    description = "player"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cs312-tf-k3s-sg"
  }
}

# Managed node: the server that will run the application
resource "aws_instance" "k3s" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k3s.id]
  iam_instance_profile   = "LabInstanceProfile"

  root_block_device {
    volume_size = 20
  }
  
  tags = {
    Name = "cs312-tf-k3s"
  }
}

# ECR repository for the CI/CD pipeline in Lab 6
resource "aws_ecr_repository" "minecraft" {
  name                 = "cs312-minecraft"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}


resource "null_resource" "ansible_provision" {

  depends_on = [
    aws_instance.k3s,
    local_file.inventory
  ]

  provisioner "local-exec" {
    command = "sleep 60 && chmod 400 newkey.pem && ansible-playbook -i inventory.ini playbook.yml --private-key ./newkey.pem"
  }
}

resource "local_file" "inventory" {
  filename = "${path.module}/inventory.ini"

  content = <<EOT
[minecraft]
${aws_instance.k3s.public_ip} ansible_user=ubuntu

EOT
}