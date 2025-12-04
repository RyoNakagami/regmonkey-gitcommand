#!/bin/bash
# ------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2025-10-20
# Script: git-gh-repo-update.sh
# Description:
#   Updates the GitHub repository description and topics
#   based on a YAML metadata file.
#
#   Steps:
#     1. Reads the YAML file for description and tags.
#     2. Constructs a `gh repo edit` command.
#     3. Updates the GitHub repository using GitHub CLI.
#
# Usage:
#   ./git-gh-repo-update.sh                       # Updates the repo using the default YAML file
#   ./git-gh-repo-update.sh /path/to/gh-meta.yml  # Specify a custom YAML file
#
# Notes:
#   - Requires GitHub CLI (gh) installed and authenticated.
#   - Requires yamlcli installed to parse yaml files.
#   - Requires jq installed to parse JSON files.
# ------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

# Parse options
while getopts "h" opt; do
    case $opt in
        h)
            usage_helper "$0"
            exit 1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

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

# Extract description
desc=$(yamlcli --to-json $META_FILE | jq -r '.["meta-data"].description')
homepage=$(yamlcli --to-json $META_FILE | jq -r '.["meta-data"].homepage // empty')

# Fetch existing topics from GitHub
mapfile -t existing_topics < <(
  gh repo view --json repositoryTopics \
  | jq -r '.repositoryTopics | if . == null then [] else . end | .[].name'
)


# YAML topics
mapfile -t yaml_topics < <(yamlcli --to-json "$META_FILE" | jq -r '.["meta-data"].tag[]')


# Topics to remove: exist in GitHub but NOT in YAML
remove_topics=()
for t in "${existing_topics[@]}"; do
    if [[ ! " ${yaml_topics[*]} " =~ " $t " ]]; then
        remove_topics+=("$t")
    fi
done


# Build gh repo edit command
cmd="gh repo edit --description \"$desc\" --homepage \"$homepage\""
for topic in "${yaml_topics[@]}"; do
    cmd+=" --add-topic $topic"
done

# Remove old topics
for topic in "${remove_topics[@]}"; do
    cmd+=" --remove-topic $topic"
done


# Ask user for confirmation
echo "About to update the repository with the following:"
echo "$cmd"
read -r -p "Do you want to proceed? [y/N]: " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then # regex match for y or Y
    echo "Running: $cmd"
    eval "$cmd"
else
    echo "Aborted."
    exit 1
fi
