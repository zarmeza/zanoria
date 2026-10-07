# frozen_string_literal: true

module CarrotHandoff
  # Command line entry point.
  #
  # Commands are intentionally few: save, load, status, clear, path. Everything
  # runs on plain text on disk, so no agent integration is required to read or
  # write a note.
  class CLI
    NAME = 'carrot-handoff'

    USAGE = <<~TEXT.freeze
      #{NAME} — carry a task between agent tools

      Usage:
        #{NAME} save [TASK]   write or update #{CarrotHandoff::FILENAME} for the current repo
        #{NAME} load          print the current handoff note
        #{NAME} status        one-line summary, for a quick check
        #{NAME} clear         delete the current handoff note
        #{NAME} path          print the note's absolute path
        #{NAME} help          this message

      In an agent session, start with `#{NAME} load` before working on anything
      a previous session left behind.
    TEXT

    # #run returns a process exit status: 0 on success, 1 on a handled failure.
    def initialize(out: $stdout, err: $stderr)
      @out = out
      @err = err
    end

    COMMANDS = {
      'save' => :save, 'new' => :save,
      'load' => :load, 'show' => :load, 'cat' => :load,
      'status' => :status, 'st' => :status,
      'clear' => :clear, 'rm' => :clear,
      'path' => :path,
      'help' => :help, '-h' => :help, '--help' => :help
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
    rescue CarrotHandoff::Error => e
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

    def save(argv)
      prepare!

      path = CarrotHandoff::Repo.path
      existing = Store.read_or_empty(path)
      task = argv.join(' ').strip

      sections = existing.sections.dup
      sections[:task] = task unless task.empty?

      record = Record.new(sections, path: path)
      Store.write(path, Template.render(record))

      if !CarrotHandoff::Repo.in_repo?
        @out.puts "Wrote #{path} (no git repository here — this note will not"
        @out.puts 'survive a machine swap. Move it into a repo to make it durable.)'
      elsif Git.tracked?(CarrotHandoff::FILENAME)
        @out.puts "Wrote #{path} (tracked by git — remember to commit it)"
      else
        @out.puts "Wrote #{path} (untracked — commit it so the next tool sees it)"
      end

      0
    end

    def load(_argv = [])
      prepare!

      unless CarrotHandoff::Repo.exists?
        @err.puts "#{NAME}: no #{CarrotHandoff::FILENAME} in #{CarrotHandoff::Repo.root}"
        @err.puts 'Nothing was handed off yet.'
        return 1
      end

      @out.puts File.read(CarrotHandoff::Repo.path)
      0
    end

    def status(_argv = [])
      prepare!

      unless CarrotHandoff::Repo.exists?
        @out.puts 'no handoff note'
        return 1
      end

      record = CarrotHandoff::Repo.current
      task = record.task.strip.lines.first.to_s.strip

      @out.puts "task:     #{task.empty? ? '_(not written)_' : task}"
      @out.puts "file:     #{CarrotHandoff::Repo.path}"
      @out.puts "sections: #{written_summary(record)}"
      @out.puts "extra:    #{extra_summary(record)}" unless record.extra_sections.empty?

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

      path = CarrotHandoff::Repo.path
      unless File.exist?(path)
        @out.puts "nothing to clear (#{path} does not exist)"
        return 0
      end

      File.delete(path)
      @out.puts "Removed #{path}"
      0
    end

    def path(_argv = [])
      prepare!
      @out.puts CarrotHandoff::Repo.path
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
