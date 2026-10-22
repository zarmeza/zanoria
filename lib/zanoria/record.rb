# frozen_string_literal: true

module Zanoria
  # A parsed handoff note.
  #
  # The file format is markdown with `## Section` headings. Parsing is tolerant:
  # an unrecognised or missing section becomes an empty string rather than an
  # error, so a hand-edited file never breaks `handoff load`.
  class Record
    # Order matters. This is both the display order and the order the template
    # writes sections in.
    SECTIONS = {
      task: 'Task',
      state: 'State',
      decisions: 'Decisions',
      attempts: 'Tried and failed',
      next_action: 'Next action',
      open_questions: 'Open questions'
    }.freeze

    HEADING_RE = /\A##\s+(.+?)\s*\z/

    # The facts a parse produced that are not section content.
    #
    # One object rather than four constructor arguments. The count was
    # creeping up — the author's own heading wording, the preamble, the
    # collisions, and the byte count — and every new fact would have made the
    # signature longer. A Struct keeps the names checked: a typo is an
    # error, not a silently ignored keyword.
    Meta = Struct.new(:headings, :preamble, :collisions, :invalid_bytes, keyword_init: true)

    attr_reader :sections, :path, :meta

    def initialize(sections = {}, path: nil, meta: Meta.new)
      @sections = sections
      @path = path
      @meta = meta
    end

    # The heading text as the author wrote it, so a note can be rendered back
    # with their own wording.
    def headings
      meta.headings || {}
    end

    # Whatever was written before the first heading.
    def preamble
      meta.preamble.to_s
    end

    # Headings that normalised onto a section that was already taken.
    def collisions
      meta.collisions || []
    end

    # Bytes the parse had to replace to make the note readable.
    def invalid_bytes
      meta.invalid_bytes.to_i
    end

    # A copy of this record with a different task line.
    #
    # Everything else travels with it: the author's heading wording, the
    # preamble, the collisions, and the byte count. A save rewrites the whole
    # file, so anything left behind here is content that goes missing.
    def with_task(task)
      sections = @sections.dup
      sections[:task] = task unless task.to_s.empty?

      Record.new(sections, path: path, meta: meta)
    end

    def self.parse(text, path: nil)
      state = { sections: {}, headings: {}, collisions: [], used: [] }
      current = nil
      buffer = []
      preamble = []

      text, invalid = scrub_bytes(text)

      text.each_line do |line|
        match = HEADING_RE.match(line.chomp)

        if match
          state[:sections][current] = buffer.join.strip if current
          current = take_key(match[1], state)
          buffer = []
        elsif current
          buffer << line
        else
          # Anything before the first heading is the author's own, and it used
          # to be dropped on the floor by the next save.
          preamble << line
        end
      end

      state[:sections][current] = buffer.join.strip if current

      new_from(state, path, preamble.join.strip, invalid)
    end

    # The text with its invalid bytes replaced, and how many there were.
    #
    # A byte that is not valid UTF-8 used to raise out of the regex match and
    # take the whole tool down with a raw backtrace. The project's own rule is
    # that a malformed note never raises, so the byte is read as the
    # replacement character and counted. The count is what lets the tool say
    # that a save wrote the replacement: the note still parses afterwards, and
    # the section count does not move, so nothing else would report it.
    def self.scrub_bytes(text)
      count = 0
      scrubbed = text.to_s.scrub do |bad|
        count += bad.bytesize
        "\uFFFD"
      end

      [scrubbed, count]
    end

    # The record a parse produced.
    def self.new_from(state, path, preamble, invalid_bytes = 0)
      new(
        state[:sections],
        path: path,
        meta: Meta.new(
          headings: state[:headings],
          preamble: preamble,
          collisions: state[:collisions],
          invalid_bytes: invalid_bytes
        )
      )
    end

    # The key for a heading, keeping every body the note holds.
    #
    # A heading that normalises to a key already seen is re-homed, so the
    # first body is not overwritten and the second is still written back out.
    def self.take_key(heading, state)
      key = normalize(heading)

      if state[:used].include?(key)
        note_collision(state, key, heading)
        key = free_key(key, state[:used])
      end

      state[:used] << key
      state[:headings][key] ||= heading
      key
    end

    # Record that a second heading landed on a section that was already taken.
    def self.note_collision(state, key, heading)
      collision = state[:collisions].find { |c| c[:key] == key }

      if collision
        collision[:headings] << heading
      else
        state[:collisions] << { key: key, headings: [state[:headings][key].to_s, heading] }
      end
    end

    # A key for a heading that collided with one already seen.
    #
    # `other_task_2` and not `other_task`, so the name reads as what it is: a
    # second copy of a section that already exists.
    def self.free_key(key, used)
      index = 2
      index += 1 while used.include?(:"other_#{key}_#{index}")

      :"other_#{key}_#{index}"
    end

    def self.load(path)
      parse(File.read(path), path: path)
    end

    # Heading text to key, e.g. "Tried and failed" => :attempts.
    #
    # Matched on a normalized form so "Tried and failed", "tried-and-failed" and
    # "TRIED AND FAILED" all land on the same key. Unrecognised headings are
    # kept under an "other_" key so a hand-written section survives a rewrite.
    #
    # Note `Hash#key` maps a *value* back to its key, which is not the lookup
    # wanted here; the alias is built once at load time instead.
    SLUG_TO_KEY = SECTIONS.each_with_object({}) do |(key, heading), acc|
      acc[heading.downcase.gsub(/[^a-z0-9]+/, '_')] = key
    end.freeze

    def self.normalize(heading)
      slug = heading.downcase.gsub(/[^a-z0-9]+/, '_').sub(/\A_+|_+\z/, '')
      SLUG_TO_KEY.fetch(slug) { :"other_#{slug}" }
    end

    SECTIONS.each_key do |key|
      define_method(key) { @sections[key].to_s }
    end

    def [](key)
      @sections[key].to_s
    end

    # True when nothing meaningful has been written.
    #
    # A section still holding its `_TODO: …` prompt counts as empty, so a
    # freshly templated file is reported as blank work rather than as a finished
    # note. Extra hand-written sections count too: someone who added their own
    # heading has done real work even if the canonical sections are untouched.
    def empty?
      @sections.each_value.none? { |value| substantive?(value) }
    end

    # A section body that is still the untouched template prompt.
    PROMPT_RE = /\A_TODO:/i

    # Sections present in the file but not in the canonical list, so a
    # hand-written section is never silently discarded on rewrite.
    def extra_sections
      @sections.keys.reject { |key| SECTIONS.key?(key) }
    end

    # The heading text as it was written, so a note can be rendered back with the
    # author's own wording. The slug is lossy: `normalize` collapses every run of
    # non-alphanumerics into "_", so "Decisions (2026-10-07)" and "Decisions
    # 2026 10 07" both parse to the same key. Only the original can tell them
    # apart, so it is kept rather than reconstructed.
    def heading_for(key)
      headings[key]
    end

    private

    def substantive?(text)
      stripped = text.to_s.strip
      !stripped.empty? && !PROMPT_RE.match?(stripped)
    end
  end
end
