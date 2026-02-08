# Cornjacket Platform Overview

This workspace organizes the platform into domain-specific repositories to enforce a **"need-to-know"** security model. By decoupling the foundational infrastructure from the application logic, we reduce the "blast radius" of changes and ensure that each component can evolve at its own pace.

## Global Directory Structure

<!-- Keep this tree concise: max 3 levels deep from cornjacket-platform/ -->
```text
cornjacket-platform/             # Wrapper folder (not a Git repo)
│
├── platform-infra/              # [Git Repo] Infrastructure foundation
│   └── ...                      # Terraform modules for VPC, networking, data
│
├── platform-services/           # [Git Repo] Application monolith
│   ├── cmd/platform/            # Single binary entry point
│   ├── internal/shared/         # Shared config, domain, infrastructure
│   ├── internal/services/       # Individual services (ingestion, query, etc.)
│   ├── tasks/                   # Feature task documents
│   └── deploy/                  # Service deployment Terraform
│
└── platform-docs/               # [Git Repo] Global documentation
    ├── decisions/               # Architectural Decision Records (ADRs)
    ├── insights/                # Patterns and learnings discovered during development
    ├── PROJECT.md               # Current phase and milestones
    └── design-spec.md           # Operational parameters
```

## Workspace Setup Guide

To maintain security and separation of concerns, this project is split into multiple repositories. We use a **Wrapper Folder** concept to organize these repositories locally.

### Local Setup
1. Create a parent directory: `mkdir cornjacket-platform && cd cornjacket-platform`
2. Clone the core repositories into this folder:
   - `git clone https://github.com/cornjacket/platform-docs.git`
   - `git clone https://github.com/cornjacket/platform-infra.git`
   - `git clone https://github.com/cornjacket/platform-services.git`
3. Create the `CLAUDE.md` symlink in the wrapper directory so that Claude Code can pick up project instructions when working from the top-level folder:
   ```bash
   ln -s platform-docs/CLAUDE.md CLAUDE.md
   ```

### The Wrapper Concept
The `cornjacket-platform/` directory is **not** a Git repository. It is a logical container that allows you to:
- **Cross-Reference:** Easily move between infrastructure and application code.
- **Local Simulation:** Use `docker-compose` at the service level to reference the entire platform.
- **Security:** Ensure that permissions are managed at the individual repository level, not the folder level.


## Repository Strategy

### 1. platform-infra (The Stage)
This repository contains the permanent, stateful infrastructure that rarely changes. It is the "land" upon which the rest of the platform is built.
* **Domain:** Networking (VPC, Subnets), Security (IAM Base), and Data (RDS, S3).
* **Security Model:** Highly restricted access. Changes require strict review as they impact all upstream services.
* **Key Tool:** Terraform with remote state management.

### 2. platform-services (The Performers)
A monolith containing all application-specific code and the "glue" required to run it. This allows for rapid feature development and atomic commits across different services.
* **Domain:** Application logic (ingestion, query, actions), shared libraries, and service-level deployment code.
* **Security Model:** Open to all product developers. Uses IAM Roles to restrict service-to-service permissions at runtime.
* **Integration:** Consumes networking and database information from platform-infra via the AWS SSM Parameter Store.
* **Feature Development:** New features are designed in task documents (`tasks/NNN-feature-name.md`) before implementation. See `tasks/README.md` for the template.



### 3. platform-docs (The Blueprint)
The centralized source of truth for the platform’s evolution and standards.
* **Domain:** Architectural Decision Records (ADRs), global standards, onboarding guides, and high-level diagrams.
* **Security Model:** Globally readable across the organization; write access reserved for Lead/Staff engineers.

---

## Documentation Conventions

- **HTML comments** in markdown files communicate constraints to maintainers (including AI assistants like Claude). Example: `<!-- Keep this tree concise: max 3 levels deep -->`. These don't render but persist in the source.
- **Task documents** (`platform-services/tasks/`) are for feature implementation specs, not documentation constraints.
- **Insights** (`platform-docs/insights/`) capture patterns and learnings discovered during development. Unlike ADRs (which document decisions), insights document wisdom gained. Create an insight when you discover a pattern worth remembering.

---

## Key Documentation

### platform-docs (this repo)

| Document | Purpose |
|----------|---------|
| [PROJECT.md](PROJECT.md) | Current phase, progress, and tagging policy |
| [design-spec.md](design-spec.md) | System design: data flow, event types, schemas, configuration |
| [decisions/](decisions/) | Architectural Decision Records (ADRs) — "why we decided X" |
| [insights/](insights/) | Patterns and learnings — "what we discovered" |
| [CLAUDE.md](CLAUDE.md) | Instructions for Claude Code AI assistant |

### platform-services

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](../platform-services/ARCHITECTURE.md) | Code structure, Clean Architecture alignment, dependency rules |
| [DEVELOPMENT.md](../platform-services/DEVELOPMENT.md) | Build patterns, local dev setup, coding conventions |
| [tasks/](../platform-services/tasks/) | Feature implementation task documents |
| [e2e/README.md](../platform-services/e2e/README.md) | End-to-end test framework and usage |

### platform-infra

| Document | Purpose |
|----------|---------|
| platform-standards.md | Infrastructure standards and conventions |

---

## Integration Pattern: The "Handshake"
To maintain the separation of concerns, the repositories do not share code. Instead, they communicate through **AWS SSM Parameter Store**.
1. **Infra** publishes resource IDs (like vpc-id or db-endpoint).
2. **Services** retrieve these IDs during the deployment phase to "handshake" with the environment.
