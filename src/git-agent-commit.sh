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
#    --codex            Use the `codex` CLI instead of `claude` for generation
#    --rule <path>      Read a branch rule file and include it in the prompt
#                       so the generated message follows the project's rules
#    --model <model>    Claude model to use (default: claude-sonnet-4-6)
#    --exclude <pat>    Pathspec to exclude from diff (repeatable).
#                       Accepts a plain pattern or a git magic pathspec:
#                         plain      '*.lock'            -> :(exclude)*.lock
#                         short      ':!*.lock'          -> kept as-is
#                                    ':^*.lock'          -> kept as-is
#                         long       ':(glob)**/*.lock'  -> :(exclude,glob)**/*.lock
#                                    ':(exclude,icase)X' -> kept as-is
#    -h, --help         Show this help message
#
# Usage:
#   ./git-gen-commit.sh                                      # Generate and commit (claude)
#   ./git-gen-commit.sh --dryrun                             # Show message only
#   ./git-gen-commit.sh --codex                              # Generate via codex instead
#   ./git-gen-commit.sh --rule .claude/commit-rule.md
#   ./git-gen-commit.sh --model claude-sonnet-4-6
#   ./git-gen-commit.sh --exclude '*.lock' --exclude 'Cargo.lock'
#   ./git-gen-commit.sh --exclude ':(glob)**/*.lock'         # magic pathspec
#   ./git-gen-commit.sh --exclude ':(icase,glob)**/*.LOCK'
#   ./git-gen-commit.sh --exclude ':!docs/**'                # already an exclude
#
# Notes:
#   - Requires the `claude` CLI on PATH (or `codex` when --codex is given).
#   - Must be run from within a git repository with staged changes.
#   - `--exclude` always yields an *excluding* pathspec: the `exclude` magic word
#     is injected when absent, and other magic words are preserved.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# -----------------------------------------------------------------------------
# Function: to_exclude_pathspec
#
# Description:
#   Normalise a user-supplied `--exclude` value into a git pathspec that is
#   guaranteed to exclude, while preserving any magic the user already wrote.
#
#   Handled forms:
#     'a/b'                  -> ':(exclude)a/b'          (plain path, no magic)
#     ':!a/b' / ':^a/b'      -> unchanged                (short exclude magic)
#     ':(glob)a/b'           -> ':(exclude,glob)a/b'     (long magic, add exclude)
#     ':(exclude,icase)a/b'  -> unchanged                (already excluding)
#     ':/a/b'                -> ':(exclude,top)a/b'      (short 'top' magic)
#     ':'                    -> rejected (matches everything; excluding it is a no-op)
#
# Arguments:
#   $1 : raw pathspec from the command line.
#
# Outputs:
#   STDOUT : the normalised excluding pathspec.
#   STDERR : error message when the pathspec cannot be normalised.
#
# Returns:
#   0 : success.
#   1 : unsupported or malformed pathspec.
# -----------------------------------------------------------------------------
to_exclude_pathspec() {
    local raw="$1"

    # No magic at all -> plain path.
    if [[ "$raw" != :* ]]; then
        printf ':(exclude)%s\n' "$raw"
        return 0
    fi

    # Bare ':' means "everything"; excluding it would drop the whole diff.
    if [[ "$raw" == ":" ]]; then
        echo "Error: --exclude does not accept the bare ':' pathspec" >&2
        return 1
    fi

    # Long form: ':(magic,words)pattern'
    if [[ "$raw" == :\(* ]]; then
        if [[ "$raw" != *")"* ]]; then
            echo "Error: unterminated magic pathspec: $raw" >&2
            return 1
        fi
        local magic="${raw#:(}"
        magic="${magic%%)*}"
        local pattern="${raw#*)}"

        # Already excluding? keep verbatim.
        if [[ ",${magic}," == *",exclude,"* ]]; then
            printf '%s\n' "$raw"
            return 0
        fi
        if [[ -z "$magic" ]]; then
            printf ':(exclude)%s\n' "$pattern"
        else
            printf ':(exclude,%s)%s\n' "$magic" "$pattern"
        fi
        return 0
    fi

    # Short form: a run of magic signature characters after ':'.
    local sig="${raw:1}"
    sig="${sig%%[!!^/]*}"
    local pattern="${raw:$(( ${#sig} + 1 ))}"

    if [[ -z "$sig" ]]; then
        echo "Error: unsupported magic pathspec: $raw" >&2
        return 1
    fi

    # '!' or '^' already means exclude -> keep verbatim.
    if [[ "$sig" == *"!"* || "$sig" == *"^"* ]]; then
        printf '%s\n' "$raw"
        return 0
    fi

    # Only 'top' (/) remains; express it in long form together with exclude.
    printf ':(exclude,top)%s\n' "$pattern"
    return 0
}

# ---- Process command line arguments ----
DRY_RUN=false
USE_CODEX=false
RULE_PATH=""
MODEL="claude-sonnet-4-6"
EXCLUDES=()
normalized=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dryrun)
            DRY_RUN=true
            shift
            ;;
        --codex)
            USE_CODEX=true
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
        --model)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                echo "Error: --model requires an argument"
                usage_helper
                exit 1
            fi
            MODEL=$2
            shift 2
            ;;
        --exclude)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                echo "Error: --exclude requires a pattern argument"
                usage_helper
                exit 1
            fi
            if ! normalized=$(to_exclude_pathspec "$2"); then
                exit 1
            fi
            EXCLUDES+=("$normalized")
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
if $USE_CODEX; then
    if ! command -v codex >/dev/null 2>&1; then
        echo "❌ 'codex' CLI not found on PATH."
        exit 1
    fi
else
    if ! command -v claude >/dev/null 2>&1; then
        echo "❌ 'claude' CLI not found on PATH."
        exit 1
    fi
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
DIFF_ARGS=()
for ex in "${EXCLUDES[@]+"${EXCLUDES[@]}"}"; do
    DIFF_ARGS+=("$ex")
done

if $USE_CODEX; then
    DIFF=$(git diff --cached -- "${DIFF_ARGS[@]+"${DIFF_ARGS[@]}"}")
    COMBINED="${PROMPT}

--- staged diff ---
${DIFF}
--- end diff ---"
    TMPFILE="$(mktemp)"
    trap 'rm -f "$TMPFILE"' EXIT
    codex exec --dangerously-bypass-approvals-and-sandbox \
        -o "$TMPFILE" "$COMBINED" >/dev/null 2>&1
    MESSAGE=$(sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//' "$TMPFILE")
else
    MESSAGE=$(git diff --cached -- "${DIFF_ARGS[@]+"${DIFF_ARGS[@]}"}" \
        | claude -p "$PROMPT" --model "$MODEL" \
        | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//')
fi

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
