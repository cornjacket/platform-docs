# Task 002: Workspace Bootstrap Script

**Type:** Task
**Status:** Pending
**Created:** 2026-02-13

## Context

There is no automated way to set up the workspace from scratch. A new user must manually clone repos, create bare repos, configure worktrees, and set up symlinks.

## Requirements

Create `platform-docs/tools/bootstrap.sh` that:

1. Accepts an optional root directory name (default: `cornjacket-platform`)
2. Creates the root directory structure
3. Creates `.repos/` with bare clones of all repos (platform-docs, platform-infra, platform-services)
4. Configures fetch refspec on each bare repo: `git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"`
5. Fetches remote tracking refs: `git fetch origin`
6. Initializes `main/` worktrees for each repo
7. Sets upstream tracking on each `main` worktree: `git branch --set-upstream-to=origin/main main`
8. Clones `ai-builder-lessons` (standard clone, not a worktree repo)
9. Symlinks workspace scripts from `platform-docs/main/tools/` to workspace root (`create-feature.sh`, `remove-feature.sh`)
10. Sets up `CLAUDE.md` and `GEMINI.md` symlinks
11. Prints next steps

## Constraints

- Should be idempotent (safe to re-run)
- Keep it as a simple shell script — no external dependencies
- Script lives in `platform-docs/tools/` (version-controlled)
