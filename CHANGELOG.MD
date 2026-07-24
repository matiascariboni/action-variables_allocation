# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-07-24

### Changed
- **Breaking:** Replaced the `ENV_FILE_IN`/`ENV_FILE_OUT` inputs with a single `ENV_FILES`
  input: a JSON array of `[input, output]` file path pairs (e.g.
  `[["./.env.prod", "./.env"], ["./.npmrc.template", "./.npmrc"]]`). Each pair is
  processed sequentially, so a single action run can now generate multiple resolved
  files instead of only one.
- `entrypoint.sh`: `processFile()` and `formatValue()` now take the input/output file
  paths as parameters instead of reading the global `ENV_FILE_IN`/`ENV_FILE_OUT`
  environment variables. A new `parseEnvFiles()` validates `ENV_FILES` (valid JSON
  array, each element a 2-string pair) and fails with a clear error (indicating the
  offending index) if malformed. `processCloudFront()` still runs exactly once, after
  all pairs are processed, unchanged.

## [1.3.0]

### Added
- New optional `CLOUDFRONT` input (default: `false`) in `action.yml` to control whether
  `processCloudFront()` runs at all. When unset or `false`, `entrypoint.sh` skips
  CloudFront distribution ID resolution entirely instead of always attempting it.

## [1.2.2]

### Fixed
- Environment-prefixed variables (e.g. `HOST_DATABASE`, `PORT_DATABASE`,
  `NOTIFICATIONS_SERVICE_URL`) were never resolved on ref names containing a `/`
  (e.g. `deploy/preprod`, `deploy/prod`). Root cause: `findVarName()` built the
  prefix from the **entire** `GITHUB_REF_NAME`, uppercased as-is, so
  `deploy/preprod` produced the literal lookup key `DEPLOY/PREPROD_HOST_DATABASE`
  (with a `/` inside the key) — matching neither the real key in
  `REPO_VARS`/`REPO_SECRETS` (`PREPROD_HOST_DATABASE`) nor the unprefixed fallback
  (`HOST_DATABASE`), so it always fell through to the "not found" error.
  Confirmed via `git log -p --follow -- entrypoint.sh`: this prefix formula was
  unchanged since the very first commit (`v1.0.0`) — **not a regression** from the
  v1.2.1 `&` fix. It was simply never exercised end-to-end on `deploy/*` refs
  before, because the unrelated infinite-loop bug fixed in v1.2.1 kept those runs
  from completing.
  `findVarName()` now derives the prefix from only the last `/`-separated segment
  of `GITHUB_REF_NAME` (e.g. `deploy/preprod` -> `preprod`, `main` -> `main`
  unchanged), joined with `_` as before.
- Removed the "Branch name contains '/'" warning in `processFile()`, since
  ref names with `/` are now handled correctly instead of merely flagged.

## [1.2.1]

### Fixed
- Infinite loop / unbounded line growth in `entrypoint.sh` when a var/secret value contained
  an `&` character. The replacement `line=${line/$placeholder/$processed_value}` used Bash's
  pattern-substitution expansion, which treats an unescaped `&` in the replacement text as
  "the whole matched text" (ksh-inherited behavior), reinserting the placeholder and growing
  the line on every pass of the placeholder-resolution loop. Replaced with a literal
  prefix/suffix substring replacement that never interprets any character specially.
- `read` calls without `-r` were silently stripping backslashes (`\`) from resolved values.
  Added `-r` to all `read` invocations in `entrypoint.sh`.
- Added an iteration cap (50) on the per-line placeholder-resolution loop as a safeguard
  against any future infinite loop of this kind.

## [1.2.0]

### Changed
- Inputs in `action.yml` are now uppercase (`ENV_FILE_IN`, `ENV_FILE_OUT`, `REPO_VARS`, `REPO_SECRETS`) for consistency with environment variables.

### Added
- Full refactor of `entrypoint.sh` into modular functions:
  - `findVarName`, `findVarValue`, `formatValue`, `processFile`, `processCloudFront`.
- Support for `~{VAR}` placeholders: values inserted **without quotes**.
- Detailed logging of resolution process (checked secrets/vars, replacements).
- Optional error bypass for `CLOUDFRONT_DIST_ID` when not defined.

### Improved
- Safer JSON formatting using `jq` instead of manual quoting.
- Enhanced array detection and preservation.
- Better handling of branch names containing `/` (with warning).

## [1.0.7]

### Added

- Json files support, now the numbers, booleans and arrays will have quotes in json output files

### Fixed

- Cloudfront dist is not a problem when there are not distribution in environment variables now

## [1.0.5]

### Added

- Arrays are allowed in venv

### Fixed

- Cloudfront id distribution is no needed anymore
- Example of usage on readme are updated

## [1.0.1]

### Fixed

- Small bugs in action.yml
- Explanations on Readme.md

## [1.0.0]

### Added

- Initialized action

[Unreleased]: https://github.com/matiascariboni/action-variables_allocation/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.3.0...v2.0.0
[1.3.0]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.0.7...v1.2.0
[1.0.7]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.0.5...v1.0.7
[1.0.5]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.0.1...v1.0.5
[1.0.1]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/matiascariboni/action-variables_allocation/compare/f29d4e8...v1.0.0