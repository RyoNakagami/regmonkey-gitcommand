#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Author: RyoNakagami
# Revised: 2026-04-23
# Script: git-sparse-checkout.sh
# Description:
#   Performs a sparse checkout of a remote git repository, cloning only the
#   specified paths (or, in skeleton mode, just the top-level files and empty
#   directory skeleton).
#
#   Steps:
#     1. Parse command-line arguments for clone URL, target dir, branch,
#        sparse path list, and skeleton-mode flag.
#     2. Clone the requested branch with blob filtering and sparse checkout.
#     3. Set the requested sparse paths using Git's sparse-checkout porcelain.
#     4. In skeleton mode, materialize empty directories.
#
# Options:
#    -u <clone_url>     Git URL to clone (required)
#    -d <target_dir>    Local target directory (required)
#    -b <branch>        Branch to checkout (required)
#    -p <sparse_path>   Sparse path to checkout; may be specified multiple times
#                       (required unless -s)
#    -s                 Skeleton mode: checkout top-level files plus an empty
#                       directory skeleton (no -p required)
#    -h, --help         Show this help message
#
# Usage:
#   ./git-sparse-checkout.sh -u https://github.com/anthropics/skills.git \
#                            -d ./anthropic-skills -b main \
#                            -p skills/skill-creator
#   ./git-sparse-checkout.sh -u https://github.com/example/repo.git \
#                            -d ./repo -b main -p src -p docs -p examples
#   ./git-sparse-checkout.sh -u git@github.com:owner/repo.git \
#                            -d ./repo -b main -s
#
# Notes:
#   - Requires git >= 2.25 with sparse-checkout support.
#   - Sparse paths use cone mode and should name directories.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
# shellcheck source=lib/docstring.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
SKELETON=false
SPARSE_PATHS=()

# Handle long-form help before getopts (getopts doesn't support --help).
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage_helper "$0"
      exit 0
      ;;
  esac
done

while getopts ":su:d:b:p:h" opt; do
  case $opt in
    s) SKELETON=true ;;
    u) CLONE_URL=$OPTARG ;;
    d) TARGET_DIR=$OPTARG ;;
    b) BRANCH=$OPTARG ;;
    p) SPARSE_PATHS+=("$OPTARG") ;;
    h)
      usage_helper "$0"
      exit 0
      ;;
    \?)
      echo "Error: Unknown option -$OPTARG" >&2
      usage_helper "$0"
      exit 1
      ;;
    :)
      echo "Error: Option -$OPTARG requires an argument" >&2
      usage_helper "$0"
      exit 1
      ;;
  esac
done

# ---- Input Validation ----
if [[ -z "${CLONE_URL-}" || -z "${TARGET_DIR-}" || -z "${BRANCH-}" ]]; then
  echo "Error: -u, -d, and -b are required." >&2
  usage_helper "$0"
  exit 1
fi

if [[ "$SKELETON" == false && ${#SPARSE_PATHS[@]} -eq 0 ]]; then
  echo "Error: at least one -p is required unless -s is specified." >&2
  usage_helper "$0"
  exit 1
fi

# ---- Clone and configure sparse checkout ----
git clone \
  --filter=blob:none \
  --sparse \
  --branch "$BRANCH" \
  "$CLONE_URL" \
  "$TARGET_DIR"

if [[ "$SKELETON" == true ]]; then
  while IFS= read -r -d '' dir; do
    mkdir -p -- "$TARGET_DIR/$dir"
  done < <(
    git -C "$TARGET_DIR" \
      ls-tree -r -d -z --name-only HEAD
  )
else
  git -C "$TARGET_DIR" \
    sparse-checkout set "${SPARSE_PATHS[@]}"
fi

echo "🎉 Done."
