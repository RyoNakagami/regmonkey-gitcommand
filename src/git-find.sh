#!/bin/bash
# -----------------------------------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2026-08-28
# Script: git-find.sh
# Description:
#   Searches file paths known to git and prints the ones matching a pattern.
#   By default it lists both tracked and untracked files while honouring
#   .gitignore (`--cached --others --exclude-standard`), so it behaves like a
#   git-aware `find` that never walks into node_modules/ or build artifacts.
#
#   Steps:
#     1. Parse command-line options (scope flags, --fixed-strings, etc.).
#     2. Verify the current working directory is a git repository.
#     3. Build the `git ls-files` scope flags from the selected mode.
#     4. Filter the resulting path list through grep with the given pattern.
#
# Options:
#    -t, --tracked          List tracked files only (git ls-files).
#    -u, --untracked        List untracked-but-not-ignored files only
#                           (drops --cached).
#    -a, --all              List tracked + untracked, including ignored files.
#    -i, --ignore-case      Case-insensitive pattern match.
#    -F, --fixed-strings    Treat the pattern as a literal string, not a regex.
#    -c, --count            Print only the number of matching paths.
#    -z, --null             NUL-separate output (safe for `xargs -0`).
#    -h, --help             Show usage information and exit.
#
#   Scope flags (-t / -u / -a) are mutually exclusive; the default is
#   tracked + untracked with .gitignore respected.
#
# Usage:
#   ./git-find.sh '<pattern>'                 # tracked + untracked, gitignore honoured
#   ./git-find.sh -t '\.py$'                  # tracked only
#   ./git-find.sh -u '\.py$'                  # untracked only
#   ./git-find.sh -i 'readme'                 # case-insensitive
#   ./git-find.sh -F 'src/lib.sh'             # literal match, no regex
#   ./git-find.sh -c '\.sh$'                  # count matches
#   ./git-find.sh -z '\.sh$' | xargs -0 wc -l # pipe safely into xargs
#   ./git-find.sh '\.md$' -- docs             # limit the search to docs/
#
#   Everything after `--` is passed to git as a pathspec, so the search can be
#   scoped to a subdirectory.
#
# One-liner equivalent:
#   # Default: tracked + untracked, respecting .gitignore
#   git ls-files --cached --others --exclude-standard | grep '<pattern>'
#
#   # Tracked only
#   git ls-files | grep '<pattern>'
#
#   # Untracked only (drop --cached)
#   git ls-files --others --exclude-standard | grep '<pattern>'
#
#   # Tracked + untracked including ignored files
#   git ls-files --cached --others | grep '<pattern>'
#
#   # NUL-safe variant for filenames with spaces or newlines
#   git ls-files -z --cached --others --exclude-standard | grep -z '<pattern>'
#
# Notes:
#   - Requires Bash shell and git.
#   - Must be executed from within a git repository.
#   - The pattern is a POSIX basic regular expression (grep default) unless
#     -F is given; it is matched against the whole path relative to the
#     repository root, not just the basename.
#   - Exits 1 when no path matches, mirroring grep's exit status.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
MODE="default"
MODE_FLAG=""
IGNORE_CASE=false
FIXED_STRINGS=false
COUNT_ONLY=false
NULL_OUT=false
PATTERN=""
PATHSPEC=()

set_mode() {
    if [[ -n "$MODE_FLAG" && "$MODE_FLAG" != "$1" ]]; then
        echo "Error: $MODE_FLAG and $1 are mutually exclusive."
        usage_helper
        exit 1
    fi
    MODE=$2
    MODE_FLAG=$1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tracked)
            set_mode "$1" tracked
            shift
            ;;
        -u|--untracked)
            set_mode "$1" untracked
            shift
            ;;
        -a|--all)
            set_mode "$1" all
            shift
            ;;
        -i|--ignore-case)
            IGNORE_CASE=true
            shift
            ;;
        -F|--fixed-strings)
            FIXED_STRINGS=true
            shift
            ;;
        -c|--count)
            COUNT_ONLY=true
            shift
            ;;
        -z|--null)
            NULL_OUT=true
            shift
            ;;
        -h|--help)
            usage_helper
            exit 0
            ;;
        --)
            shift
            PATHSPEC=("$@")
            break
            ;;
        -*)
            echo "Error: Unknown option $1"
            usage_helper
            exit 1
            ;;
        *)
            if [[ -n "$PATTERN" ]]; then
                echo "Error: Unexpected extra argument '$1'"
                usage_helper
                exit 1
            fi
            PATTERN=$1
            shift
            ;;
    esac
done

# ---- Input Validation ----
if [[ -z "$PATTERN" ]]; then
    echo "Error: <pattern> is required."
    usage_helper
    exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Error: Not inside a git repository."
    exit 1
fi

if $COUNT_ONLY && $NULL_OUT; then
    echo "Error: -c and -z are mutually exclusive."
    usage_helper
    exit 1
fi

# ---- Build git ls-files scope flags ----
LS_FLAGS=(-z)
case $MODE in
    tracked)   LS_FLAGS+=(--cached) ;;
    untracked) LS_FLAGS+=(--others --exclude-standard) ;;
    all)       LS_FLAGS+=(--cached --others) ;;
    *)         LS_FLAGS+=(--cached --others --exclude-standard) ;;
esac

# ---- Build grep flags ----
GREP_FLAGS=(-z)
$IGNORE_CASE && GREP_FLAGS+=(-i)
$FIXED_STRINGS && GREP_FLAGS+=(-F)

# ---- Execute search ----
# `sort -zu` gives a stable, de-duplicated ordering: git lists untracked paths
# before cached ones, so the raw stream is not sorted overall.
# The results are read into an array because command substitution would strip
# the NUL separators that keep unusual filenames intact.
matches=()
while IFS= read -r -d '' path; do
    matches+=("$path")
done < <(
    git ls-files "${LS_FLAGS[@]}" -- "${PATHSPEC[@]}" \
        | sort -zu \
        | { grep "${GREP_FLAGS[@]}" -- "$PATTERN" || true; }
)

if $COUNT_ONLY; then
    echo "${#matches[@]}"
    [[ ${#matches[@]} -gt 0 ]] || exit 1
    exit 0
fi

if [[ ${#matches[@]} -eq 0 ]]; then
    exit 1
fi

if $NULL_OUT; then
    printf '%s\0' "${matches[@]}"
else
    printf '%s\n' "${matches[@]}"
fi
