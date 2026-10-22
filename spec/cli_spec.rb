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
    it 'creates the note and an AGENTS.md when the repository has neither' do
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

    # The repository decides which instruction file gets wired. A `CLAUDE.md`
    # that `init` ignores leaves Claude Code reading a file without the block,
    # and the handoff silently undelivered.
    it 'wires the CLAUDE.md the repository already has' do
      in_repo do |dir|
        commit_all(dir)
        File.write(File.join(dir, 'CLAUDE.md'), "# Project\n\nReglas del proyecto.\n")
        git(dir, 'add', '-A')
        git(dir, 'commit', '--quiet', '-m', 'Add CLAUDE.md')

        _status, out, = run_cli(['init'], dir: dir)

        expect(File.read(File.join(dir, 'CLAUDE.md'))).to include('carrot-handoff:begin')
        expect(File).not_to exist(File.join(dir, 'AGENTS.md'))
        expect(out).to include('CLAUDE.md')
      end
    end

    # Claude Code reads `CLAUDE.md` and opencode reads `AGENTS.md`, so each one
    # needs the block in the file it reads.
    it 'wires both when the repository has both' do
      in_repo do |dir|
        commit_all(dir)
        File.write(File.join(dir, 'AGENTS.md'), "# Agents\n")
        File.write(File.join(dir, 'CLAUDE.md'), "# Project\n")
        git(dir, 'add', '-A')
        git(dir, 'commit', '--quiet', '-m', 'Add instruction files')

        _status, = run_cli(['init'], dir: dir)

        expect(File.read(File.join(dir, 'AGENTS.md'))).to include('carrot-handoff:begin')
        expect(File.read(File.join(dir, 'CLAUDE.md'))).to include('carrot-handoff:begin')
      end
    end

    # Re-running `init` must not stack a second block under the first. The
    # bytes are compared, because a line count would pass while the file grew.
    it 'leaves a wired CLAUDE.md byte-identical on a second run' do
      in_repo do |dir|
        commit_all(dir)
        File.write(File.join(dir, 'CLAUDE.md'), "# Project\n")
        git(dir, 'add', '-A')
        git(dir, 'commit', '--quiet', '-m', 'Add CLAUDE.md')

        run_cli(['init'], dir: dir)
        first = File.binread(File.join(dir, 'CLAUDE.md'))

        run_cli(['init'], dir: dir)

        expect(File.binread(File.join(dir, 'CLAUDE.md'))).to eq(first)
      end
    end

    # An explicit `--file` is a decision, and it wins over the detection: the
    # tool does not add files the person did not ask for.
    it 'wires only what --file names' do
      in_repo do |dir|
        commit_all(dir)
        File.write(File.join(dir, 'CLAUDE.md'), "# Project\n")
        git(dir, 'add', '-A')
        git(dir, 'commit', '--quiet', '-m', 'Add CLAUDE.md')

        run_cli(%w[init --file docs/AGENTS.md], dir: dir)

        expect(File).to exist(File.join(dir, 'docs', 'AGENTS.md'))
        expect(File.read(File.join(dir, 'CLAUDE.md'))).not_to include('carrot-handoff:begin')
        expect(File).not_to exist(File.join(dir, 'AGENTS.md'))
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

    # The promise the tool makes about durability has to be true. A path git
    # refused is not staged, and the reason it gave is the only thing that
    # tells the reader what to do about it.
    it 'says a note it could not stage was not staged' do
      in_repo do |dir|
        commit_all(dir)
        File.write(File.join(dir, '.gitignore'), ".carrot.md\n")

        _status, out, = run_cli(['init'], dir: dir)

        expect(out).to include('Could not stage .carrot.md')
        expect(out).to match(/Could not stage \.carrot\.md: .+ignored/)
        expect(out).to include('Staged AGENTS.md')
        expect(out).not_to include('Staged .carrot.md')
      end
    end

    # The suggested commit names what was actually staged, so it cannot name
    # a file that is not in the index.
    it 'names the files it staged in the commit command' do
      in_repo do |dir|
        commit_all(dir)
        _status, out, = run_cli(['init'], dir: dir)

        expect(out).to include('git commit -m "chore: add AGENTS.md .carrot.md"')
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

    # The note is the only copy of the content. A byte that was not valid
    # UTF-8 becomes the replacement character when the note is written, and
    # that is a real change to the file — the kind that is invisible
    # afterwards, because the note still parses and the section count is
    # unchanged.
    it 'says that it replaced a byte that was not valid UTF-8' do
      in_repo do |dir|
        commit_all(dir)
        path = File.join(dir, '.carrot.md')
        # The byte goes in a section the save keeps. `Task` is replaced by the
        # argument, so a byte there would never reach the file.
        File.binwrite(path, "## Task\n\nA task\n\n## Decisions\n\ncaf\xE9 latte\n")

        status, out, = run_cli(['save', 'A task'], dir: dir)

        expect(status).to eq(0)
        expect(out).to match(/Replaced 1 byte/)
        expect(File.read(path)).to include("caf\uFFFD latte")
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

    # `load` prints the file rather than a parsed record, so it cannot use the
    # same reader as `status` and `save`. It still has to report an unreadable
    # note the way they do.
    it 'reports a note it cannot read, rather than raising' do
      in_repo do |dir|
        commit_all(dir)
        path = File.join(dir, '.carrot.md')
        File.write(path, "## Task\n\nA task\n")
        File.chmod(0o000, path)

        status, _out, err = run_cli(['load'], dir: dir)

        expect(status).to eq(1)
        expect(err).to include('could not read')
      ensure
        File.chmod(0o644, path) if path && File.exist?(path)
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

    it 'warns about a subheading in the State section' do
      in_repo do |dir|
        commit_all(dir)
        path = File.join(dir, '.carrot.md')
        File.write(path, "## Task\n\nA.\n\n## State\n\n- Branch: `main`\n\n### 2026-10-10\n\nContext.\n")

        _, out, = run_cli(['status'], dir: dir)

        expect(out).to match(/warning:.*State/)
      end
    end

    # A stray latin-1 byte from a pasted terminal snippet used to take the
    # whole tool down with a raw backtrace. The project's own rule is that a
    # malformed note must never raise.
    it 'reads a note with a byte that is not valid UTF-8, and says so' do
      in_repo do |dir|
        commit_all(dir)
        path = File.join(dir, '.carrot.md')
        File.binwrite(path, "## Task\n\ncaf\xE9 latte\n")

        status, out, = run_cli(['status'], dir: dir)

        expect(status).to eq(0)
        expect(out).to match(/not valid UTF-8/)
      end
    end
  end

  describe 'a note that would lose content' do
    # A subheading written just above the next `##` heading lands in `State`,
    # and `State` is regenerated from git on every save. The block is deleted
    # and the note still looks healthy: the section is still there, and it
    # still has text in it.
    let(:note_with_state_subheading) do
      "## Task\n\nA.\n\n## State\n\n- Branch: `main`\n\n### 2026-10-10\n\nContext.\n"
    end

    it 'refuses to save over it, and writes nothing' do
      in_repo do |dir|
        commit_all(dir)
        path = File.join(dir, '.carrot.md')
        File.write(path, note_with_state_subheading)
        before = File.binread(path)

        status, _out, err = run_cli(['save', 'A task'], dir: dir)

        expect(status).to eq(1)
        expect(err).to include('State')
        expect(File.binread(path)).to eq(before)
      end
    end

    # `save "<task>"` used to replace the whole Task section, so the paragraphs
    # a previous session wrote there went with it. The note still parsed, and
    # the section count did not move, so nothing reported the loss.
    it 'refuses to replace a Task that holds more than its first paragraph' do
      in_repo do |dir|
        commit_all(dir)
        path = File.join(dir, '.carrot.md')
        File.write(path, "## Task\n\nShip it.\n\nThe context paragraph.\n\nMore context.\n")
        before = File.binread(path)

        status, _out, err = run_cli(['save', 'Something else'], dir: dir)

        expect(status).to eq(1)
        expect(err).to include('refusing to save')
        expect(err).to include('Task')
        expect(err).to include('The context paragraph.')
        expect(err).to include('More context.')
        expect(File.binread(path)).to eq(before)
      end
    end

    it 'replaces the Task when --replace-task asks for it' do
      in_repo do |dir|
        commit_all(dir)
        path = File.join(dir, '.carrot.md')
        File.write(path, "## Task\n\nShip it.\n\nThe context paragraph.\n")

        status, = run_cli(['save', '--replace-task', 'Something else'], dir: dir)

        expect(status).to eq(0)
        expect(Zanoria::Record.load(path).task).to eq('Something else')
      end
    end

    it 'still replaces a Task that holds only the line being written' do
      in_repo do |dir|
        commit_all(dir)
        path = File.join(dir, '.carrot.md')
        File.write(path, "## Task\n\nShip it.\n")

        status, = run_cli(['save', 'Something else'], dir: dir)

        expect(status).to eq(0)
        expect(Zanoria::Record.load(path).task).to eq('Something else')
      end
    end

    it 'keeps the preamble through a save' do
      in_repo do |dir|
        commit_all(dir)
        path = File.join(dir, '.carrot.md')
        File.write(path, "# Handoff note\n\nSome preamble.\n\n## Task\n\nA.\n")

        status, = run_cli(['save', 'A task'], dir: dir)

        expect(status).to eq(0)
        expect(File.read(path)).to include('Some preamble.')
      end
    end

    it 'keeps both bodies when two headings are the same section' do
      in_repo do |dir|
        commit_all(dir)
        path = File.join(dir, '.carrot.md')
        File.write(path, "## Decisions\n\nFirst.\n\n## DECISIONS\n\nSecond.\n")

        status, = run_cli(['save', 'A task'], dir: dir)

        expect(status).to eq(0)
        expect(File.read(path)).to include('First.')
        expect(File.read(path)).to include('Second.')
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

    # Deleting needs write permission on the *directory*, not on the note, so
    # the way to make it fail is to make the directory read-only.
    it 'reports a note it cannot delete, rather than raising' do
      in_repo do |dir|
        commit_all(dir)
        File.write(File.join(dir, '.carrot.md'), "## Task\n\nA task\n")
        File.chmod(0o555, dir)

        status, _out, err = run_cli(['clear'], dir: dir)

        expect(status).to eq(1)
        expect(err).to include('could not delete')
      ensure
        File.chmod(0o755, dir) if dir && File.directory?(dir)
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

  describe 'moo' do
    it 'prints the art and succeeds' do
      in_repo do |dir|
        commit_all(dir)
        status, out, = run_cli(['moo'], dir: dir)

        expect(status).to eq(0)
        expect(out).to include('Se me cayó la zanoria')
        expect(out).to include('moo')
      end
    end

    # The easter egg depends on being undiscoverable from the help text. Without
    # this assertion, adding `moo` to the command table later is a tidy-up that
    # every other example still passes.
    it 'is absent from the help text' do
      in_repo do |dir|
        _status, out, = run_cli(['help'], dir: dir)

        expect(out).not_to include('moo')
      end
    end

    # Backslashes are load-bearing in the art. In an interpolating heredoc `\ ` is
    # an escape, so the figure loses its backslashes — and every content-based
    # example above still passes, because the words survive. This is the
    # assertion that notices the drawing, not the sentence.
    #
    # Counted rather than pattern-matched, and the difference is the whole point.
    # The first version of this asserted on two literal strings from the original
    # drawing, so replacing the art — with art that was perfectly fine — turned
    # the guard red without anything being wrong. A test coupled to one drawing's
    # exact bytes guards that drawing, not the property. Comparing the count in
    # the parsed constant against the count in the source heredoc holds for any
    # drawing and still fails the moment the `'` comes off `<<~'ART'`.
    it 'keeps every backslash the source heredoc has' do
      source = File.read(File.expand_path('../lib/zanoria/moo.rb', __dir__))
      heredoc = source[/<<~'ART'\n(.*?)\n\s*ART$/m, 1]

      expect(heredoc).not_to be_nil
      expect(Zanoria::Moo::ART.count('\\')).to eq(heredoc.count('\\'))
    end

    # Monospace art that wraps in an 80-column terminal is broken, and eyeballing
    # it in a wide window hides exactly that.
    it 'fits an 80-column terminal' do
      widest = Zanoria::Moo::ART.lines.map { |line| line.chomp.length }.max

      expect(widest).to be <= 80
    end

    it 'touches nothing in the repository' do
      in_repo do |dir|
        commit_all(dir)
        run_cli(['save', 'A task'], dir: dir)
        # Committed, because `save` leaves the note untracked and a dirty tree
        # would make this assert on `save`'s effect rather than on `moo`'s.
        git(dir, 'add', '-A')
        git(dir, 'commit', '--quiet', '-m', 'add note')
        before = File.read(File.join(dir, '.carrot.md'))

        run_cli(['moo'], dir: dir)

        expect(File.read(File.join(dir, '.carrot.md'))).to eq(before)
        expect(git(dir, 'status', '--porcelain')).to eq('')
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
