# frozen_string_literal: true

module Zanoria
  # Writing the note.
  #
  # Lives outside `CLI` for the same reason `Init` does: the orchestration is
  # worth testing without going through argument dispatch, and `CLI` was at
  # the ceiling of its class length.
  module Save
    # What a save did.
    #
    # `replaced_bytes` is how many bytes the note held that were not valid
    # UTF-8. They were read as the replacement character, so the save wrote
    # the replacement — a real change to the only copy of the content, and
    # the kind that is invisible afterwards: the note still parses and the
    # section count does not move.
    Result = Struct.new(:path, :replaced_bytes, keyword_init: true)

    module_function

    # Write the note with a new task line.
    #
    # `replace_task` is the explicit permission for the one write that can
    # remove text: replacing a `Task` section that holds more than the line
    # being written. Without it the save refuses, and nothing is written.
    #
    # Raises `Zanoria::Error` when the save would destroy content. Nothing is
    # written in that case, and the note on disk is left byte for byte as it
    # was.
    def run(path:, task:, replace_task: false)
      existing = Store.read_or_empty(path)
      refuse_to_lose_content(existing)

      updated = existing.with_task(task)
      refuse_to_drop_text(existing, updated, replace_task: replace_task)

      Store.write(path, Template.render(updated))

      Result.new(path: path, replaced_bytes: existing.invalid_bytes)
    end

    # Refuse to save a note that the save would silently damage.
    #
    # The content at risk is the only copy of it. The note is committed, but
    # a note that quietly lost a block between one save and the next looks
    # perfectly healthy to `status`: the section is still there, and it still
    # has text in it.
    def refuse_to_lose_content(existing)
      losses = Zanoria::Lint.destructive(existing)
      return if losses.empty?

      raise Error, <<~MSG
        refusing to save: #{losses.join('; ')}.

        Nothing was written. Move the content under Decisions, Tried and
        failed, Next action or Open questions, or delete it, and save again.
      MSG
    end

    # Refuse when this save would replace a body with something shorter.
    #
    # `refuse_to_lose_content` asks whether the note would stop parsing
    # cleanly. That question has no opinion about a whole body being swapped
    # for a one-line argument: it parses perfectly and still loses the
    # paragraphs under it. This asks the other question — would text that is
    # on disk now be absent afterwards?
    #
    # The rule is one paragraph wide: a command may rewrite a section's first
    # paragraph, because that is where the task line lives, and may not take
    # the rest with it. `State` is exempt because it is regenerated from git on
    # every save, and prompt text is exempt because `Template.body_for`
    # regenerates it. Both exemptions are load-bearing: without them this fires
    # on every save.
    def refuse_to_drop_text(before, after, replace_task:)
      return if replace_task

      losses = lost_paragraphs(before, after)
      return if losses.empty?

      raise Error, drop_text_message(losses)
    end

    # The sections whose text beyond the first paragraph would go missing.
    def lost_paragraphs(before, after)
      keys = (before.sections.keys | after.sections.keys) - [:state]

      keys.filter_map { |key| loss_for(key, before, after) }
    end

    def loss_for(key, before, after)
      body = before[key].to_s.strip
      return if body.empty? || Record::PROMPT_RE.match?(body)

      whole = paragraphs_in(body)
      lost = whole.drop(1).reject { |paragraph| paragraphs_in(after[key].to_s).include?(paragraph) }
      return if lost.empty?

      { label: Record::SECTIONS[key] || key.to_s, lost: lost }
    end

    # Paragraphs as markdown counts them: a blank line between, no empties.
    def paragraphs_in(text)
      text.split(/\n{2,}/).map(&:strip).reject(&:empty?)
    end

    def drop_text_message(losses)
      <<~MSG
        refusing to save: this would replace text that is written only here.

        #{loss_lines(losses)}

        Nothing was written. Run `zanoria save` with no task to keep the current
        text, or `zanoria save --replace-task "<task>"` to replace it on purpose.
      MSG
    end

    def loss_lines(losses)
      losses.map do |loss|
        "  #{loss[:label]} still holds #{loss[:lost].size} paragraph(s) beyond the " \
          "first, which would be lost:\n#{loss[:lost].map { |p| "    #{preview(p)}" }.join("\n")}"
      end.join("\n")
    end

    # Enough of a paragraph to recognise it, on one line.
    def preview(paragraph)
      first = paragraph.lines.first.to_s.strip
      first.length > 72 ? "#{first[0, 69]}..." : first
    end
  end
end
