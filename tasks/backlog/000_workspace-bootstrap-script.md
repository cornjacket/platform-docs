# Workspace Bootstrap Script for New Users

**Type:** Task
**Status:** Backlog
**Created:** 2026-02-13

## Context

There is no automated way to set up the `cornjacket-platform/` workspace from scratch. A new user must manually clone repos, create symlinks, and know the repo relationships. The upcoming worktree restructure will make this more complex.

## Requirements

Create a `bootstrap.sh` (or similar) script that:

1. Creates the `cornjacket-platform/` directory structure
2. Clones all repos (platform-docs, platform-infra, platform-services, ai-builder-lessons)
3. Sets up CLAUDE.md and GEMINI.md symlinks
4. Prints next steps (e.g., `make skeleton-up`)

After the worktree restructure (Task 001), this script should also:
- Create `.repos/` with bare clones
- Initialize `main/` worktrees for each repo
- Make `create-feature.sh` executable

## Notes

- Should be idempotent (safe to re-run)
- Keep it as a simple shell script — no external dependencies
