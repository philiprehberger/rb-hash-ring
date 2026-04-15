# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-04-15

### Added
- `Ring#==` structural equality (same nodes, weights, replicas)

## [0.3.0] - 2026-04-03

### Added

- `Ring#stats(keys)` for per-node count, percentage, and ideal percentage statistics
- `Ring#hotspots(keys, threshold: 1.5)` for detecting nodes handling disproportionate load
- `Ring#rebalance_suggestions(keys)` for actionable rebalancing recommendations
- `Ring#virtual_nodes` for inspecting virtual node counts per real node
- `Ring#hash_for(key)` for exposing computed hash values (useful for debugging)
- `Ring#replicas_for(key, count)` as a discoverable alias for `get_n`

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

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
