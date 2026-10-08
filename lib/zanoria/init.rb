# frozen_string_literal: true

module Zanoria
  # One-time setup for a repository: the note, the agent wiring, and the git
  # tracking that makes both of them durable.
  #
  # `init` is scaffolding and `save` is content. The split matters most in the
  # refusal below: `save` may rewrite the note on every call, but `init` will not
  # touch a note that already exists, because the sections it holds are the only
  # record of what was tried and there is no second copy of them anywhere.
  #
  # Lives outside `CLI` because the orchestration is long enough to matter on its
  # own and is worth testing without going through argument dispatch.
  module Init
    DEFAULT_FILES = ['AGENTS.md'].freeze

    Result = Struct.new(:note, :note_created, :wired, :staged_paths, :outside, keyword_init: true) do
      def note_created?
        note_created
      end

      def wired_changed
        wired.select(&:changed?)
      end

      def wired_current
        wired.reject(&:changed?)
      end

      # Paths relative to the repo root, which is how they read in the suggested
      # `git commit` line and how the person typing it would write them.
      def staged_relative(root)
        staged_paths.map { |path| relative(path, root) }
      end

      def outside_relative(root)
        outside.map { |path| relative(path, root) }
      end

      private

      def relative(path, root)
        prefix = root.end_with?(File::SEPARATOR) ? root : "#{root}#{File::SEPARATOR}"
        path.start_with?(prefix) ? path.delete_prefix(prefix) : path
      end
    end

    module_function

    # Wire `files`, create the note if the repository has none, and stage
    # whatever landed inside the repository.
    def run(files:, task: nil)
      note, created = create_note(task)
      wired = files.map { |path| Wiring.apply(path) }
      inside, outside = split_by_repo(wired.map(&:path) + [note])

      Git.stage(inside) unless inside.empty?

      Result.new(
        note: note,
        note_created: created,
        wired: wired,
        staged_paths: inside,
        outside: outside
      )
    end

    # Write the note, but only when there is not one already.
    #
    # `task` seeds the `Task` section on creation and is ignored otherwise, so
    # re-running `init` with a fresh task line cannot quietly reword a note that
    # an agent has since filled in.
    def create_note(task)
      path = Zanoria::Repo.path
      return [path, false] if File.exist?(path)

      record = Record.new({ task: task.to_s }, path: path)
      [Store.write(path, Template.render(record)), true]
    end

    def split_by_repo(paths)
      return [paths, []] unless Zanoria::Repo.in_repo?

      paths.partition { |path| inside_repo?(path) }
    end

    # Whether `path` resolves under the repository root.
    #
    # Compared with a trailing separator rather than a bare prefix, because
    # `/srv/repo-other` starts with `/srv/repo` as a string and is a different
    # directory. `git add` would reject the path and take the whole command down
    # with it, which is a poor outcome for an instruction file the person
    # deliberately pointed outside the tree.
    def inside_repo?(path)
      root = File.realpath(Zanoria::Repo.root)
      dir = File.realpath(File.dirname(path))
      prefix = root.end_with?(File::SEPARATOR) ? root : "#{root}#{File::SEPARATOR}"

      dir == root || dir.start_with?(prefix)
    rescue SystemCallError
      false
    end
  end
end
