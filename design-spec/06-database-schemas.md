# 6. Database Schemas

## 6.1 Outbox Table

| Column | Type | Purpose |
|--------|------|---------|
| outbox_id | UUID | Unique identifier |
| created_at | TIMESTAMPTZ | When the event was accepted |
| event_payload | JSONB | The full event envelope (same format as event store) |
| retry_count | INTEGER | Number of processing attempts (for monitoring/alerting) |

## 6.2 Event Store

| Column | Type | Purpose |
|--------|------|---------|
| event_id | UUID | Unique identifier per event |
| event_type | STRING | Discriminator (e.g., `sensor.reading`, `user.action`) |
| aggregate_id | STRING | Groups related events (e.g., device ID, session ID) |
| timestamp | TIMESTAMPTZ | When the event occurred |
| payload | JSONB | Event-specific data |
| metadata | JSONB | Trace IDs, source info, schema version |

## 6.3 Dead Letter Queue (DLQ)

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

**Note:** The database schema for the DLQ table has been implemented (see `platform-services/internal/services/eventhandler/migrations/002_create_dlq.sql`), but the application logic to write failed events to this table is not yet complete. For current status and future work, refer to the backlog task: [`platform-services/tasks/BACKLOG.md`](../../platform-services/tasks/BACKLOG.md#000_dlq-implementationmd---dlq-implementation-status-event-handler-service).


## 6.4 Projections

| Column | Type | Purpose |
|--------|------|---------|
| projection_id | UUID | Unique identifier |
| projection_type | STRING | Type of projection (e.g., `sensor_state`, `user_session`) |
| aggregate_id | STRING | The aggregate this projection represents |
| state | JSONB | Current projection state |
| last_event_id | UUID | Most recent event applied (for idempotency) |
| last_event_timestamp | TIMESTAMPTZ | Timestamp of last event (for ordering) |
| updated_at | TIMESTAMPTZ | When projection was last updated |

## 6.5 Indexes

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
