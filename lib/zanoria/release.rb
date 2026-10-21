# frozen_string_literal: true

module Zanoria
  # The checks that stand between a working tree and a published gem.
  #
  # Publishing is the one action in this project that cannot be taken back: a
  # pushed gem stays on RubyGems, and the name it claims cannot be released
  # for someone else to take. The checks are therefore written as a pure
  # function over facts the caller gathers, so every one of them can be
  # specified without a network, a gem server, or a real release.
  #
  # The caller supplies the facts and does the publishing. This module decides
  # only whether it is safe to proceed, and says why when it is not.
  module Release
    # The branch a release is cut from.
    BRANCH = 'main'

    module_function

    # Raise `Zanoria::Error` unless it is safe to publish.
    #
    # `dirty` is a list of the worktree's uncommitted paths, `branch` the
    # checked out branch, `published` the versions already on RubyGems, and
    # `version` the one about to be pushed.
    def check!(dirty:, branch:, published:, version:)
      raise Error, "the worktree is dirty (#{dirty.size} file(s)); commit or stash first" unless dirty.empty?

      raise Error, "releases are cut from #{BRANCH}, not #{branch}" unless branch == BRANCH

      return unless published.include?(version)

      raise Error, "#{version} is already published on RubyGems"
    end

    # The versions named in the output of `gem list --remote --exact --all`.
    #
    # The command prints one line per gem, `name (1.0.0, 0.9.0)`, and prints
    # nothing at all for a gem that does not exist yet. Scanning the whole
    # output for version shapes would pick up the digits in a gem's name, and
    # omitting `--exact` would match every gem whose name merely contains
    # this one — so only the parenthesised list is read.
    def published_versions(output)
      match = output.to_s.match(/\(([^)]*)\)/)
      return [] if match.nil?

      match[1].split(',').map(&:strip).reject(&:empty?)
    end
  end
end
