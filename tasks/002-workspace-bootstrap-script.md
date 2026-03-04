# Task 002: Workspace Bootstrap Script

**Type:** Task
**Status:** Complete
**Created:** 2026-02-13

## Context

There is no automated way to set up the workspace from scratch. The workspace uses bare repos with git worktrees, which requires a multi-step setup process.

## Bootstrap Flow

The bootstrap is a two-phase process:

1. **Temporary clone** — user clones `platform-docs` to get the script
2. **Run bootstrap** — script builds the full worktree workspace (including a proper `platform-docs/main/` worktree)
3. **Self-cleanup** — script deletes the temporary `platform-docs` clone since the worktree version replaces it

```bash
git clone https://github.com/cornjacket/platform-docs.git
platform-docs/tools/bootstrap.sh [workspace-name]
# Temporary platform-docs/ is deleted; workspace-name/ contains everything
```

## Requirements

Create `platform-docs/tools/bootstrap.sh` that:

1. Accepts an optional root directory name (default: `cornjacket-platform`)
2. Creates the root directory structure
3. Creates `.repos/` with bare clones of all repos (platform-docs, platform-infra, platform-services)
4. Configures fetch refspec on each bare repo: `git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"`
5. Fetches remote tracking refs: `git fetch origin`
6. Initializes `main/` worktrees for each repo
7. Sets upstream tracking on each `main` worktree: `git branch --set-upstream-to=origin/main main`
8. Symlinks workspace scripts from `platform-docs/main/tools/` to workspace root (`create-feature.sh`, `remove-feature.sh`)
9. Sets up `CLAUDE.md` and `GEMINI.md` symlinks
10. Deletes the temporary `platform-docs` clone (the one used to run the script)
11. Prints next steps

## Constraints

- Should be idempotent (safe to re-run)
- Keep it as a simple shell script — no external dependencies
- Script lives in `platform-docs/tools/` (version-controlled)
