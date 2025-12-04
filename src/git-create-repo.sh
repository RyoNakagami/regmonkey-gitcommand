#!/bin/bash
# ------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2025-10-21
# Script: git-create-repo.sh
# Description:
#   Creates a GitHub repository using GitHub CLI based on
#   a YAML metadata file that defines the repository name
#   and visibility.
#
# Usage:
#   ./git-create-repo.sh                       # Uses default YAML file
#   ./git-create-repo.sh /path/to/gh-meta.yml  # Specify custom YAML file
#
# Notes:
#   - Requires GitHub CLI (gh) installed and authenticated.
#   - Requires yamlcli installed to parse YAML files.
#   - tags must not contain spaces.
# ------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# ---- Show usage ----
while getopts ":h-:" opt; do
  case $opt in
    h)
      usage_helper "$0" 
      exit 1
      ;;
    -)
      case "${OPTARG}" in
        help)
          usage_helper "$0" 
          exit 1
          ;;
        *)
          echo "Error: Unknown option --${OPTARG}" >&2
          exit 1
          ;;
      esac
      ;;
    \?)
      echo "Error: Invalid option -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))



# Determine the default YAML metadata file in the current Git repo
if [[ -z "${1-}" ]]; then
    # Get the root of the current Git repo
    GIT_ROOT=$(git rev-parse --show-toplevel)
    META_FILE="$GIT_ROOT/.github/repository_metadata/gh_repo.yml"
else
    META_FILE="$1"
fi

# Check if file exists
if [[ ! -f "$META_FILE" ]]; then
    echo "Error: YAML metadata file not found: $META_FILE" >&2
    exit 1
fi

# Check if file extension is .yml or .yaml
if [[ "$META_FILE" != *.yml && "$META_FILE" != *.yaml ]]; then
    echo "Error: YAML metadata file must have .yml or .yaml extension: $META_FILE" >&2
    exit 1
fi

# Extract repository name and visibility
repo_name=$(yamlcli --to-json "$META_FILE" | jq -r '.["meta-data"].repository_name')
visibility=$(yamlcli --to-json "$META_FILE" | jq -r '.["meta-data"].visibility')
org=$(yamlcli --to-json "$META_FILE" | jq -r '.["meta-data"].org_name // empty')

if [[ -z "$repo_name" ]]; then
    echo "Error: Repository name not defined in YAML file" >&2
    exit 1
fi

# Validate visibility
if [[ "$visibility" != "public" && "$visibility" != "private" && "$visibility" != "internal" ]]; then
    echo "Error: Visibility must be one of public, private, internal" >&2
    exit 1
fi

if [[ -n "$org" ]]; then
    full_repo_name="$org/$repo_name"
else
    full_repo_name="$repo_name"
fi

# Build gh repo create command
cmd="gh repo create \"$full_repo_name\" --$visibility --source=\"$GIT_ROOT\" --remote=origin --push"

# Ask user for confirmation
echo "About to create the repository with the following settings:
- Name: $repo_name
- Visibility: $visibility
- Source: $GIT_ROOT
- Remote: origin

Do you want to proceed? (y/n)"
read -r confirm
if [[ "$confirm" != "y" ]]; then
    echo "Aborting repository creation."
    exit 0
fi

# Execute the command
eval "$cmd"
