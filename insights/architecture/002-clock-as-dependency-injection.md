# Insight: Clock as Dependency Injection

**Discovered:** 2026-02-07
**Context:** Making `NewEnvelope()` testable without flaky timestamp assertions

## The Insight

**Time is an input, not a side effect.**

When you call `time.Now()` directly, time is a hidden dependency — non-deterministic, untestable, and impossible to control. By abstracting time behind a `Clock` interface, time becomes explicit and controllable.

This is the same principle as dependency injection for databases — you wouldn't hardcode `sql.Open()` inside your service. Why hardcode `time.Now()`?

## Why It Matters

| With `time.Now()` | With `clock.Now()` |
|-------------------|---------------------|
| Tests are flaky | Tests are deterministic |
| Can't replay events exactly | Exact replay possible |
| Can't simulate time scenarios | Time-travel debugging |
| Hidden dependency | Explicit dependency |

## The Pattern

```go
// Package-level clock avoids threading through every function
package clock

var current Clock = RealClock{}

func Now() time.Time {
    return current.Now()
}

func Set(c Clock) {
    current = c
}

func Reset() {
    Set(RealClock{})
}
```

**Production** — uses real time by default:
```go
envelope := events.NewEnvelope(...)
// clock.Now() returns time.Now().UTC()
```

**Tests** — inject fixed time:
```go
func TestEnvelope(t *testing.T) {
    clock.Set(clock.FixedClock{Time: fixedTime})
    t.Cleanup(clock.Reset)

    envelope := events.NewEnvelope(...)
    assert.Equal(t, fixedTime, envelope.IngestedAt)  // deterministic!
}
```

**Replay** — clock follows historical events:
```go
replayClock := &clock.ReplayClock{}
clock.Set(replayClock)

for _, event := range historicalEvents {
    replayClock.Advance(event.IngestedAt)
    process(event)  // sees original time
}
```

## Clock Implementations

| Clock | Use Case |
|-------|----------|
| `RealClock` | Production — actual system time |
| `FixedClock` | Unit tests — predetermined time |
| `ReplayClock` | Event replay — advances with events |
| `AcceleratedClock` | Load testing — time moves faster |

## Broader Principle

This pattern applies to any non-deterministic dependency:

| Dependency | Abstraction | Test Double |
|------------|-------------|-------------|
| Time | `Clock` interface | `FixedClock` |
| Random | `Rand` interface | `FixedRand` |
| UUID generation | `IDGenerator` interface | `SequentialID` |
| File system | `FileSystem` interface | `MemoryFS` |

The pattern is: **wrap the non-deterministic thing in an interface, inject it, swap it in tests**.

## Related

- [Task 008: Time Handling Strategy](../../platform-services/tasks/008-time-handling-strategy.md)
- [Insight: Time Separation of Concerns](001-time-separation-of-concerns.md)
- [ARCHITECTURE.md — Component Testing](../../platform-services/ARCHITECTURE.md)
