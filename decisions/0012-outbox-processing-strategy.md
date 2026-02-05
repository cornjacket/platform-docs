# ADR-0012: Outbox Processing Strategy

**Status:** Accepted
**Date:** 2026-02-04

## Context

The platform uses an outbox pattern (ADR-0002) where events are written to an outbox table and asynchronously processed. We need to decide how the Outbox Processor reads and processes these entries.

Key considerations:
- **Current deployment:** Single-instance monolith (dev environment)
- **Future deployment:** Potentially multiple instances or microservices
- **Dev throughput target:** ~10 events/second (per design spec)
- **Reliability:** Must handle NOTIFY/LISTEN failures gracefully

## Decision

### Phase 1: Dispatcher + Worker Pool (Option B)

Implement a dispatcher pattern with configurable worker pool:

```
┌─────────────────────────────────────────────────────┐
│                  Outbox Processor                   │
│                                                     │
│  ┌────────────┐         ┌─────────────────────┐    │
│  │ Dispatcher │────────▶│   Work Channel      │    │
│  │            │         └──────────┬──────────┘    │
│  │ - LISTEN   │                    │               │
│  │ - Poll     │         ┌──────────┼──────────┐    │
│  │ - Fetch    │         ▼          ▼          ▼    │
│  └────────────┘    [Worker 1] [Worker 2] [Worker N]│
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Dispatcher responsibilities:**
- Listen for PostgreSQL NOTIFY events
- Maintain watchdog timer (poll if no NOTIFY received)
- Fetch batch of pending entries
- Distribute entries to workers via channel

**Worker responsibilities:**
- Receive entry from channel
- Write to event store
- Publish to Redpanda
- Delete from outbox (or increment retry on failure)

**Configuration:**
- `OUTBOX_WORKER_COUNT` (default: 4)
- `OUTBOX_BATCH_SIZE` (default: 100)
- `OUTBOX_POLL_INTERVAL` (default: 5s, watchdog timer)

### Known Limitation

This approach does **not scale horizontally** across multiple instances. If two instances run simultaneously, they will both fetch the same entries, causing duplicate processing.

## Future Scaling Paths

When horizontal scaling is needed, two options:

### Option C: Competing Consumers with Row Locking

```sql
SELECT * FROM outbox
WHERE retry_count < max_retries
ORDER BY created_at
LIMIT $1
FOR UPDATE SKIP LOCKED
```

Multiple processor instances can run independently. Each claims rows atomically via `FOR UPDATE SKIP LOCKED`. Processed rows are deleted, so no duplicates.

**Pros:** Stays with PostgreSQL, minimal infrastructure change
**Cons:** Database becomes bottleneck at high scale

### Option D: Replace Outbox with SQS

Replace the PostgreSQL outbox table with AWS SQS:

```
Ingestion → SQS Queue → Processor(s)
```

SQS provides:
- Built-in competing consumer support
- Visibility timeout (automatic retry)
- Dead letter queue
- Horizontal scaling without database locks

**Pros:** Battle-tested queue semantics, scales independently
**Cons:** AWS dependency, eventual consistency, infrastructure change

## Migration Path

1. **Phase 1 (now):** Dispatcher + Worker Pool, single instance
2. **Phase 2 (if needed):** Add `FOR UPDATE SKIP LOCKED` for multi-instance
3. **Phase 3 (if needed):** Evaluate SQS migration based on scale requirements

The current design isolates outbox reading behind the `OutboxReader` interface, making future changes possible without touching processor logic.

## Consequences

### Positive
- Simple implementation for current scale
- Configurable worker count for tuning
- Watchdog timer ensures reliability
- Clear upgrade path documented

### Negative
- Single-instance limitation in Phase 1
- Will require code changes for horizontal scaling

### Neutral
- Interface abstraction supports future changes
