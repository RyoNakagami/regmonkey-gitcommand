#!/bin/bash
# -----------------------------------------------------------------------------
# Author: RyoNakagami
# Revised: 2025-12-05
# Script: git-delete-remote-branch.sh
# Description:
#   Deletes a specified remote Git branch, with optional deletion of the
#   corresponding local branch. Supports dry-run mode for safe preview.
#
#   Steps:
#     1. Parse command-line arguments for branch, remote, dry-run, and local options.
#     2. Validate input and check for branch existence on remote (and local if requested).
#     3. Delete the remote branch (and local branch if specified), or show actions in dry-run.
#
# Options:
#    --remote <name>    Specify remote name (default: origin)
#    --dry              Perform a dry run (no actual deletion)
#    --with-local       Also delete the local branch
#    -h, --help         Show this help message
#
# Usage:
#   ./git-delete-remote-branch.sh <branch> [--remote <name>] [--dry] [--with-local]
#     # Deletes the specified remote branch (and local branch if --with-local)
#
# Notes:
#   - Requires git installed.
#   - Requires access to the specified remote repository.
#   - Requires the branch to exist on the remote (and local if --with-local).
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- function ----
delete_branch() {
    
    local branch=$1
    local remote=$2
    local dry_run=$3
    local with_local=$4

    echo "🚀 Executing deletion: branch=${branch}, remote=${remote}, dry_run=${dry_run}, local=${with_local}"
    
    # ---- Remote delete ----
    if $dry_run; then
        echo "[Dry Run] Would delete remote branch: $remote/$branch"
    else
        git push "$remote" --delete "$branch"
        if [ $? -eq 0 ]; then
            echo "Deleted remote branch: $remote/$branch"
        else
            echo "Failed to delete remote branch: $remote/$branch"
            return 1
        fi
    fi

    # ---- Local delete ----
    if $with_local; then
        if $dry_run; then
            echo "[Dry Run] Would delete local branch: $branch"
        else
            git branch -D "$branch"
            if [ $? -eq 0 ]; then
                echo "Deleted local branch: $branch"
            else
                echo "Failed to delete local branch: $branch"
                return 1
            fi
        fi
    fi
    return 0
}

# ---- Process command line arguments ----
BRANCH=""
REMOTE_NAME="origin"
DRY_RUN=false
WITH_LOCAL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --remote)
            REMOTE_NAME=$2
            shift 2
            ;;
        --dry)
            DRY_RUN=true
            shift
            ;;
        --with-local)
            WITH_LOCAL=true
            shift
            ;;
        -h|--help)
            usage_helper
            exit 1
            ;;
        -*)
            echo "Error: Unknown option $1"
            usage_helper
            exit 1
            ;;
        *)
            BRANCH=$1
            shift
            ;;
    esac
done

# ---- Input Validation ----
if [[ -z "$BRANCH" ]]; then
    echo "Error: Missing branch name."
    usage_helper
    exit 1
fi

if ! git ls-remote --heads "$REMOTE_NAME" "$BRANCH" | grep -q "$BRANCH"; then
    echo "❌ Remote branch '$REMOTE_NAME/$BRANCH' not found."
    exit 1
fi

if $WITH_LOCAL; then
    echo "🔍 Checking local branch: $BRANCH"

    if ! git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        echo "❌ Local branch '$BRANCH' not found."
        exit 1
    fi
fi

# ---- Execute deletion ----
delete_branch "$BRANCH" "$REMOTE_NAME" $DRY_RUN $WITH_LOCAL
echo "🎉 Done."
