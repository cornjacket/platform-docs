# Cornjacket Platform Design Specification

**Last Updated:** 2026-02-06
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
| `INGESTION_DATABASE_URL` | Ingestion (incl. Worker) | outbox, event_store |
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

### 3.1 Service-Level View

Three services handle the event flow:

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  Ingestion  │────────▶│ EventHandler │────────▶│    Query    │
│   Service   │  events │   Service    │  state  │   Service   │
└─────────────┘         └──────────────┘         └─────────────┘
       ▲                                                │
       │                                                ▼
    HTTP POST                                       HTTP GET
   /api/v1/events                              /api/v1/projections
```

| Service | Responsibility | Port |
|---------|----------------|------|
| **Ingestion** | Accept events, validate, ensure delivery | 8080 |
| **EventHandler** | Process events, update projections | (background) |
| **Query** | Read projection state | 8081 |

### 3.2 Implementation Details

The infrastructure details are hidden within each service:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INGESTION SERVICE                               │
│                                                                              │
│   HTTP ──▶ Validation ──▶ Outbox ──▶ Worker ──┬──▶ Event Store (audit)     │
│   (MQTT)                   Table              │                              │
│                                               └──▶ EventHandler Client       │
│                                                    (Redpanda publish)        │
└──────────────────────────────────────────────────────────────────────────────┘
                                                           │
┌──────────────────────────────────────────────────────────┼───────────────────┐
│                           EVENTHANDLER SERVICE           ▼                   │
│                                                                              │
│   Redpanda Consumer ──▶ Handler Registry ──▶ Projections Store              │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                                           │
┌──────────────────────────────────────────────────────────┼───────────────────┐
│                              QUERY SERVICE               ▼                   │
│                                                                              │
│   HTTP ──▶ Validation ──▶ Projections Store ──▶ Response                    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Write Path

1. **Entry:** HTTP request (or MQTT in Phase 2) arrives at Ingestion Service
2. **Validate:** Ingestion Service validates the event envelope
3. **Persist:** Event written to `outbox` table (durable, transactional)
4. **Process:** Ingestion Worker picks up entry (NOTIFY/LISTEN + watchdog)
5. **Fan-out:**
   - Write to `event_store` table (append-only audit log)
   - Submit to EventHandler via client (publishes to Redpanda)
6. **Complete:** Delete from `outbox` table

### 3.4 Read Path

1. **Consume:** EventHandler subscribes to Redpanda topics
2. **Dispatch:** Route event to handler based on event_type
3. **Project:** Update projection via shared projections store
4. **Commit:** Commit consumer offset (at-least-once delivery)

### 3.5 Query Path

1. **Request:** Query Service receives HTTP request
2. **Read:** Fetch from `projections` table (pre-computed state)
3. **Return:** Return projection data to client

---

## 4. Event Types

Events flow through the system via the Ingestion Worker → Redpanda → Event Handler pipeline. The `event_type` field determines topic routing and projection handling.

### 4.1 Topic Routing

The Ingestion Worker routes events to topics based on `event_type` prefix:

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

## 12. Environment Variables

### 12.1 Naming Convention

All environment variables follow the pattern:

```
CJ_[SERVICE]_[VARIABLE_NAME]
```

| Component | Description | Examples |
|-----------|-------------|----------|
| `CJ` | Project prefix (Cornjacket) | — |
| `SERVICE` | Service or component name | `INGESTION`, `EVENTHANDLER`, `OUTBOX`, `REDPANDA` |
| `VARIABLE_NAME` | The configuration parameter | `PORT`, `DATABASE_URL`, `WORKER_COUNT` |

**Conventions:**
- All uppercase with underscores
- Project prefix ensures no collision with system or third-party variables
- Service name groups related configuration
- Defaults are set for local development (minimal config needed to run locally)

### 12.2 Service Ports

| Variable | Default | Local | Dev | Staging | Prod |
|----------|---------|-------|-----|---------|------|
| `CJ_INGESTION_PORT` | 8080 | 8080 | 8080 | 8080 | 8080 |
| `CJ_QUERY_PORT` | 8081 | 8081 | 8081 | 8081 | 8081 |
| `CJ_ACTIONS_PORT` | 8083 | 8083 | 8083 | 8083 | 8083 |

**Note:** Port 8082 is reserved for Redpanda Pandaproxy in local development.

### 12.3 Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `CJ_LOG_LEVEL` | `info` | Log verbosity (debug, info, warn, error) |
| `CJ_LOG_FORMAT` | `json` | Output format (json, text) |

**Per-environment values:**

| Environment | Level | Format | Notes |
|-------------|-------|--------|-------|
| Local | `info` or `debug` | `text` | Text format for readability |
| Dev | `info` | `json` | JSON for CloudWatch |
| Staging | `info` | `json` | JSON for CloudWatch |
| Prod | `info` | `json` | JSON for CloudWatch |

### 12.4 Database URLs

| Variable | Default | Service |
|----------|---------|---------|
| `CJ_INGESTION_DATABASE_URL` | `postgres://cornjacket:cornjacket@localhost:5432/cornjacket?sslmode=disable` | Ingestion + Ingestion Worker |
| `CJ_EVENTHANDLER_DATABASE_URL` | `postgres://cornjacket:cornjacket@localhost:5432/cornjacket?sslmode=disable` | Event Handler |
| `CJ_QUERY_DATABASE_URL` | `postgres://cornjacket:cornjacket@localhost:5432/cornjacket?sslmode=disable` | Query Service |
| `CJ_TSDB_DATABASE_URL` | `postgres://cornjacket:cornjacket@localhost:5432/cornjacket?sslmode=disable` | TSDB Writer |
| `CJ_ACTIONS_DATABASE_URL` | `postgres://cornjacket:cornjacket@localhost:5432/cornjacket?sslmode=disable` | Action Orchestrator |

