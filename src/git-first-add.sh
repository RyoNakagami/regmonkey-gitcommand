#!/bin/bash
# -----------------------------------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2026-05-20
# Script: git-first-add.sh
# Description:
#   This script reports, for each tracked file, the commit at which it was first
#   added (--diff-filter=A --reverse), the most recent re-add commit, and the
#   total number of add commits.  Use it to audit when files entered the
#   repository or to detect files that have been removed and re-added.
#
#   Steps:
#     1. Parse command-line options (--no-header, --help).
#     2. Verify the current working directory is a git repository.
#     3. Determine the target file list (arguments, or all tracked files).
#     4. For each file, query git log with --diff-filter=A and print a table row.
#
# Options:
#    -q, --no-header   Omit the table header and separator line.
#    -h, --help        Show usage information and exit.
#
# Usage:
#   ./git-first-add.sh                       # Report all tracked files.
#   ./git-first-add.sh src/foo.sh            # Report specific file(s).
#   ./git-first-add.sh --no-header src/foo.sh
#
# Notes:
#   - Requires Bash shell.
#   - Must be executed from within a git repository.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
NO_HEADER=false
FILES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -q|--no-header)
            NO_HEADER=true
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
            FILES+=("$1")
            shift
            ;;
    esac
done

# ---- Verify git repository ----
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Error: Not inside a git repository."
    exit 1
fi

# ---- Determine target file list ----
if [[ ${#FILES[@]} -eq 0 ]]; then
    mapfile -t FILES < <(git ls-files)
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "ℹ️  No tracked files found."
    exit 0
fi

# ---- Helper: emit one table row ----
get_add_log() {
    local file="$1"
    local fmt="%h %an %ad %s"
    local date_fmt="iso"

    local oldest
    oldest=$(git log --diff-filter=A --reverse \
        --format="$fmt" --date="$date_fmt" \
        -- "$file" | head -1)

    local latest
    latest=$(git log --diff-filter=A \
        --format="$fmt" --date="$date_fmt" \
        -- "$file" | head -1)

    local count
    count=$(git log --diff-filter=A --oneline -- "$file" | wc -l | tr -d ' ')

    printf "%-50s  count=%-3s  oldest: %-55s  latest: %s\n" \
        "$file" "$count" "${oldest:-(none)}" "${latest:-(none)}"
}

# ---- Print header ----
if ! $NO_HEADER; then
    printf "%-50s  %-9s  %-62s  %s\n" \
        "file" "count" "oldest commit" "latest commit"
    printf '%.0s-' {1..180}
    printf '\n'
fi

# ---- Print one row per file ----
for f in "${FILES[@]}"; do
    get_add_log "$f"
done