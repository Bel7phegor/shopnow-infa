# PROD environment
# terraform -chdir=../.. apply -var-file=terraform.tfvars
project     = "shopnow"
environment = "prod"
region      = "ap-southeast-3"

# VPC — CIDR
vpc_name = "shopnow-prod"
vpc_cidr = "10.1.0.0/16"

public_subnets = [
  { cidr = "10.1.1.0/24", az = "ap-southeast-3a", name = "public-3a" },
  { cidr = "10.1.2.0/24", az = "ap-southeast-3b", name = "public-3b" }
]

private_subnets = [
  { cidr = "10.1.11.0/24", az = "ap-southeast-3a", name = "private-3a" },
  { cidr = "10.1.12.0/24", az = "ap-southeast-3b", name = "private-3b" }
]

# NAT — mỗi AZ 1 NAT để HA (nếu 1 AZ lỗi, AZ kia vẫn đi internet được)
single_nat_gateway = false

# EKS
enable_eks           = true
eks_cluster_name     = "shopnow-prod-eks"
eks_cluster_version  = "1.35"
eks_endpoint_access  = "private" # prod: chỉ truy cập nội bộ VPC
enable_eks_auto_mode = false

# Node group
enable_nodegroup         = true
nodegroup_name           = "shopnow-prod-nodegroup"
nodegroup_instance_types = ["t3.large"]
nodegroup_desired_size   = 3
nodegroup_min_size       = 2
nodegroup_max_size       = 6
nodegroup_disk_size      = 30
enable_node_auto_repair  = true

# Prod: TẮT remote access — không ai SSH vào node production
enable_node_remote_access = false
nodegroup_ssh_key_name    = ""

# Update config — percentage để rolling update mượt hơn
nodegroup_max_unavailable_type  = "percentage"
nodegroup_max_unavailable_value = 25

# Bastion — prod bastion nhỏ thôi, chỉ để kubectl khẩn cấp
enable_bastion        = true
bastion_instance_type = "t3.small"
bastion_key_name      = "key-pem"

# IAM roles
eks_cluster_role_name      = "eks-cluster-role"
eks_nodegroup_role_name    = "eks-nodegroup-role"
bastion_instance_role_name = "ec2-eks-access-role"

# GitHub Runner EC2
enable_github_runner        = false
github_runner_instance_type = "t3.large"
github_runner_key_name      = "key-pem-prod"
github_runner_label         = "fe-runner-prod"
github_runner_role_name     = "github-runner-role-prod"

# ACM certificate https
acm_certificate_arn = "arn:aws:acm:ap-southeast-3:250830191861:certificate/xxx"