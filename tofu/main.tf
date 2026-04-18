terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Operator IP ────────────────────────────────────────────────────────────────

data "http" "my_ip" {
  url = "https://ifconfig.me/ip"
}

locals {
  operator_cidr = "${trimspace(data.http.my_ip.response_body)}/32"
}

# ── VPC ───────────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags = { Name = "${var.project_name}-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project_name}-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ── Security Group ─────────────────────────────────────────────────────────────
# SSH only for colmena deploys. Claude Code Remote Control uses outbound HTTPS
# only — it needs no inbound ports whatsoever.

resource "aws_security_group" "instance" {
  name        = "${var.project_name}-sg"
  description = "NixOS colmena instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from operator (colmena deploy)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.operator_cidr]
  }

  egress {
    description = "All outbound (HTTPS to Anthropic relay + npm registry + GitHub)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg" }
}

# ── SSH Key ────────────────────────────────────────────────────────────────────

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

# ── EC2 Instance ───────────────────────────────────────────────────────────────

resource "aws_instance" "main" {
  ami                    = var.nixos_ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name               = aws_key_pair.deployer.key_name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gb
    encrypted   = true
  }

  tags = { Name = var.project_name }
}

# ── Elastic IP ─────────────────────────────────────────────────────────────────
# Stable IP across stop/start. Avoids re-sealing credentials every time.

resource "aws_eip" "main" {
  instance = aws_instance.main.id
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-eip" }
}

# ── Deploy Key ─────────────────────────────────────────────────────────────────
# Auto-generated ed25519 key pair. Private key lives only in tofu state.

resource "tls_private_key" "deploy" {
  algorithm = "ED25519"
}

# ── Generated Files ────────────────────────────────────────────────────────────

resource "local_file" "instance_ip" {
  content  = aws_eip.main.public_ip
  filename = "${path.module}/../secrets/instance-ip.txt"
}

resource "local_file" "deploy_key_pub" {
  content  = tls_private_key.deploy.public_key_openssh
  filename = "${path.module}/../secrets/deploy-key.pub"
}

resource "local_file" "repo_config" {
  content = jsonencode({
    url    = var.repo_url
    branch = var.repo_branch
  })
  filename = "${path.module}/../secrets/repo-config.json"
}

# ── Provision ──────────────────────────────────────────────────────────────────
# Seals deploy key + placeholder session token on the instance, then runs colmena.

resource "null_resource" "provision" {
  depends_on = [local_file.instance_ip, local_file.repo_config, local_file.deploy_key_pub]

  triggers = {
    instance_id = aws_instance.main.id
  }

  provisioner "local-exec" {
    command     = "${path.module}/../scripts/provision.sh"
    environment = {
      INSTANCE_IP = aws_eip.main.public_ip
      DEPLOY_KEY  = tls_private_key.deploy.private_key_openssh
    }
  }
}

# ── Outputs ────────────────────────────────────────────────────────────────────

output "instance_ip" {
  description = "Public IP of the instance"
  value       = aws_eip.main.public_ip
}

output "deploy_key_public" {
  description = "Add this key to GitHub -> repo -> Settings -> Deploy keys"
  value       = tls_private_key.deploy.public_key_openssh
}

output "next_steps" {
  description = "Post-apply instructions"
  value       = <<-EOT

    1. Add deploy key to GitHub:
         tofu output deploy_key_public
       Copy the key to: GitHub -> repo -> Settings -> Deploy keys

    2. Restart git-clone to pick up the key:
         ssh root@${aws_eip.main.public_ip} systemctl restart git-clone-project

    3. Activate Claude session:
         ./scripts/activate-session.sh
  EOT
}
