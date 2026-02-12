# Insight: Documentation Placement

**Discovered:** 2026-02-07
**Context:** Deciding where to document the component testing insight after Task 007

## The Insight

Different documents serve different purposes. Place documentation based on what question it answers:

| Document | Question It Answers | Content Type |
|----------|---------------------|--------------|
| **ARCHITECTURE.md** | "Why is it structured this way?" | Principles, patterns, trade-offs |
| **DEVELOPMENT.md** | "How do I do X?" | Commands, workflows, conventions |
| **Task documents** | "What was implemented?" | Scope, decisions, history |
| **ADRs** | "Why did we decide X?" | Context, options, rationale |
| **Insights** | "What did we learn?" | Patterns, wisdom, templates |
| **design-spec.md** | "What are the parameters?" | Operational details, limits, config |

## Why It Matters

Misplaced documentation:
- Gets lost (nobody looks there)
- Creates duplication (same info in multiple places)
- Becomes stale (updated in one place, not others)

Well-placed documentation:
- Found when needed
- Single source of truth
- Updated naturally as part of workflow

## Example

When we added the component testing section, we considered:

| Option | Why Not |
|--------|---------|
| DEVELOPMENT.md | That's for "how to run tests", not "why architecture enables testing" |
| Task 007 | Good for history, but task docs aren't reference material |
| **ARCHITECTURE.md** | ✅ Explains the *payoff* of following the architecture |

The insight connects architecture (dependency inversion) to benefit (testability) — that's an ARCHITECTURE.md topic.

## Decision Tree

```
Is it about WHY we made a choice?
  └─ Yes → ADR (if significant) or ARCHITECTURE.md (if pattern)
  └─ No ↓

Is it about HOW to do something?
  └─ Yes → DEVELOPMENT.md
  └─ No ↓

Is it about WHAT we implemented?
  └─ Yes → Task document
  └─ No ↓

Is it about WHAT we learned?
  └─ Yes → Insights
  └─ No ↓

Is it about operational PARAMETERS?
  └─ Yes → design-spec.md
```

## Related

- [ARCHITECTURE.md](../../../platform-services/ARCHITECTURE.md)
- [DEVELOPMENT.md](../../../platform-services/DEVELOPMENT.md)
- [Task Documents](../../../platform-services/tasks/README.md)
- [ADRs](../../decisions/)
