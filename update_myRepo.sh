#!/bin/bash

# Configuration: Strict mode for robustness
set -e  # Exit immediately if a command fails
set -u  # Exit immediately if an unset variable is used

# Global Variables
CURRENT_BRANCH=""
COMMIT_MSG=""

# Define the editor to be used. Prioritizes $EDITOR, but uses 'vi' as fallback.
: ${EDITOR:=vi}

# --- Utility Functions ---

print_header() {
    echo "=========================================="
    echo "=== Commit ALL Local Changes (Main Repo) ==="
    echo "=========================================="
    echo
}

# NOTE: Removed all submodule/sub-repo specific functions.
# nuttx/ and apps/ are now treated as regular tracked directories.

generate_commit_message() {
    local DATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    local TEMP_FILE=$(mktemp)

    # Initial content for the commit file
    cat > "$TEMP_FILE" <<- EOM
Feat/Fix: Describe changes in main repo, nuttx, or apps

# ------------------------
# Enter your commit message above. Lines starting with '#' will be ignored.
# The first line is the subject (max 50 chars), separated by a blank line from the body.
# Timestamp: $DATE_TIME
EOM

    # Open the editor (vi/nano/etc.)
    "$EDITOR" "$TEMP_FILE"

    # Read the final message, ignoring comments (tr '\n' '\t' handles multi-line body)
    COMMIT_MSG=$(grep -v '^\s*#' "$TEMP_FILE" | sed '/^\s*$/d' | tr '\n' '\t' | sed 's/\t$//')
    rm "$TEMP_FILE"

    if [ -z "$COMMIT_MSG" ]; then
        echo "FATAL: Commit message is empty. Aborting commit."
        exit 1
    fi
}

perform_commit() {
    # Commit staged changes using the generated message
    echo "Performing commit on $CURRENT_BRANCH..."
    # Replace tabs with newlines for the commit message format
    COMMIT_MSG_FORMATTED=$(echo "$COMMIT_MSG" | tr '\t' '\n')
    git commit -m "$COMMIT_MSG_FORMATTED" || { echo "FATAL: Git commit failed."; exit 1; }
    echo "Commit successful."
}

pull_and_push() {
    local PUSH_CONFIRM=""
    read -p "Do you want to PULL (rebase) and then PUSH to origin/$CURRENT_BRANCH? (y/N): " PUSH_CONFIRM
    
    if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Pulling latest changes with rebase..."
        git pull --rebase origin "$CURRENT_BRANCH" || { echo "FATAL: Failed to pull/rebase. Fix conflicts and run the script again."; exit 1; }

        echo "Pushing commit to origin/$CURRENT_BRANCH..."
        git push origin "$CURRENT_BRANCH" || { echo "FATAL: Failed to push to origin/$CURRENT_BRANCH."; exit 1; }
        echo "Push successful."
    else
        echo "Commit saved locally. Skipping pull/push."
    fi
}

# --- Main Execution ---
main() {
    print_header

    # Determines the current branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    # 1. Faz o stage de TODAS as alterações, em todos os diretórios.
    echo "Staging all changes (including nuttx/ and apps/)..."
    # NOTE: This is the critical line. It stages everything for the main repo.
    git add -A || { echo "FATAL: Failed to stage changes."; exit 1; }

    # 2. Verifica se há algo para comitar
    if git diff --cached --quiet; then
        echo "No changes staged. Nothing to commit."
    else
        generate_commit_message
        perform_commit
        pull_and_push
    fi
    
    echo "Script finished."
}

# Call main function
main
