#!/bin/bash
# -----------------------------------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2026-05-19
# Script: git-add-gitkeep.sh
# Description:
#   This script discovers every `.gitkeep` file under the current git working
#   tree and stages them with `git add`, so empty directories are preserved in
#   version control.
#
#   Steps:
#     1. Parse command-line options (--check, --help).
#     2. Verify the current working directory is a git repository.
#     3. Verify `fd` is available on PATH.
#     4. Locate `.gitkeep` files (including those in hidden directories).
#     5. Stage each file with `git add`, or list them in check mode.
#
# Options:
#    -n, --check     Show the `.gitkeep` files that would be staged and exit.
#    -h, --help      Show usage information and exit.
#
# Usage:
#   ./git-add-gitkeep.sh            # Stage every .gitkeep file in the repo.
#   ./git-add-gitkeep.sh --check    # Preview .gitkeep files without staging.
#
# Notes:
#   - Requires Bash shell.
#   - Must be executed from within a git repository.
#   - Requires `fd` or `fdfind` (fd-find) on PATH.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
CHECK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--check)
            CHECK=true
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
            echo "Error: Unexpected extra argument '$1'"
            usage_helper
            exit 1
            ;;
    esac
done

# ---- Verify git repository ----
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Error: Not inside a git repository."
    exit 1
fi

# ---- Verify dependencies ----
if command -v fd >/dev/null 2>&1; then
    FD_BIN=fd
elif command -v fdfind >/dev/null 2>&1; then
    FD_BIN=fdfind
else
    echo "❌ 'fd' command not found. Please install fd-find first."
    exit 1
fi

# ---- Collect .gitkeep files ----
mapfile -t GITKEEP_FILES < <("$FD_BIN" -H '\.gitkeep$' -t f)

if [[ ${#GITKEEP_FILES[@]} -eq 0 ]]; then
    echo "ℹ️  No .gitkeep files found."
    exit 0
fi

# ---- Check mode: list candidates and exit ----
if $CHECK; then
    echo "📄 .gitkeep files that would be staged:"
    for file in "${GITKEEP_FILES[@]}"; do
        echo "  - $file"
    done
    exit 0
fi

# ---- Stage each .gitkeep ----
for file in "${GITKEEP_FILES[@]}"; do
    git add "$file"
    echo "🎉 Added: $file"
done

echo "✅ Done. Staged ${#GITKEEP_FILES[@]} .gitkeep file(s)."
