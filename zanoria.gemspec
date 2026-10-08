# frozen_string_literal: true

require_relative 'lib/zanoria/version'

Gem::Specification.new do |spec|
  spec.name          = 'zanoria'
  spec.version       = Zanoria::VERSION
  spec.authors       = ['Eleazar Meza']
  spec.email         = ['meza.eleazar@gmail.com']

  spec.summary       = 'Carry a task between AI coding agents without losing the thread.'
  spec.description   = <<~DESC
    Writes a committed .carrot.md beside the code describing the task in
    progress: what it is, what state the repository is in, what was tried and
    failed, and the single next action. Plain markdown, no agent integration
    required.
  DESC
  spec.homepage      = 'https://github.com/zarmeza/zanoria'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.3'

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['bin/zanoria', 'lib/**/*.rb', 'README.md', 'LICENSE']
  spec.bindir = 'bin'
  spec.executables = ['zanoria']
  spec.require_paths = ['lib']
end
