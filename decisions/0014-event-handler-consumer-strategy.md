# ADR 0014: Event Handler Consumer Strategy

* **Status:** Accepted
* **Date:** 2026-02-05
* **Architect:** David

## Context

The Event Handler consumes events from Redpanda topics and updates projections. We need to decide on the consumer architecture:

1. How many consumers?
2. How do they map to topics?
3. How do we scale when throughput increases?

The dev environment targets ~10 events/sec. Production will require higher throughput.

## Decision

**Phase 1: Single consumer subscribing to all topics.**

```
┌─────────────────────────────────────────────────┐
│              Event Handler (Phase 1)            │
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │         Single Consumer                  │   │
│  │  subscribes to:                          │   │
│  │    - sensor-events                       │   │
│  │    - user-actions                        │   │
│  │    - system-events                       │   │
│  └─────────────────────────────────────────┘   │
│                      │                          │
│                      ▼                          │
│  ┌─────────────────────────────────────────┐   │
│  │         Handler Registry                 │   │
│  │  dispatches by event_type prefix         │   │
│  └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

**Future: Topic-specific consumers with partition parallelism.**

```
┌─────────────────────────────────────────────────────────────────┐
│                  Event Handler (Future)                          │
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ sensor-events    │  │ user-actions     │  │ system-events  │ │
│  │ Consumer Group   │  │ Consumer Group   │  │ Consumer Group │ │
│  │                  │  │                  │  │                │ │
│  │ ┌──┐ ┌──┐ ┌──┐  │  │ ┌──┐ ┌──┐       │  │ ┌──┐           │ │
│  │ │C1│ │C2│ │C3│  │  │ │C1│ │C2│       │  │ │C1│           │ │
│  │ └──┘ └──┘ └──┘  │  │ └──┘ └──┘       │  │ └──┘           │ │
│  │  ▲    ▲    ▲    │  │  ▲    ▲         │  │  ▲             │ │
│  │  P0   P1   P2   │  │  P0   P1        │  │  P0            │ │
│  └──────────────────┘  └──────────────────┘  └────────────────┘ │
│           │                    │                    │            │
│           └────────────────────┼────────────────────┘            │
│                                ▼                                 │
│                 ┌─────────────────────────────────┐              │
│                 │   Shared Handler Registry       │              │
│                 │   (same code, multiple callers) │              │
│                 └─────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

## Rationale

### Why Single Consumer for Phase 1

| Factor | Reasoning |
|--------|-----------|
| **Simplicity** | One consumer, one goroutine, easy to debug |
| **Throughput** | ~10 events/sec is trivial for single consumer |
| **Ordering** | Global ordering across all events (not required, but simpler) |
| **No rebalancing** | No partition assignment complexity |

### Why Topic-Specific Consumers for Future

| Factor | Reasoning |
|--------|-----------|
| **Independent scaling** | Scale sensor-events consumers without affecting user-actions |
| **Isolation** | Slow projection updates for one topic don't block others |
| **Partition parallelism** | Multiple consumers per topic, one per partition |
| **Operational clarity** | Consumer lag metrics per topic |

### Shared Handler Code

The projection update logic (Handler Registry) is shared across all consumers. Each consumer:
1. Polls its topic
2. Deserializes to `events.Envelope`
3. Calls the shared Handler Registry
4. Handler dispatches by `event_type` prefix

This means:
- Handler code is written once
- Consumers are topic-specific but use common handlers
- Adding a new event type only requires registering a handler, not a new consumer

## Implementation Notes

### Phase 1 Configuration

```go
topics := []string{"sensor-events", "user-actions", "system-events"}
groupID := "event-handler"
// Single consumer subscribes to all topics
```

### Future Configuration

```go
// Each topic gets its own consumer group
// Partition count determines parallelism
sensorConsumers := NewConsumerGroup("sensor-events-handler", "sensor-events", partitions=3)
userConsumers := NewConsumerGroup("user-actions-handler", "user-actions", partitions=2)
systemConsumers := NewConsumerGroup("system-events-handler", "system-events", partitions=1)

// All share the same handler registry
registry := NewHandlerRegistry()
registry.Register("sensor.", sensorHandler)
registry.Register("user.", userHandler)
```

### Migration Trigger

Move to topic-specific consumers when:
- Single consumer can't keep up (consumer lag growing)
- Need independent scaling per event type
- Need isolation between event types

### Ordering Guarantees

| Phase | Ordering |
|-------|----------|
| Phase 1 (single consumer) | Global ordering across all topics (stronger than needed) |
| Future (partitioned) | Per-partition ordering only; same `aggregate_id` → same partition → ordered |

For CQRS projections, per-aggregate ordering is sufficient. Events for the same aggregate go to the same partition (keyed by `aggregate_id`).

## Consequences

### Benefits
- Phase 1 is simple and sufficient for dev
- Clear migration path when scaling needed
- Handler code is reusable across phases

### Trade-offs
- Phase 1 single consumer is a throughput bottleneck
- Migration requires increasing partition count (can't decrease)
- Multiple consumer groups add operational complexity

### Mitigations
- Document single-consumer limitation in ARCHITECTURE.md
- Design handler code to be consumer-agnostic from the start
- Monitor consumer lag to detect when migration is needed

## Related ADRs

- [ADR-0012](0012-outbox-processing-strategy.md) — Similar scaling strategy for Outbox Processor
- [ADR-0003](0003-cqrs-with-eventual-consistency.md) — CQRS pattern that Event Handler implements
