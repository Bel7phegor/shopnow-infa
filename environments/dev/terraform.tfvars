# DEV environment
# terraform -chdir=../.. apply -var-file=terraform.tfvars

project     = "shopnow"
environment = "dev"
region      = "ap-southeast-3"

# VPC
vpc_name = "shopnow-dev"
vpc_cidr = "10.0.0.0/16"

public_subnets = [
  { cidr = "10.0.1.0/24", az = "ap-southeast-3a", name = "public-3a" },
  { cidr = "10.0.2.0/24", az = "ap-southeast-3b", name = "public-3b" }
]

private_subnets = [
  { cidr = "10.0.11.0/24", az = "ap-southeast-3a", name = "private-3a" },
  { cidr = "10.0.12.0/24", az = "ap-southeast-3b", name = "private-3b" }
]

# NAT 
single_nat_gateway = true

# EKS
enable_eks          = true
eks_cluster_name    = "shopnow-dev-eks"
eks_cluster_version = "1.35"
eks_endpoint_access = "public_and_private"
enable_eks_auto_mode = false

# Node group
enable_nodegroup             = true
nodegroup_name               = "shopnow-dev-nodegroup"
nodegroup_instance_types     = ["t3.medium"]
nodegroup_desired_size       = 1
nodegroup_min_size           = 1
nodegroup_max_size           = 3
nodegroup_disk_size          = 20
enable_node_auto_repair      = true

# Dev: bật remote access để dễ debug node
enable_node_remote_access    = true
nodegroup_ssh_key_name       = "key-pem"

# Update config
nodegroup_max_unavailable_type  = "number"
nodegroup_max_unavailable_value = 1

# Bastion — để kubectl vào EKS (private subnet)
enable_bastion         = true
bastion_instance_type  = "t3.small"  
bastion_key_name       = "key-pem"

# IAM roles (tạo tay trước)
eks_cluster_role_name      = "eks-cluster-role"
eks_nodegroup_role_name    = "eks-nodegroup-role"
bastion_instance_role_name = "ec2-eks-access-role"

# GitHub Runner EC2
enable_github_runner        = true
github_runner_instance_type = "t3.medium"
github_runner_key_name      = "key-pem"
github_runner_label         = "fe-runner-dev"
github_runner_role_name     = "github-runner-role"
