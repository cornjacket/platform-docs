# Insight: Task Documents as Design Specs

**Discovered:** 2026-02-07
**Context:** Creating Task 008 (Time Handling Strategy) and listing all affected files before implementation

## The Insight

Task documents serve as **design specs before implementation**. By listing all affected files upfront, you can:

1. **Estimate scope accurately** — See the full blast radius before writing code
2. **Identify breaking changes** — API changes, database migrations, client updates
3. **Plan implementation order** — Migrations before code, interfaces before implementations
4. **Ensure documentation stays in sync** — ADRs, specs, and code change together

## Why It Matters

Without upfront file listing:
- Scope creep sneaks in mid-implementation
- Breaking changes surprise you late
- Documentation drifts from reality
- Reviews become "did you update X?" checklists

With upfront file listing:
- Clear contract before coding starts
- Breaking changes are visible in the design phase
- Documentation is part of the task, not an afterthought
- Reviews focus on correctness, not completeness

## Example

Task 008 listed files before any code was written:

```markdown
## Files to Create/Modify

### Create
| File | Description |
|------|-------------|
| `internal/shared/domain/clock/clock.go` | Clock interface |

### Modify
| File | Changes |
|------|---------|
| `internal/shared/domain/events/envelope.go` | Add EventTime, rename Timestamp |
| `internal/services/ingestion/handler.go` | Parse event_time from request |
| `api/openapi/ingestion.yaml` | Add event_time field |

### Database Migrations
| File | Changes |
|------|---------|
| `migrations/003_rename_timestamp.sql` | Schema update |
```

This revealed:
- API change (breaking for clients)
- Database migration required
- 7+ files affected
- Documentation updates needed (ADR, design-spec, OpenAPI)

All visible **before writing a single line of code**.

## Template

When creating task documents, include:

```markdown
## Files to Create/Modify

### Create
| File | Description |
|------|-------------|

### Modify
| File | Changes |
|------|---------|

### Delete
| File | Reason |
|------|--------|

### Database Migrations
| File | Changes |
|------|---------|

### Documentation Updates
| Document | Updates |
|----------|---------|
```

## Related

- [Task Document Template](../../../platform-services/tasks/README.md)
- [Task 008: Time Handling Strategy](../../../platform-services/tasks/008-time-handling-strategy.md) — Example of this pattern
