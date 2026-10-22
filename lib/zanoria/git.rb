# frozen_string_literal: true

require 'open3'

module Zanoria
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

    # What a staging attempt did.
    #
    # `paths` are the ones that reached the index. `failed` are the ones git
    # refused, each with git's own reason — a refusal without the reason is
    # not something the reader can act on.
    Staged = Struct.new(:paths, :failed, keyword_init: true)

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
      #
      # The pathspec is anchored at the repository root. `git ls-files` resolves
      # a relative path against the *working directory*, so a note at the root
      # of a repository looks untracked when the tool is run from a
      # subdirectory — and the tool then tells the reader to commit a note that
      # is already committed.
      def tracked?(path)
        return false unless root

        !capture(['ls-files', '--error-unmatch', '--', top_pathspec(path)]).nil?
      end

      # Stage paths for commit, one path at a time.
      #
      # The one call in this module that changes anything, and it answers a
      # question the read paths deliberately do not: did it work? A note that
      # failed to stage prints the same as one that succeeded unless something
      # says otherwise, and "committed so the next tool sees it" is a promise
      # worth keeping honest.
      #
      # One path at a time, because one call for all of them cannot answer the
      # question the report asks. `git add -- .carrot.md AGENTS.md` in a
      # repository where the note is gitignored stages `AGENTS.md`, prints
      # "The following paths are ignored", and exits 1 — so a grouped call
      # can say that something failed but never which, and the note was
      # reported as staged when it was not.
      #
      # What it leaves behind: the index, and nothing else. `git add` writes to
      # the index, and a path git refuses is left where it was.
      def stage(paths)
        result = Staged.new(paths: [], failed: [])

        paths.each do |path|
          outcome = stage_one(path)

          if outcome[:staged]
            result.paths << path
          elsif outcome[:reason]
            result.failed << { path: path, reason: outcome[:reason] }
          end
        end

        result
      end

      private

      # Stage one path.
      #
      # `git add --dry-run` is asked first, because the question the report
      # answers is not "did git exit zero" but "is there anything to commit".
      # A file already in the index as it is on disk produces no output, and
      # reporting it as staged would claim the tool had done something it had
      # not. A file git refuses says why on stderr, and that reason is the
      # only thing that tells the reader what to do about it.
      def stage_one(path)
        out, err, status = Open3.capture3(CLEAN_ENV, 'git', 'add', '--dry-run', '--', path)

        return { staged: false, reason: first_line(err) || 'git refused the path' } unless status.success?
        return { staged: false, reason: nil } if out.strip.empty?

        _out, err, status = Open3.capture3(CLEAN_ENV, 'git', 'add', '--', path)
        return { staged: false, reason: first_line(err) || 'git refused the path' } unless status.success?

        { staged: true, reason: nil }
      rescue Errno::ENOENT
        { staged: false, reason: 'git is not installed' }
      end

      # Git's refusal, on one line.
      #
      # The message runs to several lines — what was ignored, then a hint or
      # two — and the report has one line per path.
      def first_line(text)
        text.to_s.lines.map(&:strip).reject(&:empty?).first
      end

      # The path as a pathspec anchored at the repository root.
      #
      # The `:/` magic makes git resolve the rest of the pathspec against the
      # root of the working tree rather than the current directory, so the
      # answer does not depend on where the tool was run from. A path outside
      # the repository is left alone, and git will refuse it as it should.
      def top_pathspec(path)
        absolute = File.expand_path(path, root)
        prefix = root.end_with?(File::SEPARATOR) ? root : "#{root}#{File::SEPARATOR}"
        return absolute unless absolute.start_with?(prefix)

        ":/#{absolute.delete_prefix(prefix)}"
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
