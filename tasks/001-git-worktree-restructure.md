# Task 001: Transition to Git Worktree Structure

**Type:** Task
**Status:** Complete
**Created:** 2026-02-13

## Context

Reorganize the `cornjacket-platform/` workspace into a bare repository + worktree structure. This ensures path symmetry across all three repos, enabling parallel feature work and consistent AI context-sharing.

**This change assumes an AI-first workflow.** Decisions throughout this task (cross-repo path conventions, branch creation, workspace layout) assume that AI agents — not humans — will primarily be creating and modifying files and taking action within the multi-repo structure.

## Current State

```
cornjacket-platform/
├── platform-docs/          # standard clone
├── platform-infra/         # standard clone
├── platform-services/      # standard clone
├── CLAUDE.md → platform-docs/CLAUDE.md
└── GEMINI.md → platform-docs/CLAUDE.md
```

## Target State

```
cornjacket-platform/
├── .repos/                 # bare repos (hidden from AI indexing)
│   ├── docs.git
│   ├── infra.git
│   └── services.git
├── platform-docs/
│   ├── main/               # worktree: main branch
│   └── feature-x/          # worktree: feature branch
├── platform-infra/
│   ├── main/
│   └── feature-x/
├── platform-services/
│   ├── main/
│   └── feature-x/
├── create-feature.sh       # automation script
├── CLAUDE.md               # symlink (needs path update)
└── GEMINI.md               # symlink (needs path update)
```

## Action Plan

### 1. Backup and Initialization
- Create `.repos/` directory
- Identify all local branches and uncommitted changes in all three repos
- Push any unpushed commits to remote

### 2. Convert to Bare Repositories
For each repo (docs, infra, services):
- Move current repo to temporary backup
- Create bare clone: `git clone --bare <url> .repos/<repo>.git`
- **Configure fetch refspec** (bare clones strip this): `git -C .repos/<repo>.git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"`
- **Fetch remote tracking refs**: `git -C .repos/<repo>.git fetch origin`
- Verify bare repo has all branches and tags
- Delete temporary backup

### 3. Initialize Worktrees
For each bare repo:
- Create parent directory: `mkdir -p platform-<repo>`
- Add main worktree: `git -C .repos/<repo>.git worktree add ../../platform-<repo>/main main`
- **Set upstream tracking**: `git -C platform-<repo>/main branch --set-upstream-to=origin/main main`

### 4. Automation Scripts
Create `create-feature.sh` and `remove-feature.sh` in workspace root.

**Note:** Bare repo paths use `../../` for worktree targets because `git -C .repos/<repo>.git` sets the cwd two levels deep. `../../$TARGET_DIR` resolves back to the workspace root.

See the actual scripts at workspace root for current implementation.

### 5. Environment Cleanup
- Update CLAUDE.md and GEMINI.md symlinks to new paths
- Add a section to CLAUDE.md explaining the `{GIT_COMMON_BRANCH_NAME}` convention: AI agents must resolve this token to their current working branch, and all repos should be on the same branch during feature work

### 6. Document Feature Branch Workflow

Add a workflow section to CLAUDE.md (or README.md) describing how to create and work on feature branches:

```
## Feature Branch Workflow

1. Create feature worktrees across all repos:
   ./create-feature.sh feature-name

2. This creates:
   platform-docs/feature-name/
   platform-infra/feature-name/
   platform-services/feature-name/

3. Work in the feature worktrees. AI agents should operate within
   the same branch name across all repos.

4. When done, merge each repo's feature branch to main independently,
   then remove the worktrees:
   ./remove-feature.sh feature-name
```

## Constraints

- **No nested .git folders** — only `.repos/` contains git databases
- **Path pattern** — always `platform-<repo>/<branch>`

## Resolved Items

1. **CLAUDE.md symlink** — update to `CLAUDE.md → platform-docs/main/CLAUDE.md`. Main branch is the source of truth for AI agent instructions. Claude Code walks up the directory tree to find CLAUDE.md, so the root symlink is loaded regardless of which worktree Claude is invoked from. GEMINI.md follows the same pattern.

2. **Cross-repo relative paths** — update all cross-repo markdown links to use `{GIT_COMMON_BRANCH_NAME}` in the path (e.g., `../../platform-services/{GIT_COMMON_BRANCH_NAME}/DEVELOPMENT.md`). This serves two purposes: (a) tells AI agents to resolve the path using their current branch, and (b) reinforces that all repos should be on the same branch during feature work. These links are for AI navigation, not human browsing.

3. **`create-feature.sh` atomic creation** — script always creates new branches (`-b`) from main across all three repos. If any repo fails, all previously created worktrees and branches are rolled back. This is for AI-driven parallel feature work, not for sharing remote branches.

4. **Bare repo fetch refspec** — `git clone --bare` strips `remote.origin.fetch`, so bare repos can't fetch or track remote branches. Must configure the refspec and fetch after cloning, then set upstream tracking on the `main` worktree. This is a one-time setup step, not per-branch.

## Verification

- All three repos have `main/` worktrees with clean `git status`
- `create-feature.sh feature-1` creates symmetric worktrees across all repos
- Existing tests pass from within `platform-services/main/`
- CLAUDE.md symlink resolves correctly
