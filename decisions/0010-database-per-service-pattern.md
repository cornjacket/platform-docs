# ADR 0010: Database-Per-Service Pattern

* **Status:** Accepted
* **Date:** 2026-02-04
* **Architect:** David

## Context

The platform is designed as a networked monolith that can be extracted into microservices (ADR-0001). Services currently share a single PostgreSQL database (ADR-0003), but this creates tight coupling that complicates future extraction.

Key concerns:
- Services can accidentally access or corrupt each other's data
- Schema migrations require coordination across all services
- Extracting a service requires untangling shared database dependencies

## Decision

**Each service receives its own database connection URL as configuration input.**

### Configuration Pattern

```bash
# Each service has its own database URL
INGESTION_DATABASE_URL=postgres://...
EVENTHANDLER_DATABASE_URL=postgres://...
QUERY_DATABASE_URL=postgres://...
```

### Environment Strategy

| Environment | Strategy |
|-------------|----------|
| **Dev (local)** | All services point to the same database for simplicity |
| **Dev (AWS)** | Same database, optionally separate schemas |
| **Prod** | Separate databases per service |

### Table Ownership

Each service owns its tables and migrations:

| Service | Tables | Responsibility |
|---------|--------|----------------|
| **Ingestion** | outbox, event_store | Write path (Ingestion + Ingestion Worker) |
| **Event Handler** | projections, dlq | CQRS read-side projections, consumer DLQ |
| **Query** | (none) | Reads from Event Handler's projections via `shared/projections` |
| **TSDB Writer** | timeseries tables, dlq | Time-series data, consumer DLQ |
| **Actions** | action_config, dlq | Webhook configuration, consumer DLQ |

### Migration Ownership

Migrations live with the service that owns the tables:

```
internal/
├── ingestion/
│   └── migrations/
│       ├── 001_create_outbox.sql
│       └── 002_create_event_store.sql
├── eventhandler/
│   └── migrations/
│       ├── 001_create_projections.sql
│       └── 002_create_dlq.sql
└── tsdb/
    └── migrations/
        └── 001_create_timeseries.sql
```

Each service is responsible for running its own migrations.

## Rationale

**Isolation:** One service cannot accidentally read, modify, or corrupt another service's data. Database boundaries enforce service boundaries.

**Independent scaling:** Each database can be sized, tuned, and scaled independently based on its workload.

**Clean extraction:** When extracting a service to its own repo/deployment, it takes its database URL config and migrations with it. No untangling required.

**Dev flexibility:** In development, all services can share one database for simplicity. The code doesn't change — only the configuration.

**Explicit dependencies:** If Service A needs data from Service B, it must call Service B's API. No hidden database dependencies.

## Consequences

### Benefits
- True data isolation between services
- Each service owns its schema evolution
- Simplified microservices extraction
- Clear data ownership boundaries

### Trade-offs
- Cross-service queries require API calls (no JOINs across services)
- More configuration to manage (multiple database URLs)
- In prod, more databases to operate and monitor

### Constraints
- Services must not share tables directly
- Cross-service data access must go through APIs or events
- Each service must handle its own migrations

## Related ADRs
- ADR-0001: Event-Driven CQRS Architecture
- ADR-0003: Unified PostgreSQL Data Stack
- ADR-0007: Local and Cloud Development Strategy
