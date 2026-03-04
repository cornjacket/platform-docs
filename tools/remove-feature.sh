#!/bin/bash
BRANCH_NAME=$1
if [ -z "$BRANCH_NAME" ]; then
    echo "Error: Please provide a branch name."
    exit 1
fi

if [ "$BRANCH_NAME" = "main" ]; then
    echo "Error: Cannot remove the main worktree."
    exit 1
fi

REPOS=("docs" "infra" "services")
ERRORS=0

for repo in "${REPOS[@]}"; do
    BARE_REPO=".repos/${repo}.git"
    TARGET_DIR="platform-${repo}/${BRANCH_NAME}"
    echo "Processing $repo..."
    if [ ! -d "$TARGET_DIR" ]; then
        echo "  [Skip] $TARGET_DIR does not exist."
        continue
    fi
    # Attempt worktree removal (without --force).
    # git worktree remove refuses if there are uncommitted changes,
    # which prevents accidental loss of in-progress work.
    if ! git -C "$BARE_REPO" worktree remove "../../$TARGET_DIR" 2>&1; then
        echo "  [Error] Worktree has uncommitted changes. Commit or stash first."
        ERRORS=$((ERRORS + 1))
        continue
    fi
    echo "  [OK] Worktree removed."

    # Delete the local branch now that the worktree is gone.
    # -D (force delete) is safe here — the worktree is already removed,
    # so the branch is just a dangling ref. -d would fail if unmerged.
    if git -C "$BARE_REPO" branch -D "$BRANCH_NAME" 2>/dev/null; then
        echo "  [OK] Branch deleted."
    else
        echo "  [Warn] Branch '$BRANCH_NAME' not found (may have been deleted already)."
    fi
done

if [ "$ERRORS" -gt 0 ]; then
    echo "Completed with $ERRORS error(s). Check output above."
    exit 1
fi

echo "Feature '$BRANCH_NAME' removed across all repos."
