# Git Helper Scripts Documentation

A collection of git helper scripts to enhance your git workflow. Every entry below ships with a **One-liner equivalent** section showing how to achieve the same result using plain git (and standard CLI tools), so the scripts stay transparent and easy to fall back from.

## Table of Contents

- [git-add-gitkeep](#git-add-gitkeep) - Stage every `.gitkeep` file in the repo
- [git-add-newline](#git-add-newline) - Add missing trailing newlines to tracked files
- [git-add-patch](#git-add-patch) - Interactive `git add -p` with directory / keyword filters
- [git-agent-commit](#git-agent-commit) - Generate a commit message from the staged diff via an LLM CLI
- [git-browse](#git-browse) - Open repository URL in browser
- [git-check-commitsize](#git-check-commitsize) - Analyze commit sizes in repository
- [git-create-repo](#git-create-repo) - Create a GitHub repository from a YAML metadata file
- [git-delete-current-repo](#git-delete-current-repo) - Delete the GitHub repository for the current working directory
- [git-delete-obsolete-branch](#git-delete-obsolete-branch) - Delete local branches with no remote tracking
- [git-delete-remote-branch](#git-delete-remote-branch) - Delete a remote branch (optionally the local copy too)
- [git-first-add](#git-first-add) - Report the first (and latest) commit that added each tracked file
- [git-issue2pr](#git-issue2pr) - Convert a GitHub issue into a Pull Request
- [git-lastdiff](#git-lastdiff) - Show diff between last commit and current state
- [git-newline-check](#git-newline-check) - Check for missing trailing newlines
- [git-push-multiple-remotes](#git-push-multiple-remotes) - Push a branch to every configured remote
- [git-repo-update](#git-repo-update) - Update GitHub repo description / topics from a YAML file
- [git-secret-ignore](#git-secret-ignore) - Register patterns in `.git/info/exclude` (private ignore)
- [git-sparse-checkout](#git-sparse-checkout) - Clone repository with sparse checkout for specific paths
- [git-sprint-commit](#git-sprint-commit) - Commit with an ISO-week sprint prefix
- [git-ssh-clone-from-https](#git-ssh-clone-from-https) - Clone via SSH given an HTTPS URL
- [git-tmp-checkout](#git-tmp-checkout) - Create temporary branch with stashed changes
- [git-tree](#git-tree) - Display git-tracked files in tree format
- [git-whoami](#git-whoami) - Display git user identity

## git-add-gitkeep

Discovers every `.gitkeep` file under the working tree (including those inside `.gitignore`d directories) and stages them with `git add -f`, so empty directories survive in version control.

### Usage

```bash
git-add-gitkeep [options]
```

### Options

- `-n, --check` - Show the `.gitkeep` files that would be staged and exit
- `-h, --help` - Show help message

### Example

```bash
git-add-gitkeep            # Stage every .gitkeep file
git-add-gitkeep --check    # Preview without staging
```

### One-liner equivalent

Using `fd` (matches the script's behavior, including hidden / ignored dirs):

```bash
fd -H -I '\.gitkeep$' -t f -x git add -f
```

Using `find` (POSIX fallback):

```bash
find . -type f -name '.gitkeep' -exec git add -f {} +
```

## git-add-newline

Walks every tracked file and appends a trailing newline if one is missing. Skips binaries and SVGs. Useful as a pre-commit hygiene pass.

### Usage

```bash
git-add-newline [options]
```

### Options

- `-i PATTERN` - Ignore files matching the given regex (repeatable)
- `-h, --help` - Show help message

### Example

```bash
git-add-newline                          # Fix all tracked files
git-add-newline -i '\.md$'               # Skip markdown
git-add-newline -i '\.jpg$' -i '\.png$'  # Skip multiple patterns
```

### One-liner equivalent

```bash
git ls-files -z | while IFS= read -r -d '' f; do
    file --mime "$f" | grep -q -e 'charset=binary' -e 'image/svg+xml' && continue
    [ -n "$(tail -c1 "$f")" ] && { echo >> "$f"; echo "✓ $f"; }
done
```

## git-add-patch

Wraps `git add -p` with filters so you can interactively stage hunks scoped to a directory or matching a keyword in the file path.

### Usage

```bash
git-add-patch [options]
```

### Options

- `-a` - Stage all modified files (`git add -u`)
- `-d <directory>` - Interactively stage modified files under `<directory>`
- `-s <keyword>` - Interactively stage modified files whose path matches `<keyword>` (case-insensitive)
- `-h` - Show help message

### Example

```bash
git-add-patch -a                 # Stage everything modified
git-add-patch -d src/api         # Interactive patch staging in src/api
git-add-patch -s controller      # Interactive patch staging for files matching "controller"
```

### One-liner equivalent

Stage all modified files:

```bash
git add -u
```

Interactive patch staging restricted to a directory:

```bash
git ls-files -m -z -- <directory> | xargs -0 -n1 git add -p
```

Interactive patch staging filtered by a keyword in the path:

```bash
git ls-files -m | grep -i <keyword> | xargs -I{} git add -p {}
```

## git-agent-commit

Pipes the staged diff to an LLM CLI (`claude` by default, `codex` with `--codex`) to generate a concise one-line commit message, then creates the commit. Optionally honors a project-specific commit-message rule file.

### Usage

```bash
git-agent-commit [options]
```

### Options

- `--dryrun` - Print the generated message without committing
- `--codex` - Use the `codex` CLI instead of `claude`
- `--rule <path>` - Include the contents of a commit-message rule file in the prompt
- `-h, --help` - Show help message

### Example

```bash
git-agent-commit                                # Generate via claude and commit
git-agent-commit --dryrun                       # Preview the message only
git-agent-commit --codex                        # Generate via codex
git-agent-commit --rule .claude/commit-rule.md  # Apply project rules
```

### One-liner equivalent

Using `claude`:

```bash
git commit -m "$(git diff --cached | claude -p 'Write a concise one-line commit message for this diff. Output only the message, no quotes.')"
```

Using `codex`:

```bash
git commit -m "$(codex exec --dangerously-bypass-approvals-and-sandbox "Write a concise one-line commit message for this diff. Output only the message.\n\n$(git diff --cached)")"
```

## git-browse

Opens the remote repository URL in a browser, with support for GitHub, GitLab, and Bitbucket and for opening specific branches / commits.

### Usage

```bash
git-browse [-b browser] [-r ref] [-h]
```

### Options

- `-b <browser>` - Use specified browser (firefox, chrome, chromium, safari, edge)
- `-r <ref>` - Open URL for a specific branch / tag / commit
- `-h` - Show help message

### Example

```bash
git browse                  # Default remote, default browser
git browse -b firefox       # Force Firefox
git browse -r main          # Open main branch
git browse -r 1234abc       # Open a specific commit
```

### Supported Hosting Services

- GitHub (github.com) - `/tree/` for branches, `/commit/` for commits
- GitLab (gitlab.com) - `/-/tree/` for branches, `/-/commit/` for commits
- Bitbucket (bitbucket.org) - `/src/` for branches, `/commits/` for commits
- Others (defaults to GitHub-style URLs)

### gitconfig settings

`git web--browse` uses your Git configuration to determine which browser to use.

```bash
git config --global browser.firefox firefox
```

Custom browser command:

```ini
[web]
  browser = konq

[browser "konq"]
  cmd = A_PATH_TO/konqueror
```

### One-liner equivalent

GitHub repo root (converts SSH URL → HTTPS and strips `.git`):

```bash
git remote get-url origin | sed -E 's#^git@([^:]+):#https://\1/#; s#\.git$##' | xargs xdg-open
```

Open the current branch on GitHub:

```bash
url=$(git remote get-url origin | sed -E 's#^git@([^:]+):#https://\1/#; s#\.git$##')
xdg-open "$url/tree/$(git branch --show-current)"
```

Open a specific commit on GitHub:

```bash
url=$(git remote get-url origin | sed -E 's#^git@([^:]+):#https://\1/#; s#\.git$##')
xdg-open "$url/commit/<sha>"
```

## git-check-commitsize

Analyzes and reports commit sizes in a git repository, helping identify large commits.

### Usage

```bash
git-check-commitsize [options]
```

### Options

- `-u, --unit <unit>` - Unit of size (B, KB, MB, GB)
- `-l, --lowersize <size>` - Lower size threshold
- `-d, --days <days>` - Number of days to look back
- `-h, --help` - Show help message

### Example

```bash
git-check-commitsize -unit MB -lowersize 3 -days 10
```

### Output Format

```text
$ git check-commitsize -unit KB -lowersize 3 -days 60
commit-size  commit-id  file-number  commit-date
14KB         096b7bfd   6            2025-10-23
10KB         cf906f92   3            2025-09-16
23KB         dbd7014a   14           2025-09-16
```

### One-liner equivalent

List commits with their patch byte-size (sum of all changes) for the last 60 days, sorted by size:

```bash
git log --since='60 days ago' --format='%H %ad' --date=short | while read sha date; do
    size=$(git show --format='' "$sha" | wc -c)
    echo "$size $sha $date"
done | sort -rn
```

Filter to only commits ≥ 3 KB:

```bash
git log --since='60 days ago' --format='%H %ad' --date=short | while read sha date; do
    size=$(git show --format='' "$sha" | wc -c)
    [ "$size" -ge 3072 ] && printf '%dKB  %s  %s\n' $((size/1024)) "${sha:0:8}" "$date"
done
```

## git-create-repo

Creates a GitHub repository using `gh`, driven by a YAML metadata file (`.github/repository_metadata/gh_repo.yml` by default) that defines name, visibility, and optional org.

### Usage

```bash
git-create-repo                       # Use default YAML
git-create-repo /path/to/gh-meta.yml  # Use a custom YAML
```

### YAML format

```yaml
meta-data:
  repository_name: my-repo
  visibility: private        # public | private | internal
  org_name: my-org           # optional
```

### Requirements

- [GitHub CLI (`gh`)](https://cli.github.com/) authenticated
- `yamlcli` and `jq` for YAML parsing

### One-liner equivalent

Without a YAML file:

```bash
gh repo create <owner>/<name> --private --source=. --remote=origin --push
```

Public repo, no source push:

```bash
gh repo create <name> --public
```

## git-delete-current-repo

Deletes the GitHub repository that corresponds to the current working directory's `origin`, after a confirmation prompt. Local files are untouched.

### Usage

```bash
git-delete-current-repo        # Confirm and delete
git-delete-current-repo -n     # Dry run
```

### Requirements

- `gh` CLI installed and authenticated with `delete_repo` scope

### One-liner equivalent

```bash
gh repo delete "$(gh repo view --json nameWithOwner -q .nameWithOwner)" --yes
```

Add cleanup of the local remote:

```bash
gh repo delete "$(gh repo view --json nameWithOwner -q .nameWithOwner)" --yes && git remote remove origin
```

## git-delete-obsolete-branch

Manages deletion of local Git branches whose upstream is gone.

### Usage

```bash
git-delete-obsolete-branch [options]
```

### Options

- `--dry` - Show branches that would be deleted without deleting
- `--yes` - Delete without confirmation
- `-h` - Show help message

### Features

- Fetches and prunes remote branches automatically
- Identifies branches with `gone` remote tracking status
- Three modes: interactive (default), dry-run, force

### Example

```bash
git-delete-obsolete-branch --dry    # Preview
git-delete-obsolete-branch --yes    # Force delete
git-delete-obsolete-branch          # Interactive
```

### One-liner equivalent

Dry run:

```bash
git fetch --all --prune && git branch -vv | awk '/: gone]/ {print $1}'
```

Force delete all gone branches:

```bash
git fetch --all --prune && git branch -vv | awk '/: gone]/ {print $1}' | xargs -r git branch -D
```

## git-delete-remote-branch

Deletes a specified remote Git branch, with optional deletion of the corresponding local branch and a dry-run mode.

### Usage

```bash
git-delete-remote-branch <branch> [options]
```

### Options

- `--remote <name>` - Remote name (default: `origin`)
- `--dry` - Dry run, no actual deletion
- `--with-local` - Also delete the local branch
- `-h, --help` - Show help message

### Example

```bash
git-delete-remote-branch feature/foo                       # Delete on origin
git-delete-remote-branch feature/foo --remote upstream     # Delete on upstream
git-delete-remote-branch feature/foo --with-local --dry    # Preview both
```

### One-liner equivalent

Delete a remote branch:

```bash
git push origin --delete <branch>
```

Also delete the local branch:

```bash
git push origin --delete <branch> && git branch -D <branch>
```

## git-first-add

Reports, for each tracked file, the commit at which it was first added, the most recent re-add commit, and the total number of add commits. Useful for auditing when files entered the repository or detecting files that have been removed and re-added.

### Usage

```bash
git-first-add [options] [file ...]
```

### Options

- `-q, --no-header` - Omit the table header and separator line
- `-h, --help` - Show help message

### Example

```bash
git-first-add                              # All tracked files
git-first-add src/foo.sh                   # Specific file(s)
git-first-add --no-header src/foo.sh       # Useful for piping
```

### Output Format

```text
file                                                count      oldest commit                                                   latest commit
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
src/foo.sh                                          count=1    abc1234 Alice 2025-01-10 10:00:00 +0900 Initial commit          abc1234 Alice 2025-01-10 10:00:00 +0900 Initial commit
```

Each row contains:

| Field    | Description                                                              |
| -------- | ------------------------------------------------------------------------ |
| `file`   | Tracked file path                                                        |
| `count`  | Number of times the file has been added (>1 means deleted and re-added) |
| `oldest` | Hash, author, date, and subject of the first add commit                 |
| `latest` | Hash, author, date, and subject of the most recent add commit           |

### One-liner equivalent

First add commit for a single file:

```bash
git log --diff-filter=A --reverse --format="%h %an %ad %s" --date=iso -- <file> | head -1
```

Most recent add commit for a single file:

```bash
git log --diff-filter=A --format="%h %an %ad %s" --date=iso -- <file> | head -1
```

Number of times a file has been added:

```bash
git log --diff-filter=A --oneline -- <file> | wc -l
```

First add commit for all tracked files (loop):

```bash
git ls-files | while read f; do
    printf "%-50s  " "$f"
    git log --diff-filter=A --reverse --format="%h %an %ad %s" --date=iso -- "$f" | head -1
done
```

## git-issue2pr

Converts an existing GitHub issue into a Pull Request via `gh api`. The current branch is used as the head branch and the issue is linked as the PR body.

### Usage

```bash
git-issue2pr -b <base-branch> -i <issue-number> [-r <remote>]
```

### Options

- `-b <base-branch>` - Base branch for the PR (required)
- `-i <issue-number>` - GitHub issue number to convert (required)
- `-r <remote>` - Remote to resolve owner/repo (default: `origin`)
- `-h, --help` - Show help message

### Requirements

- `gh` CLI authenticated against the target repo
- The current branch must already be pushed to the remote

### Example

```bash
git-issue2pr -b main -i 42                # Convert issue #42 into a PR against main
git-issue2pr -b develop -i 7 -r upstream  # Use the upstream remote
```

### One-liner equivalent

Assuming `origin` points at GitHub and the current branch is pushed:

```bash
gh api "repos/$(gh repo view --json nameWithOwner -q .nameWithOwner)/pulls" \
    -f "head=$(git branch --show-current)" \
    -f "base=main" \
    -F "issue=42"
```

## git-lastdiff

Shows differences between the last commit that touched a file and the current state, using `git difftool`.

### Usage

```bash
git-lastdiff <file_path>
```

### One-liner equivalent

```bash
git difftool "$(git log -n 1 --format=%H -- <file>)" -- <file>
```

If the file is unchanged since the last commit on `HEAD`, this is simply:

```bash
git difftool HEAD -- <file>
```

## git-newline-check

Reports tracked files that are missing a trailing newline. Skips binaries and SVGs.

### Usage

```bash
git-newline-check [options]
```

### Options

- `-i PATTERN` - Ignore files matching the given pattern (repeatable)
- `-h, --help` - Show help message

### One-liner equivalent

```bash
git ls-files -z | while IFS= read -r -d '' f; do
    file --mime "$f" | grep -q -e 'charset=binary' -e 'image/svg+xml' && continue
    [ -n "$(tail -c1 "$f")" ] && echo "Missing newline: $f"
done
```

## git-push-multiple-remotes

Pushes a branch to every configured remote, in sequence.

### Usage

```bash
git-push-multiple-remotes <branch-name>
```

### Example

```bash
git-push-multiple-remotes main
```

### One-liner equivalent

```bash
git remote | xargs -I{} git push {} <branch>
```

Add error-on-first-failure semantics:

```bash
git remote | while read r; do git push "$r" <branch> || break; done
```

## git-repo-update

Updates a GitHub repository's description, homepage, and topics from a YAML metadata file. Topics present on the repo but absent from YAML are removed; topics in YAML but missing on the repo are added.

### Usage

```bash
git-repo-update                       # Use default YAML
git-repo-update /path/to/gh-meta.yml  # Use a custom YAML
```

### YAML format

```yaml
meta-data:
  description: Helpful one-line description
  homepage: https://example.com
  tag:
    - cli
    - git
    - helpers
```

### Requirements

- `gh`, `yamlcli`, and `jq` on PATH

### One-liner equivalent

Plain `gh` form, when you don't need YAML-driven topic reconciliation:

```bash
gh repo edit --description "<desc>" --homepage "<url>" --add-topic cli --add-topic git
```

Remove a topic:

```bash
gh repo edit --remove-topic <topic>
```

## git-secret-ignore

Registers one or more `<pattern>`s in `.git/info/exclude`, keeping them untracked locally without modifying the shared `.gitignore`. Idempotent — already-present patterns are skipped.

### Usage

```bash
git-secret-ignore <pattern> [<pattern> ...]
git-secret-ignore --check                  # Preview .git/info/exclude
```

### Options

- `-n, --check` - Print current `.git/info/exclude` contents and exit
- `-h, --help` - Show help message

### Example

```bash
git-secret-ignore secret.env
git-secret-ignore '*.key' .env.local notes.md
```

### One-liner equivalent

```bash
echo '<pattern>' >> "$(git rev-parse --git-dir)/info/exclude"
```

Idempotent (skip when already present):

```bash
grep -Fxq -- '<pattern>' "$(git rev-parse --git-dir)/info/exclude" 2>/dev/null \
    || echo '<pattern>' >> "$(git rev-parse --git-dir)/info/exclude"
```

## git-sparse-checkout

Clones a Git repository with sparse checkout enabled, useful for pulling only specific directories from a large repository.

### Usage

```bash
git-sparse-checkout -u <clone_url> -d <target_dir> -b <branch> -p <sparse_path>
```

### Options

- `-u <clone_url>` - URL of the Git repository to clone (required)
- `-d <target_dir>` - Target directory (required)
- `-b <branch>` - Branch to check out (required)
- `-p <sparse_path>` - Path pattern for sparse checkout (required)

### Example

```bash
git-sparse-checkout -u https://github.com/user/repo.git -d ./my-repo -b main -p "docs/*"
git-sparse-checkout -u https://github.com/user/repo.git -d ./project -b develop -p "src/main.py"
git-sparse-checkout -u https://github.com/user/repo.git -d ./subset -b main -p "src/\ntest/"
```

### How It Works

1. Clones the repository without checking out files (`--no-checkout`)
2. Enables sparse checkout configuration (`core.sparseCheckout true`)
3. Writes the path pattern into `.git/info/sparse-checkout`
4. Checks out the specified branch

### One-liner equivalent

```bash
git clone --no-checkout <url> <dir> \
    && cd <dir> \
    && git config core.sparseCheckout true \
    && printf 'docs/*\n' > .git/info/sparse-checkout \
    && git checkout <branch>
```

Modern `git sparse-checkout` subcommand (Git ≥ 2.25):

```bash
git clone --filter=blob:none --no-checkout <url> <dir>
cd <dir>
git sparse-checkout init --cone
git sparse-checkout set docs src
git checkout <branch>
```

## git-sprint-commit

Creates a commit whose message is prefixed with the current ISO year / week, e.g. `sprint-2025-08w`. Useful for sprint-aligned commit conventions.

### Usage

```bash
git-sprint-commit                   # Commit with just the sprint prefix
git-sprint-commit -m "<message>"    # Commit with prefix + message
```

### Options

- `-m, --message <msg>` - Message to append after the sprint prefix
- `-h, --help` - Show help message

### Example

```bash
git-sprint-commit             # -> sprint-2025-08w
git-sprint-commit -m "Fix"    # -> sprint-2025-08w: Fix
```

### One-liner equivalent

Prefix only:

```bash
git commit -m "sprint-$(date +%Y-%Vw)"
```

Prefix + message:

```bash
git commit -m "sprint-$(date +%Y-%Vw): <message>"
```

## git-ssh-clone-from-https

Converts an HTTPS clone URL into an SSH URL (optionally rewriting the host alias for SSH-config-based identities) and clones it.

### Usage

```bash
git-ssh-clone-from-https [-h hostname] [-d directory] <https_url>
```

### Options

- `-h <hostname>` - Override the SSH host (e.g. an SSH-config alias like `github-work`); default `github.com`
- `-d <directory>` - Target directory

### Example

```bash
git-ssh-clone-from-https https://github.com/user/repo.git
git-ssh-clone-from-https -h github-work -d mydir https://github.com/user/repo.git
```

### One-liner equivalent

```bash
git clone "$(echo '<https-url>' | sed -E 's#https://([^/]+)/#git@\1:#')"
```

With a custom host alias:

```bash
git clone "$(echo '<https-url>' | sed -E 's#https://[^/]+/#git@github-work:#')" <dir>
```

## git-tmp-checkout

Stashes the current working changes, creates a new branch, and pops the stash onto it — useful when you started work on the wrong branch.

### Usage

```bash
git-tmp-checkout -m <stash_message> -c <new_branch_name>
```

### Options

- `-m` - Stash message (optional, auto-generated if omitted)
- `-c` - New branch name (required)

### One-liner equivalent

```bash
git stash push -m "<msg>" && git checkout -b <new-branch> && git stash pop
```

If you have no uncommitted changes you want preserved:

```bash
git checkout -b <new-branch>
```

## git-tree

Lists git-tracked files in a tree structure, similar to `tree(1)` but limited to git-tracked files.

### Usage

```bash
git-tree [folder_path]
```

### Requirements

- `tree` command installed

### Error Cases

- Not a git repository
- Invalid directory input
- Non-git-tracked directory

### One-liner equivalent

Whole repo:

```bash
git ls-files | tree --fromfile
```

Restricted to a folder:

```bash
git ls-files -- <folder> | tree --fromfile
```

## git-whoami

Displays the configured git user name and email.

### Usage

```bash
git-whoami
```

### Output

```ini
username (email@example.com)
```

### One-liner equivalent

```bash
echo "$(git config --get user.name) ($(git config --get user.email))"
```

Repository-scoped vs global:

```bash
git config --get user.name
git config --global --get user.name
```
