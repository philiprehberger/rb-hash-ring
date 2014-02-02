# frozen_string_literal: true

require 'spec_helper'

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
end
