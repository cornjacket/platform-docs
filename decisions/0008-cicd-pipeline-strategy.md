# ADR 0008: CI/CD Pipeline Strategy

* **Status:** Accepted
* **Date:** 2026-01-29
* **Architect:** David

## Context

The platform requires automated build, test, and deployment pipelines. The CI/CD strategy must balance automation with cost-consciousness for a single-developer project.

## Decision

### Build Artifacts

| Artifact | Build | Storage |
|----------|-------|---------|
| Go binary | `go build` | Embedded in Docker image |
| Python AI service | `pip install` in Dockerfile | Docker image |
| Go Docker image | `docker build` | ECR |
| Python Docker image | `docker build` | ECR |
| Terraform state | N/A | S3 (remote backend) |

**Notes:**
- ECR repositories are provisioned by Terraform in platform-infra
- Dependency order: platform-infra must be deployed first to create ECR repos before platform-services can push images

### Pipeline Stages

| Stage | Tool | Repo | Trigger |
|-------|------|------|---------|
| Lint + format | GitHub Actions | platform-services | PR to main |
| Unit + component tests | GitHub Actions | platform-services | PR to main |
| Security scan | GitHub Actions | platform-services | PR to main |
| Terraform validate/plan | GitHub Actions | platform-infra | PR to main |
| Build + Push to ECR | GitHub Actions | platform-services | Merge to main |
| Terraform apply (infra) | GitHub Actions | platform-infra | Merge to main |
| Terraform apply (app deploy) | GitHub Actions | platform-services/deploy | Merge to main |
| E2E tests | GitHub Actions | TBD | Periodic (daily) or post-deploy |

### Deployment Model

| Environment | Method | Automation |
|-------------|--------|------------|
| **Dev** | Terraform via GitHub Actions | Fully automated on merge to main |
| **Staging/Prod** | AWS CodePipeline | Deferred |

**Dev Environment:**
- Merge to main triggers: build → push to ECR → `terraform apply` → ECS rolls out new containers
- No manual approval required

**Staging/Prod (Deferred):**
- AWS CodePipeline provides native ECS deployment strategies (rolling updates, blue-green) and approval gates not available in Terraform-only deployments
- This additional control is appropriate for production environments

### Tool Selection Rationale

**GitHub Actions for CI (test, build, push, Terraform):**
- Native GitHub integration
- Familiar workflow for developers
- Generous free tier for single-developer project
- Can authenticate to AWS for ECR push and Terraform apply

**Terraform for Deployment (Dev):**
- Single tool for infrastructure and deployment — simpler mental model
- Image version tracked in git (GitOps model)
- Easy rollback by applying previous commit
- Sufficient for dev environment without sophisticated deployment strategies

**AWS CodePipeline for Deployment (Staging/Prod, Deferred):**
- Native ECS deployment strategies (rolling, blue-green, canary)
- Built-in approval gates for production safety
- AWS-native visibility and logging
- Appropriate when deployment frequency increases or team grows

## Consequences

### Benefits
- Fully automated dev deployment on merge
- GitOps model with Terraform — infrastructure and app versions tracked in git
- Clear separation of CI (GitHub Actions) and CD (Terraform/CodePipeline)
- Easy rollback via git revert + terraform apply

### Trade-offs
- Terraform-based deployment lacks sophisticated strategies (no blue-green in dev)
- Two different deployment mechanisms for dev vs. prod
- GitHub Actions requires AWS credentials management

### Deferred Decisions
- CodePipeline configuration for staging/prod
- Blue-green deployment strategy details
- Approval gate policies for production
- E2E test trigger strategy (post-deploy vs. scheduled)

## Related ADRs
- ADR-0001: Event-Driven CQRS Architecture
- ADR-0007: Local and Cloud Development Strategy
