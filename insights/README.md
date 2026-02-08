# Insights

This directory captures patterns, learnings, and principles discovered during development. Unlike ADRs (which document decisions), insights document **wisdom gained** — things we learned that improve how we work.

## Categories

| Category | Description |
|----------|-------------|
| `development/` | Development practices, tooling, workflow |
| `architecture/` | System design patterns, trade-offs |
| `testing/` | Testing strategies, test design |

## Format

Each insight file follows this structure:

```markdown
# Insight: [Title]

**Discovered:** YYYY-MM-DD
**Context:** [What we were doing when we learned this]

## The Insight

[Clear statement of the learning]

## Why It Matters

[Impact on the project]

## Example

[Concrete example demonstrating the insight]

## Related

- [Links to related ADRs, tasks, or other insights]
```

## Index

| Insight | Category | Summary |
|---------|----------|---------|
| [Task Documents as Design Specs](development/001-task-documents-as-design-specs.md) | Development | Write task docs before implementation to estimate scope and identify breaking changes |
