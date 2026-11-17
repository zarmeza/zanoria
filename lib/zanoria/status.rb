# frozen_string_literal: true

module Zanoria
  # The facts `status` derives, as opposed to the ones the note stores.
  #
  # Lives outside `CLI` for the reason AGENTS.md gives: `CLI` sits at the ceiling
  # of `Metrics/ClassLength`, and a command class that grows by one formatting
  # method per feature is a class nobody reads. These three are also the part of
  # the summary worth testing without a stream.
  module Status
    # Past this the note stops being a handoff and becomes an archive nobody
    # scrolls through. 32 KiB is a few hundred lines of prose — more than a
    # round needs, small enough that the warning still means something.
    SIZE_LIMIT = 32 * 1024

    module_function

    # Everything `status` prints, as one block of text.
    #
    # Kept here rather than in the command class so the summary can grow
    # without the dispatcher growing with it. `status` is the command people
    # read most often, so every new fact lands here.
    def report(record, path:)
      task = record.task.strip.lines.first.to_s.strip
      lines = [
        "task:     #{task.empty? ? '_(not written)_' : task}",
        "file:     #{path}",
        "sections: #{written_summary(record)}"
      ]

      extra = extra_summary(record)
      lines << "extra:    #{extra}" unless extra.empty?

      unpushed_line = unpushed(path)
      lines << unpushed_line if unpushed_line

      # A count cannot see a note that is wrong. These are the things that are
      # wrong in a way a count cannot: content that a save would delete, a
      # heading left behind twice, two headings that are the same section.
      Lint.anomalies(record).each { |anomaly| lines << "warning:  #{anomaly}" }

      large = size_warning(path)
      lines << "warning:  #{large}" if large

      lines.join("\n")
    end

    # How many of the human sections hold real content.
    #
    # `State` is excluded because it is machine-derived, and a section still
    # showing its `_TODO:` prompt is excluded because it is a question rather
    # than an answer.
    def written_summary(record)
      human = Record::SECTIONS.keys - [:state]
      written = human.count { |key| authored?(record[key]) }

      "#{written}/#{human.size} written"
    end

    # Custom headings, stripped of the `other_` prefix parse adds.
    def extra_summary(record)
      record.extra_sections.map { |key| key.to_s.sub(/\Aother_/, '') }.join(', ')
    end

    # The line that says the note exists only in this clone, or nil.
    #
    # nil covers both "nothing to say" cases: no upstream to compare with, and
    # every note commit already pushed. "0 commits ahead" is noise, and "not
    # pushed" with no remote is a problem the reader cannot act on.
    def unpushed(path)
      ahead = Git.commits_ahead_of_upstream(path)
      return unless ahead&.positive?

      "unpushed: #{ahead} note commit(s) ahead of #{Git.upstream}"
    end

    def authored?(text)
      stripped = text.to_s.strip
      !stripped.empty? && !Record::PROMPT_RE.match?(stripped)
    end

    # The note's size, when it has grown past a comfortable read.
    #
    # The warning always comes with a remedy. A warning that only says "this
    # file is large" is a warning people learn to ignore; naming the command
    # that fixes it is what makes it actionable.
    def size_warning(path)
      size = File.size(path)
      return unless size > SIZE_LIMIT

      "the note is #{size} bytes; `zanoria archive` moves earlier rounds to #{Archive::FILENAME}"
    end
  end
end
