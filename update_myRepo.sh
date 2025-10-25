#!/bin/bash

# Configuration: Strict mode for robustness
set -e  # Exit immediately if a command fails
set -u  # Exit immediately if an unset variable is used

# Global Variables
CURRENT_BRANCH=""
NUTTX_HASH="N/A"
APPS_HASH="N/A"
COMMIT_MSG=""

# Define the editor to be used. Prioritizes $EDITOR, but uses 'vi' as fallback.
: ${EDITOR:=vi}

# --- Utility Functions ---

print_header() {
    echo "==========================================="
    echo "=== Commit and Push All Local Changes ===="
    echo "==========================================="
    echo
}

get_submodule_hashes() {
    # Captures the short-hashes of the submodules. If fails, returns 'N/A'.
    NUTTX_HASH=$(cd nuttx && git rev-parse --short HEAD 2>/dev/null || echo "N/A")
    APPS_HASH=$(cd apps && git rev-parse --short HEAD 2>/dev/null || echo "N/A")
}

generate_commit_message() {
    local DATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    local TEMP_FILE=$(mktemp)

    # Initial content for the commit file
    cat > "$TEMP_FILE" <<- EOM
Update submodules: nuttx@$NUTTX_HASH apps@$APPS_HASH on $DATE_TIME

# ------------------------
# Enter your commit message above. Lines starting with '#' will be ignored.
# The first line is the subject (max 50 chars), separated by a blank line from the body.
EOM

    # Open the editor (vi/EDITOR) with the temporary file
    echo "Opening $EDITOR for commit message..."
    # Loop to ensure the user saves a non-empty message
    while true; do
        "$EDITOR" "$TEMP_FILE"

        # Filter out comments and clean up whitespace, keeping only valid message content
        COMMIT_MSG=$(grep -v '^\s*#' "$TEMP_FILE" | sed '/^\s*$/d')

        if [ -n "$COMMIT_MSG" ]; then
            break # Exit loop if message is not empty
        else
            echo "ERROR: Commit message is empty. Please enter a message or close the editor to abort (Ctrl+C)."
        fi
    done

    # Clean up the temporary file
    rm "$TEMP_FILE"
}

perform_commit() {
    if git diff --cached --quiet; then
        echo "No changes staged. Nothing to commit."
    else
        # Pass the full message content from the temporary file for the commit
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
    
    # Stage changes first so the user can review them while writing the message
    echo "Staging all changes before prompting for message..."
    git add -A || { echo "FATAL: Failed to stage changes."; exit 1; }

    if git diff --cached --quiet; then
        echo "No changes staged. Nothing to commit."
    else
        generate_commit_message
        perform_commit
        pull_and_push
    fi

    sync_main

    echo
    echo "All operations completed."
}

# Start execution
main
