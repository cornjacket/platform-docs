# Cornjacket Platform - Claude Code Instructions

## Project Overview

This is the Cornjacket Platform, an event-driven CQRS system for data ingestion, real-time AI inference, and event orchestration. The platform targets IoT and security stream processing.

## Workspace Structure

The workspace uses a **wrapper folder** pattern with 3 separate Git repositories and 1 meta-repo:

- `platform-infra/` — Infrastructure foundation (Terraform: VPC, networking, data). Highly restricted access.
- `platform-services/` — Application monolith (Go services, shared libs, deployment code). Open to product developers.
- `platform-docs/` — Global documentation, ADRs, architecture decisions. Source of truth.
- `ai-builder-lessons/` — Project-agnostic lessons learned from AI-assisted software development. Reusable across future projects.

The `cornjacket-platform/` wrapper directory is **not** a Git repo. It is a logical container for cross-referencing between repos.

### AI Agent Configuration Symlinks

This file (`platform-docs/CLAUDE.md`) is the source of truth for AI agent instructions. It is symlinked from the wrapper directory so that AI agents automatically pick it up regardless of which tool is used:

- `cornjacket-platform/CLAUDE.md` → `platform-docs/CLAUDE.md` (Claude Code, Cursor)
- `cornjacket-platform/GEMINI.md` → `platform-docs/CLAUDE.md` (Gemini)

Both symlinks point to the same file. Edits made via either path modify this file in `platform-docs/`, where it is version-controlled.

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

## Change Tracking Rule

**Every change to the codebase MUST have an accompanying task document.** No exceptions. If a user gives instructions in chat to make a change, the AI agent must first create the task document before modifying any code. This applies to all repos, not just platform-services.

This rule ensures:
- Complete traceability — every commit has a corresponding "why" document
- Replay capability — from any tagged commit, the sequence of task docs can be used to reimplement the codebase
- No changes slip through undocumented, regardless of how they were initiated

**AI agent workflow for chat-initiated changes:**
1. Receive instruction in chat
2. **Create the task document first** (spec or task, as appropriate)
3. Then implement the change
4. Commit both the task doc and the code changes together

## Feature Development Process

All changes are tracked in `platform-services/tasks/` using a shared numbering sequence. There are two types:

### Specs (heavyweight — design review required)

For new features, significant changes, or anything requiring design decisions:

1. **Create a spec** in `platform-services/tasks/NNN-feature-name.md` using the spec template
2. **Review the design** before writing code (status: Draft → Ready)
3. **Implement** when approved (status: In Progress)
4. **Complete** when done and committed (status: Complete)

### Tasks (lightweight — record and implement)

For bug fixes, minor changes, config tweaks, or any small change that doesn't need design review:

1. **Create a task** in `platform-services/tasks/NNN-description.md` using the task template
2. **Implement** immediately (status: In Progress → Complete)

**Grouping rule:** Closely related tasks in the same session can share a single task document to avoid proliferation. Group by coherence (same area of concern), not just timing. Unrelated changes get separate docs. Specs are never grouped.

See `platform-services/tasks/README.md` for both templates, conventions, and the full index.

## Tagging Policy

Tags are created at **phase completion** and **releases** only (see ADR-0011). This avoids tag proliferation while providing meaningful checkpoints.

| Tag Type | Format | Example |
|----------|--------|---------|
| Phase | `phase-N-description` | `phase-1-local-skeleton` |
| Release | `vX.Y.Z` | `v0.1.0` |

Apply the same tag to all three repos. Intermediate progress is tracked via commits, not tags.

## AI Builder Lessons

`ai-builder-lessons/` is a **project-agnostic** repo for capturing patterns, anti-patterns, and decision frameworks discovered while building software with AI agents. It is deliberately kept outside the three platform repos because its content is not specific to cornjacket — it is intended to be a reusable reference and evolving decision tree for future AI-assisted projects.

**When to record a lesson:** Whenever an interaction with the AI agent reveals a generalizable insight — a workflow that worked well, a prompt pattern that failed, an architectural decision shaped by the AI collaboration model, or a process worth repeating.

**Goal:** Build toward a common template and decision tree that can bootstrap new projects built with AI assistance.
