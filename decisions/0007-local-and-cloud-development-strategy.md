# ADR 0007: Local and Cloud Development Strategy

* **Status:** Accepted
* **Date:** 2026-01-29
* **Architect:** David

## Context

The platform needs development environments for both local iteration and cloud testing. The architecture must balance rapid development feedback with realistic testing of the full distributed system.

## Decision

### Local Development: Hybrid Approach

**Architecture:**
- `docker-compose.yml` in `platform-services/` runs infrastructure only: Postgres, Redpanda, EMQX, Traefik
- Go binary runs natively on the host (compiled and executed directly)
- Python AI Inference Service runs natively on the host (e.g., `uvicorn` / `python main.py`)
- Application processes connect to containerized infrastructure via `localhost`

**Rationale:**
- Native execution eliminates container rebuild cycles — compile and restart immediately
- Sub-second feedback loop for Go (`go run` / `go build`) and Python (no build step)
- Infrastructure containers are stable and rarely change, so container overhead is justified for them
- Matches how most developers already work (editor + terminal + containers for deps)

**Trade-offs:**
- Local environment differs from ECS (native processes vs. all-container) — container-specific bugs may only surface in AWS dev
- Requires Go toolchain and Python virtualenv installed on host
- No Terraform or IAM simulation locally — AWS-specific behavior tested in dev environment only

**Deferred Decisions:**
- Hot-reload tooling for Go (e.g., `air`, `gow`) vs. manual restart
- Python virtualenv management (venv, poetry, etc.)
- AI Inference Service port assignment for local development

### AWS Dev Environment: Networked Monolith with Sidecar Pattern

**Architecture:**
- Single ECS Fargate task containing all components
- Single Go binary running multiple HTTP servers on different ports (8080, 8081, 8082)
- Each port represents a future microservice (Ingestion, Query, Actions)
- Traefik sidecar provides single entry point with path-based routing
- EMQX sidecar for MQTT
- No load balancer — direct task IP access

**ECS Task Composition:**

| Container | Purpose | Ports | Volume Mounts |
|-----------|---------|-------|---------------|
| **traefik** | API Gateway / Router | 80 (HTTP entry), 8180 (dashboard) | Config volume |
| **app** | Go Monolith | 8080 (ingestion), 8081 (query), 8082 (actions) | None |
| **mqtt-broker** | EMQX MQTT Broker | 1883 (MQTT), 18083 (dashboard) | EFS/EBS for persistence |
| **redpanda** | Message Bus | 9092 (Kafka API), 9644 (admin) | EFS/EBS for persistence |
| **postgres** | Event Store + TSDB | 5432 (internal only) | EFS/EBS for persistence |
| **ai-inference** | AI Inference Service (Python/FastAPI) | 8090 (HTTP, internal only) | None |

**Rationale:**
- Enforces service boundaries from day one
- Routing configuration remains nearly identical when splitting to microservices
- Minimal migration effort — extract servers to containers, update gateway targets
- Realistic interface contracts despite monolithic deployment

**Trade-offs:**
- Slightly more complex than single-port monolith
- Sidecar overhead
- Acceptable for learning proper architecture patterns

### Testing Strategy

The distributed architecture (6 containers, async flows, eventual consistency) requires a deliberate testing approach:

**Component Testing:**
- Real inbound client libraries (published by each service) exercise the service's public API
- Real database containers may run for intermediate/internal data storage within the service
- Outbound dependencies use abstracted interfaces (Repository pattern, Outbox interface)
- Tests inject mock implementations of outbound interfaces to control and verify what crosses service boundaries
- No direct mocking of database or messaging layer APIs

**End-to-End Testing:**
- Full docker-compose stack with all infrastructure containers
- Application code compiled and run natively
- Validates complete flows across service boundaries

**Contract Integrity:**
- Shared schema/type definitions across services prevent interface drift
- Component tests validate public API contracts via real client libraries
- End-to-end tests catch integration issues as a final gate

**Deferred — Integration Testing:**
- Integration tests verify specific component pairs with real infrastructure (e.g., service + real Postgres, service + real Redpanda) without the full E2E stack
- Faster feedback than E2E, catches infrastructure-specific bugs (SQL, serialization, consumer config) earlier
- Integration test infrastructure can also serve as a foundation for load testing
- Current strategy (component + E2E) is sufficient initially; add integration layer if E2E tests frequently catch issues that should have been caught earlier

## Consequences

### Benefits
- Fast local development cycle (native execution)
- Realistic cloud testing (full ECS task)
- Clear path from dev to microservices extraction
- Consistent infrastructure across local and cloud (same containers)

### Trade-offs
- Two different execution modes (local native vs. cloud containerized)
- Some bugs only surface in one environment
- Requires both local toolchains and Docker installed

### Deferred Decisions
- Static vs. dynamic mock implementation for component tests
- Hot-reload tooling selection
- Per-container resource limits based on profiling

## Related ADRs
- ADR-0001: Event-Driven CQRS Architecture
- ADR-0005: Infrastructure Technology Choices
- ADR-0008: CI/CD Pipeline Strategy
