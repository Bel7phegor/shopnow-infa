# ShopNow Infrastructure as Code (IaC) Reference Architecture

## Project Overview and Architecture

This repository contains the enterprise-grade Infrastructure as Code (IaC) codebase for the ShopNow application platform. Driven entirely by HashiCorp Terraform, this project provisions a secure, highly available, and resilient infrastructure ecosystem on Amazon Web Services (AWS) tailored for containerized application deployments.

The primary objective of this codebase is to deliver a reliable, repeatable cloud foundation capable of supporting both development (dev) and production (prod) microservices environments.

### Key Architectural Pillars

* **Network Isolation**: A custom Virtual Private Cloud (VPC) spanning multiple Availability Zones (AZs). It enforces strict network partitioning into public subnets (hosting the Application Load Balancer and NAT Gateways) and private subnets (hosting the EKS data plane, database targets, and private workloads).
* **Managed Kubernetes Platform**: An Amazon Elastic Kubernetes Service (EKS) cluster utilizing modern EKS Access Entries (API-driven authentication) and EKS Managed Node Groups with automated scaling, node health checks, and secure runtime boundaries.
* **Secure Access Control**: Complete network protection via modular Security Groups isolating control planes, compute nodes, load balancers, and administrative entrypoints. Zero external SSH access is permitted to the private cluster nodes except via a hardened, internal Bastion host or secure networks.
* **Administrative and CI/CD Automation**: Integrated, specialized EC2 hosts executing as self-hosted GitHub Actions runners inside the VPC network boundary to optimize CI/CD pipeline speeds, alongside a Bastion Host pre-configured with Kubernetes management utilities (`kubectl`, `helm`, `ingress-nginx`).
* **State Management and Locking**: Remote Terraform state archiving utilizing Amazon S3 for durable object storage coupled with Amazon DynamoDB tables for distributed state execution locks to eliminate concurrent configuration deployment conflicts.

---

## Directory Structure

```text
shopnow-infra/
├── .github/
│   └── workflows/
│       ├── terraform-ci.yml        # CI/CD pipeline for automated planning and multi-stage execution
│       └── terraform-destroy.yml   # Protected workflow for automated environment decommissioning
├── environments/
│   ├── dev/
│   │   └── terraform.tfvars        # Input variable definitions tailored for the Development cluster
│   └── prod/
│       └── terraform.tfvars        # Input variable definitions tailored for the Production cluster
├── alb.tf                          # Application Load Balancer, Target Groups, and HTTPS Listeners
├── bastion.tf                      # Bastion Host EC2 provisioning and Kubernetes tooling bootstrapping
├── cleanup.tf                      # Automation hooks for network and resource cleanup upon environment destruction
├── eks.tf                          # EKS Control Plane, Identity Providers, and Access Policies
├── igw.tf                          # AWS Internet Gateway mapping for public edge subnets
├── local.tf                        # Centralized local expression definitions and tagging semantics
├── main.tf                         # Core Terraform providers and remote S3/DynamoDB backend layout
├── nat.tf                          # AWS NAT Gateways and Elastic IPs mapping for egress route paths
├── nodegroup.tf                    # AWS EKS Managed Node Groups computing scaling rules
├── outputs.tf                      # Structural output metrics definition for post-deployment consumption
├── README.md                       # Product reference documentation
├── routes.tf                       # Route Tables and Route Table Associations for multi-AZ topology
├── runner.tf                       # Self-hosted GitHub Actions Runner instance setup and token hooks
├── setup-tools.sh                  # Administrative bootstrap script for EKS management dependencies
├── sg.tf                           # Explicit Security Group rules covering cross-component boundaries
├── variables.tf                    # Global schema schema mapping and validation defaults
└── vpc.tf                          # Virtual Private Cloud, Subnets, and Network Access Control Lists
```

---

## Complete Network Architecture and Security

The network architecture is engineered to guarantee strict isolation, high availability across multiple Availability Zones, and zero direct exposure of private infrastructure to the public internet.

### Network Topology Overview



### Subnet Layout and IP Allocation

The VPC allocates a standard Classless Inter-Domain Routing (CIDR) block block (`10.0.0.0/16`), dynamically partitioned into two functional layers across distinct Availability Zones (AZs) to prevent single-point-of-failure events:

