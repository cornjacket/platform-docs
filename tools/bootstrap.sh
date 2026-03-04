#!/bin/bash
set -e

WORKSPACE_NAME="${1:-cornjacket-platform}"
GITHUB_ORG="https://github.com/cornjacket"
REPOS=("docs" "infra" "services")

# Determine where the script was invoked from
INVOKE_DIR="$(pwd)"
WORKSPACE_DIR="${INVOKE_DIR}/${WORKSPACE_NAME}"

if [ -d "$WORKSPACE_DIR" ]; then
    echo "Error: Directory '$WORKSPACE_DIR' already exists."
    echo "Remove it first or choose a different name."
    exit 1
fi

echo "=== Creating workspace: $WORKSPACE_NAME ==="
mkdir -p "${WORKSPACE_DIR}/.repos"

# Step 1: Create bare clones
for repo in "${REPOS[@]}"; do
    echo ""
    echo "--- Cloning platform-${repo} (bare) ---"
    git clone --bare "${GITHUB_ORG}/platform-${repo}.git" "${WORKSPACE_DIR}/.repos/${repo}.git"

    # Configure fetch refspec (bare clones strip this)
    git -C "${WORKSPACE_DIR}/.repos/${repo}.git" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git -C "${WORKSPACE_DIR}/.repos/${repo}.git" fetch origin
done

# Step 2: Create main worktrees
for repo in "${REPOS[@]}"; do
    echo ""
    echo "--- Creating worktree: platform-${repo}/main ---"
    mkdir -p "${WORKSPACE_DIR}/platform-${repo}"
    git -C "${WORKSPACE_DIR}/.repos/${repo}.git" worktree add "${WORKSPACE_DIR}/platform-${repo}/main" main

    # Set upstream tracking
    git -C "${WORKSPACE_DIR}/platform-${repo}/main" branch --set-upstream-to=origin/main main
done

# Step 3: Symlink workspace scripts
echo ""
echo "--- Setting up symlinks ---"
ln -s platform-docs/main/tools/create-feature.sh "${WORKSPACE_DIR}/create-feature.sh"
ln -s platform-docs/main/tools/remove-feature.sh "${WORKSPACE_DIR}/remove-feature.sh"

# Step 4: Symlink AI agent config files
ln -s platform-docs/main/CLAUDE.md "${WORKSPACE_DIR}/CLAUDE.md"
ln -s platform-docs/main/CLAUDE.md "${WORKSPACE_DIR}/GEMINI.md"

# Step 5: Clean up the temporary platform-docs clone (if it exists next to us)
TEMP_CLONE="${INVOKE_DIR}/platform-docs"
if [ -d "$TEMP_CLONE/.git" ] && [ "$TEMP_CLONE" != "${WORKSPACE_DIR}/platform-docs" ]; then
    echo ""
    echo "--- Removing temporary platform-docs clone ---"
    rm -rf "$TEMP_CLONE"
fi

echo ""
echo "=== Workspace '$WORKSPACE_NAME' created ==="
echo ""
echo "Structure:"
echo "  ${WORKSPACE_NAME}/"
echo "  ├── .repos/           (bare repos)"
echo "  ├── platform-docs/main/"
echo "  ├── platform-infra/main/"
echo "  ├── platform-services/main/"
echo "  ├── create-feature.sh (symlink)"
echo "  ├── remove-feature.sh (symlink)"
echo "  ├── CLAUDE.md         (symlink)"
echo "  └── GEMINI.md         (symlink)"
echo ""
echo "Next steps:"
echo "  cd ${WORKSPACE_NAME}"
echo "  cd platform-services/main && make skeleton-up"
