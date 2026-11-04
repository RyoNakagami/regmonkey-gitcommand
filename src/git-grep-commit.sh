#!/bin/bash
# -----------------------------------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2026-09-08
# Script: git-grep-commit.sh
# Description:
#   Finds commits whose patches add or remove text matching a regular expression
#   (`git log -G`) and reports the affected paths grouped by commit.
#
# Options:
#    -f, --format FORMAT   Output format: table (default), json, or yml.
#    -i, --ignore-case     Match the patch regex case-insensitively.
#    --long-date           Display the author date in ISO 8601 format (%ai).
#    --short-date          Display the author date as YYYY-MM-DD (%as).
#    --diff-filter FILTER  Apply git's native status filter. Uppercase letters
#                          include statuses, lowercase letters exclude them,
#                          and * enables git's all-or-none behavior.
#    -h, --help            Show usage information and exit.
#
# Usage:
#   git-grep-commit.sh [options] <regex> [<revision> ...] [-- <pathspec> ...]
#
# Examples:
#   git-grep-commit.sh 'TODO'
#   git-grep-commit.sh -i 'todo' HEAD~20..HEAD
#   git-grep-commit.sh 'TODO' HEAD~20..HEAD -- '*.qmd'
#   git-grep-commit.sh --diff-filter=AM 'TODO' HEAD~20..HEAD
#   git-grep-commit.sh --diff-filter=ad 'TODO' HEAD~20..HEAD
#   git-grep-commit.sh --format json 'TODO' HEAD~20..HEAD -- ':(glob)**/*.qmd'
#   git-grep-commit.sh -f yml 'TODO' -- docs/
#
# Notes:
#   - Requires Bash shell and git.
#   - Must be executed from within a git repository.
#   - The regex uses git's extended POSIX regular-expression syntax.
#   - Revisions are passed to `git log`; when omitted, HEAD is used.
#   - Everything after `--` is passed to git unchanged as a pathspec.
#   - Rename/copy records use old_path and path in JSON/YAML output, and are
#     displayed as "old path -> new path" in table output.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Process command line arguments ----
OUTPUT_FORMAT="table"
IGNORE_CASE=false
DATE_FORMAT=""
DIFF_FILTER_OPTIONS=()
POSITIONAL=()
PATHSPECS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--format)
            if [[ $# -lt 2 ]]; then
                echo "Error: $1 requires a format (table, json, or yml)." >&2
                exit 1
            fi
            OUTPUT_FORMAT=$2
            shift 2
            ;;
        --format=*)
            OUTPUT_FORMAT=${1#*=}
            shift
            ;;
        -i|--ignore-case)
            IGNORE_CASE=true
            shift
            ;;
        --long-date)
            DATE_FORMAT='%ai'
            shift
            ;;
        --short-date)
            DATE_FORMAT='%as'
            shift
            ;;
        --diff-filter)
            if [[ $# -lt 2 ]]; then
                echo "Error: $1 requires a git diff-filter value." >&2
                exit 1
            fi
            DIFF_FILTER_OPTIONS+=(--diff-filter="$2")
            shift 2
            ;;
        --diff-filter=*)
            DIFF_FILTER_OPTIONS+=("$1")
            shift
            ;;
        -h|--help)
            usage_helper
            exit 0
            ;;
        --)
            shift
            PATHSPECS=("$@")
            break
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            usage_helper >&2
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

case $OUTPUT_FORMAT in
    table|json|yml)
        ;;
    yaml)
        OUTPUT_FORMAT="yml"
        ;;
    *)
        echo "Error: Unsupported format '$OUTPUT_FORMAT' (use table, json, or yml)." >&2
        exit 1
        ;;
esac

if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
    echo "Error: <regex> is required." >&2
    usage_helper >&2
    exit 1
fi

