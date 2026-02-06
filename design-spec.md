# Cornjacket Platform Design Specification

**Last Updated:** 2026-02-04
**Status:** Living Document

This document contains operational details, configuration parameters, and implementation specifics that may change over time. For architectural decisions and rationale, see the ADRs in `decisions/`.

## 1. Related ADRs

| ADR | Topic |
|-----|-------|
| [0001](decisions/0001-event-driven-cqrs-architecture.md) | Event-Driven CQRS Architecture |
| [0002](decisions/0002-outbox-first-write-pattern.md) | Outbox-First Write Pattern |
| [0003](decisions/0003-unified-postgresql-data-stack.md) | Unified PostgreSQL Data Stack |
| [0004](decisions/0004-error-handling-philosophy.md) | Error Handling Philosophy |
| [0005](decisions/0005-infrastructure-technology-choices.md) | Infrastructure Technology Choices |
| [0006](decisions/0006-security-model.md) | Security Model |
| [0007](decisions/0007-local-and-cloud-development-strategy.md) | Local and Cloud Development Strategy |
| [0008](decisions/0008-cicd-pipeline-strategy.md) | CI/CD Pipeline Strategy |
| [0009](decisions/0009-ai-inference-stream-processor.md) | AI Inference Stream Processor |
| [0010](decisions/0010-database-per-service-pattern.md) | Database-Per-Service Pattern |
| [0011](decisions/0011-coordinated-tagging-across-repos.md) | Coordinated Tagging Across Repos |
| [0012](decisions/0012-outbox-processing-strategy.md) | Outbox Processing Strategy |
| [0013](decisions/0013-uuid-v7-standardization.md) | UUID v7 Standardization |
| [0014](decisions/0014-event-handler-consumer-strategy.md) | Event Handler Consumer Strategy |

---

## 2. Dev Environment Task Architecture

### 2.1 ECS Task Composition

| Container | Purpose | Ports | Volume Mounts |
|-----------|---------|-------|---------------|
| **traefik** | API Gateway / Router | 80 (HTTP entry), 8180 (dashboard) | Config volume |
| **app** | Go Monolith | 8080 (ingestion), 8081 (query), 8082 (actions) | None |
| **mqtt-broker** | EMQX MQTT Broker | 1883 (MQTT), 18083 (dashboard) | EFS/EBS for persistence |
| **redpanda** | Message Bus | 9092 (Kafka API), 9644 (admin) | EFS/EBS for persistence |
| **postgres** | Event Store + TSDB | 5432 (internal only) | EFS/EBS for persistence |
| **ai-inference** | AI Inference Service (Python/FastAPI) | 8090 (HTTP, internal only) | None |

### 2.2 Communication Patterns

- External → Traefik (port 80) → App ports (8080/8081/8082)
- External → MQTT (port 1883) → EMQX
- IoT devices → EMQX → App (subscribes to MQTT topics)
- App → Postgres (localhost:5432) - event store reads/writes
- App → Redpanda (localhost:9092) - publish events
- App → MQTT (localhost:1883) - subscribe to device messages

### 2.3 Persistent Storage

| Container | Storage Required | Purpose |
|-----------|-----------------|---------|
| postgres | Yes (EFS/EBS) | Event store + time-series data |
| redpanda | Yes (EFS/EBS) | Message buffer |
| mqtt-broker | Yes (EFS/EBS) | Sessions/config |
| app | No | Stateless (uses Postgres for data) |
| traefik | No | Config from volume |
| ai-inference | No | Stateless |

**Decision deferred:** EFS vs. EBS for container data persistence

### 2.4 Resource Allocation (Dev)

| Setting | Value | Notes |
|---------|-------|-------|
| vCPU | 1 | Total task allocation |
| Memory | 2GB | Total task allocation |
| Rationale | Cost optimization | Acceptable slow performance for dev |

**Monitoring:** Watch for memory pressure/thrashing via CloudWatch, scale up if needed

**Decision deferred:** Per-container resource limits based on profiling

### 2.5 Access Patterns

| Service | URL Pattern |
|---------|-------------|
| HTTP API | `http://<task-ip>/api/v1/*` |
| MQTT | `mqtt://<task-ip>:1883` |
| Traefik Dashboard | `http://<task-ip>:8180` |
| EMQX Dashboard | `http://<task-ip>:18083` |
| Redpanda Admin | `http://<task-ip>:9644` |

### 2.6 Cost Estimate (Dev)

| Component | Estimated Cost |
|-----------|---------------|
| ECS Fargate (1 vCPU, 2GB, 24/7) | ~$30-40/month |
| EFS storage | ~$5-10/month |
| Logs/metrics | ~$5/month |
| **Total** | **~$40-55/month** |

