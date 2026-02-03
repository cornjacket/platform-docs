# ADR 0002: Outbox-First Write Pattern

* **Status:** Accepted
* **Date:** 2026-01-29
* **Architect:** David

## Context

In the CQRS architecture (ADR-0001), the Ingestion Service needs to:
1. Persist events to the Event Store (PostgreSQL)
2. Publish events to the Message Bus (Redpanda)

A naive dual-write approach creates a consistency hazard: if the Postgres write succeeds but the Redpanda publish fails (or vice versa), the event store and message bus become out of sync.

## Decision

Implement an **outbox-first pattern** where:
1. Ingestion Service writes only to an **outbox table** (single write, atomic)
2. A **background processor** handles the outbox → event store → Redpanda flow
3. The background processor uses **Postgres NOTIFY/LISTEN** for low-latency notification of new outbox entries

### Write Path

**Step 1 — Ingestion (synchronous, client-facing):**
1. Ingestion Service receives HTTP/MQTT request
2. Validates the incoming event
3. Writes to the **outbox table** (with retry on failure, 2-3 attempts with backoff)
4. Returns success to client once outbox write succeeds — this is the "accepted" acknowledgment

**Step 2 — Processing (asynchronous, background):**
1. Background processor LISTENs for Postgres NOTIFY on outbox inserts (with periodic fallback poll for reliability)
2. Writes event to the **event store** (append-only, immutable)
3. Publishes event to **Redpanda** message bus
4. Deletes the outbox row only after both succeed
5. If either fails, the outbox entry remains and the entire operation retries

### Consistency Guarantees

| Guarantee | Description |
|-----------|-------------|
| **Durability** | An event is durably captured the moment the outbox write succeeds. No accepted event is ever lost. |
| **Atomicity** | The event store write and Redpanda publish are handled together — if either fails, both retry. No partial state. |
| **Eventual consistency** | The event store and message bus are eventually consistent with the outbox. Lag is typically milliseconds. |
| **Immutability** | The event store is append-only. The outbox is transient (events deleted after processing). |
| **Retryability** | Failed processing is automatically retried. The outbox serves as a durable retry queue. |

### Why Not Use the Event Store as the Outbox?

Adding a `published` column to the event store and updating it after Redpanda publish would:
- Violate event store immutability (append-only principle)
- Cause table bloat from UPDATE operations (Postgres MVCC creates dead rows)
- Create index skew issues as the table grows (99.99% of rows would be `published=true`)

A separate outbox table stays small (events are deleted after processing) and keeps the event store clean.

## Rationale

- **Single write for client response:** Client latency is just one DB write (fast)
- **No dual-write hazard:** Event store + Redpanda are handled atomically by background processor
- **Built-in retry queue:** The outbox naturally serves as a durable retry mechanism
- **NOTIFY/LISTEN for low latency:** Postgres push notification avoids polling overhead while fallback poll ensures reliability

## Consequences

### Benefits
- Guaranteed durability — no accepted event is ever lost
- Clean separation: outbox is transient, event store is permanent
- Automatic retry without external job scheduler
- Client gets fast response (single write)

### Trade-offs
- Additional table to manage (outbox)
- Background processor adds operational complexity
- Slight increase in end-to-end latency (async processing)

## Related ADRs
- ADR-0001: Event-Driven CQRS Architecture
- ADR-0003: Unified PostgreSQL Data Stack
- ADR-0004: Error Handling Philosophy
