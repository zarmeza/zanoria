# frozen_string_literal: true

require 'fileutils'

module CarrotHandoff
  # Wiring an agent tool to the note.
  #
  # The note is only a handoff if something tells the next agent to read it, and
  # no agent discovers a file on its own. That is the whole reason this is a
  # module rather than a couple of lines appended inline: reading `.carrot.md`
  # is a decision, and nothing in the repository makes the decision except an
  # instruction that says to.
  #
  # The markers do double duty. They make re-running `init` idempotent, and they
  # let a later version of this block replace an earlier one in place instead of
  # stacking a second copy underneath the first.
  module Wiring
    BEGIN_MARKER = '<!-- carrot-handoff:begin -->'
    END_MARKER = '<!-- carrot-handoff:end -->'

    # The instructions themselves, markers included so the file is self-labelling
    # to anyone who opens it and has never run this tool.
    #
    # Kept in sync with README.md's "Wiring it into an agent" section, which is
    # the human-facing version of the same advice.
    BLOCK = <<~MARKDOWN.chomp
      #{BEGIN_MARKER}
      ## Handoff notes

      This repository uses carrot-handoff to carry a task between agent tools.
      The note is `.carrot.md`, committed to this repository.

      Before starting work here, run `carrot-handoff load`. If a note exists it
      describes work already in progress: read it, follow its `Next action`, and
      do not re-derive what its `Decisions` section already settled.

      Before you finish, run `carrot-handoff save "<one-line task>"` and then
      fill in `Tried and failed` and `Decisions` by hand. The tool can record the
      git state; it cannot know what you tried.

      Two things to leave alone. `State` is machine-derived and regenerates on
      every save, so edits to it are lost. And do not add a `##` heading of your
      own: only the six canonical headings round-trip in place, so dated or
      thematic context belongs under a `###` inside an existing section.

      Commit the note. An uncommitted note does not survive a context reset.
      #{END_MARKER}
    MARKDOWN

    # Between markers, lazily, so the two halves cannot drift apart.
    #
    # The trailing `[ \t]*\r?\n?` is load-bearing rather than fussy. Without it
    # the match stops at the end marker, the newline that terminates it survives
    # the substitution, and every run appends one more blank line — the file
    # grows a byte at a time and `init` is no longer idempotent.
    BLOCK_RE = /#{Regexp.escape(BEGIN_MARKER)}.*?#{Regexp.escape(END_MARKER)}[ \t]*\r?\n?/m

    # The same block is reproduced in README.md, so there were two copies of the
    # same prose with nothing tying them together. These markers delimit the
    # documented copy.
    #
    # Deliberately distinct strings from the wiring markers above. Reusing them
    # would give a wired `AGENTS.md` and a documented README one shared region,
    # and then neither could be processed without the other's markers present.
    DOC_BEGIN = '<!-- block:begin -->'
    DOC_END = '<!-- block:end -->'

    DOC_RE = /#{Regexp.escape(DOC_BEGIN)}.*?#{Regexp.escape(DOC_END)}[ \t]*\r?\n?/m

    # What happened to one file. `changed` false means the block was already
    # current, which is the normal result of a second `init` and worth reporting
    # as such rather than as work done.
    Result = Struct.new(:path, :changed, :created, keyword_init: true) do
      def changed?
        changed
      end

      def created?
        created
      end
    end

    module_function

    # Write the block into `path`, creating the file when absent and replacing an
    # earlier block in place when one is already there.
    #
    # Everything outside the markers is left byte for byte alone. The
    # instruction file belongs to the project, not to this tool, and an agent
    # guide is the one file here that a human has definitely already written.
    def apply(path)
      original = File.exist?(path) ? File.read(path) : nil
      updated = original.nil? ? framed : insert(original)

      # The directory is created rather than demanded. `--file docs/AGENTS.md`
      # names a file, and the path's parent is implied by that; refusing because
      # `docs/` is missing turns a two-word instruction into a manual mkdir. It
      # also fails late — every file after this one would already be wired, so
      # `init` would have half-run and reported nothing about it.
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, updated) unless original == updated

      Result.new(path: path, changed: original != updated, created: original.nil?)
    rescue SystemCallError => e
      raise Error, "could not write #{path}: #{e.message}"
    end

    # True when `path` already carries a block this tool owns. Used by `init` to
    # report wiring as already-current rather than as newly added.
    def wrapped?(text)
      text.to_s.include?(BEGIN_MARKER)
    end

    # Block with exactly one trailing newline, whatever the heredoc's own
    # trailing blank line was.
    def framed
      "#{BLOCK}\n"
    end

    def insert(original)
      return replace(original) if original.include?(BEGIN_MARKER)
      return framed if original.strip.empty?

      "#{original.rstrip}\n\n#{framed}"
    end

    # Swap the block between the markers, keeping everything around it.
    #
    # The block form of `sub` is deliberate. A replacement *string* would treat
    # `\1` and `\0` in the markdown as backreferences, and this block is prose
    # that a future edit could easily give one by accident.
    def replace(original)
      original.sub(BLOCK_RE) { framed }
    end

    # Return `text` with its documented block region replaced by `BLOCK`,
    # appending the region when it has none yet.
    #
    # Used two ways, and that is the entire reason it is a method rather than
    # logic inlined in a rake task: `rake docs:sync` writes the result back to
    # the README, and the spec asserts `embed(readme) == readme`. The assertion
    # is a fixed point — change `BLOCK` without re-syncing the README and the
    # spec goes red with a diff. Both halves therefore run the same code, so the
    # check cannot be a second implementation that is wrong in some new way.
    def embed(text)
      region = "#{DOC_BEGIN}\n#{framed}#{DOC_END}\n"
      return "#{text.rstrip}\n\n#{region}" unless text.include?(DOC_BEGIN)

      text.sub(DOC_RE) { region }
    end
  end
end
