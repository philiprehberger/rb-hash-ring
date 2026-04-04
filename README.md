# philiprehberger-hash_ring

[![Tests](https://github.com/philiprehberger/rb-hash-ring/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-hash-ring/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-hash_ring.svg)](https://rubygems.org/gems/philiprehberger-hash_ring)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-hash-ring)](https://github.com/philiprehberger/rb-hash-ring/commits/main)

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

### Per-Node Statistics

Get detailed statistics including ideal vs actual distribution:

```ruby
keys = (0...3000).map { |i| "key-#{i}" }
ring.stats(keys)
# => {"cache-1" => {count: 1012, percentage: 33.7, ideal_percentage: 33.33}, ...}
```

### Hotspot Detection

Find nodes handling disproportionate load:

```ruby
ring.hotspots(keys)                   # Nodes at >1.5x their fair share
ring.hotspots(keys, threshold: 2.0)   # Nodes at >2x their fair share
```

### Rebalance Suggestions

Get actionable recommendations for off-balance nodes:

```ruby
ring.rebalance_suggestions(keys)
# => [{node: "cache-1", action: :increase, current_pct: 15.2, ideal_pct: 33.33}, ...]
```

### Virtual Node Inspection

See how many virtual nodes each real node has:

```ruby
ring.virtual_nodes  # => {"cache-1" => 150, "cache-2" => 150, "cache-3" => 450}
```

### Hash Debugging

Expose the hash value computed for a given key:

```ruby
ring.hash_for('user:42')  # => 2837291045
```

### Replica Lookup

A more discoverable alias for `get_n`:

```ruby
ring.replicas_for('user:42', 2)  # => ["cache-2", "cache-3"]
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
| `ring.stats(keys)` | Per-node count, percentage, and ideal percentage |
| `ring.hotspots(keys, threshold: 1.5)` | Nodes exceeding threshold times their fair share |
| `ring.rebalance_suggestions(keys)` | Actionable suggestions for off-balance nodes |
| `ring.virtual_nodes` | Hash of {node => virtual_node_count} |
| `ring.hash_for(key)` | Computed hash value for a key |
| `ring.replicas_for(key, count)` | Alias for `get_n` (more discoverable name) |

## Development

```bash
bundle install
bundle exec rspec      # Run tests
bundle exec rubocop    # Check code style
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-hash-ring)

🐛 [Report issues](https://github.com/philiprehberger/rb-hash-ring/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-hash-ring/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
