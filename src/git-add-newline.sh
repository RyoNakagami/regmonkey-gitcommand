#!/bin/bash
# ------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2025-10-24
# Script: git-add-newline.sh
# Description:
#   Automatically adds trailing newlines to files in a git repository
#   that are missing them. This ensures proper file formatting and
#   avoids "No newline at end of file" warnings.
#
#   Steps:
#     1. Checks if we're in a git repository
#     2. Gets list of all tracked files
#     3. Filters files based on ignore patterns
#     4. Skips binary and SVG files
#     5. Adds newline if missing and reports changes
#
# Options:
#    -h, --help     Show this help message
#    -i PATTERN     Ignore files matching the given pattern (can be used multiple times)
#
# Usage:
#   ./git-add-newline.sh                    # Process all tracked files
#   ./git-add-newline.sh -i "*.md"          # Ignore markdown files
#   ./git-add-newline.sh -i "*.jpg" -i "*.png"   # Ignore multiple patterns
#
# Notes:
#   - Requires git to be installed and configured
#   - Requires file command for MIME type detection
#   - Must be run from within a git repository
# ------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Initialize array for ignore patterns ----
declare -a ignore_patterns=()

# ---- Parse command line arguments ----
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage_helper "$0"
            exit 1
            ;;
        -i)
            if [[ -z ${2:-} ]]; then
                echo "Error: -i option requires a pattern argument"
                exit 1
            fi
            ignore_patterns+=("$2")
            shift 2
            ;;
        *)
            echo "Error: Unknown option: $1"
            usage_helper "$0"
            exit 1
            ;;
    esac
done

# ---- Ensure we're in a git repository ----
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not a git repository"
    exit 1
fi

# ---- Get all tracked files ----
while IFS= read -r -d '' file; do
    # Skip file if it matches any ignore pattern
    skip=0
    for pattern in "${ignore_patterns[@]}"; do
        if [[ $file =~ $pattern ]]; then
            skip=1
            break
        fi
    done
    [[ $skip -eq 1 ]] && continue

    # Skip binary files and SVG files (they don't require trailing newlines)
    if file --mime "${file}" | grep -q -e "charset=binary" -e "image/svg+xml"; then
        continue
    fi

    # Check if file ends with a newline
    if ! tail -c1 "${file}" | read -r _; then
        echo >> "${file}"; echo "✓ Newline added to: ${file}"
    fi
done < <(git ls-files -z)
