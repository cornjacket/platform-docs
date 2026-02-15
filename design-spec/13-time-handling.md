# 13. Time Handling

The platform uses a `clock` package for time abstraction, enabling testability and replay.

## 13.1 Dual Timestamps

Events carry two timestamps with distinct purposes:

| Field | Set By | Purpose |
|-------|--------|---------|
| `event_time` | Caller | When the event occurred (business time) |
| `ingested_at` | Platform | When the platform received it (audit time) |

**API behavior:** The `event_time` field is optional. If omitted, defaults to current time.

## 13.2 Clock Implementations

| Clock | Usage | Behavior |
|-------|-------|----------|
| `RealClock` | Production | Returns `time.Now().UTC()` |
| `FixedClock` | Unit tests | Returns a predetermined time |
| `ReplayClock` | Event replay | Advances with historical events |

## 13.3 Usage

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

See [ADR-0015](../decisions/0015-time-handling-strategy.md) for rationale.
