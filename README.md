# philiprehberger-hash_ring

[![Tests](https://github.com/philiprehberger/rb-hash-ring/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-hash-ring/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-hash_ring.svg)](https://rubygems.org/gems/philiprehberger-hash_ring)
[![License](https://img.shields.io/github/license/philiprehberger/rb-hash-ring)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Consistent hashing for distributed key distribution

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-hash_ring"
```

Or install directly:

```bash
gem install philiprehberger-hash_ring
```

## Usage

```ruby
require "philiprehberger/hash_ring"

ring = Philiprehberger::HashRing::Ring.new(["cache-1", "cache-2", "cache-3"])

ring.get("user:42")       # => "cache-2"
ring.get("session:abc")   # => "cache-1"
```

### Weighted Nodes

Assign higher weight to nodes with more capacity:

```ruby
ring = Philiprehberger::HashRing::Ring.new
ring.add("small-server", weight: 1)
ring.add("large-server", weight: 3)
```

### Replication

Fetch multiple distinct nodes for redundancy:

```ruby
ring.get_n("user:42", 2)  # => ["cache-2", "cache-3"]
```

### Distribution Analysis

Check how keys are spread across nodes:

```ruby
keys = (0...1000).map { |i| "key-#{i}" }
ring.distribution(keys)   # => {"cache-1"=>312, "cache-2"=>355, "cache-3"=>333}
```

### Adding and Removing Nodes

```ruby
ring.add("cache-4")       # Only a fraction of keys are redistributed
ring.remove("cache-1")    # Remaining nodes absorb the removed node's keys
```

## API

| Method | Description |
|--------|-------------|
| `Ring.new(nodes = [], replicas: 150)` | Create a ring with virtual nodes per physical node |
| `ring.add(node, weight: 1)` | Add a node (weight multiplies replicas) |
| `ring.remove(node)` | Remove a node and its virtual nodes |
| `ring.get(key)` | Get the node responsible for a key |
| `ring.get_n(key, n)` | Get n distinct physical nodes for a key |
| `ring.nodes` | List all physical nodes |
| `ring.size` | Number of physical nodes |
| `ring.empty?` | Check if the ring is empty |
| `ring.distribution(keys)` | Hash of {node => count} showing key distribution |

## Development

```bash
bundle install
bundle exec rspec      # Run tests
bundle exec rubocop    # Check code style
```

## License

MIT