### 2.7 Service Database Configuration

Each service receives its own database URL as configuration (see ADR-0010).

| Environment Variable | Service | Tables Owned |
|---------------------|---------|--------------|
| `INGESTION_DATABASE_URL` | Ingestion + Outbox Processor | outbox, event_store |
| `EVENTHANDLER_DATABASE_URL` | Event Handler | projections, dlq |
| `QUERY_DATABASE_URL` | Query Service | (none - reads from Event Handler) |
| `TSDB_DATABASE_URL` | TSDB Writer | timeseries tables, dlq |
| `ACTIONS_DATABASE_URL` | Action Orchestrator | action_config, dlq |

**Default (Dev):** All variables point to the same database:
```
postgres://cornjacket:cornjacket@localhost:5432/cornjacket?sslmode=disable
```

**Migration Location:** Each service owns its migrations in `internal/services/<service>/migrations/`.

---

## 3. Data Flow

### 3.1 Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              WRITE PATH                                      │
│                                                                              │
│   HTTP ──▶ Ingestion ──▶ Outbox ──▶ Outbox Processor ──┬──▶ Event Store     │
│   (MQTT)     Service      Table                        │                     │
│                                                        └──▶ Redpanda        │
│                                                              │               │
└──────────────────────────────────────────────────────────────┼───────────────┘
                                                               │
┌──────────────────────────────────────────────────────────────┼───────────────┐
│                              READ PATH                       ▼               │
│                                                                              │
│   Query ◀── Projections ◀── Event Handler ◀── Redpanda                      │
│   Service      Table                            (consumer)                   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Write Path

1. **Entry:** HTTP request (or MQTT in Phase 2) arrives at Ingestion Service
2. **Validate:** Ingestion Service validates the event envelope
3. **Persist:** Event written to `outbox` table (durable, transactional)
4. **Process:** Outbox Processor picks up entry (NOTIFY/LISTEN + watchdog)
5. **Fan-out:**
   - Write to `event_store` table (append-only log)
   - Publish to Redpanda topic (based on event_type prefix)
6. **Complete:** Delete from `outbox` table

### 3.3 Read Path

1. **Consume:** Event Handler subscribes to Redpanda topics
2. **Dispatch:** Route event to handler based on event_type
3. **Project:** Update projection in `projections` table
4. **Commit:** Commit consumer offset (at-least-once delivery)

### 3.4 Query Path

1. **Request:** Query Service receives HTTP request
2. **Read:** Fetch from `projections` table (pre-computed state)
3. **Return:** Return projection data to client

---

## 4. Event Types

Events flow through the system via the Outbox Processor → Redpanda → Event Handler pipeline. The `event_type` field determines topic routing and projection handling.

### 4.1 Topic Routing

The Outbox Processor routes events to topics based on `event_type` prefix:

| Prefix | Topic | Description |
|--------|-------|-------------|
| `sensor.*` | sensor-events | IoT sensor data |
| `user.*` | user-actions | User activity |
| `*` (default) | system-events | System/operational events |

### 4.2 Event Catalog

| Event Type | Payload Schema | Projection |
|------------|----------------|------------|
| `sensor.reading` | `{"value": float, "unit": string}` | `sensor_state` |
| `user.login` | `{"user_id": string, "ip": string}` | `user_session` |
| `system.alert` | `{"level": string, "message": string}` | (none) |

### 4.3 Example Events

```json
// sensor.reading — aggregate_id is the device
{"event_type": "sensor.reading", "aggregate_id": "device-001", "payload": {"value": 72.5, "unit": "fahrenheit"}}

// user.login — aggregate_id is the user
{"event_type": "user.login", "aggregate_id": "user-123", "payload": {"user_id": "user-123", "ip": "192.168.1.1"}}

// system.alert — aggregate_id is the source component
{"event_type": "system.alert", "aggregate_id": "cluster-1", "payload": {"level": "warn", "message": "High memory usage"}}
```

### 4.4 Projections

| Projection Type | Purpose | Updated By |
|-----------------|---------|------------|
| `sensor_state` | Latest sensor reading per device | `sensor.reading` |
| `user_session` | Last login info per user | `user.login` |

New event types and projections are added as features require them.

---

## 5. Message Bus Configuration

### 5.1 Topic Design

- **Pattern:** Per-event-type topics
- **Topics:** `sensor-events`, `user-actions`, `system-events`
- **Rationale:** Clean separation, consumers subscribe to needed types, avoids topic explosion

### 5.2 Retention Policy

| Environment | Retention |
|-------------|-----------|
| Dev | 24 hours |
| Staging/Prod | TBD |

### 5.3 Partition Strategy

| Environment | Partitions per Topic |
|-------------|---------------------|
| Dev | 1 |
| Staging/Prod | TBD (based on volume) |

