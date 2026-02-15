# 9. Observability

## 9.1 Logging

| Aspect | Decision |
|--------|----------|
| Backend | CloudWatch Logs |
| Format | Structured JSON |
| Rationale | AWS-native integration, queryable logs, no additional infrastructure |

**Trade-offs:** CloudWatch query language less powerful than Elasticsearch, but sufficient for dev

## 9.2 Metrics

| Aspect | Decision |
|--------|----------|
| Backend | AWS CloudWatch Metrics |
| Scope | Basic/automatic metrics (CPU, memory, network) |
| Custom metrics | Deferred (CloudWatch SDK available) |

## 9.3 Distributed Tracing

| Aspect | Decision |
|--------|----------|
| Instrumentation | OpenTelemetry |
| Collection | Deferred |
| Backend (future) | Honeycomb |

**Rationale:** Adding instrumentation now is low-cost. Can enable/disable collection without code changes.

## 9.4 Dashboards & Visualization

| Tool | Purpose |
|------|---------|
| Traefik Dashboard | Real-time traffic routing view |
| CloudWatch Console | Ad-hoc log searches and metric viewing |
| Grafana | Deferred |
