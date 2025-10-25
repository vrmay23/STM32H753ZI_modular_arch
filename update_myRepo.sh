#!/bin/bash

# Configuration: Strict mode for robustness
set -e  # Exit immediately if a command fails
set -u  # Exit immediately if an unset variable is used

# Global Variables
CURRENT_BRANCH=""
NUTTX_HASH="N/A"
APPS_HASH="N/A"
COMMIT_MSG=""

# --- Utility Functions ---

print_header() {
    echo "==========================================="
    echo "=== Commit and Push All Local Changes ===="
    echo "==========================================="
    echo
}

get_submodule_hashes() {
    # Captures the short-hashes of the submodules. If fails (e.g., directory doesn't exist), returns 'N/A'.
    NUTTX_HASH=$(cd nuttx && git rev-parse --short HEAD 2>/dev/null || echo "N/A")
    APPS_HASH=$(cd apps && git rev-parse --short HEAD 2>/dev/null || echo "N/A")
}

generate_commit_message() {
    local USER_MSG=""
    read -p "Add extra commit message (optional): " USER_MSG

    COMMIT_MSG="Update submodules: nuttx@$NUTTX_HASH apps@$APPS_HASH on $(date '+%Y-%m-%d %H:%M:%S')"
    if [ -n "$USER_MSG" ]; then
        COMMIT_MSG="$COMMIT_MSG - $USER_MSG"
    fi
}

perform_commit() {
    echo "Adding all changes..."
    git add -A || { echo "FATAL: Failed to stage changes."; exit 1; }

    if git diff --cached --quiet; then
        echo "No changes to commit. Working tree is clean."
    else
        git commit -m "$COMMIT_MSG" || { echo "FATAL: Failed to commit changes."; exit 1; }
    fi
}

pull_and_push() {
    local REMOTE_BRANCH="origin/$CURRENT_BRANCH"

    # Checks if the branch exists on the remote
    if git ls-remote --heads origin "$CURRENT_BRANCH" | grep -q "$CURRENT_BRANCH"; then
        echo "Pulling latest changes from $REMOTE_BRANCH with rebase (ensuring linear history)..."
        # Pulls and rebases to maintain linear history
        git pull --rebase origin "$CURRENT_BRANCH" || { echo "FATAL: Git rebase failed or conflicts on $CURRENT_BRANCH. Fix manually."; exit 1; }

        echo "Pushing current branch..."
        git push origin "$CURRENT_BRANCH" || { echo "FATAL: Failed to push changes."; exit 1; }
    else
        echo "Branch $CURRENT_BRANCH not found on remote. Performing first push..."
        git push -u origin "$CURRENT_BRANCH" || { echo "FATAL: Failed initial push."; exit 1; }
    fi
}

sync_main() {
    local SYNC_MAIN=""
    read -p "Do you want to update local main from remote? (y/N): " SYNC_MAIN
    
    if [[ "$SYNC_MAIN" =~ ^[Yy]$ ]]; then
        echo "Switching to main branch..."
        git checkout main || { echo "FATAL: Failed to checkout main."; exit 1; }

        echo "Pulling latest main from origin/main with rebase (ensuring linear history)..."
        # Pulls and rebases main to guarantee linearity
        git pull --rebase origin main || { echo "FATAL: Failed to pull/rebase origin/main. Fix before switching back."; exit 1; }

        echo "Main updated successfully."

        echo "Switching back to $CURRENT_BRANCH..."
        git checkout "$CURRENT_BRANCH" || { echo "FATAL: Failed to switch back to $CURRENT_BRANCH. Check your working tree state."; exit 1; }
    fi
}

# --- Main Execution ---
main() {
    print_header

    # Determines the current branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    get_submodule_hashes
    generate_commit_message
    perform_commit
    pull_and_push
    sync_main

    echo
    echo "All operations completed."
}

# Start execution
main
