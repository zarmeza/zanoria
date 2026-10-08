# frozen_string_literal: true

module Zanoria
  # Renders the note.
  #
  # The design goal is that the sections a machine can fill in are filled in,
  # and the sections only a human or agent knows are left as prompts. The
  # "Tried and failed" prompts are the point of the whole tool: that is the
  # information neither tool can reconstruct on its own.
  module Template
    PROMPTS = {
      task: 'What this task is, in a couple of sentences. Enough for someone with no conversation history.',
      decisions: 'Choices already made, and why. Include the options rejected.',
      next_action: 'The single next step, specific enough to start on cold.',
      open_questions: 'Anything unknown, unverified, or blocked. Empty is fine.'
    }.freeze

    PROMPT_RE = /\A_TODO:/i

    # Cap on individual filenames listed in the State section. Past this the
    # note stops being scannable and starts being a `git status` dump.
    LIST_LIMIT = 20

    module_function

    def render(record, prompt: true)
      canonical = Record::SECTIONS.map do |key, heading|
        "## #{heading}\n\n#{body_for(record, key, prompt: prompt)}\n"
      end.join("\n")

      extras = extra_sections(record)
      extras.empty? ? canonical : "#{canonical}\n#{extras.join("\n")}"
    end

    # Unrecognized headings the note's author added, in the order they appeared.
    #
    # These have to be written back out. `save` rewrites the whole file, so a
    # section that is parsed but never rendered is not merely hidden -- it is
    # deleted, taking the hand-written content with it. Preserving them here is
    # the whole reason `Record.parse` keeps them under an `other_` key.
    #
    # Rendered after the canonical sections so their fixed order is undisturbed.
    def extra_sections(record)
      record.extra_sections.map do |key|
        "## #{record.heading_for(key) || deslug(key)}\n\n#{record[key].strip}\n"
      end
    end

    # Fallback for a Record assembled in code rather than parsed from a file,
    # where there is no original heading to recover. The CLI always goes through
    # `parse`, so this only serves direct callers.
    def deslug(key)
      key.to_s.sub(/\Aother_/, '').tr('_', ' ')
    end

    def body_for(record, key, prompt:)
      # An untouched prompt from a previous save must be regenerated rather
      # than frozen in as content. This is what keeps repeated saves idempotent.
      body = record[key].to_s
      body = '' if PROMPT_RE.match?(body.strip)

      # State is machine-derived, so it is replaced on every render rather than
      # preserved. Preserving it would freeze the note at whatever the worktree
      # looked like the first time it was saved — the file would then claim a
      # clean branch that no longer exists. Anything a human wants to say about
      # the state of the work belongs in Decisions or Open questions.
      body = observed_state if key == :state
      body = prompt_for(key) if prompt && body.strip.empty?

      body.strip
    end

    def prompt_for(key)
      text = PROMPTS[key]
      text ? "_TODO: #{text}_" : '_TODO:_'
    end

    # Best-effort git facts, assembled from small parts so each stays readable.
    # Never raises: an empty state block beats a failed handoff.
    def observed_state
      snapshot = {
        repo: Git.root,
        branch: Git.branch,
        head: Git.head,
        dirty: Git.dirty_files || [],
        commits: Git.recent_commits || []
      }

      lines = identity_lines(snapshot[:branch], snapshot[:head])
      lines.concat(worktree_lines(snapshot[:dirty], identified: identified?(snapshot)))
      lines.concat(commit_lines(snapshot[:commits]))

      return lines.join("\n") unless lines.empty?

      # A repository with no commits is the same shape as no repository at all:
      # `branch` and `head` are both nil because nothing has been committed yet.
      # `init` is the first command anyone runs in a fresh repo, so this is the
      # line a new project reads moments after being told it was initialized.
      # Telling that user there is no repository reads as a bug in the tool.
      snapshot[:repo] ? 'Repository has no commits yet.' : 'No git repository detected.'
    rescue StandardError => e
      "Could not inspect git state: #{e.class}: #{e.message}"
    end

    # Without a branch or a HEAD there is no repository to speak of, so the
    # worktree can be neither clean nor dirty.
    def identified?(snapshot)
      !snapshot[:branch].nil? || !snapshot[:head].nil?
    end

    def identity_lines(branch, head)
      lines = []
      lines << "- Branch: `#{branch}`" if branch
      lines << "- HEAD: `#{head}`" if head
      lines
    end

    def worktree_lines(dirty, identified:)
      return ['- Worktree: clean'] if dirty.empty? && identified
      return [] if dirty.empty?

      lines = ["- Uncommitted: #{dirty.size} file(s)"]
      dirty.first(LIST_LIMIT).each { |f| lines << "  - `#{f}`" }
      lines << "  - _…and #{dirty.size - LIST_LIMIT} more_" if dirty.size > LIST_LIMIT
      lines
    end

    def commit_lines(commits)
      return [] if commits.empty?

      ['', 'Recent commits:'] + commits.map { |c| "- `#{c}`" }
    end
  end
end
