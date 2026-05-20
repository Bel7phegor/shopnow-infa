# ShopNow Infrastructure (AWS & Terraform)

This repository contains the Infrastructure as Code (IaC) definitions for the **ShopNow** project. It leverages **Terraform** to provision and manage highly available AWS resources, including Amazon EKS, VPC networking, Bastion hosts, and Self-hosted GitHub Actions Runners.

---

## Directory Structure

```hcl
shopnow-infra/
├── main.tf             # Provider configurations & S3 Backend definition
├── variables.tf        # Input variable declarations
├── local.tf            # Computed local values
├── vpc.tf              # VPC, Subnets, and Network ACLs
├── igw.tf              # Internet Gateway
├── nat.tf              # NAT Gateway & Elastic IPs
├── routes.tf           # Route tables and associations
├── sg.tf               # Security Groups
├── eks.tf              # EKS Cluster, IAM roles, and OIDC access
├── nodegroup.tf        # EKS Managed Node Groups
├── bastion.tf          # Bastion EC2 instance (kubectl host)
├── runner.tf           # EC2 instance for Self-hosted GitHub Actions Runner
├── cleanup.tf          # Cleanup scripts (e.g., Target Groups/NLB upon destroy)
├── outputs.tf          # Output values (IPs, Kubeconfig, etc.)
└── environments/       # Environment-specific configurations
    ├── dev/
    │   └── terraform.tfvars  # Development environment variables
    └── prod/
        └── terraform.tfvars  # Production environment variables
```

---

## Automated CI/CD (GitOps)

This repository is powered by **GitHub Actions** for automated deployments:
* **Push to `develop` branch**: Automatically plans and applies infrastructure changes to the **DEV** environment.
* **Push a Tag (e.g., `v1.0.0`)**: Plans changes for **PROD** and waits for Manual Approval before applying.
* **Manual Trigger (Destroy)**: Dedicated workflow to safely tear down environments using `terraform destroy`.

---

## Manual Operations

If you need to run Terraform locally, follow the steps below.

### 1. Initial Setup (S3 Backend & State Locking)
Run these commands **only once** to set up the remote backend for storing Terraform state files.

```bash
# Create S3 bucket for storing tfstate
aws s3 mb s3://shopnow-terraform-state --region ap-southeast-3

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name shopnow-terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-3
```

### 2. Deploy Development Environment
```bash
# Initialize Terraform with DEV state key
terraform init -backend-config="key=dev/terraform.tfstate"

# Review execution plan
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply infrastructure changes
terraform apply -var-file=environments/dev/terraform.tfvars
```

### 3. Deploy Production Environment
```bash
# Reconfigure backend to use PROD state key
terraform init -reconfigure -backend-config="key=prod/terraform.tfstate"

# Review execution plan
terraform plan -var-file=environments/prod/terraform.tfvars

# Apply infrastructure changes
terraform apply -var-file=environments/prod/terraform.tfvars
```

---

## Post-Deployment Configurations

### Connecting to Amazon EKS (`kubectl`)
Once the deployment is complete, fetch the cluster configuration:

```bash
# Get the kubeconfig update command from Terraform outputs
terraform output kubeconfig_command

# Execute the output command, for example:
aws eks update-kubeconfig --region ap-southeast-3 --name shopnow-dev-eks

# Verify connection
kubectl get nodes
```

### Setting up the Self-hosted GitHub Runner
*(Run this once after the EC2 runner instance is provisioned)*

```bash
# 1. Get the Runner's Public IP
RUNNER_IP=$(terraform output -raw github_runner_public_ip)

# 2. SSH into the Runner EC2
ssh -i key-pem.pem ubuntu@$RUNNER_IP

# 3. Download and Configure the GitHub Actions Agent
mkdir -p /home/ubuntu/actions-runner && cd /home/ubuntu/actions-runner
RUNNER_VERSION="2.317.0"

curl -o runner.tar.gz -L \
  [https://github.com/actions/runner/releases/download/v$](https://github.com/actions/runner/releases/download/v$){RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
tar xzf runner.tar.gz

# Note: Generate YOUR_TOKEN_FROM_GITHUB from: 
# GitHub Repo → Settings → Actions → Runners → New self-hosted runner
./config.sh \
  --url [https://github.com/Bel7phegor/shopnow-frontend](https://github.com/Bel7phegor/shopnow-frontend) \
  --token YOUR_TOKEN_FROM_GITHUB \
  --name fe-runner-dev \
  --labels self-hosted,fe-runner-dev \
  --work _work \
  --unattended

# 4. Install and Start the runner service
sudo ./svc.sh install
sudo ./svc.sh start
```

---

## Cost Optimization (Temporary Teardown)

To save costs during off-hours, you can spin down the EKS Cluster, Node Groups, and Bastion host while keeping the VPC and Runner intact.

```bash
# Spin down EKS & Bastion
terraform apply \
  -var-file=environments/dev/terraform.tfvars \
  -var="enable_eks=false" \
  -var="enable_bastion=false"

# Bring them back online
terraform apply -var-file=environments/dev/terraform.tfvars
```