#!/bin/bash
# ------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2025-10-24
# Script: git-delete-obsolete-branch.sh
# Description:
#   Manages deletion of local Git branches that no longer have 
#   corresponding remote tracking branches (gone branches).
#
#   Steps:
#     1. Fetches the latest remote branch information
#     2. Identifies branches with 'gone' remote tracking status
#     3. Lists found obsolete branches
#     4. Handles deletion based on specified mode:
#        - Interactive (default)
#        - Dry run
#        - Force delete
#
# Options:
#    --dry   Show branches that would be deleted without actually deleting
#    --yes   Delete branches without confirmation
#    -h      Show this help message
#
# Usage:
#   ./git-detele-obsolete-branch.sh              # Interactive mode
#   ./git-detele-obsolete-branch.sh --dry        # Show branches only
#   ./git-detele-obsolete-branch.sh --yes        # Delete without confirmation
#
# Notes:
#   - Requires git to be installed and configured
#   - Must be run from within a git repository
#   - Only deletes branches that can be safely deleted
# ------------------------------------------------

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
DRY_RUN=false
FORCE_DELETE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry)
            DRY_RUN=true
            shift
            ;;
        --yes)
            FORCE_DELETE=true
            shift
            ;;
        -h|--help)
            usage_helper
            exit 1
            ;;
        *)
            echo "Error: Unknown option $1"
            usage_helper
            exit 1
            ;;
    esac
done

# Get list of branches with gone remotes
git fetch --prune
OBSOLETE_BRANCHES=$(git branch -vv | grep ': gone]' | awk '{print $1}')

if [ -z "$OBSOLETE_BRANCHES" ]; then
    echo "No obsolete branches found."
    exit 0
fi

# Function to delete a branch
delete_branch() {
    local branch=$1
    git branch -d "$branch"
    if [ $? -eq 0 ]; then
        echo "Deleted branch: $branch"
    else
        echo "Failed to delete branch: $branch"
    fi
}

# Process branches based on options
echo "Found obsolete branches:"
echo "$OBSOLETE_BRANCHES" | sed 's/^/  /'

if [ "$DRY_RUN" = true ]; then
    echo "Dry run - no branches were deleted"
    exit 0
fi

if [ "$FORCE_DELETE" = true ]; then
    echo "Deleting branches..."
    echo "$OBSOLETE_BRANCHES" | while read -r branch; do
        delete_branch "$branch"
    done
    exit 0
fi

# Interactive mode
echo "$OBSOLETE_BRANCHES"

for branch in $OBSOLETE_BRANCHES; do
    read -p "Delete branch '$branch'? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            delete_branch "$branch"
            ;;
        *)
            echo "Skipping branch: $branch"
            ;;
    esac
done
