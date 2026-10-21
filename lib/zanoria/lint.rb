# frozen_string_literal: true

module Zanoria
  # The problems a note can have that nothing else reports.
  #
  # `status` counts sections, and a section full of text is full of text
  # whether or not the text is what the author meant. These are the things
  # that are wrong in a way a count cannot see.
  #
  # The findings are split by whether they cost content. A finding that does
  # is a reason to refuse the save that would cause it; one that does not is
  # worth saying and not worth blocking on.
  module Lint
    # A heading at level three or deeper, at the start of a line.
    #
    # The `\#` is not optional: an unescaped `#{` in a regex literal is
    # interpolation, and `#{3,}` is not a valid expression.
    #
    # Anchored to the start of the line on purpose: the machine state only
    # ever emits `###` mid-line, inside a commit subject, so a line-anchored
    # match cannot fire on anything the tool wrote.
    SUBHEADING_RE = /\A\#{3,}\s+/

    module_function

    # Every problem found in `record`, as human-readable lines.
    def anomalies(record)
      findings(record).map { |finding| finding[:message] }
    end

    # The problems that would cost content if the note were saved now.
    def destructive(record)
      findings(record).select { |finding| finding[:destructive] }.map { |finding| finding[:message] }
    end

    def findings(record)
      state_subheading(record) + repeated_subheading(record) + collisions(record)
    end

    # A subheading inside the machine-derived `State` section.
    #
    # `State` is replaced by the git snapshot on every render, so a `###`
    # block written there is deleted by the next save. The usual way in is
    # to write it just above the next `##` heading, which is how it lands in
    # `State` rather than in the section it was meant for — and the loss is
    # invisible afterwards, because the section is still there and still has
    # text in it.
    def state_subheading(record)
      return [] unless record[:state].to_s.lines.any? { |line| line.match?(SUBHEADING_RE) }

      [{ message: 'the State section holds a `###` block, and State is regenerated on every save, ' \
                  'so the next save deletes it', destructive: true }]
    end

    # The same subheading twice inside one section.
    #
    # A partial edit that moves a block by changing its start and its end
    # separately leaves the heading behind twice. The content survives a save,
    # so nothing else reports it.
    def repeated_subheading(record)
      record.sections.except(:state).flat_map do |key, body|
        titles = body.to_s.lines.grep(SUBHEADING_RE).map { |line| line.sub(SUBHEADING_RE, '').strip }
        titles.tally.select { |_, count| count > 1 }.keys.map do |title|
          { message: "the #{title.inspect} heading appears more than once in #{key}", destructive: false }
        end
      end
    end

    # Two headings that normalise to the same section.
    #
    # `## Task` and `## TASK` are the same key, and the first body used to be
    # overwritten by the second without a word. The second is now kept as a
    # section of its own at the end of the note, so nothing is lost — but the
    # note is not what the author wrote, and saying so is the point.
    def collisions(record)
      record.collisions.map do |collision|
        names = collision[:headings].map(&:inspect).join(' and ')

        { message: "the #{names} headings are the same section, and the second was kept at the end of the note",
          destructive: false }
      end
    end
  end
end
