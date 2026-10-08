# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

# Rewrite the README's documented block from `Wiring::BLOCK`.
#
# `Wiring.embed` is the same call the spec checks the README against, so running
# this task can only ever produce a file that satisfies its own assertion. Not
# wired into `default`: a task that silently rewrites a tracked file as part of
# the gate hides the fact that the README was out of date, and the spec is
# supposed to be what tells you.
desc 'Rewrite the README block from Wiring::BLOCK'
task :'docs:sync' do
  require_relative 'lib/carrot_handoff'

  path = 'README.md'
  before = File.read(path)
  after = CarrotHandoff::Wiring.embed(before)

  if before == after
    puts "#{path} already in sync"
  else
    File.write(path, after)
    puts "rewrote the #{CarrotHandoff::Wiring::DOC_BEGIN} region of #{path}"
  end
end