| Subnet Type | AZ Distribution | CIDR Assignment | Function and Hosted Resources |
|---|---|---|---|
| `Public Subnet 1` | ap-southeast-3a | `10.0.1.0/24` | AWS Internet Gateway ingress, Application Load Balancer (ALB), NAT Gateway A. |
| `Public Subnet 2` | ap-southeast-3b | `10.0.2.0/24` | AWS Internet Gateway ingress, Application Load Balancer (ALB), NAT Gateway B. |
| `Private Subnet 1` | ap-southeast-3a | `10.0.11.0/24` | EKS Control Plane ENIs, EKS Worker Nodes, Self-hosted GitHub Runners. |
| `Private Subnet 2` | ap-southeast-3b | `10.0.12.0/24` | EKS Control Plane ENIs, EKS Worker Nodes, Bastion administrative host. |

### Routing Infrastructure

Traffic direction rules are explicitly split across isolated Route Tables to enforce unidirectional internet access from within private compute boundaries:

* **Public Route Table**: Maps `0.0.0.0/0` traffic directly to the AWS Internet Gateway (`igw`). This layer enables the Application Load Balancer to receive incoming internet traffic and distribute it down into the cluster.
* **Private Route Tables**: Maps `0.0.0.0/0` traffic directly to the localized AWS NAT Gateways (`nat`) bound inside the public subnets. Private workloads (such as EKS nodes or GitHub runners) fetch external packages, dependencies, and API calls securely without exposing their internal private IP addresses to external networks.

### Traffic Flow Matrix

The architecture segregates incoming and outgoing communications through well-defined internal pathways:

```text
[Internet Client]
       │ (Port 80/443)
       ▼
[Application Load Balancer (Public Subnet)]
       │ (Port 30080 Forwarding via VPC CIDR)
       ▼
[Ingress-Nginx Controller NodePort (Private Subnet Worker Nodes)]
       │ (ClusterIP Internal Routing)
       ▼
[Application Microservice Pods]
```

* **Ingress Data Flow**: External internet clients access the platform through HTTPS (Port 443). The public Application Load Balancer decrypts TLS sessions using AWS Certificate Manager (ACM) and forwards the raw traffic inside the VPC network onto the `ingress-nginx` controller running as a NodePort target (`Port 30080`) on the private EKS Worker Nodes.
* **Egress Data Flow**: Worker Nodes and GitHub Runners inside the private subnets communicate out to the internet by routing traffic up through the private route table to the public NAT Gateway, which performs Network Address Translation and hands the traffic over to the Internet Gateway.

### Security Group Firewall Enforcements

Network boundaries are protected using tight Security Group rules that implement least-privilege security models:

* **ALB Security Group**: Permits inbound `80` (HTTP) and `443` (HTTPS) from any universal source (`0.0.0.0/0`). Restricts outbound traffic explicitly to the internal VPC CIDR block targeting `Port 30080` (Ingress NodePort) and `Port 10254` (Nginx Health Check).
* **EKS Cluster Security Group**: Protects the Kubernetes control layer. Accepts incoming connections on `Port 443` (HTTPS) strictly from the EKS Nodes Security Group and the designated Bastion Host Security Group.
* **EKS Nodes Security Group**: Allows unrestricted mutual core communication between internal container pods (`-1` protocol). Accepts ingress from the public ALB on the explicit `NodePort` ranges and permits debugging queries originating from the Bastion host.
* **Bastion Security Group**: Blocks public SSH access. Allows inward connectivity on management ports strictly from secure administrative networks or private network tunnels.

---

## Pipeline Architecture and Deployment Workflows

The CI/CD framework leverages automated GitHub Actions workflows to implement continuous integration, change verification, deployment gates, and environment decommissioning.

### Workflow 1: Terraform CI/CD (`terraform-ci.yml`)

This automated pipeline manages code quality and infrastructure deployments through a unified multi-stage architecture.

