variable "region" {
  type    = string
  default = "ap-southeast-3"
}

variable "project" {
  type    = string
  default = "shopnow"
}

variable "environment" {
  description = "dev | staging | prod"
  type        = string
  default     = "dev"
}

# VPC
variable "vpc_name" {
  type    = string
  default = "shopnow"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "enable_dns_support" {
  type    = bool
  default = true
}

variable "enable_dns_hostnames" {
  type    = bool
  default = true
}

variable "map_public_ip_on_launch" {
  type    = bool
  default = true
}

variable "public_subnets" {
  type = list(object({
    cidr = string
    az   = string
    name = string
  }))
}

variable "private_subnets" {
  type = list(object({
    cidr = string
    az   = string
    name = string
  }))
}

# IGW / NAT
variable "enable_igw" {
  type    = bool
  default = true
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "single_nat_gateway" {
  description = "true = 1 NAT dùng chung (dev) | false = mỗi AZ 1 NAT (prod)"
  type        = bool
  default     = true
}

# IAM ROLES 
variable "eks_cluster_role_name" {
  type    = string
  default = "eks-cluster-role"
}

variable "eks_nodegroup_role_name" {
  type    = string
  default = "eks-nodegroup-role"
}

variable "bastion_instance_role_name" {
  type    = string
  default = "ec2-eks-access-role"
}

# EKS
variable "enable_eks" {
  description = "Bật/tắt toàn bộ EKS cluster"
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  type    = string
  default = "shopnow-eks"
}

variable "eks_cluster_version" {
  type    = string
  default = "1.35"
}

variable "enable_eks_auto_mode" {
  description = "true = AWS quản lý node hoàn toàn | false = tự quản lý node group"
  type        = bool
  default     = false
}

variable "eks_endpoint_access" {
  description = "public | private | public_and_private"
  type        = string
  default     = "public_and_private"

  validation {
    condition     = contains(["public", "private", "public_and_private"], var.eks_endpoint_access)
    error_message = "Giá trị hợp lệ: public | private | public_and_private"
  }
}

# NODE GROUP
variable "enable_nodegroup" {
  type    = bool
  default = true
}

variable "nodegroup_name" {
  type    = string
  default = "shopnow-nodegroup"
}

variable "nodegroup_update_strategy" {
  description = "Default | Minimal"
  type        = string
  default     = "Default"

  validation {
    condition     = contains(["Default", "Minimal"], var.nodegroup_update_strategy)
    error_message = "Giá trị hợp lệ: Default | Minimal"
  }
}

variable "nodegroup_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "nodegroup_desired_size" {
  type    = number
  default = 2
}

variable "nodegroup_min_size" {
  type    = number
  default = 1
}

variable "nodegroup_max_size" {
  type    = number
  default = 4
}

variable "nodegroup_disk_size" {
  type    = number
  default = 20
}

variable "nodegroup_max_unavailable_type" {
  description = "number | percentage"
  type        = string
  default     = "number"

  validation {
    condition     = contains(["number", "percentage"], var.nodegroup_max_unavailable_type)
    error_message = "Giá trị hợp lệ: number | percentage"
  }
}

variable "nodegroup_max_unavailable_value" {
  type    = number
  default = 1
}

variable "enable_node_auto_repair" {
  type    = bool
  default = true
}

variable "enable_node_remote_access" {
  description = "Bật SSH vào node — chỉ nên bật ở dev để debug"
  type        = bool
  default     = false
}

variable "nodegroup_ssh_key_name" {
  type    = string
  default = ""
}

variable "nodegroup_remote_access_sg_ids" {
  type    = list(string)
  default = []
}

# BASTION
variable "enable_bastion" {
  type    = bool
  default = true
}

variable "bastion_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "bastion_key_name" {
  type    = string
  default = ""
}

variable "bastion_eks_access_policy_arn" {
  type    = string
  default = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
}

variable "acm_certificate_arn" {
  description = "ARN của ACM certificate cho HTTPS ingress"
  type        = string
  default     = ""
}

# GITHUB RUNNER EC2
variable "enable_github_runner" {
  description = "Bật/tắt EC2 GitHub Actions runner"
  type        = bool
  default     = true
}

variable "github_runner_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "github_runner_key_name" {
  type    = string
  default = ""
}

variable "github_runner_label" {
  description = "Label của runner dùng trong runs-on. Dev: fe-runner-dev, prod: fe-runner-prod"
  type        = string
  default     = "fe-runner-dev"
}

variable "github_runner_role_name" {
  description = "IAM Role gắn vào runner EC2 — cần quyền ECR push, EKS access"
  type        = string
  default     = "github-runner-role"
}
