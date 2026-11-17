# frozen_string_literal: true

require_relative '../lib/zanoria'
require_relative 'spec_helper'

RSpec.describe Zanoria::Archive do
  let(:note) do
    <<~MD
      ## Task

      Ship #8.

      _Started: 2026-11-17_

      ## Decisions

      Introductory text stays put.

      ### 2026-10-10

      An old decision.

      ### 2026-11-17

      A decision on the boundary.

      ### Undated

      No date here.

      ## Tried and failed

      ### 2026-10-01

      An old dead end.

      ## Open questions

      ### 2026-10-02

      This is still open.
    MD
  end

  def write(dir, name, text)
    path = File.join(dir, name)
    File.write(path, text)
    path
  end

  def run_archive(dir)
    described_class.run(note_path: File.join(dir, '.carrot.md'))
  end

  it 'moves dated blocks from before the start into the archive' do
    in_repo do |dir|
      write(dir, '.carrot.md', note)

      result = run_archive(dir)

      live = File.read(File.join(dir, '.carrot.md'))
      archive = File.read(File.join(dir, '.carrot-archive.md'))
      expect(result.moved).to eq(2)
      expect(live).not_to include('An old decision.')
      expect(live).not_to include('An old dead end.')
      expect(archive).to include('An old decision.')
      expect(archive).to include('An old dead end.')
    end
  end

  it 'keeps a block dated on the start date' do
    in_repo do |dir|
      write(dir, '.carrot.md', note)

      run_archive(dir)

      expect(File.read(File.join(dir, '.carrot.md'))).to include('A decision on the boundary.')
    end
  end

  it 'keeps an undated block' do
    in_repo do |dir|
      write(dir, '.carrot.md', note)

      run_archive(dir)

      expect(File.read(File.join(dir, '.carrot.md'))).to include('No date here.')
    end
  end

  # Pending work under a dated heading is still pending work. Moving it would
  # hide it from the only file a reader is told to read.
  it 'does not archive Open questions' do
    in_repo do |dir|
      write(dir, '.carrot.md', note)

      run_archive(dir)

      expect(File.read(File.join(dir, '.carrot.md'))).to include('This is still open.')
      expect(File.read(File.join(dir, '.carrot-archive.md'))).not_to include('This is still open.')
    end
  end

  it 'groups moved blocks under the section they came from' do
    in_repo do |dir|
      write(dir, '.carrot.md', note)

      run_archive(dir)

      archive = File.read(File.join(dir, '.carrot-archive.md'))
      expect(archive).to include('# Archived rounds')
      expect(archive).to match(/## Decisions\n\n### 2026-10-10\n\nAn old decision\./)
      expect(archive).to match(/## Tried and failed\n\n### 2026-10-01\n\nAn old dead end\./)
    end
  end

  it 'leaves the task and the round start in the live note' do
    in_repo do |dir|
      write(dir, '.carrot.md', note)

      run_archive(dir)

      record = Zanoria::Record.load(File.join(dir, '.carrot.md'))
      expect(record.task).to eq('Ship #8.')
      expect(record.started_at).to eq('2026-11-17')
    end
  end

  it 'appends to an existing archive instead of overwriting it' do
    in_repo do |dir|
      write(dir, '.carrot.md', note)
      write(dir, '.carrot-archive.md',
            "# Archived rounds\n\nEarlier notes.\n\n## Decisions\n\n### 2020-01-01\n\nAn older decision.\n")

      run_archive(dir)

      archive = File.read(File.join(dir, '.carrot-archive.md'))
      expect(archive).to include('Earlier notes.')
      expect(archive).to include('An older decision.')
      expect(archive).to include('An old decision.')
    end
  end

  it 'does not write a block that is already in the archive' do
    in_repo do |dir|
      write(dir, '.carrot.md', note)
      write(dir, '.carrot-archive.md', "# Archived rounds\n\n## Decisions\n\n### 2026-10-10\n\nAn old decision.\n")

      run_archive(dir)

      archive = File.read(File.join(dir, '.carrot-archive.md'))
      expect(archive.scan('An old decision.').length).to eq(1)
    end
  end

  it 'writes nothing on a second run with nothing left to move' do
    in_repo do |dir|
      write(dir, '.carrot.md', note)
      run_archive(dir)
      note_before = File.binread(File.join(dir, '.carrot.md'))
      archive_before = File.binread(File.join(dir, '.carrot-archive.md'))

      result = run_archive(dir)

      expect(result.reason).to eq(:nothing)
      expect(File.binread(File.join(dir, '.carrot.md'))).to eq(note_before)
      expect(File.binread(File.join(dir, '.carrot-archive.md'))).to eq(archive_before)
    end
  end

  it 'writes nothing when every block belongs to the current round' do
    in_repo do |dir|
      write(dir, '.carrot.md',
            "## Task\n\nA.\n\n_Started: 2020-01-01_\n\n## Decisions\n\n### 2020-01-01\n\nThis round.\n")

      result = run_archive(dir)

      expect(result.reason).to eq(:nothing)
      expect(File).not_to exist(File.join(dir, '.carrot-archive.md'))
    end
  end

  it 'refuses without a start date and leaves both files alone' do
    in_repo do |dir|
      path = write(dir, '.carrot.md', "## Task\n\nA.\n\n## Decisions\n\n### 2020-01-01\n\nOld.\n")
      before = File.binread(path)

      result = run_archive(dir)

      expect(result.reason).to eq(:no_start)
      expect(File.binread(path)).to eq(before)
      expect(File).not_to exist(File.join(dir, '.carrot-archive.md'))
    end
  end

  it 'names the archive in the State of the note it writes' do
    in_repo do |dir|
      commit_all(dir)
      write(dir, '.carrot.md', note)

      run_archive(dir)

      expect(File.read(File.join(dir, '.carrot.md'))).to include('Earlier rounds: `.carrot-archive.md`')
    end
  end
end