#### 1. Ingestion and Triggers
The workflow automatically calculates execution strategies based on the GitHub trigger context:
* **Pull Requests** targeting `develop` or `main` execute verification steps and compile execution plans without deploying infrastructure changes.
* **Code Pushes or Merges** into the `develop` branch automatically execute planning steps and apply configurations directly onto the **Development** environment.
* **Git Tag Creations** matching the semantic version schema `v*` trigger the deployment process for the **Production** environment. This action requires authorization approval through a GitHub Environment protection gate.
* **Manual Dispatch (workflow_dispatch)** allows operators to trigger explicit runs targeting specific environments (`dev` or `prod`), requiring uppercase verification text confirmation (`APPLY`) to prevent deployment errors.

#### 2. Structural Execution Sequence

```text
[GitHub Trigger Event]
         │
         ▼
 ┌───────────────┐
 │   Job: Lint   │ ──► Enforces code style, format validation, and security rules
 └───────┬───────┘
         │ (Pass)
         ▼
 ┌───────────────┐
 │   Job: Plan   │ ──► Connects via OIDC IAM Roles, outputs 'tfplan' binary artifact
 └───────┬───────┘
         ├─────────────────────────────────────────┐
         │ (Push to develop / Manual Dev)          │ (Tag v* / Manual Prod)
         ▼                                         ▼
 ┌──────────────────────────────┐       ┌──────────────────────────────┐
 │    Job: Apply [development]  │       │ Environment Approval Gate    │
 └──────────────────────────────┘       └──────────┬───────────────────┘
                                                   │ (Approved)
                                                   ▼
                                        ┌──────────────────────────────┐
                                        │     Job: Apply [production]  │
                                        └──────────────────────────────┘
```

* **Step A: Code Linting and Formatting (`lint`)**
  Executes format checks (`terraform fmt -check`) and deep syntax checks (`terraform validate`) on an independent runner instance to guarantee code cleanliness before initiating cloud connections.
* **Step B: Execution Planning (`plan`)**
  Authenticates securely with AWS using OpenID Connect (OIDC) token exchanges, completely removing the need for persistent, long-lived AWS Access Keys inside GitHub Secrets. It configures the remote backend dynamically using environment variables (`-backend-config`) and writes out a compiled binary plan artifact (`tfplan`).
* **Step C: Environment Selective Application (`apply-dev` / `apply-prod`)**
  Downloads the validated `tfplan` binary and executes the changes (`terraform apply`). This architecture ensures that the exact plan reviewed during the planning step is applied to the target environment without modification.

---

### Workflow 2: Infrastructure Decommissioning (`terraform-destroy.yml`)

To maintain tight governance and prevent accidental infrastructure deletions, environment decommissioning is decoupled into a separate, highly protected workflow.

#### 1. Security Verification Mechanism
The pipeline can only be triggered manually via a `workflow_dispatch` event. It requires the operator to explicitly select the target environment (`dev` or `prod`) and type the word `DESTROY` in uppercase into a confirmation field.

```yaml
if: github.event.inputs.confirm == 'DESTROY'
```

If the input string does not match exactly, the workflow terminates immediately with a non-zero exit status, protecting the environment against execution errors.

#### 2. Automatic Resource Cleanup Integration
When the destruction sequence is approved, the workflow handles dependencies gracefully by using specific architectural lifecycle hooks (`cleanup.tf`):
* **Target Group and Dynamic Resource Evacuation**: Before purging core VPC constructs, the cleanup process detaches network interfaces and internal load balancer targets to prevent the cloud provider from locking resources.
* **State Mirror Purging**: Frees active resource registrations from the remote S3 State file while using DynamoDB locking mechanisms to prevent other operations from running concurrently during the teardown.

---

## Resource Architecture and Components

### Core Infrastructure Components

#### `main.tf`
Configures the foundation of the Terraform engine execution. It enforces minimum binaries constraints, initializes the `hashicorp/aws` provider version, and establishes an isolated remote backend mapping. It uses an Amazon S3 bucket for tracking state storage histories alongside an active DynamoDB lock tracking architecture to maintain synchronization across distributed execution boundaries.

#### `vpc.tf`, `igw.tf`, `nat.tf`, `routes.tf`
Establishes the structural network foundation. Splits the system configuration across public subnets for public internet visibility and private subnets across multiple availability zones. NAT Gateways map persistent Elastic IPs to route private application egress out through the Internet Gateways while completely blocking incoming uninitiated public connections.

