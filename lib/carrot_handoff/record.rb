# frozen_string_literal: true

module CarrotHandoff
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

    attr_reader :sections, :path

    def initialize(sections = {}, path: nil)
      @sections = sections
      @path = path
    end

    def self.parse(text, path: nil)
      sections = {}
      current = nil
      buffer = []

      text.to_s.each_line do |line|
        match = HEADING_RE.match(line.chomp)

        if match
          sections[current] = buffer.join.strip if current
          current = normalize(match[1])
          buffer = []
        elsif current
          buffer << line
        end
      end

      sections[current] = buffer.join.strip if current
      new(sections, path: path)
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

    private

    def substantive?(text)
      stripped = text.to_s.strip
      !stripped.empty? && !PROMPT_RE.match?(stripped)
    end
  end
end
