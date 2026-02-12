# Cornjacket Platform - Project Plan

**Last Updated:** 2026-02-10

## Current Phase

**Phase 1: Local Skeleton**

## Current Focus

- [ ] Add Traefik to docker-compose (HTTP routing)
- [ ] Add EMQX to docker-compose (MQTT broker)

Phase 1: Local Skeleton is complete. The system now provides an end-to-end event flow working locally with minimal code, including:
- Basic logging with structured JSON
- OpenAPI specs for all service endpoints
- Query Service: read from projections
- Automated end-to-end test
- Service client libraries (restructure for component testing)
- Time handling strategy (device time vs ingestion time, testability)
- Unit tests
- Integration tests (real Postgres/Redpanda via docker-compose)
- Top-level service wrappers (main.go entry points for each platform service)
- Component tests (real Postgres/Redpanda via docker-compose)
- Repositories tagged with `phase-1-local-skeleton`

## Milestones

### Phase 1: Local Skeleton
**Goal:** End-to-end event flow working locally with minimal code

```
HTTP Request → Ingestion → Outbox → Event Store + Redpanda → Consumer (Event Handler)
```

**Skipping:** Action Orchestrator, AI Service, MQTT, Traefik, authentication, AWS

### Phase 2: Local Full Stack
**Goal:** All services running locally as sidecar pattern, both entry points

- [x] [Brainstorm Phase 2 Implementation](tasks/013-brainstorm-phase-2-implementation.md)
- [x] [Docker Compose Restructure & Platform Containerization](tasks/014-docker-compose-restructure.md)
- [ ] [Embedded Migrations (service-owned, auto-applied on startup)](tasks/015-embedded-migrations.md)
- [ ] Add Traefik to docker-compose (HTTP routing)
- [ ] Add EMQX to docker-compose (MQTT broker)
- [ ] Action Orchestrator: webhook delivery
- [ ] MQTT ingestion path (EMQX → Ingestion Service)
- [ ] Full sidecar simulation in docker-compose (mirrors ECS task definition)
- [ ] E2E local test: HTTP + MQTT → projections → query
- [ ] Component tests with real client libraries
- [ ] Learn how to effectively use Redpanda (topics, consumer groups, etc.) for Phase 2 requirements.
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
| 2026-02-11 | Layered Docker Compose: subdirectory with base + fullstack overlay, no profiles | Two modes (skeleton for dev speed, fullstack for production fidelity). `-f` flags simpler than profiles. Details in Task 013, implementation in Spec 014. |

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
