# frozen_string_literal: true

module Zanoria
  # Command line entry point.
  #
  # Commands are intentionally few: save, load, status, clear, path. Everything
  # runs on plain text on disk, so no agent integration is required to read or
  # write a note.
  class CLI
    NAME = 'zanoria'

    USAGE = <<~TEXT.freeze
      #{NAME} — carry a task between agent tools

      Usage:
        #{NAME} init [TASK]    set up #{Zanoria::FILENAME} and wire the agent instructions
        #{NAME} save [TASK]    write or update #{Zanoria::FILENAME} for the current repo
        #{NAME} load           print the current handoff note
        #{NAME} status         one-line summary, for a quick check
        #{NAME} clear          delete the current handoff note
        #{NAME} path           print the note's absolute path
        #{NAME} help           this message

      #{NAME} init wires the instruction files the repository already has
      (AGENTS.md, CLAUDE.md), and creates AGENTS.md when it has none. Repeatable
      --file PATH picks the files explicitly instead. It never overwrites an
      existing note.

      #{NAME} save refuses to replace a Task section that holds more than the
      line being written. --replace-task allows it:
      #{NAME} save --replace-task "the new task".

      In an agent session, start with `#{NAME} load` before working on anything
      a previous session left behind.
    TEXT

    # #run returns a process exit status: 0 on success, 1 on a handled failure.
    def initialize(out: $stdout, err: $stderr)
      @out = out
      @err = err
    end

    COMMANDS = {
      'init' => :init, 'setup' => :init,
      'save' => :save, 'new' => :save,
      'load' => :load, 'show' => :load, 'cat' => :load,
      'status' => :status, 'st' => :status,
      'clear' => :clear, 'rm' => :clear,
      'path' => :path,
      'help' => :help, '-h' => :help, '--help' => :help,
      'moo' => :moo
    }.freeze

    # #run returns a process exit status: 0 on success, 1 on a handled failure.
    def run(argv)
      name = argv.shift
      return usage(0) if name.nil?

      command = COMMANDS[name]
      return usage(1, "unknown command #{name.inspect}") if command.nil?

      return usage(0) if command == :help

      # `send`, not `public_send`: the command implementations are private, and
      # the only path here is via COMMANDS, which is a closed set.
      send(command, argv)
    rescue Zanoria::Error => e
      @err.puts "#{NAME}: #{e.message}"
      1
    end

    def usage(status, error = nil)
      @err.puts "#{NAME}: #{error}" if error
      @err.puts unless error.nil?
      @out.puts USAGE
      status
    end

    private

    # Set the repo up for handoffs: note, agent wiring, git staging.
    def init(argv)
      prepare!

      files, task = split_init_args(argv)
      result = Init.run(files: files.empty? ? default_files : files, task: task)

      report_init(result)
      0
    end

    # Instruction files live at the repo root, resolved there rather than against
    # the cwd so `init` works from a subdirectory.
    #
    # Which files those are is the repository's call: the ones it already
    # has, or `AGENTS.md` when it has none.
    def default_files
      root = Zanoria::Repo.root

      Init.default_files(root: root).map { |name| File.join(root, name) }
    end

    # Pull `--file` flags out of argv, leaving the positional words as the task.
    #
    # Both `--file PATH` and `--file=PATH` are accepted. The repeated form is
    # what makes a repo with more than one instruction file a single command
    # rather than a loop the caller has to write.
    def split_init_args(argv)
      files = []
      task = []
      rest = argv.dup

      until rest.empty?
        arg = rest.shift

        case arg
        when '--file', '-f'
          raise Error, "#{arg} needs a path" if rest.empty?

          files << rest.shift
        when /\A--file=(.*)\z/
          raise Error, '--file needs a path' if Regexp.last_match(1).empty?

          files << Regexp.last_match(1)
        else
          task << arg
        end
      end

      [files.map { |path| File.expand_path(path) }, task.join(' ').strip]
    end

    # What `init` did, and the one thing left to do.
    def report_init(result)
      root = Zanoria::Repo.root
      @out.puts "Initialized handoff for #{root}"
      @out.puts "  #{Zanoria::FILENAME.ljust(10)} #{note_summary(result)}"

      result.wired.each { |w| @out.puts "  #{label(w.path, root).ljust(10)} #{wiring_summary(w)}" }

      report_staging(result, root)
    end

    def note_summary(result)
      if result.note_created?
        'created'
      else
        'kept (already exists — `save` updates it, `init` will not)'
      end
    end

    def wiring_summary(wired)
      return 'wired (created)' if wired.created?
      return 'wired' if wired.changed?

      'already current'
    end

    def label(path, root)
      prefix = root.end_with?(File::SEPARATOR) ? root : "#{root}#{File::SEPARATOR}"
      path.start_with?(prefix) ? path.delete_prefix(prefix) : path
    end

    # Staging is the last step that can still leave the note undiscoverable, so
    # it is reported rather than assumed. `Git.stage` returns false on failure
    # and the caller deserves to hear that instead of inferring success from the
    # absence of an error.
    def report_staging(result, root)
      unless Zanoria::Repo.in_repo?
        @out.puts 'No git repository here — this note will not survive a machine'
        @out.puts 'swap. Move it into a repo to make it durable.'
        return
      end

      staged = result.staged_relative(root)
      outside = result.outside_relative(root)

      @out.puts "Staged #{staged.join(' ')}" unless staged.empty?
      report_staging_failures(result, root)
      @out.puts "Left unstaged (outside the repo): #{outside.join(' ')}" unless outside.empty?

      return if staged.empty?

      @out.puts 'Commit it so the next tool sees it:'
      @out.puts %(  git commit -m "chore: add #{staged.join(' ')}")
    end

    # Say what could not be staged, and why.
    #
    # A path git refused is not staged. Reporting it as staged would be the
    # one promise this tool makes about durability, told falsely — and the
    # reason git gave is the only thing that tells the reader what to do
    # about it.
    def report_staging_failures(result, root)
      result.failures_relative(root).each do |failure|
        @out.puts "Could not stage #{failure[:path]}: #{failure[:reason]}"
      end
    end

    def save(argv)
      prepare!

      path = Zanoria::Repo.path
      task, replace_task = split_save_args(argv)
      result = Save.run(path: path, task: task, replace_task: replace_task)

      report_saved(path, result)

      0
    end

    # Pull `--replace-task` out of argv, leaving the task line as one string.
    #
    # A task is often several words, so everything else is joined rather than
    # treated as flags. The flag exists because replacing a `Task` that holds
    # more than its first paragraph is the one save that removes text, and it
    # should be asked for rather than inferred.
    def split_save_args(argv)
      args = argv.dup
      replace_task = !args.delete('--replace-task').nil?

      [args.join(' ').strip, replace_task]
    end

    # What was written, and what is left to do.
    #
    # A note that is not committed does not survive a machine swap, and this
    # is the only place the tool says so.
    def report_saved(path, result)
      if !Zanoria::Repo.in_repo?
        @out.puts "Wrote #{path} (no git repository here — this note will not"
        @out.puts 'survive a machine swap. Move it into a repo to make it durable.)'
      elsif Git.tracked?(Zanoria::FILENAME)
        @out.puts "Wrote #{path} (tracked by git — remember to commit it)"
      else
        @out.puts "Wrote #{path} (untracked — commit it so the next tool sees it)"
      end

      report_replaced_bytes(result)
    end

    # Say that bytes were replaced, because they were.
    #
    # The note is the only copy of the content, and a byte that was not valid
    # UTF-8 is now the replacement character. That is a real change to the
    # file, and it is the kind that is invisible afterwards: the note still
    # parses, `status` still counts the same sections, and nothing would
    # otherwise say that a byte went missing.
    def report_replaced_bytes(result)
      return unless result.replaced_bytes.positive?

      @out.puts "Replaced #{result.replaced_bytes} byte(s) that were not valid UTF-8."
    end

    def load(_argv = [])
      prepare!

      unless Zanoria::Repo.exists?
        @err.puts "#{NAME}: no #{Zanoria::FILENAME} in #{Zanoria::Repo.root}"
        @err.puts 'Nothing was handed off yet.'
        return 1
      end

      @out.puts Store.read_text(Zanoria::Repo.path)
      0
    end

    def status(_argv = [])
      prepare!

      unless Zanoria::Repo.exists?
        @out.puts 'no handoff note'
        return 1
      end

      record = Zanoria::Repo.current
      task = record.task.strip.lines.first.to_s.strip

      @out.puts "task:     #{task.empty? ? '_(not written)_' : task}"
      @out.puts "file:     #{Zanoria::Repo.path}"
      @out.puts "sections: #{written_summary(record)}"
      @out.puts "extra:    #{extra_summary(record)}" unless record.extra_sections.empty?

      # A count cannot see a note that is wrong. These are the things that are
      # wrong in a way a count cannot: content that a save would delete, a
      # heading left behind twice, two headings that are the same section.
      Zanoria::Lint.anomalies(record).each { |anomaly| @out.puts "warning:  #{anomaly}" }

      0
    end

    # How many sections hold real content, excluding the machine-derived State
    # section and anything still showing its template prompt.
    def written_summary(record)
      human = Record::SECTIONS.keys - [:state]
      written = human.count { |key| !Record::PROMPT_RE.match?(record[key].to_s.strip) && !record[key].strip.empty? }

      "#{written}/#{human.size} written"
    end

    # Custom headings, stripped of the "other_" prefix parse adds.
    def extra_summary(record)
      record.extra_sections.map { |key| key.to_s.sub(/\Aother_/, '') }.join(', ')
    end

    def clear(_argv = [])
      prepare!

      path = Zanoria::Repo.path
      unless File.exist?(path)
        @out.puts "nothing to clear (#{path} does not exist)"
        return 0
      end

      Store.delete(path)
      @out.puts "Removed #{path}"
      0
    end

    def path(_argv = [])
      prepare!
      @out.puts Zanoria::Repo.path
      0
    end

    # An easter egg, deliberately absent from `USAGE`. It is registered in
    # `COMMANDS` so `zanoria moo` works, but kept out of the help text so it stays
    # something you find rather than something you read about. `spec/cli_spec.rb`
    # asserts both halves of that: the art prints, and the word "moo" never shows
    # up in help — the second is the one that fails silently if someone tidies
    # the command table later.
    #
    # No `prepare!` here, unlike its neighbours. It reads no note and no git
    # state, so there is nothing to invalidate, and a joke should never touch the
    # repository it was run in.
    def moo(_argv = [])
      @out.puts Moo::ART
      0
    end

    # Discard memoized git state so a note reflects the directory we are in now.
    # Not an error when there is no repository: `Repo.root` falls back to the
    # cwd, and the note is written either way.
    def prepare!
      Git.reset!
    end
  end
end