#### `sg.tf`
Central security firewall definitions. Segregates communication protocols by enforcing explicit security boundaries:
* **ALB SG**: Admits incoming traffic via ports 80 (HTTP) and 443 (HTTPS) from any universal origin, restricting egress paths strictly onto designated cluster NodePorts.
* **EKS Cluster SG**: Manages communication lines between cluster workers and control infrastructure.
* **EKS Nodes SG**: Permits internal communication between pods, inbound metrics scraping from health targets, and control planes via port 443.

### Container Orchestration Platform

#### `eks.tf`
Deploys the Amazon EKS control plane cluster. Configures structural identity schemas using modern EKS Access Entries (`API_AND_CONFIG_MAP` authentication mode) instead of deprecated `aws-auth` ConfigMaps. Automatically maps cloud infrastructure governance entities, assigning administrative policies (`AmazonEKSClusterAdminPolicy`) explicitly onto both the Bastion host profile and external CI/CD runtime identities.

#### `nodegroup.tf`
Specifies EKS Managed Node Groups running optimized Amazon Linux or Ubuntu compute layers. Provisions elastic scaling configuration blocks (`desired_size`, `min_size`, `max_size`) inside isolated private subnets, managing automated health restorations via `node_repair_config` and orchestrating zero-downtime cluster updates based on user-defined `max_unavailable` tolerances.

### Operations and Continuous Integration

#### `bastion.tf`
Deploys an administrative jump host inside the public layer to bridge access into the private EKS cluster. It automatically provisions software packages (`kubectl`, `helm`, `aws-cli`) via systemd background initialization scripts (`setup-tools.sh`), binding administrative endpoints via a standard NodePort arrangement to route tracking traffic down through an Ingress Nginx Controller configuration.

#### `runner.tf`
Provisions an on-demand, self-hosted GitHub Actions runner engine inside the secure environment boundary. This architecture eliminates the need to expose EKS endpoints to the public internet, optimizing build cache activities and package processing speeds while maintaining secure OIDC IAM role token evaluations.

### CI/CD Workflow Pipelines

#### `terraform-ci.yml`
An automated hybrid automation workflow. Triggering a Pull Request to core tracking branches initiates automated validation tests, security checking, and execution plans. Merges to development environments or tag creation parameters targeting production run automated cloud deployment sequences with built-in environment protection gate structures.

#### `terraform-destroy.yml`
A highly protected, manual governance pipeline designed to decommission cloud assets securely. Implements mandatory manual user entry validation rules (requiring an exact `DESTROY` tracking token input) to safeguard production instances against accidental system deletions.

---

## Configuration Reference

The platform behavior is customized through the input variables defined within `variables.tf` and configured per environment within the `.tfvars` manifests.

### Global Project Variables

| Parameter | Data Type | Default Value | Description |
|---|---|---|---|
| `region` | `string` | `"ap-southeast-3"` | Target AWS Region for infrastructure allocation. |
| `project` | `string` | `"shopnow"` | Project namespace token used across multi-component names and resource tags. |
| `environment` | `string` | `"dev"` | Target environment designation (e.g., `dev`, `staging`, `prod`). |

### Networking and VPC Configurations

| Parameter | Data Type | Default Value | Description |
|---|---|---|---|
| `vpc_cidr` | `string` | `"10.0.0.0/16"` | Main IPv4 Classless Inter-Domain Routing block configuration for the VPC. |
| `public_subnets` | `list(object)` | *(Complex List)* | Multi-AZ definition mapping CIDR scopes and zone layouts for public subnets. |
| `private_subnets` | `list(object)` | *(Complex List)* | Multi-AZ definition mapping CIDR scopes and zone layouts for private subnets. |
| `enable_dns_support` | `bool` | `true` | Toggles internal AWS DNS resolution support metrics. |
| `enable_dns_hostnames` | `bool` | `true` | Toggles assignment of public/private DNS hostnames onto matching instances. |

### Elastic Kubernetes Service (EKS) Configurations

| Parameter | Data Type | Default Value | Description |
|---|---|---|---|
| `enable_eks` | `bool` | `true` | Master toggle to enable or disable the creation of the EKS cluster. |
| `eks_cluster_name` | `string` | `"shopnow-prod-eks"` | Human-readable identifier assigned to the EKS control plane. |
| `eks_cluster_version`| `string` | `"1.30"` | Targeted Kubernetes orchestration system minor version release. |
| `eks_endpoint_access`| `string` | `"public_and_private"` | Endpoint access visibility schema routing configurations. |

