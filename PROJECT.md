# Cornjacket Platform - Project Plan

**Last Updated:** 2026-02-03

## Current Phase

**Phase 1: Local Skeleton**

## Current Focus

- [ ] Set up Go module and project structure
- [ ] Create docker-compose.yml with Postgres + Redpanda
- [ ] Implement minimal Ingestion endpoint (HTTP → Outbox)

## Milestones

### Phase 1: Local Skeleton
**Goal:** End-to-end event flow working locally with minimal code

```
HTTP Request → Ingestion → Outbox → Event Store + Redpanda → Consumer (Event Handler)
```

- [ ] Go module initialized with directory structure
- [ ] docker-compose.yml with Postgres + Redpanda
- [ ] Database migrations (outbox, event_store, projections tables)
- [ ] Ingestion Service: HTTP endpoint → outbox write
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

## Reference

- [ADRs](decisions/) — Architectural decisions
- [Design Spec](design-spec.md) — Operational parameters
- [Development Guide](../platform-services/DEVELOPMENT.md) — Build patterns and conventions
