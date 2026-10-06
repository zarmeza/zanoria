# frozen_string_literal: true

require 'tmpdir'
require 'open3'

require_relative '../lib/carrot_handoff'
require_relative 'spec_helper'

RSpec.describe CarrotHandoff::Git do
  it 'reports the repo root' do
    in_repo do |dir|
      expect(described_class.root).to eq(File.realpath(dir))
    end
  end

  it 'returns nil outside a repository' do
    Dir.mktmpdir do
      allow(Open3).to receive(:capture2).and_raise(Errno::ENOENT)
      described_class.reset!

      expect(described_class.root).to be_nil
    end
  end

  it 'reports the current branch and HEAD after a commit' do
    in_repo do |dir|
      commit_all(dir)
      described_class.reset!

      expect(described_class.branch).to match(/\A(master|main)\z/)
      expect(described_class.head).to match(/\A[0-9a-f]{7,}\z/)
    end
  end

  it 'lists uncommitted files and reports the worktree as dirty' do
    in_repo do |dir|
      commit_all(dir)
      File.write(File.join(dir, 'untracked.txt'), 'x')
      described_class.reset!

      expect(described_class).not_to be_clean
      expect(described_class.dirty_files.first).to include('untracked.txt')
    end
  end

  it 'reports a clean worktree right after a commit' do
    in_repo do |dir|
      commit_all(dir)
      described_class.reset!

      expect(described_class).to be_clean
    end
  end

  it 'returns nil HEAD in a repo with no commits' do
    in_repo do
      expect(described_class.head).to be_nil
    end
  end

  it 'distinguishes tracked changes from untracked files' do
    in_repo do |dir|
      commit_all(dir)
      File.write(File.join(dir, 'untracked.txt'), 'x')
      described_class.reset!

      expect(described_class.dirty_files.size).to eq(1)
      expect(described_class.changed_tracked_files).to be_empty
    end
  end

  it 'summarizes recent commits newest first' do
    in_repo do |dir|
      commit_all(dir, message: 'First', filename: 'a.txt')
      commit_all(dir, message: 'Second', filename: 'b.txt')
      described_class.reset!

      commits = described_class.recent_commits
      expect(commits.first).to include('Second')
      expect(commits.last).to include('First')
    end
  end

  it 'knows whether a path is tracked' do
    in_repo do |dir|
      commit_all(dir, filename: 'tracked.txt')
      File.write(File.join(dir, 'untracked.txt'), 'x')
      described_class.reset!

      expect(described_class).to be_tracked('tracked.txt')
      expect(described_class).not_to be_tracked('untracked.txt')
    end
  end
end
