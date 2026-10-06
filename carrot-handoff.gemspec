# frozen_string_literal: true

require_relative 'lib/carrot_handoff/version'

Gem::Specification.new do |spec|
  spec.name          = 'carrot-handoff'
  spec.version       = CarrotHandoff::VERSION
  spec.authors       = ['Eleazar Meza']
  spec.email         = ['meza.eleazar@gmail.com']

  spec.summary       = 'Carry a task between AI coding agents without losing the thread.'
  spec.description   = <<~DESC
    Writes a committed .carrot.md beside the code describing the task in
    progress: what it is, what state the repository is in, what was tried and
    failed, and the single next action. Plain markdown, no agent integration
    required.
  DESC
  spec.homepage      = 'https://github.com/zarmeza/carrot-handoff'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.3'

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['bin/carrot-handoff', 'lib/**/*.rb', 'README.md', 'LICENSE']
  spec.bindir = 'bin'
  spec.executables = ['carrot-handoff']
  spec.require_paths = ['lib']
end
