#!/bin/bash

# -----------------------------------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2025-11-12
# Script: git-add-patch.sh
# Description:
#   This script stages modified files in a Git repository interactively or 
#   based on specific criteria such as directory or keyword search.
#
#   Steps:
#     1. Parse command-line options to determine the mode of operation.
#     2. Identify the Git repository root directory.
#     3. Filter modified files based on the specified directory or keyword.
#     4. Stage files interactively using `git add -p` or add all modified files.
#
# Options:
#    -a    Stage all modified files in the repository.
#    -d    Specify a directory to stage modified files from.
#    -s    Specify a keyword to filter and stage modified files.
#    -h    Display help information.
#
# Usage:
#   ./git-add-patch.sh -a                  # Stage all modified files.
#   ./git-add-patch.sh -d <directory>      # Stage files in a specific directory.
#   ./git-add-patch.sh -s <keyword>        # Stage files matching a keyword.
#
# Notes:
#   - Requires Git installed and accessible in the system PATH.
#   - The script uses `git add -p` for interactive staging.
#   - Ensure the script is executed within a Git repository.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# Initialize variables
DIRECTORY=""
SEARCH_KEYWORD=""
GIT_ADD_PATH=""
GIT_ADD_ALL=FALSE

# Parse command line options
while getopts "had:s:" opt; do
    case $opt in
        a)
            GIT_ADD_ALL=TRUE
            ;;
        d)
            DIRECTORY="$OPTARG"
            ;;
        s)
            SEARCH_KEYWORD="$OPTARG"
            ;;
        h)
            usage_helper "$0"
            exit 1
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument."
            exit 1
            ;;
    esac
done

# Get git root directory
GIT_ROOT="$(git rev-parse --show-toplevel)" || {
    echo "Error: Unable to determine the Git repository root."
    exit 1
}

# Function to filter files by search keyword
filter_by_keyword() {
    local keyword="$1"
    git ls-files -m -z "$GIT_ROOT" | grep --binary-files=text -iZ "$keyword"
}

# Function to get modified files in a directory
get_directory_files() {
    local dir="$1"
    git ls-files -m -z "$dir"
}

# Function to print modified files
print_modified_files() {
    local files="$1"

    if [ -z "$files" ]; then
        echo "No modified files found."
        exit 0
    fi

    echo "Files to be processed:"
    echo "========================="
    echo "$files"
    echo "========================="
}

# Function to add files interactively with git add -p
git_add_patch_from_pipe() {
    xargs -0 -n 1 bash -c '
        file="$1"
        echo "Processing: $file"
        exec < /dev/tty
        git add -p "$file" || {
            echo "Error: Failed to add '\''$file'\'' to the staging area."
            exit 1
        }
    ' _
}

if [ "$GIT_ADD_ALL" = TRUE ]; then
    git add -u
    exit 0
fi

# Determine which files to stage
if [ -n "$DIRECTORY" ]; then
    # Directory mode
    if [ ! -d "$DIRECTORY" ]; then
        echo "Error: Directory '$DIRECTORY' does not exist."
        exit 1
    fi
    echo "Adding modified files in directory: $DIRECTORY"
    FILES=$(git ls-files -m "$DIRECTORY")
    print_modified_files "$FILES"
    get_directory_files "$DIRECTORY" | git_add_patch_from_pipe
elif [ -n "$SEARCH_KEYWORD" ]; then
    # Search mode
    echo "Adding files matching keyword: $SEARCH_KEYWORD"
    FILES=$(git ls-files -m "$GIT_ROOT" | grep -i "$SEARCH_KEYWORD")
    print_modified_files "$FILES"
    filter_by_keyword "$SEARCH_KEYWORD" | git_add_patch_from_pipe
else
    # Default mode (git root)
    echo "Adding all modified files in repository..."
    FILES=$(git ls-files -m "$GIT_ROOT")
    print_modified_files "$FILES"
    git ls-files -m -z "$GIT_ROOT" | git_add_patch_from_pipe
fi
