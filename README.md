# End-to-End CI/CD Pipeline with Multi-Stage Deployment

A production-grade CI/CD pipeline demonstrating automated software delivery from commit to production using GitHub Actions, Docker, AWS ECR/ECS, SonarQube, and Trivy.

## Architecture

```
  Developer pushes code
         │
         ▼
  ┌──────────────┐
  │  GitHub Repo  │
  └──────┬───────┘
         │  (webhook triggers GitHub Actions)
         ▼
  ┌──────────────────────────────────────────┐
  │           GitHub Actions Pipeline         │
  │                                          │
  │  ┌─────────┐   ┌───────────┐            │
  │  │  Build   │──▶│   Test    │            │
  │  │ npm ci   │   │ Jest+cov  │            │
  │  └─────────┘   └─────┬─────┘            │
  │                      │                   │
  │               ┌──────▼──────┐            │
  │               │  SonarQube  │            │
  │               │ Quality Gate│            │
  │               └──────┬──────┘            │
  │                      │                   │
  │            ┌─────────▼─────────┐         │
  │            │   Docker Build    │         │
  │            │  (multi-stage)    │         │
  │            └─────────┬─────────┘         │
  │                      │                   │
  │              ┌───────▼───────┐           │
  │              │  Trivy Scan   │           │
  │              │ (vuln check)  │           │
  │              └───────┬───────┘           │
  │                      │                   │
  │              ┌───────▼───────┐           │
  │              │  Push to ECR  │           │
  │              └───────┬───────┘           │
  │                      │                   │
  │        ┌─────────────┴─────────────┐     │
  │        ▼                           ▼     │
  │  ┌───────────┐  approval   ┌──────────┐ │
  │  │ Deploy Dev│────gate────▶│Deploy    │ │
  │  │ (auto)    │             │Production│ │
  │  └─────┬─────┘             └────┬─────┘ │
  │        │                        │        │
  └────────┼────────────────────────┼────────┘
           │                        │
           ▼                        ▼
     ┌──────────┐           ┌──────────┐
     │ ECS Dev  │           │ ECS Prod │
     │ Cluster  │           │ Cluster  │
     └──────────┘           └──────────┘
           │                        │
           ▼                        ▼
     Slack notification       Slack notification
```

## What's in the Box

| Component | Purpose |
|---|---|
| `src/` | Express.js REST API (health check, CRUD endpoints) |
| `tests/` | Jest test suite with coverage |
| `Dockerfile` | Multi-stage build (deps → test → production) |
| `.github/workflows/pipeline.yml` | Full CI/CD pipeline |
| `infra/task-def-*.json` | ECS Fargate task definitions (dev + prod) |
| `sonar-project.properties` | SonarQube analysis config |
| `docker-compose.yml` | Local dev with SonarQube + Trivy |
| `scripts/repo-setup.sh` | One-command GitHub repo configuration |

## Prerequisites

- AWS account with ECS, ECR, and IAM configured
- GitHub repository
- SonarQube instance (cloud or self-hosted)
- Slack workspace with an incoming webhook
- GitHub CLI (`gh`) for the setup script
- Docker and Node.js 20+ for local development

## Quick Start

### Local Development

```bash
# Install dependencies
npm install

# Run tests
npm test

# Start the server
npm run dev

# Or run everything in Docker
docker compose up
```

### Pipeline Setup

```bash
# 1. Create the GitHub repo and push this code
git init && git add -A && git commit -m "initial commit"
gh repo create myorg/cicd-demo-api --private --push --source .

# 2. Run the setup script (creates environments, secrets, branch protection)
chmod +x scripts/repo-setup.sh
./scripts/repo-setup.sh myorg/cicd-demo-api

# 3. Create AWS resources
aws ecr create-repository --repository-name cicd-demo-api
# Then create ECS clusters, services, ALB, and OIDC provider
# (see "AWS Infrastructure Setup" below)
```

## Pipeline Stages

### 1. Build & Test
Installs deps, runs ESLint, executes Jest with coverage. Fails the pipeline if coverage drops below 80% lines or tests fail.

### 2. Code Quality Gate (SonarQube)
Runs static analysis against the SonarQube server. The Quality Gate enforces thresholds for reliability, security, maintainability, coverage, and duplication. If the gate fails, the pipeline stops.

### 3. Docker Build + Vulnerability Scan
Builds a multi-stage Docker image (non-root user, Alpine base, production deps only). Trivy scans the image for HIGH and CRITICAL vulnerabilities — any findings fail the build. SARIF results upload to GitHub's Security tab.

### 4. Deploy to Dev (Automatic)
On push to `main` or `develop`, the new image deploys to the Dev ECS cluster. A smoke test hits `/health` and verifies the response. Slack gets notified either way.

### 5. Deploy to Production (Manual Approval)
Only from `main`. The `production` GitHub Environment requires a reviewer to approve before deployment proceeds. Same deploy + smoke test + Slack notification pattern as dev.

## AWS Infrastructure Setup

The pipeline assumes these AWS resources exist. You need to create them outside the pipeline (via Terraform, CloudFormation, or console):

1. **ECR Repository**: `cicd-demo-api`
2. **ECS Clusters**: `demo-cluster-dev` and `demo-cluster-prod` (Fargate)
3. **ECS Services**: `demo-service-dev` and `demo-service-prod`
4. **ALB + Target Groups**: routing traffic to ECS tasks on port 3000
5. **IAM Roles**: execution role (ECR pull + CloudWatch) and task role (app permissions)
6. **OIDC Identity Provider**: so GitHub Actions can assume IAM roles without long-lived keys
7. **CloudWatch Log Groups**: `/ecs/demo-api-dev` and `/ecs/demo-api-prod`

### OIDC Setup for GitHub Actions → AWS

```bash
# Create the OIDC provider (one-time per AWS account)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Then create an IAM role with a trust policy scoped to your repo. The pipeline uses `aws-actions/configure-aws-credentials` with `role-to-assume`.

## GitHub Secrets Required

| Secret | Description |
|---|---|
| `AWS_ROLE_ARN` | IAM role ARN for dev deploys |
| `AWS_ROLE_ARN_PROD` | IAM role ARN for production deploys |
| `SONAR_TOKEN` | SonarQube authentication token |
| `SONAR_HOST_URL` | SonarQube server URL |
| `SLACK_WEBHOOK_URL` | Slack incoming webhook URL |

## Customization

**Different cloud provider**: Replace the ECR/ECS steps with your registry (Docker Hub, GCR, ACR) and deployment target (GKE, AKS, Cloud Run). The build/test/scan stages stay the same.

**Add staging environment**: Duplicate the `deploy-dev` job, point it at a staging cluster, and add it between dev and production with its own approval gate.

**Add integration tests**: Insert a job after `deploy-dev` that runs API tests against the live dev environment before the production gate.

**Canary or blue-green deploys**: Replace the ECS deploy action with CodeDeploy integration for traffic-shifting strategies.
