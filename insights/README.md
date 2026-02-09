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
| [Documentation Placement](development/002-documentation-placement.md) | Development | Place docs based on what question they answer (why/how/what) |
| [Time Separation of Concerns](architecture/001-time-separation-of-concerns.md) | Architecture | EventTime (caller) vs IngestedAt (platform) — clear ownership |
| [Clock as Dependency Injection](architecture/002-clock-as-dependency-injection.md) | Architecture | Time is an input, not a side effect — enables testing and replay |
| [Static vs Dynamic Documentation](development/003-static-vs-dynamic-documentation.md) | Development | Document the strategy, not the status — coverage commands yes, coverage files no |
| [Centralize Insights in Shared Docs Repo](development/004-centralize-insights-in-shared-docs-repo.md) | Development | Use platform-docs as single source of truth for all insights across repos |
