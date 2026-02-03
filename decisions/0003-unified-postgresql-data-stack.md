# ADR 0003: Unified PostgreSQL Data Stack

* **Status:** Accepted
* **Date:** 2026-01-29
* **Architect:** David

## Context

The platform requires multiple data stores:
- **Event Store:** Append-only log of all events (CQRS write side)
- **Time-Series Database (TSDB):** Historical storage for sensor data, metrics, AI results
- **Projections:** Materialized views optimized for queries (CQRS read side)
- **Outbox Table:** Transient queue for the outbox pattern (ADR-0002)
- **DLQ Table:** Dead letter queue for failed consumer processing

Using separate database technologies (e.g., PostgreSQL for events + InfluxDB for time-series) would add operational complexity.

## Decision

Use a **single PostgreSQL instance with TimescaleDB extension** for all data storage needs.

### Schema Separation

| Schema | Purpose | Characteristics |
|--------|---------|-----------------|
| **event_store** | Append-only event log | Immutable, source of truth |
| **outbox** | Transient processing queue | High churn (insert/delete) |
| **projections** | Materialized views for queries | Updated by Event Handler |
| **timeseries** | Time-series data (TimescaleDB hypertables) | Per-customer project schemas |
| **dlq** | Dead letter queue | Failed events for replay |

### Event Store Schema

| Column | Type | Purpose |
|--------|------|---------|
| event_id | UUID | Unique identifier per event |
| event_type | STRING | Discriminator (e.g., `sensor.reading`, `user.action`) |
| aggregate_id | STRING | Groups related events (e.g., device ID, session ID) |
| timestamp | TIMESTAMPTZ | When the event occurred |
| payload | JSONB | Event-specific data |
| metadata | JSONB | Trace IDs, source info, schema version |

### Time-Series Approach

- Each customer project defines its own TimescaleDB schema tailored to its specific data model
- Schemas use **typed columns** (not JSONB) for known, structured time-series data to optimize storage and query performance
- The Event Handler transforms events from the bus into the appropriate project-specific schema

## Rationale

- **Single database technology** simplifies the operational stack:
  - One set of connection libraries
  - One query language (SQL)
  - One backup strategy
  - One container to manage

- **TimescaleDB** extends Postgres with time-series capabilities (hypertables, continuous aggregates, compression) without introducing a separate system like InfluxDB

- **Avoids dual-database complexity:**
  - No separate drivers, connection pools, health checks
  - No data synchronization between event store and TSDB

- **PostgreSQL ecosystem** is mature and well-understood — extensive tooling, monitoring, and community support

- **Reduces cognitive overhead** for a single-developer project

## Consequences

### Benefits
- Operational simplicity — one database to manage
- Consistent tooling and monitoring
- SQL for all data access
- TimescaleDB features (hypertables, compression) available when needed

### Trade-offs
- Cannot scale event store and TSDB independently
- A dedicated TSDB (InfluxDB, QuestDB) may outperform TimescaleDB for pure time-series workloads at very high volume — acceptable given dev-scale traffic
- All eggs in one basket — Postgres outage affects everything

### Deferred Decisions
- Schema provisioning and multi-tenant isolation strategy
- Separate instances for staging/prod if independent scaling needed
- Migration to dedicated TSDB if performance requires it

## Related ADRs
- ADR-0001: Event-Driven CQRS Architecture
- ADR-0002: Outbox-First Write Pattern
- ADR-0004: Error Handling Philosophy
