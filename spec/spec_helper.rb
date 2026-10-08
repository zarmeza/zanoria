# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

require_relative '../lib/zanoria'

# Helpers for building throwaway git repositories, so specs exercise real `git`
# invocations instead of a stubbed interface.
module GitFixture
  # Run a block inside a fresh git repo, with the process cwd moved into it.
  # Yields the repo path. `Zanoria::Git` shells out with the inherited cwd, so
  # chdir is what makes the fixture real rather than mocked.
  def in_repo
    Dir.mktmpdir('carrot-spec') do |dir|
      git(dir, 'init', '--quiet')
      git(dir, 'config', 'user.email', 'spec@example.com')
      git(dir, 'config', 'user.name', 'Spec')

      original = Dir.pwd
      Dir.chdir(dir)
      Zanoria::Git.reset!
      yield dir
    ensure
      Dir.chdir(original)
      Zanoria::Git.reset!
    end
  end

  def git(dir, *args)
    out, status = Open3.capture2(
      { 'GIT_TERMINAL_PROMPT' => '0' }, 'git', *args, chdir: dir
    )
    raise "git #{args.join(' ')} failed: #{out}" unless status.success?

    out
  end

  def commit_all(dir, message: 'Initial commit', filename: 'file.txt', body: 'hello')
    File.write(File.join(dir, filename), body)
    git(dir, 'add', '-A')
    git(dir, 'commit', '--quiet', '-m', message)
  end
end

RSpec.configure do |config|
  config.include GitFixture
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
