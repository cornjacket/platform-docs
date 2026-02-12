# Insight: Static vs Dynamic Documentation

**Discovered:** 2026-02-08
**Context:** Deciding whether to check in test coverage reports

## The Insight

Documentation falls into two categories with different lifecycle management:

| Category | Examples | Checked In? | Why |
|----------|----------|-------------|-----|
| **Static (Strategy)** | Test patterns, coverage commands, "how to test" | ✅ Yes | Describes approach, changes rarely |
| **Dynamic (Status)** | Coverage %, test results, benchmark numbers | ❌ No | Point-in-time snapshot, changes constantly |

## The Principle

> **Document the strategy, not the status.**

Strategy docs describe *how* to do something. They're reference material that developers consult.

Status metrics are *outputs* generated from running tools. They become stale immediately and clutter the repo if checked in.

## Examples

### Test Coverage

| Aspect | Type | Checked In? |
|--------|------|-------------|
| "Run `go test -coverprofile=coverage.out`" | Strategy | ✅ |
| "Coverage is 73%" | Status | ❌ |
| "Target 80% for new packages" | Strategy | ✅ |
| `coverage.out` file | Status | ❌ |

### Benchmarks

| Aspect | Type | Checked In? |
|--------|------|-------------|
| "Run `go test -bench=.`" | Strategy | ✅ |
| "BenchmarkIngest: 1.2ms/op" | Status | ❌ |
| "Ingest must complete in <5ms" | Strategy | ✅ |

### Dependency Audits

| Aspect | Type | Checked In? |
|--------|------|-------------|
| "Run `go mod verify`" | Strategy | ✅ |
| "All dependencies verified ✓" | Status | ❌ |

## Where Status Belongs

Status metrics should flow through CI, not the repo:

```
Test run → CI pipeline → Dashboard/PR comment → Ephemeral
                     ↳ S3 (if historical tracking needed)
```

Benefits:
- Repo stays clean (no churn from generated files)
- CI becomes source of truth for current status
- Historical tracking is deliberate, not accidental

## Implementation

Add to `.gitignore`:
```
# Test artifacts (generated, not checked in)
coverage.out
coverage.html
```

Document commands in design-spec.md (strategy):
```bash
go test -coverprofile=coverage.out ./internal/...
go tool cover -html=coverage.out
```

CI produces and tracks the actual numbers (status).

## Related

- [design-spec.md §15 Testing](../../design-spec.md#15-testing)
- [003-documentation-placement.md](003-documentation-placement.md)
