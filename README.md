# TaskFlow - Smart Task Manager

A full-stack task management SaaS application with a **complete production-grade CI/CD pipeline** deployed on **AWS ECS Fargate** using GitHub Actions, Terraform, and Docker.

**Live URL:** `http://taskflow-alb-1054308663.us-east-1.elb.amazonaws.com/`

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                     GitHub Actions CI/CD Pipeline                      │
├────────────┬─────────────────┬──────────────────┬────────────────────┤
│ Phase 1    │ Phase 2         │ Phase 3          │ Phase 4            │
│ Run Tests  │ Terraform Apply │ Docker Build &   │ Deploy to ECS      │
│ (lint +    │ (VPC, ALB, ECS, │ Push to ECR      │ Fargate            │
│  unit +    │  ECR, S3)       │                  │                    │
│  integ)    │                 │                  │                    │
└─────┬──────┴────────┬────────┴─────────┬────────┴─────────┬──────────┘
      │               │                  │                  │
      ▼               ▼                  ▼                  ▼
 Jest/Vitest     AWS Infra          AWS ECR           ECS Fargate
   Tests         created           (Image Store)      (Containers)
                                                          │
                                                          ▼
                                               ┌───────────────────┐
                                               │ Application Load  │
                                               │ Balancer (ALB)    │
                                               │ → Public URL      │
                                               └───────────────────┘
```

---

## Features

- **Full CRUD API** — Create, Read, Update, Delete tasks with validation
- **Filtering & Sorting** — Filter by status, priority; sort by date
- **Modern UI** — Glassmorphism, gradient accents, micro-animations
- **Responsive Design** — Works on mobile, tablet, and desktop
- **Dashboard Analytics** — Visual stats for task statuses
- **Complete CI/CD** — Automated testing, infrastructure, and deployment
- **Infrastructure as Code** — All AWS resources managed by Terraform
- **Container Orchestration** — ECS Fargate (serverless containers)

---

## Tech Stack

| Layer              | Technology                              |
| ------------------ | --------------------------------------- |
| Frontend           | React 18, Vite, Axios                   |
| Backend            | Express.js, Node.js                     |
| Database           | SQLite (via Prisma ORM)                 |
| Unit Tests         | Jest (server), Vitest (client)          |
| Integration Tests  | Supertest + Prisma                      |
| E2E Tests          | Playwright                              |
| Linting            | ESLint, Prettier                        |
| CI/CD              | GitHub Actions (4-phase pipeline)       |
| Infrastructure     | Terraform (AWS provider v6.0)           |
| Containers         | Docker (multi-stage builds)             |
| Container Registry | AWS ECR                                 |
| Orchestration      | AWS ECS Fargate                         |
| Load Balancer      | AWS ALB (Application Load Balancer)     |
| Networking         | AWS VPC, Subnets, Security Groups       |
| Storage            | AWS S3 (versioned, encrypted)           |
| Logging            | AWS CloudWatch                          |
| State Management   | S3 Remote Backend + State Locking       |
| Dep Management     | Dependabot                              |

---

## Project Structure

```
├── .github/
│   ├── workflows/
│   │   ├── ecs-deploy.yml         # Full ECS CI/CD pipeline (4 phases)
│   │   ├── ci.yml                 # CI pipeline (test + lint)
│   │   ├── pr-checks.yml         # PR lint enforcement
│   │   └── deploy.yml            # EC2 deployment (legacy)
│   └── dependabot.yml            # Dependency updates
├── client/                        # React frontend
│   ├── src/components/           # React components
│   ├── tests/                    # Unit tests (Vitest)
│   ├── e2e/                      # E2E tests (Playwright)
│   ├── Dockerfile                # Frontend container (Nginx)
│   ├── nginx.conf                # Nginx config (SPA + API proxy)
│   ├── .dockerignore
│   └── vite.config.js
├── server/                        # Express backend
│   ├── src/
│   │   ├── index.js              # App entry (serves frontend + API)
│   │   ├── routes/tasks.js       # CRUD API routes
│   │   └── middleware/           # Error handler
│   ├── prisma/schema.prisma      # Database schema
│   ├── tests/unit/               # Unit tests (Jest)
│   ├── tests/integration/        # Integration tests (Supertest)
│   ├── Dockerfile                # Backend container (standalone)
│   └── .dockerignore
├── terraform/                     # Infrastructure as Code
│   ├── provider.tf               # AWS provider (v6.0)
│   ├── backend.tf                # S3 remote state + locking
│   ├── variables.tf              # Input variables
│   ├── terraform.tfvars          # Variable values
│   ├── vpc.tf                    # VPC, subnets, IGW, routes
│   ├── security_groups.tf        # ALB + ECS firewall rules
│   ├── alb.tf                    # Load balancer + target group
│   ├── ecs.tf                    # Cluster, task def, service
│   ├── ecr.tf                    # Container registry
│   ├── s3.tf                     # App storage bucket
│   ├── cloudwatch.tf             # Log groups
│   └── outputs.tf                # Output values
├── ecs/
│   └── task-definition.json      # ECS task def documentation
├── iam/
│   └── policies.json             # IAM/LabRole documentation
├── scripts/
│   ├── setup.sh                  # Local dev setup
│   ├── deploy.sh                 # EC2 deploy script
│   └── bootstrap-ec2.sh          # EC2 bootstrap
├── Dockerfile                     # Combined frontend+backend image
├── docker-compose.yml            # Local multi-container dev
├── PIPELINE_GUIDE.md             # Detailed pipeline documentation
└── README.md                     # This file
```

---

## Quick Start (Local Development)

### Prerequisites
- Node.js 18+
- npm

### Setup
```bash
git clone <your-repo-url>
cd Devops-project

