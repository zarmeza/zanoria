# frozen_string_literal: true

require_relative '../lib/zanoria'

RSpec.describe Zanoria::Release do
  describe '.check!' do
    let(:facts) { { dirty: [], branch: 'main', published: [], version: '1.0.0' } }

    it 'passes on a clean tree, on main, with an unpublished version' do
      expect { described_class.check!(**facts) }.not_to raise_error
    end

    it 'refuses a dirty worktree' do
      expect { described_class.check!(**facts, dirty: ['lib/zanoria.rb']) }
        .to raise_error(Zanoria::Error, /dirty/)
    end

    it 'refuses a branch other than main' do
      expect { described_class.check!(**facts, branch: 'feature/x') }
        .to raise_error(Zanoria::Error, /main/)
    end

    it 'refuses a version that is already published' do
      expect { described_class.check!(**facts, published: ['1.0.0']) }
        .to raise_error(Zanoria::Error, /already published/)
    end

    it 'allows a published gem to have other versions' do
      expect { described_class.check!(**facts, published: %w[0.9.0 0.8.0]) }.not_to raise_error
    end
  end

  describe '.published_versions' do
    it 'reads the versions out of the gem list output' do
      expect(described_class.published_versions('zanoria (1.0.0, 0.9.0)')).to eq(%w[1.0.0 0.9.0])
    end

    it 'returns nothing for a gem that does not exist' do
      expect(described_class.published_versions('')).to eq([])
    end

    it 'ignores digits outside the parenthesised list' do
      expect(described_class.published_versions('zanoria2 (1.0.0)')).to eq(['1.0.0'])
    end
  end
end
