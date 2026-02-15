# 15. Testing

## 15.1 Test Strategy

| Test Type | Location | Purpose | When to Run |
|-----------|----------|---------|-------------|
| Unit tests | `*_test.go` files | Test individual functions/methods in isolation | `go test ./...` |
| Integration tests | `*_test.go` files | Test components with real dependencies (Postgres, Redpanda) | `go test -tags=integration ./...` |
| Component tests | `*_test.go` files | Test service level boundaries with real dependencies (Postgres, Redpanda) | `go test -tags=component ./...` |
| E2E tests | `e2e/` directory | Test complete flows through the system | Before releases, after changes |

## 15.2 Unit/Integration Tests

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

**Running tests:**
```bash
# Unit tests only (no infrastructure needed)
go test ./internal/shared/domain/... ./internal/shared/config/...

# Integration tests (requires docker compose up)
go test -tags=integration ./internal/shared/infra/... ./internal/shared/projections/...

# All tests
go test ./...
```

**Test coverage:**
```bash
# Generate coverage report
go test -coverprofile=coverage.out ./internal/...

# View coverage summary
go tool cover -func=coverage.out

# View line-by-line in browser
go tool cover -html=coverage.out
```

Note: Coverage reports (`coverage.out`, `coverage.html`) are **not checked in**. They are ephemeral status metrics generated on demand or tracked by CI. See [Insight: Static vs Dynamic Documentation](../insights/development/003-static-vs-dynamic-documentation.md).

## 15.3 Component Tests

Component tests exercise a full service pipeline through its `Start()` entry point. They use real infrastructure for inputs (Postgres, Redpanda) and channel-based mocks for outputs (`EventSubmitter`, `ProjectionWriter`).

| Test Type | What It Tests | Infra | Mocks |
|-----------|--------------|-------|-------|
| Unit | Individual functions | None | All dependencies |
| Integration | Single adapter (repo, producer) | Real DB or Redpanda | None |
| **Component** | **Full service pipeline** | **Real DB + Redpanda** | **Service output only** |
| E2E | All services together | Everything | None |

**Build tag:** `//go:build component`

**Running component tests:**
```bash
# All component tests (requires docker compose up)
go test -tags=component -v ./internal/services/...

# Single service
go test -tags=component -v ./internal/services/ingestion/
```

**Channel-based mock pattern:**

Component tests capture async service outputs using buffered channels. The mock's method writes to a channel; the test blocks with a `select` + timeout:

```go
mock := &channelSubmitter{calls: make(chan *events.Envelope, 10)}
svc, _ := ingestion.Start(ctx, cfg, pool, mock, logger)

// POST event via HTTP
postEvent(t, payload)

// Assert — wakes up the instant the worker calls SubmitEvent()
select {
case event := <-mock.calls:
    assert.Equal(t, "sensor.reading", event.EventType)
case <-time.After(5 * time.Second):
    t.Fatal("timed out waiting for event submission")
}
```

**Sentinel event pattern for negative assertions:**

To prove an event was consumed but triggered no output (e.g., unknown event type → no projection write), avoid timeout-based assertions ("wait 500ms, check nothing happened"). Instead, produce the unknown event followed by a known event. Kafka's partition ordering guarantees the unknown event is processed first. When the mock receives the known event's output, the unknown event has already been processed and skipped:

```go
// Produce unknown event, then a known sentinel
produceEvent(t, topic, unknownEnv)   // "billing.charge" — no handler registered
produceEvent(t, topic, sensorEnv)    // "sensor.reading" — has handler

// When sensor_state arrives, billing.charge was already processed and skipped
select {
case call := <-mock.calls:
    assert.Equal(t, "sensor_state", call.ProjType)
case <-time.After(5 * time.Second):
    t.Fatal("timed out")
}

// Verify no extra writes from the unknown event
assert.Empty(t, mock.calls)
```

This pattern works in any ordered pipeline (Kafka partitions, database sequences, FIFO queues). The key requirement: the sentinel and the unknown event must share the same ordering domain.

## 15.4 End-to-End Tests

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
