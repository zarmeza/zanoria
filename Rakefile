# frozen_string_literal: true

# The development tasks need gems that are not part of the runtime, so they
# are loaded only when they are there. Someone installing the tool from a
# clone should not have to install rspec and rubocop to do it — and the
# install task is the one an end user is most likely to run.
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new

  task default: %i[spec rubocop]
rescue LoadError => e
  desc 'Run the specs and the linter (needs `bundle install`)'
  task :default do
    abort "the development tasks need the bundle: run `bundle install` (#{e.message})"
  end
end

# Rewrite the README's documented block from `Wiring::BLOCK`.
#
# `Wiring.embed` is the same call the spec checks the README against, so running
# this task can only ever produce a file that satisfies its own assertion. Not
# wired into `default`: a task that silently rewrites a tracked file as part of
# the gate hides the fact that the README was out of date, and the spec is
# supposed to be what tells you.
desc 'Rewrite the README block from Wiring::BLOCK'
task :'docs:sync' do
  require_relative 'lib/zanoria'

  path = 'README.md'
  before = File.read(path)
  after = Zanoria::Wiring.embed(before)

  if before == after
    puts "#{path} already in sync"
  else
    File.write(path, after)
    puts "rewrote the #{Zanoria::Wiring::DOC_BEGIN} region of #{path}"
  end
end

# Build the gem and install it locally.
#
# The installed gem is a snapshot of a release rather than a link to the
# checkout, so the `zanoria` on PATH only changes when this runs again.
desc 'Build the gem and install it locally'
task :install do
  require_relative 'lib/zanoria/version'

  sh 'gem build zanoria.gemspec'
  sh "gem install ./zanoria-#{Zanoria::VERSION}.gem"
end

# Build the gem, tag it, and let CI publish it to RubyGems.
#
# The guard is `Zanoria::Release.check!`, which refuses on a dirty tree, off
# `main`, or with a version that is already published. Publishing is the one
# irreversible action in this project, so the decision lives in the library
# where it can be specified, and this task only gathers the facts and pushes.
#
# The task pushes a tag rather than the gem. The gem is published by the
# workflow, which trades a short-lived OIDC token for push access — there is no
# API key to create, store, or rotate, which is the whole reason that path was
# chosen. Pushing a tag is also the smaller of the two irreversible actions: a
# tag can be deleted, a published version cannot.
desc 'Build the gem, tag it, and let CI publish it to RubyGems'
task :release do
  require 'open3'
  require_relative 'lib/zanoria'

  dirty, = Open3.capture2('git', 'status', '--porcelain', err: File::NULL)
  branch, = Open3.capture2('git', 'rev-parse', '--abbrev-ref', 'HEAD', err: File::NULL)
  listed, status = Open3.capture2('gem', 'list', '--remote', '--exact', '--all', 'zanoria', err: File::NULL)
  abort 'could not reach RubyGems to check the published versions' unless status.success?

  Zanoria::Release.check!(
    dirty: dirty.lines.map(&:strip),
    branch: branch.strip,
    published: Zanoria::Release.published_versions(listed),
    version: Zanoria::VERSION
  )

  sh 'gem build zanoria.gemspec'

  tag = "v#{Zanoria::VERSION}"
  sh "git tag #{tag}"
  sh "git push origin #{tag}"
  puts "pushed #{tag}. The Publish workflow will publish #{Zanoria::VERSION} to RubyGems."
end
