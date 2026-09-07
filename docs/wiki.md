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
- [git-find](#git-find) - Grep file paths known to git (tracked / untracked / ignored)
- [git-first-add](#git-first-add) - Report the first (and latest) commit that added each tracked file
- [git-grep-commit](#git-grep-commit) - Find commits whose patches match a regex
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

### Requirements

- `fd` (or `fdfind`) on PATH; the script exits with an error without it.
  The search starts from the current directory, not the repository root.

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

- (no options) - Interactively patch-stage **every** modified file in the repository
- `-a` - Stage all modified files non-interactively (`git add -u`)
- `-d <directory>` - Interactively stage modified files under `<directory>`
- `-s <keyword>` - Interactively stage modified files whose path matches `<keyword>` (case-insensitive)
- `-h` - Show help message

Precedence when combined: `-a` short-circuits everything, otherwise `-d` wins over `-s`.

### Example

```bash
git-add-patch                    # Patch-stage every modified file
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
- `--model <model>` - Claude model used to generate the message
  (default: `claude-sonnet-4-6`). Ignored by the `--codex` backend.
- `--exclude <pathspec>` - Drop paths from the staged diff sent to the agent
  (repeatable). Git magic pathspecs are supported, e.g. `':(glob)**/*.lock'`.
- `-h, --help` - Show help message

### Example

```bash
git-agent-commit                                # Generate via claude and commit
git-agent-commit --dryrun                       # Preview the message only
git-agent-commit --codex                        # Generate via codex
git-agent-commit --rule .claude/commit-rule.md  # Apply project rules
git-agent-commit --model claude-opus-4-6         # Pick the model
git-agent-commit --exclude '*.lock' --exclude dist/  # Ignore noisy paths
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

- `-b <browser>` - Use specified browser (`firefox`, `chrome`, `chromium`, `google-chrome`). Any other value is rejected.
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
git-check-commitsize -u <unit> -l <size> [-d <days>]
```

### Options

- `-u, --unit <unit>` - Unit of size (B, KB, MB, GB) **(required)**
- `-l, --lowersize <size>` - Lower size threshold **(required)**
- `-d, --days <days>` - Number of days to look back (default: `365`)
- `-h, --help` - Show help message

Omitting `-u` or `-l` exits with `Error: Missing required parameters.`

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

### Options

- `-h, --help` - Show help message

The YAML path must end in `.yml` or `.yaml`. `--source` is always the git root,
so the script has to be run from inside an existing repository.

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

Deletes the GitHub repository that corresponds to the current working directory's `origin`, after a confirmation prompt. Local files are untouched, but the local `origin` remote is removed on success.

### Usage

```bash
git-delete-current-repo        # Confirm and delete
git-delete-current-repo -n     # Dry run
```

### Options

- `-n` - Dry run; report what would be deleted and exit
- `-h` - Show help message

The confirmation prompt accepts only a single `y` / `Y`; anything else (including
`yes`) aborts.

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
- `-h, --help` - Show help message

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

The script runs `git fetch --prune` (default remote only) and deletes with
`git branch -d`, so unmerged branches are refused rather than discarded.

Dry run:

```bash
git fetch --prune && git branch -vv | awk '/: gone]/ {print $1}'
```

Delete all gone branches, refusing unmerged ones (what the script does):

```bash
git fetch --prune && git branch -vv | awk '/: gone]/ {print $1}' | xargs -r git branch -d
```

Force delete even unmerged branches (**not** what the script does):

```bash
git fetch --prune && git branch -vv | awk '/: gone]/ {print $1}' | xargs -r git branch -D
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

## git-find

Greps the list of file paths that git knows about. By default it searches tracked **and** untracked files while honouring `.gitignore`, so it behaves like a git-aware `find` that never descends into `node_modules/` or build output. Scope flags narrow it to tracked-only or untracked-only, and `-a` brings ignored files back in.

### Usage

```bash
git-find [options] <pattern> [-- <pathspec> ...]
```

### Options

| Option | Description |
| --- | --- |
| `-t`, `--tracked` | List tracked files only (`git ls-files`) |
| `-u`, `--untracked` | List untracked-but-not-ignored files only (drops `--cached`) |
| `-a`, `--all` | List tracked + untracked, including ignored files |
| `-i`, `--ignore-case` | Case-insensitive pattern match |
| `-F`, `--fixed-strings` | Treat the pattern as a literal string, not a regex |
| `-c`, `--count` | Print only the number of matching paths |
| `-z`, `--null` | NUL-separate output (safe for `xargs -0`) |
| `-h`, `--help` | Show this help message |

Scope flags (`-t` / `-u` / `-a`) are mutually exclusive, and `-c` and `-z` are mutually exclusive too. Everything after `--` is passed to git as a pathspec, so the search can be scoped to a subdirectory.

### Examples

```bash
git-find '\.py$'                     # tracked + untracked, gitignore honoured
git-find -t '\.py$'                  # tracked only
git-find -u '\.py$'                  # untracked only
git-find -i 'readme'                 # case-insensitive
git-find -F 'src/lib.sh'             # literal match, no regex
git-find -c '\.sh$'                  # count matches
git-find -z '\.sh$' | xargs -0 wc -l # pipe safely into xargs
git-find '\.md$' -- docs             # limit the search to docs/
```

The pattern is matched against the whole path relative to the repository root, not just the basename. Exit status is `1` when nothing matches, mirroring `grep`.

### One-liner equivalent

Default (tracked + untracked, respecting `.gitignore`):

```bash
git ls-files --cached --others --exclude-standard | grep '<pattern>'
```

Tracked only:

```bash
git ls-files | grep '<pattern>'
```

Untracked only — drop `--cached`:

```bash
git ls-files --others --exclude-standard | grep '<pattern>'
```

Tracked + untracked including ignored files:

```bash
git ls-files --cached --others | grep '<pattern>'
```

NUL-safe variant for filenames containing spaces or newlines:

```bash
git ls-files -z --cached --others --exclude-standard | grep -z '<pattern>'
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
src/foo.sh                                          count=1    oldest: abc1234 Alice 2025-01-10 10:00:00 +0900 Initial commit  latest: abc1234 Alice 2025-01-10 10:00:00 +0900 Initial commit
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

## git-grep-commit

Finds commits whose patches add or remove text matching a regular expression,
then groups the affected paths by commit. Revision ranges and every path after
`--` are passed through to Git, including magic pathspecs.

### Usage

```bash
git-grep-commit [options] <regex> [<revision> ...] [-- <pathspec> ...]
```

### Options

- `-f, --format <format>` - Output as `table` (default), `json`, or `yml`;
  `yaml` is accepted as an alias for `yml`
- `-i, --ignore-case` - Match the patch regex case-insensitively
- `--diff-filter <filter>` - Apply Git's native diff filter. Uppercase status
  letters include changes, lowercase letters exclude changes, and `*` enables
  Git's all-or-none behavior. Both `--diff-filter=AM` and `--diff-filter AM`
  are accepted.
- `-h, --help` - Show help message

The filter value is passed unchanged to Git:

| Filter | Result |
| --- | --- |
| `A` | Added paths only |
| `M` | Modified paths only |
| `D` | Deleted paths only |
| `R` | Renamed paths only |
| `C` | Copied paths only |
| `AM` | Added or modified paths |
| `ad` | Exclude added and deleted paths |
| `AM*` | If a commit contains an added or modified path, select all changed paths in that commit |

Other native Git status letters such as `T`, `U`, `X`, and `B` are also
accepted. Because `*` modifies other selection letters, it is normally combined
with them, as in `AM*`.

### Examples

```bash
git-grep-commit 'TODO'
git-grep-commit -i 'todo' HEAD~20..HEAD
git-grep-commit --diff-filter=A 'TODO' HEAD~20..HEAD
git-grep-commit --diff-filter=AM 'TODO' HEAD~20..HEAD
git-grep-commit --diff-filter=ad 'TODO' HEAD~20..HEAD
git-grep-commit --diff-filter='*' 'TODO' HEAD~20..HEAD
git-grep-commit --diff-filter='AM*' 'TODO' HEAD~20..HEAD
git-grep-commit 'TODO' HEAD~20..HEAD -- '*.qmd'
git-grep-commit --format json 'TODO' HEAD~20..HEAD -- ':(glob)**/*.qmd'
git-grep-commit -f yml 'TODO' -- docs/
```

JSON and YAML contain one object per commit with a nested `files` list. Rename
and copy entries contain both `old_path` and `path`; the table renders these as
`old path -> new path`. Filenames containing tabs or newlines are escaped in the
table and serialized safely in JSON/YAML.

### One-liner equivalent

```bash
git log -G '<regex>' [--regexp-ignore-case] [--diff-filter=AM] \
    --format='commit %h' --name-status \
    <revision-range> -- '<pathspec>'
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

Shows what the last commit that touched a file actually changed, by diffing that
commit against its parent. Uses `git difftool` by default.

### Usage

```bash
git-lastdiff [-n <N>] [--no-tool] <file_path>
```

### Options

- `-n <N>` - Diff the N-th most recent commit that touched the file (default: `1`).
  Errors out if the file has fewer than N commits.
- `--no-tool` - Use `git diff` (plain terminal output) instead of `git difftool`.
- `-h, --help` - Show help message.

### Example

```bash
# What did the last commit change in this file?
git-lastdiff src/git-find.sh

# The commit before that, as plain text
git-lastdiff -n 2 --no-tool src/git-find.sh
```

### One-liner equivalent

The script resolves the N-th newest commit for the file, then diffs that commit's
**parent** against `HEAD`:

```bash
git difftool -y "$(git log -n 1 --format=%H -- <file>)^" HEAD -- <file>
```

With `--no-tool`:

```bash
git diff "$(git log -n 1 --format=%H -- <file>)^" HEAD -- <file>
```

For a root commit (no parent) the script substitutes the empty-tree object
(`git hash-object -t tree /dev/null`), so the file shows up as entirely added.

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

The script does **not** stop on a failed push: it continues to the remaining
remotes and always exits `0`. To stop at the first failure instead (a behavior
change, not an equivalent):

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

The default YAML path is
`<repo-root>/.github/repository_metadata/gh_repo.yml`.

### Options

- `-h` - Show help message (exits with status 1)

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

Clones a Git repository with sparse checkout enabled, useful for pulling only specific directories from a large repository. The clone is blobless (`--filter=blob:none`), so file contents are fetched lazily.

### Usage

```bash
git-sparse-checkout -u <clone_url> -d <target_dir> -b <branch> -p <sparse_path>
git-sparse-checkout -s -u <clone_url> -d <target_dir> -b <branch>
```

### Options

- `-u <clone_url>` - URL of the Git repository to clone (required)
- `-d <target_dir>` - Target directory (required)
- `-b <branch>` - Branch to check out (required)
- `-p <sparse_path>` - **Colon-separated** list of path patterns to check out.
  Required unless `-s` is given.
- `-s` - Bare/skeleton mode: check out only the top-level files (`/*` plus `!/*/`)
  and then create the repository's directory tree as empty directories. Mutually
  exclusive with the need for `-p`.
- `-h` - Show help message

### Example

```bash
git-sparse-checkout -u https://github.com/user/repo.git -d ./my-repo -b main -p "docs/*"
git-sparse-checkout -u https://github.com/user/repo.git -d ./project -b develop -p "src/main.py"

# Multiple paths are separated by ':'
git-sparse-checkout -u https://github.com/user/repo.git -d ./subset -b main -p "src/:test/"

# Skeleton only: top-level files + empty dir tree
git-sparse-checkout -s -u https://github.com/user/repo.git -d ./skeleton -b main
```

### How It Works

1. Clones the repository blobless and without checking out files
   (`git clone --filter=blob:none --no-checkout`)
2. Enables sparse checkout configuration (`core.sparseCheckout true`)
3. Writes the patterns into `.git/info/sparse-checkout`, splitting `-p` on `:`
4. Checks out the specified branch
5. With `-s`, additionally materializes every tracked directory as an empty dir
   (`git ls-tree -r -d --name-only HEAD | xargs -I{} mkdir -p "{}"`)

### One-liner equivalent

```bash
git clone --filter=blob:none --no-checkout <url> <dir> \
    && cd <dir> \
    && git config core.sparseCheckout true \
    && printf 'src/\ntest/\n' > .git/info/sparse-checkout \
    && git checkout <branch>
```

Skeleton mode (`-s`):

```bash
git clone --filter=blob:none --no-checkout <url> <dir> && cd <dir>
git config core.sparseCheckout true
printf '/*\n!/*/\n' > .git/info/sparse-checkout
git checkout <branch>
git ls-tree -r -d --name-only HEAD | xargs -I{} mkdir -p "{}"
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
git-sprint-commit <words...>        # Trailing words become the message
```

Requires staged changes; aborts with `No staged changes to commit.` otherwise.

### Options

- `-m, --message <msg>` - Message to append after the sprint prefix
- `-h, --help` - Show help message

Any trailing positional arguments are appended to the message, so
`git-sprint-commit Fix typo` works and combines with `-m`.

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

- `-m` - Stash message. If omitted, defaults to
  `Stash created on <YYYY-MM-DD HH:MM:SS> from commit <short-sha>`.
- `-c` - New branch name (required)
- `-h, --help` - Show help message

### Example

```bash
git-tmp-checkout -c feature/wip
git-tmp-checkout -m "half-done refactor" -c feature/wip
```

### One-liner equivalent

The stash includes untracked and ignored files (`-a`), and is applied rather than
popped, so the stash entry remains in the list afterwards:

```bash
git stash push -a -m "<msg>" && git switch -c <new-branch> && git stash apply stash@{0}
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

### Options

- `-h, --help` - Show help message

### Requirements

- `tree` command installed

### Error Cases

- Not a git repository
- Invalid directory input

A directory that exists but contains no git-tracked files is not an error — the
output is simply empty.

### One-liner equivalent

The script lists files from the commit at `HEAD` (`git ls-tree`), so
staged-but-uncommitted new files do not appear.

Whole repo:

```bash
git ls-tree -r --name-only HEAD | tree --fromfile
```

Restricted to a folder:

```bash
git ls-tree -r --name-only HEAD -- <folder> | tree --fromfile
```

## git-whoami

Displays the configured git user name and email.

### Usage

```bash
git-whoami
```

### Options

- `-h` - Show help message (exits with status 1). Long-form `--help` is not supported.

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
