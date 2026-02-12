# Insight: Phased Development with Milestone Tags

**Discovered:** 2026-02-10
**Context:** Adding explicit tagging tasks to each phase checklist in PROJECT.md

## The Insight

Major development work — whether the initial platform build or future feature epics — should be broken into formal phases, each ending with coordinated milestone tags across all repos. The tagging task must be an explicit last item in each phase's checklist, not an implicit consequence of the tagging policy.

This applies beyond the current Phase 1–5 structure. Any future major feature or enhancement that spans multiple weeks or multiple repos should follow the same pattern:

1. **Break the work into phases** with clear deliverables
2. **Each phase gets a checklist** in PROJECT.md (or equivalent tracking)
3. **The last item in each checklist is the milestone tag** — naming all repos explicitly

## Why It Matters

Policies describe intent. Checklists drive execution.

ADR-0011 defines the tagging policy (format, rules, when to tag). But a policy in an ADR is something you consult *if you remember to*. A checkbox at the bottom of the active phase list is something you stare at every day until it's done.

Without the explicit task:
- Tags get forgotten because they happen after the "real work" is done
- Partial tagging happens — one repo gets tagged, the others don't
- Six months later, `git checkout phase-2-local-full-stack` works in `platform-services` but fails in `platform-infra`

With the explicit task:
- The phase isn't "complete" until the tag exists on all three repos
- The tag becomes a **gate** — it forces a moment of verification before moving on
- Cross-repo state is auditable at every phase boundary

## Example

Current PROJECT.md structure:

```markdown
### Phase 2: Local Full Stack
- [ ] Add Traefik to docker-compose (HTTP routing)
- [ ] Add EMQX to docker-compose (MQTT broker)
- [ ] ...
- [ ] Tag `phase-2-local-full-stack` on platform-services, platform-docs, platform-infra
```

Future feature epic (hypothetical):

```markdown
### DLQ Implementation
#### Phase 1: Schema and Storage
- [ ] DLQ table migration
- [ ] DLQ writer implementation
- [ ] Tag `dlq-phase-1-storage` on platform-services, platform-docs

#### Phase 2: Retry and Alerting
- [ ] Retry scheduler
- [ ] Alert integration
- [ ] Tag `dlq-phase-2-retry` on platform-services, platform-docs
```

## Related

- [ADR-0011: Coordinated Tagging Across Repos](../../decisions/0011-coordinated-tagging-across-repos.md) — The tagging policy this insight operationalizes
- [Task Documents as Design Specs](002-task-documents-as-design-specs.md) — Same principle: make invisible process steps visible through documentation structure
- [ai-builder-lessons/006](../../../ai-builder-lessons/lessons/006-explicit-milestone-tags-in-checklists.md) — Project-agnostic version of this insight
