# Git Helper Scripts Documentation

A collection of git helper scripts to enhance your git workflow.

## Table of Contents

- [git-check-commitsize](#git-check-commitsize) - Analyze commit sizes in repository
- [git-delete-obsolete-branch](#git-delete-obsolete-branch) - Delete local branches with no remote tracking
- [git-lastdiff](#git-lastdiff) - Show diff between last commit and current state
- [git-newline-check](#git-newline-check) - Check for missing trailing newlines
- [git-sparse-checkout](#git-sparse-checkout) - Clone repository with sparse checkout for specific paths
- [git-tmp-checkout](#git-tmp-checkout) - Create temporary branch with stashed changes
- [git-tree](#git-tree) - Display git-tracked files in tree format
- [git-whoami](#git-whoami) - Display git user identity
- [git-browse](#git-browse) - Open repository URL in browser

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
# List commits larger than 3MB in the last 10 days
git-check-commitsize -unit MB -lowersize 3 -days 10
```

### Output Format

```bash
$ git check-commitsize -unit KB -lowersize 3 -days 60
commit-size  commit-id  file-number  commit-date
14KB         096b7bfd   6            2025-10-23  
10KB         cf906f92   3            2025-09-16  
23KB         dbd7014a   14           2025-09-16  
```

## git-delete-obsolete-branch

Manages deletion of local Git branches that no longer have corresponding remote tracking branches (gone branches).

### Usage

```bash
git-delete-obsolete-branch [options]
```

### Options

- `--dry` - Show branches that would be deleted without actually deleting them
- `--yes` - Delete branches without confirmation
- `-h` - Show help message

### Features

- Fetches and prunes remote branches automatically
- Identifies branches with 'gone' remote tracking status
- Provides three operation modes:
  - Interactive (default): Asks for confirmation before deleting each branch
  - Dry run: Shows which branches would be deleted
  - Force delete: Deletes branches without asking
- Safe deletion using `git branch -d`

### Example

```bash
# Show branches that would be deleted
git-delete-obsolete-branch --dry

# Delete branches without confirmation
git-delete-obsolete-branch --yes

# Interactive mode (default)
git-delete-obsolete-branch
```

## git-lastdiff

Shows differences between the last commit and current state of a specified file using git difftool.

### Usage

```bash
git-lastdiff <file_path>
```

### Features

- Automatically fetches the last commit ID for the specified file
- Uses git difftool for comparison
- Shows visual diff between last commit and current state

## git-newline-check

Checks for files missing trailing newlines in the git repository.

### Usage

```bash
git-newline-check [options]
```

### Options

- `-h, --help` - Show help message
- `-i PATTERN` - Ignore files matching the given pattern (can be used multiple times)

### Features

- Skips binary files and SVG files automatically
- Supports custom ignore patterns
- Reports files missing trailing newlines

## git-sparse-checkout

Clones a Git repository with sparse checkout enabled, allowing you to work with only specific directories or files from a large repository.

### Usage

```bash
git-sparse-checkout -u <clone_url> -d <target_dir> -b <branch> -p <sparse_path>
```

### Options

- `-u <clone_url>` - URL of the Git repository to clone (required)
- `-d <target_dir>` - Target directory where the repository will be cloned (required)
- `-b <branch>` - Branch to checkout (required)
- `-p <sparse_path>` - Path pattern for sparse checkout (required)

### Example

```bash
# Clone only the 'docs' directory from a repository
git-sparse-checkout -u https://github.com/user/repo.git -d ./my-repo -b main -p "docs/*"

# Clone only specific files
git-sparse-checkout -u https://github.com/user/repo.git -d ./project -b develop -p "src/main.py"

# Clone multiple paths (use multiple patterns separated by newlines)
git-sparse-checkout -u https://github.com/user/repo.git -d ./subset -b main -p "src/\ntest/"
```

### Features

- Performs shallow clone with no initial checkout for efficiency
- Automatically configures sparse checkout settings
- Supports any valid Git URL (HTTPS, SSH, etc.)
- Works with any branch name
- Supports glob patterns for path matching

### How It Works

1. Clones the repository without checking out files (`--no-checkout`)
2. Enables sparse checkout configuration (`core.sparseCheckout true`)
3. Sets the sparse checkout path pattern in `.git/info/sparse-checkout`
4. Checks out the specified branch with only the matching files

### Use Cases

- Working with large monorepos where you only need specific components
- Reducing disk space usage by excluding unnecessary directories
- Faster clone and checkout times for large repositories
- Isolating specific project modules or documentation

## git-tmp-checkout

Creates a temporary branch with stashed changes, useful for experimental work.

### Usage

```bash
git-tmp-checkout -m <stash_message> -c <new_branch_name>
```

### Options

- `-m` - Stash message (optional, auto-generated if not provided)
- `-c` - New branch name (required)

### Features

- Automatically stashes current changes
- Creates new branch
- Applies stashed changes to new branch

## git-tree

Lists git-tracked files in a tree structure, similar to the `tree` command but only showing git-tracked files.

### Usage

```bash
git-tree [folder_path]
```

### Requirements

- `tree` command must be installed
- [GitHub CLI (`gh`)](https://cli.github.com/)

### Features

- Shows only git-tracked files
- Supports specific directory viewing
- Maintains tree-like structure output

### Error Cases

- Not a git repository
- Invalid directory input
- Non-git-tracked directory

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

### Features

- Shows current git configuration identity
- Validates both name and email are set

## git-browse

Opens the remote repository URL in a browser with support for different hosting services.

### Usage

```bash
git-browse [-b browser] [-r ref] [-h]
```

### Options

- `-b <browser>` - Use specified browser (firefox, chrome, chromium, safari, edge)
- `-r <ref>` - Open specific branch/tag/commit URL
- `-h` - Show help message

### Features

- Interactive selection for multiple remotes
- Support for major git hosting services (GitHub, GitLab, Bitbucket)
- Handles both SSH and HTTPS remote URLs
- Supports branch names containing slashes
- Browser validation with common browser options
- Preview of URL before opening

### Examples

```bash
# Open default remote in default browser
git browse

# Open in Firefox
git browse -b firefox

# Open specific branch
git browse -r main

# Open specific commit
git browse -r 1234abc
```

### Supported Hosting Services

- GitHub (github.com)
- GitLab (gitlab.com)
- Bitbucket (bitbucket.org)
- Others (defaults to GitHub-style URLs)

### URL Format Handling

- Automatically converts SSH URLs to HTTPS format
- Properly encodes branch names with slashes
- Uses platform-specific URL patterns:
  - GitHub: `/tree/` for branches, `/commit/` for commits
  - GitLab: `/-/tree/` for branches, `/-/commit/` for commits
  - Bitbucket: `/src/` for branches, `/commits/` for commits

### gitconfig settings

`git web--browse` uses your Git configuration to determine which browser to use when opening URLs.

Basic Example

```bash
git config --global browser.firefox firefox
```

You can define custom browser commands by name and use them in `[web]`:

```ini
[web]
  browser = konq

[browser "konq"]
  cmd = A_PATH_TO/konqueror
```

- `konq` is just a name you assign.
- `cmd` is the actual shell command used to launch the browser (here, Konqueror).
- This allows you to define any arbitrary browser or command wrapper.
