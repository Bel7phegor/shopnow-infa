# VPC
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "nat_public_ips" {
  value = var.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
}

# EKS
output "eks_cluster_name" {
  value = var.enable_eks ? aws_eks_cluster.main[0].name : null
}

output "eks_cluster_endpoint" {
  value = var.enable_eks ? aws_eks_cluster.main[0].endpoint : null
}

output "eks_cluster_version" {
  value = var.enable_eks ? aws_eks_cluster.main[0].version : null
}

output "eks_endpoint_access_mode" {
  value = var.enable_eks ? var.eks_endpoint_access : null
}

output "nodegroup_status" {
  value = local.should_create_nodegroup ? aws_eks_node_group.main[0].status : "disabled"
}

# BASTION
output "bastion_private_ip" {
  value = local.should_create_bastion ? aws_instance.bastion[0].private_ip : null
}

# GITHUB RUNNER
output "github_runner_public_ip" {
  description = "IP để SSH vào runner và chạy config.sh"
  value       = local.should_create_runner ? aws_instance.github_runner[0].public_ip : null
}

output "github_runner_instance_id" {
  value = local.should_create_runner ? aws_instance.github_runner[0].id : null
}

# USEFUL COMMANDS
output "kubeconfig_command" {
  description = "Chạy lệnh này để kết nối kubectl vào cluster"
  value       = var.enable_eks ? "aws eks update-kubeconfig --region ${var.region} --name ${var.eks_cluster_name}" : null
}
