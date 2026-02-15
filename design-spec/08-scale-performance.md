# 8. Scale & Performance Requirements (Dev)

## 8.1 Target Throughput

| Metric | Target | Notes |
|--------|--------|-------|
| HTTP API | ~10 requests/second | Dev environment |
| MQTT events | ~10 events/second | Dev environment |

**Note:** These targets are intentionally orders of magnitude below production ambitions to optimize for cost and simplicity during the learning phase.

## 8.2 Latency Requirements

| Metric | Target | Notes |
|--------|--------|-------|
| Ingestion latency | < 500ms | HTTP request to accepted response |
| End-to-end latency | < 5 seconds | Event received to projection updated |
| Query latency | < 1 second | Query response time |

**Rationale:** Relaxed requirements appropriate for dev environment. Focus on correctness over performance.

**Decision deferred:** Production SLAs (p50, p95, p99 latency targets)

## 8.3 Data Retention Policies

| Data Store | Retention | Notes |
|------------|-----------|-------|
| Postgres Event Store | 7 days | |
| Postgres Projections/TSDB | 7 days | |
| Redpanda Message Bus | 24 hours | |

**Rationale:** Cost optimization for dev environment. Sufficient for testing and debugging.

**Decision deferred:**
- Production retention requirements (30/90/365 days or longer)
- Archival strategy for long-term storage
- Compliance/regulatory retention requirements
