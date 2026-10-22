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
    # Raises `Zanoria::Error` when the save would destroy content. Nothing is
    # written in that case, and the note on disk is left byte for byte as it
    # was.
    def run(path:, task:)
      existing = Store.read_or_empty(path)
      refuse_to_lose_content(existing)

      Store.write(path, Template.render(existing.with_task(task)))

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
  end
end
