# frozen_string_literal: true

require_relative '../lib/zanoria'

RSpec.describe Zanoria::Record do
  describe '.parse' do
    it 'splits on level-two headings' do
      record = described_class.parse(<<~MD)
        ## Task

        Fix the parser.

        ## Next action

        Add a fixture.
      MD

      expect(record.task).to eq('Fix the parser.')
      expect(record.next_action).to eq('Add a fixture.')
    end

    it 'returns empty strings for absent sections' do
      record = described_class.parse("## Task\n\nOnly this.\n")

      expect(record.task).to eq('Only this.')
      expect(record.decisions).to eq('')
      expect(record.attempts).to eq('')
    end

    it 'ignores headings nested deeper than level two' do
      record = described_class.parse(<<~MD)
        ## Task

        Outer.

        ### Subheading

        Inner content.
      MD

      expect(record.task).to include('Outer.')
      expect(record.task).to include('Subheading')
    end

    it 'matches headings regardless of case and dash style' do
      record = described_class.parse("## TRIED-AND-FAILED\n\nNope.\n")

      expect(record.attempts).to eq('Nope.')
    end

    it 'keeps unrecognised sections instead of dropping them' do
      record = described_class.parse("## Task\n\nA.\n\n## Deployment notes\n\nHeroku.\n")

      expect(record.extra_sections.map(&:to_s)).to eq(%w[other_deployment_notes])
    end

    it 'keeps whatever the author wrote before the first heading' do
      record = described_class.parse("# Handoff note\n\nSome preamble.\n\n## Task\n\nA.\n")

      expect(record.preamble).to eq("# Handoff note\n\nSome preamble.")
    end

    it 'keeps the first body when two headings are the same section' do
      record = described_class.parse("## Task\n\nFirst.\n\n## TASK\n\nSecond.\n")

      expect(record.task).to eq('First.')
    end

    it 'keeps the second body as a section of its own' do
      record = described_class.parse("## Task\n\nFirst.\n\n## TASK\n\nSecond.\n")

      expect(record.extra_sections.map(&:to_s)).to eq(%w[other_task_2])
    end

    it 'records which headings collided' do
      record = described_class.parse("## Task\n\nFirst.\n\n## TASK\n\nSecond.\n")

      expect(record.collisions.map { |c| c[:headings] }).to eq([%w[Task TASK]])
    end

    it 'handles empty input' do
      expect(described_class.parse('').sections).to eq({})
      expect(described_class.parse(nil).sections).to eq({})
    end

    # The project's own rule: never let a malformed note raise. A stray byte
    # from a pasted terminal snippet used to raise `ArgumentError` out of the
    # regex match and take the whole tool down.
    it 'reads a note with a byte that is not valid UTF-8' do
      record = described_class.parse("## Task\n\ncaf\xE9 latte\n")

      expect(record.task).to include('caf')
      expect(record.task).to include('latte')
    end

    it 'counts the bytes it had to replace' do
      record = described_class.parse("## Task\n\ncaf\xE9 latte\n")

      expect(record.invalid_bytes).to eq(1)
    end

    it 'counts nothing when the note is valid UTF-8' do
      record = described_class.parse("## Task\n\ncafé latte\n")

      expect(record.invalid_bytes).to eq(0)
    end

    it 'treats a record whose sections are all prompts as empty' do
      record = described_class.parse(
        "## Task\n\n_TODO: describe the task_\n\n## Next action\n\n_TODO: describe the next step_\n"
      )

      expect(record).to be_empty
    end
  end

  describe '#empty?' do
    it 'is false when any canonical section has content' do
      record = described_class.parse("## Task\n\nSomething.\n")

      expect(record).not_to be_empty
    end

    it 'is false when only an extra section has content' do
      record = described_class.parse("## Notes\n\nSomething.\n")

      expect(record).not_to be_empty
    end
  end
end
