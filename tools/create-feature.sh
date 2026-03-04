#!/bin/bash
BRANCH_NAME=$1
if [ -z "$BRANCH_NAME" ]; then
    echo "Error: Please provide a branch name."
    exit 1
fi

REPOS=("docs" "infra" "services")
CREATED=()

for repo in "${REPOS[@]}"; do
    BARE_REPO=".repos/${repo}.git"
    TARGET_DIR="platform-${repo}/${BRANCH_NAME}"
    echo "Processing $repo..."
    if [ -d "$TARGET_DIR" ]; then
        echo "  [Error] Directory $TARGET_DIR already exists."
        for created_repo in "${CREATED[@]}"; do
            ROLLBACK_DIR="platform-${created_repo}/${BRANCH_NAME}"
            echo "  [Rollback] Removing $ROLLBACK_DIR"
            git -C ".repos/${created_repo}.git" worktree remove "../../$ROLLBACK_DIR" --force
            git -C ".repos/${created_repo}.git" branch -D "$BRANCH_NAME" 2>/dev/null
        done
        echo "All branches rolled back. No worktrees created."
        exit 1
    fi
    if ! git -C "$BARE_REPO" worktree add "../../$TARGET_DIR" -b "$BRANCH_NAME" main; then
        echo "  [Error] Failed to create worktree for $repo."
        for created_repo in "${CREATED[@]}"; do
            ROLLBACK_DIR="platform-${created_repo}/${BRANCH_NAME}"
            echo "  [Rollback] Removing $ROLLBACK_DIR"
            git -C ".repos/${created_repo}.git" worktree remove "../../$ROLLBACK_DIR" --force
            git -C ".repos/${created_repo}.git" branch -D "$BRANCH_NAME" 2>/dev/null
        done
        echo "All branches rolled back. No worktrees created."
        exit 1
    fi
    CREATED+=("$repo")
done

echo "Feature '$BRANCH_NAME' created across all repos."