**Rationale (Dev):** Simplest configuration, guaranteed ordering, sufficient for low-traffic dev

---

## 6. Database Schemas

### 6.1 Outbox Table

| Column | Type | Purpose |
|--------|------|---------|
| outbox_id | UUID | Unique identifier |
| created_at | TIMESTAMPTZ | When the event was accepted |
| event_payload | JSONB | The full event envelope (same format as event store) |
| retry_count | INTEGER | Number of processing attempts (for monitoring/alerting) |

### 6.2 Event Store

| Column | Type | Purpose |
|--------|------|---------|
| event_id | UUID | Unique identifier per event |
| event_type | STRING | Discriminator (e.g., `sensor.reading`, `user.action`) |
| aggregate_id | STRING | Groups related events (e.g., device ID, session ID) |
| timestamp | TIMESTAMPTZ | When the event occurred |
| payload | JSONB | Event-specific data |
| metadata | JSONB | Trace IDs, source info, schema version |

### 6.3 Dead Letter Queue (DLQ)

| Column | Type | Purpose |
|--------|------|---------|
| dlq_id | UUID | Unique identifier |
| consumer | STRING | Which consumer failed (event-handler, ai-inference) |
| event_id | UUID | Original event ID |
| event_payload | JSONB | Full event data for replay |
| error_message | TEXT | Why it failed |
| failed_at | TIMESTAMPTZ | When it failed |
| retry_count | INTEGER | How many retries were attempted |
| status | STRING | `pending`, `replayed`, `discarded` |

### 6.4 Projections

| Column | Type | Purpose |
|--------|------|---------|
| projection_id | UUID | Unique identifier |
| projection_type | STRING | Type of projection (e.g., `sensor_state`, `user_session`) |
| aggregate_id | STRING | The aggregate this projection represents |
| state | JSONB | Current projection state |
| last_event_id | UUID | Most recent event applied (for idempotency) |
| last_event_timestamp | TIMESTAMPTZ | Timestamp of last event (for ordering) |
| updated_at | TIMESTAMPTZ | When projection was last updated |

### 6.5 Indexes

| Table | Index | Columns | Purpose |
|-------|-------|---------|---------|
| **outbox** | PRIMARY KEY | `outbox_id` | Unique lookup |
| | `idx_outbox_created_at` | `created_at` | Fetch oldest entries first |
| **event_store** | PRIMARY KEY | `event_id` | Unique lookup, idempotency |
| | `idx_event_store_aggregate` | `aggregate_id` | Query events by aggregate |
| | `idx_event_store_type` | `event_type` | Query events by type |
| | `idx_event_store_timestamp` | `timestamp` | Time-range queries |
| **projections** | PRIMARY KEY | `projection_id` | Unique lookup |
| | UNIQUE | `(projection_type, aggregate_id)` | One projection per type per aggregate, used by Upsert |
| | `idx_projections_type` | `projection_type` | List all projections of a type |
| | `idx_projections_aggregate_id` | `aggregate_id` | Get all projections for an aggregate |
| **dlq** | PRIMARY KEY | `dlq_id` | Unique lookup |
| | `idx_dlq_consumer` | `consumer` | Query by consumer |
| | `idx_dlq_status` | `status` | Query by status (pending, replayed, discarded) |
| | `idx_dlq_failed_at` | `failed_at` | Time-range queries |

**Index Design Rationale:**

- **Primary lookup patterns** are covered by PRIMARY KEY and UNIQUE constraints
- **Secondary patterns** (filtering, sorting) have dedicated indexes
- **Composite indexes** used where queries filter on multiple columns together
- **No over-indexing** — indexes added based on actual query patterns

---

## 7. Action Orchestrator Configuration

### 7.1 Webhook Retry Logic

| Setting | Initial Default | Notes |
|---------|-----------------|-------|
| Max retry attempts | 3-5 | Subject to tuning |
| Backoff delays | 1s, 2s, 4s, 8s, 16s | Exponential backoff |
| After max retries | Log failure and continue | No blocking |

### 7.2 Timeout Handling

| Setting | Initial Default | Notes |
|---------|-----------------|-------|
| Per-webhook timeout | 30 seconds | Subject to tuning |

### 7.3 Rate Limiting

| Setting | Initial Default | Notes |
|---------|-----------------|-------|
| Global rate limit | 10 webhooks/minute | Subject to tuning |
| Implementation | In-memory tracking | Single-instance dev only |

**Decision deferred:**
- Per-endpoint rate limits for production
- Shared state management (Redis) for multi-instance deployments

### 7.4 Deduplication

