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

  it 'replaces a hand-edited State with fresh git facts' do
    # The failure this guards: State is written into the file, so filling it
    # "only when empty" would never re-fill it, and the note would go stale
    # permanently — claiming a clean branch that no longer exists.
    stale = CarrotHandoff::Record.new(
      { task: 'A task.', state: "- Branch: `deleted`\n- Worktree: clean" }
    )
    allow(CarrotHandoff::Git).to receive_messages(
      branch: 'main', head: 'abc1234', dirty_files: [], recent_commits: []
    )

    output = described_class.render(stale)

    expect(output).to include('- Branch: `main`')
    expect(output).not_to include('deleted')
  end

  it 'writes extra sections back out instead of dropping them' do
    # The failure this guards: `save` rewrites the whole file, so a section that
    # parses but is never rendered is deleted outright. A hand-written note
    # carries a heading the tool does not know about, and that content is
    # exactly what exists nowhere else.
    record = CarrotHandoff::Record.parse("## Task\n\nA task.\n\n## Deployment notes\n\nHeroku.\n")

    output = described_class.render(record)

    expect(output).to include('## Deployment notes')
    expect(output).to include('Heroku.')
  end

  it 'restores the heading as written rather than the slug' do
    # "normalize" collapses every run of non-alphanumerics to "_", so
    # "Decisions (2026-10-07)" and "Decisions 2026 10 07" are the same key.
    # Rendering the slug back out would mangle the heading on every save.
    record = CarrotHandoff::Record.parse("## Task\n\nA.\n\n## Decisions (2026-10-07)\n\nX.\n")

    output = described_class.render(record)

    expect(output).to include('## Decisions (2026-10-07)')
  end

  it 'renders extra sections after the canonical ones, so order holds' do
    record = CarrotHandoff::Record.parse("## Deployment notes\n\nHeroku.\n\n## Task\n\nA.\n")

    output = described_class.render(record)
    headings = output.lines.grep(/\A## /)

    expect(headings.last).to eq("## Deployment notes\n")
    expect(headings.first).to eq("## Task\n")
  end

  it 'is idempotent across a save round trip carrying an extra section' do
    allow(CarrotHandoff::Git).to receive_messages(
      branch: 'main', head: 'abc1234', dirty_files: [], recent_commits: []
    )
    record = CarrotHandoff::Record.parse("## Task\n\nA.\n\n## Deployment notes\n\nHeroku.\n")

    first = described_class.render(record)
    second = described_class.render(CarrotHandoff::Record.parse(first))

    expect(second).to eq(first)
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
        root: nil, branch: nil, head: nil, dirty_files: [], recent_commits: []
      )

      expect(described_class.observed_state).to eq('No git repository detected.')
    end

    # `branch` and `head` are nil in a repo with no commits for the same reason
    # they are nil outside one, so the two cases are indistinguishable from those
    # readers alone. `root` is what tells them apart, and getting it wrong makes
    # `init` claim there is no repository in the fresh repo it just set up.
    it 'distinguishes a repository with no commits from no repository' do
      allow(CarrotHandoff::Git).to receive_messages(
        root: '/srv/repo', branch: nil, head: nil, dirty_files: [], recent_commits: []
      )

      expect(described_class.observed_state).to eq('Repository has no commits yet.')
    end

    it 'still lists uncommitted files in a repository with no commits' do
      allow(CarrotHandoff::Git).to receive_messages(
        root: '/srv/repo', branch: nil, head: nil, recent_commits: []
      )
      allow(CarrotHandoff::Git).to receive(:dirty_files).and_return(['?? new.rb'])

      expect(described_class.observed_state).to include('- Uncommitted: 1 file(s)')
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
