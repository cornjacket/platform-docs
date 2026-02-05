# Cornjacket Platform - Claude Code Instructions

## Project Overview

This is the Cornjacket Platform, an event-driven CQRS system for data ingestion, real-time AI inference, and event orchestration. The platform targets IoT and security stream processing.

## Workspace Structure

The workspace uses a **wrapper folder** pattern with 3 separate Git repositories:

- `platform-infra/` — Infrastructure foundation (Terraform: VPC, networking, data). Highly restricted access.
- `platform-services/` — Application monolith (Go services, shared libs, deployment code). Open to product developers.
- `platform-docs/` — Global documentation, ADRs, architecture decisions. Source of truth.

The `cornjacket-platform/` wrapper directory is **not** a Git repo. It is a logical container for cross-referencing between repos.

## Key Architecture

- **Entry Layer:** Traefik (HTTP gateway) + EMQX (MQTT broker)
- **Application Layer (Networked Monolith):**
  - Ingestion Service (Go, :8080) — validates/writes events, publishes to Redpanda
  - Query Service (Go, :8081) — reads from projections/TSDB
  - Action Orchestrator (Go, :8082) — triggers webhooks/alerts
  - Event Handler — background worker for CQRS projections
- **Data Layer:** Redpanda (Kafka-compatible message bus) + PostgreSQL with TimescaleDB
- **Processing Layer:** AI Inference Service (Python/FastAPI) — stream processor for anomaly detection

## Integration Pattern

Repos communicate via **AWS SSM Parameter Store**. Infrastructure publishes resource IDs; services retrieve them at deploy time.

## Key Documentation

- `platform-docs/README.md` — Workspace overview and setup guide
- `platform-docs/decisions/` — Architectural Decision Records (ADRs)
- `platform-infra/platform-standards.md` — Infrastructure standards
- `platform-infra/platform-infra-networking/specification.md` — Networking blueprint

## Development Notes

- Dev environment runs as a single ECS Fargate task (1 vCPU, 2GB RAM) with 5 sidecar containers
- Message format is JSON (binary migration deferred)
- CQRS with eventual consistency between write and read sides
- Each service owns its database and migrations (see ADR-0010)
- Many production decisions are explicitly deferred (see ADR 0001)

## Feature Development Process

When adding features to platform-services:

1. **Create a task document** in `platform-services/tasks/NNN-feature-name.md`
2. **Review the design** before writing code (status: Draft → Ready)
3. **Implement** when approved (status: In Progress)
4. **Complete** when done and committed (status: Complete)

Task documents define what, why, how, and acceptance criteria. See `platform-services/tasks/README.md` for the template and convention.

This ensures designs are reviewed before implementation and creates a record of feature decisions.

## Tagging Policy

Tags are created at **phase completion** and **releases** only (see ADR-0011). This avoids tag proliferation while providing meaningful checkpoints.

| Tag Type | Format | Example |
|----------|--------|---------|
| Phase | `phase-N-description` | `phase-1-local-skeleton` |
| Release | `vX.Y.Z` | `v0.1.0` |

Apply the same tag to all three repos. Intermediate progress is tracked via commits, not tags.
