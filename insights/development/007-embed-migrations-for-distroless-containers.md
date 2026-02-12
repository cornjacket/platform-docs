# Insight: Embed Migrations for Distroless Containers

**Discovered:** 2026-02-12
**Context:** Containerizing the platform with a distroless base image, where `make migrate-all` (which shells into Postgres via `docker compose exec`) cannot work

## The Insight

When deploying Go services as distroless containers, SQL migration files must be compiled into the binary using `//go:embed`. The binary becomes fully self-contained: it connects to the database, applies pending migrations, then starts serving. No shell, no filesystem, no operator intervention.

The pattern:
1. Each service package declares `//go:embed migrations/*.sql` to expose a `MigrationFS`
2. A shared `RunMigrations()` helper opens a temporary `database/sql` connection and applies migrations via goose
3. `main.go` runs all migrations sequentially before starting any services
4. If any migration fails, the binary exits immediately — no partially-migrated database serves traffic

## Why It Matters

This eliminates an entire class of deployment problems:
- **No manual migration step** — zero-touch deployment in ECS, Kubernetes, or any container runtime
- **No init containers or sidecar scripts** — the binary is the single deployment artifact
- **Environment-agnostic** — identical behavior in local dev, Docker fullstack, and AWS
- **Fail-fast** — migration errors surface at startup, not at query time

The alternative — having a separate migration job, bastion script, or operator workflow — adds operational complexity that doesn't scale.

## Example

```go
// internal/services/ingestion/migrations.go
package ingestion

import "embed"

//go:embed migrations/*.sql
var MigrationFS embed.FS
```

```go
// cmd/platform/main.go — between DB connect and service start
if err := postgres.RunMigrations(cfg.DatabaseURL, ingestion.MigrationFS, "migrations", "goose_ingestion"); err != nil {
    slog.Error("migration failed", "error", err)
    os.Exit(1)
}
```

Goose requires `-- +goose Up` at the top of each SQL file. PL/pgSQL functions with `$$` dollar-quoting need `-- +goose StatementBegin` / `-- +goose StatementEnd` to prevent semicolon splitting.

## Related

- [ADR-0016: Embedded Migration on Startup](../../decisions/0016-embedded-migration-on-startup.md)
- [Spec 015: Embedded Migrations](../../platform-services/tasks/015-embedded-migrations.md)
- [Per-Service Migration Table Isolation](006-per-service-migration-table-isolation.md)
