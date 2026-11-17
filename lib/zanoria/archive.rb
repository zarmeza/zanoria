# frozen_string_literal: true

require 'date'

module Zanoria
  # Moving earlier rounds out of the live note.
  #
  # The tool cannot know when a round is over: a task can be reworded without
  # starting a new one, and git history can be rewritten, so a derived boundary
  # would be wrong in ways nobody can see. The note records its own start in
  # `_Started:`, and the operator runs this command when the work that round
  # describes is done. Everything after that is deterministic.
  module Archive
    FILENAME = '.carrot-archive.md'

    # Only the sections that hold dated rounds. `Open questions` is pending
    # work and `Next action` is current by definition, so moving either would
    # hide what the next reader needs rather than tidy what they have finished.
    SECTIONS = %i[decisions attempts].freeze

    BLOCK_START = '### '
    HEADING_DATE_RE = /\A###\s+(\d{4}-\d{2}-\d{2})\b/

    # What an archive run did. `reason` is nil when blocks moved; otherwise it
    # says why nothing did, because "nothing happened" is the common case and a
    # silent success would read as a command that is broken.
    Result = Struct.new(:archive_path, :note_path, :moved, :reason, keyword_init: true) do
      def moved?
        !moved.to_i.zero?
      end

      # What the command says. The reason nothing moved is part of the answer:
      # a silent success reads as a command that is broken.
      def message
        case reason
        when :no_start
          "No _Started: date in #{note_path}; the next `zanoria save` records it."
        when :nothing
          'Nothing to archive — every dated block belongs to the current round.'
        else
          ["Archived #{moved} block(s) into #{archive_path}",
           "Wrote #{note_path} (State names the archive)",
           'Commit both so the next tool sees them.'].join("\n")
        end
      end
    end

    module_function

    def run(note_path:)
      record = Store.read(note_path)
      started = record.started_at
      return Result.new(note_path: note_path, moved: 0, reason: :no_start) if started.to_s.empty?

      start_date = Date.iso8601(started)
      moves, updated = collect(record, start_date)
      return Result.new(note_path: note_path, moved: 0, reason: :nothing) if moves.empty?

      archive_path = File.join(File.dirname(note_path), FILENAME)
      existing = File.exist?(archive_path) ? File.read(archive_path) : nil

      # The archive is written first. If the note write then fails, the blocks
      # exist in both files, which is recoverable; the reverse would leave them
      # in neither.
      Store.write(archive_path, Document.append(existing, moves))
      Store.write(note_path, Template.render(updated))

      Result.new(archive_path: archive_path, note_path: note_path,
                 moved: moves.values.sum(&:size))
    end

    # The sections with their old blocks removed, and those blocks by section.
    def collect(record, start_date)
      moves = {}
      updated = record

      SECTIONS.each do |key|
        leading, blocks = split_blocks(record[key])
        old, kept = blocks.partition { |block| before?(block, start_date) }
        next if old.empty?

        moves[key] = old
        updated = updated.with_section(key, join_blocks(leading, kept))
      end

      [moves, updated]
    end

    # A section body as the text before its first `###` heading, plus each
    # `###` block with its heading and body intact.
    def split_blocks(body)
      leading = []
      blocks = []
      current = nil

      body.to_s.each_line do |line|
        if line.start_with?(BLOCK_START)
          blocks << current.join.strip if current
          current = [line]
        elsif current
          current << line
        else
          leading << line
        end
      end

      blocks << current.join.strip if current
      [leading.join.strip, blocks]
    end

    def join_blocks(leading, blocks)
      ([leading] + blocks).reject(&:empty?).join("\n\n")
    end

    # A block belongs to an earlier round when its heading date is before the
    # recorded start. A block with no date, or an impossible one, stays in the
    # live note: the tool cannot tell which round it belongs to, and guessing
    # is how content moves somewhere nobody looks.
    def before?(block, start_date)
      date = date_of(block.lines.first.to_s)
      date ? date < start_date : false
    end

    def date_of(heading)
      match = HEADING_DATE_RE.match(heading)
      return unless match

      Date.iso8601(match[1])
    rescue Date::Error
      nil
    end

    # The archive document itself: plain markdown, appended to and never
    # rewritten, grouped under the heading of the section a block came from.
    module Document
      TITLE = '# Archived rounds'
      INTRO = 'Earlier rounds from `.carrot.md`, moved by `zanoria archive`.'
      SECTION_RE = /\A##\s+(.+?)\s*\z/

      module_function

      # The archive text with `moves` appended, or a fresh archive when there
      # is none. Existing text outside the insertion point is preserved.
      def append(existing, moves)
        return render(default_preamble, new_sections(moves)) if existing.nil?

        preamble, sections = parse(existing)
        moves.each do |key, blocks|
          heading = Record::SECTIONS[key]
          section = sections.find { |candidate| candidate[:heading].casecmp?(heading) }

          if section
            section[:body] = append_blocks(section[:body], blocks)
          else
            sections << { heading: heading, body: "#{blocks.join("\n\n")}\n" }
          end
        end

        render(preamble, sections)
      end

      def default_preamble
        "#{TITLE}\n\n#{INTRO}\n"
      end

      def new_sections(moves)
        moves.map { |key, blocks| { heading: Record::SECTIONS[key], body: "#{blocks.join("\n\n")}\n" } }
      end

      # An archive is a preamble followed by `## Section` headings with the
      # moved `###` blocks beneath them.
      def parse(text)
        preamble = []
        sections = []
        current = nil

        text.each_line do |line|
          match = SECTION_RE.match(line.chomp)

          if match
            sections << current if current
            current = { heading: match[1], body: +'' }
          elsif current
            current[:body] << line
          else
            preamble << line
          end
        end

        sections << current if current
        [preamble.join, sections]
      end

      # Append blocks that are not already there, so a second run cannot write
      # the same round twice.
      def append_blocks(body, blocks)
        fresh = blocks.reject { |block| body.include?(block) }
        return body if fresh.empty?

        "#{body.rstrip}\n\n#{fresh.join("\n\n")}\n"
      end

      def render(preamble, sections)
        parts = []
        parts << preamble.strip unless preamble.strip.empty?
        sections.each { |section| parts << "## #{section[:heading]}\n\n#{section[:body].strip}" }

        "#{parts.join("\n\n")}\n"
      end
    end
  end
end
