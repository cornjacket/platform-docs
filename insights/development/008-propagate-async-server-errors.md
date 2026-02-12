# Insight: Propagate Async Server Errors to Main

**Discovered:** 2026-02-12
**Context:** Five stale platform processes discovered running simultaneously — all had failed to bind HTTP ports but kept running background workers indefinitely

## The Insight

When `http.ListenAndServe` runs in a goroutine (the standard Go pattern), bind failures are asynchronous. If the error is only logged and not propagated back to the main goroutine, the process appears healthy — background workers keep running, the main goroutine blocks on `select` waiting for signals, and the process never exits.

Every goroutine that can fail fatally must have a path to trigger process shutdown. The simplest pattern: write the error to a channel that `main()` selects on alongside the signal channel.

## Why It Matters

Silent partial failures are worse than crashes:
- Background workers continue processing (outbox polling, event consuming) without HTTP health checks responding
- Container orchestrators (ECS, Kubernetes) can't detect the failure if health checks never respond
- Multiple broken instances accumulate, all competing for the same database and message bus resources
- Port conflicts mask the root cause — "address already in use" scrolls past in logs while the process seems fine

## Example

```go
// BAD: error logged but process lives forever
go func() {
    if err := server.ListenAndServe(); err != nil {
        slog.Error("server error", "error", err)  // and then... nothing
    }
}()

// GOOD: error propagated to main select
errCh := make(chan error, 1)
go func() {
    if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
        errCh <- err
    }
}()

select {
case sig := <-sigCh:
    // graceful shutdown
case err := <-errCh:
    // fatal error, initiate shutdown
}
```

## Related

- [Backlog 002: Port Collision Shutdown](../../platform-services/tasks/backlog/002_port-collision-shutdown.md)
- [Backlog 003: Service Health Checks](../../platform-services/tasks/backlog/003_service-health-checks.md)
