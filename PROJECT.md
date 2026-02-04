# Cornjacket Platform - Project Plan

**Last Updated:** 2026-02-03

## Current Phase

**Phase 1: Local Skeleton**

## Current Focus

- [ ] Start docker-compose and run migrations
- [ ] Test ingestion endpoint manually (curl)
- [ ] Implement Outbox Processor (NOTIFY/LISTEN)

## Milestones

### Phase 1: Local Skeleton
**Goal:** End-to-end event flow working locally with minimal code

```
HTTP Request → Ingestion → Outbox → Event Store + Redpanda → Consumer (Event Handler)
```

- [x] Go module initialized with directory structure
- [x] docker-compose.yml with Postgres + Redpanda
- [x] Database migrations (outbox, event_store, projections, dlq tables)
- [x] Ingestion Service: HTTP endpoint → outbox write
- [ ] Outbox Processor: NOTIFY/LISTEN → event store + Redpanda publish
- [ ] Event Handler: Redpanda consumer → projection update
- [ ] Basic logging with structured JSON
- [ ] Manual end-to-end test (curl → check projection)

**Skipping:** Query Service, Action Orchestrator, AI Service, MQTT, Traefik, authentication, AWS

### Phase 2: Local Full Stack
**Goal:** All services running locally, both entry points

- [ ] Add Traefik to docker-compose (HTTP routing)
- [ ] Add EMQX to docker-compose (MQTT broker)
- [ ] Query Service: read from projections
- [ ] MQTT ingestion path (EMQX → Ingestion Service)
- [ ] Component tests with real client libraries
- [ ] Mock outbound interfaces for testing

**Skipping:** AWS, CI/CD, AI Service

### Phase 3: CI Foundation
**Goal:** Automated quality gates before AWS deployment

- [ ] GitHub Actions: lint, format (golangci-lint, gofmt)
- [ ] GitHub Actions: unit tests, component tests
- [ ] GitHub Actions: Docker build (no push yet)
- [ ] GitHub Actions: Terraform validate/plan for platform-infra
- [ ] Security scanning (gosec or similar)

**Skipping:** ECR push, AWS deployment

### Phase 4: AWS Dev Environment
**Goal:** Running in ECS with the full sidecar pattern

- [ ] platform-infra: VPC, subnets, security groups
- [ ] platform-infra: ECS cluster, ECR repositories
- [ ] platform-infra: EFS/EBS for persistence
- [ ] platform-services/deploy: ECS task definition (Terraform)
- [ ] GitHub Actions: build → push to ECR → terraform apply
- [ ] E2E smoke test against deployed environment
- [ ] Verify all access patterns (HTTP, MQTT, dashboards)

### Phase 5: Polish
**Goal:** Production-ready features

- [ ] AI Inference Service (Python/FastAPI)
- [ ] TSDB Writer (optional consumer)
- [ ] Action Orchestrator with webhook delivery
- [ ] Circuit breaker for webhooks
- [ ] DLQ implementation
- [ ] Observability: structured logging, CloudWatch metrics
- [ ] Error handling per ADR-0004

---

## Decisions Log

Implementation decisions made during development (not ADR-level).

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-03 | Project plan created | Starting Phase 1 |

---

## Blockers / Open Questions

- None currently

---

## Creating Milestones

Milestones use coordinated Git tags across all three repos (see ADR-0011).

### When to Create a Milestone

- End of a development phase
- Before significant architectural changes
- After completing a major feature
- Any point you might want to return to for debugging

### How to Create a Milestone

1. Ensure all repos are committed and clean
2. Choose a tag name: `milestone-NNN-description`
3. Apply the same tag to all three repos:

```bash
# In each repo (platform-docs, platform-services, platform-infra)
git tag -a milestone-001-phase1-ingestion -m "Phase 1: Ingestion service complete"
```

4. Record the milestone below

### Milestone History

| Tag | Date | Description |
|-----|------|-------------|
| `milestone-001-phase1-dbperservice` | 2026-02-04 | Ingestion service + database-per-service pattern |

---

## Reference

- [ADRs](decisions/) — Architectural decisions
- [Design Spec](design-spec.md) — Operational parameters
- [Development Guide](../platform-services/DEVELOPMENT.md) — Build patterns and conventions
