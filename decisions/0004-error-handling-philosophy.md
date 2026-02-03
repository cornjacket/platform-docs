# ADR 0004: Error Handling Philosophy

* **Status:** Accepted
* **Date:** 2026-01-29
* **Architect:** David

## Context

The distributed, event-driven architecture (ADR-0001) has multiple failure points across the write path and consumer path. A consistent error handling philosophy is needed to ensure reliability without over-engineering.

## Decision

### Delivery Guarantee: At-Least-Once

Events may be delivered more than once; consumers must handle duplicates. Kafka/Redpanda offset is only committed after successful processing.

### Idempotency

- **5-minute deduplication window** for consumers
- Dev (single instance): In-memory cache sufficient
- Production (multi-instance): Shared state required (Redis or Postgres)
- Defense in depth: Operations should be idempotent where possible (upsert vs. insert, PUT vs. POST)

### Retry Strategy: Hybrid with Exponential Backoff

All consumers use the same retry pattern:
- 1st retry: Immediate
- 2nd retry: 1 second delay
- 3rd retry: 2 second delay
- Give up after 3 retries (~3 seconds total)

### Differentiated Failure Handling

Different failure types require different responses:

| Failure Type | Cause | Strategy | DLQ? |
|--------------|-------|----------|------|
| Infrastructure outage | Postgres down | Block — don't commit offset, retry until recovered | No |
| Poison message | Bad event data, model error | Send to DLQ, commit offset, continue | Yes |
| External dependency down | Webhook endpoint unreachable | Circuit breaker, log failure, short-circuit | No |

**Rationale:**
- **Infrastructure outage:** Blocking is correct — processing more events will also fail. Wait for recovery.
- **Poison message:** Isolate the bad event in DLQ, continue processing. Can replay or debug later.
- **External dependency down:** Not our fault — circuit breaker prevents wasting resources on a dead endpoint.

### Dead Letter Queue (DLQ)

- **Per-consumer DLQ in Postgres** (not Redpanda topic)
- Durable beyond Redpanda's 24-hour retention
- Queryable (find failures by consumer, time range, error type)
- Consistent with single-Postgres-stack decision (ADR-0003)

### Circuit Breaker for Webhooks

- **Blacklist pattern with expiry** for failing webhook endpoints
- Track consecutive failures per endpoint
- After threshold (e.g., 5 failures), add endpoint to blacklist
- Blacklisted endpoints fail immediately (short-circuit) — no timeout wait
- Blacklist entries expire after cooldown period (e.g., 5 minutes)
- **Storage:** Redis or similar (supports TTL-based expiry)

**Rationale:**
- Don't waste resources calling dead endpoints
- Faster failure response (no 30-second timeout)
- Automatic recovery when endpoint comes back
- Endpoint downtime is consumer's responsibility (SLA violation)

### Error Visibility

- Errors logged with full context (event ID, consumer, error message, stack trace)
- Dashboard and alerting deferred to later phase

## Data Flow and Failure Points

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ WRITE PATH                                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Client                                                                     │
│    │                                                                        │
│    ▼                                                                        │
│  Ingestion Service                                                          │
│    │                                                                        │
│    ▼                                                                        │
│  Outbox Table (Postgres)  ◄─── Failure A: Write fails, return error to client
│    │                                                                        │
│    ▼                                                                        │
│  Background Processor (NOTIFY/LISTEN)                                       │
│    │                                                                        │
│    ├──► Event Store (Postgres)  ◄─── Failure B: Retry, outbox entry remains │
│    │                                                                        │
│    └──► Redpanda publish  ◄─── Failure C: Retry, outbox entry remains       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ CONSUMER PATH                                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Redpanda                                                                   │
│    │                                                                        │
│    ├──► Event Handler  ◄─── Failure D: Projection update fails              │
│    │                                                                        │
│    ├──► AI Inference Service  ◄─── Failure E: Model processing fails        │
│    │                                                                        │
│    └──► Action Orchestrator  ◄─── Failure F: Webhook delivery fails         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Consequences

### Benefits
- Clear, consistent error handling across all components
- Automatic retry with bounded attempts
- DLQ enables debugging and replay without blocking processing
- Circuit breaker protects against cascading failures from external dependencies

### Trade-offs
- DLQ adds operational overhead (monitoring, replay procedures)
- Circuit breaker requires Redis or similar for shared state in multi-instance deployments
- At-least-once delivery requires idempotent consumers

### Deferred Decisions
- Specific shared state implementation for production deduplication
- DLQ replay mechanisms (manual, automated, on-demand API)
- Circuit breaker threshold and cooldown values
- Error dashboard and alerting

## Related ADRs
- ADR-0001: Event-Driven CQRS Architecture
- ADR-0002: Outbox-First Write Pattern
- ADR-0003: Unified PostgreSQL Data Stack
