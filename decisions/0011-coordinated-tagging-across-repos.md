# ADR 0011: Coordinated Tagging Across Repos

* **Status:** Accepted
* **Date:** 2026-02-04
* **Architect:** David

## Context

The Cornjacket platform uses a polyrepo structure with three separate Git repositories:
- `platform-infra` — Infrastructure (Terraform)
- `platform-services` — Application code (Go, Python)
- `platform-docs` — Documentation and ADRs

When debugging issues or reproducing a specific state, it's crucial to know which versions of each repo were deployed together. Without coordination, it's difficult to answer "what was the state of the system at point X?"

## Decision

**Use coordinated Git tags across all three repositories to mark milestones and releases.**

### Tag Format

| Tag Type | Format | Example | Use Case |
|----------|--------|---------|----------|
| Milestone | `milestone-NNN-description` | `milestone-001-phase1-ingestion` | Development checkpoints |
| Release | `vX.Y.Z` | `v0.1.0` | Production releases |

### Rules

1. **Same tag, all repos:** When creating a milestone or release, apply the identical tag to all three repos
2. **Atomic tagging:** Tag all repos in a single session to avoid drift
3. **Tag message:** Include a brief description of what the milestone represents
4. **Never move tags:** Tags are immutable; create a new tag if needed

### When to Create Milestones

- End of a development phase (e.g., Phase 1 complete)
- Before significant architectural changes
- After completing a major feature
- Before deploying to a new environment
- Any point you might want to return to

## Rationale

**Debugging:** When investigating an issue, checkout the same tag across all repos to reproduce the exact system state.

**Reproducibility:** Any milestone can be fully recreated by checking out the coordinated tag in each repo.

**Alignment:** Ensures docs, infrastructure, and application code are always in sync at known points.

**Simplicity:** Git tags are lightweight and don't require additional tooling or version manifest files.

## Consequences

### Benefits
- Easy to reproduce any milestone state across all repos
- Clear alignment between docs, infra, and services
- Simple debugging: "checkout milestone-005 in all repos"
- No additional tooling required

### Trade-offs
- Manual process (must remember to tag all three repos)
- Tags can diverge if process isn't followed
- No automated enforcement

### Mitigations
- Document the process in PROJECT.md
- Add reminder to CLAUDE.md for AI-assisted development
- Consider automation script if manual process becomes error-prone

## Related ADRs
- ADR-0008: CI/CD Pipeline Strategy (future: automated tagging on release)
