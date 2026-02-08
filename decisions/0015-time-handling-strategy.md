# ADR-0015: Time Handling Strategy

**Status:** Accepted
**Date:** 2026-02-07

## Context

The platform needs to handle timestamps for events in a way that:
1. Distinguishes when events occurred vs when they were received
2. Supports IoT devices that buffer events during network outages
3. Enables deterministic unit testing
4. Allows future replay scenarios

## Decision

### Dual Timestamps

Events have two timestamps with clear ownership:

| Timestamp | Owner | Purpose |
|-----------|-------|---------|
| `EventTime` | Caller/Producer | When it happened (business domain) |
| `IngestedAt` | Platform | When received (infrastructure domain) |

### Clock Abstraction

Time is accessed via `clock.Now()` instead of `time.Now()`. The clock package provides:
- `RealClock` — Production (actual system time)
- `FixedClock` — Unit tests (deterministic assertions)
- `ReplayClock` — Event replay (advances with historical events)

## Consequences

### Positive
- Unit tests are deterministic (no flaky timestamp assertions)
- IoT devices can report accurate event times despite network delays
- Replay scenarios can recreate exact historical state
- Clear separation between business time and platform time

### Negative
- Slightly more complex API (optional `event_time` field)
- Callers with incorrect clocks can submit inaccurate event times

## Implementation

See [Task 008](../../platform-services/tasks/008-time-handling-strategy.md) for full implementation details.

## Related

- [Insight: Time Separation of Concerns](../insights/architecture/001-time-separation-of-concerns.md)
- [Insight: Clock as Dependency Injection](../insights/architecture/002-clock-as-dependency-injection.md)
