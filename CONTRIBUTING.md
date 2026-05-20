# Contributing

## Branch strategy

- Work happens on feature branches cut from `develop`.
- `develop` is the integration branch for day-to-day PRs.
- `main` is the release branch. A merge to `main` triggers the release workflow.

## Push and open a PR

```bash
# Push your feature branch
git push -u origin <your-branch>

# Open a PR targeting develop
gh pr create --base develop
```

For a release PR (develop → main), target `main` instead:

```bash
gh pr create --base main
```

## Merging a release PR

Before merging `develop` → `main`, two things are required:

### 1. Update `CHANGELOG.md`

Add a new version section at the top of the file following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html):

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...
```

Also append a comparison link at the bottom:

```markdown
[X.Y.Z]: https://github.com/RyoNakagami/regmonkey-gitcommand/compare/vX.Y.Z-1...vX.Y.Z
```

### 2. Add the `release` label to the PR

[`.github/workflows/develop-to-main-release.yml`](.github/workflows/develop-to-main-release.yml)
fires when a PR to `main` is closed. It skips unless two conditions are both true:

- `github.event.pull_request.merged == true`
- `contains(github.event.pull_request.labels.*.name, 'release')` — the PR carries the label named exactly **`release`**

Add the label before merging:

```bash
gh pr edit <PR-number> --add-label release
```

When triggered it:

1. Extracts the top version from `CHANGELOG.md` (first line matching `## [X.Y.Z]`).
2. Aborts if that tag already exists in the repo.
3. Creates an annotated tag `vX.Y.Z` and pushes it.
4. Publishes a GitHub Release whose body is the matching `CHANGELOG.md` section.

If the label is missing the workflow is skipped and no tag is created.
