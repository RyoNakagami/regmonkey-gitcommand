#!/bin/bash
# -----------------------------------------------------------------------------
# Author: RyoNakagami
# Revised: 2026-04-23
# Script: git-issue2pr.sh
# Description:
#   Converts an existing GitHub issue into a Pull Request by calling the
#   GitHub REST API via `gh api`. The current branch is used as the head
#   branch and the issue is linked as the PR body/source.
#
#   Steps:
#     1. Parse command-line arguments for base branch, issue number, and remote.
#     2. Resolve owner/repo from the specified git remote URL.
#     3. Show a confirmation prompt summarizing the PR to be created.
#     4. Call `gh api repos/<owner>/<repo>/pulls` with head/base/issue fields.
#
# Options:
#    -b <base-branch>   Base branch for the Pull Request (required)
#    -i <issue-number>  GitHub issue number to convert (required)
#    -r <remote>        Remote name to resolve owner/repo (default: origin)
#    -h, --help         Show this help message
#
# Usage:
#   ./git-issue2pr.sh -b main -i 42
#   ./git-issue2pr.sh -b develop -i 7 -r upstream
#
# Notes:
#   - Requires `gh` CLI authenticated against the target repository.
#   - Must be run from within a git repository whose remote points to GitHub.
#   - The current branch is used as the PR head; push it to the remote first.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
BASE=""
ISSUE=""
REMOTE="origin"

# Handle long-form help before getopts (getopts doesn't support --help).
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage_helper
      exit 0
      ;;
  esac
done

while getopts ":b:i:r:h" opt; do
  case $opt in
    b) BASE="$OPTARG" ;;
    i) ISSUE="$OPTARG" ;;
    r) REMOTE="$OPTARG" ;;
    h)
      usage_helper
      exit 0
      ;;
    \?)
      echo "Error: Unknown option -$OPTARG"
      usage_helper
      exit 1
      ;;
    :)
      echo "Error: Option -$OPTARG requires an argument"
      usage_helper
      exit 1
      ;;
  esac
done

# ---- Input Validation ----
if [[ -z "$BASE" || -z "$ISSUE" ]]; then
  echo "Error: -b <base-branch> and -i <issue-number> are required."
  usage_helper
  exit 1
fi

# ---- Resolve owner/repo from remote URL ----
REMOTE_URL=$(git remote get-url "$REMOTE")
if [[ "$REMOTE_URL" =~ github.com[:/](.+)/(.+)\.git ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
else
  echo "❌ Could not parse repo owner/name from remote: $REMOTE_URL"
  exit 1
fi

# ---- Current branch ----
HEAD_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# ---- Confirmation prompt ----
echo "⚡ Ready to create a Pull Request:"
echo "  Repo:   $OWNER/$REPO"
echo "  Head:   $HEAD_BRANCH"
echo "  Base:   $BASE"
echo "  Issue:  #$ISSUE"
echo
read -rp "Do you want to continue? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "❌ Aborted."
  exit 1
fi

# ---- Create PR ----
gh api "repos/$OWNER/$REPO/pulls" \
  -f "head=$HEAD_BRANCH" \
  -f "base=$BASE" \
  -F "issue=$ISSUE"

echo "🎉 Done."
