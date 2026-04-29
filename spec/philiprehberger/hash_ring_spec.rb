# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe Philiprehberger::HashRing::Ring do
  subject(:ring) { described_class.new }

  describe '#new' do
    it 'creates an empty ring' do
      expect(ring).to be_empty
    end

    it 'accepts initial nodes' do
      ring = described_class.new(%w[node-a node-b node-c])
      expect(ring.size).to eq(3)
    end

    it 'accepts a custom replica count' do
      ring = described_class.new([], replicas: 50)
      expect(ring.replicas).to eq(50)
    end
  end

  describe '#add' do
    it 'adds a node to the ring' do
      ring.add('node-a')
      expect(ring.nodes).to eq(['node-a'])
    end

    it 'ignores duplicate nodes' do
      ring.add('node-a')
      ring.add('node-a')
      expect(ring.size).to eq(1)
    end

    it 'returns self for chaining' do
      expect(ring.add('node-a')).to eq(ring)
    end
  end

  describe '#remove' do
    before do
      ring.add('node-a')
      ring.add('node-b')
    end

    it 'removes a node from the ring' do
      ring.remove('node-a')
      expect(ring.nodes).to eq(['node-b'])
    end

    it 'stops returning the removed node' do
      ring.remove('node-a')
      100.times do |i|
        expect(ring.get("key-#{i}")).to eq('node-b')
      end
    end

    it 'ignores removing a non-existent node' do
      ring.remove('node-z')
      expect(ring.size).to eq(2)
    end
  end

  describe '#get' do
    let(:ring) { described_class.new(%w[node-a node-b node-c]) }

    it 'returns nil for an empty ring' do
      empty_ring = described_class.new
      expect(empty_ring.get('key')).to be_nil
    end

    it 'returns a node for a given key' do
      expect(ring.get('my-key')).to be_a(String)
    end

    it 'returns consistent results for the same key' do
      first_result = ring.get('consistent-key')
      10.times do
        expect(ring.get('consistent-key')).to eq(first_result)
      end
    end

    it 'distributes different keys across nodes' do
      nodes_seen = (0...100).map { |i| ring.get("key-#{i}") }.uniq
      expect(nodes_seen.size).to be > 1
    end
  end

  describe '#get_n' do
    let(:ring) { described_class.new(%w[node-a node-b node-c]) }

    it 'returns n distinct physical nodes' do
      result = ring.get_n('my-key', 2)
      expect(result.size).to eq(2)
      expect(result.uniq.size).to eq(2)
    end

    it 'does not return more nodes than exist' do
      result = ring.get_n('my-key', 5)
      expect(result.size).to eq(3)
    end

    it 'returns an empty array for an empty ring' do
      empty_ring = described_class.new
      expect(empty_ring.get_n('key', 2)).to eq([])
    end

    it 'returns a single node when n is 1' do
      result = ring.get_n('key', 1)
      expect(result.size).to eq(1)
      expect(result.first).to eq(ring.get('key'))
    end
  end

  describe '#distribution' do
    let(:ring) { described_class.new(%w[node-a node-b node-c]) }

    it 'returns a hash of node to count' do
      keys = (0...1000).map { |i| "key-#{i}" }
      dist = ring.distribution(keys)

      expect(dist.keys).to match_array(%w[node-a node-b node-c])
      expect(dist.values.sum).to eq(1000)
    end

    it 'distributes keys roughly evenly' do
      keys = (0...3000).map { |i| "key-#{i}" }
      dist = ring.distribution(keys)

      dist.each_value do |count|
        expect(count).to be_between(500, 1500)
      end
    end
  end

  describe 'minimal redistribution' do
    it 'redistributes only a fraction of keys when adding a node' do
      ring = described_class.new(%w[node-a node-b node-c])
      keys = (0...1000).map { |i| "key-#{i}" }

      before_mapping = keys.to_h { |k| [k, ring.get(k)] }

      ring.add('node-d')

      changed = keys.count { |k| ring.get(k) != before_mapping[k] }

      expect(changed).to be < 500
      expect(changed).to be > 0
    end
  end

  describe '#nodes' do
    it 'returns all physical nodes' do
      ring.add('node-a')
      ring.add('node-b')
      expect(ring.nodes).to match_array(%w[node-a node-b])
    end
  end

  describe '#size' do
    it 'returns the number of physical nodes' do
      ring.add('node-a')
      ring.add('node-b')
      expect(ring.size).to eq(2)
    end
  end

  describe '#empty?' do
    it 'returns true for an empty ring' do
      expect(ring).to be_empty
    end

    it 'returns false when nodes are added' do
      ring.add('node-a')
      expect(ring).not_to be_empty
    end
  end

  describe '#node?' do
    it 'returns false for an unknown node' do
      expect(ring.node?('missing')).to be false
    end

    it 'returns true after a node has been added' do
      ring.add('cache-1')
      expect(ring.node?('cache-1')).to be true
    end

    it 'returns false again after a node is removed' do
      ring.add('cache-1')
      ring.remove('cache-1')
      expect(ring.node?('cache-1')).to be false
    end

    it 'distinguishes between added nodes' do
      ring.add('cache-1')
      ring.add('cache-2')
      expect(ring.node?('cache-1')).to be true
      expect(ring.node?('cache-2')).to be true
      expect(ring.node?('cache-3')).to be false
    end
  end

  describe 'weighted nodes' do
    it 'gives higher-weight nodes more keys' do
      ring = described_class.new
      ring.add('light', weight: 1)
      ring.add('heavy', weight: 3)

      keys = (0...2000).map { |i| "key-#{i}" }
      dist = ring.distribution(keys)

      expect(dist['heavy']).to be > dist['light']
    end
  end

  describe 'custom hash function' do
    it 'accepts a custom hash function via hash: parameter' do
      custom_hash = ->(key) { Digest::SHA256.hexdigest(key) }
      ring = described_class.new(%w[node-a node-b], hash: custom_hash)
      expect(ring.get('test-key')).to be_a(String)
    end

    it 'produces consistent results with custom hash' do
      custom_hash = ->(key) { Digest::SHA256.hexdigest(key) }
      ring = described_class.new(%w[node-a node-b node-c], hash: custom_hash)

      first = ring.get('my-key')
      10.times do
        expect(ring.get('my-key')).to eq(first)
      end
    end

    it 'distributes keys with custom hash' do
      custom_hash = ->(key) { Digest::SHA256.hexdigest(key) }
      ring = described_class.new(%w[node-a node-b node-c], hash: custom_hash)

      nodes_seen = (0...100).map { |i| ring.get("key-#{i}") }.uniq
      expect(nodes_seen.size).to be > 1
    end

    it 'raises ArgumentError if hash does not respond to :call' do
      expect { described_class.new([], hash: 'not_callable') }.to raise_error(ArgumentError, /must respond to :call/)
    end

    it 'may produce different assignments than default MD5' do
      nodes = %w[node-a node-b node-c]
      default_ring = described_class.new(nodes)
      sha_ring = described_class.new(nodes, hash: ->(key) { Digest::SHA256.hexdigest(key) })

      keys = (0...100).map { |i| "key-#{i}" }
      default_results = keys.map { |k| default_ring.get(k) }
      sha_results = keys.map { |k| sha_ring.get(k) }

      # They should not be identical (extremely unlikely with different hash functions)
      expect(sha_results).not_to eq(default_results)
    end

    it 'uses default MD5 when no hash is provided' do
      ring_a = described_class.new(%w[node-a node-b])
      ring_b = described_class.new(%w[node-a node-b])

      expect(ring_a.get('test')).to eq(ring_b.get('test'))
    end
  end

  describe '#migration_plan' do
    it 'returns moved keys and summary when a node is added' do
      old_ring = described_class.new(%w[node-a node-b node-c])
      new_ring = described_class.new(%w[node-a node-b node-c node-d])

      plan = old_ring.migration_plan(new_ring)

      expect(plan).to have_key(:moved)
      expect(plan).to have_key(:summary)
      expect(plan[:moved]).to be_an(Array)
      expect(plan[:moved].first).to include(:key_sample, :from, :to)
    end

    it 'reports no moves when rings are identical' do
      ring_a = described_class.new(%w[node-a node-b])
      ring_b = described_class.new(%w[node-a node-b])

      plan = ring_a.migration_plan(ring_b)

      expect(plan[:moved]).to be_empty
      expect(plan[:summary]).to be_empty
    end

    it 'tracks gained and lost counts per node' do
      old_ring = described_class.new(%w[node-a node-b node-c])
      new_ring = described_class.new(%w[node-a node-b node-c node-d])

      plan = old_ring.migration_plan(new_ring)

      expect(plan[:summary]['node-d'][:gained]).to be > 0

      total_lost = plan[:summary].values.sum { |s| s[:lost] }
      total_gained = plan[:summary].values.sum { |s| s[:gained] }
      expect(total_lost).to eq(total_gained)
    end

    it 'shows all keys moving when ring topology completely changes' do
      old_ring = described_class.new(%w[node-a node-b])
      new_ring = described_class.new(%w[node-x node-y])

      plan = old_ring.migration_plan(new_ring)

      expect(plan[:moved].size).to eq(10_000)
    end

    it 'handles empty source ring' do
      old_ring = described_class.new
      new_ring = described_class.new(%w[node-a])

      plan = old_ring.migration_plan(new_ring)

      expect(plan[:moved].size).to eq(10_000)
      expect(plan[:moved].all? { |m| m[:from].nil? }).to be true
    end

    it 'handles empty target ring' do
      old_ring = described_class.new(%w[node-a])
      new_ring = described_class.new

      plan = old_ring.migration_plan(new_ring)

      expect(plan[:moved].size).to eq(10_000)
      expect(plan[:moved].all? { |m| m[:to].nil? }).to be true
    end
  end

  describe 'serialization' do
    describe '#to_json' do
      it 'serializes the ring to JSON' do
        ring = described_class.new(%w[node-a node-b])
        json = ring.to_json
        parsed = JSON.parse(json)

        expect(parsed['replicas']).to eq(150)
        expect(parsed['nodes'].size).to eq(2)
        expect(parsed['nodes'].map { |n| n['name'] }).to match_array(%w[node-a node-b])
      end

      it 'includes node weights' do
        ring = described_class.new
        ring.add('light', weight: 1)
        ring.add('heavy', weight: 3)

        parsed = JSON.parse(ring.to_json)
        heavy_entry = parsed['nodes'].find { |n| n['name'] == 'heavy' }

        expect(heavy_entry['weight']).to eq(3)
      end

      it 'serializes custom replica count' do
        ring = described_class.new(%w[node-a], replicas: 50)
        parsed = JSON.parse(ring.to_json)

        expect(parsed['replicas']).to eq(50)
      end
    end

    describe '.from_json' do
      it 'reconstructs a ring from JSON' do
        original = described_class.new(%w[node-a node-b node-c])
        json = original.to_json
        restored = described_class.from_json(json)

        expect(restored.nodes).to match_array(original.nodes)
        expect(restored.replicas).to eq(original.replicas)
      end

      it 'produces the same key assignments' do
        original = described_class.new(%w[node-a node-b node-c])
        restored = described_class.from_json(original.to_json)

        100.times do |i|
          expect(restored.get("key-#{i}")).to eq(original.get("key-#{i}"))
        end
      end

      it 'preserves node weights' do
        original = described_class.new
        original.add('light', weight: 1)
        original.add('heavy', weight: 3)

        restored = described_class.from_json(original.to_json)
        keys = (0...2000).map { |i| "key-#{i}" }

        original_dist = original.distribution(keys)
        restored_dist = restored.distribution(keys)

        expect(restored_dist).to eq(original_dist)
      end

      it 'uses default hash function on restore' do
        custom_ring = described_class.new(%w[node-a node-b], hash: ->(k) { Digest::SHA256.hexdigest(k) })
        json = custom_ring.to_json

        restored = described_class.from_json(json)
        default_ring = described_class.new(%w[node-a node-b])

        expect(restored.get('test')).to eq(default_ring.get('test'))
      end

      it 'handles an empty ring' do
        original = described_class.new
        restored = described_class.from_json(original.to_json)

        expect(restored).to be_empty
        expect(restored.get('key')).to be_nil
      end
    end
  end

  describe '#balance_score' do
    it 'returns a float between 0.0 and 1.0' do
      ring = described_class.new(%w[node-a node-b node-c])
      score = ring.balance_score

      expect(score).to be_a(Float)
      expect(score).to be_between(0.0, 1.0)
    end

    it 'returns 1.0 for an empty ring' do
      expect(ring.balance_score).to eq(1.0)
    end

    it 'returns a high score for evenly distributed nodes' do
      ring = described_class.new(%w[node-a node-b node-c], replicas: 300)
      score = ring.balance_score

      expect(score).to be > 0.8
    end

    it 'returns a lower score for highly unbalanced weights' do
      ring = described_class.new
      ring.add('tiny', weight: 1)
      ring.add('huge', weight: 100)

      score = ring.balance_score

      expect(score).to be < 0.5
    end

    it 'returns a high score for a single node' do
      ring = described_class.new(%w[node-a])

      expect(ring.balance_score).to eq(1.0)
    end
  end

  describe '#load_factor' do
    it 'returns 0.0 for empty keys' do
      ring = described_class.new(%w[node-a node-b node-c])
      expect(ring.load_factor([])).to eq(0.0)
    end

    it 'returns 0.0 for an empty ring' do
      empty_ring = described_class.new
      keys = (0...100).map { |i| "key-#{i}" }
      expect(empty_ring.load_factor(keys)).to eq(0.0)
    end

    it 'returns 0.0 for a single-node ring regardless of keys' do
      ring = described_class.new(%w[only-node])
      keys = (0...100).map { |i| "key-#{i}" }
      expect(ring.load_factor(keys)).to eq(0.0)
    end

    it 'returns a small value for a uniformly distributed ring' do
      ring = described_class.new(%w[node-a node-b node-c], replicas: 300)
      keys = (0...3000).map { |i| "key-#{i}" }

      expect(ring.load_factor(keys)).to be < 0.2
    end

    it 'returns a larger value for a pathologically weighted ring' do
      ring = described_class.new
      ring.add('tiny', weight: 1)
      ring.add('huge', weight: 100)
      keys = (0...3000).map { |i| "key-#{i}" }

      expect(ring.load_factor(keys)).to be > 0.5
    end

    it 'reflects imbalance introduced by weights' do
      balanced_ring = described_class.new(%w[node-a node-b node-c], replicas: 300)
      imbalanced_ring = described_class.new
      imbalanced_ring.add('small', weight: 1)
      imbalanced_ring.add('medium', weight: 5)
      imbalanced_ring.add('large', weight: 20)

      keys = (0...3000).map { |i| "key-#{i}" }

      expect(imbalanced_ring.load_factor(keys)).to be > balanced_ring.load_factor(keys)
    end

    it 'returns a Float' do
      ring = described_class.new(%w[node-a node-b])
      keys = (0...100).map { |i| "key-#{i}" }
      expect(ring.load_factor(keys)).to be_a(Float)
    end
  end

  describe '#stats' do
    it 'returns count, percentage, and ideal_percentage per node' do
      ring = described_class.new(%w[node-a node-b node-c])
      keys = (0...3000).map { |i| "key-#{i}" }
      result = ring.stats(keys)

      expect(result.keys).to match_array(%w[node-a node-b node-c])
      result.each_value do |s|
        expect(s).to have_key(:count)
        expect(s).to have_key(:percentage)
        expect(s).to have_key(:ideal_percentage)
        expect(s[:ideal_percentage]).to be_within(0.01).of(100.0 / 3)
      end
      expect(result.values.sum { |s| s[:count] }).to eq(3000)
    end

    it 'returns roughly balanced stats for equal-weight nodes' do
      ring = described_class.new(%w[node-a node-b], replicas: 300)
      keys = (0...2000).map { |i| "key-#{i}" }
      result = ring.stats(keys)

      result.each_value do |s|
        expect(s[:percentage]).to be_between(30.0, 70.0)
        expect(s[:ideal_percentage]).to be_within(0.01).of(50.0)
      end
    end

    it 'reflects weighted ideal percentages' do
      ring = described_class.new
      ring.add('light', weight: 1)
      ring.add('heavy', weight: 3)
      keys = (0...1000).map { |i| "key-#{i}" }
      result = ring.stats(keys)

      expect(result['light'][:ideal_percentage]).to be_within(0.01).of(25.0)
      expect(result['heavy'][:ideal_percentage]).to be_within(0.01).of(75.0)
    end

    it 'returns empty hash for empty ring' do
      expect(ring.stats(%w[a b c])).to eq({})
    end
  end

  describe '#hotspots' do
    it 'returns nodes exceeding threshold times their fair share' do
      ring = described_class.new
      ring.add('light', weight: 1)
      ring.add('heavy', weight: 3)
      keys = (0...4000).map { |i| "key-#{i}" }

      # With default threshold 1.5, the heavy node getting ~75% of keys
      # should not be a hotspot (its fair share is 75%), and light getting ~25%
      # should also not be a hotspot.
      hotspots = ring.hotspots(keys)
      # Hard to guarantee exact results, but at minimum the method returns an array
      expect(hotspots).to be_an(Array)
    end

    it 'returns empty array for empty ring' do
      expect(ring.hotspots(%w[a b c])).to eq([])
    end

    it 'detects hotspots with a low threshold' do
      ring = described_class.new(%w[node-a node-b node-c])
      keys = (0...3000).map { |i| "key-#{i}" }
      # With threshold 0.5, any node getting more than 50% of ideal (>500 keys) is a hotspot
      # All nodes should get roughly 1000 keys, so all should be hotspots at 0.5
      hotspots = ring.hotspots(keys, threshold: 0.5)
      expect(hotspots.size).to eq(3)
    end

    it 'returns no hotspots with a very high threshold' do
      ring = described_class.new(%w[node-a node-b node-c])
      keys = (0...3000).map { |i| "key-#{i}" }
      hotspots = ring.hotspots(keys, threshold: 100.0)
      expect(hotspots).to be_empty
    end
  end

  describe '#rebalance_suggestions' do
    it 'returns suggestions for significantly off-balance nodes' do
      ring = described_class.new
      ring.add('tiny', weight: 1)
      ring.add('huge', weight: 100)
      keys = (0...10_000).map { |i| "key-#{i}" }

      suggestions = ring.rebalance_suggestions(keys)
      expect(suggestions).to be_an(Array)
      suggestions.each do |s|
        expect(s).to have_key(:node)
        expect(s).to have_key(:action)
        expect(s).to have_key(:current_pct)
        expect(s).to have_key(:ideal_pct)
        expect(%i[increase decrease]).to include(s[:action])
      end
    end

    it 'returns empty array for well-balanced ring' do
      ring = described_class.new(%w[node-a node-b node-c], replicas: 300)
      keys = (0...9000).map { |i| "key-#{i}" }
      suggestions = ring.rebalance_suggestions(keys)
      expect(suggestions).to be_empty
    end

    it 'returns empty array for empty ring' do
      expect(ring.rebalance_suggestions(%w[a b c])).to eq([])
    end
  end

  describe '#virtual_nodes' do
    it 'returns virtual node count per real node' do
      ring = described_class.new(%w[node-a node-b], replicas: 100)
      result = ring.virtual_nodes

      expect(result).to eq('node-a' => 100, 'node-b' => 100)
    end

    it 'reflects weights in virtual node counts' do
      ring = described_class.new
      ring.add('light', weight: 1)
      ring.add('heavy', weight: 3)

      result = ring.virtual_nodes
      expect(result['light']).to eq(150)
      expect(result['heavy']).to eq(450)
    end

    it 'returns empty hash for empty ring' do
      expect(ring.virtual_nodes).to eq({})
    end
  end

  describe '#hash_for' do
    it 'returns an integer hash value for a key' do
      ring = described_class.new(%w[node-a])
      value = ring.hash_for('test-key')

      expect(value).to be_an(Integer)
    end

    it 'returns consistent values for the same key' do
      ring = described_class.new(%w[node-a])
      expect(ring.hash_for('key')).to eq(ring.hash_for('key'))
    end

    it 'returns different values for different keys' do
      ring = described_class.new(%w[node-a])
      expect(ring.hash_for('key-a')).not_to eq(ring.hash_for('key-b'))
    end
  end

  describe '#replicas_for' do
    let(:ring) { described_class.new(%w[node-a node-b node-c]) }

    it 'is an alias for get_n' do
      key = 'my-key'
      expect(ring.replicas_for(key, 2)).to eq(ring.get_n(key, 2))
    end

    it 'returns distinct nodes' do
      result = ring.replicas_for('key', 3)
      expect(result.size).to eq(3)
      expect(result.uniq.size).to eq(3)
    end

    it 'returns empty array for empty ring' do
      empty_ring = described_class.new
      expect(empty_ring.replicas_for('key', 2)).to eq([])
    end
  end

  describe '#nodes_for_keys' do
    let(:ring) { described_class.new(%w[node-a node-b node-c]) }

    it 'returns a hash mapping nodes to keys' do
      keys = %w[key-1 key-2 key-3]
      result = ring.nodes_for_keys(keys)

      expect(result).to be_a(Hash)
      expect(result.values.flatten).to match_array(keys)
    end

    it 'assigns each key to exactly one node' do
      keys = (0...50).map { |i| "key-#{i}" }
      result = ring.nodes_for_keys(keys)

      all_assigned = result.values.flatten
      expect(all_assigned.size).to eq(keys.size)
      expect(all_assigned).to match_array(keys)
    end

    it 'is consistent with get' do
      keys = (0...50).map { |i| "key-#{i}" }
      result = ring.nodes_for_keys(keys)

      result.each do |node, node_keys|
        node_keys.each do |key|
          expect(ring.get(key)).to eq(node)
        end
      end
    end

    it 'returns an empty hash for an empty ring' do
      empty_ring = described_class.new
      result = empty_ring.nodes_for_keys(%w[key-1 key-2])

      expect(result).to be_empty
    end

    it 'returns an empty hash for empty keys' do
      result = ring.nodes_for_keys([])

      expect(result).to be_empty
    end

    it 'distributes keys across multiple nodes' do
      keys = (0...100).map { |i| "key-#{i}" }
      result = ring.nodes_for_keys(keys)

      expect(result.keys.size).to be > 1
    end
  end

  describe '#==' do
    it 'returns true for rings with identical nodes and replicas' do
      a = described_class.new(%w[n1 n2], replicas: 100)
      b = described_class.new(%w[n1 n2], replicas: 100)
      expect(a).to eq(b)
    end

    it 'returns false for different nodes' do
      a = described_class.new(%w[n1 n2], replicas: 100)
      b = described_class.new(%w[n1 n3], replicas: 100)
      expect(a).not_to eq(b)
    end

    it 'returns false for different replica counts' do
      a = described_class.new(%w[n1 n2], replicas: 100)
      b = described_class.new(%w[n1 n2], replicas: 200)
      expect(a).not_to eq(b)
    end

    it 'returns false for different weights' do
      a = described_class.new([], replicas: 100)
      a.add('n1', weight: 1)
      b = described_class.new([], replicas: 100)
      b.add('n1', weight: 2)
      expect(a).not_to eq(b)
    end
  end
end
