#!/bin/bash
# -----------------------------------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2026-04-23
# Script: git-gen-commit.sh
# Description:
#   Generates a Git commit message from the currently staged diff by piping
#   `git diff --cached` into the `claude` CLI, then creates the commit.
#
#   Steps:
#     1. Verify there are staged changes (exit if none).
#     2. Build a prompt (optionally extended with a branch rule file).
#     3. Pipe the staged diff to `claude -p <prompt>` to produce a one-line message.
#     4. Either print the message (--dryrun) or create the commit.
#
# Options:
#    --dryrun           Print the generated commit message without committing
#    --rule <path>      Read a branch rule file and include it in the prompt
#                       so the generated message follows the project's rules
#    -h, --help         Show this help message
#
# Usage:
#   ./git-gen-commit.sh                      # Generate and commit
#   ./git-gen-commit.sh --dryrun             # Show message only
#   ./git-gen-commit.sh --rule .claude/commit-rule.md
#
# Notes:
#   - Requires the `claude` CLI to be installed and on PATH.
#   - Must be run from within a git repository with staged changes.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
DRY_RUN=false
RULE_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dryrun)
            DRY_RUN=true
            shift
            ;;
        --rule)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                echo "Error: --rule requires a path argument"
                usage_helper
                exit 1
            fi
            RULE_PATH=$2
            shift 2
            ;;
        -h|--help)
            usage_helper
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            usage_helper
            exit 1
            ;;
    esac
done

# ---- Input Validation ----
if ! command -v claude >/dev/null 2>&1; then
    echo "❌ 'claude' CLI not found on PATH."
    exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not inside a git repository."
    exit 1
fi

if git diff --cached --quiet; then
    echo "No staged changes to commit." >&2
    exit 1
fi

# ---- Build prompt ----
PROMPT="Write a concise one-line commit message for this diff. Output only the message, no quotes or explanations."

if [[ -n "$RULE_PATH" ]]; then
    if [[ ! -r "$RULE_PATH" ]]; then
        echo "❌ Rule file not readable: $RULE_PATH"
        exit 1
    fi
    RULE_CONTENT=$(cat "$RULE_PATH")
    PROMPT="${PROMPT}

Follow the commit message rules below:
---
${RULE_CONTENT}
---"
fi

# ---- Generate message ----
MESSAGE=$(git diff --cached | claude -p "$PROMPT" | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//')

if [[ -z "$MESSAGE" ]]; then
    echo "❌ Empty commit message returned from claude."
    exit 1
fi

# ---- Commit or dry run ----
if $DRY_RUN; then
    echo "[Dry Run] Generated commit message:"
    echo "  $MESSAGE"
    exit 0
fi

git commit -m "$MESSAGE"
echo "🎉 Done."
