#!/bin/bash
# -----------------------------------------------------------------------------
# Author: RyoNakagami
# Revised: 2026-04-23
# Script: git-sparse-checkout.sh
# Description:
#   Performs a sparse checkout of a remote git repository, cloning only the
#   specified paths (or, in bare mode, just the top-level files and empty
#   directory skeleton).
#
#   Steps:
#     1. Parse command-line arguments for clone URL, target dir, branch,
#        sparse path list, and bare-mode flag.
#     2. Clone the repository with blob filtering and no checkout.
#     3. Enable core.sparseCheckout and write the sparse-checkout rules.
#     4. Checkout the requested branch; in bare mode, materialize empty dirs.
#
# Options:
#    -u <clone_url>     Git URL to clone (required)
#    -d <target_dir>    Local target directory (required)
#    -b <branch>        Branch to checkout (required)
#    -p <sparse_path>   Colon-separated list of sparse paths
#                       (required unless -s)
#    -s                 Bare mode: fetch only top-level files plus an empty
#                       directory skeleton (no -p required)
#    -h, --help         Show this help message
#
# Usage:
#   ./git-sparse-checkout.sh -u git@github.com:owner/repo.git \
#                            -d ./repo -b main -p "src/a:docs"
#   ./git-sparse-checkout.sh -u git@github.com:owner/repo.git \
#                            -d ./repo -b main -s
#
# Notes:
#   - Requires git >= 2.25 with sparse-checkout support.
#   - Sparse paths in -p are separated by ':'.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
BARE=false

# Handle long-form help before getopts (getopts doesn't support --help).
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage_helper
      exit 0
      ;;
  esac
done

while getopts ":su:d:b:p:h" opt; do
  case $opt in
    s) BARE=true ;;
    u) CLONE_URL=$OPTARG ;;
    d) TARGET_DIR=$OPTARG ;;
    b) BRANCH=$OPTARG ;;
    p) SPARSE_PATH=$OPTARG ;;
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
if [[ -z "${CLONE_URL-}" || -z "${TARGET_DIR-}" || -z "${BRANCH-}" ]]; then
  echo "Error: -u, -d, and -b are required."
  usage_helper
  exit 1
fi

if [[ "$BARE" = false && -z "${SPARSE_PATH-}" ]]; then
  echo "Error: -p <sparse_path> is required unless -s (bare mode) is specified."
  usage_helper
  exit 1
fi

# ---- Clone and configure sparse checkout ----
git clone --filter=blob:none --no-checkout "$CLONE_URL" "$TARGET_DIR"
cd "$TARGET_DIR"
git config core.sparseCheckout true

if $BARE; then
  {
    echo "/*"
    echo "!/*/"
  } > .git/info/sparse-checkout
  git checkout "$BRANCH"
  git ls-tree -r -d --name-only HEAD | xargs -I{} mkdir -p "{}"
  echo "🎉 Done."
  exit 0
fi

echo -e "$SPARSE_PATH" | tr ':' '\n' > .git/info/sparse-checkout
git checkout "$BRANCH"
echo "🎉 Done."