**Per-environment values:**

| Environment | Pattern |
|-------------|---------|
| Local | All services share one local database |
| Dev | All services share one RDS instance (cost optimization) |
| Staging | Separate databases per service (mirrors prod) |
| Prod | Separate databases per service (ADR-0010) |

### 12.5 Message Bus (Redpanda)

| Variable | Default | Local | Dev | Staging | Prod |
|----------|---------|-------|-----|---------|------|
| `CJ_REDPANDA_BROKERS` | `localhost:9092` | `localhost:9092` | TBD | TBD | TBD |

### 12.6 Ingestion Worker

| Variable | Default | Description |
|----------|---------|-------------|
| `CJ_OUTBOX_WORKER_COUNT` | `4` | Number of worker goroutines |
| `CJ_OUTBOX_BATCH_SIZE` | `100` | Max entries fetched per batch |
| `CJ_OUTBOX_MAX_RETRIES` | `5` | Max retry attempts before leaving in outbox |
| `CJ_OUTBOX_POLL_INTERVAL` | `5s` | Watchdog timer interval |

**Per-environment tuning:**

| Environment | Workers | Batch Size | Notes |
|-------------|---------|------------|-------|
| Local | 4 | 100 | Sufficient for testing |
| Dev | 4 | 100 | Same as local |
| Staging | 4 | 100 | Tune based on load testing |
| Prod | TBD | TBD | Tune based on throughput requirements |

### 12.7 Event Handler

| Variable | Default | Description |
|----------|---------|-------------|
| `CJ_EVENTHANDLER_CONSUMER_GROUP` | `event-handler` | Kafka consumer group ID |
| `CJ_EVENTHANDLER_TOPICS` | `sensor-events,user-actions,system-events` | Comma-separated topic list |
| `CJ_EVENTHANDLER_POLL_TIMEOUT` | `1s` | Poll timeout duration |

### 12.8 Feature Flags

| Variable | Default | Description |
|----------|---------|-------------|
| `CJ_FEATURE_TSDB` | `false` | Enable TSDB writer service |

