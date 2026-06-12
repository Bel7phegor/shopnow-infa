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
  description = "true = 1 NAT used in common (dev) | false = each AZ has 1 NAT (prod)"
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
  description = "Enable/disable all EKS cluster"
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
  description = "true = AWS manager node completely | false = self-manage node group"
  type        = bool
  default     = false
}

variable "eks_endpoint_access" {
  description = "public | private | public_and_private"
  type        = string
  default     = "public_and_private"

  validation {
    condition     = contains(["public", "private", "public_and_private"], var.eks_endpoint_access)
    error_message = "Valid values: public | private | public_and_private"
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
    error_message = "Valid values: Default | Minimal"
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
    error_message = "Valid values: number | percentage"
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
  description = "Enable SSH access to nodes — should be enable only for dev, disable for prod"
  type        = bool
  default     = false
}

variable "nodegroup_ssh_key_name" {
  type    = string
  default = "key-pem"
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

# ACM / ALB
variable "acm_certificate_arn" {
  description = "The ARN of the ACM certificate for HTTPS — must be in the same region as the ALB"
  type        = string
  default     = "arn:aws:acm:ap-southeast-3:250830191861:certificate/d116056f-d39c-4a78-a7a4-d9f7dacde7dc"
}

variable "enable_alb" {
  description = "Enable/disable ALB — automatically disabled if node group is not created"
  type        = bool
  default     = true
}

# GITHUB RUNNER EC2
variable "enable_github_runner" {
  description = "Enable/disable EC2 GitHub Actions runner"
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
  description = "The runner's label is used in runs-on. Dev: fe-runner-dev, prod: fe-runner-prod"
  type        = string
  default     = "fe-runner-dev"
}

variable "github_runner_role_name" {
  description = "The IAM Role is attached to the EC2 runner — requires ECR push and EKS access permissions."
  type        = string
  default     = "github-runner-role"
}
