#!/bin/bash
# -----------------------------------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2025-10-29
# Script: docstring.sh
# Description:
#   This script provides utilities for extracting and displaying
#   the docstring (comment block) from the top of a specified file.
#
# Usage:
#   # As a library (recommended):
#   source ./docstring.sh
#   usage_helper "$0"          # Display the current script's docstring
#
# Notes:
#   - Requires Bash shell.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Description:
#   Extracts and prints the top-level docstring from a given file.
#   The function:
#     - Skips a leading shebang line (#!...) if present.
#     - Captures the first contiguous block of comment lines ('# ...')
#       that appear at the top of the file.
#     - Stops reading when a non-comment line is encountered after the block.
#
# Globals:
#   None
#
# Arguments:
#   $1 : Path to the file from which to extract the docstring.
#
# Outputs:
#   STDOUT : The extracted docstring text (with '#' prefixes removed).
#   STDERR : Error messages when the file is missing, unreadable, or has no docstring.
#
# Returns:
#   0 : Successfully printed a docstring.
#   2 : Missing file argument.
#   3 : File is unreadable.
#   4 : No docstring found.
# -----------------------------------------------------------------------------

print_docstring() {
  local file="${1:-}"
  if [[ -z "$file" ]]; then
    echo "print_docstring: missing file argument" >&2
    return 2
  fi
  if [[ ! -r "$file" ]]; then
    echo "print_docstring: cannot read file: $file" >&2
    return 3
  fi

  local started=false
  local line
  local printed=false

  while IFS=$'\n' read -r line || [[ -n "$line" ]]; do
    # If it's a shebang exactly at first line, skip it but don't mark started
    if ! $started && [[ "$line" =~ ^\#! ]]; then
      continue
    fi

    # Trim leading spaces for detection
    if [[ "$line" =~ ^[[:space:]]*# ]]; then
      started=true
      # Remove leading '#' and a single following space if present (for nicer display)
      # Preserve indentation after the comment marker.
      # Example: "#   foo" -> "  foo"
      local content="${line#[[:space:]]#}"
      # If comment marker was followed by a space, remove one space:
      if [[ "$content" =~ ^[[:space:]] ]]; then
        content="${content# }"
      fi
      printf '%s\n' "$content"
      printed=true
    else
      # If we've started and encounter a non-comment line (not blank or code), stop.
      if $started; then
        break
      fi
      # If not started and this is an empty line, skip; but if non-empty and not comment, then nothing to print.
      if [[ -n "${line//[[:space:]]/}" ]]; then
        # non-comment content before any comment header -> no docstring
        break
      fi
    fi
  done < "$file"

  if ! $printed; then
    return 4
  fi
  return 0
}

# -----------------------------------------------------------------------------
# Function: usage_helper
#
# Description:
#   Print the docstring/header of a target file using print_docstring().
#   Intended to be sourced by other scripts to implement `-h|--help` behavior.
#   If no argument is provided, the function defaults to the invoking script ($0).
#
# Globals:
#   None (relies on the externally defined print_docstring function)
#
# Arguments:
#   $1 : (optional) Path to the target file whose docstring should be printed.
#        If omitted, defaults to the current script ($0).
#
# Outputs:
#   STDOUT : The docstring text emitted by print_docstring() when found.
#   STDERR : Error message when no docstring/header is found or print_docstring fails.
#
# Returns:
#   0 : Successfully printed the docstring.
#   1 : print_docstring failed (no docstring/header found or other error).
# -----------------------------------------------------------------------------
usage_helper() {
  local target="${1:-$0}"
  if ! print_docstring "$target"; then
    echo "No docstring/header found in: $target" >&2
    return 1
  fi
  return 0
}
