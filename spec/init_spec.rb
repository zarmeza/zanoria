# frozen_string_literal: true

require_relative '../lib/zanoria'
require_relative 'spec_helper'

RSpec.describe Zanoria::Init do
  # `Init.run` takes absolute paths, the way the CLI resolves them.
  def run_init(task: nil, files: nil)
    files ||= [File.join(Zanoria::Repo.root, 'AGENTS.md')]
    described_class.run(files: files, task: task)
  end

  describe 'the note' do
    it 'creates one when the repo has none' do
      in_repo do |dir|
        result = run_init(task: 'Wire up handoffs')

        expect(result).to be_note_created
        record = Zanoria::Record.load(File.join(dir, '.carrot.md'))
        expect(record.task).to eq('Wire up handoffs')
      end
    end

    it 'leaves every human section a prompt when no task is given' do
      in_repo do |dir|
        run_init
        record = Zanoria::Record.load(File.join(dir, '.carrot.md'))

        human = Zanoria::Record::SECTIONS.keys - [:state]
        expect(human.map { |key| record[key] }).to all(match(Zanoria::Template::PROMPT_RE))

        # `State` is the exception and is expected to hold real content: it is
        # derived from git, not authored.
        expect(record.state).to include('no commits yet')
      end
    end

    # The property that matters most. `Tried and failed` exists nowhere but the
    # note, and an `init` that rewrote it would destroy the only copy.
    it 'never rewrites a note that already exists' do
      in_repo do |dir|
        path = File.join(dir, '.carrot.md')
        File.write(path, "## Task\n\nReal work.\n\n## Tried and failed\n\nTried the thing.\n")
        before = File.binread(path)

        result = run_init(task: 'a task that must not win')

        expect(result).not_to be_note_created
        expect(File.binread(path)).to eq(before)
        expect(Zanoria::Record.load(path).attempts).to eq('Tried the thing.')
      end
    end
  end

  describe 'git staging' do
    it 'stages the note and the instruction file' do
      in_repo do |dir|
        run_init

        staged = git(dir, 'diff', '--cached', '--name-only').lines.map(&:strip)
        expect(staged).to include('.carrot.md', 'AGENTS.md')
      end
    end

    it 'refuses to stage a path outside the repository' do
      in_repo do |dir|
        outside = File.join(File.dirname(dir), 'outside-AGENTS.md')
        result = described_class.run(files: [outside], task: nil)

        expect(result.outside).to eq([outside])
        expect(result.staged_paths).not_to include(outside)
        expect(File).to exist(outside)
      end
    end

    # `/srv/repo-other` starts with `/srv/repo` as a string. A bare prefix
    # comparison would stage it, and `git add` would then fail the whole run.
    it 'does not mistake a sibling directory prefix for the repository' do
      in_repo do |dir|
        sibling = "#{dir}-other"
        FileUtils.mkdir_p(sibling)
        path = File.join(sibling, 'AGENTS.md')

        result = described_class.run(files: [path], task: nil)

        expect(result.outside).to eq([path])
      end
    end

    it 'stages nothing outside a repository' do
      Dir.mktmpdir do |dir|
        allow(Zanoria::Git).to receive(:root).and_return(nil)
        Dir.chdir(dir) { run_init }

        expect(Dir.children(dir)).to contain_exactly('.carrot.md', 'AGENTS.md')
      end
    end
  end

  describe 'reporting' do
    it 'reports paths relative to the repository root' do
      in_repo do |dir|
        result = run_init
        expect(result.staged_relative(File.realpath(dir))).to contain_exactly('.carrot.md', 'AGENTS.md')
      end
    end

    it 'separates files it changed from files already current' do
      in_repo do |_dir|
        run_init
        second = run_init

        expect(second.wired_changed).to be_empty
        expect(second.wired_current.size).to eq(1)
      end
    end
  end
end