# Install server dependencies
cd server && npm install && npx prisma generate && npx prisma db push
cd ..

# Install client dependencies
cd client && npm install
cd ..
```

### Run Locally
```bash
# Terminal 1 — Backend (port 3001)
cd server && npm run dev

# Terminal 2 — Frontend (port 5173)
cd client && npm run dev
```

Open http://localhost:5173

---

## Docker (Local)

### Using Docker Compose (Recommended)
```bash
docker compose up --build
```
- Frontend: http://localhost:8080
- Backend API: http://localhost:3001

### Individual Containers
```bash
# Backend only
cd server && docker build -t taskflow-server .
docker run -p 3001:3001 taskflow-server

# Frontend only
cd client && docker build -t taskflow-client .
docker run -p 8080:80 taskflow-client
```

### Combined Image (used in ECS)
```bash
docker build --platform linux/amd64 -t taskflow-combined .
docker run -p 3001:3001 taskflow-combined
```

---

## CI/CD Pipeline (GitHub Actions → AWS ECS Fargate)

The pipeline (`.github/workflows/ecs-deploy.yml`) executes 4 phases in order:

### Phase 1 — Testing
- Runs server + client linting
- Runs server unit tests (Jest)
- Runs server integration tests (Supertest)
- Runs client unit tests (Vitest)
- **Pipeline stops if any test fails**

### Phase 2 — Terraform Apply
- Initializes Terraform with S3 remote backend
- Validates configuration
- Generates execution plan
- Applies infrastructure (VPC, ALB, ECS, ECR, S3)
- Uses pre-existing AWS Academy `LabRole` (no IAM creation)

### Phase 3 — Docker Build & Push
- Logs into AWS ECR
- Builds combined image (frontend + backend) for `linux/amd64`
- Tags with `latest` and git SHA
- Pushes to ECR

### Phase 4 — Deploy to ECS Fargate
- Retrieves current task definition
- Updates container image to new version
- Registers new task definition revision
- Forces new deployment on ECS service
- Waits for service to stabilize
- Outputs ALB URL

### GitHub Secrets Required
| Secret | Source |
|--------|--------|
| `AWS_ACCESS_KEY_ID` | AWS Academy → AWS Details → CLI Credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS Academy → AWS Details → CLI Credentials |
| `AWS_SESSION_TOKEN` | AWS Academy → AWS Details → CLI Credentials |
| `AWS_REGION` | `us-east-1` |

---

## AWS Infrastructure (Terraform)

All infrastructure is defined in `terraform/` and managed as code:

| Resource | Purpose |
|----------|---------|
| VPC | Isolated network (10.0.0.0/16) |
| 2 Public Subnets | Multi-AZ for high availability |
| Internet Gateway | Allows internet access |
| Route Tables | Routes traffic to IGW |
| ALB Security Group | Allows HTTP (port 80) from internet |
| ECS Security Group | Allows traffic only from ALB |
| Application Load Balancer | Distributes traffic, health checks |
| Target Group | Routes to ECS tasks on port 3001 |
| ECS Cluster | Logical container grouping |
| ECS Task Definition | Container blueprint (LabRole, 512 CPU, 1024 MB) |
| ECS Service (Fargate) | Ensures tasks are always running |
| ECR Repository | Private Docker image storage |
| S3 Bucket | Versioned, encrypted app storage |
| CloudWatch Log Group | Container logs (7-day retention) |

### Remote State
- Terraform state stored in S3 (survives pipeline reruns)
- State locking via `use_lockfile = true`
- Infrastructure is NOT recreated on every pipeline run

### AWS Academy Compatibility
- Uses pre-existing `LabRole` for ECS execution and task roles
- No IAM role/policy creation (restricted in Academy)
- Session tokens required (expire ~4 hours)

---

## API Endpoints

| Method | Endpoint         | Description        |
| ------ | ---------------- | ------------------ |
| GET    | /api/tasks       | Get all tasks      |
| GET    | /api/tasks/:id   | Get task by ID     |
| POST   | /api/tasks       | Create a task      |
| PUT    | /api/tasks/:id   | Update a task      |
| DELETE | /api/tasks/:id   | Delete a task      |
| GET    | /api/health      | Health check       |

**Query Parameters:** `?status=pending&priority=high&sort=oldest`

---

## Testing

```bash
# Server unit tests
cd server && npm run test:unit

