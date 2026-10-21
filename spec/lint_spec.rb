# frozen_string_literal: true

require_relative '../lib/zanoria'

RSpec.describe Zanoria::Lint do
  # A note with a subheading in the machine-derived State section. The next
  # save deletes it, and the section is still there afterwards.
  let(:state_subheading) do
    Zanoria::Record.parse("## Task\n\nA.\n\n## State\n\n- Branch: `main`\n\n### 2026-10-10\n\nContext.\n")
  end

  # The same subheading twice inside one section, which a partial edit leaves
  # behind. The content survives a save, so nothing else reports it.
  let(:repeated_subheading) do
    Zanoria::Record.parse("## Task\n\nA.\n\n## Decisions\n\n### Round one\n\nX.\n\n### Round one\n\nY.\n")
  end

  describe '.anomalies' do
    it 'finds nothing wrong with a note that is fine' do
      record = Zanoria::Record.parse("## Task\n\nA.\n\n## State\n\n- Branch: `main`\n\n## Decisions\n\nD.\n")

      expect(described_class.anomalies(record)).to be_empty
    end

    it 'finds a subheading in the State section' do
      expect(described_class.anomalies(state_subheading)).to include(a_string_matching(/State/))
    end

    it 'finds a heading repeated inside one section' do
      expect(described_class.anomalies(repeated_subheading)).to include(a_string_matching(/Round one/))
    end

    it 'finds two headings that are the same section' do
      record = Zanoria::Record.parse("## Task\n\nFirst.\n\n## TASK\n\nSecond.\n")

      expect(described_class.anomalies(record)).to include(a_string_matching(/same section/))
    end

    # The `###` form the wiring block explicitly recommends. A detector that
    # flags this is a detector nobody turns off.
    it 'does not report a subheading that is in the right section' do
      record = Zanoria::Record.parse("## Task\n\nA.\n\n## Decisions\n\n### 2026-10-10\n\nX.\n")

      expect(described_class.anomalies(record)).to be_empty
    end

    it 'does not mistake a commit subject for a subheading' do
      record = Zanoria::Record.parse("## State\n\n- Branch: `main`\n\nRecent commits:\n- `abc1234 fix ###123`\n")

      expect(described_class.anomalies(record)).to be_empty
    end
  end

  describe '.destructive' do
    it 'counts a subheading in the State section as destructive' do
      expect(described_class.destructive(state_subheading)).not_to be_empty
    end

    it 'does not count a repeated heading as destructive' do
      expect(described_class.destructive(repeated_subheading)).to be_empty
    end

    it 'does not count two headings that are the same section as destructive' do
      record = Zanoria::Record.parse("## Task\n\nFirst.\n\n## TASK\n\nSecond.\n")

      expect(described_class.destructive(record)).to be_empty
    end
  end
end
