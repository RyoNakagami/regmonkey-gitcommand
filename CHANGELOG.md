# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `git-sed`: safely replace ERE matches in Git-selected, tracked text files,
  with dry-run previews, pathspec filters, clean-file protection, and optional
  per-file confirmation.
- `git-rename-repo`: rename the current GitHub repository to the
  `repository_name` defined in a YAML metadata file
  (`.github/repository_metadata/gh_repo.yml` by default), the counterpart to
  `git-create-repo`. Validates that the name is a bare repository name (no owner,
  no whitespace) and that the optional owner key (`org-name`, falling back to
  `org_name`) matches the current owner, since `gh repo rename` cannot transfer
  ownership. Exits successfully when the name already matches, so it is safe to
  re-run. Supports `-n`/`--dry-run` and confirms before renaming.
- `git-grep-commit`: find commits with `git log -G`, optionally scoped by
  revision ranges and Git pathspecs, and render the matching paths as a table,
  JSON, or YAML. Use `-i` for case-insensitive patch matching and Git-compatible
  `--diff-filter` values, including uppercase inclusion, lowercase exclusion,
  and `*` all-or-none behavior.

## [1.3.0] - 2026-08-28

### Added
- `git-find`: grep the file paths git knows about. By default it lists tracked
  *and* untracked files while honouring `.gitignore`
  (`git ls-files --cached --others --exclude-standard`), so it behaves like a
  git-aware `find` that never descends into `node_modules/` or build output.
  Scope flags `-t`/`--tracked`, `-u`/`--untracked` and `-a`/`--all` (include
  ignored files) are mutually exclusive; `-i`, `-F`, `-c` and `-z` mirror the
  corresponding grep options, and everything after `--` is passed to git as a
  pathspec. Output is NUL-safe end to end, and the exit status is `1` when
  nothing matches.
- `git-agent-commit`: `--model <model>` selects the Claude model used to generate
  the message (default `claude-sonnet-4-6`); ignored by the `--codex` backend.
- `git-agent-commit`: `--exclude <pathspec>` (repeatable) drops paths from the
  staged diff sent to the agent, so lock files and generated output no longer
  dominate the generated message.

### Fixed
- `git-agent-commit`: `--exclude` now understands git magic pathspecs. Previously the
  value was unconditionally prefixed with `:!`, so a magic pathspec such as
  `--exclude ':(glob)**/*.lock'` became `:!:(glob)**/*.lock` — which git silently
  interprets as excluding a literal file named `:(glob)**/*.lock`, matching nothing.
  The exclusion was therefore a no-op with no error reported. The `exclude` magic word
  is now merged into the user's pathspec while preserving any other magic words
  (`glob`, `icase`, `top`, `attr:`, ...):
  `'*.lock'` → `:(exclude)*.lock`, `':(glob)**/*.lock'` → `:(exclude,glob)**/*.lock`,
  `':/a/b'` → `:(exclude,top)a/b`, while `':!x'` / `':^x'` / `':(exclude,icase)x'`
  are passed through unchanged. Malformed values (bare `:`, unterminated `:(glob`)
  are now rejected with an error instead of being silently ignored.

### Documentation
- Commit conventions guide (`docs/COMMITRULES.md`) documenting the Conventional
  Commits format used by this project.
- Wiki entry for `git-find`, including options, examples and the `git ls-files |
  grep` one-liner equivalents.
- Wiki now covers every script in `src/` (24 scripts), and each entry was audited
  against its script's actual argument parsing. Corrections:
  - `git-agent-commit`: documented the `--model` and `--exclude` options, which
    the code already supported.
  - `git-add-patch`: documented the default no-flag mode (patch-stage every
    modified file) and the `-a` > `-d` > `-s` precedence.
  - `git-browse`: `-b` accepts `firefox`, `chrome`, `chromium`, `google-chrome`;
    `safari` and `edge` were listed but are rejected by the script.
  - `git-check-commitsize`: `-u`/`-l` are required, and `-d` defaults to 365 days.
  - `git-lastdiff`: added the missing `### Options` section (`-n`, `--no-tool`,
    `-h`) and corrected the one-liner — the script diffs the parent of the
    selected commit against `HEAD`, not the commit itself.
  - `git-sparse-checkout`: documented `-s` (skeleton mode) and `-h`, stated that
    `-p` is colon-separated (the v1.0.3 change was never propagated to the wiki),
    that `-p` is required only without `-s`, and that the clone is blobless.
  - `git-sprint-commit`: documented trailing positional arguments and the
    staged-changes precondition.
  - `git-tmp-checkout`: documented `-h` and the auto-generated stash message, and
    corrected the one-liner (`git stash push -a` + `git stash apply`, so the
    stash entry is retained).
  - `git-tree`: one-liners now use `git ls-tree -r --name-only HEAD` to match the
    script; an untracked directory yields empty output rather than an error.
  - `git-delete-obsolete-branch`: the script fetches with `git fetch --prune`
    (not `--all`) and deletes with `git branch -d` (not `-D`).
  - `git-delete-current-repo`: noted that the local `origin` remote is removed on
    success, and documented `-n`/`-h`.
  - `git-push-multiple-remotes`: noted that the script continues past a failed
    push and always exits 0.
  - Added the previously undocumented `-h`/`--help` options for
    `git-create-repo`, `git-repo-update`, `git-tree`, `git-tmp-checkout` and
    `git-whoami`, plus the `fd` requirement for `git-add-gitkeep` and the
    `.yml`/`.yaml` requirement for `git-create-repo`.

