# ADR-0013: UUID v7 Standardization

**Status:** Accepted
**Date:** 2026-02-04

## Context

The platform generates UUIDs in two places:

1. **Application (Go):** `EventID` in event envelopes, using `github.com/google/uuid` which generates UUID v4
2. **PostgreSQL:** Internal row IDs (`outbox_id`, `projection_id`, `dlq_id`) using `uuid_generate_v4()` from `uuid-ossp` extension

Concerns with UUID v4:

- **No time ordering:** Random UUIDs cause B-tree index fragmentation (random inserts across pages)
- **Query performance:** Time-range queries on UUIDs are inefficient
- **Debugging:** Cannot visually identify event ordering from IDs
- **Horizontal scaling:** While v4 collision is astronomically unlikely, v7 provides additional safety through time-based prefixes

## Decision

Standardize on **UUID v7** across the entire platform.

### UUID v7 Benefits

| Aspect | UUID v4 | UUID v7 |
|--------|---------|---------|
| Generation | Random | Time-ordered + random |
| Index locality | Poor (random page inserts) | Good (sequential inserts) |
| Sortable by time | No | Yes |
| Collision resistance | 122 random bits | Timestamp + 62 random bits |
| Debugging | Opaque | Time-decodable |

### Implementation

**PostgreSQL 18 native `uuidv7()`:**
- Upgrade to `timescale/timescaledb:2.23.0-pg18`
- Use `DEFAULT uuidv7()` for database-generated UUIDs
- No extension required — built into PostgreSQL 18

**Application (Go):**
- Replace `github.com/google/uuid` with `github.com/gofrs/uuid/v5`
- Use `uuid.NewV7()` for `EventID` generation (application-controlled)

### Why PostgreSQL 18?

We initially considered using the `pg_uuidv7` extension, but verified it was **not available** in `timescale/timescaledb:2.11.2-pg15`:

```sql
SELECT * FROM pg_available_extensions WHERE name = 'pg_uuidv7';
-- (0 rows)
```

**Alternatives considered:**

| Option | Verdict |
|--------|---------|
| Generate all UUIDs in application | More code, less consistent |
| [fboulnois/pg_uuidv7](https://github.com/fboulnois/pg_uuidv7) Docker image | Has extension, but no TimescaleDB |
| Build custom image (TimescaleDB + pg_uuidv7) | Adds maintenance burden |
| **Upgrade to PostgreSQL 18** | Native `uuidv7()` built-in, TimescaleDB image available |

**Decision:** Upgrade to PostgreSQL 18 (`timescale/timescaledb:2.23.0-pg18`). This:
- Provides native `uuidv7()` without extensions
- Keeps database DEFAULTs (simpler SQL, less application code)
- Uses official TimescaleDB image
- Is acceptable risk for dev environment (PG18 is stable as of 2026)

### Affected Components

| Location | Current | New |
|----------|---------|-----|
| `docker-compose.yml` | `timescale/timescaledb:2.11.2-pg15` | `timescale/timescaledb:2.23.0-pg18` |
| `events/envelope.go` | `uuid.New()` (v4) | `uuid.NewV7()` |
| `001_create_outbox.sql` | `uuid_generate_v4()` | `uuidv7()` |
| `002_create_event_store.sql` | (app provides v4) | (app provides v7) |
| `001_create_projections.sql` | `uuid_generate_v4()` | `uuidv7()` |
| `002_create_dlq.sql` | `uuid_generate_v4()` | `uuidv7()` |

## Consequences

### Positive

- Consistent UUID version across application and database
- Better index performance for high-volume tables
- Time-ordered IDs aid debugging and log correlation
- Reduced index fragmentation
- Native PostgreSQL support — no extensions required

### Negative

- Requires PostgreSQL 18 (upgraded from 15)
- Existing data (if any) will have v4 UUIDs mixed with v7

### Neutral

- UUID v7 is a standard (RFC 9562, published 2024)
- PostgreSQL 18 is stable and supported by TimescaleDB
