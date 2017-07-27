# frozen_string_literal: true

require 'digest/md5'
require 'json'

module Philiprehberger
  module HashRing
    class Ring
      attr_reader :replicas

      def initialize(nodes = [], replicas: 150, hash: nil)
        if hash
          raise ArgumentError, 'hash must respond to :call' unless hash.respond_to?(:call)

          @custom_hash = hash
        end

        @replicas = replicas
        @nodes = {}
        @ring = []
        @sorted_positions = []

        nodes.each { |node| add(node) }
      end

      def add(node, weight: 1)
        return if @nodes.key?(node)

        @nodes[node] = weight
        rebuild_ring
        self
      end

      def remove(node)
        return unless @nodes.key?(node)

        @nodes.delete(node)
        rebuild_ring
        self
      end

      def get(key)
        return nil if @ring.empty?

        pos = hash_key(key.to_s)
        idx = binary_search(pos)
        @ring[idx][1]
      end

      def get_n(key, count)
        return [] if @ring.empty?

        count = [@nodes.size, count].min
        pos = hash_key(key.to_s)
        idx = binary_search(pos)

        collect_distinct_nodes(idx, count)
      end

      def nodes
        @nodes.keys
      end

      def size
        @nodes.size
      end

      def empty?
        @nodes.empty?
      end

      def distribution(keys)
        result = Hash.new(0)
        keys.each do |key|
          node = get(key)
          result[node] += 1 if node
        end
        result
      end

      def migration_plan(other_ring)
        test_keys = (0...10_000).map { |i| "key_#{i}" }
        moved = []
        summary = Hash.new { |h, k| h[k] = { gained: 0, lost: 0 } }

        test_keys.each do |key|
          from = get(key)
          to = other_ring.get(key)
          next if from == to

          moved << { key_sample: key, from: from, to: to }
          summary[from][:lost] += 1 if from
          summary[to][:gained] += 1 if to
        end

        { moved: moved, summary: summary }
      end

      def to_json(*_args)
        data = {
          'nodes' => @nodes.map { |node, weight| { 'name' => node, 'weight' => weight } },
          'replicas' => @replicas
        }
        JSON.generate(data)
      end

      def self.from_json(data)
        parsed = JSON.parse(data)
        ring = new([], replicas: parsed['replicas'])
        parsed['nodes'].each do |entry|
          ring.add(entry['name'], weight: entry['weight'])
        end
        ring
      end

      def balance_score
        return 1.0 if @nodes.empty?

        test_keys = (0...10_000).map { |i| "key_#{i}" }
        dist = distribution(test_keys)
        counts = @nodes.keys.map { |node| dist[node] || 0 }
        ideal = 10_000.0 / @nodes.size
        mean = counts.sum.to_f / counts.size
        variance = counts.sum { |c| (c - mean)**2 } / counts.size.to_f
        std_dev = Math.sqrt(variance)
        score = 1.0 - (std_dev / ideal)
        score.clamp(0.0, 1.0)
      end

      def nodes_for_keys(keys)
        result = Hash.new { |h, k| h[k] = [] }
        keys.each do |key|
          node = get(key)
          result[node] << key if node
        end
        result
      end

      private

      def collect_distinct_nodes(start_idx, count)
        result = []
        @ring.size.times do |offset|
          node = @ring[(start_idx + offset) % @ring.size][1]
          result << node unless result.include?(node)
          break if result.size >= count
        end
        result
      end

      def rebuild_ring
        @ring = []
        @nodes.each do |node, weight|
          total_replicas = @replicas * weight
          total_replicas.times do |i|
            pos = hash_key("#{node}-#{i}")
            @ring << [pos, node]
          end
        end
        @ring.sort_by!(&:first)
        @sorted_positions = @ring.map(&:first)
      end

      def hash_key(key)
        digest_str = if @custom_hash
                       @custom_hash.call(key)
                     else
                       Digest::MD5.hexdigest(key)
                     end
        digest_str[0, 8].to_i(16)
      end

      def binary_search(pos)
        idx = @sorted_positions.bsearch_index { |p| p >= pos }
        idx || 0
      end
    end
  end
end
