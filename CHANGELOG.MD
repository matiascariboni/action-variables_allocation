# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.0.7...v1.2.0
[1.0.7]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.0.5...v1.0.7
[1.0.5]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.0.1...v1.0.5
[1.0.1]: https://github.com/matiascariboni/action-variables_allocation/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/matiascariboni/action-variables_allocation/compare/f29d4e8...v1.0.0