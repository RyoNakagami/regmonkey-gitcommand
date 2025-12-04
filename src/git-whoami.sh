#!/bin/bash
# -----------------------------------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2025-12-04
# Script: git-whoami.sh
# Description:
#   Prints the current Git user's name and email as configured in Git.
#
#   Steps:
#     1. Retrieve user.name and user.email from Git config.
#     2. Check if both values are set.
#     3. Print the user name and email in a formatted string.
#
# Options:
#    -h : Display help information.
#
# Usage:
#   ./git-whoami.sh                    # Prints Git user name and email
#
# Notes:
#   - Requires git installed.
# -----------------------------------------------------------------------------

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# Parse options
while getopts "h" opt; do
    case $opt in
        h)
            usage_helper "$0"
            exit 1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done



# Get the Git user name and email from the configuration
user_name=$(git config user.name)
user_email=$(git config user.email)

# Check if the user name and email are set
if [ -z "$user_name" ] || [ -z "$user_email" ]; then
    echo "Git user name or email is not set."
    exit 1
fi

# Print the user name and email
echo "$user_name ($user_email)"
