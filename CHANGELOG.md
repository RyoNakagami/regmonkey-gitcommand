# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
