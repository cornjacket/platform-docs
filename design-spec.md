# Cornjacket Platform Design Specification

**Last Updated:** 2026-02-13
**Status:** Living Document

This document contains operational details, configuration parameters, and implementation specifics that may change over time. For architectural decisions and rationale, see the [ADRs index](decisions/README.md).

Each section below links to a detailed document. Read the summary to determine if you need the full section.

---

## Sections

### [1. Related ADRs](design-spec/01-related-adrs.md)
Cross-reference table linking all 16 ADRs to their topics. Use this to find the rationale behind any architectural decision.

### [2. Dev Environment Task Architecture](design-spec/02-dev-environment.md)
ECS task composition (6 containers), communication patterns, persistent storage, resource allocation, access patterns, cost estimates, service database configuration, Docker Compose layering (skeleton vs fullstack modes), and service health/startup reliability requirements.

### [3. Data Flow](design-spec/03-data-flow.md)
Service-level view of the Ingestion → EventHandler → Query pipeline. Includes ASCII diagrams showing both the high-level flow and internal implementation details. Describes the write path (HTTP → outbox → event store + Redpanda), read path (consumer → projections), and query path.

### [4. Event Types](design-spec/04-event-types.md)
Topic routing rules (event_type prefix → Redpanda topic), event catalog with payload schemas, example JSON payloads, and projection mappings.

### [5. Message Bus Configuration](design-spec/05-message-bus.md)
Redpanda topic design, retention policies (24h dev), and partition strategy (1 partition per topic in dev).

### [6. Database Schemas](design-spec/06-database-schemas.md)
Table definitions for outbox, event_store, DLQ, and projections. Includes all indexes with design rationale. Notes on DLQ implementation status.

### [7. Action Orchestrator Configuration](design-spec/07-action-orchestrator.md)
Webhook retry logic (exponential backoff), timeout handling, rate limiting, deduplication, and circuit breaker settings. All values are initial defaults subject to tuning.

### [8. Scale & Performance Requirements (Dev)](design-spec/08-scale-performance.md)
Target throughput (~10 req/s), latency requirements (< 500ms ingestion, < 5s end-to-end), and data retention policies (7 days Postgres, 24h Redpanda). Intentionally relaxed for dev.

### [9. Observability](design-spec/09-observability.md)
Logging (CloudWatch, structured JSON), metrics (CloudWatch basic), distributed tracing (OpenTelemetry instrumented, collection deferred), and dashboards.

### [10. Disaster Recovery (Dev)](design-spec/10-disaster-recovery.md)
No formal backup strategy for dev. Recovery via Terraform redeploy + seed scripts. No strict RTO/RPO requirements. Production DR decisions deferred.

### [11. Message Format](design-spec/11-message-format.md)
Currently JSON across all stores. Migration to binary (Protobuf or MessagePack) deferred to production phase.

### [12. Environment Variables](design-spec/12-environment-variables.md)
Naming convention (`CJ_[SERVICE]_[VARIABLE]`), all configuration variables with defaults, per-environment values, and complete reference table.

### [13. Time Handling](design-spec/13-time-handling.md)
Dual timestamp strategy (event_time vs ingested_at), clock abstraction package (RealClock, FixedClock, ReplayClock), and usage examples.

### [14. API Reference](design-spec/14-api-reference.md)
OpenAPI 3.0 specs location and viewing instructions. Ingestion (POST /api/v1/events) and Query (GET /api/v1/projections/*) services.

### [15. Testing](design-spec/15-testing.md)
Four-level test strategy (unit, integration, component, e2e). Includes test infrastructure patterns: channel-based mocks, sentinel event pattern for negative assertions, and e2e test runner usage.

---

## Document History

| Date | Change |
|------|--------|
| 2026-02-13 | Reorganize into index + section files (Task 017) |
| 2026-02-12 | Add Service Health & Startup Reliability section (2.9) |
| 2026-02-11 | Add Docker Compose Layering section (2.8) |
| 2026-02-10 | Add Component Tests section (15.3), renumber E2E to 15.4 |
| 2026-02-07 | Add Time Handling section (13) |
| 2026-02-07 | Add Unit/Integration Tests section (15.2) |
| 2026-02-05 | Add Environment Variables section (12) |
| 2026-01-29 | Initial creation from ADR refactoring |