| Setting | Initial Default | Notes |
|---------|-----------------|-------|
| Deduplication window | 5 minutes | Subject to tuning |
| Key | event type + target identifier | |
| Implementation | In-memory cache | State lost on restart |

**Decision deferred:**
- Sophisticated deduplication logic (similarity matching, alert grouping)
- Persistent deduplication state (Redis) for production

### 7.5 Circuit Breaker for Webhooks

| Setting | Initial Default | Notes |
|---------|-----------------|-------|
| Failure threshold | 5 consecutive failures | Triggers blacklist |
| Cooldown period | 5 minutes | TTL-based expiry |
| Storage | Redis | Supports TTL |

---

## 8. Scale & Performance Requirements (Dev)

### 8.1 Target Throughput

| Metric | Target | Notes |
|--------|--------|-------|
| HTTP API | ~10 requests/second | Dev environment |
| MQTT events | ~10 events/second | Dev environment |

**Note:** These targets are intentionally orders of magnitude below production ambitions to optimize for cost and simplicity during the learning phase.

### 8.2 Latency Requirements

| Metric | Target | Notes |
|--------|--------|-------|
| Ingestion latency | < 500ms | HTTP request to accepted response |
| End-to-end latency | < 5 seconds | Event received to projection updated |
| Query latency | < 1 second | Query response time |

**Rationale:** Relaxed requirements appropriate for dev environment. Focus on correctness over performance.

**Decision deferred:** Production SLAs (p50, p95, p99 latency targets)

### 8.3 Data Retention Policies

| Data Store | Retention | Notes |
|------------|-----------|-------|
| Postgres Event Store | 7 days | |
| Postgres Projections/TSDB | 7 days | |
| Redpanda Message Bus | 24 hours | |

**Rationale:** Cost optimization for dev environment. Sufficient for testing and debugging.

**Decision deferred:**
- Production retention requirements (30/90/365 days or longer)
- Archival strategy for long-term storage
- Compliance/regulatory retention requirements

---

## 9. Observability

### 9.1 Logging

| Aspect | Decision |
|--------|----------|
| Backend | CloudWatch Logs |
| Format | Structured JSON |
| Rationale | AWS-native integration, queryable logs, no additional infrastructure |

**Trade-offs:** CloudWatch query language less powerful than Elasticsearch, but sufficient for dev

### 9.2 Metrics

| Aspect | Decision |
|--------|----------|
| Backend | AWS CloudWatch Metrics |
| Scope | Basic/automatic metrics (CPU, memory, network) |
| Custom metrics | Deferred (CloudWatch SDK available) |

### 9.3 Distributed Tracing

| Aspect | Decision |
|--------|----------|
| Instrumentation | OpenTelemetry |
| Collection | Deferred |
| Backend (future) | Honeycomb |

**Rationale:** Adding instrumentation now is low-cost. Can enable/disable collection without code changes.

### 9.4 Dashboards & Visualization

| Tool | Purpose |
|------|---------|
| Traefik Dashboard | Real-time traffic routing view |
| CloudWatch Console | Ad-hoc log searches and metric viewing |
| Grafana | Deferred |

---

## 10. Disaster Recovery (Dev)

### 10.1 Backup Strategy

**Decision:** No formal backup strategy for dev environment

**Rationale:**
- Dev environment data not business-critical
- Test data can be regenerated as needed
- Infrastructure-as-code (Terraform) enables rapid rebuild

**Data at risk:**
- Postgres: Event store and projections (7-day retention)
- Redpanda: Message buffer (24-hour retention)
- EMQX: Session and configuration data

### 10.2 Recovery Procedures

**Recovery approach:**
1. Redeploy infrastructure using Terraform
2. Deploy latest application containers
3. Regenerate test data using seed scripts

### 10.3 Recovery Objectives

| Objective | Requirement | Notes |
|-----------|-------------|-------|
| RTO | No strict requirement | Several hours acceptable |
| RPO | No strict requirement | Data loss acceptable |

**Decision deferred (Production):**
- Automated snapshots, point-in-time recovery
- Backup retention policies
- Cross-region backup replication
- Automated failover mechanisms
- Blue-green deployment for zero-downtime recovery
- Runbooks for incident response

---

## 11. Message Format

### 11.1 Current Format

| Aspect | Decision |
|--------|----------|
| Format | JSON |
| Scope | Outbox table, event store, Redpanda message bus |
| Serialization | Single path (Ingestion Service serializes once) |

### 11.2 Migration Path

| Phase | Format |
|-------|--------|
| Development | JSON |
| Production | Binary (Protobuf or MessagePack) |

**Decision deferred:** Protobuf vs. MessagePack based on schema stability needs and performance testing

---

## 12. Document History

| Date | Change |
|------|--------|
| 2026-01-29 | Initial creation from ADR refactoring |
