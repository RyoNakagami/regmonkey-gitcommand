#!/bin/bash
# -----------------------------------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2026-04-23
# Script: git-tree.sh
# Description:
#   Tree-display for git-tracked files. Wraps `tree --fromfile` so the output
#   respects .gitignore and only shows files that git knows about.
#
#   Steps:
#     1. Confirm we are inside a git working tree (scoped to the target path
#        when one is supplied).
#     2. List git-tracked files via `git ls-tree -r --name-only HEAD`.
#     3. Pipe the list into `tree --fromfile` to render the hierarchy.
#
# Options:
#    -h, --help     Show this help message
#
# Usage:
#   ./git-tree.sh                 # render the entire repository
#   ./git-tree.sh <folder path>   # render only the given folder
#
# Notes:
#   - Requires git and the `tree` command to be installed.
#   - Must be run from within a git repository.
#   - When the given folder is not tracked by git, the output will be empty:
#       <folder name>
#
#       0 directories, 0 files
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
TARGET_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage_helper
            exit 0
            ;;
        -*)
            echo "Error: Unknown option $1"
            usage_helper
            exit 1
            ;;
        *)
            if [[ -n "$TARGET_DIR" ]]; then
                echo "Error: Unexpected extra argument '$1'"
                usage_helper
                exit 1
            fi
            TARGET_DIR=$1
            shift
            ;;
    esac
done

# ---- Input Validation ----
if ! command -v tree >/dev/null 2>&1; then
    echo "❌ 'tree' command not found. Please install it first."
    exit 1
fi

if [[ -n "$TARGET_DIR" && ! -d "$TARGET_DIR" ]]; then
    echo "❌ '$TARGET_DIR' does not exist or is not a directory."
    exit 1
fi

GIT_CHECK_DIR="${TARGET_DIR:-.}"
if ! git -C "$GIT_CHECK_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "fatal: not a git repository (or any of the parent directories): .git"
    exit 1
fi

# ---- Execute tree rendering ----
if [[ -z "$TARGET_DIR" ]]; then
    git ls-tree -r --name-only HEAD | tree --fromfile
else
    git ls-tree -r --name-only HEAD "$TARGET_DIR" | tree --fromfile
fi
