# Insight: Process Liveness Is Not Health

**Discovered:** 2026-02-12
**Context:** Five stale platform processes found running with failed HTTP port binds — alive but not functional, invisible to any health monitoring

## The Insight

A running process is not a healthy service. Every service in the platform — including background workers with no natural HTTP interface — must expose an HTTP health check endpoint. Process liveness (container hasn't exited) is the lowest bar; it cannot detect:

- Deadlocked goroutines (process alive, work stopped)
- Lost Kafka consumer group membership (process alive, not consuming)
- Exhausted or hung database connection pools
- Failed port binds where background workers keep running without HTTP endpoints

Container orchestrators (ECS, Kubernetes) rely on HTTP health probes to make scheduling decisions. Without an endpoint, the orchestrator assumes healthy — it cannot distinguish a working service from a zombie.

## Why It Matters

This is a platform-wide architectural requirement, not a per-service convenience. It means:

1. **Background workers need HTTP servers.** The Event Handler is primarily a Kafka consumer, but it must still run a minimal HTTP server for health probes. The health response should reflect actual readiness ("connected to Kafka and processing"), not just "process started."

2. **Health checks define the deployment contract.** ECS task definitions, Docker Compose `healthcheck` directives, and load balancer target groups all depend on HTTP health endpoints. A service without one cannot be orchestrated.

3. **Shallow health is better than no health.** Even a basic "return 200 if the server is listening" catches port conflicts, startup failures, and crash loops. Deep health (checking downstream dependencies) can be added incrementally.

## Example

```go
// Even a background consumer needs this
mux := http.NewServeMux()
mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{
        "status":  "ok",
        "service": "eventhandler",
    })
})
go http.ListenAndServe(":8084", mux)
```

## Related

- [Design Spec: Section 2.9 — Service Health & Startup Reliability](../../design-spec.md)
- [Insight: Propagate Async Server Errors to Main](../development/008-propagate-async-server-errors.md)
- [Backlog 003: Service Health Checks](../../platform-services/tasks/backlog/003_service-health-checks.md)
