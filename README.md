# shopnow-infra — Hướng dẫn sử dụng

## Cấu trúc

```
shopnow-infra/
  main.tf          # Provider, S3 backend
  variables.tf     # Khai báo tất cả biến
  local.tf         # Computed locals
  vpc.tf           # VPC, subnets
  igw.tf           # Internet Gateway
  nat.tf           # NAT Gateway + EIP
  routes.tf        # Route tables
  sg.tf            # Security groups
  eks.tf           # EKS cluster + access
  nodegroup.tf     # EKS node group
  bastion.tf       # Bastion EC2 (kubectl host)
  runner.tf        # GitHub Actions runner EC2
  cleanup.tf       # Cleanup NLB khi destroy
  outputs.tf       # Output values
  environments/
    dev/
      terraform.tfvars    # Config cho dev
    prod/
      terraform.tfvars    # Config cho prod
```

---

## Lần đầu setup — tạo S3 backend

```bash
# Chỉ chạy 1 lần duy nhất
aws s3 mb s3://shopnow-terraform-state --region ap-southeast-3

aws dynamodb create-table \
  --table-name shopnow-terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-3
```

---

## Deploy Dev environment

```bash
# Init với state key riêng cho dev
terraform init \
  -backend-config="key=dev/terraform.tfstate"

# Xem những gì sẽ thay đổi
terraform plan \
  -var-file=environments/dev/terraform.tfvars

# Apply
terraform apply \
  -var-file=environments/dev/terraform.tfvars
```

---

## Deploy Prod environment

```bash
# Init với state key riêng cho prod (không dùng chung với dev)
terraform init -reconfigure \
  -backend-config="key=prod/terraform.tfstate"

terraform plan  -var-file=environments/prod/terraform.tfvars
terraform apply -var-file=environments/prod/terraform.tfvars
```

---

## Sau khi terraform apply xong

### 1. Kết nối kubectl vào EKS

```bash
# Lấy command từ output
terraform output kubeconfig_command

# Chạy command đó, ví dụ:
aws eks update-kubeconfig --region ap-southeast-3 --name shopnow-dev-eks
kubectl get nodes
```

### 2. Cài runner agent lên EC2 runner (chỉ làm 1 lần)

```bash
# Lấy IP từ output
RUNNER_IP=$(terraform output -raw github_runner_public_ip)

# SSH vào runner
ssh -i key-pem.pem ubuntu@$RUNNER_IP

# Trong runner EC2:
cd /home/github-runner/actions-runner
RUNNER_VERSION="2.317.0"
curl -o runner.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
tar xzf runner.tar.gz

# Lấy token từ: GitHub repo → Settings → Actions → Runners → New self-hosted runner
./config.sh \
  --url https://github.com/Bel7phegor/shopnow-frontend \
  --token YOUR_TOKEN_FROM_GITHUB \
  --name fe-runner-dev \
  --labels self-hosted,fe-runner-dev \
  --work _work \
  --unattended

sudo ./svc.sh install
sudo ./svc.sh start
```

### 3. Import EC2 runner đang có vào Terraform state

Nếu bạn đã có EC2 runner tạo tay, import vào thay vì tạo mới:

```bash
terraform import aws_instance.github_runner[0] i-0xxxxxxxxxxxxxxxxx
```

---

## Tắt EKS

```bash
# Tắt EKS + nodegroup + bastion, giữ VPC + runner
terraform apply \
  -var-file=environments/dev/terraform.tfvars \
  -var="enable_eks=false" \
  -var="enable_bastion=false"

# Bật lại
terraform apply \
  -var-file=environments/dev/terraform.tfvars
```
