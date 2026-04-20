# TaskFlow — Complete CI/CD Pipeline Guide (AWS ECS Fargate)

This document explains **everything** that was added to your project to build a production-style CI/CD pipeline using GitHub Actions, Terraform, Docker, AWS ECR, and AWS ECS Fargate.

**Important: This setup is AWS Academy compatible — uses the pre-existing `LabRole` (NO IAM role/policy creation).**

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [AWS Academy — Key Differences](#aws-academy--key-differences)
3. [What Changed in the Project](#what-changed-in-the-project)
4. [Pipeline Flow](#pipeline-flow)
5. [Terraform Remote State — Why It Matters](#terraform-remote-state--why-it-matters)
6. [Infrastructure Explained (Terraform)](#infrastructure-explained-terraform)
7. [Docker — Production-Grade Container](#docker--production-grade-container)
8. [GitHub Actions Workflow Explained](#github-actions-workflow-explained)
9. [ALB — Application Load Balancer](#alb--application-load-balancer)
10. [Security Best Practices](#security-best-practices)
11. [How to Deploy — Step by Step](#how-to-deploy--step-by-step)
12. [Verification Steps](#verification-steps)
13. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         GitHub Actions Pipeline                          │
├─────────────┬─────────────────┬──────────────────┬─────────────────────┤
│  Phase 1    │   Phase 2       │   Phase 3        │   Phase 4           │
│  Run Tests  │   Terraform     │   Docker Build   │   Deploy to ECS     │
│  (lint +    │   Apply (infra) │   & Push to ECR  │   Fargate           │
│   unit +    │                 │                  │                     │
│   integ)    │                 │                  │                     │
└─────┬───────┴────────┬────────┴─────────┬────────┴──────────┬──────────┘
      │                │                  │                   │
      ▼                ▼                  ▼                   ▼
┌──────────┐  ┌────────────────┐  ┌──────────────┐  ┌────────────────────┐
│ Jest /   │  │ AWS Resources: │  │ AWS ECR      │  │ ECS Fargate        │
│ Vitest   │  │ VPC, Subnets,  │  │ (Container   │  │ (Runs containers   │
│ Tests    │  │ ALB, ECS, ECR  │  │  Registry)   │  │  serverlessly)     │
└──────────┘  └────────────────┘  └──────────────┘  └─────────┬──────────┘
                                                               │
                                                               ▼
                                                    ┌────────────────────┐
                                                    │ Application Load   │
                                                    │ Balancer (ALB)     │
                                                    │ → Public DNS URL   │
                                                    └────────────────────┘
```

---

## AWS Academy — Key Differences

AWS Academy labs have restrictions compared to regular AWS accounts:

| Feature | Regular AWS | AWS Academy |
|---------|-------------|-------------|
| IAM Role Creation | ✅ Allowed | ❌ NOT allowed |
| IAM Policy Creation | ✅ Allowed | ❌ NOT allowed |
| Pre-existing Role | None | `LabRole` (broad permissions) |
| Session Tokens | Optional | **REQUIRED** (expire ~4 hours) |
| Region | Any | Usually `us-east-1` |

### What is LabRole?
AWS Academy automatically creates a role called `LabRole` in your account. This role has broad permissions for common services (ECS, ECR, S3, EC2, VPC, CloudWatch, ELB). We use this role for:
- **ECS Execution Role**: Lets ECS pull Docker images from ECR and write logs
- **ECS Task Role**: Permissions available to the running application container

### How we reference LabRole in Terraform:
```hcl
execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
task_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
```
The `data.aws_caller_identity.current.account_id` automatically fetches your account ID — no hardcoding needed.

---

## What Changed in the Project

### New Files Added:

```
Devops-project/
├── PIPELINE_GUIDE.md                  ← This file (you're reading it)
├── terraform/
│   ├── backend.tf                     ← S3 remote state configuration
│   ├── provider.tf                    ← AWS provider (v6.0) + account ID lookup
│   ├── variables.tf                   ← Input variables
│   ├── outputs.tf                     ← Output values (ALB URL, etc.)
│   ├── vpc.tf                         ← VPC, subnets, internet gateway
│   ├── security_groups.tf             ← Firewall rules
│   ├── ecs.tf                         ← ECS cluster, task (uses LabRole), service
│   ├── ecr.tf                         ← Container registry
│   ├── alb.tf                         ← Application Load Balancer
│   ├── s3.tf                          ← S3 bucket for storage
│   ├── cloudwatch.tf                  ← Log groups
│   └── terraform.tfvars               ← Default variable values
├── ecs/
│   └── task-definition.json           ← ECS task definition template (docs)
├── iam/
│   └── policies.json                  ← IAM/LabRole documentation
├── .github/
│   └── workflows/
│       └── ecs-deploy.yml             ← Full 4-phase CI/CD pipeline
└── server/
    ├── Dockerfile                     ← UPDATED: non-root, healthcheck, optimized
    └── .dockerignore                  ← NEW: keep image small
```

### What We Did NOT Create (AWS Academy restriction):
- ❌ No `iam.tf` file — Cannot create IAM roles/policies
- ❌ No custom execution roles — Uses pre-existing `LabRole`
- ❌ No custom task roles — Uses pre-existing `LabRole`

---

## Pipeline Flow

The pipeline runs in this **exact order** (each phase depends on the previous):

```
push/PR to main
      │
      ▼
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐     ┌──────────────┐
│   Phase 1   │────▶│     Phase 2      │────▶│    Phase 3      │────▶│   Phase 4    │
│   Testing   │     │  Terraform Apply │     │ Docker Build &  │     │  Deploy to   │
│             │     │                  │     │ Push to ECR     │     │  ECS Fargate │
└─────────────┘     └──────────────────┘     └─────────────────┘     └──────────────┘
```

- **Phase 1 fails** → Everything stops (no broken code gets deployed)
- **Phase 2 fails** → No Docker build (infra must exist first)
- **Phase 3 fails** → No deployment (image must exist in ECR first)
- **Phase 4 fails** → ECS rolls back automatically (circuit breaker enabled)

---

## Terraform Remote State — Why It Matters

### The Problem Without Remote State:
Every time GitHub Actions runs `terraform apply`, Terraform has NO memory of what it created before. It would try to create everything from scratch, causing:
- Duplicate resources (multiple VPCs, ECS clusters)
- Errors ("resource already exists")
- Wasted money

### The Solution — S3 Remote Backend:
Terraform stores its "memory" (state file) in an S3 bucket. On every run:
1. Terraform downloads the state from S3
2. Compares desired config vs. actual state
3. Only creates/modifies/destroys what's different
4. Uploads updated state back to S3

### State Locking with DynamoDB:
If two pipeline runs happen simultaneously, they could corrupt the state. DynamoDB provides a "lock" — only one Terraform operation can run at a time.

### How It Works in Our Pipeline:
```
GitHub Actions Run #1: Creates VPC, ECS, ALB → State saved to S3
GitHub Actions Run #2: Reads state from S3 → "Everything exists" → No changes
GitHub Actions Run #3: You change a variable → Reads state → Only updates the diff
```

### How Terraform Detects Existing Infrastructure:
1. Downloads `terraform.tfstate` from S3
2. State file contains resource IDs (e.g., `vpc-abc123`, `ecs-cluster-xyz`)
3. Uses AWS APIs to check if those resources still exist
4. Compares current config → if no diff, does nothing

### How State Locking Prevents Corruption:
1. Pipeline A starts → writes lock to DynamoDB → runs terraform
2. Pipeline B starts → tries to write lock → **BLOCKED** (waits or fails)
3. Pipeline A finishes → releases lock
4. Pipeline B can now proceed

---

## Infrastructure Explained (Terraform)

### VPC (Virtual Private Cloud) — `vpc.tf`
- **What**: Your own isolated network in AWS
- **Why**: Security — your containers are not on the public internet directly
- **Details**: CIDR 10.0.0.0/16 with 2 public subnets in different AZs

### Subnets — `vpc.tf`
- **Public Subnets**: 2 subnets in different availability zones
- **Why 2?**: ALB requires at least 2 subnets in different AZs
- **Auto-assign public IP**: Enabled so ECS tasks can pull images from ECR

### Internet Gateway + Route Tables — `vpc.tf`
- **Internet Gateway**: Allows traffic in/out of the VPC
- **Route Table**: Tells traffic "to reach the internet, use the IGW"

### Security Groups (Firewall Rules) — `security_groups.tf`
- **ALB Security Group**: Allows inbound HTTP (port 80) from anywhere
- **ECS Security Group**: Only allows traffic FROM the ALB (not direct internet access)

### ECS (Elastic Container Service) — `ecs.tf`
- **Cluster**: Logical grouping of your services
- **Task Definition**: Blueprint for your container (image, CPU, memory, ports)
- **Service**: Ensures desired number of tasks are always running
- **Fargate**: Serverless — no EC2 instances to manage
- **LabRole**: Used for both execution and task roles (AWS Academy)

### ECR (Elastic Container Registry) — `ecr.tf`
- **What**: AWS's Docker Hub — stores your container images privately
- **force_delete**: Allows cleanup during lab teardown
- **Lifecycle Policy**: Keeps only last 5 images (saves storage)

### ALB (Application Load Balancer) — `alb.tf`
- **What**: Distributes incoming traffic to your ECS tasks
- **Why**: Provides a stable DNS URL, health checks, and scaling
- **Health Check**: Hits `/api/health` every 30s to confirm app is alive

### S3 Bucket — `s3.tf`
- **Purpose**: Application storage + demonstrates S3 best practices
- **Security**: Versioning ON, encryption ON, public access BLOCKED
- **Unique name**: Uses account ID suffix for global uniqueness

### CloudWatch Logs — `cloudwatch.tf`
- **Purpose**: Container stdout/stderr are sent here
- **Retention**: 7 days (lab environment)
- **View logs**: AWS Console → CloudWatch → Log Groups → `/ecs/taskflow`

---

## Docker — Production-Grade Container

The Dockerfile uses these production best practices:

| Practice | Why |
|----------|-----|
| Multi-stage build | Smaller final image (no dev tools) |
| `node:20-alpine` | Tiny base image (~50MB vs ~900MB for full) |
| Non-root user (`appuser`) | Security — if hacked, attacker has limited permissions |
| HEALTHCHECK | ECS/Docker knows if the app crashed |
| `.dockerignore` | Don't copy `node_modules`, `.git`, tests into image |
| `npm ci --omit=dev` | Only production dependencies |
| Explicit COPY order | Better Docker layer caching |

---

## GitHub Actions Workflow Explained

### Job: `test`
- Installs dependencies for server AND client
- Runs linting (code style checks)
- Runs unit tests (individual function testing)
- Runs integration tests (API endpoint testing)
- Caches `node_modules` for speed
- **If any test fails, the entire pipeline stops**

### Job: `terraform` (needs: test)
- Configures AWS credentials from GitHub Secrets (including session token)
- Runs `terraform init` (connects to S3 backend)
- Runs `terraform validate` (checks syntax)
- Runs `terraform plan` (shows what would change)
- Runs `terraform apply -auto-approve` (applies changes)

### Job: `docker-build-push` (needs: terraform)
- Logs into AWS ECR
- Builds the Docker image with proper tags (latest + git SHA)
- Pushes to ECR repository

### Job: `deploy-ecs` (needs: docker-build-push)
- Gets current task definition from ECS
- Updates container image to new version
- Registers new task definition revision
- Forces new deployment on ECS service
- Waits for service to stabilize (healthy containers running)
- Outputs the ALB URL

---

## ALB — Application Load Balancer

### How Traffic Flows:
```
User Browser
    │
    ▼ (HTTP port 80)
┌────────────────┐
│  ALB           │ ← Public DNS: taskflow-alb-xxxxx.region.elb.amazonaws.com
│  (Internet-    │
│   facing)      │
└───────┬────────┘
        │ (port 3001)
        ▼
┌────────────────┐
│  ECS Fargate   │
│  Task(s)       │
│  (Container)   │
└────────────────┘
```

### Health Checks:
- Path: `/api/health`
- Interval: 30 seconds
- Healthy threshold: 3 consecutive successes
- Unhealthy threshold: 3 consecutive failures
- If unhealthy → ECS replaces the task automatically

### ECS Auto-registers with ALB:
- When a new task starts → ECS automatically registers it with the target group
- When a task stops → ECS automatically deregisters it
- You don't need to manually manage targets

---

## Security Best Practices

1. **No hardcoded credentials** — All secrets in GitHub Secrets
2. **Non-root container** — Runs as `appuser` (UID 1001)
3. **No IAM creation** — Uses pre-existing LabRole (Academy safe)
4. **Private ECS tasks** — Only accessible via ALB, not directly
5. **S3 bucket locked down** — No public access, encrypted, versioned
6. **Security groups** — ECS only accepts traffic from ALB
7. **No SSH access** — Fargate has no EC2 instance to SSH into
8. **State file encrypted** — Terraform state in S3 uses AES-256
9. **ECR image scanning** — Checks for vulnerabilities on push
10. **Circuit breaker** — Auto-rollback if new deployment fails

---

## How to Deploy — Step by Step

### Prerequisites:
1. AWS Academy Lab started (green status)
2. GitHub repository with your code
3. AWS credentials from lab (Access Key + Secret Key + Session Token)

### Step 1: Create the Terraform State S3 Bucket (ONE TIME ONLY)

Open AWS Academy Lab → Terminal (or CloudShell):
```bash
aws s3api create-bucket \
  --bucket taskflow-terraform-state-ronit \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket taskflow-terraform-state-ronit \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket taskflow-terraform-state-ronit \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'
```

### Step 2: Create DynamoDB Lock Table (ONE TIME ONLY)
```bash
aws dynamodb create-table \
  --table-name taskflow-terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Step 3: Set GitHub Secrets

Go to your repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret Name | Where to Get It |
|-------------|----------------|
| `AWS_ACCESS_KEY_ID` | AWS Academy → AWS Details → Show CLI Credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS Academy → AWS Details → Show CLI Credentials |
| `AWS_SESSION_TOKEN` | AWS Academy → AWS Details → Show CLI Credentials |
| `AWS_REGION` | `us-east-1` |

**⚠️ Important**: Session tokens expire when the lab session restarts. You'll need to update `AWS_SESSION_TOKEN` each time you start a new lab session.

### Step 4: Update Backend Bucket Name (if different)

Edit `terraform/backend.tf` and replace the bucket name if yours is different:
```hcl
bucket = "taskflow-terraform-state-ronit"  # ← YOUR bucket name
```

### Step 5: Push to GitHub
```bash
git add .
git commit -m "feat: add ECS Fargate CI/CD pipeline with Terraform"
git push origin main
```

### Step 6: Watch the Pipeline
Go to your repo → Actions tab → Watch the 4 phases execute in order.

### Step 7: Get Your App URL
After deployment completes, check the workflow summary or run:
```bash
aws elbv2 describe-load-balancers --names taskflow-alb \
  --query 'LoadBalancers[0].DNSName' --output text
```

---

## Verification Steps

After deployment, verify everything works:

```bash
# 1. Check ECS service is running
aws ecs describe-services --cluster taskflow-cluster --services taskflow-service \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# 2. Hit the health endpoint
curl http://<ALB-DNS-URL>/api/health
# Expected: {"status":"ok","timestamp":"..."}

# 3. Test the API
curl http://<ALB-DNS-URL>/api/tasks
# Expected: [] (empty array)

# 4. Create a task
curl -X POST http://<ALB-DNS-URL>/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"First ECS Task","priority":"high"}'

# 5. Check CloudWatch logs
aws logs get-log-events \
  --log-group-name /ecs/taskflow \
  --log-stream-name $(aws logs describe-log-streams --log-group-name /ecs/taskflow --query 'logStreams[0].logStreamName' --output text)
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "bucket doesn't exist" | Create S3 bucket manually first (Step 1) |
| "Access Denied" | Update GitHub Secrets — session token expired |
| ECS task keeps restarting | Check CloudWatch logs: `/ecs/taskflow` |
| ALB shows unhealthy targets | Ensure security group allows port 3001 from ALB |
| Terraform state lock error | Run: `terraform force-unlock <LOCK-ID>` |
| "Role LabRole does not exist" | Make sure AWS Academy lab is started (green) |
| Docker build OOM | Increase `task_memory` in terraform.tfvars |
| Pipeline hangs at "wait for stability" | Check task definition — image might be wrong |

---

## Cleanup (Destroy Everything)

When done with the lab:
```bash
cd terraform
terraform destroy -auto-approve
```

Or manually via AWS Console delete:
1. ECS Service → Stop tasks
2. ECS Cluster
3. ALB + Target Group
4. ECR Repository
5. VPC (will delete subnets, IGW, route tables, security groups)
6. S3 Buckets
7. CloudWatch Log Groups

---

## Best Practices Followed

1. **Infrastructure as Code** — All resources defined in Terraform (reproducible)
2. **Remote State** — State persisted in S3 with DynamoDB locking (team-safe)
3. **No IAM Creation** — Uses pre-existing LabRole (AWS Academy compatible)
4. **Immutable Deployments** — New image = new task (no in-place updates)
5. **Health Checks** — ALB + Docker HEALTHCHECK ensure only healthy containers serve traffic
6. **Multi-AZ** — Subnets in 2 AZs for high availability
7. **Encrypted at Rest** — S3 uses AES-256
8. **No Secrets in Code** — All credentials via GitHub Secrets / environment variables
9. **Pipeline Gating** — Tests must pass before any infrastructure changes
10. **Auto-Recovery** — ECS circuit breaker rolls back failed deployments
11. **Force New Deployment** — `force_new_deployment = true` ensures latest image is used
12. **ECR Image Scanning** — Automatic vulnerability detection on push
