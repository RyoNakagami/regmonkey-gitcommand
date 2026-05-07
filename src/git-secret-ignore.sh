#!/bin/bash
# -----------------------------------------------------------------------------
# Author: RyoNakagami
# Revised: 2026-05-04
# Script: git-secret-ignore.sh
# Description:
#   This script registers one or more <pattern>s as locally-ignored paths via
#   `.git/info/exclude`, keeping them untracked without modifying the shared
#   `.gitignore`.
#
#   Steps:
#     1. Parse command-line options (--check, --help).
#     2. Verify the current working directory is a git repository.
#     3. Create `.git/info/exclude` if it does not yet exist.
#     4. Append each specified pattern to the exclude file when absent.
#
# Options:
#    --check, -n      Show what is written in .git/info/exclude and exit.
#    --help, -h       Show usage information and exit.
#
# Usage:
#   ./git-secret-ignore.sh <pattern> [<pattern> ...]   # Register pattern(s) in .git/info/exclude.
#   ./git-secret-ignore.sh --check                     # Preview current exclude file contents.
#   ./git-secret-ignore.sh secret.env '*.key' .env.local
#
# Notes:
#   - Requires Bash shell.
#   - Must be executed from within a git repository.
#   - Requires standard Unix utilities (grep, touch) on PATH.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
PATTERNS=()
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
            PATTERNS+=("$1")
            shift
            ;;
    esac
done

# ---- Verify git repository ----
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || {
    echo "❌ Error: Not inside a git repository."
    exit 1
}

EXCLUDE_FILE="${GIT_DIR}/info/exclude"

# ---- Check mode: print current exclude contents and exit ----
if $CHECK; then
    if [[ -f "$EXCLUDE_FILE" ]]; then
        echo "📄 Contents of ${EXCLUDE_FILE}:"
        cat "$EXCLUDE_FILE"
    else
        echo "ℹ️  ${EXCLUDE_FILE} does not exist yet."
    fi
    exit 0
fi

# ---- Input Validation ----
if [[ ${#PATTERNS[@]} -eq 0 ]]; then
    echo "Error: Missing <pattern>."
    usage_helper
    exit 1
fi

# ---- Ensure exclude file exists ----
mkdir -p "$(dirname "$EXCLUDE_FILE")"
touch "$EXCLUDE_FILE"

# ---- Append each pattern when absent ----
for pattern in "${PATTERNS[@]}"; do
    if grep -Fxq -- "$pattern" "$EXCLUDE_FILE"; then
        echo "ℹ️  Already present: $pattern"
    else
        printf '%s\n' "$pattern" >> "$EXCLUDE_FILE"
        echo "🎉 Registered: $pattern"
    fi
done

echo "✅ Done. Updated ${EXCLUDE_FILE}."