### 12.9 Complete Reference

| Variable | Default | Service | Description |
|----------|---------|---------|-------------|
| `CJ_LOG_LEVEL` | `info` | All | Log verbosity (debug, info, warn, error) |
| `CJ_LOG_FORMAT` | `json` | All | Output format (json, text) |
| `CJ_INGESTION_PORT` | `8080` | Ingestion | HTTP server port |
| `CJ_QUERY_PORT` | `8081` | Query | HTTP server port |
| `CJ_ACTIONS_PORT` | `8083` | Actions | HTTP server port |
| `CJ_INGESTION_DATABASE_URL` | (see 12.3) | Ingestion | PostgreSQL connection string |
| `CJ_EVENTHANDLER_DATABASE_URL` | (see 12.3) | Event Handler | PostgreSQL connection string |
| `CJ_QUERY_DATABASE_URL` | (see 12.3) | Query | PostgreSQL connection string |
| `CJ_TSDB_DATABASE_URL` | (see 12.3) | TSDB | PostgreSQL connection string |
| `CJ_ACTIONS_DATABASE_URL` | (see 12.3) | Actions | PostgreSQL connection string |
| `CJ_REDPANDA_BROKERS` | `localhost:9092` | All | Kafka broker addresses |
| `CJ_OUTBOX_WORKER_COUNT` | `4` | Outbox | Worker goroutine count |
| `CJ_OUTBOX_BATCH_SIZE` | `100` | Outbox | Entries per fetch |
| `CJ_OUTBOX_MAX_RETRIES` | `5` | Outbox | Max retry attempts |
| `CJ_OUTBOX_POLL_INTERVAL` | `5s` | Outbox | Watchdog interval |
| `CJ_EVENTHANDLER_CONSUMER_GROUP` | `event-handler` | Event Handler | Consumer group ID |
| `CJ_EVENTHANDLER_TOPICS` | `sensor-events,user-actions,system-events` | Event Handler | Topics to consume |
| `CJ_EVENTHANDLER_POLL_TIMEOUT` | `1s` | Event Handler | Poll timeout |
| `CJ_FEATURE_TSDB` | `false` | TSDB | Enable TSDB writer |

---

## 13. Time Handling

The platform uses a `clock` package for time abstraction, enabling testability and replay.

### 13.1 Dual Timestamps

Events carry two timestamps with distinct purposes:

| Field | Set By | Purpose |
|-------|--------|---------|
| `event_time` | Caller | When the event occurred (business time) |
| `ingested_at` | Platform | When the platform received it (audit time) |

**API behavior:** The `event_time` field is optional. If omitted, defaults to current time.

### 13.2 Clock Implementations

| Clock | Usage | Behavior |
|-------|-------|----------|
| `RealClock` | Production | Returns `time.Now().UTC()` |
| `FixedClock` | Unit tests | Returns a predetermined time |
| `ReplayClock` | Event replay | Advances with historical events |

### 13.3 Usage

```go
// Production (default) — uses real time
timestamp := clock.Now()

// Unit tests — inject fixed time
clock.Set(clock.FixedClock{Time: fixedTime})
t.Cleanup(clock.Reset)

// Replay — advance per event
replayClock := &clock.ReplayClock{}
clock.Set(replayClock)
replayClock.Advance(event.IngestedAt)
```

See [ADR-0015](decisions/0015-time-handling-strategy.md) for rationale.

---

## 14. API Reference

API endpoints are defined using OpenAPI 3.0 specifications in `platform-services/api/openapi/`.