# Server integration tests
cd server && npm run test:integration

# Client unit tests
cd client && npm test

# E2E tests (requires app running)
cd client && npm run test:e2e
```

---

## Manual Deployment (Push to ECR)

```bash
# 1. Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  454091892877.dkr.ecr.us-east-1.amazonaws.com

# 2. Build for amd64 (required for ECS Fargate)
docker build --platform linux/amd64 \
  -t 454091892877.dkr.ecr.us-east-1.amazonaws.com/taskflow-server:latest .

# 3. Push to ECR
docker push 454091892877.dkr.ecr.us-east-1.amazonaws.com/taskflow-server:latest

# 4. Force ECS to pull new image
aws ecs update-service --cluster taskflow-cluster \
  --service taskflow-service --force-new-deployment --region us-east-1
```

---

## Cleanup

```bash
# Destroy all AWS infrastructure
cd terraform && terraform destroy -auto-approve

# Remove local containers
docker compose down --rmi all
```

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Combined Dockerfile | Single container serves React + API (simpler for ECS) |
| SQLite + Prisma | Zero-config database, perfect for demos |
| Multi-stage Docker builds | Smaller images (~100MB vs ~1GB) |
| Non-root container user | Security hardening |
| S3 Remote State | Terraform remembers infrastructure between runs |
| ALB + ECS | Auto health checks, rolling deployments, no downtime |
| LabRole (no IAM) | AWS Academy compatible |
| Circuit Breaker | Auto-rollback on failed deployments |
| `--platform linux/amd64` | Apple Silicon compatibility with ECS |

---

## Documentation

- [`PIPELINE_GUIDE.md`](./PIPELINE_GUIDE.md) — Detailed pipeline explanation with diagrams
- [`iam/policies.json`](./iam/policies.json) — IAM/LabRole documentation
- [`ecs/task-definition.json`](./ecs/task-definition.json) — ECS task definition reference

---

## License

MIT License — built for educational purposes.
