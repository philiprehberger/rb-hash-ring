# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-26

### Added
- Initial release
- Consistent hash ring with virtual nodes using MD5 digest
- Weighted node support for uneven distribution
- Replication via `get_n` for fetching multiple distinct nodes
- Key distribution analysis with `distribution` method
- Minimal key redistribution when nodes are added or removed
