# frozen_string_literal: true

require 'digest/md5'

module Philiprehberger
  module HashRing
    class Ring
      attr_reader :replicas

      def initialize(nodes = [], replicas: 150)
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
        digest = Digest::MD5.digest(key)
        (digest[0].ord << 24) | (digest[1].ord << 16) | (digest[2].ord << 8) | digest[3].ord
      end

      def binary_search(pos)
        idx = @sorted_positions.bsearch_index { |p| p >= pos }
        idx || 0
      end
    end
  end
end