### EKS Node Group Worker Node Configurations

| Parameter | Data Type | Default Value | Description |
|---|---|---|---|
| `nodegroup_name` | `string` | `"shopnow-core-nodes"`| Distinct identifier assigned to the managed node group pool. |
| `nodegroup_instance_types` | `list(string)` | `["t3.xlarge"]` | Hardware class compute definitions for application execution instances. |
| `nodegroup_disk_size`| `number` | `50` | Persistent storage limits measured in gigabytes attached onto workers. |
| `nodegroup_desired_size` | `number` | `2` | Initial count parameter of cluster instances during baseline bootstrap phases. |
| `nodegroup_min_size` | `number` | `1` | Lower floor threshold bounds allowed for automated cluster downscaling. |
| `nodegroup_max_size` | `number` | `5` | Upper ceiling threshold bounds allowed for automated cluster upscaling. |

### Enterprise Access and Feature Toggles

| Parameter | Data Type | Default Value | Description |
|---|---|---|---|
| `enable_bastion` | `bool` | `true` | Toggles provisioning of the administrative Bastion jump box. |
| `enable_alb` | `bool` | `true` | Controls execution initialization workflows for the public ALB. |
| `enable_github_runner`| `bool` | `true` | Controls deployment sequences for the self-hosted GitHub agent. |
| `acm_certificate_arn`| `string` | *(Valid AWS ARN)* | AWS Certificate Manager tracking identifier provisioning secure TLS sessions. |

---

## Operations Guide (CLI Usage)

### Initial Repository Initialization

Execute the initialization sequence from your local command terminal to download explicit provider binaries and connect structural tracking frameworks onto remote storage backends.

```bash
# Initialize targeting the Development environment state file
terraform init \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="bucket=shopnow-terraform-state" \
  -backend-config="region=ap-southeast-3" \
  -backend-config="dynamodb_table=shopnow-terraform-lock" \
  -backend-config="encrypt=true" \
  -reconfigure
```

### Infrastructure Inspection and Planning

Always compile and verify an isolated execution blueprint layout prior to changing active operational assets.

```bash
# Generate and save an execution plan for the Development environment
terraform plan \
  -var-file="environments/dev/terraform.tfvars" \
  -out=dev.tfplan

# Review the structural components targeted for addition, modifications, or deletions
terraform show dev.tfplan
```

### Applying Infrastructure Configurations

Apply approved configurations to provision your infrastructure on AWS.

```bash
# Execute structural updates using the verified execution blueprint
terraform apply dev.tfplan
```

To initialize, plan, and deploy configurations for the Production cluster ecosystem, shift targets onto matching environment configurations:

```bash
# Initialize Production backend workspaces
terraform init \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="bucket=shopnow-terraform-state" \
  -backend-config="region=ap-southeast-3" \
  -backend-config="dynamodb_table=shopnow-terraform-lock" \
  -backend-config="encrypt=true" \
  -reconfigure

# Review and apply Production system assets
terraform plan -var-file="environments/prod/terraform.tfvars" -out=prod.tfplan
terraform apply prod.tfplan
```

### Cluster Interaction and Administrative Verification

Once the infrastructure deployment completes successfully, copy the output parameters to configure local cluster access points.

```bash
# Query tracking outputs to retrieve EKS allocation variables
export CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
export AWS_REGION=$(terraform output -raw aws_region)

# Update local kubeconfig data states to link into the private control layer
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Validate health dimensions across cluster nodes and compute namespaces
kubectl get nodes -o wide
kubectl get pods --all-namespaces
```

### Decommissioning Cloud Assets

When you need to tear down an entire cluster environment, execute the structural destruction sequence using exact variable mappings to avoid leaving behind orphaned, billable resources.

```bash
# Compile a destructive review map
terraform plan \
  -destroy \
  -var-file="environments/dev/terraform.tfvars" \
  -out=destroy.tfplan

# Execute destruction sequence to purge cloud resources
terraform apply destroy.tfplan
```