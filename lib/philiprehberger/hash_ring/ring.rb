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

      # Add a node to the ring with an optional weight multiplier.
      #
      # @param node [Object] the node identifier to add
      # @param weight [Integer] multiplier applied to the replica count for this node (default: 1)
      # @return [Ring] self for chaining
      def add(node, weight: 1)
        return if @nodes.key?(node)

        @nodes[node] = weight
        rebuild_ring
        self
      end

      # Remove a node and all of its virtual replicas from the ring.
      #
      # @param node [Object] the node identifier to remove
      # @return [Ring] self for chaining
      def remove(node)
        return unless @nodes.key?(node)

        @nodes.delete(node)
        rebuild_ring
        self
      end

      # Find the node responsible for a given key using consistent hashing.
      #
      # @param key [Object] the key to route (coerced to String)
      # @return [Object, nil] the node responsible for the key, or nil if the ring is empty
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

      # Count how many of the supplied keys route to each node.
      #
      # @param keys [Enumerable] the keys to route through the ring
      # @return [Hash{Object => Integer}] a mapping of node to the number of keys routed to it
      def distribution(keys)
        result = Hash.new(0)
        keys.each do |key|
          node = get(key)
          result[node] += 1 if node
        end
        result
      end

      # Measure the balance of key distribution as a coefficient of variation.
      #
      # For each key, determines which node it routes to and counts the per-node
      # distribution. Returns the standard deviation of those counts divided by
      # their mean. Lower values indicate a more uniform distribution
      # (0.0 = perfectly balanced).
      #
      # @param keys [Enumerable] the keys to route through the ring
      # @return [Float] the coefficient of variation of per-node key counts, or
      #   0.0 when `keys` is empty or the ring has 0 or 1 nodes
      def load_factor(keys)
        return 0.0 if @nodes.size < 2

        key_list = keys.to_a
        return 0.0 if key_list.empty?

        dist = distribution(key_list)
        counts = @nodes.keys.map { |node| dist[node] || 0 }
        mean = counts.sum.to_f / counts.size
        return 0.0 if mean.zero?

        variance = counts.sum { |c| (c - mean)**2 } / counts.size.to_f
        Math.sqrt(variance) / mean
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

      def stats(keys)
        return {} if @nodes.empty?

        dist = distribution(keys)
        total = keys.size.to_f
        total_weight = @nodes.values.sum.to_f

        @nodes.each_with_object({}) do |(node, weight), result|
          count = dist[node] || 0
          ideal_pct = if @nodes.values.all? { |w| w == 1 }
                        100.0 / @nodes.size
                      else
                        (weight / total_weight) * 100.0
                      end
          result[node] = {
            count: count,
            percentage: total.zero? ? 0.0 : (count / total) * 100.0,
            ideal_percentage: ideal_pct
          }
        end
      end

      def hotspots(keys, threshold: 1.5)
        return [] if @nodes.empty?

        dist = distribution(keys)
        total = keys.size.to_f
        total_weight = @nodes.values.sum.to_f

        @nodes.each_with_object([]) do |(node, weight), result|
          count = dist[node] || 0
          ideal_count = if @nodes.values.all? { |w| w == 1 }
                          total / @nodes.size
                        else
                          (weight / total_weight) * total
                        end
          result << node if ideal_count.positive? && count > threshold * ideal_count
        end
      end

      def rebalance_suggestions(keys)
        return [] if @nodes.empty?

        node_stats = stats(keys)
        node_stats.each_with_object([]) do |(node, s), suggestions|
          deviation = s[:percentage] - s[:ideal_percentage]
          next unless deviation.abs > 10.0

          suggestions << {
            node: node,
            action: deviation.positive? ? :decrease : :increase,
            current_pct: s[:percentage],
            ideal_pct: s[:ideal_percentage]
          }
        end
      end

      def virtual_nodes
        @nodes.each_with_object({}) do |(node, weight), result|
          result[node] = @replicas * weight
        end
      end

      def hash_for(key)
        hash_key(key.to_s)
      end

      def replicas_for(key, count)
        get_n(key, count)
      end

      # Compare two rings for structural equality (same nodes, weights, replicas).
      #
      # @param other [Ring]
      # @return [Boolean]
      def ==(other)
        other.is_a?(Ring) && @nodes == other.instance_variable_get(:@nodes) && @replicas == other.replicas
      end

      alias eql? ==

      def hash
        [@nodes, @replicas].hash
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
