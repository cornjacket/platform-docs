# Cornjacket Platform - Claude Code Instructions

## Project Overview

This is the Cornjacket Platform, an event-driven CQRS system for data ingestion, real-time AI inference, and event orchestration. The platform targets IoT and security stream processing.

## Workspace Structure

The workspace uses a **wrapper folder** pattern with 3 separate Git repositories and 1 meta-repo:

- `platform-infra/` — Infrastructure foundation (Terraform: VPC, networking, data). Highly restricted access.
- `platform-services/` — Application monolith (Go services, shared libs, deployment code). Open to product developers.
- `platform-docs/` — Global documentation, ADRs, architecture decisions. Source of truth.
- `ai-builder-lessons/` — Project-agnostic lessons learned from AI-assisted software development. Reusable across future projects.

The `cornjacket-platform/` wrapper directory is **not** a Git repo. It uses **bare repositories** (`.repos/`) with **git worktrees** for each branch:

```
cornjacket-platform/
├── .repos/              # bare repos (docs.git, infra.git, services.git)
├── platform-docs/main/
├── platform-infra/main/
├── platform-services/main/
└── create-feature.sh
```

### Feature Branch Workflow

1. Create feature worktrees across all repos: `./create-feature.sh feature-name`
2. This creates `platform-docs/feature-name/`, `platform-infra/feature-name/`, `platform-services/feature-name/`
3. Work in the feature worktrees. AI agents should operate within the same branch name across all repos.
4. When done, merge each repo's feature branch to main independently, then remove the worktrees:
   ```
   git -C .repos/docs.git worktree remove ../platform-docs/feature-name
   git -C .repos/infra.git worktree remove ../platform-infra/feature-name
   git -C .repos/services.git worktree remove ../platform-services/feature-name
   ```

### AI Agent Configuration Symlinks

This file (`platform-docs/main/CLAUDE.md`) is the source of truth for AI agent instructions. It is symlinked from the wrapper directory so that AI agents automatically pick it up regardless of which tool is used:

- `cornjacket-platform/CLAUDE.md` → `platform-docs/main/CLAUDE.md` (Claude Code, Cursor)
- `cornjacket-platform/GEMINI.md` → `platform-docs/main/CLAUDE.md` (Gemini)

Both symlinks point to the same file on the `main` branch. Claude Code walks up the directory tree to find CLAUDE.md, so the root symlink is loaded regardless of which worktree Claude is invoked from.

### Cross-Repo Path Convention

The workspace uses a **git worktree** layout: `platform-<repo>/<branch>/`. Cross-repo markdown links use the token `{GIT_COMMON_BRANCH_NAME}` in the path (e.g., `../../platform-services/{GIT_COMMON_BRANCH_NAME}/DEVELOPMENT.md`). AI agents must resolve this token to their current working branch. All repos should be on the same branch during feature work.

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

**AI agent workflow:**
1. **Create the task document first** (spec or task, as appropriate)
2. **Commit the task document** — this creates a checkpoint to restart from if implementation fails
3. Implement the change
4. Test the implementation
5. Commit the implementation

## Feature Development Process

Changes are tracked in two task directories, each with its own numbering sequence:

| Directory | Scope |
|-----------|-------|
| `platform-services/tasks/` | Code, tests, service-level docs |
| `platform-docs/tasks/` | Workspace structure, cross-repo concerns, project process |

There are two types of task document:

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

See `platform-services/tasks/README.md` and `platform-docs/tasks/README.md` for templates, conventions, and indexes.

## Tagging Policy

Tags are created at **phase completion** and **releases** only (see ADR-0011). This avoids tag proliferation while providing meaningful checkpoints.

| Tag Type | Format | Example |
|----------|--------|---------|
| Phase | `phase-N-description` | `phase-1-local-skeleton` |
| Release | `vX.Y.Z` | `v0.1.0` |

Apply the same tag to all three repos and **push tags immediately** (`git push origin <tag>`). Tags must exist on the remote — local-only tags are lost on re-clone. Intermediate progress is tracked via commits, not tags.

## Conciseness Rule

**Be concise in all output.** This applies to both conversational responses and generated documents (task docs, specs, comments, commit messages). Avoid filler, redundant explanations, and over-elaboration. Say what needs to be said, then stop. This directly reduces token usage and keeps context windows focused on useful information.

- Prefer short sentences over long ones
- Omit obvious context the user already knows
- In documents, use tables and bullet points over prose where possible
- Don't repeat information that exists elsewhere — link to it instead

## AI Builder Lessons

`ai-builder-lessons/` is a **project-agnostic** repo for capturing patterns, anti-patterns, and decision frameworks discovered while building software with AI agents. It is deliberately kept outside the three platform repos because its content is not specific to cornjacket — it is intended to be a reusable reference and evolving decision tree for future AI-assisted projects.

**When to record a lesson:** Whenever an interaction with the AI agent reveals a generalizable insight — a workflow that worked well, a prompt pattern that failed, an architectural decision shaped by the AI collaboration model, or a process worth repeating.

**Goal:** Build toward a common template and decision tree that can bootstrap new projects built with AI assistance.
