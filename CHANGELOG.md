# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-28

### Added

- Custom hash function support via `hash:` parameter on `Ring.new`
- `Ring#migration_plan(other_ring)` for planning node topology changes
- `Ring#to_json` and `Ring.from_json` for ring serialization
- `Ring#balance_score` for measuring key distribution quality
- `Ring#nodes_for_keys(keys)` for batch key routing

## [0.1.1] - 2026-03-26

### Changed

- Fix README compliance (license link)

## [0.1.0] - 2026-03-26

### Added
- Initial release
- Consistent hash ring with virtual nodes using MD5 digest
- Weighted node support for uneven distribution
- Replication via `get_n` for fetching multiple distinct nodes
- Key distribution analysis with `distribution` method
- Minimal key redistribution when nodes are added or removed
