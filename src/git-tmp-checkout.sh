#!/bin/bash
# -----------------------------------------------------------------------------
# Author: RyoNakagami
# Revised: 2026-04-23
# Script: git-tmp-checkout.sh
# Description:
#   Snapshots the current working tree (including untracked files) into a
#   stash, creates a new branch, and re-applies the stash on top of it so
#   in-progress work can be moved off the current branch without losing state.
#
#   Steps:
#     1. Parse command-line arguments for stash message and new branch name.
#     2. `git stash push -a` to capture tracked + untracked changes.
#     3. `git switch -c` to create and switch to the new branch.
#     4. `git stash apply stash@{0}` to restore the working tree on the new branch.
#
# Options:
#    -m <stash_message>   Message to attach to the stash
#                         (default: timestamp + short commit id)
#    -c <new_branch>      Name of the new branch to create (required)
#    -h, --help           Show this help message
#
# Usage:
#   ./git-tmp-checkout.sh -c feature/wip
#   ./git-tmp-checkout.sh -m "wip: refactor" -c feature/wip
#
# Notes:
#   - Requires git with `switch` support (git >= 2.23).
#   - The stash is left in the stash list after apply; drop it manually if
#     you no longer need the snapshot.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
stash_message=""
new_branch_name=""

# Handle long-form help before getopts (getopts doesn't support --help).
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            usage_helper
            exit 0
            ;;
    esac
done

while getopts ":m:c:h" opt; do
    case "$opt" in
        m) stash_message="$OPTARG" ;;
        c) new_branch_name="$OPTARG" ;;
        h)
            usage_helper
            exit 0
            ;;
        \?)
            echo "Error: Unknown option -$OPTARG"
            usage_helper
            exit 1
            ;;
        :)
            echo "Error: Option -$OPTARG requires an argument"
            usage_helper
            exit 1
            ;;
    esac
done

# ---- Input Validation ----
if [ -z "$new_branch_name" ]; then
    echo "Error: -c <new_branch> is required."
    usage_helper
    exit 1
fi

# ---- Default stash message ----
if [ -z "$stash_message" ]; then
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    commit_id=$(git rev-parse --short HEAD 2>/dev/null || echo "no-commit-id")
    stash_message="Stash created on $timestamp from commit $commit_id"
fi

# ---- Execute ----
git stash push -a -m "$stash_message" &&
git switch -c "$new_branch_name" &&
git stash apply stash@{0}

echo "🎉 Successfully switched to branch '$new_branch_name' and applied stashed changes."
