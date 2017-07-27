# philiprehberger-hash_ring

[![Tests](https://github.com/philiprehberger/rb-hash-ring/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-hash-ring/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-hash_ring.svg)](https://rubygems.org/gems/philiprehberger-hash_ring)
[![GitHub release](https://img.shields.io/github/v/release/philiprehberger/rb-hash-ring)](https://github.com/philiprehberger/rb-hash-ring/releases)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-hash-ring)](https://github.com/philiprehberger/rb-hash-ring/commits/main)
[![License](https://img.shields.io/github/license/philiprehberger/rb-hash-ring)](LICENSE)
[![Bug Reports](https://img.shields.io/github/issues/philiprehberger/rb-hash-ring/bug)](https://github.com/philiprehberger/rb-hash-ring/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Feature Requests](https://img.shields.io/github/issues/philiprehberger/rb-hash-ring/enhancement)](https://github.com/philiprehberger/rb-hash-ring/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Consistent hashing for distributed key distribution

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem 'philiprehberger-hash_ring'
```

Or install directly:

```bash
gem install philiprehberger-hash_ring
```

## Usage

```ruby
require 'philiprehberger/hash_ring'

ring = Philiprehberger::HashRing::Ring.new(['cache-1', 'cache-2', 'cache-3'])

ring.get('user:42')       # => "cache-2"
ring.get('session:abc')   # => "cache-1"
```

### Weighted Nodes

Assign higher weight to nodes with more capacity:

```ruby
ring = Philiprehberger::HashRing::Ring.new
ring.add('small-server', weight: 1)
ring.add('large-server', weight: 3)
```

### Replication

Fetch multiple distinct nodes for redundancy:

```ruby
ring.get_n('user:42', 2)  # => ["cache-2", "cache-3"]
```

### Custom Hash Function

Use a different hash algorithm instead of the default MD5:

```ruby
ring = Philiprehberger::HashRing::Ring.new(
  ['cache-1', 'cache-2'],
  hash: ->(key) { Digest::SHA256.hexdigest(key) }
)
```

### Migration Plan

Compare two ring topologies to plan node changes:

```ruby
old_ring = Philiprehberger::HashRing::Ring.new(['node-a', 'node-b', 'node-c'])
new_ring = Philiprehberger::HashRing::Ring.new(['node-a', 'node-b', 'node-c', 'node-d'])

plan = old_ring.migration_plan(new_ring)
plan[:moved]    # => [{key_sample: "key_42", from: "node-b", to: "node-d"}, ...]
plan[:summary]  # => {"node-d" => {gained: 2480, lost: 0}, ...}
```

### Serialization

Save and restore ring state as JSON:

```ruby
json = ring.to_json
restored = Philiprehberger::HashRing::Ring.from_json(json)
```

### Balance Score

Measure how evenly keys are distributed across nodes:

```ruby
ring.balance_score  # => 0.95 (1.0 = perfectly balanced)
```

### Batch Key Routing

Find which node handles each key in a batch:

```ruby
result = ring.nodes_for_keys(['user:1', 'user:2', 'user:3'])
# => {"cache-1" => ["user:1", "user:3"], "cache-2" => ["user:2"]}
```

### Distribution Analysis

Check how keys are spread across nodes:

```ruby
keys = (0...1000).map { |i| "key-#{i}" }
ring.distribution(keys)   # => {"cache-1"=>312, "cache-2"=>355, "cache-3"=>333}
```

### Adding and Removing Nodes

```ruby
ring.add('cache-4')       # Only a fraction of keys are redistributed
ring.remove('cache-1')    # Remaining nodes absorb the removed node's keys
```

## API

| Method | Description |
|--------|-------------|
| `Ring.new(nodes = [], replicas: 150, hash: nil)` | Create a ring with optional custom hash function |
| `Ring.from_json(data)` | Reconstruct a ring from JSON string |
| `ring.add(node, weight: 1)` | Add a node (weight multiplies replicas) |
| `ring.remove(node)` | Remove a node and its virtual nodes |
| `ring.get(key)` | Get the node responsible for a key |
| `ring.get_n(key, n)` | Get n distinct physical nodes for a key |
| `ring.nodes` | List all physical nodes |
| `ring.size` | Number of physical nodes |
| `ring.empty?` | Check if the ring is empty |
| `ring.distribution(keys)` | Hash of {node => count} showing key distribution |
| `ring.migration_plan(other_ring)` | Compare topologies and show key movement |
| `ring.to_json` | Serialize ring state to JSON |
| `ring.balance_score` | Distribution quality score (0.0-1.0) |
| `ring.nodes_for_keys(keys)` | Map each key to its responsible node |

## Development

```bash
bundle install
bundle exec rspec      # Run tests
bundle exec rubocop    # Check code style
```

## Support

- [Bug reports](https://github.com/philiprehberger/rb-hash-ring/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
- [Feature requests](https://github.com/philiprehberger/rb-hash-ring/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)
- [GitHub Sponsors](https://github.com/sponsors/philiprehberger)

## License

[MIT](LICENSE)