### Fixed
- `git-add-newline`: the `--help` text advertised glob-style ignore patterns
  (`-i "*.md"`), but matching uses bash regex (`[[ $file =~ $pattern ]]`), so a
  glob never matched. The examples now show regexes (`-i '\.md$'`).

### Removed
- `VERSION` file. The release workflow derives the tag from the top
  `## [X.Y.Z]` heading in this changelog, so the file was a second, redundant
  source of truth that had to be kept in sync by hand.

## [1.2.0] - 2026-05-20

### Added
- `git-first-add`: for each tracked file, report the commit at which it was first
  added (`--diff-filter=A --reverse`), the most recent re-add commit, and the total
  number of add events. Accepts specific file arguments or defaults to all tracked
  files; supports `-q`/`--no-header` to suppress the table header.
- Contributing guide documenting the branch and release workflow (`CONTRIBUTING.md`).

### CI
- Release workflow: automatically creates a version tag on `develop → main` merges,
  driven by the `VERSION` file.

### Documentation
- Expanded wiki with full script entries and one-liner usage equivalents.

## [1.1.0] - 2026-05-19

### Added
- `git-agent-commit` (renamed from `git-gen-commit`) gains a `--codex` backend that
  generates the commit message via `codex exec` instead of `claude -p`. The staged
  diff is embedded inline in the prompt and only the final agent message is captured.
- `git-secret-ignore`: register one or more patterns in `.git/info/exclude` in a
  single invocation.
- `git-add-gitkeep`: stage repository `.gitkeep` files; uses `-f`/`-I` so ignored
  directories are still picked up.
- `git-delete-remote-branch`: delete remote branches.
- `git-issue2pr`: convert an issue to a PR via `gh api`.
- `git-delete-obsolete-branch`: prune obsolete local branches.
- `git-create-repo`: create a GitHub repository from a YAML metadata file
  (`.github/repository_metadata/gh_repo.yml` by default) via `gh`.
- `git-repo-update`: reconcile a repository's description, homepage and topics
  from the same YAML metadata file.
- `git-delete-current-repo`: delete the GitHub repository for the current working
  directory after confirmation, with `-n` for a dry run.
- `git-sprint-commit`: commit with an ISO year/week prefix (`sprint-YYYY-WWw`).
- `git-ssh-clone-from-https`: clone over SSH given an HTTPS URL.

### Changed
- `git-add-gitkeep` now passes `-f`/`-I` so `.gitkeep` files inside gitignored
  directories are staged.
- `git-lastdiff` supports `-n` offset, `--no-tool` flag, and handles the
  root-commit case.
- Standardized script headers, help handling, and `usage_helper` integration
  across `git-issue2pr`, `git-sparse-checkout`, `git-tmp-checkout`, and `git-tree`.
- `git-delete-obsolete-branch` now uses `usage_helper` for `--help`.
- Shared library helpers and docstrings updated.

## [1.0.3] - 2025-08-06

### Added
- `git-browse`: open the remote repository URL (branch, tag or commit) in a
  browser, with GitHub / GitLab / Bitbucket URL patterns.

### Changed
- `git-sparse-checkout`: change the `sparse_path` separator from comma to colon.

## [1.0.2] - 2025-08-05

### Changed
- `git-sparse-checkout`: separator change (merged from the
  `devin/1722794754-sparse-checkout-wiki` branch).

### Documentation
- Comprehensive documentation for `git-sparse-checkout`.

## [1.0.1] - 2025-08-05

Maintenance release.

## [1.0.0] - 2025-08-05

### Added
- Initial tagged release, with the scripts installed as `src/git-*` (the `.sh`
  extension was added in a later release).
- `git-add-patch`: interactive patch-add helper.
- `git-add-newline`: ensure trailing newline before staging.
- `git-check-commitsize`: report commits above a size threshold within a time
  window.
- `git-lastdiff`: show what the last commit touching a file changed.
- `git-newline-check`: list files missing a trailing newline.
- `git-push-multiple-remotes`: push a branch to every configured remote.
- `git-sparse-checkout`: clone a repository with sparse checkout.
- `git-tmp-checkout`: stash the working tree and move it to a new branch.
- `git-tree`: render git-tracked files as a tree.
- `git-whoami`: print the configured git user name and email.

[Unreleased]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.0.3...v1.1.0
[1.0.3]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/RyoNakagami/regmonkey-gitcommand/releases/tag/v1.0.0
