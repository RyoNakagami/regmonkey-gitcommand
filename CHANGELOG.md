# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- Initial tagged release.
- `git-add-patch`: interactive patch-add helper.
- `git-add-newline`: ensure trailing newline before staging.

[Unreleased]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.0.3...v1.1.0
[1.0.3]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/RyoNakagami/regmonkey-gitcommand/releases/tag/v1.0.0
