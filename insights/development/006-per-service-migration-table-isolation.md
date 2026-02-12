# Insight: Per-Service Migration Table Isolation

**Discovered:** 2026-02-12
**Context:** Implementing embedded migrations (Spec 015) with goose, where two services share a single Postgres database in dev

## The Insight

When multiple services share a database and each has its own set of numbered migration files, a single migration version table causes **silent** migration skipping. The first service claims version numbers (1, 2), and the second service's migrations (also numbered 1, 2) are skipped without error because goose sees "already at version 2."

The fix: each service must use a dedicated version tracking table (e.g., `goose_ingestion`, `goose_eventhandler`) via `goose.SetTableName()`.

This applies to any migration framework — goose, golang-migrate, flyway, alembic — whenever multiple independent migration sets share a database.

## Why It Matters

This bug is silent. The migration tool reports success ("no migrations to run"), the application starts normally, and queries fail later with "relation does not exist" errors. In production with separate databases per service (ADR-0010), the collision doesn't occur — so it only manifests in dev/test environments where databases are shared for convenience. That makes it harder to catch: it works in production but breaks in dev, which is the opposite of the usual failure mode.

## Example

```go
// BAD: both services share the default "goose_db_version" table
postgres.RunMigrations(cfg.IngestionDBURL, ingestion.MigrationFS, "migrations")
postgres.RunMigrations(cfg.EventHandlerDBURL, eventhandler.MigrationFS, "migrations")
// Second call is a no-op — event handler tables never created

// GOOD: per-service version tracking
postgres.RunMigrations(cfg.IngestionDBURL, ingestion.MigrationFS, "migrations", "goose_ingestion")
postgres.RunMigrations(cfg.EventHandlerDBURL, eventhandler.MigrationFS, "migrations", "goose_eventhandler")
```

## Related

- [ADR-0010: Database-Per-Service Pattern](../../decisions/0010-database-per-service.md)
- [ADR-0016: Embedded Migration on Startup](../../decisions/0016-embedded-migration-on-startup.md)
- [Spec 015: Embedded Migrations](../../platform-services/tasks/015-embedded-migrations.md)
