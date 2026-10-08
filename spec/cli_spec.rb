# frozen_string_literal: true

require_relative '../lib/zanoria'
require_relative 'spec_helper'

RSpec.describe Zanoria::CLI do
  # Run the CLI against an explicit stream pair, with the process cwd set to the
  # fixture repo, and return [status, stdout, stderr].
  def run_cli(argv, dir:, out: StringIO.new, err: StringIO.new)
    original = Dir.pwd
    Dir.chdir(dir)
    Zanoria::Git.reset!
    status = described_class.new(out: out, err: err).run(argv)
    [status, out.string, err.string]
  ensure
    Dir.chdir(original)
    Zanoria::Git.reset!
  end

  describe 'help' do
    it 'prints usage and succeeds' do
      in_repo do |dir|
        status, out, = run_cli(['help'], dir: dir)

        expect(status).to eq(0)
        expect(out).to include('carry a task between agent tools')
      end
    end

    it 'treats no arguments as help' do
      in_repo do |dir|
        status, out, = run_cli([], dir: dir)

        expect(status).to eq(0)
        expect(out).to include('Usage:')
      end
    end

    it 'lists init first, since it is the command a new repo wants' do
      in_repo do |dir|
        _status, out, = run_cli(['help'], dir: dir)

        expect(out.index('init')).to be < out.index('save')
      end
    end
  end

  describe 'init' do
    it 'creates the note and wires AGENTS.md by default' do
      in_repo do |dir|
        commit_all(dir)
        status, out, = run_cli(['init'], dir: dir)

        expect(status).to eq(0)
        expect(File).to exist(File.join(dir, '.carrot.md'))
        expect(File.read(File.join(dir, 'AGENTS.md'))).to include('carrot-handoff:begin')
        expect(out).to include('created')
        expect(out).to include('wired')
      end
    end

    it 'seeds the task from a positional argument' do
      in_repo do |dir|
        commit_all(dir)
        run_cli(%w[init Upgrade omniauth-facebook], dir: dir)

        record = Zanoria::Record.load(File.join(dir, '.carrot.md'))
        expect(record.task).to eq('Upgrade omniauth-facebook')
      end
    end

    it 'keeps an existing note and says so' do
      in_repo do |dir|
        commit_all(dir)
        run_cli(['init', 'First task'], dir: dir)
        run_cli(['save', 'Second task'], dir: dir)

        _status, out, = run_cli(['init', 'Third task'], dir: dir)
        record = Zanoria::Record.load(File.join(dir, '.carrot.md'))

        expect(record.task).to eq('Second task')
        expect(out).to include('kept')
      end
    end

    it 'stages both files and prints the commit command' do
      in_repo do |dir|
        commit_all(dir)
        _status, out, = run_cli(['init'], dir: dir)

        expect(out).to include('Staged')
        expect(out).to include('git commit -m')
      end
    end

    it 'accepts --file with a separate path or an equals sign' do
      in_repo do |dir|
        commit_all(dir)
        status, = run_cli(%w[init --file CLAUDE.md --file=docs/AGENTS.md], dir: dir)

        expect(status).to eq(0)
        expect(File).to exist(File.join(dir, 'CLAUDE.md'))
        expect(File).to exist(File.join(dir, 'docs', 'AGENTS.md'))
        expect(File).not_to exist(File.join(dir, 'AGENTS.md'))
      end
    end

    it 'resolves the repository root when run from a subdirectory' do
      in_repo do |dir|
        commit_all(dir)
        FileUtils.mkdir_p(File.join(dir, 'deep'))
        _status, out, = run_cli(['init'], dir: File.join(dir, 'deep'))

        expect(File).to exist(File.join(dir, 'AGENTS.md'))
        expect(out).to include(dir)
      end
    end

    it 'is idempotent across repeated runs' do
      in_repo do |dir|
        commit_all(dir)
        run_cli(['init'], dir: dir)
        first = File.binread(File.join(dir, 'AGENTS.md'))

        _status, out, = run_cli(['init'], dir: dir)

        expect(File.binread(File.join(dir, 'AGENTS.md'))).to eq(first)
        expect(out).to include('already current')
      end
    end

    it 'warns rather than staging outside a repository' do
      Dir.mktmpdir do |dir|
        allow(Zanoria::Git).to receive(:root).and_return(nil)
        status, out, = run_cli(['init'], dir: dir)

        expect(status).to eq(0)
        expect(File).to exist(File.join(dir, '.carrot.md'))
        expect(out).to include('No git repository here')
        expect(out).not_to include('Staged')
      end
    end

    it 'rejects --file with no path' do
      in_repo do |dir|
        commit_all(dir)
        status, _out, err = run_cli(['init', '--file'], dir: dir)

        expect(status).to eq(1)
        expect(err).to include('--file needs a path')
      end
    end

    it 'rejects an empty --file value' do
      in_repo do |dir|
        commit_all(dir)
        status, _out, err = run_cli(['init', '--file='], dir: dir)

        expect(status).to eq(1)
        expect(err).to include('--file needs a path')
      end
    end
  end

  describe 'save' do
    it 'writes the note with the task filled in' do
      in_repo do |dir|
        commit_all(dir)
        status, out, = run_cli(%w[save Upgrade Rails], dir: dir)

        expect(status).to eq(0)
        expect(out).to include('Wrote')

        record = Zanoria::Record.load(File.join(dir, '.carrot.md'))
        expect(record.task).to eq('Upgrade Rails')
      end
    end

    it 'warns when the note is not tracked by git' do
      in_repo do |dir|
        commit_all(dir)
        _, out, = run_cli(['save', 'A task'], dir: dir)

        expect(out).to include('untracked')
      end
    end

    it 'warns when the note is already tracked' do
      in_repo do |dir|
        commit_all(dir, filename: '.carrot.md')
        _, out, = run_cli(['save', 'A task'], dir: dir)

        expect(out).to include('tracked by git')
      end
    end

    it 'preserves existing sections on a second save' do
      in_repo do |dir|
        commit_all(dir)
        run_cli(['save', 'Original task'], dir: dir)
        path = File.join(dir, '.carrot.md')

        # Fill in a section by hand, the way an agent would. The "Decisions"
        # prompt is the first one on the page, so replace that whole line.
        File.write(path, File.read(path).sub(/^_TODO: .*_$/, 'Chose X over Y:'))

        run_cli(['save', 'Better task'], dir: dir)
        record = Zanoria::Record.load(path)

        expect(record.task).to eq('Better task')
        expect(record.decisions).to eq('Chose X over Y:')
      end
    end

    it 'keeps a hand-written section outside the canonical list' do
      in_repo do |dir|
        commit_all(dir)
        path = File.join(dir, '.carrot.md')
        File.write(path, "## Task\n\nA.\n\n## Deployment notes\n\nHeroku.\n")

        run_cli(['save', 'A task'], dir: dir)
        contents = File.read(path)

        expect(contents).to include('## Deployment notes')
        expect(contents).to include('Heroku.')
      end
    end

    it 'writes to the current directory when there is no repository' do
      Dir.mktmpdir do |dir|
        allow(Zanoria::Git).to receive(:root).and_return(nil)
        status, out, = run_cli(['save', 'A task'], dir: dir)

        expect(status).to eq(0)
        expect(File).to exist(File.join(dir, '.carrot.md'))
        expect(out).to include('no git repository here')
      end
    end

    it 'round trips a note written outside a repository' do
      Dir.mktmpdir do |dir|
        allow(Zanoria::Git).to receive(:root).and_return(nil)
        run_cli(['save', 'A task'], dir: dir)
        status, out, = run_cli(['load'], dir: dir)

        expect(status).to eq(0)
        expect(out).to include('A task')
      end
    end

    it 'says the note will not survive a machine swap' do
      Dir.mktmpdir do |dir|
        allow(Zanoria::Git).to receive(:root).and_return(nil)
        _status, out, = run_cli(['save', 'A task'], dir: dir)

        expect(out).to include('will not')
        expect(out).to include('machine swap')
      end
    end
  end

  describe 'load' do
    it 'prints the note' do
      in_repo do |dir|
        commit_all(dir)
        run_cli(['save', 'A task'], dir: dir)
        status, out, = run_cli(['load'], dir: dir)

        expect(status).to eq(0)
        expect(out).to include('A task')
        expect(out).to include('## Tried and failed')
      end
    end

    it 'fails when no note exists' do
      in_repo do |dir|
        commit_all(dir)
        status, _out, err = run_cli(['load'], dir: dir)

        expect(status).to eq(1)
        expect(err).to include('Nothing was handed off yet')
      end
    end
  end

  describe 'status' do
    it 'summarizes task, path and filled section count' do
      in_repo do |dir|
        commit_all(dir)
        run_cli(['save', 'Ship the thing'], dir: dir)
        status, out, = run_cli(['status'], dir: dir)

        expect(status).to eq(0)
        expect(out).to include('task:     Ship the thing')
        expect(out).to include('.carrot.md')
        # State is machine-derived, so it is not counted: five human sections.
        expect(out).to match(%r{sections: \d+/5 written})
      end
    end

    it 'reports when nothing has been handed off' do
      in_repo do |dir|
        commit_all(dir)
        status, out, = run_cli(['status'], dir: dir)

        expect(status).to eq(1)
        expect(out).to include('no handoff note')
      end
    end

    it 'notes sections outside the canonical list' do
      in_repo do |dir|
        commit_all(dir)
        path = File.join(dir, '.carrot.md')
        File.write(path, "## Task\n\nA.\n\n## Deployment notes\n\nHeroku.\n")

        _, out, = run_cli(['status'], dir: dir)
        expect(out).to include('extra:    deployment_notes')
      end
    end
  end

  describe 'clear' do
    it 'removes the note' do
      in_repo do |dir|
        commit_all(dir)
        run_cli(['save', 'A task'], dir: dir)
        status, out, = run_cli(['clear'], dir: dir)

        expect(status).to eq(0)
        expect(out).to include('Removed')
        expect(File.exist?(File.join(dir, '.carrot.md'))).to be(false)
      end
    end

    it 'is a no-op when there is nothing to clear' do
      in_repo do |dir|
        commit_all(dir)
        status, out, = run_cli(['clear'], dir: dir)

        expect(status).to eq(0)
        expect(out).to include('nothing to clear')
      end
    end
  end

  describe 'path' do
    it 'prints the note path inside the repo' do
      in_repo do |dir|
        status, out, = run_cli(['path'], dir: dir)

        expect(status).to eq(0)
        expect(out.strip).to eq(File.join(File.realpath(dir), '.carrot.md'))
      end
    end
  end

  describe 'unknown command' do
    it 'reports the command and exits non-zero' do
      in_repo do |dir|
        status, _out, err = run_cli(['frobnicate'], dir: dir)

        expect(status).to eq(1)
        expect(err).to include('unknown command "frobnicate"')
      end
    end
  end
end
