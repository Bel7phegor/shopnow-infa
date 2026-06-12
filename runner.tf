# IAM role cho runner EC2 (data source — tạo tay trước)
data "aws_iam_role" "github_runner" {
  count = local.should_create_runner ? 1 : 0
  name  = var.github_runner_role_name
}

resource "aws_iam_instance_profile" "github_runner" {
  count = local.should_create_runner ? 1 : 0
  name  = "${var.project}-github-runner-profile-${var.environment}"
  role  = data.aws_iam_role.github_runner[0].name

  tags = merge(local.common_tags, {
    Name      = "${var.project}-github-runner-profile-${var.environment}"
    Component = "github-runner"
  })
}

resource "aws_security_group" "github_runner" {
  count       = local.should_create_runner ? 1 : 0
  name        = "${var.project}-runner-sg-${var.environment}"
  description = "GitHub Actions runner EC2"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, {
    Name      = "${var.project}-runner-sg-${var.environment}"
    Component = "github-runner"
  })
}

resource "aws_instance" "github_runner" {
  count                  = local.should_create_runner ? 1 : 0
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.github_runner_instance_type
  subnet_id              = aws_subnet.public[0].id # public để outbound poll GitHub
  vpc_security_group_ids = [aws_security_group.github_runner[0].id]
  iam_instance_profile   = aws_iam_instance_profile.github_runner[0].name
  key_name               = var.github_runner_key_name != "" ? var.github_runner_key_name : null

  user_data = <<-USERDATA
    #!/bin/bash
    set -e
    exec > >(tee /var/log/userdata.log | logger -t userdata -s 2>/dev/console) 2>&1

    apt-get update -y
    apt-get install -y curl unzip wget git jq

    # Docker
    curl -fsSL https://get.docker.com | bash
    usermod -aG docker ubuntu
    systemctl enable docker
    systemctl start docker

    # AWS CLI
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws

    # kubectl
    curl -fLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl

    # Helm
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    useradd -m -s /bin/bash github-runner || true
    usermod -aG docker github-runner
    mkdir -p /home/github-runner/actions-runner
    chown -R github-runner:github-runner /home/github-runner

    echo "Userdata complete — instance is ready to be configured as GitHub Actions runner"
  USERDATA

  tags = merge(local.common_tags, {
    Name         = "${var.project}-github-runner-${var.environment}"
    Component    = "github-runner"
    RunnerLabel  = var.github_runner_label
    OS           = "ubuntu-22.04"
    InstanceType = var.github_runner_instance_type
  })
}