#!/bin/bash
# -----------------------------------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2026-09-11
# Script: git-sed.sh
# Description:
#   Replaces text in git-tracked, non-binary working-tree files selected by an
#   extended regular expression. Git determines the file set and sed performs
#   the replacement, so .gitignore and Git pathspecs are respected.
#
# Options:
#   --from ERE            Use ERE as sed's left-hand side instead of pattern.
#   --to STR              Use STR as sed's replacement instead of replacement.
#   -n, --dry-run         Preview replacements without writing files.
#   -i, --ignore-case     Match case-insensitively in git grep and sed.
#   -w, --word-regexp     Match whole words (sed wraps its LHS in \b ... \b).
#   --include GLOB        Include a pathspec glob (repeatable).
#   --exclude GLOB        Exclude a pathspec glob (repeatable).
#   --first               Replace only the first match on each line.
#   --ask                 Confirm each file: y/n/d/a/q.
#   --diff                Show git diff for files changed by this invocation.
#   --difftool            Run git difftool for files changed by this invocation.
#   --force               Allow replacements in files with uncommitted changes.
#   -h, --help            Show usage information and exit.
#
# Usage:
#   git-sed [options] <pattern> [<replacement>] [<revision>] [-- <pathspec>...]
#
# Examples:
#   git-sed 'foo_client' 'bar_client'
#   git-sed --from 'foo_([0-9]+)' --to 'bar_\1' 'foo_'
#   git-sed -n -i --include '*.py' 'old_name' 'new_name'
#   git-sed --ask 'https://old.example' 'https://new.example' -- src/
#
# Notes:
#   - Patterns use extended POSIX regular-expression syntax (ERE).
#   - A revision selects files only; replacements always affect the working tree.
#   - A missing replacement implies --dry-run.
#   - --word-regexp uses git grep's word semantics to select files and sed's
#     \b word boundaries to replace text; edge cases can differ between them.
# -----------------------------------------------------------------------------

set -euo pipefail

# shellcheck disable=SC1091
# shellcheck source=../lib/docstring.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

FROM=""; TO=""; TO_SET=false
DRY_RUN=false; IGNORE_CASE=false; WORD_REGEXP=false; FIRST_ONLY=false
ASK=false; SHOW_DIFF=false; SHOW_DIFFTOOL=false; FORCE=false
POSITIONAL=(); PATHSPECS=()

require_value() {
    if [[ $# -lt 2 ]]; then echo "Error: $1 requires a value." >&2; exit 1; fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --from) require_value "$@"; FROM=$2; shift 2 ;;
        --from=*) FROM=${1#*=}; shift ;;
        --to) require_value "$@"; TO=$2; TO_SET=true; shift 2 ;;
        --to=*) TO=${1#*=}; TO_SET=true; shift ;;
        -n|--dry-run) DRY_RUN=true; shift ;;
        -i|--ignore-case) IGNORE_CASE=true; shift ;;
        -w|--word-regexp) WORD_REGEXP=true; shift ;;
        --include) require_value "$@"; PATHSPECS+=("$2"); shift 2 ;;
        --include=*) PATHSPECS+=("${1#*=}"); shift ;;
        --exclude) require_value "$@"; PATHSPECS+=(":(exclude)$2"); shift 2 ;;
        --exclude=*) PATHSPECS+=(":(exclude)${1#*=}"); shift ;;
        --first) FIRST_ONLY=true; shift ;;
        --ask) ASK=true; shift ;;
        --diff) SHOW_DIFF=true; shift ;;
        --difftool) SHOW_DIFFTOOL=true; shift ;;
        --force) FORCE=true; shift ;;
        -h|--help) usage_helper; exit 0 ;;
        --) shift; PATHSPECS+=("$@"); break ;;
        -*) echo "Error: Unknown option $1" >&2; usage_helper >&2; exit 1 ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done

if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
    echo "Error: <pattern> is required." >&2; usage_helper >&2; exit 1
