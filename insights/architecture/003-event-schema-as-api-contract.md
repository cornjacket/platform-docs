# Insight: Event Schema as API Contract

**Discovered:** 2026-02-09
**Context:** Reviewing whether `Metadata` fields needed formal documentation beyond Go struct comments

## The Insight

**In event-driven systems, the event struct IS the API contract.**

HTTP APIs have OpenAPI specs as a separate contract definition. For events, the Go struct + JSON tags serve that role. When there's a single producer and the schema is stable, documenting it separately creates drift risk — two sources of truth that can diverge.

## Why It Matters

The current `Envelope` and `Metadata` structs are the single source of truth for the event schema. Every field, its JSON serialization name, and its optionality (`omitempty`) are defined in one place. Consumers (Event Handler, projections) import the same type — compile-time enforcement, zero ambiguity.

This works because:
- One producer (Ingestion Service)
- One schema version (`SchemaVersion: 1`)
- One source value (`"ingestion-api"`)

## When This Breaks

Formalize the event schema (event catalog, schema registry, or even a markdown spec) when any of these triggers occur:

| Trigger | Why It Matters |
|---------|---------------|
| Multiple producers (MQTT path, Action Orchestrator) | `Source` field gets multiple values — need to document valid values |
| `SchemaVersion` increments beyond 1 | Consumers need to know how to handle version differences |
| External consumers | They can't import Go types — need a language-neutral contract |
| Payload structure varies by event type | `json.RawMessage` hides the actual schema — each event type needs its own spec |

## The Principle

**Document contracts at the point they become ambiguous.** A single-producer system with one Go type is unambiguous by construction. A multi-producer system with schema evolution is not.

## Related

- [Insight: Time Separation of Concerns](001-time-separation-of-concerns.md) — EventTime vs IngestedAt ownership in the Envelope
- [ADR-0001: Event-Driven CQRS Architecture](../../decisions/0001-event-driven-cqrs-architecture.md)
