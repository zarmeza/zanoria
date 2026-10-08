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

    it 'handles empty input' do
      expect(described_class.parse('').sections).to eq({})
      expect(described_class.parse(nil).sections).to eq({})
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
