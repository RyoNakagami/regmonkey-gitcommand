#!/bin/bash
# ------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2025-10-20
# Script: git-delete-current-repo.sh
# Description:
#   Deletes the GitHub repository corresponding to the current
#   local Git repository.
#
#   Steps:
#     1. Determines the repository in <OWNER/REPO> format
#        using GitHub CLI.
#     2. Prompts the user for confirmation.
#     3. Deletes the repository if confirmed.
#
# Usage:
#   ./git-delete-current-repo.shah          # Deletes the current repo after confirmation
#   ./git-delete-current-repo.sh -n         # Dry-run (show what would be deleted)
#
# Notes:
#   - Requires GitHub CLI (gh) installed and authenticated.
#   - Deletion is permanent; local files remain unaffected.
# ------------------------------------------------
set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ANSI color codes
RED='\033[0;31m'
NC='\033[0m'      # No Color

# Parse options
DRY_RUN=false
while getopts "nh" opt; do
    case $opt in
        h)
            usage_helper "$0"
            exit 1
            ;;
        n)
            DRY_RUN=true
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Get current repository in <OWNER/REPO> format
TARGET_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
TARGET_URL=$(gh repo view --json nameWithOwner,url -q .url)

if $DRY_RUN; then
    echo "[Dry run] The following repository would be deleted: $TARGET_REPO"
    exit 0
fi

# Confirm deletion with user
echo -e "Are you sure you want to delete the repository?\nRepo: ${RED}$TARGET_REPO${NC}\nURL: $TARGET_URL"
echo -e "Type Yes/No [y/N]: \c"
read confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    gh repo delete "$TARGET_REPO" --yes
    git remote remove origin
    echo "Repository '$TARGET_REPO' deleted."
else
    echo "Aborted."
fi
