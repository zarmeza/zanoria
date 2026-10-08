# frozen_string_literal: true

require_relative '../lib/carrot_handoff'
require_relative 'spec_helper'

RSpec.describe CarrotHandoff::Wiring do
  # Writes `contents` to a file in the repo and returns its path.
  def agent_file(dir, contents = "# Project\n\nExisting prose.\n")
    path = File.join(dir, 'AGENTS.md')
    File.write(path, contents)
    path
  end

  describe '.apply' do
    it 'creates the file when it does not exist' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'AGENTS.md')
        result = described_class.apply(path)

        expect(result).to be_created
        expect(result).to be_changed
        expect(File.read(path)).to include(described_class::BEGIN_MARKER)
      end
    end

    it 'appends the block, keeping what was there' do
      in_repo do |dir|
        path = agent_file(dir)
        described_class.apply(path)

        contents = File.read(path)
        expect(contents).to start_with("# Project\n\nExisting prose.")
        expect(contents).to include('## Handoff notes')
      end
    end

    it 'writes only the block into a blank file' do
      in_repo do |dir|
        path = agent_file(dir, "\n\n")
        described_class.apply(path)

        expect(File.read(path).strip).to eq(described_class::BLOCK)
      end
    end

    it 'creates the parent directory when it is missing' do
      in_repo do |dir|
        path = File.join(dir, 'docs', 'nested', 'AGENTS.md')
        described_class.apply(path)

        expect(File).to exist(path)
      end
    end

    it 'reports an unchanged file as unchanged' do
      in_repo do |dir|
        path = agent_file(dir)
        described_class.apply(path)

        expect(described_class.apply(path)).not_to be_changed
      end
    end

    it 'does not treat an unwired file as current' do
      in_repo do |dir|
        path = agent_file(dir)

        expect(described_class.apply(path)).to be_changed
      end
    end

    # The regression this exists for. `BLOCK_RE` once stopped at the end marker,
    # so the newline terminating it survived every substitution and `init` grew
    # the file by one blank line per run. Byte-for-byte, not line-count: a
    # whitespace assertion would have passed while the file still grew.
    it 'is byte-identical after repeated runs' do
      in_repo do |dir|
        path = agent_file(dir)
        described_class.apply(path)
        first = File.binread(path)

        3.times { described_class.apply(path) }

        expect(File.binread(path)).to eq(first)
      end
    end

    it 'leaves text outside the markers untouched when replacing' do
      in_repo do |dir|
        path = agent_file(dir, "TOP\n\n#{described_class::BLOCK}\nBOTTOM\n")
        described_class.apply(path)

        contents = File.read(path)
        expect(contents).to start_with('TOP')
        expect(contents).to end_with("BOTTOM\n")
      end
    end

    it 'replaces an older block instead of stacking a second one' do
      in_repo do |dir|
        path = File.join(dir, 'AGENTS.md')
        stale = "## Handoff notes\n\nOutdated advice.\n"
        File.write(path, "TOP\n\n#{described_class::BEGIN_MARKER}\n#{stale}#{described_class::END_MARKER}\nBOTTOM\n")

        described_class.apply(path)
        contents = File.read(path)

        expect(contents).not_to include('Outdated advice')
        expect(contents.scan(described_class::BEGIN_MARKER).size).to eq(1)
        expect(contents).to include('TOP')
        expect(contents).to include('BOTTOM')
      end
    end

    it 'raises a tool error rather than a raw system one' do
      Dir.mktmpdir do |dir|
        # A directory where the file should be: File.write cannot write it, and
        # the CLI turns a raw Errno into an unreadable backtrace without help.
        FileUtils.mkdir_p(File.join(dir, 'AGENTS.md'))

        expect { described_class.apply(File.join(dir, 'AGENTS.md')) }
          .to raise_error(CarrotHandoff::Error, /could not write/)
      end
    end
  end

  describe '.embed' do
    let(:readme) { File.read(File.expand_path('../README.md', __dir__)) }

    # The whole point. `rake docs:sync` writes `embed(readme)` back, so this
    # passing means the README is a fixed point of the function that maintains
    # it: change `BLOCK` without re-syncing and this goes red.
    #
    # A second implementation of the comparison in the spec would drift from
    # `embed` itself, which is the failure this arrangement exists to prevent.
    it 'has a README that is a fixed point of embed' do
      expect(described_class.embed(readme)).to eq(readme)
    end

    it 'replaces a stale block' do
      stale = "Intro.\n\n#{described_class::DOC_BEGIN}\nOLD TEXT\n#{described_class::DOC_END}\nOutro.\n"

      result = described_class.embed(stale)

      expect(result).not_to include('OLD TEXT')
      expect(result).to include(described_class::BLOCK)
      expect(result).to start_with('Intro.')
      expect(result).to end_with("Outro.\n")
    end

    it 'appends the region when the file has none' do
      result = described_class.embed("Just prose.\n")

      expect(result).to start_with("Just prose.\n\n")
      expect(result).to include(described_class::BLOCK)
    end

    it 'is idempotent' do
      once = described_class.embed("Intro.\n")
      expect(described_class.embed(once)).to eq(once)
    end
  end

  describe 'the block itself' do
    it 'carries both markers' do
      expect(described_class::BLOCK).to include(described_class::BEGIN_MARKER)
      expect(described_class::BLOCK).to include(described_class::END_MARKER)
    end

    it 'ends without a trailing newline so callers control spacing' do
      expect(described_class::BLOCK).not_to end_with("\n")
    end

    it 'tells an agent to load before working and save before finishing' do
      expect(described_class::BLOCK).to include('carrot-handoff load')
      expect(described_class::BLOCK).to include('carrot-handoff save')
    end

    # From this repository's own note: an invented `##` heading survives a save
    # but is not canonical, and a `###` block above the next `##` is absorbed by
    # `State` and deleted. Every repo that runs `init` gets the warning.
    it 'warns off inventing a ## heading' do
      expect(described_class::BLOCK).to include('do not add a `##` heading')
      expect(described_class::BLOCK).to include('`###`')
    end
  end
end
