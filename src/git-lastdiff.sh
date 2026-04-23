#!/bin/bash
# -----------------------------------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2026-04-23
# Script: git-lastdiff.sh
# Description:
#   Shows the diff introduced by the most recent commit that touched a given
#   file, compared against the current HEAD.
#
#   Steps:
#     1. Validate input and confirm the target file exists inside a git repo.
#     2. Locate the N-th most recent commit that modified the file (default 1).
#     3. Resolve its parent, falling back to the empty tree for root commits.
#     4. Launch `git difftool` (or `git diff` with --no-tool) between that
#        parent and HEAD, scoped to the file.
#
# Options:
#    -n <N>          Use the N-th most recent commit touching the file (default: 1)
#    --no-tool       Use `git diff` instead of `git difftool`
#    -h, --help      Show this help message
#
# Usage:
#   ./git-lastdiff.sh <file path>
#   ./git-lastdiff.sh <file path> -n 2          # second-to-last change
#   ./git-lastdiff.sh <file path> --no-tool     # plain git diff output
#
# Notes:
#   - Requires git to be installed and configured.
#   - Must be run from within a git repository.
#   - `git difftool` honors your configured diff.tool.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
TARGET_FILE=""
COMMIT_OFFSET=1
USE_TOOL=true

while [[ $# -gt 0 ]]; do
    case $1 in
        -n)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                echo "Error: -n requires a positive integer argument"
                usage_helper
                exit 1
            fi
            COMMIT_OFFSET=$2
            shift 2
            ;;
        --no-tool)
            USE_TOOL=false
            shift
            ;;
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
            if [[ -n "$TARGET_FILE" ]]; then
                echo "Error: Unexpected extra argument '$1'"
                usage_helper
                exit 1
            fi
            TARGET_FILE=$1
            shift
            ;;
    esac
done

# ---- Input Validation ----
if [[ -z "$TARGET_FILE" ]]; then
    echo "Error: Missing file path."
    usage_helper
    exit 1
fi

if ! [[ "$COMMIT_OFFSET" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: -n must be a positive integer (got '$COMMIT_OFFSET')."
    exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not inside a git repository."
    exit 1
fi

if [[ ! -f "$TARGET_FILE" ]]; then
    echo "❌ File '$TARGET_FILE' does not exist."
    exit 1
fi

# ---- Resolve commit that last touched the file ----
COMMIT_ID=$(git log --format="%H" -n "$COMMIT_OFFSET" -- "$TARGET_FILE" | tail -n 1)

if [[ -z "$COMMIT_ID" ]]; then
    echo "❌ No commit history found for '$TARGET_FILE'."
    exit 1
fi

COMMIT_COUNT=$(git log --format="%H" -- "$TARGET_FILE" | wc -l)
if (( COMMIT_OFFSET > COMMIT_COUNT )); then
    echo "❌ Requested commit #$COMMIT_OFFSET but '$TARGET_FILE' only has $COMMIT_COUNT commit(s)."
    exit 1
fi

# Resolve parent; fall back to empty tree hash for root commits.
if PARENT_ID=$(git rev-parse --verify "${COMMIT_ID}^" 2>/dev/null); then
    :
else
    PARENT_ID=$(git hash-object -t tree /dev/null)
fi

# ---- Execute diff ----
if $USE_TOOL; then
    git difftool -y "$PARENT_ID" HEAD -- "$TARGET_FILE"
else
    git diff "$PARENT_ID" HEAD -- "$TARGET_FILE"
fi
