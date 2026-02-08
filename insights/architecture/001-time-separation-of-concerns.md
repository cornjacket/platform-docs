# Insight: Separation of Concerns for Time

**Discovered:** 2026-02-07
**Context:** Designing Task 008 (Time Handling Strategy) for the event-driven platform

## The Insight

Event-driven systems need **two distinct timestamps** with clear ownership:

| Timestamp | Owner | Meaning |
|-----------|-------|---------|
| **EventTime** | Caller/Producer | "When did this happen?" — business domain |
| **IngestedAt** | Platform | "When did we receive it?" — infrastructure domain |

**The caller should NOT set IngestedAt** because:
1. It's the platform's audit record, not the caller's claim
2. Callers could lie (security/audit concern)
3. It's semantically wrong — "when I ingested" is the platform's truth

## Why It Matters

Without separation:
- Can't distinguish "when it happened" from "when we learned about it"
- Can't track ingestion latency or debug delays
- Buffered/batched events lose their original timing
- Replay scenarios become impossible to implement correctly

With separation:
- Analytics use EventTime for business insights
- Operations use IngestedAt for SLA tracking
- Replay preserves original semantics
- Each timestamp has one owner, one meaning

## Example

```
Device buffers 3 readings during network outage:
  Reading 1: EventTime = 10:00:00  (temperature spike)
  Reading 2: EventTime = 10:01:00  (normal)
  Reading 3: EventTime = 10:02:00  (normal)

Network recovers, device sends batch at 10:15:00:
  All 3 arrive with IngestedAt = 10:15:00

Analysis:
  - EventTime tells us the spike happened at 10:00
  - IngestedAt tells us we learned about it 15 minutes late
  - Without both, we'd think all readings happened at 10:15
```

## Industry Precedent

| System | Event Time | Ingestion Time |
|--------|------------|----------------|
| **Kafka** | CreateTime (producer) | LogAppendTime (broker) |
| **Event Store** | Created (producer) | Recorded (server) |
| **Apache Flink** | Event time | Processing time / Ingestion time |
| **CloudEvents** | `time` field | (not specified — infrastructure concern) |

## API Design

```go
// Caller provides eventTime, platform sets ingestedAt
func NewEnvelope(
    eventType, aggregateID string,
    payload any,
    metadata Metadata,
    eventTime time.Time,  // ← from caller
) (*Envelope, error) {
    return &Envelope{
        EventTime:  eventTime,
        IngestedAt: clock.Now(),  // ← from platform
        // ...
    }, nil
}
```

## Related

- [Task 008: Time Handling Strategy](../../platform-services/tasks/008-time-handling-strategy.md)
- [Insight: Clock as Dependency Injection](002-clock-as-dependency-injection.md)