PATTERN=${POSITIONAL[0]}
REVISIONS=("${POSITIONAL[@]:1}")
if [[ ${#REVISIONS[@]} -eq 0 ]]; then
    REVISIONS=(HEAD)
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: Not inside a git repository." >&2
    exit 1
fi

# ---- Collect NUL-delimited git output ----
# Record separator (0x1e) distinguishes a commit field from a status field.
# `-z` makes paths safe even when they contain spaces, tabs, or newlines.
LOG_FILE=$(mktemp "${TMPDIR:-/tmp}/git-grep-commit.XXXXXX")
trap 'rm -f "$LOG_FILE"' EXIT HUP INT TERM

PRETTY_FORMAT='%x1e%h'
if [[ -n $DATE_FORMAT ]]; then
    PRETTY_FORMAT+="%x1f${DATE_FORMAT}"
fi

GIT_LOG_OPTIONS=(-z -G "$PATTERN" --format="$PRETTY_FORMAT" --name-status)
if $IGNORE_CASE; then
    GIT_LOG_OPTIONS+=(--regexp-ignore-case)
fi
if [[ ${#DIFF_FILTER_OPTIONS[@]} -gt 0 ]]; then
    GIT_LOG_OPTIONS+=("${DIFF_FILTER_OPTIONS[@]}")
fi

if ! git log "${GIT_LOG_OPTIONS[@]}" \
    "${REVISIONS[@]}" -- "${PATHSPECS[@]}" >"$LOG_FILE"; then
    exit 1
fi

RECORD_COMMITS=()
RECORD_DATES=()
RECORD_STATUSES=()
RECORD_PATHS=()
RECORD_OLD_PATHS=()
current_commit=""
current_date=""

exec 3<"$LOG_FILE"
while IFS= read -r -d '' field <&3; do
    if [[ $field == $'\x1e'* ]]; then
        commit_field=${field#$'\x1e'}
        if [[ -n $DATE_FORMAT ]]; then
            current_commit=${commit_field%%$'\x1f'*}
            current_date=${commit_field#*$'\x1f'}
        else
            current_commit=$commit_field
            current_date=""
        fi
        continue
    fi

    if [[ -z "$current_commit" ]]; then
        echo "Error: Could not parse git log output." >&2
        exit 1
    fi

    status=${field#$'\n'}
    if ! IFS= read -r -d '' first_path <&3; then
        echo "Error: Incomplete path record in git log output." >&2
        exit 1
    fi

    old_path=""
    path=$first_path
    if [[ $status == R* || $status == C* ]]; then
        old_path=$first_path
        if ! IFS= read -r -d '' path <&3; then
            echo "Error: Incomplete rename/copy record in git log output." >&2
            exit 1
        fi
    fi

    RECORD_COMMITS+=("$current_commit")
    RECORD_DATES+=("$current_date")
    RECORD_STATUSES+=("$status")
    RECORD_PATHS+=("$path")
    RECORD_OLD_PATHS+=("$old_path")
done
exec 3<&-

# ---- Output helpers ----
json_quote() {
    local value=$1
    local result='"'
    local char escaped code i
    local LC_ALL=C

    for ((i = 0; i < ${#value}; i++)); do
        char=${value:i:1}
        case $char in
            '"') result+='\"' ;;
            $'\\') result+='\\' ;;
            $'\b') result+='\b' ;;
            $'\f') result+='\f' ;;
            $'\n') result+='\n' ;;
            $'\r') result+='\r' ;;
            $'\t') result+='\t' ;;
            *)
                printf -v code '%d' "'$char"
                if ((code < 32)); then
                    printf -v escaped '\\u%04x' "$code"
                    result+=$escaped
                else
                    result+=$char
                fi
                ;;
        esac
    done

    printf '%s"' "$result"
}

table_escape() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

emit_json() {
    local i=0
    local j commit outer_sep="" file_sep

    printf '[\n'
    while ((i < ${#RECORD_COMMITS[@]})); do
        commit=${RECORD_COMMITS[i]}
        printf '%s  {"commit": %s' "$outer_sep" "$(json_quote "$commit")"
        if [[ -n $DATE_FORMAT ]]; then
            printf ', "date": %s' "$(json_quote "${RECORD_DATES[i]}")"
        fi
        printf ', "files": [\n'
        j=$i
        file_sep=""
        while ((j < ${#RECORD_COMMITS[@]})) && [[ ${RECORD_COMMITS[j]} == "$commit" ]]; do
            printf '%s    {"status": %s, ' "$file_sep" "$(json_quote "${RECORD_STATUSES[j]}")"
            if [[ -n ${RECORD_OLD_PATHS[j]} ]]; then
                printf '"old_path": %s, ' "$(json_quote "${RECORD_OLD_PATHS[j]}")"
            fi
            printf '"path": %s}' "$(json_quote "${RECORD_PATHS[j]}")"
            file_sep=$',\n'
            ((j += 1))
        done
        printf '\n  ]}'
        outer_sep=$',\n'
        i=$j
    done
    printf '\n]\n'
}

emit_yml() {
    local i=0
    local j commit

    if [[ ${#RECORD_COMMITS[@]} -eq 0 ]]; then
        printf '[]\n'
        return
    fi

    while ((i < ${#RECORD_COMMITS[@]})); do
        commit=${RECORD_COMMITS[i]}
        printf -- '- commit: %s\n' "$(json_quote "$commit")"
        if [[ -n $DATE_FORMAT ]]; then
            printf '  date: %s\n' "$(json_quote "${RECORD_DATES[i]}")"
        fi
        printf '  files:\n'
        j=$i
        while ((j < ${#RECORD_COMMITS[@]})) && [[ ${RECORD_COMMITS[j]} == "$commit" ]]; do
            printf '    - status: %s\n' "$(json_quote "${RECORD_STATUSES[j]}")"
            if [[ -n ${RECORD_OLD_PATHS[j]} ]]; then
                printf '      old_path: %s\n' "$(json_quote "${RECORD_OLD_PATHS[j]}")"
            fi
            printf '      path: %s\n' "$(json_quote "${RECORD_PATHS[j]}")"
            ((j += 1))
        done
        i=$j
    done
}

emit_table() {
    local commit_width=6
    local date_width=4
    local status_width=6
    local path_width=4
    local display_path line
    local i total_width
    local table_paths=()

    for ((i = 0; i < ${#RECORD_COMMITS[@]}; i++)); do
        display_path=$(table_escape "${RECORD_PATHS[i]}")
        if [[ -n ${RECORD_OLD_PATHS[i]} ]]; then
            display_path="$(table_escape "${RECORD_OLD_PATHS[i]}") -> $display_path"
        fi
        table_paths+=("$display_path")

        ((${#RECORD_COMMITS[i]} > commit_width)) && commit_width=${#RECORD_COMMITS[i]}
        ((${#RECORD_DATES[i]} > date_width)) && date_width=${#RECORD_DATES[i]}
        ((${#RECORD_STATUSES[i]} > status_width)) && status_width=${#RECORD_STATUSES[i]}
        ((${#display_path} > path_width)) && path_width=${#display_path}
    done

    if [[ -n $DATE_FORMAT ]]; then
        printf '%-*s  %-*s  %-*s  %s\n' \
            "$commit_width" COMMIT "$date_width" DATE "$status_width" STATUS PATH
        total_width=$((commit_width + date_width + status_width + path_width + 6))
    else
        printf '%-*s  %-*s  %s\n' "$commit_width" COMMIT "$status_width" STATUS PATH
        total_width=$((commit_width + status_width + path_width + 4))
    fi
    printf -v line '%*s' "$total_width" ''
    printf '%s\n' "${line// /-}"

    for ((i = 0; i < ${#RECORD_COMMITS[@]}; i++)); do
        if [[ -n $DATE_FORMAT ]]; then
            printf '%-*s  %-*s  %-*s  %s\n' \
                "$commit_width" "${RECORD_COMMITS[i]}" \
                "$date_width" "${RECORD_DATES[i]}" \
                "$status_width" "${RECORD_STATUSES[i]}" \
                "${table_paths[i]}"
        else
            printf '%-*s  %-*s  %s\n' \
                "$commit_width" "${RECORD_COMMITS[i]}" \
                "$status_width" "${RECORD_STATUSES[i]}" \
                "${table_paths[i]}"
        fi
    done
}

case $OUTPUT_FORMAT in
    json) emit_json ;;
    yml) emit_yml ;;
    table) emit_table ;;
esac