| Service | Spec File | Port | Description |
|---------|-----------|------|-------------|
| Ingestion | `ingestion.yaml` | 8080 | Event ingestion (POST /api/v1/events) |
| Query | `query.yaml` | 8081 | Projection queries (GET /api/v1/projections/*) |

**Viewing the specs:**

```bash
# Install a viewer (optional)
npm install -g @redocly/cli

# Preview Ingestion API docs
redocly preview-docs platform-services/api/openapi/ingestion.yaml

# Preview Query API docs
redocly preview-docs platform-services/api/openapi/query.yaml
```

The OpenAPI specs are the source of truth for API contracts. See individual spec files for:
- Endpoint paths and methods
- Request/response schemas
- Example payloads
- Error responses

---

## 15. Testing

### 15.1 Test Strategy

| Test Type | Location | Purpose | When to Run |
|-----------|----------|---------|-------------|
| Unit tests | `*_test.go` files | Test individual functions/methods in isolation | `go test ./...` |
| Integration tests | `*_test.go` files | Test components with real dependencies (Postgres, Redpanda) | `go test -tags=integration ./...` |
| E2E tests | `e2e/` directory | Test complete flows through the system | Before releases, after changes |

### 15.2 Unit/Integration Tests

Unit tests verify individual functions without external dependencies. Integration tests verify components with real infrastructure (requires `docker compose up`).

**Testable Packages (no mocking required):**

| Package | What to Test | Test Type |
|---------|--------------|-----------|
| `shared/config` | `Load()` with various env vars | Unit |
| `shared/domain/events` | `NewEnvelope()`, `ParsePayload()` | Unit |
| `client/eventhandler` | `SubmitEvent()` topic routing logic | Unit (mock `EventPublisher`) |

**Testable Packages (integration, requires infrastructure):**

| Package | What to Test | Dependencies |
|---------|--------------|--------------|
| `shared/projections` | `WriteProjection()`, `GetProjection()`, `ListProjections()` | Postgres |
| `shared/infra/postgres` | `OutboxRepo`, `EventStoreRepo`, connection pool | Postgres |
| `shared/infra/redpanda` | `Publish()`, partition key routing | Redpanda |

**Service Component Tests (mock interfaces):**

| Service | Mock Interface | Test Scenarios |
|---------|----------------|----------------|
| Ingestion Worker | `EventSubmitter` | Outbox processing calls `SubmitEvent()` correctly |
| EventHandler | `projections.Store` | Event handlers call `WriteProjection()` with correct state |
| Query Service | `ProjectionReader` | `GetProjection()`/`ListProjections()` return expected data |

**Running tests:**
```bash
# Unit tests only (no infrastructure needed)
go test ./internal/shared/domain/... ./internal/shared/config/...

# Integration tests (requires docker compose up)
go test -tags=integration ./internal/shared/infra/... ./internal/shared/projections/...

# All tests
go test ./...
```

### 15.3 End-to-End Tests

E2E tests verify the complete event flow:
```
HTTP POST → Ingestion → Outbox → Event Store + Redpanda → Event Handler → Projections → Query API
```

**Directory structure:**
```
platform-services/e2e/
├── main.go           # Test runner entry point
├── run.sh            # Shell script with environment setup
├── README.md         # Detailed usage documentation
├── runner/           # Test registration and execution framework
├── client/           # HTTP client helpers (reusable)
└── tests/            # Test implementations
```

**Usage:**
```bash
# Prerequisites: platform must be running
docker compose up -d
make migrate-all
go run ./cmd/platform &

# Run all tests sequentially
./e2e/run.sh

# Run specific test
./e2e/run.sh -test=ingest-event

# Run against different environment
./e2e/run.sh -env=dev

# List available tests
./e2e/run.sh -list
```

**Available tests:**

| Test | Description |
|------|-------------|
| `ingest-event` | Ingest event, verify projection created |
| `query-projection` | Query projections, test pagination |
| `full-flow` | Ingest, update, verify state changes |

**Adding new tests:** See `platform-services/e2e/README.md` for the self-registration pattern.

---

## 16. Document History

| Date | Change |
|------|--------|
| 2026-02-07 | Add Time Handling section (13) |
| 2026-02-07 | Add Unit/Integration Tests section (15.2) |
| 2026-02-05 | Add Environment Variables section (12) |
| 2026-01-29 | Initial creation from ADR refactoring |
