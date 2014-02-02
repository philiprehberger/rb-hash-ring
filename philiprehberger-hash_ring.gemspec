# frozen_string_literal: true

require_relative 'lib/philiprehberger/hash_ring/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-hash_ring'
  spec.version       = Philiprehberger::HashRing::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']
  spec.summary       = 'Consistent hashing for distributed key distribution'
  spec.description   = 'Consistent hash ring with virtual nodes, weighted members, and replication support. ' \
                       'Minimal key redistribution when nodes are added or removed.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-hash-ring'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'
  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
