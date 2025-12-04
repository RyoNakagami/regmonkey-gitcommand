#!/bin/bash

# -----------------------------------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2025-11-12
# Script: git-browse.sh
# Description:
#   This script opens the remote repository URL (branch, tag, or commit) in a
#   web browser. It supports GitHub, GitLab, and Bitbucket URL patterns and
#   allows specifying a browser or a specific reference.
#
#   Steps:
#     1. Parse command-line options to determine the browser and reference.
#     2. Retrieve the list of push remotes and handle multiple remotes.
#     3. Convert SSH URLs to HTTPS if necessary.
#     4. Modify the URL based on the specified reference (branch, tag, or commit).
#     5. Open the URL in the specified or default browser.
#
# Options:
#    -b <browser>  Use the specified browser (e.g., firefox, chrome).
#    -r <ref>      Open the URL for a specific branch, tag, or commit.
#    -h            Show this help message.
#
# Usage:
#   ./git-browse.sh                      # Open the default remote in the default browser.
#   ./git-browse.sh -b firefox           # Open the default remote in Firefox.
#   ./git-browse.sh -r main              # Open the URL for the "main" branch.
#   ./git-browse.sh -r 1234abc           # Open the URL for a specific commit.
#
# Notes:
#   - Requires Git, awk, sed, and a supported browser installed.
#   - Ensure the script is executed within a Git repository.
#   - Supports GitHub, GitLab, and Bitbucket URL patterns.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Initialize variables ----
BROWSER=""
REF=""

# Validate browser
validate_browser() {
    local browser=$1
    case "$browser" in
        firefox|chrome|chromium|google-chrome)
            return 0
            ;;
        *)
            echo "❌ Error: Unsupported browser: $browser" >&2
            echo "Supported browsers: firefox, chrome, chromium, google-chrome" >&2
            exit 1
            ;;
    esac
}

# Parse command-line arguments
while getopts "b:r:h" opt; do
    case "$opt" in
        b) 
            BROWSER="$OPTARG"
            validate_browser "$BROWSER"
            ;;
        r) 
            REF="$OPTARG"
            ;;
        h) 
            usage_helper "$0" 
            exit 1
            ;;
        *) 
            usage_helper "$0"
            exit 1
            ;;
    esac
done

# Get list of push remotes
remotes=($(git remote -v | awk '/\(push\)/ {print $2}' | sort -u))
if [ ${#remotes[@]} -eq 0 ]; then
    echo "❌ Error: No push remotes found" >&2
    exit 1
fi

# Handle multiple remotes with simple numbered menu
if [ ${#remotes[@]} -gt 1 ]; then
    echo "Multiple remotes found. Please select one:"
    select remote in "${remotes[@]}"; do
        if [ -n "$remote" ]; then
            break
        else
            echo "❌ Invalid selection. Please try again."
        fi
    done
else
    remote="${remotes[0]}"
fi

# Convert SSH to HTTPS if needed
if [[ "$remote" =~ ^git@([^:]+):(.+)$ ]]; then
    DOMAIN="${BASH_REMATCH[1]}"
    REPO_PATH="${BASH_REMATCH[2]}"
    remote="https://${DOMAIN}/${REPO_PATH}"
fi

# Modify URL if ref is specified
if [ -n "$REF" ]; then
    # Handle different remote URL formats
    if [[ "$remote" =~ ^git@ ]]; then
        # SSH format
        remote=$(echo "$remote" | sed "s|:|/|" | sed "s|^git@|https://|")
    elif [[ "$remote" =~ ^https?:// ]]; then
        # Already HTTPS format, nothing to do
        :
    else
        echo "❌ Error: Unsupported remote URL format: $remote" >&2
        exit 1
    fi
    
    # Remove .git suffix if present
    remote=${remote%.git}
    
    # Handle different hosting services
    if [[ "$remote" =~ github.com ]]; then
        if git rev-parse --verify "$REF^{commit}" >/dev/null 2>&1; then
            remote="$remote/commit/$REF"
        else
            # Handle branch names with slashes
            branch_path=${REF//\//%2F}
            remote="$remote/tree/$branch_path"
        fi
    elif [[ "$remote" =~ gitlab.com ]]; then
        if git rev-parse --verify "$REF^{commit}" >/dev/null 2>&1; then
            remote="$remote/-/commit/$REF"
        else
            branch_path=${REF//\//%2F}
            remote="$remote/-/tree/$branch_path"
        fi
    elif [[ "$remote" =~ bitbucket.org ]]; then
        if git rev-parse --verify "$REF^{commit}" >/dev/null 2>&1; then
            remote="$remote/commits/$REF"
        else
            branch_path=${REF//\//%2F}
            remote="$remote/src/$branch_path"
        fi
    else
        # Default to GitHub-style URLs for unknown hosts
        if git rev-parse --verify "$REF^{commit}" >/dev/null 2>&1; then
            remote="$remote/commit/$REF"
        else
            branch_path=${REF//\//%2F}
            remote="$remote/tree/$branch_path"
        fi
    fi
fi

# Open in specified browser or default
if [ -n "$BROWSER" ]; then
    echo "Opening in $BROWSER: $remote"
    git web--browse -b $BROWSER "$remote" >/dev/null 2>&1
else
    echo "Opening in default browser: $remote"
    git web--browse "$remote" >/dev/null 2>&1
fi
