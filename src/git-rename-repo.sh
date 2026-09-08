#!/bin/bash
# ------------------------------------------------
# Author: Ryo Nakagami
# Revised: 2026-09-08
# Script: git-rename-repo.sh
# Description:
#   Renames the current GitHub repository to the repository name
#   defined in a YAML metadata file.
#
# Usage:
#   ./git-rename-repo.sh                       # Uses the default YAML file
#   ./git-rename-repo.sh /path/to/gh-meta.yml  # Uses a custom YAML file
#   ./git-rename-repo.sh -n                    # Dry-run
#
# When you use HTTPS
# git remote set-url origin https://github.com/your-username/new-repository-name.git
#
# When you use SSH
# git remote set-url origin git@github.com:your-username/new-repository-name.git
#
# Notes:
#   - Requires GitHub CLI (gh) installed and authenticated.
#   - Requires yamlcli and jq to parse YAML files.
#   - Renaming cannot transfer a repository to another owner.
# ------------------------------------------------

set -euo pipefail

# ---- Load dependencies ----
# shellcheck disable=SC1091  # Resolve relative to this script at runtime.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docstring.sh"

DRY_RUN=false

# ---- Show usage / parse options ----
while getopts ":nh-:" opt; do
    case "$opt" in
        n)
            DRY_RUN=true
            ;;
        h)
            usage_helper "$0"
            exit 0
            ;;
        -)
            case "${OPTARG}" in
                dry-run)
                    DRY_RUN=true
                    ;;
                help)
                    usage_helper "$0"
                    exit 0
                    ;;
                *)
                    echo "Error: Unknown option --${OPTARG}" >&2
                    exit 1
                    ;;
            esac
            ;;
        \?)
            echo "Error: Invalid option -${OPTARG}" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -gt 1 ]]; then
    echo "Error: Too many arguments" >&2
    exit 1
fi

for command_name in git gh yamlcli jq; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Error: Required command not found: $command_name" >&2
        exit 1
    fi
done

# Determine the default YAML metadata file in the current Git repository.
GIT_ROOT=$(git rev-parse --show-toplevel)
if [[ $# -eq 0 ]]; then
    META_FILE="$GIT_ROOT/.github/repository_metadata/gh_repo.yml"
else
    META_FILE="$1"
fi

if [[ ! -f "$META_FILE" ]]; then
    echo "Error: YAML metadata file not found: $META_FILE" >&2
    exit 1
fi

if [[ "$META_FILE" != *.yml && "$META_FILE" != *.yaml ]]; then
    echo "Error: YAML metadata file must have a .yml or .yaml extension: $META_FILE" >&2
    exit 1
fi

metadata_json=$(yamlcli --to-json "$META_FILE")
new_repo_name=$(jq -r '.["meta-data"].repository_name // empty' <<<"$metadata_json")
# `org-name` is the metadata key used by gh_repo.yml. Keep `org_name` as a
# fallback for metadata files created for older versions of git-create-repo.sh.
metadata_owner=$(jq -r '.["meta-data"]["org-name"] // .["meta-data"].org_name // empty' <<<"$metadata_json")

if [[ -z "$new_repo_name" ]]; then
    echo "Error: Repository name is not defined in YAML file" >&2
    exit 1
fi

if [[ "$new_repo_name" == */* || "$new_repo_name" =~ [[:space:]] ]]; then
    echo "Error: repository_name must be a repository name without an owner or spaces: $new_repo_name" >&2
    exit 1
fi

current_repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
current_owner=${current_repo%%/*}
current_repo_name=${current_repo#*/}

if [[ -n "$metadata_owner" && "${metadata_owner,,}" != "${current_owner,,}" ]]; then
    echo "Error: Repository owner in YAML ('$metadata_owner') does not match the current owner ('$current_owner')." >&2
    echo "       'gh repo rename' cannot transfer repository ownership." >&2
    exit 1
fi

if [[ "$new_repo_name" == "$current_repo_name" ]]; then
    echo "Repository name is already '$current_repo'. No rename is needed."
    exit 0
fi

echo "About to rename the GitHub repository:"
echo "- Current: $current_repo"
echo "- New:     $current_owner/$new_repo_name"
echo "- Metadata: $META_FILE"

if $DRY_RUN; then
    echo "gh repo rename $new_repo_name --repo $current_repo --yes"
    echo "[Dry run] No changes were made."
    exit 0
fi

read -r -p "Do you want to proceed? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

gh repo rename "$new_repo_name" --repo "$current_repo" --yes
echo "Repository renamed to '$current_owner/$new_repo_name'."
