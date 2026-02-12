# ADR 0016: Embedded Migration on Startup

* **Status:** Proposed
* **Date:** 2026-02-11
* **Architect:** David

## Context

ADR-0010 establishes that each service owns its migrations and is responsible for running them. In practice, migrations are currently applied by a developer running `make migrate-all`, which shells into the Postgres container via `docker compose exec` and pipes SQL files.

This works for local skeleton development (binary on host, Postgres in Docker) but breaks in every other deployment context:

- **Fullstack mode (containerized platform):** The platform image is distroless — no shell, no filesystem access to SQL files, no `docker compose exec`.
- **AWS ECS:** No Docker Compose, no developer in the loop. Migrations must happen without manual intervention.
- **Bastion pattern:** A DevOps engineer SSHs into a bastion host and runs migrations manually. This doesn't scale, introduces human error, and couples deployments to operator availability.

The gap is that ADR-0010 defines migration *ownership* but not migration *execution*.

## Decision

**Each service embeds its SQL migration files into the Go binary using `//go:embed` and applies pending migrations automatically on startup, before serving traffic.**

### Mechanism

1. Migration `.sql` files stay in `internal/services/<service>/migrations/` (unchanged from ADR-0010).
2. Each service package uses `//go:embed migrations/*.sql` to compile the SQL into the binary.
3. On startup, before `Start()` opens any ports or consumers, a migration step:
   - Connects to the service's database
   - Checks a `schema_migrations` table for already-applied versions
   - Applies any pending migrations in order
   - Skips already-applied migrations (idempotent)
4. If migration fails, the service does not start.

### Library

Use `golang-migrate/migrate` (or `pressly/goose`) — both support `io/fs` sources (compatible with `//go:embed`) and track applied versions in a metadata table.

### Startup Order

```
main.go
  ├── Load config
  ├── Connect to databases
  ├── Run migrations (per-service, against each service's DB)  ← NEW
  ├── Start services (ingestion, eventhandler, query)
  └── Wait for shutdown
```

### `make migrate-all` Retained

The Makefile target remains as a development convenience for resetting a local database (drop all tables, re-migrate from scratch). It is no longer the primary migration mechanism — the binary handles that.

## Rationale

**Zero-touch deployment:** The binary is the single deployment artifact. No sidecar scripts, no init containers, no operator intervention. Start the binary, migrations run, services start.

**Distroless compatible:** `//go:embed` compiles SQL into the binary. No filesystem, no shell, no external files needed at runtime.

**Consistent across environments:** Local dev, Docker fullstack, ECS — identical behavior. The same binary applies the same migrations everywhere.

**Fail-fast:** If a migration fails, the service doesn't start. No partially-migrated database serving traffic.

**Extends ADR-0010:** Migration ownership (files live with the service) was already decided. This ADR adds the execution mechanism.

## Consequences

### Benefits
- Deployments are fully automated — no manual migration step
- Works in distroless containers and serverless environments
- Single artifact (binary) contains everything needed to run
- Idempotent — safe to restart, scale horizontally, or roll back to a previous version

### Trade-offs
- Startup time increases slightly (migration check on every boot, even if nothing to apply)
- Adds a library dependency (`golang-migrate` or `goose`)
- Rollback migrations require careful design (down migrations vs forward-only)
- All replicas race to migrate on simultaneous startup (library handles locking)

### Constraints
- Migration files must be sequential and immutable once deployed (no editing applied migrations)
- Forward-only migrations recommended (no down migrations in production)
- `schema_migrations` table is owned by the migration library, not by any service

## Related ADRs
- ADR-0010: Database-Per-Service Pattern (migration ownership)
- ADR-0003: Unified PostgreSQL Data Stack
- ADR-0007: Local and Cloud Development Strategy
