# frozen_string_literal: true

module Zanoria
  # The facts `status` derives, as opposed to the ones the note stores.
  #
  # Lives outside `CLI` for the reason AGENTS.md gives: `CLI` sits at the ceiling
  # of `Metrics/ClassLength`, and a command class that grows by one formatting
  # method per feature is a class nobody reads. These three are also the part of
  # the summary worth testing without a stream.
  module Status
    module_function

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
  end
end
