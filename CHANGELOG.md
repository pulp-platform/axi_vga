# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Unreleased

## 0.1.4 - 2024-09-19
### Changed
- Use assert macros from `common_cells`.

## 0.1.3 - 2024-03-14
### Changed
- Fix Ax PROT to issue secure requests.

## 0.1.2 - 2024-03-14
### Changed
- Update dependencies
    - bump AXI from `0.38.0` to `0.39.2`
    - bump Common Cells from `1.28.0` to `1.33.0`
    - bump Register Interface from `0.3.8` to `0.4.2`

### Fixed
- Buffer reads in a credit-counter-controlled FIFO to prevent memory trashing.

## 0.1.1 - 2023-01-30
### Fixed
- Fix typo in GNU Make fragment root variable

## 0.1.0 - 2023-01-30
### Added
- Add Makefrag and CI linting for licensing, RTL, and build.
- Add AXI VGA sources from Neo with some fixes.
