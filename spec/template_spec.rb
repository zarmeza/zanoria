# frozen_string_literal: true

require_relative '../lib/carrot_handoff'
require_relative 'spec_helper'

RSpec.describe CarrotHandoff::Template do
  it 'renders every canonical section in order' do
    record = CarrotHandoff::Record.new({ task: 'A task.' })
    output = described_class.render(record)

    headings = output.lines.grep(/\A## /)
    expect(headings).to eq(CarrotHandoff::Record::SECTIONS.values.map { |h| "## #{h}\n" })
  end

  it 'fills empty sections with prompts when asked' do
    output = described_class.render(CarrotHandoff::Record.new({ task: 'A task.' }))

    expect(output).to include('_TODO:')
    expect(output).to include('Tried and failed')
  end

  it 'omits prompts when prompt is false' do
    output = described_class.render(CarrotHandoff::Record.new({ task: 'A task.' }), prompt: false)

    expect(output).not_to include('_TODO')
  end

  it 'keeps written content and only prompts the rest' do
    record = CarrotHandoff::Record.new({ task: 'A task.', attempts: 'Tried X. Failed.' })
    output = described_class.render(record)

    expect(output).to include('Tried X. Failed.')
    expect(output).to include('_TODO:')
  end

  it 'fills State from git instead of prompting for it' do
    allow(CarrotHandoff::Git).to receive_messages(
      branch: 'main', head: 'abc1234', dirty_files: [], recent_commits: []
    )

    output = described_class.render(CarrotHandoff::Record.new({ task: 'A task.' }))

    expect(output).to include('- Branch: `main`')
    expect(output).to include('- Worktree: clean')
    expect(output).not_to include('- State\n\n_TODO')
  end

  it 'regenerates State on a second save instead of freezing the old one' do
    allow(CarrotHandoff::Git).to receive_messages(
      branch: 'main', head: 'abc1234', dirty_files: ['a.rb'], recent_commits: []
    )

    # Render, parse back, render again — what two consecutive saves do.
    first = described_class.render(CarrotHandoff::Record.new({ task: 'A task.' }))
    second = described_class.render(CarrotHandoff::Record.parse(first))

    expect(second).to include('- Uncommitted: 1 file(s)')
    expect(second).not_to include('- Worktree: clean')
  end

  describe '.observed_state' do
    it 'reports branch, HEAD, worktree and recent commits' do
      in_repo do |dir|
        commit_all(dir, message: 'First commit')
        CarrotHandoff::Git.reset!
        File.write(File.join(dir, 'dirty.txt'), 'x')

        state = described_class.observed_state

        expect(state).to match(/Branch: `[^`]+`/)
        expect(state).to match(/HEAD: `[0-9a-f]+`/)
        expect(state).to include('Uncommitted: 1 file(s)')
        expect(state).to include('First commit')
      end
    end

    it 'reports a clean worktree' do
      in_repo do |dir|
        commit_all(dir)
        CarrotHandoff::Git.reset!

        expect(described_class.observed_state).to include('Worktree: clean')
      end
    end

    it 'truncates a very long dirty list' do
      in_repo do |dir|
        commit_all(dir)
        25.times { |i| File.write(File.join(dir, "f#{i}.txt"), 'x') }
        CarrotHandoff::Git.reset!

        state = described_class.observed_state
        expect(state).to include('Uncommitted: 25 file(s)')
        expect(state).to include('_…and 5 more_')
      end
    end

    it 'says so plainly when git reports nothing at all' do
      allow(CarrotHandoff::Git).to receive_messages(
        branch: nil, head: nil, dirty_files: [], recent_commits: []
      )

      expect(described_class.observed_state).to eq('No git repository detected.')
    end

    it 'survives a git binary that is not installed' do
      allow(CarrotHandoff::Git).to receive_messages(
        branch: nil, head: nil, dirty_files: [], recent_commits: []
      )
      allow(CarrotHandoff::Git).to receive(:dirty_files).and_raise(Errno::ENOENT)

      expect { described_class.observed_state }.not_to raise_error
    end
  end
end
