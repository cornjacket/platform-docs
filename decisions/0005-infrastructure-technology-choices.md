# ADR 0005: Infrastructure Technology Choices

* **Status:** Accepted
* **Date:** 2026-01-29
* **Architect:** David

## Context

The event-driven CQRS architecture (ADR-0001) requires several infrastructure components:
- API Gateway for HTTP traffic
- MQTT Broker for IoT device connections
- Message Bus for event streaming

This ADR documents the technology choices for these infrastructure components.

## Decision

### API Gateway: Traefik

| Aspect | Decision |
|--------|----------|
| **Technology** | Traefik |
| **Deployment** | Sidecar container in ECS task |
| **Responsibilities** | HTTP routing, JWT validation, rate limiting |

**Rationale:**
- Lightweight, container-native
- Easy configuration via labels or static config
- Built-in dashboard for debugging
- ForwardAuth middleware for JWT validation

### MQTT Broker: EMQX

| Aspect | Decision |
|--------|----------|
| **Technology** | EMQX |
| **Deployment** | Sidecar container in ECS task |
| **Responsibilities** | IoT device connections, pub/sub messaging |

**Rationale:**
- Purpose-built MQTT broker (not a general message queue)
- High connection capacity for IoT devices
- Built-in authentication (username/password for dev)
- Dashboard for monitoring connections and topics

### Message Bus: Redpanda

| Aspect | Decision |
|--------|----------|
| **Technology** | Redpanda (Kafka-compatible) |
| **Deployment** | Sidecar container in ECS task |
| **Responsibilities** | Event streaming, consumer fan-out, backpressure |

**Rationale:**
- Kafka ecosystem is industry standard
- Redpanda is simpler than Kafka (no Zookeeper dependency)
- Compatible with standard Kafka client libraries
- Works locally and in AWS
- Single binary, lower resource footprint

### Entry Point Strategy: Parallel Entry

```
HTTP Clients ──► Traefik (port 80) ──► Go Monolith (8080/8081/8082)

IoT Devices ──► EMQX (port 1883) ──► Go Monolith (subscribes to topics)
```

**Rationale:**
- Protocol isolation prevents long-lived MQTT connections from consuming resources needed by short-lived HTTP requests
- Each protocol handled by purpose-built, battle-tested tooling
- Clear separation of concerns

### Build vs. Buy: Hybrid Integration

| Category | Approach |
|----------|----------|
| **Infrastructure** | Off-the-shelf (Traefik, EMQX, Redpanda, PostgreSQL) |
| **Business Logic** | Custom Go services (Ingestion, Query, Actions, Event Handler) |
| **AI/ML** | Custom Python service (FastAPI) |

**Rationale:**
- Focus engineering effort on unique business logic and AI implementation
- Don't reinvent standard networking protocols
- Leverage battle-tested security and protocol compliance from off-the-shelf tools

## Consequences

### Benefits
- Proven, well-documented technologies
- Large community support for each component
- Standard client libraries available in Go and Python
- Each tool is best-in-class for its specific responsibility

### Trade-offs
- Multiple technologies to learn and operate
- Version compatibility considerations across components
- Each tool has its own configuration paradigm

### Deferred Decisions
- Extraction of Redpanda to standalone ECS service for production scaling
- Managed alternatives (Amazon MSK, AWS IoT Core) for production
- Client certificate authentication (mTLS) for MQTT in production

## Related ADRs
- ADR-0001: Event-Driven CQRS Architecture
- ADR-0007: Local and Cloud Development Strategy
