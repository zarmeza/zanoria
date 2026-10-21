# frozen_string_literal: true

require_relative 'lib/zanoria/version'

# The files that ship in the gem.
#
# Resolved against this file's own directory rather than the working
# directory, so the list is the same wherever the build runs and a stray
# `lib/` elsewhere cannot change what ships.
#
# The build still has to be run from the gem's root: RubyGems validates
# `spec.files` against the working directory, so `gem build` from anywhere
# else fails with `["bin/zanoria"] are not files`. That is RubyGems' own
# rule, not this gemspec's.
#
# Not frozen: `Gem::Specification#normalize` appends to `spec.files`, so a
# frozen array fails the build with a FrozenError.
GEM_FILES = Dir.chdir(__dir__) do
  Dir['bin/zanoria', 'lib/**/*.rb', 'README.md', 'LICENSE']
end

Gem::Specification.new do |spec|
  spec.name          = 'zanoria'
  spec.version       = Zanoria::VERSION
  spec.authors       = ['Eleazar Meza']
  spec.email         = ['meza.eleazar@gmail.com']

  spec.summary       = 'Carry a task between AI coding agents without losing the thread.'
  spec.description   = <<~DESC
    Writes a committed .carrot.md beside the code describing the task in
    progress: what it is, what state the repository is in, what was tried and
    failed, and the single next step. Plain markdown, no agent integration
    required.
  DESC
  spec.homepage      = 'https://github.com/zarmeza/zanoria'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.3'

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['source_code_uri'] = 'https://github.com/zarmeza/zanoria'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/zarmeza/zanoria/issues'
  spec.metadata['changelog_uri'] = 'https://github.com/zarmeza/zanoria/commits/main'
  spec.metadata['documentation_uri'] = 'https://github.com/zarmeza/zanoria#readme'

  spec.files = GEM_FILES
  spec.bindir = 'bin'
  spec.executables = ['zanoria']
  spec.require_paths = ['lib']
end
