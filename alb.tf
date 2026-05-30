
# ALB SECURITY GROUP
resource "aws_security_group" "alb" {
  count       = local.should_create_alb ? 1 : 0
  name        = "${var.project}-alb-sg"
  description = "ALB: allow HTTP/HTTPS from internet, egress to nodes NodePort"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ALB chỉ egress vào nodes trên đúng NodePort 30080
  egress {
    description     = "Forward to ingress-nginx NodePort"
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes[0].id]
  }

  # Health check port
  egress {
    description     = "Health check to ingress-nginx"
    from_port       = 10254
    to_port         = 10254
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes[0].id]
  }

  tags = merge(local.common_tags, {
    Name      = "${var.project}-alb-sg"
    Component = "alb"
  })
}

# ─────────────────────────────────────────────
# APPLICATION LOAD BALANCER
# ─────────────────────────────────────────────
resource "aws_lb" "main" {
  count              = local.should_create_alb ? 1 : 0
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = aws_subnet.public[*].id

  # Bật access log nếu cần debug
  # access_logs {
  #   bucket  = "shopnow-alb-logs"
  #   enabled = true
  # }

  tags = merge(local.common_tags, {
    Name      = "${var.project}-alb"
    Component = "alb"
  })
}

# ─────────────────────────────────────────────
# TARGET GROUP → ingress-nginx NodePort 30080
# ─────────────────────────────────────────────
resource "aws_lb_target_group" "nginx" {
  count       = local.should_create_alb ? 1 : 0
  name        = "${var.project}-nginx-tg"
  port        = 30080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance" # forward theo EC2 instance + NodePort

  health_check {
    enabled             = true
    path                = "/healthz"
    port                = "10254" # ingress-nginx health check port
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name      = "${var.project}-nginx-tg"
    Component = "alb"
  })
}

# ─────────────────────────────────────────────
# LISTENER: HTTP 80 → redirect HTTPS 443
# ─────────────────────────────────────────────
resource "aws_lb_listener" "http" {
  count             = local.should_create_alb ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.common_tags, {
    Name      = "${var.project}-alb-http-listener"
    Component = "alb"
  })
}

# ─────────────────────────────────────────────
# LISTENER: HTTPS 443 → forward → nginx TG
# ─────────────────────────────────────────────
resource "aws_lb_listener" "https" {
  count             = local.should_create_alb ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx[0].arn
  }

  tags = merge(local.common_tags, {
    Name      = "${var.project}-alb-https-listener"
    Component = "alb"
  })
}

# ─────────────────────────────────────────────
# AUTO SCALING ATTACHMENT
# Gắn ASG của node group vào Target Group
# → ALB tự động biết instances nào cần forward
# ─────────────────────────────────────────────
resource "aws_autoscaling_attachment" "nginx" {
  count = local.should_create_alb ? 1 : 0

  autoscaling_group_name = aws_eks_node_group.main[0].resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.nginx[0].arn
}
