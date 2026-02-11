# Cornjacket Platform - Project Plan

**Last Updated:** 2026-02-10

## Current Phase

**Phase 1: Local Skeleton**

## Current Focus

- [x] Basic logging with structured JSON
- [x] OpenAPI specs for all service endpoints
- [x] Query Service: read from projections
- [x] Automated end-to-end test
- [x] Service client libraries (restructure for component testing)
- [x] Time handling strategy (device time vs ingestion time, testability)
- [x] Unit tests
- [x] Integration tests (real Postgres/Redpanda via docker-compose)
- [x] Top-level service wrappers (main.go entry points for each platform service)
- [x] Component tests (real Postgres/Redpanda via docker-compose)
- [ ] Review integration test polling pattern vs channel-based mock pattern
- [ ] Tag `phase-1-local-skeleton` on platform-services, platform-docs, platform-infra

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
- [x] Service client libraries (restructure for component testing)
- [x] Time handling strategy (device time vs ingestion time, testability)
- [x] Unit tests
- [x] Integration tests (real Postgres/Redpanda via docker-compose)
- [x] Top-level service wrappers (main.go entry points for each platform service)
- [x] Component tests (real Postgres/Redpanda via docker-compose)
- [ ] Review integration test polling pattern vs channel-based mock pattern
- [ ] Tag `phase-1-local-skeleton` on platform-services, platform-docs, platform-infra

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
- [ ] Evaluate whether pull requests are needed for this project
- [ ] Tag `phase-2-local-full-stack` on platform-services, platform-docs, platform-infra

**Skipping:** AWS, CI/CD, AI Service

### Phase 3: CI Foundation
**Goal:** Automated quality gates before AWS deployment

- [ ] GitHub Actions: lint, format (golangci-lint, gofmt)
- [ ] GitHub Actions: unit tests, component tests
- [ ] GitHub Actions: test coverage reports (track %, fail on regression)
- [ ] GitHub Actions: Docker build (no push yet)
- [ ] GitHub Actions: Terraform validate/plan for platform-infra
- [ ] Security scanning (gosec or similar)
- [ ] Migrate integration tests from docker-compose to testcontainers (self-contained CI)
- [ ] Tag `phase-3-ci-foundation` on platform-services, platform-docs, platform-infra

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
- [ ] Tag `phase-4-aws-dev` on platform-services, platform-docs, platform-infra

### Phase 5: Polish
**Goal:** Production-ready features

- [ ] AI Inference Service (Python/FastAPI)
- [ ] TSDB Writer (optional consumer)
- [ ] Circuit breaker for webhooks
- [ ] DLQ implementation
- [ ] Observability: structured logging, CloudWatch metrics
- [ ] Error handling per ADR-0004
- [ ] Tag `phase-5-polish` on platform-services, platform-docs, platform-infra

---

## Decisions Log

Implementation decisions made during development (not ADR-level).

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-03 | Project plan created | Starting Phase 1 |
| 2026-02-06 | Move Query Service to Phase 1 | Enables automated e2e testing |
| 2026-02-06 | Add service client libraries before unit tests | Enables component testing with mocks |
| 2026-02-10 | Integration tests use docker-compose (Phase 1), defer testcontainers to Phase 3 | docker-compose already exists; testcontainers needed only when CI requires self-contained tests. Test helpers abstracted behind `internal/testutil/` so migration is zero-cost. See Lesson 005. |

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
