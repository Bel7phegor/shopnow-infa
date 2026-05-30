resource "aws_security_group" "eks_cluster" {
  count       = var.enable_eks ? 1 : 0
  name        = "${var.eks_cluster_name}-cluster-sg"
  description = "EKS control plane security group"
  vpc_id      = aws_vpc.main.id

  # Nodes → Control plane (HTTPS)
  ingress {
    description     = "Nodes to control plane"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes[0].id]
  }

  # Bastion → Control plane (HTTPS)
  dynamic "ingress" {
    for_each = local.should_create_bastion ? [1] : []
    content {
      description     = "Bastion to control plane"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      security_groups = [aws_security_group.bastion[0].id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name      = "${var.eks_cluster_name}-cluster-sg"
    Component = "eks-cluster"
  })
}

# EKS NODES SECURITY GROUP
resource "aws_security_group" "eks_nodes" {
  count       = var.enable_eks ? 1 : 0
  name        = "${var.eks_cluster_name}-nodes-sg"
  description = "EKS worker nodes security group"
  vpc_id      = aws_vpc.main.id

  # Node ↔ Node (all traffic)
  ingress {
    description = "Node to node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "Control plane to nodes (kubelet, metrics, exec)"
    from_port   = 1025
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Bastion → Nodes (all traffic, để debug)
  dynamic "ingress" {
    for_each = local.should_create_bastion ? [1] : []
    content {
      description     = "Bastion to nodes"
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      security_groups = [aws_security_group.bastion[0].id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name      = "${var.eks_cluster_name}-nodes-sg"
    Component = "eks-nodegroup"
  })
}

# BASTION SECURITY GROUP
resource "aws_security_group" "bastion" {
  count       = local.should_create_bastion ? 1 : 0
  name        = "${var.project}-bastion-sg"
  description = "Bastion EC2 security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from within VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name      = "${var.project}-bastion-sg"
    Component = "bastion"
  })
}

resource "aws_security_group_rule" "alb_to_eks_auto_nodes_http" {
  count                    = var.enable_eks && local.should_create_alb ? 1 : 0
  type                     = "ingress"
  from_port                = 30080
  to_port                  = 30080
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.alb[0].id
  description              = "ALB to ingress-nginx NodePort HTTP"
}
