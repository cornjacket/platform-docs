# Cornjacket Platform - Project Plan

**Last Updated:** 2026-02-06

## Current Phase

**Phase 1: Local Skeleton**

## Current Focus

- [x] Basic logging with structured JSON
- [x] OpenAPI specs for all service endpoints
- [x] Query Service: read from projections
- [x] Automated end-to-end test
- [ ] Service client libraries (restructure for component testing)
- [ ] Unit tests

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
- [x] Ingestion Worker: NOTIFY/LISTEN → event store + Redpanda publish
- [x] Event Handler: Redpanda consumer → projection update
- [x] Basic logging with structured JSON
- [x] OpenAPI specs for all service endpoints
- [x] Query Service: read from projections
- [x] Automated end-to-end test
- [ ] Service client libraries (restructure for component testing)
- [ ] Unit tests

**Skipping:** Action Orchestrator, AI Service, MQTT, Traefik, authentication, AWS

### Phase 2: Local Full Stack
**Goal:** All services running locally as sidecar pattern, both entry points

- [ ] Add Traefik to docker-compose (HTTP routing)
- [ ] Add EMQX to docker-compose (MQTT broker)
- [ ] Action Orchestrator: webhook delivery
- [ ] MQTT ingestion path (EMQX → Ingestion Service)
- [ ] Full sidecar simulation in docker-compose (mirrors ECS task definition)
- [ ] E2E local test: HTTP + MQTT → projections → query
- [ ] Component tests with real client libraries

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
**Goal:** Deploy validated sidecar pattern to ECS

- [ ] platform-infra: VPC, subnets, security groups
- [ ] platform-infra: ECS cluster, ECR repositories
- [ ] platform-infra: EFS/EBS for persistence
- [ ] platform-services/deploy: ECS task definition (Terraform, mirrors docker-compose)
- [ ] GitHub Actions: build → push to ECR → terraform apply
- [ ] E2E smoke test against deployed environment
- [ ] Verify all access patterns (HTTP, MQTT, dashboards)

### Phase 5: Polish
**Goal:** Production-ready features

- [ ] AI Inference Service (Python/FastAPI)
- [ ] TSDB Writer (optional consumer)
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
| 2026-02-06 | Move Query Service to Phase 1 | Enables automated e2e testing |
| 2026-02-06 | Add service client libraries before unit tests | Enables component testing with mocks |

---

## Blockers / Open Questions

- None currently

---

## Tagging Policy

Tags are created at **phase completion** and **releases** only. This avoids tag proliferation while providing meaningful checkpoints. See ADR-0011.

| Tag Type | Format | Example |
|----------|--------|---------|
| Phase | `phase-N-description` | `phase-1-local-skeleton` |
| Release | `vX.Y.Z` | `v0.1.0` |

Apply the same tag to all three repos. Intermediate progress is tracked via commits, not tags.

---

## Reference

- [ADRs](decisions/) — Architectural decisions
- [Design Spec](design-spec.md) — Operational parameters
- [Development Guide](../platform-services/DEVELOPMENT.md) — Build patterns and conventions