fi
if [[ ${#POSITIONAL[@]} -gt 3 ]]; then
    echo "Error: expected <pattern> [<replacement>] [<revision>]." >&2; usage_helper >&2; exit 1
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: Not inside a git repository." >&2; exit 1
fi

PATTERN=${POSITIONAL[0]}; REPLACEMENT=""; REPLACEMENT_SET=false; REVISION=""
if [[ ${#POSITIONAL[@]} -ge 2 ]]; then REPLACEMENT=${POSITIONAL[1]}; REPLACEMENT_SET=true; fi
if [[ ${#POSITIONAL[@]} -eq 3 ]]; then REVISION=${POSITIONAL[2]}; fi

SED_FROM=${FROM:-$PATTERN}
if $TO_SET; then SED_TO=$TO; else SED_TO=$REPLACEMENT; fi
if ! $REPLACEMENT_SET && ! $TO_SET; then DRY_RUN=true; fi

DELIMITER=""
for candidate in / '|' '#' '%' ',' '@' '^'; do
    if [[ $SED_FROM != *"$candidate"* && $SED_TO != *"$candidate"* ]]; then DELIMITER=$candidate; break; fi
done
if [[ -z $DELIMITER ]]; then
    echo "Error: could not choose a sed delimiter absent from --from and --to values." >&2; exit 1
fi

SED_LHS=$SED_FROM
if $WORD_REGEXP; then SED_LHS="\\b${SED_LHS}\\b"; fi
SED_FLAGS="g"
if $FIRST_ONLY; then SED_FLAGS=""; fi
if $IGNORE_CASE; then SED_FLAGS+="I"; fi
SED_EXPR="s${DELIMITER}${SED_LHS}${DELIMITER}${SED_TO}${DELIMITER}${SED_FLAGS}"

GREP_OPTIONS=(-l -I -z -E -e "$PATTERN")
if $IGNORE_CASE; then GREP_OPTIONS+=(-i); fi
if $WORD_REGEXP; then GREP_OPTIONS+=(-w); fi

FILES=()
collect_files() {
    local entry file status pid
    if [[ -n $REVISION ]]; then
        coproc GIT_GREP { git grep "${GREP_OPTIONS[@]}" "$REVISION" -- "${PATHSPECS[@]}"; }
    else
        coproc GIT_GREP { git grep "${GREP_OPTIONS[@]}" -- "${PATHSPECS[@]}"; }
    fi
    pid=$GIT_GREP_PID
    while IFS= read -r -d '' entry <&"${GIT_GREP[0]}"; do
        file=$entry
        if [[ -n $REVISION && $entry == "$REVISION:"* ]]; then file=${entry#"$REVISION":}; fi
        if [[ -n $REVISION && ! -e $file && ! -L $file ]]; then
            printf 'Warning: %s exists in %s but not in the working tree; skipping.\n' "$file" "$REVISION" >&2
            continue
        fi
        FILES+=("$file")
    done
    if wait "$pid"; then return 0; fi
    status=$?
    if [[ $status -eq 1 ]]; then return 1; fi
    return "$status"
}

if collect_files; then
    :
else
    status=$?
    if [[ $status -eq 1 ]]; then echo "No files matched."; exit 0; fi
    echo "Error: git grep failed." >&2; exit "$status"
fi
if [[ ${#FILES[@]} -eq 0 ]]; then echo "No files matched."; exit 0; fi

# Count by replacing matches with an otherwise absent control marker. This uses
# sed itself, avoiding a second implementation of ERE matching semantics.
count_replacements_in_line() {
    local line=$1 marker="" candidate marked markers count_expr
    for candidate in $'\001' $'\002' $'\003' $'\004' $'\005' $'\006' $'\007' $'\010' \
        $'\013' $'\014' $'\016' $'\017' $'\020' $'\021' $'\022' $'\023' $'\024' \
        $'\025' $'\026' $'\027' $'\030' $'\031' $'\032' $'\033' $'\034' $'\035' $'\036' $'\037'; do
        if [[ $line != *"$candidate"* ]]; then marker=$candidate; break; fi
    done
    if [[ -z $marker ]]; then echo "Error: cannot count replacements in this line." >&2; return 1; fi
    count_expr="s${DELIMITER}${SED_LHS}${DELIMITER}${marker}${DELIMITER}${SED_FLAGS}"
    marked=$(printf '%s\n' "$line" | sed -E -e "$count_expr")
    markers=${marked//[^$marker]/}
    printf '%s\n' "${#markers}"
}

count_replacements_in_file() {
    local file=$1 line count total=0
    while IFS= read -r line || [[ -n $line ]]; do
        count=$(count_replacements_in_line "$line")
        total=$((total + count))
    done < "$file"
    printf '%s\n' "$total"
}

print_preview_file() {
    local file=$1 line after line_number=0 printed=false
    while IFS= read -r line || [[ -n $line ]]; do
        line_number=$((line_number + 1))
        after=$(printf '%s\n' "$line" | sed -E -e "$SED_EXPR")
        if [[ $line != "$after" ]]; then
            if ! $printed; then printf '%s\n' "$file"; printed=true; fi
            printf '  %d: -  %s\n      +  %s\n' "$line_number" "$line" "$after"
        fi
    done < "$file"
    if $printed; then printf '\n'; fi
}

APPLY_FILES=(); REPLACEMENT_COUNTS=(); TOTAL_REPLACEMENTS=0
for file in "${FILES[@]}"; do
    count=$(count_replacements_in_file "$file")
    if [[ $count -gt 0 ]]; then
        APPLY_FILES+=("$file"); REPLACEMENT_COUNTS+=("$count")
        TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + count))
    fi
done
if [[ ${#APPLY_FILES[@]} -eq 0 ]]; then echo "No replacements would be made."; exit 0; fi

if $DRY_RUN; then
    for file in "${APPLY_FILES[@]}"; do print_preview_file "$file"; done
    printf '%d files, %d replacements (dry run; nothing written)\n' "${#APPLY_FILES[@]}" "$TOTAL_REPLACEMENTS"
    exit 0
fi

if ! $FORCE; then
    dirty_files=()
    for file in "${APPLY_FILES[@]}"; do
        if ! git diff --quiet -- "$file" || ! git diff --cached --quiet -- "$file"; then dirty_files+=("$file"); fi
    done
    if [[ ${#dirty_files[@]} -gt 0 ]]; then
        echo "Error: refusing to modify files with uncommitted changes (use --force to override):" >&2
        printf '  %s\n' "${dirty_files[@]}" >&2
        exit 1
    fi
fi

TOUCHED=()
apply_file() { local file=$1; sed -E -i -e "$SED_EXPR" -- "$file"; TOUCHED+=("$file"); }

if $ASK; then
    if [[ ! -r /dev/tty ]]; then echo "Error: --ask requires a controlling terminal." >&2; exit 1; fi
    apply_all=false; stopped=false
    for index in "${!APPLY_FILES[@]}"; do
        file=${APPLY_FILES[index]}
        if $apply_all; then apply_file "$file"; continue; fi
        while true; do
            print_preview_file "$file"
            printf 'Apply to this file? [y/n/d/a/q] ' >/dev/tty
            if ! IFS= read -r answer </dev/tty; then echo "Error: could not read an answer from /dev/tty." >&2; exit 1; fi
            case $answer in
                y|Y) apply_file "$file"; break ;;
                n|N) break ;;
                d|D) git diff --no-index -- "$file" <(sed -E -e "$SED_EXPR" -- "$file") || true ;;
                a|A) apply_file "$file"; apply_all=true; break ;;
                q|Q) stopped=true; break 2 ;;
                *) echo "Please answer y, n, d, a, or q." >/dev/tty ;;
            esac
        done
    done
    if $stopped; then echo "Stopped; already applied changes were kept."; fi
else
    printf '%s\0' "${APPLY_FILES[@]}" | xargs -0 sed -E -i -e "$SED_EXPR" --
    TOUCHED=("${APPLY_FILES[@]}")
fi

if [[ ${#TOUCHED[@]} -gt 0 ]]; then
    if $SHOW_DIFF; then git diff -- "${TOUCHED[@]}"; fi
    if $SHOW_DIFFTOOL; then git difftool -- "${TOUCHED[@]}"; fi
fi
