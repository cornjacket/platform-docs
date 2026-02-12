# Insight: Centralize Insights in the Shared Docs Repo

**Discovered:** 2026-02-09
**Context:** When establishing the insights practice across a multi-repo workspace, the question arose whether each repo (platform-infra, platform-services, platform-docs) needed its own `insights/` folder.

## The Insight

When a shared documentation repo exists, centralize all insights there rather than creating `insights/` folders in every repo. Use category subdirectories (`architecture/`, `development/`, `testing/`, `infrastructure/`) to organize by topic. The spirit of the rule is "don't lose implementation knowledge" — not "every repo must have an insights folder."

## Why It Matters

- Avoids fragmenting the collection across repos — one place to search, one index to maintain
- platform-docs is already the source of truth for ADRs, design specs, and project status; insights belong alongside these
- Category subdirectories handle the organizational concern without repo-level duplication
- Cross-references between insights are simpler when they all live in the same tree

## Example

Instead of:
```
platform-infra/insights/001-vpc-sizing.md
platform-services/insights/001-consumer-rebalancing.md
platform-docs/insights/001-task-docs-as-specs.md
```

Centralize as:
```
platform-docs/insights/
  architecture/001-time-separation-of-concerns.md
  development/001-task-documents-as-design-specs.md
  infrastructure/001-vpc-sizing.md
```

## Related

- [ADR-0011](../../decisions/) — Tagging policy (another case of "avoid proliferation")
- [AI Builder Lesson 002](../../../ai-builder-lessons/lessons/002-project-insights-folder-complements-adrs.md) — The general lesson about insights vs ADRs
