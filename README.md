# Cornjacket Platform Overview

This workspace organizes the platform into domain-specific repositories to enforce a **"need-to-know"** security model. By decoupling the foundational infrastructure from the application logic, we reduce the "blast radius" of changes and ensure that each component can evolve at its own pace.

## Global Directory Structure

<!-- Keep this tree concise: max 5 levels deep from cornjacket-platform/ -->
```text
cornjacket-platform/                      # Wrapper folder (not a Git repo)
│
├── platform-infra/                       # [Git Repo] Foundational infrastructure (Terraform)
│   ├── platform-infra-networking/        # Manages VPC, subnets, etc.
│   │   ├── dev/                          # dev environment-specific config
│   │   │   └── main.tf
│   │   └── modules/                      # Reusable Terraform modules
│   │       └── platform-vpc/
│
├── platform-services/                    # [Git Repo] Application monolith (Go)
│   ├── internal/                         # All application code
│   │   ├── services/                     # Business logic for each service
│   │   │   ├── ingestion/                # Handles incoming events
│   │   │   │   ├── handler.go            # HTTP driving adapter
│   │   │   │   └── service.go            # Application use cases
│   │   │   ├── eventhandler/             # Processes events into projections
│   │   │   │   ├── consumer.go           # Redpanda consumer
│   │   │   │   └── handlers.go           # Event-specific logic
│   │   │   ├── query/                    # Serves read-only projections
│   │   │   │   └── handler.go
│   │   │   ├── actions/                  # (Future) Orchestrates actions
│   │   │   └── tsdb/                     # (Future) Handles time-series data
│   │   └── shared/                       # Code shared between services
│   │       ├── domain/                   # Core entities (events, clock)
│   │       │   └── events/
│   │       └── infra/                    # Infra clients (Postgres, Redpanda)
│   │           └── postgres/
│   └── e2e/                              # End-to-end test suite
│       ├── tests/
│       │   └── full_flow.go
│
└── platform-docs/                        # [Git Repo] Global documentation
    ├── decisions/                        # Architectural Decision Records (ADRs)
    │   └── 0001-event-driven-cqrs-architecture.md
    ├── insights/                         # Architectural patterns and learnings
    │   ├── architecture/
    │   │   └── 001-time-separation-of-concerns.md
    │   └── development/
```

## Key Architectural Principles

This section provides a high-level summary of the core architectural patterns that govern the platform. For a detailed breakdown, see the [design-spec.md](design-spec.md).

### Event-Driven Data Flow (CQRS)

The platform uses a CQRS (Command Query Responsibility Segregation) pattern. The flow is one-way and decoupled, allowing for high reliability and scalability.

1.  **Ingestion (Write Path)**: The **Ingestion Service** receives an event, immediately saves it to a durable `outbox` table in PostgreSQL, and then publishes it to a **Redpanda** (Kafka) message bus. This ensures no data is lost.
2.  **Processing**: The **EventHandler Service** consumes events from Redpanda and uses them to build "projections"—read-optimized views of the data (e.g., `latest_sensor_state`).
3.  **Querying (Read Path)**: The **Query Service** serves fast reads to clients by querying the pre-computed projections directly.

### Time as a Dependency

To ensure tests are reliable and data is accurate, the platform treats time as an abstracted dependency.

-   **`clock` Package**: All code must call `clock.Now()` instead of `time.Now()`. This allows tests to inject a `FixedClock` for deterministic results.
-   **Dual Timestamps**: Events have two timestamps:
    -   `EventTime`: When the event occurred (business time), set by the client.
    -   `IngestedAt`: When the platform received it (audit time), set by the server.

This design is detailed in [ADR-0015](decisions/0015-time-handling-strategy.md) and the [Clock as Dependency Injection insight](insights/architecture/002-clock-as-dependency-injection.md).

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
-   **Cross-Reference:** Easily move between infrastructure and application code.
-   **Local Simulation:** Use `docker-compose` at the service level to reference the entire platform.
-   **Security:** Ensure that permissions are managed at the individual repository level, not the folder level.


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
| [tasks/](../platform-services/tasks/) | Feature implementation task documents and backlog |
| [e2e/README.md](../platform-services/e2e/README.md) | End-to-end test framework and usage |

## Backlog for platform-services

The `platform-services/tasks/backlog/` directory contains potential future tasks that are not yet committed for immediate implementation. These tasks are not numbered sequentially with the main `tasks/` directory. When a task from the backlog is committed for development, it will be moved from `backlog/` to `tasks/` and assigned the next available sequential number.

The `platform-services/tasks/BACKLOG.md` file provides an index and summary of all items currently in the backlog. It serves as a central place to track potential work without conflating it with actively planned and sequenced tasks.

This approach helps maintain a clear separation between:
- **Committed Tasks:** Items in `platform-services/tasks/` that are part of the current development plan and are assigned sequential numbers.
- **Potential Tasks (Backlog):** Items in `platform-services/tasks/backlog/` that are identified but not yet prioritized or scheduled for implementation.

This ensures that the main `tasks/` directory remains focused on immediate development, while the backlog provides a structured way to capture and manage future work.


### platform-infra

| Document | Purpose |
|----------|---------|
| platform-standards.md | Infrastructure standards and conventions |

---

## Integration Pattern: The "Handshake"
To maintain the separation of concerns, the repositories do not share code. Instead, they communicate through **AWS SSM Parameter Store**.
1. **Infra** publishes resource IDs (like vpc-id or db-endpoint).
2. **Services** retrieve these IDs during the deployment phase to "handshake" with the environment.

