# Cornjacket Platform Overview

This workspace organizes the platform into domain-specific repositories to enforce a **"need-to-know"** security model. By decoupling the foundational infrastructure from the application logic, we reduce the "blast radius" of changes and ensure that each component can evolve at its own pace.

## Global Directory Structure

```text
cornjacket-platform/             # The "Wrapper" Parent Folder (Not a Git repo)
│
├── platform-infra/              # [Git Repo 1] The Infrastructure Foundation
│   ├── platform-infra-networking/
│   │   ├── dev/                 # Terraform for the Dev VPC
│   │   ├── modules/             # Reusable network logic
│   │   ├── specification.md     # Networking blueprint
│   │   └── platform-standards.md
│   └── platform-infra-data/     # (Phase 2) Databases & S3
│
├── platform-services/           # [Git Repo 2] The Application Monolith
│   ├── apps/                    # All individual service code
│   │   ├── auth-service/
│   │   ├── api-gateway/
│   │   └── worker-service/
│   ├── shared/                  # Shared libraries/utilities
│   ├── deploy/                  # Terraform to "glue" apps to infra
│   │   ├── data.tf              # Pulls VPC ID from SSM
│   │   └── main.tf              # Deploys containers/Lambdas
│   └── docker-compose.yml       # Local development setup
│
└── platform-docs/               # [Git Repo 3] Global Documentation
    ├── architecture-diagrams/
    └── onboarding-guides.md
```

## Repository Strategy

### 1. platform-infra (The Stage)
This repository contains the permanent, stateful infrastructure that rarely changes. It is the "land" upon which the rest of the platform is built.
* **Domain:** Networking (VPC, Subnets), Security (IAM Base), and Data (RDS, S3).
* **Security Model:** Highly restricted access. Changes require strict review as they impact all upstream services.
* **Key Tool:** Terraform with remote state management.

### 2. platform-services (The Performers)
A monolith containing all application-specific code and the "glue" required to run it. This allows for rapid feature development and atomic commits across different services.
* **Domain:** Application logic (auth, api, workers), Shared libraries, and Service-level deployment code.
* **Security Model:** Open to all product developers. Uses IAM Roles to restrict service-to-service permissions at runtime.
* **Integration:** Consumes networking and database information from platform-infra via the AWS SSM Parameter Store.



### 3. platform-docs (The Blueprint)
The centralized source of truth for the platform’s evolution and standards.
* **Domain:** Architectural Decision Records (ADRs), global standards, onboarding guides, and high-level diagrams.
* **Security Model:** Globally readable across the organization; write access reserved for Lead/Staff engineers.

---

## Integration Pattern: The "Handshake"
To maintain the separation of concerns, the repositories do not share code. Instead, they communicate through **AWS SSM Parameter Store**. 
1. **Infra** publishes resource IDs (like vpc-id or db-endpoint).
2. **Services** retrieve these IDs during the deployment phase to "handshake" with the environment.
