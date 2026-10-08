# frozen_string_literal: true

require 'open3'

module CarrotHandoff
  # Thin wrapper over the `git` binary.
  #
  # Everything here degrades to nil rather than raising. A handoff note is still
  # useful in a dirty worktree or a repo with no commits yet, so a missing fact
  # must never stop the tool from writing one.
  module Git
    # Commands run with a scrubbed environment. A hook or a stray alias in the
    # user's config must not change what we report.
    CLEAN_ENV = {
      'GIT_OPTIONAL_LOCKS' => '0',
      'GIT_TERMINAL_PROMPT' => '0'
    }.freeze

    class << self
      # Absolute path of the repository root, or nil when not in a repo.
      def root
        @root ||= capture(%w[rev-parse --show-toplevel])
      end

      # Discard memoized state. Needed when the process outlives a `cd`.
      def reset!
        @root = nil
      end

      def branch
        value = capture(%w[rev-parse --abbrev-ref HEAD])
        return if value.nil? || value == 'HEAD'

        value
      end

      # Uncommitted changes as porcelain status lines, e.g. " M lib/foo.rb".
      def dirty_files
        (capture(%w[status --porcelain]) || '').lines.map(&:strip).reject(&:empty?)
      end

      def clean?
        dirty_files.empty?
      end

      # Files that differ from HEAD, ignoring untracked ones. Empty output when
      # there is no HEAD yet (fresh repo).
      def changed_tracked_files
        (capture(%w[diff --name-only HEAD]) || '').lines.map(&:strip).reject(&:empty?)
      end

      # HEAD abbreviated sha, or nil when the repository has no commits.
      def head
        capture(%w[rev-parse --short HEAD])
      end

      # One-line summary of the most recent commits, newest first.
      def recent_commits(limit = 5)
        (capture(%w[log -n] + [limit.to_s, '--format=%h %s']) || '').lines.map(&:strip)
      end

      # True when the file is tracked by git.
      def tracked?(path)
        return false unless root

        !capture(['ls-files', '--error-unmatch', path]).nil?
      end

      # Stage paths for commit.
      #
      # The one call in this module that changes anything, and it answers a
      # question the read paths deliberately do not: did it work? A note that
      # failed to stage prints the same as one that succeeded unless something
      # says otherwise, and "committed so the next tool sees it" is a promise
      # worth keeping honest.
      def stage(paths)
        return false if paths.empty?

        run('add', '--', *paths)
      end

      private

      # True when git exits zero. Deliberately not `capture`: staging produces no
      # output worth keeping, and reporting failure as `nil` would be
      # indistinguishable from the empty-output case the readers rely on.
      def run(*)
        _out, status = Open3.capture2(CLEAN_ENV, 'git', *, err: File::NULL)
        status.success?
      rescue Errno::ENOENT
        false
      end

      # Run git and return stripped stdout, or nil on any failure.
      #
      # stderr is discarded deliberately. `git ls-files --error-unmatch` is the
      # standard way to test whether a path is tracked, and it complains on
      # stderr while doing so. A note-taking tool should not print that noise.
      def capture(args)
        out, status = Open3.capture2(CLEAN_ENV, 'git', *args, err: File::NULL)
        return nil unless status.success?

        out.strip.empty? ? nil : out.strip
      rescue Errno::ENOENT
        # git is not installed at all.
        nil
      end
    end
  end
end
