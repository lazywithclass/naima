variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  type    = string
  default = "naima"
}

variable "instance_type" {
  description = <<-EOT
    t3.medium (2 vCPU, 4 GB) is the recommended minimum.
    Runs NixOS + Docker + Node.js (Claude Code) concurrently.
    ~$0.042/hr in eu-west-1. t3 burst credits recover faster than t2.
  EOT
  type    = string
  default = "t3.medium"
}

variable "nixos_ami_id" {
  description = <<-EOT
    NixOS 24.11 x86_64 HVM AMI for your region.
    Find the latest: https://nixos.org/download/#nixos-amazon
    No default — must be set explicitly to avoid silent region mismatches.
  EOT
  type = string
}

variable "ssh_public_key" {
  description = "Contents of ~/.ssh/id_ed25519.pub (or equivalent)"
  type        = string
}

variable "root_volume_gb" {
  description = "EBS root volume size. NixOS needs headroom for closures."
  type        = number
  default     = 30
}

variable "repo_url" {
  description = "SSH clone URL, e.g. git@github.com:org/repo.git"
  type        = string
}

variable "repo_branch" {
  description = "Branch to clone"
  type        = string
  default     = "master"
}
